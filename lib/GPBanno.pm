#!/usr/bin/perl

package GPBanno;

use strict;
use warnings;

sub extract_gff_file {
        my ($geneid, $gff, $out) = @_;
        system("grep $geneid $gff | awk '\$3 ~ /^(gene|mRNA|transcript|exon|CDS|three_prime_UTR|five_prime_UTR|UTR3|UTR5)\$/ {print}' > $out");        my $gene_count = `awk '\$3 == "gene"' "$out" | wc -l`;
        die "Error: Can not found the gene in the GFF file. Please check the gene ID and GFF file.\n" if($gene_count < 1);
        die "Error: More than one entry for the gene was found in the GFF file. Please check the gene ID and GFF file.\n" if($gene_count > 1);

        my $gene_chr = `awk '\$3 == "gene" {print \$1}' "$out"`;
        chomp($gene_chr);
        my $gene_start = `awk '\$3 == "gene" {print \$4}' "$out"`;
        chomp($gene_start);
        my $gene_end = `awk '\$3 == "gene" {print \$5}' "$out"`;
        chomp($gene_end);

        return ($gene_chr, $gene_start, $gene_end);
}


sub get_gene_anno {

        my ($gff_file) = @_;

        #my @gene_anno = `cat $dir_name/$geneid.gff`;
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
        #print Dumper \@gene_anno_sorted;

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
                }elsif($class eq "exon" || $class eq "CDS" || $class eq "three_prime_UTR" || $class eq "five_prime_UTR" || $class eq "UTR3" ||
$class eq
"UTR5"){
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




