# Reference environment

`environment.yml` defines the lightweight Python reference environment for the
template utilities and modeling scaffold. `requirements-modeling-lock.txt`
records a pinned reference set of core Python versions for the modeling
scaffold. It is intentionally limited to packages for which a reproducible
version record is available.

Create the reference environment with:

```powershell
conda env create -f environment/environment.yml
conda activate submission-metabolomics-workflow
```

The R LC-MS modules should be executed in a project-specific R environment.
Before public release, each study code package should add an `renv.lock` or
equivalent R package snapshot generated from the environment used to produce
the reported figures and tables.
