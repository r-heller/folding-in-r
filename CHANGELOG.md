# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Repository structure, `renv` project, and build configuration.
- Bookdown configuration for HTML (`bs4_book`), PDF (xelatex) and EPUB.
- Style assets: Hugo Coder palette, Inter and JetBrains Mono, LaTeX preamble.
- Chapter stubs for twelve body chapters in four parts, front and back matter,
  and two appendices.
- Companion package `foldbenchR` (local sibling directory).
- Verified bibliography and a citation checker.
- Render, citation-check and package-check workflows.
- `README.md`, `CITATION.cff` and contribution guide.
- VG Wort instrumentation scaffold.
- Chapter prose for ten of the twelve body chapters, the glossary, and both
  appendices, written against the `foldbenchR` API.
- Benchmark grid now scores five methods (PCA, classical MDS, Isomap, t-SNE,
  UMAP) instead of PCA alone.
- 61 bibliography entries added alongside the prose.

### Fixed

- `.gitignore` no longer swallows `data/processed/benchmark-grid.rds`. The
  blanket `*.rds` rule is scoped to the repository root, where the bookdown
  session cache actually lands, so the precomputed grid can be committed as
  `scripts/run-benchmark-grid.R` has always said it should be.
- A failed embedding in the benchmark grid is recorded as `NA` rather than
  dropped. Dropping it biased every curve by removing the hard configurations.
