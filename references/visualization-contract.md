# Visualization contract

## Global defaults

- Standalone figures only unless a combined plot is explicitly requested.
- No automatic `a`, `b`, or `c` labels.
- No automatic main/supplementary assignment.
- Numeric filename prefix means generation order only.
- Each distinct figure gets a unique prefix; alternate formats share it.
- White background, restrained palette, Arial/Helvetica, minimal grid.
- Use colors from `08_code/configs/color_palette.yml`.
- Preserve the same biological group color across all figures.
- State whether a projection is unsupervised or supervised in its title/legend
  and source-data metadata.

## Exports

- Vector: PDF and SVG.
- Raster: PNG and TIFF at 600 dpi when supported.
- Write source data before rendering the plot.
- Save width, height, DPI, script, and source path in `FIGURE_MAP.tsv`.

## Clinical displays

- Table 1 follows a three-line-table structure: characteristic rows, group
  summaries, P value, and missingness note.
- Continuous variables: individual points plus a compact distribution summary.
- Categorical variables: sample-level counts or fractions with denominators.
- Disease-only variables exclude controls from the denominator and state this
  in source data and legend.

## PCA

- Draw positive and negative ion modes separately.
- Provide QC-inclusive PCA for technical stability and biological-only PCA for
  group separation.
- Use confidence ellipses only when a group has enough observations.
- Axis labels report explained variance.
- Do not force equal coordinates unless requested.
- Export scores, loadings, variance, retained features, and QC CV summaries.

## Supervised projections

- Use PLS-DA or sPLS-DA only when group labels are the declared supervision
  target; do not encode a desired biological ordering as the target.
- State the method, input matrix, scaling, component-selection rule, and group
  labels used for training.
- Plot group points, centroids, and any centroid connectors only as a display
  summary; do not call the connector a trajectory without longitudinal evidence.
- Export coordinates, centroids, feature weights, and plotting order.

## Heatmaps

- Row-scale after configured preprocessing; record clipping.
- Show clinical column annotations.
- For group-split heatmaps, split columns first and cluster independently
  inside each group.
- Keep controls' disease-specific annotations blank.
- Export displayed matrix, annotations, row/column order, and selected-feature
  rule.

## Volcano plots

- Define log2FC as numerator minus reference and print the direction in source
  data.
- Use FDR and effect-size thresholds from config.
- Label metabolites by common name when available and features by stable ID
  otherwise.
- Export complete results and the exact label-selection table.

## Enrichment

- Prefer a dotplot using FDR on the x-axis, hits as size, and impact or NES as
  color.
- Show a significance reference when meaningful.
- Do not imply significance for merely top-ranked nonsignificant pathways.
- Avoid dense networks unless they answer a specific redundancy question.
