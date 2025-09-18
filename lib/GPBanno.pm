#!/usr/bin/perl

package GPBanno;

use strict;
use warnings;
use List::Util qw(max);

sub get_interval {
	
	my ($geneid, $genelist, $region, $regionlist, $extend, $gff, $dir_name) = @_;

	my @interval_arr;
	if (defined $geneid && $geneid ne '') {
        	my ($gene_chr, $gene_start, $gene_end) = extract_gene_gff_file($geneid, $gff, "$dir_name/gff/$geneid.gff");
        	push(@interval_arr, [$geneid, $gene_chr, max(1, $gene_start - $extend), $gene_end + $extend]);
	} elsif (defined $genelist && $genelist ne '') {
        	open my $fh_genelist, '<', $genelist or die "Error: Can't open file '$genelist': $!\n";
        	while (my $line = <$fh_genelist>) {
                	chomp $line;
                	my ($geneid) = split /\t/, $line;
                	next unless $geneid;
                	my ($gene_chr, $gene_start, $gene_end) = extract_gene_gff_file($geneid, $gff, "$dir_name/gff/$geneid.gff");
                	push(@interval_arr, [$geneid, $gene_chr, max(1, $gene_start - $extend), $gene_end + $extend]);
        	}
        	close $fh_genelist;
	} elsif (defined $region && $region ne '') {
        	(my $file_region = $region) =~ s/:/_/;
        	my ($region_chr, $region_start, $region_end) = extract_region_gff_file($region, $gff, "$dir_name/gff/$file_region.gff");
        	push(@interval_arr, [$file_region, $region_chr, $region_start, $region_end]);
	} elsif (defined $regionlist && $regionlist ne ''){
        	open my $fh_regionlist, '<', $regionlist or die "Error: Can't open file '$regionlist': $!\n";
        	while (my $line = <$fh_regionlist>) {
                	chomp $line;
                	my ($region) = split /\t/, $line;
                	next unless $region;
                	(my $file_region = $region) =~ s/:/_/;
                	my ($region_chr, $region_start, $region_end) = extract_region_gff_file($region, $gff, "$dir_name/gff/$file_region.gff");
                	push(@interval_arr, [$file_region, $region_chr, $region_start, $region_end]);
        	}
		close $fh_regionlist;
	}

	return \@interval_arr;
}


sub find_gene_gff {
	
	my ($gene_id, $gff_file) = @_;
	
	open my $fh, '<', $gff_file or die "Error: Can't open file '$gff_file': $!\n";
	
	my @out;
	my %tx;
	my $gene_hit  = 0;
	my @gene_lines;

	while (my $line = <$fh>) {
		next if $line =~ /^#/;
		next if $line =~ /^\s*$/;
		chomp $line;
		my @f = split /\t/, $line;
		next unless @f >= 9;
		my $type = $f[2];
		my $attr = $f[8];

		if ($type eq 'gene') {
			if ($attr =~ /ID=(.*?)(;|$)/ && $1 eq $gene_id) {
				$gene_hit++;
				push @gene_lines, $.;
				push @out, $line;
			}
		} elsif ($type eq 'mRNA' || $type eq 'transcript') {
			if ($attr =~ /Parent=(.*?)(;|$)/ && $1 eq $gene_id) {
				my ($tx_id) = $attr =~ /ID=(.*?)(;|$)/;
				$tx{$tx_id} = 1 if defined $tx_id;
				push @out, $line;
			}
		}
	}

	if ($gene_hit == 0){
		die "Error: Can not found the gene '$gene_id' in the GFF file. Please check the gene ID and GFF file.\n"
	}elsif ($gene_hit > 1){
		die "Error: Gene ID '$gene_id' found $gene_hit times (should be exactly 1) at line " . join(',', @gene_lines) . " in '$gff_file'\n" unless $gene_hit == 1;
	}

	seek $fh, 0, 0;
	while (my $line = <$fh>) {
		next if $line =~ /^#/;
		next if $line =~ /^\s*$/;
		chomp $line;
		my @f = split /\t/, $line;
		my $type = $f[2];
		next unless $type =~ /^(exon|CDS|five_prime_UTR|three_prime_UTR|UTR3|UTR5)$/i;
		my $attr = $f[8];
		if ($attr =~ /Parent=(.*?)(;|$)/ && exists $tx{$1}) {
			push @out, $line;
		}
	}
	close $fh;

	return \@out; 
}


