#!/bin/bash

mkdir demo_human_res
cd demo_human_res

## Download demo data
wget http://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz
gunzip hg38.fa.gz

wget https://cgm.sjtu.edu.cn/GPB/demo/human/human_demo.vcf.gz
wget https://cgm.sjtu.edu.cn/GPB/demo/human/human_demo.vcf.gz.tbi
wget https://cgm.sjtu.edu.cn/GPB/demo/human/human_gene_anno.gff3
wget https://cgm.sjtu.edu.cn/GPB/demo/human/human_repeat_anno.bed
wget https://cgm.sjtu.edu.cn/GPB/demo/human/human_demo_pheno.txt

## Visualizing a single gene
gpb --vcf human_demo.vcf.gz --reffa hg38.fa --gff human_gene_anno.gff3 --bed human_repeat_anno.bed --geneid ENSG00000112695.13 --out demores_human_gene --pheno human_demo_pheno.txt --extend 1000

## Visualizing multiple genes
printf '%s\n' ENSG00000171611.10 ENSG00000164430.17 ENSG00000205269.6 > human_demo_genelist.txt
gpb --vcf human_demo.vcf.gz --reffa hg38.fa --gff human_gene_anno.gff3 --bed human_repeat_anno.bed --genelist human_demo_genelist.txt --out demores_human_genelist --pheno human_demo_pheno.txt --extend 1000

## Visualizing a specific genomic region
gpb --vcf human_demo.vcf.gz --reffa hg38.fa --gff human_gene_anno.gff3 --bed human_repeat_anno.bed --region chr6:42915066-42940195 --out demores_human_region --pheno human_demo_pheno.txt

## Visualizing multiple genomic regions
printf '%s\n' chr6:2884917-2912669 chr6:18385699-18470573  chr6:73393730-73453504 > human_demo_region.list
gpb --vcf human_demo.vcf.gz --reffa hg38.fa --gff human_gene_anno.gff3  --bed human_repeat_anno.bed --regionlist human_demo_region.list --out  demores_human_regionlist --pheno human_demo_pheno.txt



