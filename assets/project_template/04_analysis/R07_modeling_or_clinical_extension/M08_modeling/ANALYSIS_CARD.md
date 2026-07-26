# Analysis card

## Analysis ID
M08

## Question
Which curated metabolites consistently contribute to internal classification?

## Method
The bundled Python script is an exploratory screen: stratified held-out
evaluation, repeated cross-validation on the training partition,
in-resampling preprocessing/tuning, diverse classifiers, and CV-weighted
consensus ranking. Do not use its held-out result to choose a final model.

For manuscript-facing internal performance, define a finite candidate manifest
and use repeated nested CV. Fit all preprocessing, feature selection,
residualization, tuning, calibration, ensemble weights, and threshold selection
inside the applicable training partition. See `references/modeling-contract.md`.

## Outputs
Split table, predictions, performance, models, importance tables, integrated
volcano, standalone single-feature ROC plots, environment, and runtime.

## Caveat
This exploratory screen does not estimate final internal performance. Internal
discrimination from a locked nested protocol is still not independent
diagnostic validation.
