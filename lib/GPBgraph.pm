
#!/usr/bin/perl

package GPBgraph;

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use FindBin qw($Bin);
use JSON;

sub viewGraph {

	my $usage = "\nUsage: gpb viewGraph --graph <OG FILE> --refname <REFERENCE PATH NAME> --gff <GFF file> --geneid <GENE ID> ...\n

Necessary input description:
   
    -i, --graph			<file>		Variation graph in ODGI format(.og)
    -a, --refname		<string>	Reference path name

    -f, --gff			<file>		GFF file with gene annotation
    -g, --geneid		<string>	Gene ID

Options:
    -e, --extend		<n>		The length of upstream and downstream extension of the gene
    						(Default:10)

    -d, 			<n>		Parameter for 'odgi extract'. 
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



	my ($graph, $refname, $gff, $geneid, $help);
	my $extend = 10;
	my $thread = 1;
	my $maxd = 30000;
	my $maxe = 6;

	GetOptions(
		'graph|i=s'		=> \$graph,
		'refname|a=s'		=> \$refname,

		'gff|f=s'		=> \$gff,
		'geneid|g=s'		=> \$geneid,

		'extend|e=i'		=> \$extend,
	
		'max-distance-subpaths|d' => \$maxd,
		'max-merging-iterations|m'=> \$maxe,

		'threads|t=i'		=> \$thread,

		'help|h!'		=> \$help

	) or die $!."\n";


	die $usage if !(defined($graph) & defined($gff) & defined($geneid) & defined($refname));
	die $usage if $help;

	GPButils::check_file('--grpah/-i', $graph);
	GPButils::check_arg('--refname/-a', $refname);
	GPButils::check_file('--gff/-f', $gff);
	GPButils::check_arg('--geneid/-g', $geneid);
	
	die "Please install 'odgi' first\n" if(system("command -v odgi > /dev/null 2>&1") != 0);

	my $dir_name = $geneid;
	mkdir $dir_name or die "Error: output directory \"$dir_name\" already exists. To avoid overwriting of existing files, we kindly request that the output directory should not exist.\n";
	
	my ($gene_chr, $gene_start, $gene_end) = GPBanno::extract_gff_file($geneid, $gff, "$dir_name/$geneid.gff");
	
	my $region_start = $gene_start - $extend;
        $region_start = 1 if($region_start < 1);
        my $region_end = $gene_end + $extend;
	
	my $pos = "$refname.$gene_chr:$region_start-$region_end";

	GPBgfa::extract_subgraph($graph, $refname, $pos, $dir_name, $geneid, $maxd, $maxe, $thread);

	my ($node_add_sample, $edge_out, $ref_info) = GPBgfa::parse_graph_gfa("$dir_name/${geneid}.gfa", $refname);
	
	my ($gene_info, $trans_data, $element_data) = GPBanno::get_gene_anno("$dir_name/$geneid.gff");

	mkdir "$dir_name/report";
	open(OUT, ">$dir_name/report/${geneid}.json") or die "Could not open output file.\n";
	my %out = (
        	graphData => {
                	node => $node_add_sample,
                	edge => $edge_out,
                	ref => $ref_info
        	},
        	geneData => $gene_info,
        	transData => $trans_data,
        	elementData => $element_data
	);
	my $out_json = encode_json(\%out);
	print OUT $out_json;
	close(OUT);

	open(GREPORT, ">$dir_name/report/${geneid}_report.html") or die "Could not open report file.\n";
	my $report = GPBreport::export_report("${geneid}.json");
	print GREPORT $report;
	mkdir "$dir_name/report/js";
	system "cp -r ${Bin}/src/* ${dir_name}/report/";	

}


1;









