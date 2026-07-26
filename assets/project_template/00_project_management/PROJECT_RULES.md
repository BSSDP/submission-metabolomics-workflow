# Project rules

## Data

- `00_raw_data/` is immutable.
- Store derived matrices only under `03_processed_data/`.
- Record input paths, inclusion rules, parameters, and session information.
- Do not hard-code absolute project paths in analysis scripts.
- Register inputs, cohorts, contrasts, and clinical-variable meanings before
  running inferential or predictive analyses.

## Analyses

- Register each analysis before it contributes to a result.
- Keep each analysis independently rerunnable and removable.
- Create an `ANALYSIS_CARD.md` beside every analysis script.
- Save complete result tables, source data, logs, and Methods notes.
- Record negative and exploratory results without promoting them to main claims.

## Figures

- Draw standalone figures by default.
- Do not add panel letters.
- Do not assign manuscript or supplementary position without instruction.
- Prefix each distinct figure with the next unused sequence number.
- Prefixes record generation order only.
- Keep positive- and negative-ion PCA figures separate.
- Use only `08_code/configs/color_palette.yml` and `figure_style.yml`.
- Export PDF, SVG, PNG, and TIFF where supported.
- Store plot source data under `05_figures/figure_source_data/`.

## Tables and writing

- Generate formal tables by script.
- Update registries, methods, changelog, decisions, and risks with results.
- Avoid causal or diagnostic claims unsupported by the study design.

## Modeling

- Run modeling in the isolated Python environment.
- Keep all preprocessing and tuning inside resampling.
- Never use held-out test data for feature selection or consensus weighting.
- Treat perfect internal performance as a confounding warning.
- Learn all residualization, preprocessing, selection, tuning, calibration, and
  threshold rules inside the training resampling unit unless a rule is fixed
  externally before evaluation.
