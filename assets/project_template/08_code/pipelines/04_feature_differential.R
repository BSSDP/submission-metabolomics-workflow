#!/usr/bin/env Rscript

source("08_code/R/workflow_utils.R")
cfg <- load_config()
require_packages(c("ggplot2", "ggrepel", "limma", "data.table"))

metadata <- read_metadata(cfg)
matrix <- read_feature_matrix(path_in_project(
  "03_processed_data", "metabolomics", "matrix_cleaned",
  "combined_feature_matrix_log2.tsv"
))
matrix <- matrix[, metadata$matrix_sample_id, drop = FALSE]
all_results <- list()

for (comparison in cfg$differential$comparisons) {
  selected_metadata <- metadata
  selected_matrix <- matrix
  query <- comparison$subset_query %||% ""
  if (nzchar(query)) {
    keep <- with(selected_metadata, eval(parse(text = query)))
    keep[is.na(keep)] <- FALSE
    selected_metadata <- selected_metadata[keep, , drop = FALSE]
    selected_matrix <- selected_matrix[
      , selected_metadata$matrix_sample_id, drop = FALSE
    ]
  }
  result <- run_limma_contrast(
    selected_matrix, selected_metadata,
    comparison$numerator, comparison$reference,
    comparison$id, cfg
  )
  all_results[[comparison$id]] <- result
  output_dir <- path_in_project(
    "04_analysis", "R02_metabolomic_landscape",
    "M04_feature_differential", "outputs"
  )
  ensure_dir(output_dir)
  write_tsv(result, file.path(output_dir, paste0(comparison$id, "_all.tsv")))
  write_tsv(
    result[result$status == "Up", , drop = FALSE],
    file.path(output_dir, paste0(comparison$id, "_up.tsv"))
  )
  write_tsv(
    result[result$status == "Down", , drop = FALSE],
    file.path(output_dir, paste0(comparison$id, "_down.tsv"))
  )

  figure <- reserve_figure(
    paste0("feature_volcano_", clean_slug(comparison$id)),
    "metabolomics_volcano"
  )
  source_path <- path_in_project(
    "05_figures", "figure_source_data",
    paste0(figure$prefix, "_", figure$slug, "_source.tsv")
  )
  write_tsv(result, source_path)
  plot <- plot_volcano(result, paste("Differential features:", comparison$id))
  save_plot_bundle(plot, figure$stem, 100, 80)
  append_figure_map(
    figure, "M04_feature_differential",
    paste("Feature-level differential result:", comparison$id),
    "volcano", source_path,
    path_in_project("08_code", "pipelines", "04_feature_differential.R"),
    100, 80
  )
}

if (isTRUE(cfg$differential$grouped_multivolcano) && length(all_results) > 1) {
  combined <- do.call(rbind, all_results)
  combined$comparison_id <- factor(
    combined$comparison_id, levels = names(all_results)
  )
  palette <- load_palette()
  figure <- reserve_figure(
    "feature_grouped_multivolcano", "metabolomics_volcano"
  )
  source_path <- path_in_project(
    "05_figures", "figure_source_data",
    paste0(figure$prefix, "_", figure$slug, "_source.tsv")
  )
  write_tsv(combined, source_path)
  colors <- c(
    "Not significant" = palette$directions$background,
    "Down" = palette$directions$down,
    "Up" = palette$directions$up
  )
  plot <- ggplot2::ggplot(
    combined,
    ggplot2::aes(comparison_id, log2FC, color = status)
  ) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.4, color = palette$text$axis) +
    ggplot2::geom_jitter(width = 0.22, height = 0, size = 1.0, alpha = 0.55) +
    ggplot2::scale_color_manual(values = colors) +
    ggplot2::labs(
      title = "Grouped differential features",
      x = NULL, y = "log2 fold change"
    ) +
    theme_submission(8) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 25, hjust = 1))
  save_plot_bundle(plot, figure$stem, 150, 90)
  append_figure_map(
    figure, "M04_feature_differential",
    "Grouped feature-level differential results", "grouped_multivolcano",
    source_path,
    path_in_project("08_code", "pipelines", "04_feature_differential.R"),
    150, 90
  )
}

record_session("M04_feature_differential")
message("Feature differential analysis complete.")

