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
top5 <- all_markers |>
  group_by(cluster) |>
  slice_max(order_by = avg_log2FC, n = 5)

head(top5)

library(ggplot2)

# Sum raw peak counts per cell type, then CPM-normalise using all peaks
pb <- as.matrix(AggregateExpression(pbmc, assays = "peaks", group.by = "predicted.id")$peaks)
pb_cpm <- log1p(sweep(pb, 2, colSums(pb), "/") * 1e6)

# Keep the top marker peaks and z-score each peak across cell types
top_peaks <- unique(top5$gene)
mat <- pb_cpm[top_peaks, ]
mat <- t(scale(t(mat)))

heat_df <- data.frame(
  peak      = factor(rep(rownames(mat), ncol(mat)), levels = rev(top_peaks)),
  cell_type = rep(colnames(mat), each = nrow(mat)),
  z         = as.vector(mat)
)

ggplot(heat_df, aes(x = cell_type, y = peak, fill = z)) +
  geom_tile() +
  scale_fill_gradient2(low = "steelblue", mid = "white", high = "firebrick") +
  labs(x = NULL, y = NULL, fill = "Row z-score") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        axis.text.y = element_text(size = 5))

# ## ?? e.g. AggregateExpression() then DESeq2 ??
