#!/usr/bin/env Rscript

scripts <- c(
  "08_code/pipelines/00_audit_inputs.R",
  "08_code/pipelines/01_clinical_table1.R",
  "08_code/pipelines/02_pca.R",
  "08_code/pipelines/03_heatmaps.R",
  "08_code/pipelines/04_feature_differential.R",
  "08_code/pipelines/05_metabolite_annotation_filter.R",
  "08_code/pipelines/06_metabolite_differential.R",
  "08_code/pipelines/07_pathway_enrichment_plot.R"
)

for (script in scripts) {
  message("Running ", script)
  status <- system2(file.path(R.home("bin"), "Rscript"), script)
  if (!identical(status, 0L)) stop("Pipeline failed: ", script)
}

message("Stable R workflow complete.")

