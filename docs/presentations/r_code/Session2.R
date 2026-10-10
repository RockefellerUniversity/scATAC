suppressPackageStartupMessages(require(knitr))
knitr::opts_chunk$set(echo = TRUE, tidy = T)

library(Signac)
library(Seurat)


# # read in h5 file
# library(Signac)
# library(Seurat)
# 
# counts <- Read10X_h5(filename = "~/Desktop/ATAC.data.500.cell/atac_pbmc_500_nextgem_filtered_peak_bc_matrix.h5")
# 
# std_chr   <- paste0("chr", c(1:22, "X", "Y"))
# peak_chr  <- as.character(seqnames(StringToGRanges(rownames(counts), sep = c(":", "-"))))
# counts    <- counts[peak_chr %in% std_chr, ]
# 
# metadata <- read.csv(
#   file = "~/Desktop/ATAC.data.500.cell/atac_pbmc_500_nextgem_singlecell.csv",
#   header = TRUE,
#   row.names = 1
# )
# 
# chrom_assay <- CreateChromatinAssay(
#   counts = counts,
#   sep = c(":", "-"),
#   fragments = "~/Desktop/ATAC.data.500.cell/atac_pbmc_500_nextgem_fragments.tsv.gz",
#   min.cells = 10,
#   min.features = 200
# )
# 
# pbmc <- CreateSeuratObject(
#   counts = chrom_assay,
#   assay = "peaks",
#   meta.data = metadata
# )

pbmc <- readRDS("data/pbmc_start.rds")





library(AnnotationHub)
ah <- AnnotationHub()

query(ah, "EnsDb.Hsapiens.v98")
ensdb_v98 <- ah[["AH75011"]]

annotations <- GetGRangesFromEnsDb(ensdb = ensdb_v98)

head(annotations)


seqlevels(annotations) <- paste0('chr', seqlevels(annotations))
genome(annotations) <- "hg38"

Annotation(pbmc) <- annotations


pbmc <- TSSEnrichment(object = pbmc)

VlnPlot(object = pbmc,
  features = c('TSS.enrichment'))


pbmc <- TSSEnrichment(object = pbmc, fast = F)

TSSPlot(pbmc)



pbmc$TSSE.group <- ifelse(pbmc$TSS.enrichment > 4, "High", "Low")

TSSPlot(pbmc, 
        group.by = "TSSE.group")

pbmc <- NucleosomeSignal(object = pbmc)

VlnPlot(pbmc, features = "nucleosome_signal")

FragmentHistogram(
  object = pbmc
)

pbmc$nucleosome_group <- ifelse(pbmc$nucleosome_signal > 2,
                                 "NS > 2", "NS < 2")
FragmentHistogram(
  object   = pbmc,
  group.by = "nucleosome_group"
)

pbmc$pct_reads_in_peaks <- pbmc$peak_region_fragments /
                            pbmc$passed_filters * 100

VlnPlot(pbmc, features = "pct_reads_in_peaks")

Signac::blacklist_hg38

pbmc$excl_prop <- FractionCountsInRegion(
  object = pbmc,
  assay = 'peaks',
  regions = blacklist_hg38
)

VlnPlot(pbmc, features = "excl_prop")


library(scDblFinder)
library(SingleCellExperiment)
library(GenomicRanges)

sce <- as.SingleCellExperiment(pbmc, assay = "peaks")

set.seed(42)  
sce <- scDblFinder(
  sce,
  aggregateFeatures = TRUE,
  nfeatures         = 25,
  processing        = "normFeatures",
  dbr               = NULL          
)



frag_path <- GetFragmentData(Fragments(pbmc)[[1]], slot = "path")



library(AnnotationHub)
ah <- AnnotationHub()

rm_q <- query(ah, c("RepeatMasker", "hg38"))
mcols(rm_q)[, c("title", "rdataclass", "sourceurl")]
rmsk <- rm_q[[which(rm_q$rdataclass == "GRanges")[1]]]


plain <- function(gr) GRanges(as.character(seqnames(gr)), ranges(gr))

excl <- reduce(c(
  GRanges(c("chrM", "chrX", "chrY"), IRanges(1L, width = seqlengths(Annotation(pbmc))["chrX"])),
  plain(blacklist_hg38_unified),
  plain(rmsk)
))


amu <- amulet(
  frag_path,
  barcodes         = colnames(pbmc),
  regionsToExclude = excl
)

amu <- amu[colnames(pbmc), ]

pbmc$amulet.nAbove2 <- amu$nAbove2
pbmc$amulet.q <- amu$q.value
pbmc$amulet.class <- ifelse(amu$q.value<0.01, "Doublet", "Singlet")

pbmc$scDblFinder.score <- sce$scDblFinder.score
pbmc$scDblFinder.class <- sce$scDblFinder.class


table(scDblFinder = pbmc$scDblFinder.class,
      amulet      = pbmc$amulet.class)

VlnPlot(pbmc, features = "nCount_peaks",
        group.by = "amulet.class", pt.size = 0.1)


VlnPlot(pbmc, features = "amulet.nAbove2",
  group.by = "amulet.class", pt.size = 0.1, log =T)



VlnPlot(pbmc, features = "nCount_peaks",
        group.by = "scDblFinder.class", pt.size = 0.1)

library(ggplot2)
VlnPlot(
  object   = pbmc,
  features = c(
    "nCount_peaks",
    "TSS.enrichment",
    "excl_prop",
    "nucleosome_signal",
    "pct_reads_in_peaks"
  ),
  pt.size = 0.1,
  ncol    = 5
) & theme(plot.title = element_text(size = 8))

DensityScatter(
  object     = pbmc,
  x          = "nCount_peaks",
  y          = "TSS.enrichment",
  log_x      = TRUE,
  quantiles  = TRUE
)

DensityScatter(
  object     = pbmc,
  x          = "nCount_peaks",
  y          = "pct_reads_in_peaks",
  log_x      = TRUE,
  quantiles  = TRUE
)

pbmc


pbmc <- subset(
  x      = pbmc,
  subset = nCount_peaks > 5000 &
           nCount_peaks < 60000 &
           TSS.enrichment > 4 &
           nucleosome_signal < 2 &
           pct_reads_in_peaks > 40
)

pbmc


# ATACqc(pbmc)
# 

pbmc <- RunTFIDF(pbmc)

pbmc[["peaks"]]@data[1:5, 1:5]

pbmc <- FindTopFeatures(pbmc, min.cutoff = "q5")

length(VariableFeatures(pbmc))

head(VariableFeatures(pbmc))

peak_counts <- rowSums(GetAssayData(pbmc, assay = "peaks", layer = "counts"))
quantile(peak_counts, c(0.05, 0.25, 0.5, 0.75))
hist(log10(peak_counts), breaks = 50, main = "Total counts per peak")
abline(v = log10(22), col = "red", linetype = "dashed", lwd = 2)


# saveRDS(pbmc,"~/Desktop/ATAC.data.500.cell/pbmc_filtered_tfidf.rds")
