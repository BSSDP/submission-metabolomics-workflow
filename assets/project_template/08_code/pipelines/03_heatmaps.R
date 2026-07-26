#!/usr/bin/env Rscript

source("08_code/R/workflow_utils.R")
cfg <- load_config()
palette <- load_palette()
require_packages(c("ComplexHeatmap", "circlize", "data.table"))

metadata <- read_metadata(cfg)
matrix_path <- path_in_project(
  "03_processed_data", "metabolomics", "matrix_cleaned",
  "combined_feature_matrix_log2.tsv"
)
feature_matrix <- read_feature_matrix(matrix_path)
feature_matrix <- feature_matrix[, metadata$matrix_sample_id, drop = FALSE]
z_matrix <- row_zscore(feature_matrix)

primary <- cfg$differential$comparisons[[1]]
differential <- run_limma_contrast(
  feature_matrix, metadata, primary$numerator, primary$reference,
  primary$id, cfg
)
top_features <- head(differential$feature_id, cfg$heatmap$top_n_differential)
top_features <- intersect(top_features, rownames(z_matrix))
disease_samples <- metadata$matrix_sample_id[
  metadata$group == cfg$clinical$disease_only_group
]

clinical_variables <- cfg$clinical$variables
annotation <- data.frame(row.names = metadata$matrix_sample_id, check.names = FALSE)
for (column in cfg$heatmap$annotation_columns) {
  if (column == "group") {
    annotation[[column]] <- metadata$group
  } else if (column %in% names(metadata)) {
    annotation[[column]] <- metadata[[column]]
    variable <- Filter(function(x) identical(x$column, column), clinical_variables)
    if (length(variable) && identical(variable[[1]]$scope, "disease")) {
      annotation[[column]][metadata$group != cfg$clinical$disease_only_group] <- NA
    }
  }
}

annotation_colors <- list()
for (column in names(annotation)) {
  values <- annotation[[column]]
  numeric_values <- suppressWarnings(as.numeric(as.character(values)))
  if (sum(is.finite(numeric_values)) >= max(3, nrow(annotation) / 2)) {
    range_values <- range(numeric_values, na.rm = TRUE)
    if (diff(range_values) == 0) range_values <- range_values + c(-0.5, 0.5)
    annotation_colors[[column]] <- circlize::colorRamp2(
      range_values,
      c(palette$clinical$continuous_low, palette$clinical$continuous_high)
    )
  } else {
    levels_present <- sort(unique(as.character(values[!is.na(values)])))
    annotation_colors[[column]] <- stats::setNames(
      rep(palette$clinical$categorical, length.out = length(levels_present)),
      levels_present
    )
    if (column == "group") {
      annotation_colors[[column]] <- c(
        stats::setNames(palette$groups$control, cfg$project$reference_class),
        stats::setNames(palette$groups$disease, cfg$project$positive_class)
      )
    }
  }
}

make_annotation <- function(selected_samples) {
  ComplexHeatmap::HeatmapAnnotation(
    df = annotation[selected_samples, , drop = FALSE],
    col = annotation_colors,
    na_col = palette$clinical$not_applicable,
    simple_anno_size = grid::unit(2.2, "mm"),
    annotation_name_gp = grid::gpar(fontfamily = submission_font(), fontsize = 5.5),
    border = FALSE
  )
}

