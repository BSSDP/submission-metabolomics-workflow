suppressPackageStartupMessages({
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' is required.")
  }
})

project_root <- function() {
  root <- normalizePath(".", winslash = "/", mustWork = TRUE)
  required <- file.path(root, "08_code", "configs", "project.yml")
  if (!file.exists(required)) {
    stop("Run from the project root; missing ", required)
  }
  root
}

path_in_project <- function(...) {
  file.path(project_root(), ...)
}

load_config <- function() {
  yaml::read_yaml(path_in_project("08_code", "configs", "project.yml"))
}

load_palette <- function() {
  yaml::read_yaml(path_in_project("08_code", "configs", "color_palette.yml"))
}

load_figure_style <- function() {
  yaml::read_yaml(path_in_project("08_code", "configs", "figure_style.yml"))
}

submission_font <- function() {
  style <- load_figure_style()
  desired <- style$font$family %||% "Arial"
  if (desired %in% names(grDevices::pdfFonts())) desired else "sans"
}

require_packages <- function(packages) {
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop("Missing R packages: ", paste(missing, collapse = ", "))
  }
}

ensure_dir <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE)
  invisible(path)
}

assert_not_raw_output <- function(path) {
  raw <- normalizePath(path_in_project("00_raw_data"), winslash = "/", mustWork = FALSE)
  target <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (startsWith(tolower(target), tolower(paste0(raw, "/"))) ||
      identical(tolower(target), tolower(raw))) {
    stop("Refusing to write under immutable raw data: ", path)
  }
}

read_any_table <- function(path, sheet = 1) {
  require_packages(c("data.table"))
  extension <- tolower(tools::file_ext(path))
  if (!file.exists(path)) stop("Input file not found: ", path)
  if (extension %in% c("xlsx", "xls")) {
    require_packages(c("readxl"))
    return(as.data.frame(readxl::read_excel(path, sheet = sheet), check.names = FALSE))
  }
  separator <- if (extension == "csv") "," else "\t"
  data.table::fread(path, sep = separator, data.table = FALSE, check.names = FALSE)
}

write_tsv <- function(x, path) {
  require_packages(c("data.table"))
  assert_not_raw_output(path)
  ensure_dir(dirname(path))
  data.table::fwrite(x, path, sep = "\t", quote = FALSE, na = "NA")
  invisible(path)
}

