#!/usr/bin/env Rscript

source("08_code/R/workflow_utils.R")
cfg <- load_config()
require_packages(c("ggplot2", "data.table"))

read_pathway <- function(path) {
  if (!nzchar(path)) return(NULL)
  full <- path_in_project(path)
  if (!file.exists(full)) stop("Pathway input not found: ", full)
  if (tolower(tools::file_ext(full)) == "zip") {
    members <- utils::unzip(full, list = TRUE)$Name
    candidates <- members[grepl("pathway.*\\.(csv|tsv)$", members, ignore.case = TRUE)]
    if (!length(candidates)) stop("ZIP lacks a pathway CSV/TSV: ", full)
    connection <- unz(full, candidates[[1]])
    on.exit(close(connection), add = TRUE)
    if (grepl("\\.csv$", candidates[[1]], ignore.case = TRUE)) {
      data <- utils::read.csv(connection, check.names = FALSE)
    } else {
      data <- utils::read.delim(connection, check.names = FALSE)
    }
  } else {
    data <- read_any_table(full)
  }
  data
}

jobs <- list(Up = cfg$inputs$pathway_up, Down = cfg$inputs$pathway_down)
for (direction in names(jobs)) {
  path <- jobs[[direction]] %||% ""
  if (!nzchar(path)) next
  result <- read_pathway(path)
  columns <- cfg$pathway
  required <- c(
    columns$pathway_column, columns$fdr_column,
    columns$hits_column, columns$impact_column
  )
  missing <- setdiff(required, names(result))
  if (length(missing)) {
    stop("Pathway table lacks columns: ", paste(missing, collapse = ", "))
  }
  standardized <- data.frame(
    pathway = as.character(result[[columns$pathway_column]]),
    FDR = suppressWarnings(as.numeric(result[[columns$fdr_column]])),
    hits = suppressWarnings(as.numeric(result[[columns$hits_column]])),
    impact = suppressWarnings(as.numeric(result[[columns$impact_column]])),
    direction = direction,
    stringsAsFactors = FALSE
  )
  standardized <- standardized[
    is.finite(standardized$FDR) & standardized$FDR > 0, , drop = FALSE
  ]
  standardized <- standardized[order(standardized$FDR, -standardized$hits), ]
  standardized$minus_log10_FDR <- -log10(standardized$FDR)
  plotted <- head(standardized, cfg$pathway$top_n)
  plotted$pathway <- factor(plotted$pathway, levels = rev(plotted$pathway))

  output_dir <- path_in_project(
    "04_analysis", "R03_metabolic_modules_and_pathways",
    "M07_pathway_enrichment", "outputs"
  )
  ensure_dir(output_dir)
  write_tsv(
    standardized,
    file.path(output_dir, paste0(tolower(direction), "_all_pathways.tsv"))
  )
  figure <- reserve_figure(
    paste0(tolower(direction), "_metabolite_pathway_dotplot"),
    "metabolomics_pathway"
  )
  source_path <- path_in_project(
    "05_figures", "figure_source_data",
    paste0(figure$prefix, "_", figure$slug, "_source.tsv")
  )
  write_tsv(plotted, source_path)
  plot <- ggplot2::ggplot(
    plotted,
    ggplot2::aes(minus_log10_FDR, pathway, size = hits, color = impact)
  ) +
    ggplot2::geom_vline(
      xintercept = -log10(0.05), linetype = "dashed",
      linewidth = 0.4, color = load_palette()$text$axis
    ) +
    ggplot2::geom_point(alpha = 0.85) +
    ggplot2::scale_color_gradient(
      low = load_palette()$heatmap$mid,
      high = load_palette()$heatmap$high
    ) +
    ggplot2::labs(
      title = paste(direction, "metabolite pathways"),
      x = expression(-log[10](FDR)), y = NULL, size = "Hits", color = "Impact"
    ) +
    theme_submission(8)
  save_plot_bundle(plot, figure$stem, 140, 95)
  append_figure_map(
    figure, "M07_pathway_enrichment",
    paste(direction, "metabolite pathway enrichment"), "pathway_dotplot",
    source_path,
    path_in_project("08_code", "pipelines", "07_pathway_enrichment_plot.R"),
    140, 95
  )
}

record_session("M07_pathway_enrichment")
message("Pathway plots complete.")

