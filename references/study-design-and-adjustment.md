# Study design and adjustment

## Separate four decisions

1. **Display order**: the order used in figures and tables.
2. **Statistical contrast**: numerator, reference, eligible subset, and model.
3. **Confounder adjustment**: covariates chosen from the clinical question and
   data-generating process, before reviewing outcome results.
4. **Predictive sensitivity analysis**: a leakage-controlled test of whether a
   predictive signal persists after a stated correction.

Do not substitute one decision for another. For example, an N-to-benign-to-
malignant display order does not itself establish biological trajectory.

## Covariates

Record each candidate covariate's rationale, missingness, relationship to the
endpoint, and whether it is included in the primary model, a sensitivity model,
or only descriptive displays. Typical candidates include age, sex, batch,
collection site, acquisition run, fasting status, and medication where known.

For differential inference, use an explicitly stated design formula. For
prediction, learn preprocessing and residualization inside the training
resampling unit. Do not residualize the full analysis cohort and then quote
cross-validated performance as though no information was shared.

## Age adjustment patterns

Choose the method that answers the question; do not select one solely because
it produces the largest AUC.

- **Covariate-adjusted inference**: include age in the feature-level model.
- **Reference-group residualization**: estimate feature-age relationships in a
  prespecified reference group and subtract the estimated age component from
  all eligible samples; use the rule inside folds for prediction.
- **Within-training residualization**: estimate feature-age relationships using
  training samples only, then transform validation/test samples.
- **Age-inclusive prediction**: include age as a candidate predictor when the
  intended clinical model legitimately uses age; report the incremental value
  over age alone.
- **Matching/weighting**: use only when sample size and covariate overlap make
  the estimand defensible.

## Ordered and paired studies

For ordered clinical groups, call a pattern an ordered cross-sectional
association unless longitudinal timing or a validated trajectory model supports
more. For paired/repeated samples, use pair-aware filtering and paired or
mixed-effect analyses; include pair/timepoint fields in every source table.
