#!/usr/bin/perl

package GPBvariant;

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use FindBin qw($Bin);
use JSON;

sub viewVariant {

	my $usage = "\nUsage: gpb viewVariant --vcf <VCF FILE> --fa <REFERENCE FASTA FILE> --gff <GFF file> --geneid <GENE ID> ...\n

Necessary input description:
   
    -i, --vcf			<file>		VCF file (.vcf)
    -r, --reffa			<file>		Reference genome sequence file (.fa)

    -f, --gff			<file>		GFF file with gene annotation
    -g, --geneid		<string>	Gene ID

Options:
    -e, --extend        	<n>             The length of upstream and downstream extension of the gene
                                	        (Default:10)

     -d,			<n>		Parameter for 'odgi extract'. 
    ---max-distance-subpaths			Maximum distance between subpaths allowed for merging them. It reduces
    						the fragmentation of unspecified paths in the input path ranges.
						(Default:30000)

    -m,				<n>		Parameter for 'odgi extract'.
    --max-merging-iterations			Maximum number of iterations in attempting to merge close subpaths. It
    						stops early if during an iteration no subpaths were merged.
						(Default:6)

    -t, --threads		<n>		Thread number
    
    -h, --help					Print usage page.

\n";


	my ($vcf, $reffa, $gff, $geneid, $help);
	my $extend = 10;
	my $thread = 1;
	my $maxd = 30000;
	my $maxe = 6;

	GetOptions(
                'vcf|i=s'		=> \$vcf,
		'reffa|r=s'		=> \$reffa,

                'gff|f=s'       	=> \$gff,
                'geneid|g=s'		=> \$geneid,

                'extend|e=i'    	=> \$extend,

		'max-distance-subpaths|d' => \$maxd,
                'max-merging-iterations|m'=> \$maxe,

                'threads|t=i'		=> \$thread,

                'help|h!'		=> \$help
        ) or die $!."\n";


	die $usage if !(defined($vcf) & defined($reffa) & defined($gff) & defined($geneid));
	die $usage if $help;

	GPButils::check_file('--vcf/-i', $vcf);
        GPButils::check_file('--reffa/-r', $reffa);
        GPButils::check_arg('--gff/-f', $gff);
        GPButils::check_arg('--geneid/-g', $geneid);

	die "Please install 'vg' first\n" if(system("command -v vg > /dev/null 2>&1") != 0);
	die "Please install 'odgi' first\n" if(system("command -v odgi > /dev/null 2>&1") != 0);
	die "Please install 'bcftools' first\n" if(system("command -v bcftools > /dev/null 2>&1") != 0);
	die "Please install 'samtools' first\n" if(system("command -v samtools > /dev/null 2>&1") != 0);

	my $dir_name = $geneid;
	mkdir $dir_name or die "Error: output directory \"$dir_name\" already exists. To avoid overwriting of existing files, we kindly request that the output directory should not exist.\n";

	system("grep $geneid $gff | awk '\$3 ~ /^(gene|mRNA|transcript|exon|CDS|three_prime_UTR|five_prime_UTR|UTR3|UTR5)\$/ {print}' > $dir_name/$geneid.gff");

	my ($gene_chr, $gene_start, $gene_end) = GPBanno::extract_gff_file($geneid, $gff, "$dir_name/$geneid.gff");

	my $region_start = $gene_start - $extend;
	$region_start = 1 if($region_start < 1);
	my $region_end = $gene_end + $extend;


	GPBgfa::build_graph($vcf, $reffa, $gene_chr, $region_start, $region_end, $dir_name, $geneid, $thread);
	my $sample_n = `grep '^#CHROM' ${dir_name}/$geneid.vcf | head -1 | awk '{print NF}'` - 9;

	my $pos = "${gene_chr}:${region_start}-${region_end}";
	my $refname = ${gene_chr};
	GPBgfa::extract_subgraph("${dir_name}/${geneid}_$gene_chr.og", $refname, $pos, $dir_name, $geneid, $maxd, $maxe, $thread);	
	unlink "$dir_name/${geneid}_$gene_chr.og" if -e "$dir_name/${geneid}_$gene_chr.og";

	my ($nodes, $edge_out, $ref_info) = GPBgfa::parse_variant_gfa("$dir_name/${geneid}.gfa", $sample_n);

	my ($gene_info, $trans_data, $element_data) = GPBanno::get_gene_anno("$dir_name/$geneid.gff");

	mkdir "$dir_name/report";
	open(OUT, ">$dir_name/report/${geneid}.json") or die "Could not open output file.\n";
        my %out = (
                graphData => {
                        node => $nodes,
                        edge => $edge_out,
                        ref => $ref_info
                },
                geneData => $gene_info,
                transData => $trans_data,
                elementData => $element_data
        );

        #print Dumper \%out;
        my $out_json = encode_json(\%out);
        print OUT $out_json;

        close(OUT);

        open(GREPORT, ">$dir_name/report/${geneid}_report.html") or die "Could not open report file.\n";
        my $report = GPBreport::export_report("${geneid}.json");
        print GREPORT $report;
	mkdir "$dir_name/report/js";
        system "cp -r ${Bin}/src/* ${dir_name}/report/js/"; 


}

1;



