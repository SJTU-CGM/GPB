#!/usr/bin/perl

package GPBarg;

use strict;
use warnings;


sub check_input {
	my ($vcf, $reffa, $graph, $refname, $gff, $geneid, $genelist, $region, $regionlist, $extend, $bed, $pheno, $maxe, $maxd, $threads) = @_;

	my $has_vcf_mode = ($vcf || $reffa);
	my $has_graph_mode = ($graph || $refname);

	if($has_vcf_mode && $has_graph_mode){
		die "Error: Cannot use both Variant mode and Graph mode parameters simultaneously\n";
	}elsif(!$has_vcf_mode && !$has_graph_mode){
		die "Error: Must select one input mode: Variant mode (--vcf/--reffa) or Graph mode (--graph/--refname)\n";
	}else{
		die "Error: --reffa is required when using --vcf\n" if $vcf && !$reffa;
        	die "Error: --vcf is required when using --reffa\n" if $reffa && !$vcf;
        	die "Error: --refname is required when using --graph\n" if $graph && !$refname;
        	die "Error: --graph is required when using --refname\n" if $refname && !$graph;
	}

	if(!defined $gff){
        	die "Error: Please provide the GFF file with gene annotation\n";
	}

	my @range_options = ($geneid, $genelist, $region, $regionlist);
	my $range_count = scalar grep { defined $_ } @range_options;
	if ($range_count == 0){
        	die "Error: Please specify one analysis range parameter: --geneid, --genelist, --region, or --regionlist\n";
	}elsif ($range_count > 1) {
        	die "Error: Can only specify one analysis range parameter: --geneid, --genelist, --region, or --regionlist\n";
	}

	if (defined $extend && !$geneid && !$genelist) {
    		warn "Warning: --extend parameter can only be used with --geneid or --genelist\n";
	}

	die "Error: --extend value must be greater than or equal to 0\n" if defined $extend && $extend < 0;
        die "Error: -d/--max-distance-subpaths value must be greater than or equal to 0\n" if defined $maxd && $maxd < 0;
        die "Error: -e/--max-merging-iterations value must be greater than or equal to 0\n" if defined $maxe && $maxe < 0;
        die "Error: -t/--threads value must be greater than 0\n" if defined $threads && $threads < 1;
        die "Error: Invalid region format: $region. Expected format: 'chr:start-end' (e.g., chr1:1000-2000), and end must be greater than start.\n" if $region && !validate_region_format($region);

	check_file($vcf, "VCF") if defined $vcf;
	check_vcf_index($vcf) if defined $vcf;
	check_file($reffa, "Reference genome") if defined $reffa;
	check_file($graph, "Graph pangenome") if defined $graph;

	check_file($gff, "GFF") if defined $gff;
	check_zip($gff) if defined $gff;
	check_file($bed, "BED") if defined $bed;
	validate_bed_file($bed) if defined $bed;
	check_file($pheno, "Phenotype") if defined $pheno;
	validate_phenotype_file($pheno) if defined $pheno;

	check_file($genelist, "Gene list") if defined $genelist;
	check_file($regionlist, "Region list") if defined $regionlist;
	validate_regionlist_file($regionlist) if defined $regionlist;

}

sub check_zip {
	my ($file) = @_;

	$file =~ s/'/'\\''/g;	
	my $type = `file -b --mime-type '$file' 2>/dev/null`;
	$? && die "Error: 'file' command failed or not found.\n";
	
	chomp($type);
	if ($type =~ /^application\/(gzip|x-gzip|zip|x-bzip2|xz)$/){
		die "Error: '$file' is compressed ($type). Please provide a plain-text GFF file.\n"
	}

	return 1;
}

sub mk_outdir {
	my ($out) = @_;

	my $dir_name;
	if (defined $out){
        	$dir_name = $out;
	} else {
        	my ($sec, $min, $hour, $mday, $mon, $year) = localtime;
        	$dir_name = sprintf("gpb_res_%02d-%02d_%02d%02d%02d", $mon+1, $mday, $hour, $min, $sec);
	}
	die "Error: Output directory \"$dir_name\" already exists. To avoid overwriting of existing files, we kindly request that the output directory should not exist.\n" if -e $dir_name;

	mkdir $dir_name or die "Error: Failed to create directory \"$dir_name\": $!\n";
	
	return $dir_name;
}