sub extract_gene_gff_file {
        my ($gene_id, $gff_file, $out_file) = @_;

	my $gene_anno = find_gene_gff($gene_id, $gff_file);

	open my $fh, '>', $out_file or die "Error: Can't write file '$out_file': $!\n";
	print $fh "$_\n" for @$gene_anno;
	close $fh;

	my ($gene_chr, $gene_start, $gene_end);
    	for my $line (@$gene_anno) {
        	next unless $line =~ /^([^\t]+)\t[^\t]*\tgene\t(\d+)\t(\d+)\t/;
        	($gene_chr, $gene_start, $gene_end) = ($1, $2, $3);
        	last;  
    	}

        return ($gene_chr, $gene_start, $gene_end);
}


sub extract_region_gff_file {
	my ($region, $gff_file, $out_file) = @_;
	
	my ($chr, $start, $end) = $region =~ /^([^:]+):(\d+)-(\d+)$/;

	my %wanted = map { $_ => 1 } qw(
    		gene mRNA transcript exon CDS three_prime_UTR five_prime_UTR UTR3 UTR5
	);

	open my $in,  '<', $gff_file or die "Error: Can't open file '$gff_file': $!\n";
	open my $out, '>', $out_file or die "Error: Can't write file '$out_file': $!\n";

	while (my $line = <$in>) {
		next if $line =~ /^#/;
		next if $line =~ /^\s*$/;
		chomp $line;
		my @f = split /\t/, $line;
		next unless @f >= 5;
		next unless $f[0] eq $chr;
		my $type = $f[2];
		next unless $wanted{$type};
		if ($f[3] <= $end && $f[4] >= $start) {
			print $out $line, "\n";
		}
	}
	close $in;
	close $out;
	
	return ($chr, $start, $end);
}


