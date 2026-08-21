# Generation Log

Build record for *Folding in R*. One entry per merged phase, newest last.
Each entry names the branch, the gate that was checked, and the resulting SHA.

Scope note, **superseded at Phase 12** and kept because the phase entries below
were written under it: *"this scaffold was generated locally. Nothing has been
pushed to `origin`, no release was cut, and the sibling package `foldbench`
exists as a local directory rather than a GitHub repository. Phases 1–10 of the
scaffold prompt are therefore executed up to, but not including, their remote
steps."*

As of Phase 12 the work is on `origin/main`, CI runs on every push, and
`foldbench` no longer exists in any form (Phase 11). No release has been cut and
GitHub Pages is not yet enabled — the render workflow had never completed a run
until Phase 12, so there has never been anything to deploy.

---

## Phase 1 — Repository initialization

`chore/init` → `2a41709`. Directory layout, both licences, `.gitignore`.

## Phases 2–4 — Configuration, style assets, chapter stubs

`feat/bookdown-config` → `84b6cba`. `_bookdown.yml`, `_output.yml`, the three
style includes, and one stub per chapter carrying its opening question and
outline.

Gate: the book renders. Note for anyone porting from methods-in-r — do not
carry over its `tweak_part_screwup()` no-op. It works around a bookdown 0.46
crash that is fixed in 0.47, and under 0.47 it suppresses every part heading:
0 occurrences of "Part I" with the patch against 98 without it.

## Phase 5 — Companion package `foldbench`

Built at `../foldbench` as a local directory, per the scope note above.
Patterns, folding and sampling, product and lift, and the evaluation metrics.

Gate: `R CMD check --as-cran` — 0 errors, 0 warnings, 0 notes.

## Phase 6 — Bibliography

`feat/bibliography` → `5a2bb69`. Nine entries, every one carrying a DOI, arXiv
ID or ISBN that resolves. Three citations the book will need are parked in a
commented UNVERIFIED block rather than written from memory: Venna & Kaski on
trustworthiness, Miura's 1985 ISAS report, and the primaries for Maekawa's and
Kawasaki's theorems.

## Phase 7 — Scripts and CI

`feat/scripts-and-ci` → `3a331ba`, workflows corrected in `95f7aaa`. Two of the
five scripts were rewritten rather than copied: citation verification now
resolves through the Handle System, and the README table of contents is read
from each file's first H1 instead of a YAML block that bookdown chapters do not
have.

Gate: `scripts/verify-citations.R` — all 9 identifiers resolve.

## Environment

`chore/renv` → `48dce7a`. `renv.lock` pins 87 packages. `foldbench` is excluded
as a sibling source repository; `torch` is recorded but not installed, so
`scripts/renv-snapshot.R` is used in place of a bare `renv::snapshot()`, which
would drop it every time.

## Phase 8 — Metadata and README

`docs/metadata` → `f77ba68`. README, `CITATION.cff`, `CONTRIBUTING.md`. The
README structure section is generated; do not edit it by hand.

## Phase 9 — VG Wort instrumentation

`feat/vgwort` → `8c8bca3`. Register scaffolded with empty pixel columns.

Gate: `scripts/check-vgwort-eligibility.R` — 0 eligible, 22 below threshold,
which is correct for a scaffold. The inherited script reported every empty stub
as eligible at 4000-plus characters; R's `.` does not match newline, so its
`<script>` strip never fired.

## Phase 10 — Smoke test

`fix/render-smoke-test` → `74ae873`. Full render in all three formats, then the
defects it surfaced: part files invisible because bookdown skips leading
underscores, sidebar dividers duplicated because bookdown 0.47 now renders
parts natively, no Font Awesome anywhere because the vendored CSS was missing
and bs4_book's kit fallback answers 403, and every per-chapter download link
dead because the PDFs were named after source files rather than pages.

Gates: `render_book(output_format = "all")` clean; 18 chapter PDFs, each
matching an HTML page; 9 identifiers resolve; `foldbench` checks 0/0/0.

Not done, per the scope note: push, release, GitHub Pages.

## Phase 11 — `foldbench` dissolved into the book

The companion package is gone. Its contents move into `R/` as plain scripts,
sourced by `_common.R` the same way `scientometrics-in-r` sources its helpers.

Rationale. `foldbench` was never published — Phase 5 built it as a local
sibling directory and `github.com/r-heller/foldbench` returned 404 — so the
book has always described an install step no reader could perform. Keeping the
code in the book repository also removes the failure mode the package
introduced: a reader rendering the book at commit X against helpers at some
other version, with nothing recording which. The helpers are now versioned with
the chapters that use them, at the same commit.

Changes:

- `R/` added, with `R/README.md` documenting the intended file layout
  (`patterns.R`, `folding.R`, `sampling.R`, `constructions.R`, `metrics.R`,
  `plotting.R`). One file per concern, sourced alphabetically, so no file may
  depend on another at source time — only at call time.
- `_common.R` sources `R/*.R`. Tolerant of an empty `R/` while the chapters are
  still stubs and every chunk is `eval = FALSE`; this must become a hard error
  once the first chapter goes live.
- `.github/workflows/r-cmd-check.yml` replaced by `helpers.yml`, which sources
  every script in `R/` and runs testthat. Inert while `R/` is empty, matching
  the behaviour of the workflow it replaces.
- `render-book.yml` no longer checks out and installs `r-heller/foldbench`.
- `scripts/run-benchmark-grid.R` sources `R/` instead of `library(foldbench)`,
  and its provenance note now records the commit SHA of `R/` rather than a
  package version.
