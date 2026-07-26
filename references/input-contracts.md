# Input contracts

## Register inputs first

Complete `02_metadata/input_manifest.tsv` before a script reads any file. One
row represents one immutable source or a documented external result. Record the
assay, cohort, role, layout, ID field, checksum where feasible, and whether it
may be used for discovery, validation, or display only.

Never overwrite raw files. Store harmonized metadata and derived matrices under
`02_metadata/` and `03_processed_data/`, respectively.

## Intensity or analyte matrices

Supported layouts are `features_by_samples`, `samples_by_features`, or tidy
long-form. Declare the layout; do not infer it silently.

- Use stable feature or analyte identifiers as matrix row/column names.
- Use matrix sample IDs that match sample metadata exactly after the documented
  ID-normalization step.
- For untargeted LC-MS, declare each acquisition mode separately and prefix
  mode when combining feature IDs.
- For targeted assays, retain analyte name, assay ID, unit, lower limit of
  quantification, and any batch-correction status.
- Identify pooled QC, blanks, internal standards, batches, and injection order
  when present. Their absence is valid only when recorded.

## Sample metadata

One row per analytical sample. `sample_metadata_template.tsv` is deliberately
broader than any single study. Populate or leave fields blank; do not invent
values. At minimum specify matrix ID, display ID, cohort, primary group,
inclusion status, and exclusion reason when excluded.

Maintain a separate `cohort_registry.tsv` for discovery, internal evaluation,
independent validation, public cohort, and cell-line evidence layers. A sample
must not belong to more than one mutually exclusive model-evaluation role.

## Clinical and outcome metadata

Use `clinical_variable_dictionary.tsv` to define variable source, type, unit,
scope, allowed levels, and missing-data meaning. For paired/repeated designs,
declare pair ID and timepoint. For survival, declare time unit, event coding,
and censoring convention before fitting a model.

## Feature annotation and metabolite identities

One row per annotated feature or targeted analyte. For untargeted data map
source IDs to name, formula, InChIKey, adduct, RT, m/z, MS/MS evidence,
annotation confidence, and quality fields. Mapping coverage must be reported by
assay or ion mode. For targeted data retain calibration and quantification
metadata when available.

## Required audit checks

- sample IDs are unique, aligned, and logged after normalization;
- orientation, feature/analyte IDs, and units are declared;
- group order, contrasts, positive class, and reference class are explicit;
- cohort role, batches, QC/blank labels, and pair IDs are validated;
- zeros, missingness, infinities, duplicate IDs, and nonnumeric values are
  summarized;
- clinical levels, missingness, and denominators are enumerated;
- annotation coverage and identity confidence are visible;
- raw file hashes are recorded where practical.
