#!/usr/bin/env Rscript

source("08_code/R/workflow_utils.R")
cfg <- load_config()
require_packages(c("data.table", "ggplot2"))

normalize_name <- function(x) {
  x <- trimws(as.character(x))
  x <- sub(";\\s*CE[0-9].*$", "", x, ignore.case = TRUE)
  x <- gsub("\\s+", " ", x)
  x[x == ""] <- NA_character_
  x
}

normalize_name_key <- function(x) {
  x <- tolower(normalize_name(x))
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT")
  gsub("[^a-z0-9]+", "", x)
}

normalize_formula <- function(x) {
  x <- toupper(gsub("\\s+", "", trimws(as.character(x))))
  x[x == ""] <- NA_character_
  x
}

normalize_inchikey <- function(x) {
  x <- toupper(trimws(as.character(x)))
  x[!grepl("^[A-Z]{14}-[A-Z]{10}-[A-Z]$", x)] <- NA_character_
  x
}

append_reason <- function(current, addition) {
  ifelse(
    is.na(current) | !nzchar(current),
    addition,
    paste(current, addition, sep = "; ")
  )
}

truth_value <- function(x) {
  tolower(trimws(as.character(x))) %in% c("true", "yes", "y", "1", "assigned", "matched")
}

read_mapping <- function(path, mode) {
  raw <- read_any_table(path)
  columns <- cfg$annotation$columns
  required_keys <- c("feature_id", "name")
  missing_keys <- required_keys[
    !vapply(required_keys, function(key) columns[[key]] %in% names(raw), logical(1))
  ]
  if (length(missing_keys)) {
    stop("Mapping lacks required configured fields: ", paste(missing_keys, collapse = ", "))
  }
  get_column <- function(key, default = NA) {
    source <- columns[[key]]
    if (!is.null(source) && source %in% names(raw)) raw[[source]] else
      rep(default, nrow(raw))
  }
  fill <- suppressWarnings(as.numeric(get_column("fill_fraction")))
  if (identical(cfg$annotation$fill_fraction_scale, "percent")) fill <- fill / 100
  feature_raw <- trimws(as.character(get_column("feature_id")))
  name <- normalize_name(get_column("name"))
  formula <- normalize_formula(get_column("formula"))
  inchikey <- normalize_inchikey(get_column("inchikey"))
  normalized_name <- normalize_name_key(name)
  identity_key_initial <- ifelse(
    !is.na(inchikey),
    paste0("IK:", inchikey),
    paste0("NF:", normalized_name, "|", formula)
  )
  output <- data.frame(
    mode = mode,
    source_feature_id = paste0(mode, "_", feature_raw),
    raw_feature_id = feature_raw,
    identity_key_initial = identity_key_initial,
    identity_key = identity_key_initial,
    identity_source = ifelse(!is.na(inchikey), "INCHIKEY", "normalized_name_formula"),
    metabolite_name = name,
    normalized_name = normalized_name,
    formula = formula,
    inchikey = inchikey,
    smiles = as.character(get_column("smiles")),
    ontology = as.character(get_column("ontology")),
    fill_fraction = fill,
    msms_assigned = truth_value(get_column("msms_assigned")),
    total_score = suppressWarnings(as.numeric(get_column("total_score"))),
    rt_matched = truth_value(get_column("rt_matched")),
    mz_matched = truth_value(get_column("mz_matched")),
    msms_matched = truth_value(get_column("msms_matched")),
    stringsAsFactors = FALSE
  )
  output$name_formula_signature <- ifelse(
    !is.na(output$normalized_name) & nzchar(output$normalized_name) &
      !is.na(output$formula) & nzchar(output$formula),
    paste(output$normalized_name, output$formula, sep = "|"),
    NA_character_
  )
  output$identity_review_flag <- FALSE
  output$identity_review_reason <- NA_character_
  output$feature_annotation_conflict <- FALSE
  output$annotated <- !is.na(output$metabolite_name) &
    nzchar(output$normalized_name) & output$normalized_name != "unknown"
  output$name_length <- nchar(output$metabolite_name)
  output$punctuation_count <- nchar(gsub("[[:alnum:] ]", "", output$metabolite_name))
  output$strange_name_flag <- (
    output$name_length >= cfg$annotation$strange_name_length_min |
      output$punctuation_count >= cfg$annotation$strange_name_punctuation_min
  )
  output$lipid_shorthand_flag <- grepl(
    "^(FA\\s*\\d+[:_]\\d+(\\+\\d+O)?|LPC|LPE|LYSOPC|LYSOPE|PC\\s*\\()",
    toupper(trimws(output$metabolite_name))
  )
  review_text <- paste(output$metabolite_name, output$ontology)
  output$drug_contaminant_review_flag <- grepl(
    "drug|pharmaceutical|xenobiotic|pollutant|plasticizer|detergent|surfactant",
    review_text, ignore.case = TRUE
  )
  output
}