- README, `00-how-to-use.Rmd` and `08-building-benchmarks.Rmd` updated; the
  install line `R CMD INSTALL ../foldbench` is removed from the build recipe.

`renv/settings.json` no longer lists `foldbench` under `ignored.packages`; the
list is now empty. `renv.lock` itself never referenced it.

Earlier entries in this log describing `foldbench` as a sibling package are left
as written. This log is append-only and records what was true at each phase.

## Phase 12 — S0 cleared, and the book renders in CI for the first time

The concept baseline (`PROJECT_CONCEPT.md`, `PLAN.md`, `CHAPTERS.md`) is
committed rather than kept beside the repository, and all eight S0 blockers are
closed. Details and acceptance criteria are in `PLAN.md`; what belongs here is
what was learned doing it.

**The book had never rendered in CI.** Every push since 2026-08-07 failed in
`renv::restore()` on `libglpk.so.40`, because `render-book.yml` had no
system-dependency step while `helpers.yml` has had one since it was written.
Nothing in the plan mentioned it; nobody had opened the log. The whole of S0-3 —
the elaborate machinery for making a failed render fail loudly — was guarding a
build that had never succeeded.

Two mechanisms were arranged to hide exactly that. `continue-on-error` on the
EPUB and PDF steps, and a full-book download link written unconditionally while
the per-chapter link immediately below it was correctly probed. Both are gone;
both artefacts are now asserted to exist and clear a size floor, since a
truncated PDF is as bad as a missing one, and every download link probes its own
target.

**`packages.bib` was being written 22 times per render**, once per source file,
from a `.packages()` vector that differs per chapter — so the committed file
described whichever chapter knitted last. `R-fs` and `R-yaml` were in it because
some chapter loaded `fs` and `yaml`, not because the book cites them. Generation
moved to `scripts/write-package-bib.R` with a hand-maintained vector and a
`--check` mode for CI.

**`r-lib/actions/setup-renv` restores the whole lockfile.** The
`renv::restore(exclude = "torch")` step that followed it was a no-op, and the
README's claim that CI runs without `torch` was wrong. Both corrected.

Gates: `renv::restore()` completes in CI; `git add --dry-run` confirms
`data/processed/*.rds` is committable; a render leaves `packages.bib` untouched;
`#citing` resolves cross-page to `citing.html#citing`; the `boxempty` block
renders with its class.

## Phase 13 — the gates that have to precede drafting

`verify-citations.R` could not fail in the two ways that mattered. An entry with
no identifier returned `NA` and was printed as *tolerated* before exiting 0, so
an entry written entirely from memory passed CI green — in direct contradiction
of `CONTRIBUTING.md`. And nothing checked that a key cited in the text existed
at all. Both fixed, and both fixes tested by breaking the bibliography four ways
on purpose: no identifier, `% NOIDENT-OK` tolerated, dangling key, bad DOI. All
four exit 1.

`scripts/lint-chapters.R` is new, with the six checks `PLAN.md` S1-1 specifies.
Check 1 — no bare decimal or comma-grouped integer in prose — is the
anti-fabrication gate, and it works: it caught "CC BY 4.0" in the datasets
appendix on its first run against real text, which is a licence name and now
carries an explicit `lint-allow-number` escape. Stub chapters are exempt via the
TODO marker they were created with, so the exemption deletes itself when
drafting starts. All six checks were tested against a chapter written to violate
each.

Bibliography 9 → 26 entries, every field transcribed from a fetched metadata
record. Three things in the notes turned out to be wrong: the Euler Isometric
Swiss Roll is a *dataset* inside an SDM 2017 paper on streaming error metrics,
not a paper title, and the second arXiv ID recorded as a co-primary only uses
it; the Miura repository URL had to be found rather than assumed, since every
record id on that host returns 200; and the ISSN recorded for that report was
never confirmed and is dropped.

**A(k) is transcribed from the primary** — Kaski et al. 2003, with Eqs. (3) and
(4) — and agrees with what had been written from memory. That is the outcome you
hope for and not one you can assume. The paper's own caveat, that A(k) is a
scaling rather than a proven worst-case bound, is recorded for Chapter 9.

`render-chapter-pdfs.R` emitted every cross-reference as the literal string
`\@ref(label)`; it rendered through `rmarkdown::render()` with `--citeproc`,
which knows nothing about bookdown references. It now renders each chapter
through `bookdown::pdf_book` in an isolated directory. Two further bugs surfaced
while fixing it, both of the same species as everything else in this phase:
`anchor_of()` took the whole `{#id .class}` brace and produced a dead download
name, and bookdown resolves the project config on its first call in a session,
so the first chapter of the loop rendered the *entire book* over
`docs/folding-in-r.pdf` while reporting success. The script now asserts the file
it asked for exists and counts what is on disk rather than what it attempted.

The ambient contraction was re-derived rather than carried: $|d_A/d_U -
\sin(\rho/2)|$ is at most $1.11\times10^{-16}$ over 360 configurations. Its
strictness has a floor — the contraction stops being representable in double
precision below a fold angle of about $3\times10^{-8}$ rad — which qualifies one
of the invariants in `R/README.md` and sharpens the Claim C argument.

Chapter 12's three open decisions are closed from primary sources: the dataset
(Zheng et al. 68k PBMC), the licence (CC BY 4.0, so redistribution is permitted
and only size constrains what ships), and label provenance — the labels come
from separately sequenced purified subpopulations, not from clustering the
matrix under test, so the comparison is not circular in the way that would have
mattered.
