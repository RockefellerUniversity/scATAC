# options(timeout = 600)
# download.file(
#   url      = "https://www.dropbox.com/scl/fi/a6dcb7ipvh1epzswtq9t1/pbmc_annotated.rds?rlkey=33f90hbganthzp5yi3r196z72&st=c4giu9vl&dl=1",
#   destfile = "data/pbmc_annotated.rds",
#   mode     = "wb"
# )

library(Signac)
library(Seurat)

pbmc <- readRDS("data/pbmc_annotated.rds")

DefaultAssay(pbmc) <- "peaks"

Idents(pbmc) <- "predicted.id"



da_peaks <- FindMarkers(
  object      = pbmc,
  ident.1     = "CD14+ Monocytes",
  only.pos    = TRUE,         # look for positive markers
  test.use    = "LR",         # logistic regression
  latent.vars = "nCount_peaks" # control for depth
)

head(da_peaks)

significant_peaks <- subset(da_peaks,
                              p_val_adj < 0.05 & avg_log2FC > 0.5)

closest <- ClosestFeature(pbmc, regions = rownames(significant_peaks))

head(closest[, c("gene_name", "distance", "query_region")])

DefaultAssay(pbmc) <- "peaks"

CoveragePlot(
  object           = pbmc,
  region           = "FAM174B",
  expression.assay = "RNA",
  extend.upstream   = 500,
  extend.downstream = 10000
)


top_peak <- closest$query_region[closest$gene_name == "TRPV4"][1]

CoveragePlot(
  object            = pbmc,
  region            = top_peak,
  extend.upstream   = 1000,
  extend.downstream = 1000
)

CoveragePlot(
  object           = pbmc,
  region           = "IL1B",
  expression.assay = "RNA",
  extend.upstream   = 500,
  extend.downstream = 10000
)

all_markers <- FindAllMarkers(
  object      = pbmc,
  only.pos    = TRUE,
  test.use    = "LR",
  latent.vars = "nCount_peaks"
)



head(all_markers)

library(dplyr)
top2 <- all_markers |>
  group_by(cluster) |>
  slice_max(order_by = avg_log2FC, n = 2)

head(top2)

library(ggplot2)
DotPlot(pbmc,top2$gene)+
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8 ))


# options(timeout = 600)
# download.file(
#   url      = "https://www.dropbox.com/scl/fi/qavpfxt969y4j9fl9e4x9/pbmc_integrated.rds?rlkey=bwwxg3s55a31o2o15yp1gx73g&st=25qa5j3z&dl=1",
#   destfile = "data/pbmc_integrated.rds",
#   mode     = "wb"
# )



# celltype_map <- c(
#   # Multiome (seurat_annotations)
#   "CD14 Mono"      = "CD14+ Monocytes",
#   "CD16 Mono"      = "CD16+ Monocytes",
#   "CD4 Naive"      = "CD4 Naive",
#   "CD4 TCM"        = "CD4 Memory",
#   "CD4 TEM"        = "CD4 Memory",
#   "Treg"           = "CD4 Memory",
#   "CD8 Naive"      = "CD8 Naive",
#   "CD8 TEM_1"      = "CD8 effector",
#   "CD8 TEM_2"      = "CD8 effector",
#   "NK"             = "NK",
#   "Naive B"        = "B",
#   "Intermediate B" = "B",
#   "Memory B"       = "B",
#   "cDC"            = "Dendritic cell",
#   "pDC"            = "pDC",
#   "gdT"            = "Other T",
#   "MAIT"           = "Other T",
#   "HSPC"           = NA,
#   "Plasma"         = NA,
#   # PBMC 500 (predicted.id from the 10k reference)
#   "CD14+ Monocytes"        = "CD14+ Monocytes",
#   "CD16+ Monocytes"        = "CD16+ Monocytes",
#   "CD4 Memory"             = "CD4 Memory",
#   "CD8 effector"           = "CD8 effector",
#   "NK dim"                 = "NK",
#   "NK bright"              = "NK",
#   "pre-B cell"             = "B",
#   "B cell progenitor"      = "B",
#   "Dendritic cell"         = "Dendritic cell",
#   "Double negative T cell" = "Other T",
#   "Platelet"               = NA
# )
# 
# multi$celltype <- unname(celltype_map[multi$seurat_annotations])
# pbmc$celltype  <- unname(celltype_map[pbmc$predicted.id])

# peaks_500   <- read.table("data/atac_pbmc_500_nextgem_peaks.bed",
#                           col.names = c("chr", "start", "end"))
# peaks_500   <- makeGRangesFromDataFrame(peaks_500)
# peaks_multi <- granges(multi[["peaks"]])
# 
# combined_peaks <- reduce(c(peaks_500, peaks_multi))
# combined_peaks <- combined_peaks[width(combined_peaks) > 20 &
#                                  width(combined_peaks) < 10000]