resolve_identity_keys <- function(mapping) {
  # Bridge only unambiguous name+formula annotations to one InChIKey-backed identity.
  signatures <- unique(mapping$name_formula_signature[!is.na(mapping$name_formula_signature)])
  for (signature in signatures) {
    selected <- !is.na(mapping$name_formula_signature) &
      mapping$name_formula_signature == signature
    known_keys <- unique(mapping$inchikey[selected & !is.na(mapping$inchikey)])
    unkeyed <- selected & is.na(mapping$inchikey)
    if (length(known_keys) == 1L && any(unkeyed)) {
      mapping$identity_key[unkeyed] <- paste0("IK:", known_keys[[1]])
      mapping$identity_source[unkeyed] <- "bridged_name_formula_to_INCHIKEY"
    } else if (length(known_keys) > 1L) {
      mapping$identity_review_flag[selected] <- TRUE
      mapping$identity_review_reason[selected] <- append_reason(
        mapping$identity_review_reason[selected],
        "multiple_InChIKeys_for_normalized_name_formula"
      )
      unresolved <- unkeyed
      mapping$identity_key[unresolved] <- paste0(
        "UNRESOLVED:", signature, "|", mapping$source_feature_id[unresolved]
      )
      mapping$identity_source[unresolved] <- "unresolved_name_formula_multiple_INCHIKEY"
    }
  }

  name_only <- mapping$annotated & is.na(mapping$inchikey) &
    is.na(mapping$name_formula_signature)
  if (any(name_only)) {
    mapping$identity_key[name_only] <- paste0(
      "NAME_ONLY:", mapping$normalized_name[name_only], "|",
      mapping$source_feature_id[name_only]
    )
    mapping$identity_source[name_only] <- "name_only_manual_review"
    mapping$identity_review_flag[name_only] <- TRUE
    mapping$identity_review_reason[name_only] <- append_reason(
      mapping$identity_review_reason[name_only],
      "missing_INCHIKEY_or_formula"
    )
  }

  by_feature <- split(seq_len(nrow(mapping)), mapping$source_feature_id)
  for (indices in by_feature) {
    keys <- unique(mapping$identity_key[indices][!is.na(mapping$identity_key[indices])])
    if (length(keys) > 1L) {
      mapping$feature_annotation_conflict[indices] <- TRUE
      mapping$identity_review_flag[indices] <- TRUE
      mapping$identity_review_reason[indices] <- append_reason(
        mapping$identity_review_reason[indices],
        "one_source_feature_maps_to_multiple_identities"
      )
    }
  }
  mapping
}

attach_overrides <- function(mapping, overrides, mode) {
  mapping$override_action <- NA_character_
  mapping$override_name <- NA_character_
  mapping$override_reason <- NA_character_
  mapping$override_feature_exact <- FALSE
  mapping$override_identity_exact <- FALSE
  if (!nrow(overrides)) return(mapping)

  for (i in seq_len(nrow(overrides))) {
    match_mode <- is.na(overrides$mode[i]) || !nzchar(overrides$mode[i]) ||
      overrides$mode[i] == mode
    feature_value <- as.character(overrides$feature_id[i])
    identity_value <- as.character(overrides$identity_key[i])
    has_feature <- !is.na(feature_value) && nzchar(feature_value)
    has_identity <- !is.na(identity_value) && nzchar(identity_value)
    match_feature <- if (has_feature) {
      mapping$source_feature_id == feature_value | mapping$raw_feature_id == feature_value
    } else {
      rep(FALSE, nrow(mapping))
    }
    match_identity <- if (has_identity) {
      mapping$identity_key == identity_value
    } else {
      rep(FALSE, nrow(mapping))
    }
    selected <- match_mode & (match_feature | match_identity)
    mapping$override_action[selected] <- overrides$action[i]
    mapping$override_name[selected] <- overrides$common_name[i]
    mapping$override_reason[selected] <- overrides$reason[i]
    mapping$override_feature_exact[selected & match_feature] <- TRUE
    mapping$override_identity_exact[selected & match_identity] <- TRUE
  }
  mapping
}

