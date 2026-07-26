# Modeling contract

## Purpose and terms

Use this contract for diagnostic, prognostic, or classification models derived
from untargeted features, curated metabolites, targeted analytes, clinical
markers, or their combinations. Treat a model as a reproducible pipeline, not
only an algorithm: eligibility, feature representation, preprocessing, feature
rule, classifier, calibration, and threshold are all parts of the model.

Use three evidence layers and label them consistently:

1. **Exploratory screen**: compare a finite candidate set to learn which model
   families and feature representations are credible.
2. **Internal performance estimation**: use repeated nested resampling or an
   untouched held-out test set after the full pipeline is locked.
3. **Independent validation**: run the exact locked pipeline in a distinct
   cohort with compatible measurements. External analyte measurement alone is
   not validation of a different discovery-derived model.

## Create a model-development manifest before fitting

Write a machine-readable configuration and an `ANALYSIS_CARD.md` that name:

- endpoint, positive class, eligible samples, cohort role, and intended use;
- primary metric and secondary metrics; use PR AUC as a co-primary or primary
  metric when class imbalance makes ROC AUC insufficient;
- split unit and grouping constraints, such as repeated samples, batches,
  centres, families, or paired specimens;
- candidate model families, finite parameter grids, feature-count grid, and
  any fixed targeted panel;
- allowed feature representations and covariate sensitivity analyses;
- selection rule, tie-break rule, resampling folds/repeats, seed, and stopping
  rule for any focused optimization round.

Record every deviation. Exploration is acceptable when it is labelled as such;
unlogged model fishing is not.

## Use the development sequence: screen, lock, validate

### 1. Screen a compact, diverse library

Always include a regularized linear baseline, usually ridge, lasso, or elastic
net logistic regression. Add only models that match the data size and intended
claim:

| Model family | Typical use and constraint |
| --- | --- |
| Penalized logistic regression, LDA | Default interpretable baselines for small to moderate cohorts. |
| PLS-DA | Supervised latent-variable baseline; tune components inside resampling and label it supervised. |
| Linear or radial SVM, naive Bayes, kNN, QDA | Compact nonlinear or distributional alternatives; use restricted grids. |
| Random forest, extra trees, boosting | Consider only with enough effective sample size and a shallow, bounded tuning grid. |
| Gaussian process or small neural network | Optional nonlinear view; justify the representation and control complexity. |
| Probability blend or stacking | Use only after complementary base learners show credible, resampling-stable value. |

Do not present a long library as proof that the most complex model is best. A
simple model with similar discrimination, better calibration, and lower
instability is usually the stronger publication choice.

### 2. Use valid representations

Treat raw signal and derived representations as separate, predeclared candidate
views. Examples include log-transformed absolute intensity, targeted
concentration, and composition-aware within-sample relative abundance. Use a
composition-aware transformation only when it preserves the biological question
and handle zeroes within each training partition.

Do not mix representations merely to maximize a result. State why each view
might capture a distinct biological or analytical property, and record the
exact transformation.

### 3. Estimate internal performance with nested resampling

For small or moderate discovery cohorts, use repeated stratified nested CV when
there is no genuinely untouched development test set. For every outer fold:

```text
outer training samples
  -> inner resampling: fit preprocessing, residualization, feature selection,
     model tuning, calibration, blend weights, and threshold selection
  -> select one complete pipeline under the declared rule
  -> refit that pipeline on the outer training samples only
  -> predict the outer assessment samples once
```

Repeat this process across the declared folds and seeds. The outer assessment
samples must not influence model choice, feature choice, blend weights,
calibration, or threshold. If a retained test set is used instead, perform all
screening and locking with the training data only, then evaluate that test set
once.

## Select and lock the model

Select from inner-resampling summaries, never from outer-test or retained-test
performance. Rank candidates by the declared primary metric, then use the
prespecified tie-breakers: PR AUC where relevant, calibration, performance
dispersion across repeats, feature-selection stability, and parsimony.

Report model-win frequency across outer folds/repeats rather than implying that
one fragile winner is definitive. Lock the following before independent
validation: input analytes/features, representation, preprocessing, selected
feature rule, algorithm, tuned parameters, probability calibration, score
formula, and operating threshold.

## Handle feature sets explicitly

Distinguish these branches in code and reporting:

