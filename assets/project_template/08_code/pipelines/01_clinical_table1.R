#!/usr/bin/env Rscript

source("08_code/R/workflow_utils.R")
cfg <- load_config()
palette <- load_palette()
require_packages(c("ggplot2", "data.table", "scales"))

metadata <- read_metadata(cfg)
group_levels <- c(cfg$project$reference_class, cfg$project$positive_class)
metadata$group <- factor(metadata$group, levels = group_levels)
variables <- cfg$clinical$variables

format_continuous <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) return("")
  quantiles <- stats::quantile(x, c(0.25, 0.5, 0.75), names = FALSE)
  sprintf("%.1f [%.1f, %.1f]", quantiles[2], quantiles[1], quantiles[3])
}

format_count <- function(n, denominator) {
  if (!denominator) return("")
  sprintf("%d (%.1f%%)", n, 100 * n / denominator)
}

format_p <- function(p) {
  if (!is.finite(p)) return("")
  if (p < 0.001) "<0.001" else sprintf("%.3f", p)
}

rows <- list()
add_row <- function(characteristic, overall = "", reference = "", positive = "",
                    p_value = "", missing = "") {
  rows[[length(rows) + 1L]] <<- data.frame(
    Characteristic = characteristic,
    Overall = overall,
    Reference = reference,
    Positive = positive,
    `P value` = p_value,
    Missingness = missing,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

for (variable in variables) {
  column <- variable$column
  if (!column %in% names(metadata)) {
    warning("Clinical variable missing and skipped: ", column)
    next
  }
  scope <- variable$scope %||% "all"
  data <- metadata
  if (scope == "disease") {
    data <- data[data$group == cfg$clinical$disease_only_group, , drop = FALSE]
  }
  values <- data[[column]]
  missing_n <- sum(is.na(values) | trimws(as.character(values)) == "")
  missing_label <- sprintf("%d/%d", missing_n, nrow(data))

  if (variable$type == "continuous") {
    numeric_values <- suppressWarnings(as.numeric(values))
    p <- NA_real_
    if (scope == "all" && length(unique(stats::na.omit(data$group))) == 2) {
      p <- tryCatch(
        stats::wilcox.test(numeric_values ~ data$group, exact = FALSE)$p.value,
        error = function(e) NA_real_
      )
    }
    add_row(
      variable$label,
      format_continuous(numeric_values),
      if (scope == "all") format_continuous(numeric_values[data$group == group_levels[1]]) else "",
      format_continuous(numeric_values[data$group == group_levels[2]]),
      format_p(p),
      missing_label
    )
  } else {
    text <- as.character(values)
    levels_present <- sort(unique(text[!is.na(text) & nzchar(trimws(text))]))
    p <- NA_real_
    if (scope == "all" && length(levels_present) > 1) {
      contingency <- table(text, data$group)
      expected <- suppressWarnings(stats::chisq.test(contingency)$expected)
      p <- tryCatch(
        if (any(expected < 5)) stats::fisher.test(contingency)$p.value else
          stats::chisq.test(contingency, correct = FALSE)$p.value,
        error = function(e) NA_real_
      )
    }
    add_row(variable$label, p_value = format_p(p), missing = missing_label)
    for (level in levels_present) {
      add_row(
        paste0("  ", level),
        format_count(sum(text == level, na.rm = TRUE), sum(!is.na(text))),
        if (scope == "all") format_count(
          sum(text == level & data$group == group_levels[1], na.rm = TRUE),
          sum(!is.na(text) & data$group == group_levels[1])
        ) else "",
        format_count(
          sum(text == level & data$group == group_levels[2], na.rm = TRUE),
          sum(!is.na(text) & data$group == group_levels[2])
        )
      )
    }
  }
}

table1 <- do.call(rbind, rows)
names(table1)[names(table1) == "Reference"] <- group_levels[1]
names(table1)[names(table1) == "Positive"] <- group_levels[2]
source_path <- path_in_project(
  "06_tables", "source_data_tables", "Table1_clinical_characteristics_source.tsv"
)
write_tsv(table1, source_path)

if (requireNamespace("openxlsx", quietly = TRUE)) {
  workbook <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(workbook, "Table 1")
  openxlsx::writeData(workbook, "Table 1", table1)
  top_border <- openxlsx::createStyle(border = "top", borderStyle = "thin")
  bottom_border <- openxlsx::createStyle(border = "bottom", borderStyle = "thin")
  header <- openxlsx::createStyle(textDecoration = "bold", border = "bottom")
  openxlsx::addStyle(workbook, "Table 1", top_border, rows = 1, cols = 1:ncol(table1))
  openxlsx::addStyle(workbook, "Table 1", header, rows = 1, cols = 1:ncol(table1))
  openxlsx::addStyle(
    workbook, "Table 1", bottom_border,
    rows = nrow(table1) + 1, cols = 1:ncol(table1)
  )
  openxlsx::setColWidths(workbook, "Table 1", cols = 1:ncol(table1), widths = "auto")
  output <- path_in_project("06_tables", "main_tables", "Table1_clinical_characteristics.xlsx")
  ensure_dir(dirname(output))
  openxlsx::saveWorkbook(workbook, output, overwrite = TRUE)
}

group_colors <- c(
  stats::setNames(palette$groups$control, group_levels[1]),
  stats::setNames(palette$groups$disease, group_levels[2])
)

for (variable in variables) {
  column <- variable$column
  if (!column %in% names(metadata)) next
  data <- metadata
  if ((variable$scope %||% "all") == "disease") {
    data <- data[data$group == cfg$clinical$disease_only_group, , drop = FALSE]
  }
  figure <- reserve_figure(paste0("clinical_", clean_slug(column)), "clinical")
  plot_source <- data.frame(
    sample_id = data$sample_id,
    group = as.character(data$group),
    value = data[[column]],
    stringsAsFactors = FALSE
  )
  plot_source_path <- path_in_project(
    "05_figures", "figure_source_data",
    paste0(figure$prefix, "_", figure$slug, "_source.tsv")
  )
  write_tsv(plot_source, plot_source_path)

  if (variable$type == "continuous") {
    plot_source$value_numeric <- suppressWarnings(as.numeric(plot_source$value))
    plot <- ggplot2::ggplot(
      plot_source,
      ggplot2::aes(group, value_numeric, color = group)
    ) +
      ggplot2::geom_boxplot(width = 0.45, outlier.shape = NA, linewidth = 0.45) +
      ggplot2::geom_jitter(width = 0.12, alpha = 0.65, size = 1.2) +
      ggplot2::scale_color_manual(values = group_colors) +
      ggplot2::labs(title = variable$label, x = NULL, y = variable$label) +
      theme_submission(8)
  } else {
    counts <- as.data.frame(table(plot_source$group, plot_source$value))
    names(counts) <- c("group", "category", "n")
    counts <- counts[counts$n > 0, , drop = FALSE]
    counts$fraction <- ave(counts$n, counts$group, FUN = function(x) x / sum(x))
    plot <- ggplot2::ggplot(
      counts,
      ggplot2::aes(group, fraction, fill = category)
    ) +
      ggplot2::geom_col(width = 0.68, color = "white", linewidth = 0.25) +
      ggplot2::scale_fill_manual(
        values = rep(palette$clinical$categorical, length.out = length(unique(counts$category)))
      ) +
      ggplot2::scale_y_continuous(labels = scales::percent_format()) +
      ggplot2::labs(title = variable$label, x = NULL, y = "Fraction") +
      theme_submission(8)
  }
  save_plot_bundle(plot, figure$stem, 100, 80)
  append_figure_map(
    figure, "M01_clinical", paste0("Clinical distribution: ", variable$label),
    if (variable$type == "continuous") "box_jitter" else "stacked_fraction_bar",
    plot_source_path, path_in_project("08_code", "pipelines", "01_clinical_table1.R"),
    100, 80
  )
}

record_session("M01_clinical")
message("Clinical Table 1 and figures complete.")
