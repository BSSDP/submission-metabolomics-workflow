---
name: submission-metabolomics-workflow
description: Scaffold, audit, analyze, and revise publication-oriented metabolomics studies. Use for untargeted LC-MS, targeted panels, or discovery-to-validation projects requiring traceable input contracts, QC, clinical and differential analysis, metabolite curation, pathway results, leakage-controlled multi-model screening, nested validation, covariate sensitivity analysis, clinical-marker integration, figures, tables, and manuscript-ready reporting.
---

# Submission Metabolomics Workflow

Build portable, submission-grade metabolomics projects. This skill preserves
the analysis-to-claim trail: immutable inputs, explicit study design, modular
code, complete result tables, figure source data, and cautious interpretation.
Use R for the supplied LC-MS analysis baseline and Python for predictive
modeling unless an established project environment dictates otherwise.

## Start

1. Inspect files without modifying raw data. Read `references/input-contracts.md`.
2. Select the closest profile and design; they are declarations, not methods:

| Profile | Appropriate use |
| --- | --- |
| `untargeted_dual_ion` | Positive/negative ion LC-MS with pooled QC |
| `untargeted_single_assay` | One feature matrix or one acquisition mode |
| `targeted_panel` | Quantified MRM/PRM or clinical analyte panel |
| `hybrid_discovery_targeted` | Untargeted discovery plus targeted confirmation |
| `external_results_only` | Auditing/visualizing exported result tables only |

Supported designs are `case_control`, `multigroup`, `ordinal_group`,
`paired_or_longitudinal`, `diagnostic`, and `prognostic`.

3. Initialize a clean project:

```powershell
python scripts/init_project.py D:\path\to\new_project --profile hybrid_discovery_targeted --design diagnostic --project-name my_study
```

4. Configure `08_code/configs/project.yml`, `02_metadata/input_manifest.tsv`,
`02_metadata/cohort_registry.tsv`, and `02_metadata/contrast_plan.tsv` before
running any module. Use only project-relative paths.
5. Run the audit first. Stop and document a decision when sample IDs, matrix
orientation, group direction, pair IDs, batch/QC labels, or annotation columns
remain ambiguous.

```powershell
Rscript 08_code/pipelines/00_audit_inputs.R
python scripts/validate_project.py D:\path\to\new_project --stage scaffold
```

The supplied `08_code/run_all.R` is a stable **dual-ion untargeted LC-MS
baseline**. Adapt or replace individual modules for targeted, paired,
longitudinal, survival, or multi-cohort studies; never run it unchanged merely
because the folder exists.

## Non-Negotiable Project Rules

Read `references/project-contract.md` before creating or moving files.

- Treat `00_raw_data/` as immutable; derived data belong under
  `03_processed_data/`.
- Register every result-producing analysis and give it an `ANALYSIS_CARD.md`.
- Store sample/feature inclusion tables, executable code, parameters, logs,
  complete statistics, figure source data, and environment details.
- Do not silently overwrite accepted outputs. Version or archive them and
  update the ledgers.
- Freeze the input matrix, target definition, contrast, and adjustment set
  before modeling or inference. Record post hoc exploration as exploratory.
- Keep discovery, internal resampling, independent validation, and external
  biological support as separate evidence layers.

## Study Design And Adjustment

Read `references/study-design-and-adjustment.md` before differential analysis,
dimension reduction, age/batch adjustment, paired testing, progression claims,
or clinical prediction.

- Declare display order separately from statistical contrasts.
- Treat ordered clinical groups as cross-sectional unless time or repeated
measurements justify a temporal claim.
- Fit covariate adjustment to the stated estimand; for predictive sensitivity
analyses, learn transforms inside training folds or from a prespecified
reference group only.
- Do not use supervised plots to claim unsupervised separation. Label PLS-DA,
sPLS-DA, LDA-based, and other supervised displays accurately.

## Analysis Modules

Read `references/analysis-workflow.md`; run only modules answering the stated
question.

1. Input audit, metadata harmonization, and technical/QC assessment.
2. Cohort table and clinical distributions.
3. Feature/analyte landscape: PCA or clearly labelled supervised displays,
   heatmaps, and prespecified contrasts.
4. Annotation and metabolite curation for untargeted data. Read
   `references/metabolite-curation.md` whenever identities are interpreted.
5. Metabolite/analyte statistics, pathway analysis, and focused biological
   interpretation.
6. Prediction or prognosis only after the matrix and design are frozen. Read
   `references/modeling-contract.md` first.
7. Figure, table, source-data, and manuscript handoff. Read
   `references/reporting-and-sharing.md` before a submission-facing update.

## Modeling

- Treat development as `screen -> lock -> validate`, not as an open-ended race
  for the largest apparent AUC. Declare the endpoint, eligible samples,
  primary metric, candidate library, representations, feature-set rule, and
  resampling plan in a model-development manifest before fitting.
- Use a compact, scientifically motivated library spanning a regularized linear
  baseline and only the flexible models justified by sample size. Compare model
  families, feature counts, and representations within repeated nested
  resampling; prefer reproducibility, calibration, and parsimony when primary
  performance is similar.
- Put imputation, scaling, residualization, feature selection, tuning,
  calibration, ensemble weights, and threshold selection inside the appropriate
  resampling unit. Treat a retained test set as untouched until the model is
  locked; do not choose a winner from its performance.
- Permit a finite, documented optimization round only after the initial screen.
  Re-evaluate every proposed representation, blend, or stack with a fresh full
  nested protocol and benchmark it against the best simple model. Never fit
  weights, transformations, or thresholds using outer-test predictions.
- Save split IDs, folds, seeds, candidate manifest, probabilities, thresholds,
  calibration, feature/parameter/winner frequencies, tuning results, failed
  fits, model objects, and figure source data.
- Report AUC together with PR AUC when imbalance matters, plus sensitivity,
  specificity, threshold, calibration, and sample/event counts appropriate to
  the task. Compare a metabolite panel, clinical marker, and combined model
  only under a common evaluation design. Distinguish optimized score thresholds
  from fixed clinical cutoffs.
- Run age or other covariate sensitivity analyses by learning the adjustment
  from each resampling-training partition or an explicitly defined training
  reference group, then applying it to the paired assessment samples. Do not
  residualize a completed score after fitting and call that model adjusted.
- Describe cell-line, public-omics, and pathway analyses as exploratory
  biological support, not diagnostic validation or causal proof.

## Figures And Completion

Read `references/visualization-contract.md` before plotting. Generate
standalone figures by default; do not add panel letters or assign a manuscript
slot without instruction. Use the global palette, write source data first, and
export PDF, SVG, PNG, and TIFF where supported.

Before calling any result complete, run:

```powershell
python scripts/validate_project.py D:\path\to\new_project --stage ready
```

Then manually verify group direction, labels, units, denominator, covariate
handling, legends, font fit, and that the Result/Figure/Table/Methods ledgers
point to the current outputs.
