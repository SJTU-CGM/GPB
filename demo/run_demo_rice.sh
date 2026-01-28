#!/bin/bash

mkdir demo_rice_res
cd demo_rice_res

## Download demo data
wget https://cgm.sjtu.edu.cn/GPB/demo/rice/chr09_mc.og
wget https://cgm.sjtu.edu.cn/GPB/demo/rice/rice_gene_anno.gff3
wget https://cgm.sjtu.edu.cn/GPB/demo/rice/rice_repeat_anno.bed
wget https://cgm.sjtu.edu.cn/GPB/demo/rice/rice_demo_pheno.txt

## Visualizing a single gene
gpb --graph chr09_mc.og --refname IRGSP-1.0 --gff rice_gene_anno.gff3  --bed rice_repeat_anno.bed --geneid LOC_Os09g28300 --out demores_rice_gene --pheno rice_demo_pheno.txt --extend 100

## Visualizing multiple genes
printf '%s\n' LOC_Os09g29820 LOC_Os09g26999 LOC_Os09g15840 > rice_demo_genelist.txt
gpb --graph chr09_mc.og --refname IRGSP-1.0 --gff rice_gene_anno.gff3  --bed rice_repeat_anno.bed --genelist rice_demo_genelist.txt --out demores_rice_genelist --pheno rice_demo_pheno.txt --extend 100

## Visualizing a specific genomic region
gpb --graph chr09_mc.og --refname IRGSP-1.0 --gff rice_gene_anno.gff3  --bed rice_repeat_anno.bed --region chr09:18669248-18673240 --out demores_rice_region --pheno rice_demo_pheno.txt

## Visualizing multiple genomic regions
printf '%s\n' chr09:7231334-7235878  chr09:17324231-17329297 chr09:15385163-15389649 > rice_demo_region.list
gpb --graph chr09_mc.og --refname IRGSP-1.0 --gff rice_gene_anno.gff3  --bed rice_repeat_anno.bed --regionlist rice_demo_region.list --out  demores_rice_regionlist --pheno rice_demo_pheno.txt


