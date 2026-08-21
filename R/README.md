# Book helpers

The code this book runs on lives here, as plain R scripts sourced into the
render session by `_common.R`. There is no companion package: clone the
repository, run `renv::restore()`, and the helpers are on the search path.

This is the same arrangement `scientometrics-in-r` uses.

## Planned layout

One file per concern, sourced in alphabetical order, so no file may depend on
another at *source* time — only at *call* time.

| File | Holds |
|:-----|:------|
| `patterns.R`   | crease-pattern constructors: `miura_ori()`, `yoshimura()`, `waterbomb()` |
| `folding.R`    | the rigid-folding map at angle `theta`, and the ambient embedding |
| `sampling.R`   | `sample_manifold()` — uniform sampling over facets, noise models |
| `constructions.R` | the product and lift constructions |
| `metrics.R`    | `reconstruction_error()`, `trustworthiness()`, `continuity()`, `knn_preservation()` |
| `plotting.R`   | crease-pattern and embedding plots, the book palette (viridis option "C") |

Tests for these live in `tests/testthat/` and run in CI via
`.github/workflows/helpers.yml`.
