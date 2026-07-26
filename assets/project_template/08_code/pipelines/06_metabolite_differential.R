#!/usr/bin/env Rscript

source("08_code/R/workflow_utils.R")
cfg <- load_config()
require_packages(c("limma", "ggplot2", "ggrepel", "data.table"))

metadata <- read_metadata(cfg)
matrix_path <- path_in_project(
  "03_processed_data", "metabolomics", "matrix_annotated_metabolite_level",
  "metabolite_matrix_combined_common_name.tsv"
)
data <- read_any_table(matrix_path)
annotation_columns <- c(
  "metabolite_id", "common_name", "display_name", "mode", "source_feature_id"
)
missing <- setdiff(annotation_columns, names(data))
if (length(missing)) stop("Metabolite matrix lacks columns: ", paste(missing, collapse = ", "))
matrix <- as.matrix(data[, setdiff(names(data), annotation_columns), drop = FALSE])
storage.mode(matrix) <- "double"
rownames(matrix) <- data$metabolite_id
matrix <- matrix[, metadata$matrix_sample_id, drop = FALSE]
annotation <- data[, annotation_columns, drop = FALSE]

for (comparison in cfg$differential$comparisons) {
  result <- run_limma_contrast(
    matrix, metadata, comparison$numerator, comparison$reference,
    comparison$id, cfg
  )
  result <- merge(result, annotation, by.x = "feature_id", by.y = "metabolite_id")
  result <- result[order(result$FDR, -abs(result$log2FC)), , drop = FALSE]
  result$rank <- seq_len(nrow(result))
  output_dir <- path_in_project(
    "04_analysis", "R02_metabolomic_landscape",
    "M06_metabolite_differential", "outputs"
  )
  ensure_dir(output_dir)
  write_tsv(result, file.path(output_dir, paste0(comparison$id, "_all_metabolites.tsv")))
  write_tsv(
    result[result$status == "Up", , drop = FALSE],
    file.path(output_dir, paste0(comparison$id, "_up_metabolites.tsv"))
  )
  write_tsv(
    result[result$status == "Down", , drop = FALSE],
    file.path(output_dir, paste0(comparison$id, "_down_metabolites.tsv"))
  )

  figure <- reserve_figure(
    paste0("metabolite_volcano_", clean_slug(comparison$id)),
    "metabolomics_volcano"
  )
  source_path <- path_in_project(
    "05_figures", "figure_source_data",
    paste0(figure$prefix, "_", figure$slug, "_source.tsv")
  )
  write_tsv(result, source_path)
  plot <- plot_volcano(
    result, paste("Differential metabolites:", comparison$id),
    label_column = "common_name"
  )
  save_plot_bundle(plot, figure$stem, 100, 80)
  append_figure_map(
    figure, "M06_metabolite_differential",
    paste("Metabolite-level differential result:", comparison$id),
    "volcano", source_path,
    path_in_project("08_code", "pipelines", "06_metabolite_differential.R"),
    100, 80
  )
}

record_session("M06_metabolite_differential")
message("Metabolite differential analysis complete.")