save_heatmap <- function(matrix, selected_samples, slug, title, split_groups = FALSE) {
  matrix <- matrix[, selected_samples, drop = FALSE]
  clip <- cfg$preprocessing$heatmap_z_clip
  display <- pmax(pmin(matrix, clip), -clip)
  split <- NULL
  if (split_groups) {
    split <- factor(
      metadata$group[match(selected_samples, metadata$matrix_sample_id)],
      levels = c(cfg$project$reference_class, cfg$project$positive_class)
    )
  }
  color_fun <- circlize::colorRamp2(
    c(-clip, 0, clip),
    c(palette$heatmap$low, palette$heatmap$mid, palette$heatmap$high)
  )
  heatmap <- ComplexHeatmap::Heatmap(
    display,
    name = "Row z-score",
    col = color_fun,
    top_annotation = make_annotation(selected_samples),
    cluster_rows = TRUE,
    cluster_columns = TRUE,
    column_split = split,
    cluster_column_slices = FALSE,
    clustering_distance_rows = cfg$heatmap$distance,
    clustering_distance_columns = cfg$heatmap$distance,
    clustering_method_rows = cfg$heatmap$clustering_method,
    clustering_method_columns = cfg$heatmap$clustering_method,
    show_column_names = FALSE,
    show_row_names = nrow(display) <= 120,
    row_names_gp = grid::gpar(fontfamily = submission_font(), fontsize = 4.5),
    column_title = title,
    column_title_gp = grid::gpar(
      fontfamily = submission_font(), fontsize = 8, fontface = "bold"
    ),
    use_raster = nrow(display) > 100,
    raster_quality = 3,
    border = FALSE
  )
  figure <- reserve_figure(slug, "metabolomics_heatmap")
  source_path <- path_in_project(
    "05_figures", "figure_source_data",
    paste0(figure$prefix, "_", figure$slug, "_matrix.tsv")
  )
  write_feature_matrix(matrix, source_path)
  annotation_path <- path_in_project(
    "05_figures", "figure_source_data",
    paste0(figure$prefix, "_", figure$slug, "_annotation.tsv")
  )
  write_tsv(
    data.frame(
      matrix_sample_id = rownames(annotation[selected_samples, , drop = FALSE]),
      annotation[selected_samples, , drop = FALSE],
      check.names = FALSE
    ),
    annotation_path
  )
  style <- load_figure_style()
  width_mm <- style$sizes_mm$heatmap$width
  height_mm <- style$sizes_mm$heatmap$height
  width <- width_mm / 25.4
  height <- height_mm / 25.4
  ensure_dir(dirname(figure$stem))
  grDevices::cairo_pdf(
    paste0(figure$stem, ".pdf"), width = width, height = height,
    family = submission_font()
  )
  ComplexHeatmap::draw(heatmap, annotation_legend_side = "bottom")
  grDevices::dev.off()
  if (requireNamespace("svglite", quietly = TRUE)) {
    svglite::svglite(paste0(figure$stem, ".svg"), width = width, height = height)
    ComplexHeatmap::draw(heatmap, annotation_legend_side = "bottom")
    grDevices::dev.off()
  }
  if (requireNamespace("ragg", quietly = TRUE)) {
    ragg::agg_png(
      paste0(figure$stem, ".png"), width = width, height = height,
      units = "in", res = style$export$raster_dpi
    )
    ComplexHeatmap::draw(heatmap, annotation_legend_side = "bottom")
    grDevices::dev.off()
    ragg::agg_tiff(
      paste0(figure$stem, ".tiff"), width = width, height = height,
      units = "in", res = style$export$raster_dpi, compression = "lzw"
    )
    ComplexHeatmap::draw(heatmap, annotation_legend_side = "bottom")
    grDevices::dev.off()
  }
  append_figure_map(
    figure, "M03_heatmaps", title, "annotated_heatmap", source_path,
    path_in_project("08_code", "pipelines", "03_heatmaps.R"),
    width_mm, height_mm
  )
}

jobs <- cfg$heatmap$outputs
all_samples <- metadata$matrix_sample_id
if (isTRUE(jobs$all_features_group_split)) {
  ordered <- c(
    metadata$matrix_sample_id[metadata$group == cfg$project$reference_class],
    metadata$matrix_sample_id[metadata$group == cfg$project$positive_class]
  )
  save_heatmap(
    z_matrix, ordered, "all_samples_all_features_group_split",
    "All samples and all features, clustered within group", TRUE
  )
}
if (isTRUE(jobs$all_features_global)) {
  save_heatmap(
    z_matrix, all_samples, "all_samples_all_features_global_cluster",
    "All samples and all features"
  )
}
if (isTRUE(jobs$top_differential_global)) {
  save_heatmap(
    z_matrix[top_features, , drop = FALSE], all_samples,
    "all_samples_top_differential_features",
    paste("All samples and top", length(top_features), "differential features")
  )
}
if (isTRUE(jobs$disease_all_features)) {
  save_heatmap(
    z_matrix, disease_samples, "disease_samples_all_features",
    "Disease samples and all features"
  )
}
if (isTRUE(jobs$disease_top_differential)) {
  save_heatmap(
    z_matrix[top_features, , drop = FALSE], disease_samples,
    "disease_samples_top_differential_features",
    paste("Disease samples and top", length(top_features), "differential features")
  )
}

record_session("M03_heatmaps")
message("Heatmaps complete.")