sub get_gene_pos {

        my ($gff_file) = @_;

	my %rank = (
        	gene            => 1,
        	mRNA            => 2,
        	transcript      => 2,
        	exon            => 3,
        	CDS             => 4,
        	three_prime_UTR => 4,
        	five_prime_UTR  => 4,
        	UTR3            => 4,
        	UTR5            => 4,
    	);
	
	open my $fh_gff, '<', $gff_file or die "Error: Can't open file '$gff_file': $!\n";
	my @rec;
	while (<$fh_gff>) {
		chomp;
		next if /^#/;
		next if /^\s*$/;
		my @f = split /\t/;
		next unless $f[2] eq 'gene';
		my $gid;
		for (split /;/, $f[8]) {
			my ($k, $v) = split /=/, $_, 2;
			if ($k eq 'ID') {
				$gid = $v;
				last;
			}
		}
		next unless defined $gid;
		push @rec, [ $f[0], $f[3], $gid ];
	}
	close $fh_gff;

	@rec = sort {
    		$a->[0] cmp $b->[0] || $a->[1] <=> $b->[1]
	} @rec;

	my %seen;
	my @gene_sorted = grep { !$seen{$_}++ } map { $_->[2] } @rec;

	my @all_gene_pos;
	for my $gene (@gene_sorted) {
		my %gene_pos;
		my @trans_arr;
		my $gene_anno = find_gene_gff($gene, $gff_file);

		@$gene_anno = sort {
			my ($ta) = (split /\t/, $a)[2];
			my ($tb) = (split /\t/, $b)[2];
			my $ra = $rank{$ta} // 99;
			my $rb = $rank{$tb} // 99;
			$ra <=> $rb || $a cmp $b
		} @$gene_anno;

		foreach my $line (@$gene_anno) {
			my @f = split /\t/, $line;
			my ($chr, $class, $start, $end, $strand, $attrs) = @f[0,2,3,4,6,8];
			my %attr = $attrs =~ /([^;=]+)=([^;]*)/g;

			if($class eq "gene"){
				$gene_pos{'gene_id'} = $attr{"ID"};
				$gene_pos{'chr'} = $chr;
				$gene_pos{'start'} = $start;
				$gene_pos{'end'} = $end;
				$gene_pos{'strand'} = $strand;	
			}elsif($class eq "mRNA" || $class eq "transcript"){
				push(@trans_arr, $attr{"ID"});
				push(@{$gene_pos{'ele'}}, ["transcript", $start, $end, $#trans_arr + 1, $attr{"ID"}]);
			}elsif ($class =~ /^(exon|CDS|three_prime_UTR|five_prime_UTR|UTR3|UTR5)$/i) {
				my @idx = grep { $trans_arr[$_] eq $attr{"Parent"} } 0 .. $#trans_arr;
				next unless @idx;
				$class = 'UTR3' if $class eq 'three_prime_UTR';
				$class = 'UTR5' if $class eq 'five_prime_UTR';
				push(@{$gene_pos{'ele'}}, [$class, $start, $end, $idx[0] + 1, $attr{"ID"}] // '');
			}
		}
		push @all_gene_pos, \%gene_pos;
	}

	return \@all_gene_pos;

}


sub get_gene_anno {
	my ($gff_file) = @_;
        my @gene_anno = `cat $gff_file`;
        my %rank = (
                gene            => 1,
                mRNA            => 2,
                transcript      => 2,
                exon            => 3,
                CDS             => 4,
                three_prime_UTR => 4,
                five_prime_UTR  => 4,
                UTR3            => 4,
                UTR5            => 4,
        );
        my @gene_anno_sorted = sort {
                my ($ta) = (split /\t/, $a)[2];
                my ($tb) = (split /\t/, $b)[2];
                $rank{$ta} <=> $rank{$tb}  ||  $a cmp $b
        } @gene_anno;

        my %gene_info;
        my @trans_arr;
        my @trans_data;
        my @element_data;

        foreach my $line (@gene_anno_sorted){
                my @arr = split(/\t/, $line);
                my $chr = $arr[0];
                my $class = $arr[2];
                my $start = $arr[3];
                my $end = $arr[4];
                my $strand = $arr[6];
                my $attrs = $arr[8];
                chomp $attrs;
                my %attr = $attrs =~ /([^;=]+)=([^;]*)/g;;
                my @idx;

		if($class eq "gene"){
                         %gene_info = (
                                 chr => $chr,
                                 start => $start,
                                 end => $end,
                                 strand => $strand,
                                 gene_id => $attr{"ID"},
                                 idx => 0,
                                 group => "gene"
                         );
                }elsif($class eq "mRNA" || $arr[2] eq "transcript"){
                        push(@trans_arr, $attr{"ID"});
                        push(@trans_data, [$start, $end, $#trans_arr + 1, $attr{"ID"}]);
                }elsif($class eq "exon" || $class eq "CDS" || $class eq "three_prime_UTR" || $class eq "five_prime_UTR" || $class eq "UTR3" || $class eq "UTR5"){
                        @idx = grep { $trans_arr[$_] eq $attr{"Parent"} } 0 .. $#trans_arr;
                        if($class eq "exon" || $class eq "CDS"){
                                push(@element_data, [$start, $end, $idx[0] + 1, $class]);
                        }elsif($class eq "three_prime_UTR" || $class eq "UTR3"){
                                push(@element_data, [$start, $end, $idx[0] + 1, "UTR3"]);
                        }elsif($class eq "five_prime_UTR" || $class eq "UTR5"){
                                push(@element_data, [$start, $end, $idx[0] + 1, "UTR5"]);
                        }
                }
        }

        return (\%gene_info, \@trans_data, \@element_data);

}


1;




