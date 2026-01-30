# GPB: Graph-based Pangenome Browser

*A novel flow-based visualization tool for pangenome graphs*

GPB is a visualization tool that employs a novel flow-based layout to clearly reveal graph topology and population frequency. It integrates the sequence graph with reference genome annotations for direct evaluation of variant impact, and can incorporate phenotypic data to explore genotype-to-phenotype associations. All features are accessible through an interactive web interface.

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
### Basic (Both graph mode and VCF mode):
* <b>Perl</b>
* <b>ODGI (v0.9 or later)</b><br>
### VCF mode:
* <b>VG (v1.60 or later)</b><br>
* <b>Samtools (v1.16 or later)</b><br>
* <b>Bcftools (v1.16 or later)</b><br>

## Installation procedures
1. You can download the GPB from Github:
```
$ git clone https://github.com/SJTU-CGM/GPB.git
```
 Alternatively, you could also obtain the tool on the [GPB](https://cgm.sjtu.edu.cn/GPB/install.html) website and uncompress the GPB toolbox package:
```
$ tar zxvf GPB-v**.tar.gz
```

2. You need to add `gpb` to `PATH` and add `lib/` to `PERL5LIB`
```
$ export PATH="/path/to/GPB:$PATH"
$ export PERL5LIB="/path/to/GPB/lib${PERL5LIB:+:$PERL5LIB}"
```

3. Finally, you can test if the GPB is installed successfully by:
```
$ gpb
```

If you could see the following content, congratulations! The XXX is successfully installed. If not, see if all the requirements are satisfied, or you may contact the authors for help.

```
Usage:
For variant data: gpb --vcf <in.vcf> --reffa <ref.fa> --gff <ref_gene.gff>  (--geneid ID | --genelist list.txt | --region chr:start-end | --regionlist list.txt) [OPTIONS]
For pangenome graph: gpb --graph <graph.og> --refname <ref_path> --gff <ref_gene.gff>  (--geneid ID | --genelist list.txt | --region chr:start-end | --regionlist list.txt) [OPTIONS]

REQUIRED ARGUMENTS
  1. Input mode (choose one group):
    --vcf               <file>          VCF file with variants (.vcf). (requires --reffa)
    --reffa             <file>          Reference genome in FASTA format (.fa). (requires --vcf)

    --graph             <file>          Variation graph in ODGI format (.og). (requires --refname)
    --refname           <string>        Name of the reference path in the graph. (requires --graph)

  2. Reference gene annotation:
    --gff               <file>          Gene annotation file in GFF format for the reference genome.

  3. Analysis range (choose one)
    --geneid            <string>        Single gene ID to analyze.
    --genelist          <file>          File containing list of gene IDs (one per line).
    --region            <string>        Single genomic region in 'chr:start-end' format (e.g. chr1:1000-2000).
    --regionlist        <file>          File containing multiple genomic regions (one per line).

OPTIONAL ARGUMENTS
    --bed               <file>          Additional reference-genome annotations besides genes in BED format
                                        (e.g. repeats, domains). 
    --pheno             <file>          Tab-delimited phenotype matrix: first column contains path identifiers 
                                        (header: 'Path'), remaining columns represent different phenotype with 
                                        corresponding names as headers.    
                                        Missing values in the file are indicated by -, NA, NaN, null, None,
                                        NULL, undefined, unknown or Unknown.

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

A listing of all parameters can be obtained with gpb --help or gpb -h.



## Quick start
### Graph-based pangenome mode
For an already constructed graph pangenome, the following parameters are required:
* Graph pangenome file (`--graph`)
* Reference genome path name (`--refname`)
* Reference genome gene annotation (`--gff`)`
* Target region (one of `--geneid`, `--genelist`, `--region`, `--regionlist`)
* Additional reference genome annotations (`--bed`, optional)

Download demo data:
```bash
# Download chr09_mc.og (9.0G)
wget https://cgm.sjtu.edu.cn/GPB/demo/rice/chr09_mc.og
# Download rice_gene_anno.gff3 (79M)
wget https://cgm.sjtu.edu.cn/GPB/demo/rice/rice_gene_anno.gff3
# Download rice_repeat_anno.bed (41M)
wget https://cgm.sjtu.edu.cn/GPB/demo/rice/rice_repeat_anno.bed
# Download rice_demo_pheno.txt (1.5K)
wget https://cgm.sjtu.edu.cn/GPB/demo/rice/rice_demo_pheno.txt
```

Visualizing a single gene (Example: *LOC_Os09g28300*):
```
gpb --graph chr09_mc.og --refname IRGSP-1.0 --gff rice_gene_anno.gff3 --bed rice_repeat_anno.bed --geneid LOC_Os09g28300 --out demores_rice_gene --pheno rice_demo_pheno.txt --extend 100
```
Visualizing multiple genes (Example: *LOC_Os09g29820*, *LOC_Os09g26999*, *LOC_Os09g15840*):
```
printf '%s\n' LOC_Os09g29820 LOC_Os09g26999 LOC_Os09g15840 > rice_demo_genelist.txt
gpb --graph chr09_mc.og --refname IRGSP-1.0 --gff rice_gene_anno.gff3 --bed rice_repeat_anno.bed --genelist rice_demo_genelist.txt --out demores_rice_genelist --pheno rice_demo_pheno.txt --extend 100
```
Visualizing a specific genomic region (Example: chr09:18669248-18673240):
```
gpb --graph chr09_mc.og --refname IRGSP-1.0 --gff rice_gene_anno.gff3 --bed rice_repeat_anno.bed --region chr09:18669248-18673240 --out demores_rice_region --pheno rice_demo_pheno.txt 
```
Visualizing multiple genomic regions (Example: chr09:7231334-7235878, chr09:17324231-17329297, chr09:15385163-15389649):
```
printf '%s\n' chr09:7231334-7235878 chr09:17324231-17329297 chr09:15385163-15389649 > rice_demo_region.list
gpb --graph chr09_mc.og --refname IRGSP-1.0 --gff rice_gene_anno.gff3 --bed rice_repeat_anno.bed --regionlist rice_demo_region.list --out demores_rice_regionlist --pheno rice_demo_pheno.txt
```

### Variant data mode
For variant data (VCF file), the following parameters are required:
* Variant data (`--vcf`)
* Reference genome sequence (`--reffa`)
* Reference genome gene annotation (`--gff`)
* Target region (one of `--geneid`, `--genelist`, `--region`, `--regionlist`)
* Additional reference genome annotations (`--bed`, optional)

Download demo data:
```bash
# Download human_demo.vcf.gz (634M)
wget https://cgm.sjtu.edu.cn/GPB/demo/human/human_demo.vcf.gz
wget https://cgm.sjtu.edu.cn/GPB/demo/human/human_demo.vcf.gz.tbi
# Download hg38.fa (3.1G)
wget http://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz
gunzip hg38.fa.gz
# Download human_gene_anno.gff3 (84M)
wget https://cgm.sjtu.edu.cn/GPB/demo/human/human_gene_anno.gff3
# Download human_repeat_anno.bed (232M)
wget https://cgm.sjtu.edu.cn/GPB/demo/human/human_repeat_anno.bed
# Download human_demo_pheno.txt (45K)
wget https://cgm.sjtu.edu.cn/GPB/demo/human/human_demo_pheno.txt
```

Visualizing a single gene (Example: *ENSG00000112695.13*):
```
gpb --vcf human_demo.vcf.gz --reffa hg38.fa --gff human_gene_anno.gff3 --bed human_repeat_anno.bed --geneid ENSG00000112695.13 --out demores_rice_gene --pheno human_demo_pheno.txt --extend 1000
```

Visualizing multiple genes (Example: *ENSG00000171611.10*, *ENSG00000164430.17*, *ENSG00000205269.6*):
```
printf '%s\n' ENSG00000171611.10 ENSG00000164430.17 ENSG00000205269.6 > human_demo_genelist.txt
gpb --vcf human_demo.vcf.gz --reffa hg38.fa --gff human_gene_anno.gff3 --bed human_repeat_anno.bed --genelist human_demo_genelist.txt --out demores_human_genelist --pheno human_demo_pheno.txt --extend 1000
```

Visualizing a specific genomic region (Example: chr6:42915066-42940195):
```
gpb --vcf human_demo.vcf.gz --reffa hg38.fa --gff human_gene_anno.gff3 --bed human_repeat_anno.bed --region chr6:42915066-42940195 --out demores_human_region --pheno human_demo_pheno.txt
```

Visualizing multiple genomic regions (Example: chr6:2884917-2912669, chr6:18385699-18470573, chr6:73393730-73453504):
```
printf '%s\n' chr6:2884917-2912669 chr6:18385699-18470573 chr6:73393730-73453504 > human_demo_region.list
gpb --vcf human_demo.vcf.gz --reffa hg38.fa --gff human_gene_anno.gff3 --bed human_repeat_anno.bed --regionlist human_demo_region.list --out demores_human_regionlist --pheno human_demo_pheno.txt
```




