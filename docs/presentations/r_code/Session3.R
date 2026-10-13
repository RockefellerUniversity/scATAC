library(Signac)
library(Seurat)
library(ggplot2)

pbmc <- readRDS("data/pbmc_filtered_tfidf.rds")

pbmc <- RunSVD(pbmc)

pbmc[["lsi"]]




# DepthCor(pbmc)

DepthCor(pbmc)

pbmc <- RunUMAP(
  object    = pbmc,
  reduction = "lsi",
  dims      = 2:30,
  seed.use  = 42
)

DimPlot(object = pbmc, label = TRUE) + NoLegend()

pbmc2 <- RunUMAP(
  object    = pbmc,
  reduction = "lsi",
  dims      = 1:30,
  seed.use  = 42
)

FeaturePlot(pbmc2, features = "nCount_peaks", max.cutoff = "q95")

pbmc <- FindNeighbors(
  object    = pbmc,
  reduction = "lsi",
  dims      = 2:30
)

pbmc <- FindClusters(
  object    = pbmc,
  verbose   = FALSE,
  algorithm = 3,
  random.seed = 42
)

DimPlot(object = pbmc, label = TRUE) + NoLegend()

pbmc <- FindClusters(pbmc, resolution = 0.5)   # coarser
pbmc <- FindClusters(pbmc, resolution = 2.0)   # finer

p1 <- DimPlot(pbmc, group.by = "peaks_snn_res.0.5", label = TRUE) +
      ggtitle("Resolution 0.5") + NoLegend()
p2 <- DimPlot(pbmc, group.by = "peaks_snn_res.2",   label = TRUE) +
      ggtitle("Resolution 2.0") + NoLegend()


p1 + p2

FeaturePlot(
  object     = pbmc,
  features   = c("nCount_peaks",
    "TSS.enrichment",
    "excl_prop",
    "nucleosome_signal"),
  ncol       = 2,
  max.cutoff = "q95",
  pt.size = 0.2
)

FeaturePlot(
  object     = pbmc,
  features   = c(
    "pct_reads_in_peaks",
    "amulet.q",
    "scDblFinder.score"),
  ncol       = 2,
  max.cutoff = "q95",
  pt.size = 0.2
)

VlnPlot(
  object     = pbmc,
  features   = c("nCount_peaks",
    "TSS.enrichment",
    "excl_prop",
    "nucleosome_signal",
    "pct_reads_in_peaks",
    "scDblFinder.score",
    "amulet.q"),
  split.by = "peaks_snn_res.2",
  ncol       = 3
)

# library(Herper)
# 
# install_CondaTools("macs","peak.calling", pathToMiniConda = "~/Documents/mini")
# 

# peaks <- CallPeaks(
#   object                = pbmc,
#   group.by              = "seurat_clusters",
#   macs2.path            = "~/Documents/mini/env/peak.calling/macs3",
#   effective.genome.size = 2.7e9,
#   combine.peaks         = TRUE
# )

# peaks <- keepStandardChromosomes(peaks, pruning.mode = "coarse")
# peaks <- subsetByOverlaps(peaks, blacklist_hg38_unified, invert = TRUE)

# head(peaks$peak_called_in)

# combined_peaks <- reduce(c(peaks_sample1, peaks_sample2))
# 
# peak_widths    <- width(combined_peaks)
# combined_peaks <- combined_peaks[peak_widths > 20 & peak_widths < 10000]

# macs_counts <- FeatureMatrix(
#   fragments = Fragments(pbmc),
#   features  = peaks,
#   cells     = colnames(pbmc)
# )
# 
# pbmc[["macs_peaks"]] <- CreateChromatinAssay(
#   counts     = macs_counts,
#   fragments  = Fragments(pbmc),
#   annotation = Annotation(pbmc)
# )

# DefaultAssay(pbmc) <- "macs_peaks"
# 
# pbmc <- RunTFIDF(pbmc)
# pbmc <- FindTopFeatures(pbmc, min.cutoff = "q5")
# pbmc <- RunSVD(pbmc)
# pbmc <- RunUMAP(pbmc, reduction = "lsi", dims = 2:30, seed.use = 42)