# # PBMC 500
# counts_500 <- FeatureMatrix(
#   fragments = Fragments(pbmc),
#   features  = combined_peaks,
#   cells     = colnames(pbmc)
# )
# 
# obj_500 <- CreateSeuratObject(
#   counts    = CreateChromatinAssay(counts     = counts_500,
#                                    fragments  = Fragments(pbmc),
#                                    annotation = Annotation(pbmc)),
#   assay     = "peaks",
#   meta.data = pbmc[[]]
# )
# 
# # PBMC Multiome
# counts_multi <- FeatureMatrix(
#   fragments = Fragments(multi),
#   features  = combined_peaks,
#   cells     = colnames(multi)
# )
# 
# obj_multi <- CreateSeuratObject(
#   counts    = CreateChromatinAssay(counts     = counts_multi,
#                                    fragments  = Fragments(multi),
#                                    annotation = Annotation(pbmc)),
#   assay     = "peaks",
#   meta.data = multi[[]]
# )

# combined <- merge(obj_500, y = obj_multi,
#                   add.cell.ids = c("pbmc500", "multiome"))
# 
# combined <- RunTFIDF(combined)
# combined <- FindTopFeatures(combined, min.cutoff = 10)
# combined <- RunSVD(combined, seed.use = 42)
# combined <- RunUMAP(combined, reduction = "lsi", dims = 2:30, seed.use = 42,
#                     reduction.name = "umap_unintegrated")

pbmc_int <- readRDS("data/pbmc_integrated.rds")
pbmc_int
table(pbmc_int$celltype, pbmc_int$sample)



DimPlot(pbmc_int, reduction = "umap_unintegrated",
        group.by = c("sample", "celltype"), label = TRUE, repel = TRUE)

VlnPlot(pbmc_int, "TSS.enrichment", split.by = "sample")


# obj_list <- SplitObject(combined, split.by = "sample")
# obj_list <- lapply(obj_list, function(x) {
#   x <- FindTopFeatures(x, min.cutoff = 10)
#   x <- RunTFIDF(x)
#   RunSVD(x, seed.use = 42)
# })
# 
# anchors <- FindIntegrationAnchors(
#   object.list     = obj_list,
#   anchor.features = rownames(combined),
#   reduction       = "rlsi",
#   dims            = 2:30
# )
# 
# combined <- IntegrateEmbeddings(
#   anchorset          = anchors,
#   reductions         = combined[["lsi"]],
#   new.reduction.name = "integrated_lsi",
#   dims.to.integrate  = 1:30
# )
# 
# combined <- RunUMAP(combined, reduction = "integrated_lsi",
#                     dims = 2:30, seed.use = 42)

DimPlot(pbmc_int, reduction = "umap",
        group.by = c("sample", "celltype"), label = TRUE, repel = TRUE)

library(DESeq2)

bulk <- AggregateExpression(
  pbmc_int,
  assays       = "peaks",
  return.seurat = FALSE,
  group.by     = c("celltype","sample")
)

counts_bulk <- bulk$peaks
head(counts_bulk)

parts <- do.call(rbind, strsplit(colnames(counts_bulk), "_"))

col_data <- data.frame(
  celltype  = parts[, 1],
  sample    = parts[, 2],
  row.names = colnames(counts_bulk)
)

# How many cells went into each pseudobulk. AggregateExpression turns "_"
# inside a value into "-", so match that when building the group names.
pb_group <- paste(pbmc_int$celltype, gsub("_", "-", pbmc_int$sample), sep = "_")
col_data$n_cells <- as.vector(table(pb_group)[rownames(col_data)])
col_data

# Pseudobulks summed from only a few cells are mostly noise, and DESeq2 shares
# its variance estimates across all columns, so drop them before fitting
keep_cols   <- col_data$n_cells >= 10
counts_keep <- counts_bulk[, keep_cols]
col_keep    <- col_data[keep_cols, ]

dds <- DESeqDataSetFromMatrix(
  countData = counts_keep,
  colData   = col_keep,
  design    = ~ sample + celltype   # sample is the replicate/blocking factor
)
dds <- DESeq(dds)

res_deseq <- results(dds, contrast = c("celltype", "CD14+ Monocytes", "B"))
summary(res_deseq, alpha = 0.05)


Idents(pbmc_int) <- "celltype"
res_fm <- FindMarkers(pbmc_int, ident.1 = "CD14+ Monocytes", ident.2 = "B")




pb_sig <- rownames(res_deseq)[which(res_deseq$padj < 0.05)]
fm_sig <- rownames(res_fm)[res_fm$p_val_adj < 0.05]

data.frame(
  approach    = c("Pseudobulk (DESeq2)", "FindMarkers (per cell)"),
  significant = c(length(pb_sig), length(fm_sig)),
  in_both     = length(intersect(pb_sig, fm_sig)),
  # typical strength of evidence among the peaks each approach calls
  median_padj_significant = c(median(res_deseq[pb_sig, "padj"]),
                              median(res_fm[fm_sig, "p_val_adj"])),
  min_padj = c(min(res_deseq[pb_sig, "padj"]),
                              min(res_fm[fm_sig, "p_val_adj"]))
)

CoveragePlot(
  object            = pbmc_int,
  region            = "chr6-106702055-106703095",
  group.by          = "celltype",
  split.by          = "sample",
  idents            = c("CD14+ Monocytes", "B"),
  extend.upstream   = 2000,
  extend.downstream = 2000
)

CoveragePlot(
  object            = pbmc_int,
  region            = "chr6-41934567-41943790",
  group.by          = "celltype",
  split.by          = "sample",
  idents            = c("CD14+ Monocytes", "B"),
  extend.upstream   = 2000,
  extend.downstream = 2000
)
