# Metabolite curation

## Identity

Normalize whitespace and trivial suffixes first. Use:

1. valid full InChIKey;
2. normalized common name plus normalized molecular formula when InChIKey is
   missing or a documented stereochemical alias is intentionally collapsed.

Keep the original strings, candidate key, final key, and chosen identity source.
Do not auto-deduplicate name-only annotations lacking both a valid InChIKey and
a molecular formula. When an unkeyed annotation shares normalized name and
formula with exactly one InChIKey-backed identity, it may be bridged to that
identity and must be labelled as such. Multiple candidate InChIKeys or multiple
identities for one raw feature require manual review.

## Representative feature ranking

Rank within ion mode and identity using annotation evidence only:

- configured fill/coverage priority;
- MS/MS assigned;
- higher total score;
- RT/mz/MSMS match support;
- stronger dot-product evidence;
- deterministic feature ID tie-break.

The direction of the configured fill/coverage field must be explicit. The
template uses `higher_is_better` because `Fill %` is treated as observed
coverage. Use `lower_is_better` only when the source field is a missingness or
imputation fraction.

Do not use group P values, fold changes, model importance, or abundance to
choose the representative feature.

## Exclusion classes

Review and record:

- explicit pharmaceutical/xenobiotic molecules unlikely to be endogenous;
- known contaminants, plasticizers, detergents, and analytical artifacts;
- implausibly long or malformed annotation names;
- lipid-class shorthand such as `FA x:y+zO`, `LPC`, `LPE`, `LysoPC`, `LysoPE`,
  and generic `PC` species when the project small-molecule boundary excludes
  them.

Named conventional fatty acids are not automatically equivalent to shorthand
lipid classes. Endogenous metabolites that are also used therapeutically must
not be removed solely because they appear in a drug database.

## Review gates

- Produce retained, excluded, and ambiguous-review tables.
- Audit excluded rows for plausible endogenous metabolites.
- Audit retained rows for obvious drugs, pollutants, malformed names, and
  unresolved duplicates.
- Use exact overrides with action, reason, evidence, reviewer, and date.
- Supported actions are `keep`, `exclude`, and `prefer_feature`; the latter
  requires exact mode, feature ID, and identity key.
- Keep the override table reversible and under version control.
- For a raw feature with conflicting identities, use an exact `feature_id` plus
  `identity_key` override and `prefer_feature` only after manual review.

## Output

For each mode retain:

- complete normalized mapping;
- identity-bridge, conflict, and duplicate-identity audits;
- duplicate audit;
- quality-ranked mapping;
- deduplicated mapping;
- exclusion candidates;
- final clean mapping;
- metabolite-by-sample matrix;
- metabolite-to-feature lineage.
- cross-mode biological-identity audit.

For the combined matrix retain mode in the row ID and provide both stable-ID and
common-name versions. Keep positive/negative measurements separate, but export
a cross-mode biological-identity audit for enrichment/modeling decisions;
never let the same identity count twice in a pathway hit universe by accident.

## Targeted panels

For targeted assays, retain the prespecified analyte list and assay identifier.
Do not relabel quantified analytes as untargeted "features" in manuscript text:
use *analyte* for targeted measurement and reserve *metabolite* for biological
interpretation when identity is established.

Do not apply untargeted representative-feature ranking to targeted analytes.
When multiple transitions or assays quantify one analyte, select the reporting
assay using a prespecified calibration/QC rule and retain all transition-level
evidence in the assay audit.
