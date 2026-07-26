#!/usr/bin/env Rscript

source("08_code/R/workflow_utils.R")
cfg <- load_config()
require_packages(c("data.table", "yaml"))

metadata <- read_metadata(cfg)
modes <- list(
  positive = cfg$inputs$positive_matrix,
  negative = cfg$inputs$negative_matrix
)

inventory <- list()
processed <- list()
feature_audit <- list()

for (mode in names(modes)) {
  path <- path_in_project(modes[[mode]])
  raw <- read_intensity_matrix(path, mode, cfg)
  aligned <- align_biological_samples(raw$matrix, metadata, cfg)
  biological <- raw$matrix[!aligned$qc, , drop = FALSE]
  biological <- biological[match(metadata$matrix_sample_id, rownames(biological)), , drop = FALSE]
  prep <- preprocess_intensity(biological, cfg)
  processed[[mode]] <- prep$log

  inventory[[mode]] <- data.frame(
    mode = mode,
    input_file = relative_path(path),
    md5 = unname(tools::md5sum(path)),
    n_samples_total = nrow(raw$matrix),
    n_samples_biological = sum(!aligned$qc),
    n_samples_qc = sum(aligned$qc),
    n_features_input = ncol(raw$matrix),
    n_features_retained = ncol(prep$log),
    stringsAsFactors = FALSE
  )
  feature_audit[[mode]] <- data.frame(
    mode = mode,
    feature_id = names(prep$missing_fraction),
    missing_fraction = unname(prep$missing_fraction),
    stringsAsFactors = FALSE
  )
}

combined <- rbind(t(processed$positive), t(processed$negative))
if (anyDuplicated(rownames(combined))) stop("Combined feature IDs are duplicated.")
if (!identical(colnames(combined), metadata$matrix_sample_id)) {
  stop("Processed matrix columns do not align with metadata.")
}

metadata_path <- path_in_project("02_metadata", "sample_metadata_master.tsv")
write_tsv(metadata, metadata_path)
write_tsv(
  do.call(rbind, inventory),
  path_in_project("03_processed_data", "metabolomics", "input_inventory.tsv")
)
write_tsv(
  do.call(rbind, feature_audit),
  path_in_project("03_processed_data", "metabolomics", "feature_missingness_audit.tsv")
)
matrix_path <- path_in_project(
  "03_processed_data", "metabolomics", "matrix_cleaned",
  "combined_feature_matrix_log2.tsv"
)
write_feature_matrix(combined, matrix_path)

write_tsv(
  data.frame(
    group = names(table(metadata$group)),
    n = as.integer(table(metadata$group)),
    stringsAsFactors = FALSE
  ),
  path_in_project("03_processed_data", "metabolomics", "cohort_group_summary.tsv")
)

record_session("M00_input_audit")
message("Input audit complete.")

