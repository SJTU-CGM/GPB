# fGPB: Flow-based Graph Pangenome Browser

*A novel flow-based visualization tool for pangenome graphs*

fGPB is a visualization tool that employs a novel flow-based layout to clearly reveal graph topology and population frequency. It integrates the sequence graph with reference genome annotations for direct evaluation of variant impact, and can incorporate phenotypic data to explore genotype-to-phenotype associations. All features are accessible through an interactive web interface.

**Key Features:**

* **1. Flow-Based Layout Algorithm**  
  Visualizes graph structure and population frequency simultaneously.

* **2. Integrated Genome Annotation**  
  Integrates the sequence graph with reference annotations to assess variant effects on genomic features.

* **3. Phenotypic Data Visualization**  
  Enables overlay of phenotypic information for validating variant-to-phenotype links.

* **4. Interactive Web Interface**  
  Provides zooming, panning, and data inspection capabilities for interactive exploration.

## Requirements
### Basic (Both graph mode and Variant mode):
* <b>Perl</b>
* <b>ODGI</b> (v0.9 or later, https://github.com/pangenome/odgi)<br>
### Variant mode:
* <b>VG</b> (v1.60 or later, https://github.com/vgteam/vg) (bundled in `ext/bin/`)<br>
* <b>Samtools</b> (v1.16 or later, https://github.com/samtools/samtools)<br>
* <b>Bcftools</b> (v1.16 or later, https://github.com/samtools/bcftools)<br>

## Installation procedures
1. You can download the fGPB from Github:
```
git clone https://github.com/SJTU-CGM/fGPB.git
```
 Alternatively, you could also obtain the tool on the [fGPB](https://cgm.sjtu.edu.cn/fGPB/install.html) website and uncompress the fGPB toolbox package:
```
tar zxvf fGPB-v**.tar.gz
```

2. You need to add `fgpb` to `PATH` and add `lib/` to `PERL5LIB`
```
export PATH="/path/to/fGPB:$PATH"
export PERL5LIB="/path/to/fGPB/lib${PERL5LIB:+:$PERL5LIB}"
```

3. Finally, you can test if the fGPB is installed successfully by:
```
fgpb
```

If you could see the following content, congratulations! The fGPB is successfully installed. If not, see if all the requirements are satisfied, or you may contact the authors for help.

```
Usage:
Two running modes are supported:

Mode 1: Extract gene(s)/region(s) from a pangenome graph, and visualize
    fgpb --graph <graph.og> --ref-name <ref_path> (--geneid <ID> | --geneid-list <list.file> | --region <chr:start-end> | --region-list <list.bed>) [OPTIONS]

Mode 2: Build graph from variant data, extract gene(s)/region(s), and visualize
    fgpb --variant <in.vcf> --ref-fa <ref.fa> (--geneid <ID> | --geneid-list <list.file> | --region <chr:start-end> | --region-list <list.bed>) [OPTIONS]
REQUIRED ARGUMENTS
  Input mode (choose one group):
    -v, --variant       <file>          Variants in VCF format (.vcf). (requires '-r/--ref-fa')
    -r, --ref-fa        <file>          Reference genome in FASTA format (.fa). (requires '-v/--variant')

    -g, --graph         <file>          Variation graph in ODGI format (.og). (requires '-R/--ref-name')
    -R, --ref-name      <string>        Name of the reference path in the graph. (requires '-g/--graph')

  Target gene(s)/region(s):
    --geneid            <string>        Single gene ID to analyze. (requires '-a/--gene-anno')
    --geneid-list       <file>          File containing list of gene IDs (one per line). (requires '-a/--gene-anno')
    --region            <string>        Single genomic region in 'chr:start-end' format (e.g. chr1:1000-2000).
    --region-list       <file>          BED file with genomic regions (chrom<tab>start<tab>end, 0-based).

RECOMMENDED ARGUMENTS (DATA TRACKS)
    -a, --gene-anno     <file>          Gene annotation file in GFF3/GTF format for the reference genome.
    -x, --extra-anno    <file>          Additional reference-genome annotations besides genes in BED format
                                        (e.g. repeats, domains). 
    -p, --pheno         <file>          Tab-delimited phenotype matrix: first column contains path identifiers 
                                        (header: 'Path'), remaining columns represent different phenotype with 
                                        corresponding names as headers.    
                                        Missing values in the file are indicated by '-', 'NA', 'NaN', 'null', 
                                        'None', 'NULL', 'undefined', 'unknown' or 'Unknown'.

OPTIONAL ARGUMENTS
    -o, --out           <string>        Output file name.

    -e, --extend        <n>             Extend analysis region by N bp upstream and downstream of genes.
                                        Only work with --geneid or --genelist.
                                        (Default:10)

    -d,                 <n>             Parameter for 'odgi extract'.
    --max-distance-subpaths             Maximum distance between subpaths allowed for merging them. It reduces
                                        the fragmentation of unspecified paths in the input path ranges.
                                        (Default:10000)

    -m,                 <n>             Parameter for 'odgi extract'.
    --max-merging-iterations            Maximum number of iterations in attempting to merge close subpaths. It
                                        stops early if during an iteration no subpaths were merged.
                                        (Default:3)

    -t, --threads       <n>             Thread number.

    -h, --help                          Print usage page. 

```

A listing of all parameters can be obtained with fgpb --help or fgpb -h.



## Quick start
### Graph-based pangenome mode
For an already constructed graph pangenome, the following parameters are required:
* Graph pangenome file (`--graph`)
* Reference genome path name (`--ref-name`)
* Target region (one of `--geneid`, `--geneid-list`, `--region`, `--region-list`)
* Reference genome gene annotation (`--gene-anno`, optional)
* Additional reference genome annotations (`--extra-anno`, optional)

Download demo data:
```bash
# Download chr09_mc.og (9.0G)
wget https://cgm.sjtu.edu.cn/fGPB/demo/rice/chr09_mc.og
# Download rice_gene_anno.gff3 (79M)
wget https://cgm.sjtu.edu.cn/fGPB/demo/rice/rice_gene_anno.gff3
# Download rice_repeat_anno.bed (41M)
wget https://cgm.sjtu.edu.cn/fGPB/demo/rice/rice_repeat_anno.bed
# Download rice_demo_pheno.txt (1.5K)
wget https://cgm.sjtu.edu.cn/fGPB/demo/rice/rice_demo_pheno.txt
```

Visualizing a single gene (Example: *LOC_Os09g28300*):
```
fgpb --graph chr09_mc.og --ref-name IRGSP-1.0 --gene-anno rice_gene_anno.gff3  --extra-anno rice_repeat_anno.bed --geneid LOC_Os09g28300 --out demores_rice_gene --pheno rice_demo_pheno.txt --extend 100
```
Visualizing multiple genes (Example: *LOC_Os09g29820*, *LOC_Os09g26999*, *LOC_Os09g15840*):
```
printf '%s\n' LOC_Os09g29820 LOC_Os09g26999 LOC_Os09g15840 > rice_demo_genelist.txt
fgpb --graph chr09_mc.og --ref-name IRGSP-1.0 --gene-anno rice_gene_anno.gff3  --extra-anno rice_repeat_anno.bed --geneid-list rice_demo_genelist.txt --out demores_rice_genelist --pheno rice_demo_pheno.txt --extend 100
```
Visualizing a specific genomic region (Example: chr09:18669248-18673240):
```
fgpb --graph chr09_mc.og --ref-name IRGSP-1.0 --gene-anno rice_gene_anno.gff3  --extra-anno rice_repeat_anno.bed --region chr09:18669248-18673240 --out demores_rice_region --pheno rice_demo_pheno.txt
```
Visualizing multiple genomic regions (Example: chr09:7231334-7235878, chr09:17324231-17329297, chr09:15385163-15389649):
```
printf 'chr09\t7231333\t7235878\nchr09\t17324230\t17329297\nchr09\t15385162\t15389649\n' > rice_demo_region.bed
fgpb --graph chr09_mc.og --ref-name IRGSP-1.0 --gene-anno rice_gene_anno.gff3 --extra-anno rice_repeat_anno.bed --region-list rice_demo_region.bed --out  demores_rice_regionlist --pheno rice_demo_pheno.txt
```

### Variant data mode
For variant data (VCF file), the following parameters are required:
* Variant data (`--variant`)
* Reference genome sequence (`--ref-fa`)
* Target region (one of `--geneid`, `--geneid-list`, `--region`, `--region-list`)
* Reference genome gene annotation (`--gene-anno`, optional)
* Additional reference genome annotations (`--extra-anno`, optional)

Download demo data:
```bash
# Download human_demo.vcf.gz (634M)
wget https://cgm.sjtu.edu.cn/fGPB/demo/human/human_demo.vcf.gz
wget https://cgm.sjtu.edu.cn/fGPB/demo/human/human_demo.vcf.gz.tbi
# Download hg38.fa (3.1G)
wget http://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz
gunzip hg38.fa.gz
# Download human_gene_anno.gff3 (84M)
wget https://cgm.sjtu.edu.cn/fGPB/demo/human/human_gene_anno.gff3
# Download human_repeat_anno.bed (232M)
wget https://cgm.sjtu.edu.cn/fGPB/demo/human/human_repeat_anno.bed
# Download human_demo_pheno.txt (45K)
wget https://cgm.sjtu.edu.cn/fGPB/demo/human/human_demo_pheno.txt
```

Visualizing a single gene (Example: *ENSG00000112695.13*):
```
fgpb --variant human_demo.vcf.gz --ref-fa hg38.fa --gene-anno human_gene_anno.gff3 --extra-anno human_repeat_anno.bed --geneid ENSG00000112695.13 --out demores_human_gene --pheno human_demo_pheno.txt --extend 1000
```

Visualizing multiple genes (Example: *ENSG00000171611.10*, *ENSG00000164430.17*, *ENSG00000205269.6*):
```
printf '%s\n' ENSG00000171611.10 ENSG00000164430.17 ENSG00000205269.6 > human_demo_genelist.txt
fgpb --variant human_demo.vcf.gz --ref-fa hg38.fa --gene-anno human_gene_anno.gff3 --extra-anno human_repeat_anno.bed --geneid-list human_demo_genelist.txt --out demores_human_genelist --pheno human_demo_pheno.txt --extend 1000
```

Visualizing a specific genomic region (Example: chr6:42915066-42940195):
```
fgpb --variant human_demo.vcf.gz --ref-fa hg38.fa --gene-anno human_gene_anno.gff3 --extra-anno human_repeat_anno.bed --region chr6:42915066-42940195 --out demores_human_region --pheno human_demo_pheno.txt
```

Visualizing multiple genomic regions (Example: chr6:2884917-2912669, chr6:18385699-18470573, chr6:73393730-73453504):
```
printf 'chr6\t2884916\t2912669\nchr6\t18385698\t18470573\nchr6\t73393729\t73453504\n' > human_demo_region.bed
fgpb --variant human_demo.vcf.gz --ref-fa hg38.fa --gene-anno human_gene_anno.gff3  --extra-anno human_repeat_anno.bed --region-list human_demo_region.bed --out demores_human_regionlist --pheno human_demo_pheno.txt
```




