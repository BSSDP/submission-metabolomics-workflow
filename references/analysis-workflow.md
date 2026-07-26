# Analysis workflow

## Choose modules from the question

Use the project profile and design to select modules. Do not force every study
through every display or analysis.

| Module | Untargeted LC-MS | Targeted panel | Hybrid study |
| --- | --- | --- | --- |
| Input/QC audit | Required | Required | Required per assay |
| Clinical table | When metadata exist | When metadata exist | Required per cohort |
| PCA/QC landscape | Usually | Optional | Discovery assay |
| Feature differential | Usually | Not applicable | Discovery assay |
| Analyte differential | After curation | Usually | Targeted confirmation |
| Annotation curation | Required | Assay verification | Discovery assay |
| Pathway analysis | Optional | Optional | Integrative interpretation |
| Predictive modeling | Optional | Optional | Prespecify transfer/validation |

## Core sequence

1. Lock input inventory, sample inclusion, cohort roles, group order, and
   statistical contrasts.
2. Perform technical audit: QC/blank behavior, batch/run order, missingness,
   matrix orientation, and ID alignment.
3. Describe the cohort with explicit denominators and missingness.
4. Preprocess according to the assay and write all choices to the analysis card.
5. Produce global structure displays. Label supervised projections as
   supervised and do not infer progression merely from ordered group spacing.
6. Run prespecified feature/analyte contrasts with direction, adjustment set,
   and multiple-testing method recorded.
7. For untargeted work, curate feature-to-metabolite mapping before claiming
   metabolite-level results.
8. Run pathway analysis only with a declared universe and mapping rule.
9. Run prediction, prognosis, or clinical-marker comparison under a frozen
   resampling and validation plan.
10. Export complete results, source data, and current figure/table/manuscript
    ledger entries.

## Preprocessing defaults, not mandates

For a standard untargeted LC-MS matrix, a defensible starting sequence is zero
to missing conversion, feature filtering, feature-wise imputation, sample
normalization, log transform, and suitable scaling. Targeted analytes may
instead require unit checks, lower-limit treatment, batch correction, and
analyte-specific transformations. Record the biological population used to
estimate any correction.

## Multigroup, paired, and ordered studies

- Plan all pairwise and omnibus tests in `contrast_plan.tsv`.
- Display order is not an ordinal model. Use an ordinal or trend method only
  when scientifically appropriate and report it separately.
- For paired/repeated samples, preserve pair IDs through filtering and use a
  paired or mixed-effect method; never treat repeated rows as independent.
- Analyze discovery and independent validation cohorts separately unless a
  prespecified pooling/harmonization strategy exists.
