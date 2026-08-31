# Licence: the committed data

The book's dual licence covers two things and this repository contains three.
Prose is CC BY 4.0 (`LICENSE`); code is MIT (`LICENSE-CODE.md`); and everything
under `data/` is neither prose nor code and was covered by neither.

That gap matters more here than it would in most books. The book's whole
argument is that its results are reproducible from committed artefacts, so a
reader is *expected* to download `data/processed/`, re-run the analysis and
publish what they find. A reader who reads the licence carefully enough to ask
whether they may is exactly the reader this book is written for.

## `data/processed/` — generated results

**CC0 1.0 Universal (public domain dedication).**

Every file here is the output of a script in `scripts/`, run on data this
repository generates from a closed-form crease pattern. No third party has any
claim on any of it, and the facts in a table of measurements are not copyrightable
in most jurisdictions in any case. CC0 says that plainly rather than leaving a
reader to reason about it.

Attribution is not required and is appreciated. If you report a number from one
of these files, cite the book — `CITATION.cff` has the form — because the number
is only interpretable against the design that produced it, and the design is in
the prose.

Each artefact carries a provenance block naming the `R/` tree hash, the R
version, the BLAS, the package versions and the wall clock of the run that made
it. Redistributing an artefact without its provenance strips the one thing that
makes it checkable; please do not.

## `data/raw/` — anything obtained rather than generated

**Under whatever licence its source gives it, which is recorded per dataset in
`A2-datasets.Rmd`.**

At the time of writing there is one such dataset: the Fresh 68k PBMC matrix
(Donor A) from 10x Genomics, used only in the applications chapter, which that
appendix determines to be CC BY 4.0 and which is **not redistributed here** —
`scripts/prepare-single-cell.R` fetches it. The determination, its two named
caveats and the label-provenance argument are in `A2-datasets.Rmd` and are part
of the book rather than a footnote to it.

The rule for anything added later is the same and is not negotiable by
convenience: an external dataset is redistributed only if its licence permits it
and the licence is named in `A2-datasets.Rmd`. Otherwise the repository ships the
script that fetches it.

## `js/`, `style/` and other vendored assets

`THIRD-PARTY.md` lists what is vendored and under what terms.

## In short

| Path | Licence |
|:--|:--|
| `*.Rmd`, `*.md`, the rendered book | CC BY 4.0 |
| `R/`, `scripts/`, `tests/`, `js/fold-figure.html` | MIT |
| `data/processed/` | CC0 1.0 |
| `data/raw/` | per dataset, see `A2-datasets.Rmd` |
| vendored assets | see `THIRD-PARTY.md` |