rank_mapping <- function(mapping, cfg) {
  data <- data.table::as.data.table(mapping)
  direction <- cfg$annotation$fill_fraction_direction %||% "higher_is_better"
  if (!direction %in% c("higher_is_better", "lower_is_better")) {
    stop("annotation.fill_fraction_direction must be higher_is_better or lower_is_better")
  }
  data[, fill_rank := ifelse(
    is.finite(fill_fraction),
    if (direction == "higher_is_better") -fill_fraction else fill_fraction,
    Inf
  )]
  data[, score_rank := ifelse(is.finite(total_score), total_score, -Inf)]
  data[, manual_priority := !is.na(override_action) & override_action == "prefer_feature"]
  data.table::setorder(
    data, identity_key, -manual_priority, fill_rank, -msms_assigned, -score_rank,
    -rt_matched, -mz_matched, -msms_matched, source_feature_id
  )
  data[, n_candidate_features := .N, by = identity_key]
  data[, representative_rank := seq_len(.N), by = identity_key]
  as.data.frame(data)
}

overrides_path <- path_in_project("02_metadata", "curation_overrides.tsv")
overrides <- read_any_table(overrides_path)
feature_matrix <- read_feature_matrix(path_in_project(
  "03_processed_data", "metabolomics", "matrix_cleaned",
  "combined_feature_matrix_log2.tsv"
))

jobs <- list(
  positive = cfg$inputs$mapping_positive,
  negative = cfg$inputs$mapping_negative
)
clean_mappings <- list()
flow_tables <- list()

output_dir <- path_in_project(
  "03_processed_data", "metabolomics", "matrix_annotated_metabolite_level"
)
ensure_dir(output_dir)

for (mode in names(jobs)) {
  mapping <- read_mapping(path_in_project(jobs[[mode]]), mode)
  mapping <- resolve_identity_keys(mapping)
  mapping <- attach_overrides(mapping, overrides, mode)
  mapping$present_in_matrix <- mapping$source_feature_id %in% rownames(feature_matrix)
  manual_conflict_resolution <- mapping$feature_annotation_conflict &
    !is.na(mapping$override_action) & mapping$override_action == "prefer_feature" &
    mapping$override_feature_exact & mapping$override_identity_exact
  manual_conflict_resolution[is.na(manual_conflict_resolution)] <- FALSE
  eligible <- mapping$annotated & mapping$present_in_matrix &
    (!mapping$feature_annotation_conflict | manual_conflict_resolution)
  eligible[is.na(eligible)] <- FALSE
  ranked <- rank_mapping(mapping[eligible, , drop = FALSE], cfg)
  deduplicated <- ranked[ranked$representative_rank == 1, , drop = FALSE]

  auto_exclude <- rep(FALSE, nrow(deduplicated))
  reason <- rep(NA_character_, nrow(deduplicated))
  if (isTRUE(cfg$annotation$auto_exclude_lipid_shorthand)) {
    auto_exclude <- auto_exclude | deduplicated$lipid_shorthand_flag
    reason[deduplicated$lipid_shorthand_flag] <- "lipid_shorthand"
  }
  if (isTRUE(cfg$annotation$auto_exclude_strange_names)) {
    auto_exclude <- auto_exclude | deduplicated$strange_name_flag
    reason[deduplicated$strange_name_flag & is.na(reason)] <- "strange_name"
  }
  override_exclude <- !is.na(deduplicated$override_action) &
    deduplicated$override_action == "exclude"
  override_keep <- !is.na(deduplicated$override_action) &
    deduplicated$override_action == "keep"
  exclude <- auto_exclude | override_exclude
  exclude[override_keep] <- FALSE
  reason[override_exclude] <- deduplicated$override_reason[override_exclude]
  deduplicated$final_action <- ifelse(exclude, "exclude", "keep")
  deduplicated$exclusion_reason <- reason
  deduplicated$common_name <- ifelse(
    !is.na(deduplicated$override_name) & nzchar(deduplicated$override_name),
    deduplicated$override_name,
    deduplicated$metabolite_name
  )
  clean <- deduplicated[deduplicated$final_action == "keep", , drop = FALSE]
  clean_mappings[[mode]] <- clean

  duplicate_audit <- ranked[ranked$n_candidate_features > 1, , drop = FALSE]
  review_queue <- mapping[
    mapping$strange_name_flag |
      mapping$drug_contaminant_review_flag |
      mapping$identity_review_flag |
      mapping$feature_annotation_conflict |
      (mapping$annotated & mapping$present_in_matrix & !eligible),
    ,
    drop = FALSE
  ]

  write_tsv(mapping, file.path(output_dir, paste0(mode, "_mapping_normalized.tsv")))
  write_tsv(ranked, file.path(output_dir, paste0(mode, "_mapping_quality_ranked.tsv")))
  write_tsv(
    duplicate_audit,
    file.path(output_dir, paste0(mode, "_duplicate_identity_audit.tsv"))
  )
  write_tsv(deduplicated, file.path(output_dir, paste0(mode, "_mapping_curated.tsv")))
  write_tsv(clean, file.path(output_dir, paste0(mode, "_mapping_clean.tsv")))
  write_tsv(
    review_queue,
    file.path(output_dir, paste0(mode, "_manual_review_queue.tsv"))
  )

  flow <- data.frame(
    mode = mode,
    stage = factor(
      c("Mapping rows", "Annotated and measured", "Deduplicated", "Retained"),
      levels = c("Mapping rows", "Annotated and measured", "Deduplicated", "Retained")
    ),
    n = c(
      nrow(mapping),
      sum(mapping$annotated & mapping$present_in_matrix),
      nrow(deduplicated),
      nrow(clean)
    )
  )
  flow_tables[[mode]] <- flow
  figure <- reserve_figure(
    paste0(mode, "_annotation_filtering_flow"),
    "metabolite_annotation_filtering"
  )
  source_path <- path_in_project(
    "05_figures", "figure_source_data",
    paste0(figure$prefix, "_", figure$slug, "_source.tsv")
  )
  write_tsv(flow, source_path)
  plot <- ggplot2::ggplot(flow, ggplot2::aes(stage, n, group = 1)) +
    ggplot2::geom_line(linewidth = 0.7, color = load_palette()$ion_modes[[mode]]) +
    ggplot2::geom_point(size = 2.2, color = load_palette()$ion_modes[[mode]]) +
    ggplot2::geom_text(ggplot2::aes(label = n), vjust = -0.7, size = 2.5) +
    ggplot2::labs(
      title = paste(tools::toTitleCase(mode), "ion annotation filtering"),
      x = NULL, y = "Features or identities"
    ) +
    theme_submission(8) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 20, hjust = 1))
  save_plot_bundle(plot, figure$stem, 110, 80)
  append_figure_map(
    figure, "M05_annotation_filter",
    paste(mode, "ion annotation filtering"), "filtering_flow",
    source_path,
    path_in_project("08_code", "pipelines", "05_metabolite_annotation_filter.R"),
    110, 80
  )
}

