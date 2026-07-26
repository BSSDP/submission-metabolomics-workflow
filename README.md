# Submission Metabolomics Workflow

**Version:** `v0.3.1`  
**Status:** fixed public release  
**Scope:** reproducible, submission-oriented metabolomics analysis and reporting framework

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21593800.svg)](https://doi.org/10.5281/zenodo.21593800)

This repository provides a configuration-driven workflow resource for
untargeted LC-MS, targeted analyte panels and discovery-to-validation
metabolomics studies. It is designed to preserve the traceable path from raw
inputs to figures, tables and manuscript claims. It is a workflow framework,
not a clinical decision-support system and not a replacement for a
study-specific statistical analysis plan.

## What is included

- a structured project template with immutable raw-input boundaries;
- input, metadata, contrast, curation and reporting contracts;
- R-oriented untargeted LC-MS baseline modules;
- a Python modeling scaffold and a diagnostic-model development manifest;
- explicit rules for leakage-controlled nested resampling, covariate
  sensitivity analysis, fixed clinical cutoffs and independent validation;
- project validation and analysis-module generation utilities; and
- example configurations for a hybrid discovery-to-targeted diagnostic study.

## Quick start

1. Create the reference Python environment described in
   [`environment/README.md`](environment/README.md).
2. Initialise a new study directory from the included template.

   ```powershell
   python scripts/init_project.py D:\path\to\new_project `
     --profile hybrid_discovery_targeted `
     --design diagnostic `
     --project-name my_metabolomics_study
   ```

3. Complete the project contract and input manifests before executing any
   analysis module. Use the worked configuration in
   [`examples/hybrid_discovery_targeted_diagnostic.yml`](examples/hybrid_discovery_targeted_diagnostic.yml)
   as a declaration template, not as an executable protocol.
4. Run the input audit and scaffold validator before creating result files.

   ```powershell
   Rscript 08_code/pipelines/00_audit_inputs.R
   python scripts/validate_project.py D:\path\to\new_project --stage scaffold
   ```

## Reproducibility contract

The workflow requires every manuscript-facing analysis to retain its input
definition, sample and feature inclusion records, parameters, split IDs,
seeds, complete statistics, figure source data and output provenance. Model
development is treated as `screen -> lock -> validate`; an independent cohort
must not be used to choose features, hyperparameters, ensemble weights or
thresholds.

The supplied base scripts are intentionally conservative starting points.
They must be adapted through project-specific, versioned configuration files
for targeted panels, paired analyses, public datasets or other designs that do
not match the dual-ion untargeted LC-MS baseline.

## Fixed release

This fixed release is identified by `VERSION` and the SHA-256 manifest in
[`release/RELEASE_MANIFEST.sha256`](release/RELEASE_MANIFEST.sha256). The
manifest excludes generated caches and project data. The release bundle can be
used for peer review or public archival unchanged; subsequent changes require
a new version, release note and manifest.

## Citation and disclosure

For the fixed `v0.3.1` release, cite DOI
[`10.5281/zenodo.21593800`](https://doi.org/10.5281/zenodo.21593800). The
concept DOI [`10.5281/zenodo.21593799`](https://doi.org/10.5281/zenodo.21593799)
always resolves to the latest archived version. [`CITATION.cff`](CITATION.cff)
contains the version-specific citation metadata. This resource documents
reproducible workflow practice; it does not itself constitute validation of a
biomarker, assay or clinical algorithm.

## Repository layout

| Path | Purpose |
| --- | --- |
| `SKILL.md` | operational instructions for the workflow resource |
| `assets/project_template/` | project scaffold and configuration templates |
| `references/` | methodological and reporting contracts |
| `scripts/` | project initialisation, validation and module utilities |
| `examples/` | non-study-specific configuration examples |
| `environment/` | reference execution environment specifications |
| `release/` | fixed-release notes and checksum manifest |
