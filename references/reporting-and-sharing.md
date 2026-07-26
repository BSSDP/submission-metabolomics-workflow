# Reporting and sharing

## Result-to-claim chain

Each manuscript-facing sentence should trace to an analysis ID, complete table,
source-data file, figure/table entry, method note, and a stated claim level.
Keep exploratory, confirmatory, public-data, and external-validation evidence
separate in `RESULT_LEDGER.tsv`.

## Minimum reporting

- cohort/sample counts and inclusion criteria;
- assay platform, preprocessing, QC/blank handling, and annotation confidence;
- contrast direction, adjustment set, test, effect measure, P value, and FDR;
- model task, resampling, feature-selection location, threshold rule, and
  performance with denominators;
- figure source data and exact plot script;
- versioned methods and software environment.

## Portable sharing package

Before sharing a project or using it as a new template:

1. Remove patient identifiers and paths outside the project root.
2. Keep raw-data placeholders, manifest, metadata dictionary, contrast plan,
   configuration, and small synthetic examples where permitted.
3. Include an environment specification and a command that reproduces the
   structural audit.
4. Archive superseded figures/results with a decision note rather than deleting
   the evidence trail.
5. State which outputs are illustrative, internal, independently validated, or
   exploratory.
