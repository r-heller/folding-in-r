# Folding in R

*Origami, Manifolds, and Dimension Reduction*

Online edition: <https://r-heller.github.io/folding-in-r/>

## What this book covers

A rigid origami crease pattern generates a manifold whose true low-dimensional
structure is known exactly, in closed form. Rigid folding bends the sheet along
creases only and leaves the facets flat, so the folded surface is isometric to
the flat sheet: geodesic distances are unchanged. The flat crease pattern is
therefore not an approximation of the correct two-dimensional embedding — it is
the correct embedding.

That makes three things possible that the standard benchmarks cannot offer.
Fold angle is a continuous difficulty parameter, so every method's performance
is a curve rather than a single number. Reconstruction error is exact, measured
as Procrustes-aligned RMSE against the true unfolding. And because the truth is
known, the *evaluation metrics themselves* can be checked — trustworthiness and
continuity can be asked how optimistic they are, and by how much.

The book uses that to answer Chari and Pachter's critique of two-dimensional
embeddings with measurement rather than argument, and closes by using the
benchmark to choose a method for a real dataset.

## What it does not cover

Rigidity theory. Computational origami design algorithms. Deep generative
models beyond a single autoencoder chapter. Project tooling — there is no
chapter on `bookdown`, `make`, or continuous integration. Material that could
not be tied back to the ground-truth claim above was cut rather than kept for
completeness.

## Structure

<!-- TOC:START -->
- Impressum
- Acknowledgments
- How to use this book

**Part I — Folding**

1. Introduction
2. The geometry of folding
3. Folding as a generative model

**Part II — Methods under test**

4. Linear projections and where they break
5. Geodesic methods
6. Neighbour embeddings
7. Learned folds

**Part III — The benchmark**

8. Building crease-pattern manifolds
9. Ground truth and the evaluators
10. Benchmark results
11. Crease patterns vs. the Swiss roll

**Part IV — Application**

12. From benchmark to decision

**Appendix — Reference material**

13. Notation
14. Datasets and codebook
- Glossary
- Colophon
- About the author
- Citing this book
- References
<!-- TOC:END -->

## The code

The pattern constructors, the folding and sampling interface, the product and
lift constructions, and the evaluation metrics live in `R/` as plain scripts,
sourced by `_common.R` at render time. There is no companion package to
install, and no way for the helpers to drift from the chapters that use them:
they are versioned together, in this repository, at the same commit.

## Building the book

```sh
R -e 'renv::restore()'
R -e 'bookdown::render_book("index.Rmd", output_format = "all")'
```

Two passes are not required, but `renv::restore()` is: the package versions are
pinned in `renv.lock`.

One package needs a word of explanation.

`torch` **is** in the lockfile but is not installed in the working checkout.
Only Chapter 7 needs it, it pulls a large binary backend on first use, and the
rest of the book renders without it. `renv::status()` therefore reports one
package recorded-but-not-installed; that is the intended state locally. Install
it when Chapter 7 is written.

CI is a different matter, and the README used to get this wrong.
`r-lib/actions/setup-renv` restores the whole lockfile, so the render job has
`torch` installed whatever the workflow asks for afterwards. The
`renv::restore(exclude = "torch")` step that used to follow it was a no-op.


Supporting scripts:

| Script | Purpose |
|---|---|
| `scripts/verify-citations.R` | Resolves every identifier in `book.bib`; exits non-zero on failure |
| `scripts/render-chapter-pdfs.R` | Per-chapter PDFs for the download button |
| `scripts/toc-to-readme.R` | Regenerates the table of contents above |
| `scripts/renv-snapshot.R` | `renv::snapshot()` that keeps the deferred packages in the lockfile |
| `scripts/run-benchmark-grid.R` | Chapter 10 grid. Slow; run locally and commit the result |
| `scripts/check-vgwort-eligibility.R` | Character counts and VG Wort eligibility |

## Status

Version 0.1.0 — scaffold. Chapters carry their opening question and an outline;
the prose is not written. `drafts/` holds work in progress and is not part of
the rendered book.

## Cite this repository

See `CITATION.cff`, or:

```bibtex
@book{heller2026folding,
  title     = {Folding in R: Origami, Manifolds, and Dimension Reduction},
  author    = {Heller, R.},
  year      = {2026},
  publisher = {Self-published},
  url       = {https://r-heller.github.io/folding-in-r/}
}
```

## Licence

Prose under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); see
`LICENSE`. Code under the MIT License; see `LICENSE-CODE.md`.
