# Project contract

## Required top-level structure

```text
project_root/
  00_project_docs/
  00_project_management/
  00_raw_data/
  02_metadata/
  03_processed_data/
  04_analysis/
  05_figures/
  06_tables/
  07_manuscript/
  08_code/
  09_logs/
  10_archive/
  ref/
  python_env/
```

`00_raw_data` is read-only. Derived matrices belong in `03_processed_data`.
Unassigned figures belong in `05_figures/unassigned`; source tables belong in
`05_figures/figure_source_data`.

## Required management files

- `PROJECT_RULES.md`
- `MANUSCRIPT_STORYLINE.md`
- `ANALYSIS_REGISTRY.tsv`
- `RESULT_LEDGER.tsv`
- `FIGURE_MAP.tsv`
- `TABLE_MAP.tsv`
- `METHODS_LEDGER.md`
- `CHANGELOG.md`
- `DECISION_LOG.md`
- `REVIEWER_RISK_LEDGER.md`
- `TODO_MASTER.md`
- `PROFILE_SELECTION.md`

## Analysis module

Create one folder per analysis:

```text
04_analysis/Rxx_result_name/Rxx_Axxx_short_name/
  ANALYSIS_CARD.md
  Rxx_Axxx_short_name_v001.R
  outputs/
  source_data/
  figures/
  logs/
```

The card must state the question, inputs, inclusion rules, method, parameters,
outputs, linked result, interpretation boundary, caveats, decision status, and
update history. For predictive analyses also state the target, positive class,
cohort role, resampling unit, and where every learned transform was fit.

## Traceability

For every reported result retain:

- immutable input paths and checksums where practical;
- sample and feature inclusion tables;
- executable script and declared environment;
- complete statistical table, not only significant rows;
- figure source data;
- PDF/SVG/PNG/TIFF output as applicable;
- Methods note and session information;
- registry and ledger entries;
- decision and reviewer-risk notes when judgment is involved.

## Version behavior

- Use `v001`, `v002`, and so on for meaningful revisions.
- Do not overwrite accepted results silently.
- Archive superseded outputs or record their removal explicitly.
- A curation change invalidates all downstream metabolite-level results until
  rebuilt.
- A changed inclusion table, endpoint, contrast, adjustment rule, or feature
  panel invalidates any linked inference/model result until rebuilt.

## Result-first rule

Do not add an analysis merely because a method exists. State the biological or
clinical question first. Mark unsupported exploratory work as exploratory or
archive it without forcing it into the manuscript.
