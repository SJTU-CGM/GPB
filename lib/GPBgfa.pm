#!/usr/bin/perl

package GPBgfa;

use strict;
use warnings;

sub build_graph {
	
	my ($vcf, $reffa, $gene_chr, $region_start, $region_end, $dir_name, $geneid, $thread) = @_;

	system("samtools faidx $reffa $gene_chr > $dir_name/$gene_chr.fa") == 0 or die "Error: Failed to extract the sequence ($gene_chr) containing the target gene from FASTA file.\n ";

        system(qq{
                bcftools view -r ${gene_chr}:${region_start}-${region_end} ${vcf} |
                bcftools norm -f ${dir_name}/${gene_chr}.fa -m- -Ov |
                awk 'BEGIN {FS=OFS="\\t"} 
                        /#CHROM/ {start=1; print; next} 
                        start {for (i=10; i<=NF; i++) gsub(/\\//, "|", \$i); print} 
                        !start {print}' |
                awk 'BEGIN {OFS="\\t"} 
                        /#CHROM/ {start=1; part_num=0; print; next} 
                        start {count=gsub(/(1\\|0|1\\|\\.|1\\|1|0\\|1|\\.\\|1)/, "1|1"); 
                                gsub(/\\.\\|\\./, "0|0");
                                part_num++; 
                                \$3="ID" part_num "-" count; 
                                print} 
                        !start {print}' |
                bcftools sort -Ov > ${dir_name}/$geneid.vcf
        }) == 0 or die "Error: Filed to extract variants from VCF file.\n";

        my $vcf_count = `grep -v "#" "${dir_name}/$geneid.vcf" | wc -l`;
        die "Error: No variants were found in the region associated with the target gene.\n" if($vcf_count < 1);

	system("vg construct -A -r $dir_name/$gene_chr.fa -v ${dir_name}/$geneid.vcf --threads $thread > ${dir_name}/${geneid}_$gene_chr.vg") == 65280 or die "Failed to construct the sequence graph using VG.\n";
	system("vg view ${dir_name}/${geneid}_$gene_chr.vg --threads $thread > ${dir_name}/${geneid}_$gene_chr.gfa") == 65280 or die "Failed to output the GFA file using VG.\n";
        system("odgi build -g ${dir_name}/${geneid}_$gene_chr.gfa -o ${dir_name}/${geneid}_$gene_chr.og -t $thread") == 0 or die "Failed to construct the sequence graph using ODGI.\n";

	unlink "$dir_name/$gene_chr.fa" if -e "$dir_name/$gene_chr.fa";
	unlink "$dir_name/$gene_chr.fa.fai" if -e "$dir_name/$gene_chr.fa.fai";
	unlink "$dir_name/${geneid}_$gene_chr.vg" if -e "$dir_name/${geneid}_$gene_chr.vg";
	unlink "$dir_name/${geneid}_$gene_chr.gfa" if -e "$dir_name/${geneid}_$gene_chr.gfa";	
}


sub extract_subgraph {

	my ($graph, $refname, $pos, $dir_name, $geneid, $maxd, $maxe, $thread) = @_;	

	system("odgi extract -i $graph -r $pos -d $maxd -e $maxe -o $dir_name/${geneid}_raw.og --threads $thread -P") == 0 or die "Error: Failed to extract subgraph using 'odgi extract'.\n";
        system("odgi normalize -i $dir_name/${geneid}_raw.og -o $dir_name/${geneid}_norm.og --threads $thread -P") == 0 or die "Error: Failed to compact unitigs and simplify redundant furcations using 'odgi normalize'.\n";
        system("odgi paths -i $dir_name/${geneid}_norm.og -L --threads $thread -P | grep $refname > $dir_name/${geneid}.refpath") == 0 or die "Error: Failed to interrogate reference path using 'odgi paths'.\n";
        system("odgi groom -i $dir_name/${geneid}_norm.og -R $dir_name/${geneid}.refpath -o $dir_name/${geneid}.og --threads $thread -P") == 0 or die "Error: Failed to harmonize node orientations of reference path using 'odgi groom'.\n";
        system("odgi view -i $dir_name/${geneid}.og -g > $dir_name/${geneid}.gfa") == 0 or die "Failed to output the GFA file using 'odgi view'.\n";

        unlink "$dir_name/${geneid}_raw.og" if -e "$dir_name/${geneid}_raw.og";
        unlink "$dir_name/${geneid}_norm.og" if -e "$dir_name/${geneid}_norm.og";
	unlink "$dir_name/${geneid}.refpath" if -e "$dir_name/${geneid}.refpath";


}

sub parse_graph_gfa {
	
	my ($gfa_file, $refname) = @_;

	my @nodes;
        my %node_sample;
        my %edge_pair;
        my %ref_info;
	my @node_inv;

	push(@nodes, ["0+", ""]);
	push(@nodes, ["Inf+", ""]);

	open(GFA, "<$gfa_file") or die "Could not open '$gfa_file' file.\n";
        while(<GFA>){
                chomp $_;
                my @arr = split(/\t/, $_);
                my $class = $arr[0];
                if($class eq "S"){
			push(@nodes, [$arr[1]."+", $arr[2]]);
                }elsif($class eq "P" && $arr[1] =~ /chr/){
                        my @cur_nodes = split(/,/, $arr[2]);
                        unshift(@cur_nodes, "0+");
			push(@cur_nodes, "Inf+");
                        for(my $i = 0; $i < @cur_nodes - 1; $i++){
                                my $from = $cur_nodes[$i];
                                my $to = $cur_nodes[$i + 1];
				push @node_inv, $from =~ s/-$//r if $from =~ /-$/;
				push @node_inv, $to =~ s/-$//r if $to =~ /-$/;
                                if(exists $edge_pair{"${from}_${to}"}){
                                        $edge_pair{"${from}_${to}"} += 1;
                                }else{
                                        $edge_pair{"${from}_${to}"} = 1;
                                }

                        }
                        foreach my $node (@cur_nodes){
                                if ($arr[1] =~ /^(.*?)(?=\.chr)/) {
                                        if(exists $node_sample{$node}){
                                                $node_sample{$node} .= ",$1";
                                        }else{
                                                $node_sample{$node} = $1;
                                        }
                                }
                        }
                        if($arr[1] =~ /\Q$refname\E\.(\w+):(\d+)-(\d+)/){
                                 $ref_info{chr} = $1;
                                 $ref_info{start} = $2;
                                 $ref_info{end} = $3;
                                 $ref_info{nodes} = $arr[2];
                        }

                }

        }

        close(GFA);

	$node_sample{"0+"} = "";
	$node_sample{"Inf+"} = "";

	foreach my $nodei (@node_inv){
		push(@nodes, [$nodei."-", "The reverse complement of ".$nodei."+"]);
	}

	my @edge_out;
        foreach my $key (keys %edge_pair) {
                my ($start, $end) = split /_/, $key;
                push @edge_out, [$start, $end, $edge_pair{$key}];
        }

	my @node_add_sample;
        foreach my $node (@nodes){
		push(@node_add_sample, [@$node[0], @$node[1], $node_sample{@$node[0]}]);
        }

	return (\@node_add_sample, \@edge_out, \%ref_info);

}


sub parse_variant_gfa {

	my ($gfa_file, $sample_n) = @_;

	open(GFA, "<$gfa_file") or die "Could not open '$gfa_file' file.\n";
        my @nodes;
        my @edges;
        my %edge_pair;
        my %ref_info;
        my %alt_paths;
        my @ref_nodes;
        my @ref_edge_pair;

        while(<GFA>){
                chomp($_);
                my @arr = split(/\t/, $_);
                my $class = $arr[0];
                if($class eq "S"){
			push(@nodes, [$arr[1]."+", $arr[2]]);
                }elsif($class eq "L"){
                        push(@edges, [$arr[1].$arr[2], $arr[3].$arr[4]]);
                }elsif($class eq "P"){
                        my $cur_path = $arr[1];
                        my $cur_nodes = $arr[2];
                        my @cur_node_arr = split(/,/, $cur_nodes);
                        if($cur_path =~ /^(chr\w+):(\d+)-(\d+)$/){
                                $ref_info{chr} = $1;
                                $ref_info{start} = $2;
                                $ref_info{end} = $3;
                                $ref_info{nodes} = $cur_nodes;
                                @ref_nodes = @cur_node_arr;
                        }elsif($cur_path =~ /_alt_(ID\d+-\d+)_(\d+):(\d+)-(\d+)/){
                                $alt_paths{$1}->{$2} = [@cur_node_arr];
                        }
                }

        }

	foreach my $e (@edges){
                my @e = @$e;
                $edge_pair{"$e[0]_$e[1]"} = 0;
        }

        foreach my $x (0..($#ref_nodes-1)){
                $edge_pair{"$ref_nodes[$x]_$ref_nodes[$x+1]"} = $sample_n;
                push(@ref_edge_pair, "$ref_nodes[$x]_$ref_nodes[$x+1]");
        }

	foreach my $id (sort keys %alt_paths){
        if ($id =~ /-(\d+)$/) {
                my $sample_n = $1;
                #print Dumper $alt_paths{$id};
                my @ref_node_idx;
                if($alt_paths{$id}{0} && $alt_paths{$id}{1}){
                        my @alt_node_0 = @{$alt_paths{$id}{0}};
                        my @alt_node_1 = @{$alt_paths{$id}{1}};
                        #print Dumper \@alt_node_0;
                        foreach my $node (@alt_node_0){
                                my ($idx) = grep{$ref_nodes[$_] == $node} 0..$#ref_nodes;
                                if(defined $idx){
                                        push(@ref_node_idx, $idx);
                                }
                        }
                        if(scalar(@ref_node_idx) eq scalar(@alt_node_0)){
                                if($ref_node_idx[0] > 0){
                                        unshift(@ref_node_idx, $ref_node_idx[0] - 1);
                                }
                                foreach my $i (@ref_node_idx){
                                        $edge_pair{"$ref_nodes[$i]_$ref_nodes[$i+1]"} -= $sample_n;
                                }
                        }else{

                        }
                        unshift(@alt_node_1, $ref_nodes[$ref_node_idx[0]]);
                        push(@alt_node_1, $ref_nodes[$ref_node_idx[$#ref_node_idx] + 1]);
                        foreach my $j (0..($#alt_node_1-1)){
                                $edge_pair{"$alt_node_1[$j]_$alt_node_1[$j+1]"} += $sample_n;
                        }
                         }elsif($alt_paths{$id}{0}){
                        my @alt_node_0 = @{$alt_paths{$id}{0}};
                        #print Dumper \@alt_node_0;
                        #print Dumper \@ref_nodes;
                        foreach my $node (@alt_node_0){
                                my ($idx) = grep{$ref_nodes[$_] eq $node} 0..$#ref_nodes;
                                if(defined $idx){
                                        push(@ref_node_idx, $idx);
                                }
                        }
                        #print Dumper \@ref_node_idx;
                        if(scalar(@ref_node_idx) eq scalar(@alt_node_0)){
                                if($ref_node_idx[0] > 0){
                                        unshift(@ref_node_idx, $ref_node_idx[0] - 1);
                                }
                                foreach my $i (@ref_node_idx){
                                        $edge_pair{"$ref_nodes[$i]_$ref_nodes[$i+1]"} -= $sample_n;
                                }
                        }else{

                        }
                        $edge_pair{"$ref_nodes[$ref_node_idx[0]]_$ref_nodes[$ref_node_idx[$#ref_node_idx]+1]"} += $sample_n;
			}elsif($alt_paths{$id}{1}){
                        my @alt_node_1 = @{$alt_paths{$id}{1}};
                        foreach my $e (@ref_edge_pair){
                                my @c = split(/-/, $e);
                                if(exists $edge_pair{"$c[0]_$alt_node_1[0]"} && exists $edge_pair{"$alt_node_1[$#alt_node_1]-$c[1]"}){
                                        unshift(@alt_node_1, $c[0]);
                                        push(@alt_node_1, $c[1]);
                                        $edge_pair{"$c[0]_$c[1]"} -= $sample_n;
                                }
                        }
                        foreach my $j (0..($#alt_node_1-1)){
                                $edge_pair{"$alt_node_1[$j]_$alt_node_1[$j+1]"} += $sample_n;
                        }
                }
        }

}

close(GFA);

my @edge_out;
foreach my $key (keys %edge_pair) {
    my ($start, $end) = split /_/, $key;
    push @edge_out, [$start, $end, $edge_pair{$key}];
}

	return (\@nodes, \@edge_out, \%ref_info);

}



1;