combined_mapping <- do.call(rbind, clean_mappings)
combined_mapping$biological_identity_key <- combined_mapping$identity_key
cross_mode_unique_modes <- vapply(
  split(combined_mapping$mode, combined_mapping$biological_identity_key),
  function(x) length(unique(x)),
  integer(1)
)
combined_mapping$cross_mode_duplicate_flag <-
  cross_mode_unique_modes[combined_mapping$biological_identity_key] > 1L
combined_mapping$metabolite_id <- paste0(
  combined_mapping$mode, "::", combined_mapping$identity_key
)
display_base <- paste0(combined_mapping$common_name, " [", combined_mapping$mode, "]")
display_collision <- ave(display_base, display_base, FUN = length) > 1L
combined_mapping$display_name <- ifelse(
  display_collision,
  paste0(display_base, " {", combined_mapping$source_feature_id, "}"),
  display_base
)
selected <- feature_matrix[combined_mapping$source_feature_id, , drop = FALSE]
rownames(selected) <- combined_mapping$metabolite_id
output_matrix <- data.frame(
  metabolite_id = combined_mapping$metabolite_id,
  biological_identity_key = combined_mapping$biological_identity_key,
  common_name = combined_mapping$common_name,
  display_name = combined_mapping$display_name,
  mode = combined_mapping$mode,
  cross_mode_duplicate_flag = combined_mapping$cross_mode_duplicate_flag,
  source_feature_id = combined_mapping$source_feature_id,
  selected,
  check.names = FALSE,
  stringsAsFactors = FALSE
)
write_tsv(
  output_matrix,
  file.path(output_dir, "metabolite_matrix_combined_common_name.tsv")
)
write_tsv(
  combined_mapping,
  file.path(output_dir, "metabolite_to_feature_lineage.tsv")
)
cross_mode_audit <- data.table::as.data.table(combined_mapping)[,
  .(
    common_names = paste(sort(unique(common_name)), collapse = "; "),
    modes = paste(sort(unique(mode)), collapse = "; "),
    n_modes = data.table::uniqueN(mode),
    n_retained_measurements = .N,
    source_feature_ids = paste(sort(unique(source_feature_id)), collapse = "; ")
  ),
  by = biological_identity_key
]
cross_mode_audit[, cross_mode_duplicate_flag := n_modes > 1L]
write_tsv(
  as.data.frame(cross_mode_audit),
  file.path(output_dir, "cross_mode_biological_identity_audit.tsv")
)

for (mode in names(clean_mappings)) {
  keep <- output_matrix$mode == mode
  write_tsv(
    output_matrix[keep, , drop = FALSE],
    file.path(output_dir, paste0("metabolite_matrix_", mode, "_common_name.tsv"))
  )
}

record_session("M05_annotation_filter")
message("Metabolite annotation, filtering, and matrices complete.")
