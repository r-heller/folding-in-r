# Book helpers

The code this book runs on lives here, as plain R scripts sourced into the
render session by `_common.R`. There is no companion package: clone the
repository, run `renv::restore()`, and the helpers are on the search path.

This is the same arrangement `scientometrics-in-r` uses.

## Layout

One file per concern, sourced in **alphabetical order**, so no file may depend
on another at *source* time — only at *call* time. A file that needs a constant
at source time is a file in the wrong place.

| File | Holds | First needed |
|:--|:--|:--|
| `baselines.R`     | `swiss_roll()`, `s_curve()`, `severed_sphere()` | Ch 11 |
| `constants.R`     | θ grid, sample sizes, palette option, tolerances | Ch 3 |
| `constructions.R` | product and lift constructions, irreducible-loss bound | Ch 8 |
| `folding.R`       | `fold()`, the ambient embedding, `crease_assignment()`, `branch_gap()`, `facet_gap()` | Ch 2 |
| `figure-export.R` | geometry for the interactive figures, with isometry asserted | Ch 1 |
| `metrics.R`       | Procrustes RMSE, $Q_{NX}$, T/C/kNN, `reference_dist()`, `metric_floor()` | Ch 4 |
| `methods.R`       | the embedding registry — nine methods | Ch 4 |
| `patterns.R`      | `miura_ori()`, `yoshimura()`, `waterbomb()` | Ch 2 |
| `plotting.R`      | crease-pattern and embedding plots | Ch 2 |
| `sampling.R`      | `sample_manifold()`, noise models, `boundary=` | Ch 3 |

Tests live in `tests/testthat/` and run in CI via
`.github/workflows/helpers.yml`.

## The object contract

Three S3 classes carry everything between files. They are plain lists with a
class attribute — no S4, no R6, no S7. Every field below is required.

### `crease_pattern` — a flat, unfolded crease pattern

Returned by `miura_ori()`, `yoshimura()`, `waterbomb()`.

```
list(
  vertices = <V x 2 double>,   # coordinates in the unfolded plane, the chart U
  facets   = <list of integer vectors>,   # vertex indices, counter-clockwise
  creases  = <data.frame(i, j, assignment)>,  # assignment in "M", "V", "B"
  family   = <"miura" | "yoshimura" | "waterbomb">,
  params   = <named list of the generating parameters>
)
```

`assignment == "B"` marks a boundary edge, which folds not at all. The unfolded
`vertices` are the **ground truth**: the book's whole premise is that this
matrix is the answer, not an approximation of it.

### `folded_pattern` — the same pattern at folding parameter θ

Returned by `fold(pattern, theta)`.

```
list(
  pattern   = <the crease_pattern it came from>,
  theta     = <double, the folding parameter; 0 is the flat sheet>,
  vertices3 = <V x 3 double>,  # ambient positions, row-aligned with vertices
  rho       = <double, one dihedral angle per row of creases; pi when theta = 0>
)
```

θ is a **parameter of the map**, not an angle read off the figure, and ρ is
derived from it. See the glossary; conflating the two is the error the earlier
draft made.

### `manifold_sample` — points drawn from a folded pattern

Returned by `sample_manifold(pattern, theta, n, noise, seed)`.

```
list(
  X      = <n x 3 double>,  # ambient coordinates, with noise applied
  truth  = <n x 2 double>,  # the exact chart coordinates of the same points
  facet  = <integer n>,     # which facet each point landed on
  theta  = <double>,
  seed   = <integer>
)
```

`X[i, ]` and `truth[i, ]` are the same point seen two ways. Everything the book
measures is a comparison between an embedding of `X` and `truth`.

## Invariants the tests assert

These are not style preferences. Each one is a claim the book makes in prose,
and a test that fails here is a chapter that has to be rewritten.

1. **Isometry.** For every pattern that folds, all pairwise distances *within a
   facet* are preserved under `fold()` to $10^{-10}$, across the whole θ sweep
   and, for Miura, across $\alpha \in [20°, 85°]$.
2. **Flat at zero.** `fold(p, 0)$vertices3[, 1:2]` equals `p$vertices` up to a
   rigid motion, and `rho` is π throughout.
3. **An independent identity.** At least one relation per pattern that was *not*
   built into the derivation — for Miura, the major-crease dihedral.
4. **Ambient contraction.** For θ > 0, ambient distance is strictly less than
   chart distance for any pair separated by a fold, and equal for pairs inside
   one facet.
5. **Truth is the chart.** `sample_manifold()` returns `truth` rows that lie in
   the facet they claim, and `X` rows that lie on the folded surface to
   numerical tolerance.