gene.activities <- GeneActivity(pbmc)

pbmc[["RNA"]] <- CreateAssayObject(counts = gene.activities)

pbmc <- NormalizeData(
  object             = pbmc,
  assay              = "RNA",
  normalization.method = "LogNormalize",
  scale.factor       = median(pbmc$nCount_RNA)
)

DefaultAssay(pbmc) <- "RNA"

# FeaturePlot(
#   object     = pbmc,
#   features   = c(
#     "MS4A1",   # B cells
#     "CD3D",    # T cells
#     "LEF1",    # naive T cells
#     "NKG7",    # NK cells
#     "TREM1",   # monocytes
#     "LYZ"      # monocytes/DCs
#   ),
#   pt.size    = 0.1,
#   max.cutoff = "q95",
#   ncol       = 3
# )

FeaturePlot(
  object     = pbmc,
  features   = c(
    "MS4A1",   # B cells
    "CD3D",    # T cells
    "LEF1",    # naive T cells
    "NKG7",    # NK cells
    "TREM1",   # monocytes
    "LYZ"      # monocytes/DCs
  ),
  pt.size    = 0.1,
  max.cutoff = "q95",
  ncol       = 3
)

# options(timeout = 600)  # the default 60s is too short for a ~170 MB file
# download.file(
#   url      = "https://signac-objects.s3.amazonaws.com/pbmc_10k_v3.rds",
#   destfile = "data/pbmc_10k_rna.rds",
#   mode     = "wb"
# )


pbmc_rna <- readRDS("data/pbmc_10k_rna.rds")
pbmc_rna <- UpdateSeuratObject(pbmc_rna)

DefaultAssay(pbmc) <- "RNA"

transfer.anchors <- FindTransferAnchors(
  reference       = pbmc_rna,
  query           = pbmc,
  features        = VariableFeatures(object = pbmc_rna),
  reference.assay = "RNA",
  query.assay     = "RNA",
  reduction       = "cca" 
)

celltype.predictions <- TransferData(
  anchorset       = transfer.anchors,
  refdata         = pbmc_rna$celltype,
  weight.reduction = pbmc[["lsi"]],
  dims            = 2:30
)

pbmc <- AddMetaData(pbmc, metadata = celltype.predictions)

DimPlot(
  object   = pbmc,
  group.by = "predicted.id",
  label    = TRUE,
  repel    = TRUE
) + NoLegend()

hist(pbmc$prediction.score.max,
     breaks = 50,
     xlab   = "Max prediction score",
     main   = "Label transfer confidence")

pbmc$low_confidence <- pbmc$prediction.score.max < 0.5
table(pbmc$low_confidence)

DimPlot(
  object   = pbmc,
  group.by = "low_confidence",
  label    = TRUE,
  repel    = TRUE
) + NoLegend()

# DefaultAssay(pbmc) <- "RNA"
# t_cells <- subset(pbmc, predicted.id %in% c("CD4 Naive", "CD4 Memory", "CD8 Naive", "CD8 effector"))
# 
# DotPlot(
#   object   = t_cells,
#   assay    = "RNA",
#   features = c("CD8A", "CD8B", "BACH2", "TCF7", "LEF1", "CD44", "NKG7", "GZMB", "CCL5"),
#   group.by = "predicted.id"
# ) + RotatedAxis()
# 

DefaultAssay(pbmc) <- "RNA"
t_cells <- subset(pbmc, predicted.id %in% c("CD4 Naive", "CD4 Memory", "CD8 Naive", "CD8 effector"))

DotPlot(
  object   = t_cells,
  assay    = "RNA",
  features = c("CD8A", "CD8B", "BACH2", "TCF7", "LEF1", "CD44", "NKG7", "GZMB", "CCL5"),
  group.by = "predicted.id"
) + RotatedAxis()

