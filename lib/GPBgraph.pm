#!/usr/bin/perl

package GPBgraph;

use strict;
use warnings;
use File::Temp qw(tempfile);
use GPBvcf;


sub build_graph {
	
	my ($vcf, $reffa, $interval_arr, $dir_name, $thread) = @_;
	my @interval_arr = @$interval_arr;

	my %seen;
	my @chr_uniq = grep { !$seen{$_}++ } map { $_->[1] } @interval_arr;

	system('/bin/sh', '-c',
		qq{samtools faidx \Q$reffa\E }.join(' ', map { quotemeta } @chr_uniq).qq{ > \Q$dir_name/seq.fa\E 2>/dev/null}) == 0
		or die "Error: Failed to extract sequence (".join(' ',@chr_uniq).") from FASTA file: $?.\n";

	my $region_arg;
	if (@interval_arr == 1) {
		my ($chr, $start, $end) = @{$interval_arr[0]}[1,2,3];
		$region_arg = "-r ${chr}:${start}-${end}";
	} else {
		open my $bed_fh, '>', "${dir_name}/interval.bed" or die "Error: Can't write file '${dir_name}/interval.bed': $!\n";
		for my $interval_row (@interval_arr) {
			my ($chr, $start, $end) = @$interval_row[1,2,3];
			print $bed_fh join("\t", $chr, $start-1, $end), "\n";
		}
		close $bed_fh;
		$region_arg = "-R ${dir_name}/interval.bed";
	}

	my (undef, $tmp_view)  = tempfile(DIR => $dir_name, SUFFIX => '.view.vcf.gz', UNLINK => 1);
	my (undef, $tmp_sort)  = tempfile(DIR => $dir_name, SUFFIX => '.sort.vcf.gz', UNLINK => 1);
	my (undef, $tmp_norm)  = tempfile(DIR => $dir_name, SUFFIX => '.norm.vcf.gz', UNLINK => 1);
	my (undef, $tmp_gt)  = tempfile(DIR => $dir_name, SUFFIX => '.gt.vcf', UNLINK => 1);
	my (undef, $tmp_process)  = tempfile(DIR => $dir_name, SUFFIX => '.process.vcf', UNLINK => 1);

	system('/bin/sh', '-c', 
		qq{bcftools view --threads $thread $region_arg -i 'GT ~ "1[|/]1"' \Q$vcf\E -Oz -o \Q$tmp_view\E 2>/dev/null}) == 0
    		or die "Error: bcftools view failed, exit code: $?\n";
	system('/bin/sh', '-c',
                qq{bcftools annotate -x INFO,^FORMAT/GT \Q$tmp_view\E | bcftools sort -Oz -o \Q$tmp_sort\E 2>/dev/null}) == 0
                or die "Error: bcftools sort failed, exit code: $?\n";
	system('/bin/sh', '-c',
		qq{bcftools norm --threads $thread -m- -f \Q${dir_name}/seq.fa\E \Q$tmp_sort\E | bcftools norm --threads $thread -d all -f \Q${dir_name}/seq.fa\E - -Oz -o \Q$tmp_norm\E 2>/dev/null}) == 0
		or die "Error: bcftools norm failed, exit code: $?\n";
	system('/bin/sh', '-c',
		qq{bcftools +setGT --threads $thread \Q$tmp_norm\E -- -t q -i 'GT~"1[|/]1"' -n c:'1|1' | bcftools +setGT --threads $thread -Ov -o \Q$tmp_gt\E -- -t q -e 'GT~"1[|/]1"' -n c:'0|0' 2>/dev/null}) == 0
		or die "Error: bcftools +setGT failed, exit code: $?\n";
	unlink $tmp_view, $tmp_sort, $tmp_norm;
	
	GPBvcf::process_vcf($tmp_gt, $tmp_process);

	system('/bin/sh', '-c',
	        qq{bcftools norm -d all -Ov -o \Q${dir_name}/pan.norm.vcf\E \Q$tmp_process\E 2>/dev/null}) == 0
	        or die "Error: bcftools norm failed: $?\n";
	
	open my $norm, '<', "${dir_name}/pan.norm.vcf" or die "Error: Can't open file '${dir_name}/pan.norm.vcf': $!\n";
	open my $vcf_out,  '>', "${dir_name}/pan.vcf" or die  "Error: Can't write file '${dir_name}/pan.vcf': $!\n";
        open my $list_out, '>', "${dir_name}/variant_samples.txt" or die  "Error: Can't write file '${dir_name}/variant_samples.txt': $!\n";

	my @samples;
        my $part_num = 0;

        while (my $line = <$norm>) {
                if ($line =~ /^##/) {
                        print $vcf_out $line;
                        next;
                }

                if ($line =~ /^#CHROM/) {
                        chomp $line;
                        my @f = split /\t/, $line;
                        @samples = @f[9..$#f];
                        print $vcf_out $line, "\n";
                        next;
                }

                chomp $line;
                my @f  = split /\t/, $line;
                my $gt_start = 9;

                my $count = 0;
                $count += () = join("\t", @f[$gt_start..$#f]) =~ /1\|1/g;
                ++$part_num;
                $f[2] = "ID$part_num-$count";

                my @hit;
                for my $i ($gt_start..$#f) {
                        my $gt = $f[$i];
			push @hit, $samples[$i - $gt_start] if $gt !~ /^(0\|0|\.\|\.)$/;
                }
                print $list_out join("\t", $f[2], join(',', @hit)), "\n";

                print $vcf_out join("\t", @f), "\n";

        }

	close $norm;
	close $vcf_out;
	close $list_out;

	my $vcf_count = `grep -v "#" "${dir_name}/pan.vcf" | wc -l`;
        die "Error: No variants were found in the region associated with the target gene.\n" if($vcf_count < 1);

	system("vg construct -A -r $dir_name/seq.fa -v ${dir_name}/pan.vcf --threads $thread > ${dir_name}/pan.vg") == 65280 or die "Error: Failed to construct the sequence graph using VG.\n";
	system("vg view ${dir_name}/pan.vg --threads $thread > ${dir_name}/pan.gfa") == 65280 or die "Error: Failed to output the GFA file using VG.\n";
        system("odgi build -g ${dir_name}/pan.gfa -o ${dir_name}/pan.og -t $thread") == 0 or die "Error: Failed to construct the sequence graph using ODGI.\n";

	unlink "$dir_name/overlap.bed" if -e "$dir_name/overlap.bed";
	unlink "$dir_name/interval.bed" if -e "$dir_name/interval.bed";
	unlink "$dir_name/pan.norm.vcf" if -e "$dir_name/pan.norm.vcf";
	unlink "$dir_name/seq.fa" if -e "$dir_name/seq.fa";
	unlink "$dir_name/seq.fa.fai" if -e "$dir_name/seq.fa.fai";
	unlink "$dir_name/pan.vg" if -e "$dir_name/pan.vg";
	unlink "$dir_name/pan.gfa" if -e "$dir_name/pan.gfa";	
}


sub extract_subgraph {

	my ($graph, $refname, $pos, $dir_name, $pref, $maxd, $maxe, $thread) = @_;	

	system("odgi extract -i $graph -r $pos -E -P -d $maxd -e $maxe -o $dir_name/${pref}_raw.og --threads $thread -P -E") == 0 or die "Error: Failed to extract subgraph using 'odgi extract'.\n";
        system("odgi normalize -i $dir_name/${pref}_raw.og -o $dir_name/${pref}_norm.og --threads $thread -P") == 0 or die "Error: Failed to compact unitigs and simplify redundant furcations using 'odgi normalize'.\n";
        system("odgi paths -i $dir_name/${pref}_norm.og -L --threads $thread -P | grep $refname > $dir_name/${pref}.refpath") == 0 or die "Error: Failed to interrogate reference path using 'odgi paths'.\n";
        system("odgi groom -i $dir_name/${pref}_norm.og -R $dir_name/${pref}.refpath -o $dir_name/${pref}.og --threads $thread -P") == 0 or die "Error: Failed to harmonize node orientations of reference path using 'odgi groom'.\n";
        system("odgi view -i $dir_name/${pref}.og -g > $dir_name/gfa/${pref}.gfa") == 0 or die "Error: Failed to output the GFA file using 'odgi view'.\n";

	unlink "$dir_name/${pref}_raw.og" if -e "$dir_name/${pref}_raw.og";
	unlink "$dir_name/${pref}_norm.og" if -e "$dir_name/${pref}_norm.og";
	unlink "$dir_name/${pref}.refpath" if -e "$dir_name/${pref}.refpath";
	unlink "$dir_name/${pref}.og" if -e "$dir_name/${pref}.og";

}



1;

