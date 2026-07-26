#!/usr/bin/env Rscript

source("08_code/R/workflow_utils.R")
cfg <- load_config()
palette <- load_palette()
require_packages(c("ggplot2", "data.table"))
metadata <- read_metadata(cfg)
group_levels <- c(cfg$project$reference_class, cfg$project$positive_class)

jobs <- list(
  positive = cfg$inputs$positive_matrix,
  negative = cfg$inputs$negative_matrix
)

for (mode in names(jobs)) {
  raw <- read_intensity_matrix(path_in_project(jobs[[mode]]), mode, cfg)
  alignment <- align_biological_samples(raw$matrix, metadata, cfg)
  for (include_qc in c(TRUE, FALSE)) {
    selected <- if (include_qc) rep(TRUE, nrow(raw$matrix)) else !alignment$qc
    x <- raw$matrix[selected, , drop = FALSE]
    qc_flag <- grepl(cfg$matrix$qc_sample_regex, rownames(x), perl = TRUE)
    prep <- preprocess_intensity(x, cfg)
    scaled <- pareto_scale(prep$log)
    pca <- stats::prcomp(scaled, center = FALSE, scale. = FALSE)
    variance <- pca$sdev^2 / sum(pca$sdev^2)

    biological_ids <- rownames(x)[!qc_flag]
    biological_metadata <- metadata[
      match(biological_ids, metadata$matrix_sample_id), , drop = FALSE
    ]
    groups <- rep("QC", nrow(x))
    groups[!qc_flag] <- biological_metadata$group
    scores <- data.frame(
      matrix_sample_id = rownames(x),
      sample_id = ifelse(
        qc_flag, paste0(toupper(mode), "_", rownames(x)),
        biological_metadata$sample_id[match(rownames(x), biological_ids)]
      ),
      group = groups,
      sample_type = ifelse(qc_flag, "Pooled QC", "Biological"),
      mode = mode,
      PC1 = pca$x[, 1],
      PC2 = pca$x[, 2],
      stringsAsFactors = FALSE
    )
    scores$group <- factor(scores$group, levels = c(group_levels, "QC"))
    suffix <- if (include_qc) "with_QC" else "biological_only"
    slug <- paste(mode, "ion_PCA", suffix, sep = "_")
    figure <- reserve_figure(slug, "metabolomics_pca")
    source_path <- path_in_project(
      "05_figures", "figure_source_data",
      paste0(figure$prefix, "_", figure$slug, "_scores.tsv")
    )
    write_tsv(scores, source_path)
    write_tsv(
      data.frame(
        component = paste0("PC", seq_along(variance)),
        variance_fraction = variance,
        variance_percent = 100 * variance
      ),
      path_in_project(
        "03_processed_data", "metabolomics", "qc_reports",
        paste0(mode, "_", suffix, "_PCA_variance.tsv")
      )
    )
    if (any(qc_flag)) {
      qc_cv <- apply(
        prep$normalized[qc_flag, , drop = FALSE],
        2,
        function(values) stats::sd(values) / mean(values)
      )
      qc_cv_table <- data.frame(
        mode = mode,
        feature_id = names(qc_cv),
        qc_cv = unname(qc_cv),
        passes_30_percent = qc_cv <= 0.30,
        stringsAsFactors = FALSE
      )
      write_tsv(
        qc_cv_table,
        path_in_project(
          "03_processed_data", "metabolomics", "qc_reports",
          paste0(mode, "_feature_QC_CV.tsv")
        )
      )
      write_tsv(
        data.frame(
          mode = mode,
          n_qc = sum(qc_flag),
          median_qc_cv = stats::median(qc_cv, na.rm = TRUE),
          fraction_qc_cv_le_30_percent = mean(qc_cv <= 0.30, na.rm = TRUE)
        ),
        path_in_project(
          "03_processed_data", "metabolomics", "qc_reports",
          paste0(mode, "_QC_CV_summary.tsv")
        )
      )
    }

    colors <- c(
      stats::setNames(palette$groups$control, group_levels[1]),
      stats::setNames(palette$groups$disease, group_levels[2]),
      QC = palette$groups$qc
    )
    ellipse_data <- scores[
      ave(seq_len(nrow(scores)), scores$group, FUN = length) >= 3, ,
      drop = FALSE
    ]
    plot <- ggplot2::ggplot(scores, ggplot2::aes(PC1, PC2, color = group))
    if (nrow(ellipse_data)) {
      plot <- plot +
        ggplot2::stat_ellipse(
          data = ellipse_data, ggplot2::aes(fill = group),
          geom = "polygon", type = cfg$pca$ellipse_type,
          level = cfg$pca$confidence_level, alpha = 0.08,
          color = NA, show.legend = FALSE
        ) +
        ggplot2::stat_ellipse(
          data = ellipse_data, type = cfg$pca$ellipse_type,
          level = cfg$pca$confidence_level, linewidth = 0.5,
          show.legend = FALSE
        )
    }
    plot <- plot +
      ggplot2::geom_point(size = 1.5, alpha = 0.75, stroke = 0) +
      ggplot2::scale_color_manual(values = colors) +
      ggplot2::scale_fill_manual(values = colors) +
      ggplot2::labs(
        title = paste(tools::toTitleCase(mode), "ion PCA"),
        x = sprintf("PC1 (%.1f%%)", 100 * variance[1]),
        y = sprintf("PC2 (%.1f%%)", 100 * variance[2])
      ) +
      theme_submission(8)
    save_plot_bundle(plot, figure$stem, 100, 80)
    append_figure_map(
      figure, "M02_PCA",
      paste(mode, "ion PCA", suffix), "PCA", source_path,
      path_in_project("08_code", "pipelines", "02_pca.R"), 100, 80
    )
  }
}

record_session("M02_PCA")
message("PCA figures complete.")