sub check_file {
    my ($file, $type) = @_;
    return 0 unless defined $file;

    if (!-e $file) {
        die "Error: $type file does not exist: $file\n";
        return 0;
    }
    if (!-r $file) {
        die "Error: $type file is not readable: $file\n";
        return 0;
    }
    if (-z $file) {
        die "Error: $type file is empty: $file\n";
        return 0;
    }

    return 1;
}


sub check_vcf_index {
    my ($vcf) = @_;

    -e $vcf or die "Error: File'$vcf' does not exist\n";

    open my $fh, '<:raw', $vcf or die "Error: Can't open file '$vcf': $!\n";
    my $head;
    read $fh, $head, 16;
    close $fh;
    substr($head, 0, 3) eq "\x1f\x8b\x08" or die "Error: '$vcf' is not bgzip (block-gzipped) format\n";
	
    (-f "$vcf.tbi" || -f "$vcf.csi") or die "Error: file '$vcf' missing index file (.tbi or .csi)\n";

    return 1;
}


sub validate_region_format {
    my ($region) = @_;
    return 0 unless defined $region;

    if ($region =~ /^([^:]+):(\d+)-(\d+)$/) {
        my ($chr, $start, $end) = ($1, $2, $3);
        return 0 if $start >= $end;
        return 0 if $start < 1;
        return 1;
    }

    return 0;
}


sub validate_bed_file {
    my ($file) = @_;
    open my $fh, '<', $file or die "Error: Can't open file '$file': $!\n";
    my $line_no = 0;
    while (my $line = <$fh>) {
        $line_no++;
	next if $line =~ /^#/;
        next if $line =~ /^\s*$/;
        $line =~ s/\s+$//;
        my @f = split /\t/, $line;

        @f == 4 or die "Error: Line $line_no in file '$file': expected 4 columns (sequence<tab>start<tab>end<tab>annotation); got " . scalar(@f) . "\n";

        $f[1] =~ /^[0-9]+$/ or die "Error: Line $line_no in file '$file': start '$f[1]' not integer \n";
        $f[2] =~ /^[0-9]+$/ or die "Error: Line $line_no in file '$file': end   '$f[2]' not integer \n";
        $f[1] < $f[2]       or die "Error: Line $line_no in file '$file': start >= end '\n";
    }
    close $fh;
    return 1;
}


sub validate_phenotype_file {
        my ($file) = @_;

        open my $fh, '<', $file or die "Error: Can't open file '$file': $!\n";

        my $header = <$fh>;
        chomp $header;
        my @headers = split(/\t/, $header);

        if (scalar @headers < 2) {
                warn "Warning: Phenotype file should contain at least one phenotype column besides 'Path'\n";
        }

        my $line_num = 1;
        my %path_names;
        while (my $line = <$fh>) {
                $line_num++;
                chomp $line;
		next if $line =~ /^#/;
                next if $line =~ /^\s*$/;
                my @fields = split(/\t/, $line);
                if (scalar @fields < 1) {
                        warn "Warning: Line $line_num in file '$file': Empty line or missing data\n";
                        next;
                }
                my $path_name = $fields[0];
                if (exists $path_names{$path_name}) {
                        warn "Warning: Line $line_num in file '$file': Duplicate path name '$path_name'\n";
                }
                $path_names{$path_name}++;

        }

        close $fh;

	return 1;
}


sub validate_regionlist_file {
	my ($regionlist) = @_;

	open my $fh, '<', $regionlist or die "Error: Can't open file '$regionlist': $!\n";

	while (my $line = <$fh>) {
		chomp $line;
		next if $line =~ /^#/;
		next if $line =~ /^\s*$/;

		my ($chr, $start, $end) = $line =~ /^(?:chr)?([^:\s]+):([\d,]+)-([\d,]+)$/i
        		or die "Error: Invalid region format: $line. Expected format: 'chr:start-end' (e.g., chr1:1000-2000).\n";
		
		s/,//g for ($start, $end);

		$end > $start or die "Error: Invalid region format: $line. End must be greater than start.\n";

	}

	close $fh;

	return 1;
}


1;

