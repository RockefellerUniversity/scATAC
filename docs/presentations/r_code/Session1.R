# setwd("/PathToMyDownload/RU_Course_template/docs")
# # e.g. setwd("~/Downloads/Intro_To_R_1Day/r_course")

## wget https://cf.10xgenomics.com/samples/cell-atac/2.0.0/atac_pbmc_500_nextgem/atac_pbmc_500_nextgem_fastqs.tar

## tar -xvf atac_pbmc_500_nextgem_fastqs.tar

## wget -O cellranger-atac-2.2.0.tar.gz "https://cf.10xgenomics.com/releases/cell-atac/cellranger-atac-2.2.0.tar.gz?Expires=1790236407&Key-Pair-Id=APKAI7S6A5RYOXBWRPDA&Signature=KD5CNhBTKkkdwbdJkXjVmf-ybpjwUJ8~MsVSCf2dL~cW7j8LGc0PMWz6arvTTzNq0u5ZBMzqI02L3KBS6-pImXFwegQ8VxN4RPGVCY-V1UvWD~NqYEFsdBcCM~EeJKbd9sGOlTklk7xQ9XdP0tHZnBLpixC3BjqH~ymDcZZSc6RqBWy3kCQ7uzGWi-PQPKEYLbPS4Pd-enmFbgPplDYjHPmmpa5S7nCegzlfYBnYOnYN8iahjsTkOxrYv~KWf4g9uKVU-Z~lW-gx7mt2RIHfVfTy9zLnmdb~AC-xtryUH6jyPvN7nxpaQw3FchRaXtIZVNm59UfPfIstIRrgcDqhBw__"

## wget "https://cf.10xgenomics.com/supp/cell-arc/refdata-cellranger-arc-GRCh38-2024-A.tar.gz"

## tar -xzvf cellranger-atac-2.2.0.tar.gz
## tar -xzvf refdata-cellranger-arc-GRCm39-2024-A.tar.gz

## export PATH=/PATH_TO_CELLRANGER_DIRECTORY/cellranger-atac-2.2.0:$PATH

## cellranger-atac count --id=pbmc_500 \
##    --sample atac_pbmc_500_nextgem \
##    --fastqs=PATH_TO_FASTQ_DIRECTORY \
##    --reference=/PATH_TO_CELLRANGER_DIRECTORY/refdata-cellranger-arc-GRCh38-2024-A.tar.gz

## cellranger mkgtf Homo_sapiens.GRCh38.ensembl.gtf \
## Homo_sapiens.GRCh38.ensembl.filtered.gtf \
##                    --attribute=gene_biotype:protein_coding \
##                    --attribute=gene_biotype:lncRNA \
##                    --attribute=gene_biotype:antisense \
##                    --attribute=gene_biotype:IG_LV_gene \
##                    --attribute=gene_biotype:IG_V_gene \
##                    --attribute=gene_biotype:IG_V_pseudogene \
##                    --attribute=gene_biotype:IG_D_gene \
##                    --attribute=gene_biotype:IG_J_gene \
##                    --attribute=gene_biotype:IG_J_pseudogene \
##                    --attribute=gene_biotype:IG_C_gene \
##                    --attribute=gene_biotype:IG_C_pseudogene \
##                    --attribute=gene_biotype:TR_V_gene \
##                    --attribute=gene_biotype:TR_V_pseudogene \
##                    --attribute=gene_biotype:TR_D_gene \
##                    --attribute=gene_biotype:TR_J_gene \
##                    --attribute=gene_biotype:TR_J_pseudogene \
##                    --attribute=gene_biotype:TR_C_gene

## {
##   organism: "human"
##   genome: ["GRCh38"]
##   input_fasta: ["/path/to/GRCh38/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz"]
##   input_gtf: ["/path/to/Homo_sapiens.GRCh38.ensembl.filtered.gtf"]
##   non_nuclear_contigs: ["chrM"]
##   input_motifs: "/path/to/jaspar/motifs.pfm"
## }
## 

## 
## cellranger-atac mkref --config=/path/to/references/custom_GRCh38.config
## 

library(Signac)
library(Seurat)


metadata <- read.csv(
  file = "data/pbmc500_singlecell.csv",
  header = TRUE,
  row.names = 1
)
metadata[1:3, ]


counts <- Read10X_h5(filename = "data/pbmc500_filtered_peak_bc_matrix.h5")
std_chr   <- paste0("chr", c(1:22, "X", "Y"))
peak_chr  <- as.character(seqnames(StringToGRanges(rownames(counts), sep = c(":", "-"))))
counts    <- counts[peak_chr %in% std_chr, ]
counts[1:5, 1:3]

pbmc <- readRDS("data/pbmc_start.rds")

# # NOTE: need signac v1.16 to correctly read this in
# 
# chrom_assay <- CreateChromatinAssay(
#   counts = counts,
#   sep = c(":", "-"),
#   fragments = "data/pbmc500_fragments.tsv.gz",
#   min.cells = 10,
#   min.features = 200
# )
# 
# class(chrom_assay)

class(pbmc@assays$peaks)

# pbmc <- CreateSeuratObject(
#   counts = chrom_assay,
#   assay = "peaks",
#   meta.data = metadata
# )
# 
# pbmc

pbmc

# frags <- Fragments(pbmc)
# frags_updated <- UpdatePath(
#   frags[[1]],
#   new.path = "~/Downloads/pbmc500_fragments.tsv.gz"
# )
# Fragments(pbmc) <- NULL
# Fragments(pbmc) <- frags_updated

# frags_updated_bad <- UpdatePath(
#   frags[[1]],
#   new.path = "~/Downloads/atac_pbmc_500_nextgem_fragments.tsv.gz"
# )