- **Fixed panel**: the analytes are prespecified and every fold uses the same
  set. This is appropriate for a targeted assay or a locked discovery panel.
- **Adaptive panel**: variance filtering, ranking, RFE, or sparse selection is
  repeated entirely inside each training partition. Report selected-feature
  frequency and the final locked rule.
- **Feature-count screen**: compare a declared, finite count grid inside inner
  resampling. Select the count with the same rule used for model family choice.

Never choose a panel using all samples and then describe resampling of only the
classifier as full validation.

## Conduct focused optimization without post hoc overfitting

After an initial screen, permit one bounded optimization phase when it asks a
specific methodological question, for example whether a composition-aware view
adds information beyond raw intensity, or whether two complementary probability
models improve a simple baseline.

Before this phase, create a candidate manifest listing every new view, base
learner, blend-weight grid, and decision rule. Re-run a fresh full nested
evaluation for all candidates. Do not:

- inspect outer-test predictions and then invent a new transformation;
- tune blend weights, meta-models, or thresholds on pooled out-of-fold or test
  predictions that include the sample being assessed;
- keep extending the candidate list until a desired P value or AUC appears.

For a probability ensemble, generate base-learner predictions only from inner
out-of-fold fits within each outer training partition. Estimate blend weights,
meta-model parameters, calibration, and threshold from those inner predictions;
then apply the locked ensemble to the outer assessment partition. Benchmark the
ensemble against each base learner and retain it only when the improvement is
stable and the added complexity is scientifically defensible.

## Test covariate robustness correctly

If age, batch, sex, medication, or another variable is imbalanced, specify
whether the question is confounding control, clinical augmentation, or a
sensitivity analysis. These are distinct analyses.

- For residualization sensitivity analysis, fit the covariate-to-analyte model
  within each resampling-training partition, optionally using a prespecified
  reference group contained in that partition. Apply those learned coefficients
  to the paired training and assessment data before model fitting.
- Re-run the complete model-development protocol on residualized inputs and
  compare it with the unadjusted pipeline under identical folds and seeds.
- Do not subtract age effects from a completed model score and call the original
  model age adjusted.
- If adding age as a predictor, label it a clinical-plus-metabolite model. Do
  not use this result alone to claim that the metabolite signal is independent
  of age.

## Compare clinical markers and sequential strategies fairly

Evaluate panel alone, marker alone, and panel-plus-marker models with the same
eligible samples, outer folds, repeats, preprocessing rules, and metrics. A
fixed clinical cutoff, such as a guideline marker threshold, is a decision rule
and must be reported separately from a probability threshold optimized in
training resampling.

For a sequential strategy, generate the first-step panel score out of fold for
the samples used to train the second step. Within each outer fold of the second
step, the first-step scorer must be fitted using only data available in that
outer training partition. Do not use a score fitted on the full cohort as a
second-step predictor during internal evaluation.

## Save a complete audit trail

Write the following, even when a candidate fails:

- `model_development_manifest.yml` and sample inclusion/exclusion table;
- fold and repeat assignments, seed, package versions, runtime, and failures;
- model-screening summary with model family, representation, feature rule,
  tuning grid, primary/secondary metrics, calibration, and selection status;
- per-repeat and per-fold metrics, inner selection tables, winner frequency,
  parameter frequency, and feature-selection frequency;
- outer-fold or held-out predictions with probabilities, thresholds, and score
  components; save ROC, PR, calibration, decision, and score-distribution
  source-data tables separately from rendered figures;
- final locked score formula and model object, plus an exact independent-
  validation input contract when validation is available.

Report ROC AUC, PR AUC where appropriate, sensitivity, specificity, PPV, NPV,
F1, threshold, confidence intervals where supported, and all denominators. For
repeated nested CV, clearly state whether a metric summarizes fold-level values
or pooled out-of-fold predictions; do not conflate the two.

## Interpret with discipline

Internal discrimination estimates performance in the observed cohort. It does
not establish a deployable diagnostic test. Use terms such as "internally
evaluated" or "exploratory model development" until an independent cohort has
tested the exact locked pipeline.

If covariate-residualized performance remains similar, describe it as a
sensitivity result supporting robustness to the specified adjustment rule. It
does not prove all confounding has been eliminated. If a complex model or
ensemble wins only marginally, report the simple benchmark alongside it and do
not overstate its advantage.