clean_slug <- function(x) {
  x <- gsub("[^A-Za-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  x
}

reserve_figure <- function(slug, module) {
  slug <- clean_slug(slug)
  output_dir <- path_in_project("05_figures", "unassigned", module)
  ensure_dir(output_dir)
  existing <- list.files(
    path_in_project("05_figures"),
    pattern = paste0("^([0-9]+)_", slug, "\\.pdf$"),
    recursive = TRUE,
    full.names = TRUE
  )
  if (length(existing)) {
    prefix <- sub("_.*$", "", basename(existing[[1]]))
  } else {
    all_files <- list.files(
      path_in_project("05_figures"),
      pattern = "^[0-9]+_",
      recursive = TRUE
    )
    numbers <- suppressWarnings(as.integer(sub("_.*$", "", basename(all_files))))
    numbers <- numbers[is.finite(numbers)]
    prefix <- sprintf("%02d", if (length(numbers)) max(numbers) + 1L else 1L)
  }
  list(
    prefix = prefix,
    slug = slug,
    stem = file.path(output_dir, paste0(prefix, "_", slug))
  )
}

theme_submission <- function(base_size = 8) {
  require_packages(c("ggplot2"))
  palette <- load_palette()
  ggplot2::theme_classic(base_size = base_size, base_family = submission_font()) +
    ggplot2::theme(
      axis.line = ggplot2::element_line(linewidth = 0.35, colour = palette$text$axis),
      axis.ticks = ggplot2::element_line(linewidth = 0.35, colour = palette$text$axis),
      axis.text = ggplot2::element_text(colour = palette$text$dark),
      axis.title = ggplot2::element_text(colour = palette$text$dark),
      legend.position = "top",
      legend.justification = "left",
      legend.title = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank(),
      plot.title.position = "plot",
      plot.title = ggplot2::element_text(face = "bold")
    )
}

save_plot_bundle <- function(plot, stem, width_mm = 100, height_mm = 80) {
  require_packages(c("ggplot2"))
  assert_not_raw_output(stem)
  ensure_dir(dirname(stem))
  style <- load_figure_style()
  dpi <- style$export$raster_dpi %||% 600
  width <- width_mm / 25.4
  height <- height_mm / 25.4

  ggplot2::ggsave(
    paste0(stem, ".pdf"), plot, width = width, height = height,
    units = "in", device = grDevices::cairo_pdf
  )
  if (requireNamespace("svglite", quietly = TRUE)) {
    ggplot2::ggsave(
      paste0(stem, ".svg"), plot, width = width, height = height,
      units = "in", device = svglite::svglite
    )
  }
  ggplot2::ggsave(
    paste0(stem, ".png"), plot, width = width, height = height,
    units = "in", dpi = dpi
  )
  if (requireNamespace("ragg", quietly = TRUE)) {
    ggplot2::ggsave(
      paste0(stem, ".tiff"), plot, width = width, height = height,
      units = "in", dpi = dpi, device = ragg::agg_tiff,
      compression = "lzw"
    )
  }
  invisible(stem)
}

append_figure_map <- function(
    figure, analysis_id, message, plot_type, source_data, script_file,
    width_mm, height_mm) {
  map_path <- path_in_project("00_project_management", "FIGURE_MAP.tsv")
  current <- read_any_table(map_path)
  figure_id <- paste0(figure$prefix, "_", toupper(figure$slug))
  if (nrow(current) && figure_id %in% current$figure_id) return(invisible(figure_id))
  row <- data.frame(
    figure_id = figure_id,
    panel_id = NA_character_,
    status = "done",
    result_section = "unassigned",
    message = message,
    plot_type = plot_type,
    analysis_id = analysis_id,
    source_data_file = relative_path(source_data),
    script_file = relative_path(script_file),
    output_pdf = relative_path(paste0(figure$stem, ".pdf")),
    output_svg = relative_path(paste0(figure$stem, ".svg")),
    output_png = relative_path(paste0(figure$stem, ".png")),
    output_tiff = relative_path(paste0(figure$stem, ".tiff")),
    width_mm = width_mm,
    height_mm = height_mm,
    journal_role = "unassigned",
    legend_status = "pending",
    decision = "pending",
    stringsAsFactors = FALSE
  )
  write_tsv(rbind(current, row), map_path)
  invisible(figure_id)
}

relative_path <- function(path) {
  root <- normalizePath(project_root(), winslash = "/", mustWork = TRUE)
  target <- normalizePath(path, winslash = "/", mustWork = FALSE)
  sub(paste0("^", gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", root), "/?"), "", target)
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
}

read_intensity_matrix <- function(path, mode, cfg) {
  raw <- read_any_table(path)
  id_column <- cfg$matrix$feature_id_column
  if (!id_column %in% names(raw)) {
    if (ncol(raw) < 2) stop("Intensity matrix has too few columns: ", path)
    id_column <- names(raw)[1]
  }
  ids <- trimws(as.character(raw[[id_column]]))
  if (any(!nzchar(ids)) || anyDuplicated(ids)) {
    stop("Feature IDs are blank or duplicated in ", path)
  }
  sample_columns <- setdiff(names(raw), id_column)
  numeric_data <- lapply(raw[sample_columns], function(x) suppressWarnings(as.numeric(x)))
  for (j in seq_along(sample_columns)) {
    introduced <- is.na(numeric_data[[j]]) & !is.na(raw[[sample_columns[[j]]]]) &
      nzchar(trimws(as.character(raw[[sample_columns[[j]]]])))
    if (any(introduced)) {
      stop("Nonnumeric intensity values in sample column ", sample_columns[[j]])
    }
  }
  matrix <- t(as.matrix(as.data.frame(numeric_data, check.names = FALSE)))
  rownames(matrix) <- sample_columns
  colnames(matrix) <- paste0(mode, "_", ids)
  storage.mode(matrix) <- "double"
  list(matrix = matrix, raw_feature_id = stats::setNames(ids, colnames(matrix)))
}

preprocess_intensity <- function(x, cfg) {
  parameters <- cfg$preprocessing
  if (isTRUE(cfg$matrix$zero_as_missing)) x[x <= 0] <- NA_real_
  x[!is.finite(x)] <- NA_real_
  missing_fraction <- colMeans(is.na(x))
  keep <- missing_fraction <= parameters$feature_missingness_max
  x <- x[, keep, drop = FALSE]
  missing_fraction <- missing_fraction[keep]
  if (ncol(x) < 2) stop("Fewer than two features remain after missingness filtering.")

  minimum <- apply(x, 2, function(v) {
    values <- v[is.finite(v) & v > 0]
    if (length(values)) min(values) else NA_real_
  })
  keep <- is.finite(minimum)
  x <- x[, keep, drop = FALSE]
  minimum <- minimum[keep]
  missing_fraction <- missing_fraction[keep]
  for (j in seq_len(ncol(x))) {
    missing <- is.na(x[, j])
    x[missing, j] <- minimum[j] / 2
  }

  sample_total <- rowSums(x)
  if (any(!is.finite(sample_total) | sample_total <= 0)) {
    stop("Invalid sample totals after imputation.")
  }
  normalization_factor <- sample_total / stats::median(sample_total)
  normalized <- sweep(x, 1, normalization_factor, "/")
  log_matrix <- log(normalized, base = parameters$log_base)
  variable <- apply(log_matrix, 2, stats::sd) > 0
  log_matrix <- log_matrix[, variable, drop = FALSE]
  normalized <- normalized[, variable, drop = FALSE]
  missing_fraction <- missing_fraction[variable]

  list(
    raw_imputed = x[, variable, drop = FALSE],
    normalized = normalized,
    log = log_matrix,
    missing_fraction = missing_fraction,
    normalization_factor = normalization_factor
  )
}

pareto_scale <- function(x) {
  centered <- sweep(x, 2, colMeans(x), "-")
  standard_deviation <- apply(x, 2, stats::sd)
  keep <- is.finite(standard_deviation) & standard_deviation > 0
  sweep(centered[, keep, drop = FALSE], 2, sqrt(standard_deviation[keep]), "/")
}

row_zscore <- function(feature_by_sample) {
  means <- rowMeans(feature_by_sample)
  standard_deviation <- apply(feature_by_sample, 1, stats::sd)
  keep <- is.finite(standard_deviation) & standard_deviation > 0
  output <- sweep(feature_by_sample[keep, , drop = FALSE], 1, means[keep], "-")
  sweep(output, 1, standard_deviation[keep], "/")
}

read_metadata <- function(cfg) {
  clinical_path <- path_in_project(cfg$inputs$clinical)
  clinical <- read_any_table(clinical_path, sheet = cfg$clinical$sheet %||% 1)
  required <- c(
    cfg$clinical$sample_id_column,
    cfg$clinical$matrix_sample_id_column,
    cfg$clinical$group_column
  )
  missing <- setdiff(required, names(clinical))
  if (length(missing)) {
    stop("Clinical metadata is missing columns: ", paste(missing, collapse = ", "))
  }
  include_column <- cfg$clinical$include_column
  if (!is.null(include_column) && include_column %in% names(clinical)) {
    clinical <- clinical[
      tolower(as.character(clinical[[include_column]])) ==
        tolower(as.character(cfg$clinical$include_value)),
      ,
      drop = FALSE
    ]
  }
  clinical$sample_id <- as.character(clinical[[cfg$clinical$sample_id_column]])
  clinical$matrix_sample_id <- as.character(
    clinical[[cfg$clinical$matrix_sample_id_column]]
  )
  clinical$group <- as.character(clinical[[cfg$clinical$group_column]])
  if (anyDuplicated(clinical$sample_id) || anyDuplicated(clinical$matrix_sample_id)) {
    stop("Clinical metadata contains duplicated sample IDs.")
  }
  clinical
}

align_biological_samples <- function(x, metadata, cfg) {
  qc <- grepl(cfg$matrix$qc_sample_regex, rownames(x), perl = TRUE)
  biological <- rownames(x)[!qc]
  expected <- metadata$matrix_sample_id
  if (!setequal(biological, expected)) {
    stop(
      "Matrix/metadata sample mismatch. Matrix-only: ",
      paste(head(setdiff(biological, expected), 10), collapse = ", "),
      "; metadata-only: ",
      paste(head(setdiff(expected, biological), 10), collapse = ", ")
    )
  }
  metadata <- metadata[match(biological, metadata$matrix_sample_id), , drop = FALSE]
  list(qc = qc, metadata = metadata)
}

write_feature_matrix <- function(feature_by_sample, path) {
  output <- data.frame(
    feature_id = rownames(feature_by_sample),
    mode = sub("_.*$", "", rownames(feature_by_sample)),
    as.data.frame(feature_by_sample, check.names = FALSE),
    check.names = FALSE
  )
  write_tsv(output, path)
}

read_feature_matrix <- function(path) {
  data <- read_any_table(path)
  required <- c("feature_id", "mode")
  if (!all(required %in% names(data))) {
    stop("Processed matrix must include feature_id and mode.")
  }
  matrix <- as.matrix(data[, setdiff(names(data), required), drop = FALSE])
  storage.mode(matrix) <- "double"
  rownames(matrix) <- as.character(data$feature_id)
  matrix
}

run_limma_contrast <- function(
    feature_by_sample, metadata, numerator, reference, comparison_id, cfg) {
  require_packages(c("limma"))
  group <- metadata$group
  keep <- group %in% c(reference, numerator)
  selected <- feature_by_sample[, metadata$matrix_sample_id[keep], drop = FALSE]
  factor_group <- factor(group[keep], levels = c(reference, numerator))
  if (nlevels(droplevels(factor_group)) != 2) {
    stop("Comparison lacks both groups: ", comparison_id)
  }
  design <- stats::model.matrix(~ 0 + factor_group)
  colnames(design) <- c(reference, numerator)
  fit <- limma::lmFit(selected, design)
  contrast <- limma::makeContrasts(
    contrasts = paste0(numerator, "-", reference),
    levels = design
  )
  fit <- limma::eBayes(limma::contrasts.fit(fit, contrast))
  result <- limma::topTable(fit, number = Inf, sort.by = "none", adjust.method = "BH")
  output <- data.frame(
    comparison_id = comparison_id,
    feature_id = rownames(result),
    mode = sub("_.*$", "", rownames(result)),
    numerator = numerator,
    reference = reference,
    n_numerator = sum(factor_group == numerator),
    n_reference = sum(factor_group == reference),
    mean_numerator = rowMeans(selected[, factor_group == numerator, drop = FALSE]),
    mean_reference = rowMeans(selected[, factor_group == reference, drop = FALSE]),
    log2FC = result$logFC,
    P_value = result$P.Value,
    FDR = result$adj.P.Val,
    t = result$t,
    B = result$B,
    stringsAsFactors = FALSE
  )
  output$neg_log10_FDR <- -log10(pmax(output$FDR, .Machine$double.xmin))
  cutoff <- cfg$differential$fdr_cutoff
  effect <- cfg$differential$min_abs_log2fc
  output$status <- ifelse(
    output$FDR < cutoff & output$log2FC >= effect,
    "Up",
    ifelse(output$FDR < cutoff & output$log2FC <= -effect, "Down", "Not significant")
  )
  output <- output[order(output$FDR, -abs(output$log2FC)), , drop = FALSE]
  output$rank <- seq_len(nrow(output))
  rownames(output) <- NULL
  output
}

plot_volcano <- function(result, title, label_column = "feature_id") {
  require_packages(c("ggplot2", "ggrepel"))
  cfg <- load_config()
  palette <- load_palette()
  colors <- c(
    "Not significant" = palette$directions$background,
    "Down" = palette$directions$down,
    "Up" = palette$directions$up
  )
  label_n <- cfg$differential$label_top_n
  labeled <- result[result$status != "Not significant", , drop = FALSE]
  labeled <- head(labeled[order(labeled$FDR, -abs(labeled$log2FC)), ], label_n)
  plot <- ggplot2::ggplot(
    result,
    ggplot2::aes(log2FC, neg_log10_FDR, color = status)
  ) +
    ggplot2::geom_hline(
      yintercept = -log10(cfg$differential$fdr_cutoff),
      linetype = "dashed", linewidth = 0.4, color = palette$text$axis
    ) +
    ggplot2::geom_vline(
      xintercept = c(
        -cfg$differential$min_abs_log2fc,
        cfg$differential$min_abs_log2fc
      ),
      linetype = "dashed", linewidth = 0.4, color = palette$text$axis
    ) +
    ggplot2::geom_point(size = 1.2, alpha = 0.65, stroke = 0) +
    ggplot2::scale_color_manual(values = colors) +
    ggplot2::labs(
      title = title,
      subtitle = paste0(
        result$numerator[[1]], " minus ", result$reference[[1]],
        "; FDR < ", cfg$differential$fdr_cutoff
      ),
      x = "log2 fold change",
      y = expression(-log[10](FDR))
    ) +
    theme_submission(8)
  if (nrow(labeled)) {
    plot <- plot + ggrepel::geom_text_repel(
      data = labeled,
      ggplot2::aes(label = .data[[label_column]]),
      seed = cfg$project$seed,
      size = 2.2,
      min.segment.length = 0,
      max.overlaps = Inf,
      show.legend = FALSE
    )
  }
  plot
}

record_session <- function(analysis_id) {
  path <- path_in_project("09_logs", paste0(analysis_id, "_sessionInfo.txt"))
  ensure_dir(dirname(path))
  capture.output(sessionInfo(), file = path)
  invisible(path)
}
