#!/usr/bin/perl

package GPBvcf;

use strict;
use warnings;
use List::Util qw(sum all);

sub process_vcf {
    my ($file, $out_file) = @_;
    open my $fh, '<', $file or die "Error open input file $file: $!\n";
    open my $fh_out, '>', $out_file or die "Error open output file $out_file: $!\n";

    my @var_cluster;
    my ($last_chr, $last_end);

    while (<$fh>) {
	chomp;
	my $line = $_;

	print $fh_out "$line\n";
       	next if (/^#/);

    	my %var = parse_variant_line($line);
	next if (length($var{alt}) > 1);

    	if ( defined $last_chr && $var{chr} eq $last_chr && $var{pos} <= $last_end ){
		push @var_cluster, \%var;
    	}else {
        	process_var_cluster(\@var_cluster, $fh_out) if @var_cluster >= 2;
        	@var_cluster = ( \%var );
    	}
    	$last_chr = $var{chr};
    	$last_end = $var{end};
     }
     
     process_var_cluster(\@var_cluster, $fh_out) if @var_cluster >= 2;
     close $fh;
     close $fh_out;

}


sub parse_variant_line {
    my ($line) = @_;
    my @f = split/\t/, $line;
    my ($chr,$pos,$id,$ref,$alt,$qual,$filter,$info,$format) = @f[0..8];
    my @geno_str = @f[9..$#f];

    my $ref_len = length($ref);
    my $end = $pos + $ref_len - 1;

    return (
        chr=>$chr, pos=>$pos, end=>$end, id=>$id, ref=>$ref, alt=>$alt,
        qual=>$qual, filter=>$filter, info=>$info, format=>$format,
	geno_str=>\@geno_str, ref_len=>$ref_len
    );
}


sub process_var_cluster {
    my ($cluster, $fh_out) = @_;
    my @vars = @$cluster;
    my $var_cnt = scalar(@vars);
    return if $var_cnt < 2;
    my $chr = $vars[0]{chr};

    my $multi_alt_cnt = sum map { length($_->{alt}||'') > 1 ? 1 : 0 } @vars;
    return if  $multi_alt_cnt > 1;
    if ($multi_alt_cnt == 1){
    	my ($target) = grep { length($_->{alt}||'') > 1 } @vars;
    	my $target_pos = $target->{pos};
    	return unless all { $_->{pos} eq $target_pos } @vars;
    }

    my $n = $var_cnt;
    my $sample_cnt = scalar(@{$vars[0]{geno_str}}) if $var_cnt > 0;
    return unless $sample_cnt;

    for my $win_len (2 .. $n) {
        for my $start (0 .. $n - $win_len) {
            my $end_idx = $start + $win_len - 1;
	    my @subset  = @vars[$start .. $end_idx];

            my $win_min_pos = (sort { $a <=> $b } map { $_->{pos} } @subset)[0];
            my $win_max_end = (sort { $b <=> $a }
                               map { $_->{pos} + length($_->{ref}) - 1 } @subset)[0];

	    my $has_common_sample = 0;
            SAMPLE_LOOP: 
            for my $sample_idx (0 .. $sample_cnt - 1) {
                my $all_homo = 1;
                for my $var (@subset) {
                    my $geno = $var->{geno_str}[$sample_idx] // '';
                    if ($geno ne '1|1') {
                        $all_homo = 0;
                        last; 
                    }
                }
                if ($all_homo) {
                    $has_common_sample = 1;
                    last SAMPLE_LOOP;  
                }
            }

	    next unless $has_common_sample;

	    my @intervals = map {
		    my $s = $_->{pos};
		    my $e = $s + length($_->{ref}) - 1;
		    [$s, $e];
	    } @subset;

	    my $all_touch = 1;
	    for my $i (0 .. $#intervals - 1) {
		    my ($s1, $e1) = @{$intervals[$i]};
		    for my $j ($i + 1 .. $#intervals) {
			    my ($s2, $e2) = @{$intervals[$j]};
			    if ($s2 - $e1 > 1 || $s1 - $e2 > 1) {
				    $all_touch = 0;
				    last;
			    }
		    }
		    last unless $all_touch;
	    }

	    next unless $all_touch;

            my $new_vcf_line = generate_merged_vcf(
                                   \@subset,
                                   $win_min_pos,
                                   $win_max_end);
            next if $new_vcf_line eq '';

            print $fh_out "$new_vcf_line\n";
        }
    }

}


sub generate_merged_vcf {
    my ($subset,  $merge_pos, $merge_end) = @_;
    my @vars = @$subset;
    return "" if scalar(@vars) < 2;
    
    my $chr = $vars[0]->{chr};
    my $merge_ids  = join(";", map {$_->{id}} @vars);
    
    my ($merged_ref, $merged_alt) = build_base_coord_map(\@vars, $merge_pos, $merge_end);
    
    my $sample_cnt = @{ $vars[0]{geno_str} };
    my @merge_geno;
    for my $i (0 .. $sample_cnt - 1){
	my $all_hom_alt = 1;
    	foreach my $var (@vars) {
            if ($var->{geno_str}[$i] ne '1|1') {
            	$all_hom_alt = 0;
            	last;
            }
    	}

    	if ($all_hom_alt) {
        	$merge_geno[$i] = '1|1';
    	} else {
        	$merge_geno[$i] = '0|0';
    	}
    }
    
    my @vcf_cols = (
        $chr, $merge_pos, $merge_ids, $merged_ref, $merged_alt,
        '.', 'PASS', '.', $vars[0]->{format},
        @merge_geno
    );
    return join("\t", @vcf_cols);
}



sub build_base_coord_map {
    my ($vars, $min_pos, $max_end) = @_;

    my @sorted_vars = sort { $a->{pos} <=> $b->{pos} } @$vars;
    my %coord_to_base;
    for my $v (@sorted_vars) {
        my $pos = $v->{pos};
        my @bases = split //, $v->{ref};
        for my $i (0 .. $#bases) {
            $coord_to_base{ $pos + $i } = $bases[$i];
        }
    }
    my $merged_ref = '';
    for my $c ($min_pos .. $max_end) {
        $merged_ref .= $coord_to_base{$c} // 'N';
    }

    my (@short, @long);
    for my $v (@sorted_vars) {
        my $alt = $v->{alt} // '';
        $alt = '-' if $alt eq '';
        length($alt) > 1 ? push @long, $v : push @short, $v;
    }

    my $merged_alt;
    if    (!@long && @short) {
        $merged_alt = $short[0]{alt};
    }
    elsif (@long == 1) {
	my $first = substr($merged_ref, 0, 1);
        my $rest  = substr($long[0]{alt}, 1);
        $merged_alt = $first . $rest;
    }
    else {
        $merged_alt = '.';
    }

    return ($merged_ref, $merged_alt);
}



1;



