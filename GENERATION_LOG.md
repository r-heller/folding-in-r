# Generation Log

Build record for *Folding in R*. One entry per merged phase, newest last.
Each entry names the branch, the gate that was checked, and the resulting SHA.

Scope note: this scaffold was generated locally. Nothing has been pushed to
`origin`, no release was cut, and the sibling package `foldbench` exists as a
local directory rather than a GitHub repository. Phases 1–10 of the scaffold
prompt are therefore executed up to, but not including, their remote steps.

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
