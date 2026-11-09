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
sourced by `_common.R` at render time. No package installation is needed for
these helpers: they are versioned with the chapters at the same commit.
The standalone `foldbenchR` package is being revived separately, at the owner's
request, using the same documented Miura construction. It does not replace
these book helpers or the provenance of the committed benchmark results.

## Building the book

Install R and Pandoc first. From the checkout:

```sh
R -e 'install.packages("renv", repos="https://cloud.r-project.org")'
R -e 'renv::restore()'
R -e 'bookdown::render_book("index.Rmd", output_format = "bookdown::bs4_book")'
R -e 'bookdown::render_book("index.Rmd", output_format = "bookdown::epub_book")'
# PDF additionally needs XeLaTeX and the fonts/packages in style/preamble.tex.
R -e 'bookdown::render_book("index.Rmd", output_format = "bookdown::pdf_book")'
```

Open `docs/index.html` or serve `docs/` with `python3 -m http.server --directory docs`.
HTML and EPUB were rebuilt locally on 30 October 2026 using R 4.6.1 and an isolated
library; that validates the current content, not an exact restore of the older
lockfile. PDF was not rebuilt because this environment has no TeX installation.

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

## Status

Version 0.1.0 — work in progress. Ten body chapters contain developed material;
Chapter 7 (learned folds) and Chapter 12 (the real-data application) remain
explicit outlines. `drafts/` is outside the rendered book. The volume is not a
complete submission-ready manuscript. Current verification and remaining work
are recorded in `MAINTENANCE.md`.

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
`LICENSE`. Code under the MIT License; see `LICENSE-CODE.md`. Generated data
under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/); see
`LICENSE-DATA.md`, which also covers external data the book fetches rather than
redistributes. Vendored third-party material is listed in `THIRD-PARTY.md`.

The data licence is not boilerplate. This book's argument is that its results are
reproducible from committed artefacts, so a reader is expected to download
`data/processed/`, re-run the analysis and publish what they find — and the dual
licence covered prose and code and left that third thing unaddressed.

## Validate a release build

Use Python 3 with `pypdf`, the book’s R dependencies, Pandoc and XeLaTeX.
Refresh the page notes before rendering; their dates follow source revisions,
not the day the site is built. Then validate the actual downloadable artifacts:

```sh
python3 scripts/update-page-provenance.py
Rscript -e 'bookdown::render_book("index.Rmd", output_format = "all")'
python3 scripts/split-chapter-pdfs.py
python3 scripts/finalize-book.py
python3 scripts/check-book.py
```

The final check fails on missing author/date notes, broken local links or anchors,
and missing or unreadable whole-book PDF/EPUB files. Chapter downloads reuse the
whole-book PDF’s bookmarks instead of executing every chapter a second time.
