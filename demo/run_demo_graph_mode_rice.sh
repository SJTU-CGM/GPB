#!/bin/bash

mkdir demo_rice_res
cd demo_rice_res

## Download demo data
wget https://cgm.sjtu.edu.cn/fGPB/demo/rice/chr09_mc.og
wget https://cgm.sjtu.edu.cn/fGPB/demo/rice/rice_gene_anno.gff3
wget https://cgm.sjtu.edu.cn/fGPB/demo/rice/rice_repeat_anno.bed
wget https://cgm.sjtu.edu.cn/fGPB/demo/rice/rice_demo_pheno.txt

## Visualizing a single gene
fgpb --graph chr09_mc.og --ref-name IRGSP-1.0 --gene-anno rice_gene_anno.gff3  --extra-anno rice_repeat_anno.bed --geneid LOC_Os09g28300 --out demores_rice_gene --pheno rice_demo_pheno.txt --extend 100

## Visualizing multiple genes
printf '%s\n' LOC_Os09g29820 LOC_Os09g26999 LOC_Os09g15840 > rice_demo_genelist.txt
fgpb --graph chr09_mc.og --ref-name IRGSP-1.0 --gene-anno rice_gene_anno.gff3  --extra-anno rice_repeat_anno.bed --geneid-list rice_demo_genelist.txt --out demores_rice_genelist --pheno rice_demo_pheno.txt --extend 100

## Visualizing a specific genomic region
fgpb --graph chr09_mc.og --ref-name IRGSP-1.0 --gene-anno rice_gene_anno.gff3  --extra-anno rice_repeat_anno.bed --region chr09:18669248-18673240 --out demores_rice_region --pheno rice_demo_pheno.txt

## Visualizing multiple genomic regions
printf 'chr09\t7231333\t7235878\nchr09\t17324230\t17329297\nchr09\t15385162\t15389649\n' > rice_demo_region.bed
fgpb --graph chr09_mc.og --ref-name IRGSP-1.0 --gene-anno rice_gene_anno.gff3 --extra-anno rice_repeat_anno.bed --region-list rice_demo_region.bed --out  demores_rice_regionlist --pheno rice_demo_pheno.txt


