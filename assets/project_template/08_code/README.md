# Code profiles

The bundled R scripts are a tested starting point for dual-ion untargeted
LC-MS. They assume positive/negative matrices and a common clinical metadata
table. Before using another profile, duplicate only the required module(s),
register the new analysis, and adapt the input/contrast logic rather than
forcing targeted, paired, longitudinal, or external-only data through this
baseline.

Use `project.yml`, `input_manifest.tsv`, `cohort_registry.tsv`, and
`contrast_plan.tsv` as the source of truth. The template is intentionally
generic; it is not a substitute for a study-specific statistical plan.
