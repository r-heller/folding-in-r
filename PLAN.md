# PLAN.md — Folding in R, concept baseline 2026-08-21

Sequenced work to take the book from a rendering scaffold with 2,205 words of
stubs to a publishable volume matching the sibling books' rig.

Severity tiers follow the house convention: **S0** blocks everything, **S1** is
required before content ships, **S2** is quality. Each commit carries acceptance
and rollback criteria.

Read `PROJECT_CONCEPT.md` first — it holds the claims and the corrections. This
file holds the order.

---

## Decision log

**D1 — The decisive experiment runs before any prose.** The book's headline claim
(crease patterns beat the Swiss roll) is unsupported by anything currently
planned, and the book's own feasibility numbers actively undercut it: short-circuit
fraction is exactly 0.00 across five of the ten sampled fold angles, while the
geometric properties the claim rests on are constant across the whole range. The
experiment that decides it (**E1**) was scheduled as chapter 11 of 12. It moves to
the front. Committing 30,000 words to defending a claim before testing it is the
single largest risk in this project.

**D2 — Two headline metrics, not one.** Procrustes RMSE alone builds the scoring
function out of one side of the dispute the book claims to arbitrate. Adding
truth-referenced $Q_{NX}(K)$ costs one function and makes the isometry-versus-
reparameterisation question measurable instead of arguable. See `PROJECT_CONCEPT.md`.

**D3 — The stress result moves to Chapter 2 as a theorem.** It is a one-line
corollary of the ambient contraction, not an experimental finding. Stating it as
a proposition is stronger, spends no compute, and removes the objection that
2,700 grid cells were spent demonstrating a definition.

**D4 — Build the full twelve-chapter book.** 41,070 words (plus ~650 of new back
matter), 53 figures, 145 chunks, three pattern families, 9 artefacts, ~60 citations, 60–100 h compute
across two or three grid generations. Chosen over a scoped eight-chapter
Miura-only alternative (~21,500 words, 2 artefacts, ~4 h) with the cost
understood and recorded in `PROJECT_CONCEPT.md`. Per-chapter specification in
`CHAPTERS.md`.

The consequence to hold on to: **prose cannot outrun the grid.** At 2,750 words
per body chapter this is 3.2× the per-file density of `scientometrics-in-r`, and
unlike that book every paragraph here is gated on a computed number. The sibling
pattern — draft in a day, repair for weeks — does not transfer. Sequencing
(below) is therefore artefact-first, not chapter-first.

**D5 — Chapter 12 stays, with its dependencies promoted to work items.** Its risk
was never the chapter, it was that four decisions sat unresolved inside it. Each
becomes an explicit S1 item with its own gate: the dataset (S1-8), the
redistribution licence (S1-9), label provenance (S1-10), and the pre-registered
selection rule (S1-11). **The selection rule must be written into Chapter 10 §10.8
and committed before a single Chapter 12 fit is run** — that commitment is the
only thing that makes its null-result promise meaningful, and it is worthless
applied retroactively.

**D6 — `docs/` stops being tracked.** 79 files, 2.2 MB, including a stale EPUB and
PDF built from the stubs. Both siblings gitignore it and track zero files there.
The deploy uses `clean: true`, so the committed copy serves no purpose except
churn — and it guarantees a reader cloning the repo gets a stale rendered book
beside the sources.

---

## S0 — blockers

Nothing else can proceed. All eight are small; together they are one afternoon.

#### S0-1 — `.gitignore` blocks the book's own data

`git check-ignore -v data/processed/benchmark-grid.rds` returns
`.gitignore:36:*.rds`. The book's entire data-provenance story — grid precomputed,
committed, `run-benchmark-grid.R` kept as the provenance record — is **impossible
as configured**. Every chapter from 4 onward opens with a `read_run()` of a
committed `.rds`.

*Accept:* `git ls-files --error-unmatch data/processed/benchmark-grid.rds`
succeeds in CI. *Rollback:* revert the negation, artefacts move to release assets.

#### S0-2 — Commit the Phase-11 tree

`git status --porcelain` shows `?? R/`, `?? tests/`, `?? .github/workflows/helpers.yml`,
`D .github/workflows/r-cmd-check.yml` and six modified files. All of it is one
`git checkout .` from vanishing.

*Accept:* working tree clean. *Rollback:* n/a.

#### S0-3 — Disarm the silent-broken-site mechanism

This is `methods-in-r`'s 4,093 dead links in miniature, already armed.
`render-book.yml` sets `continue-on-error: true` on the HTML, EPUB **and** PDF
steps (lines 47, 54, 58), so a failed PDF render deploys a green build.
`style/after-body.html:95` then injects `aBook.href = "folding-in-r.pdf"`
unconditionally on every page — while line 111, immediately below, correctly
guards the *chapter* PDF behind a `fetch(..., {method:"HEAD"})` probe. The
asymmetry is the bug. `_output.yml:21` independently adds `download: ["pdf","epub"]`.

*Accept:* (a) `continue-on-error` removed, replaced by a post-render assertion
that both artefacts exist and exceed a size floor — a truncated PDF is as bad as
a missing one; (b) the full-book link uses the same HEAD probe as the chapter
link; (c) `link-check.yml` runs lychee over `docs/` after render.
*Rollback:* restore tolerance, drop the download menu instead.

#### S0-4 — One `render_book` call, not three

The workflow calls `render_book` separately for bs4_book, epub_book and pdf_book,
tripling a build already near the 90-minute CI ceiling. The Phase-10 smoke test
used `output_format = "all"` in one call.

*Accept:* single call; wall-clock recorded in `GENERATION_LOG.md`.

#### S0-5 — Move `write_bib()` out of `_common.R`

`_bookdown.yml` sets `new_session: yes` with `before_chapter_script: "_common.R"`,
so `_common.R` runs fresh for each of the 22 page-producing files and its final
statement overwrites `packages.bib` every time. `.packages()` differs per chapter,
so the surviving file describes whichever chapter knitted last. `index.Rmd`
declares `bibliography: [book.bib, packages.bib]`, so `@R-uwot` cited in Chapter 6
resolves to nothing if Chapter 12 knitted last.

*Accept:* `write_bib()` lives in `scripts/write-package-bib.R`, run once
pre-render with an explicit hand-maintained package vector — never `.packages()`,
which is exactly what makes it session-dependent. `packages.bib` is committed like
any other artefact.

#### S0-6 — Untrack `docs/` (D6)

*Accept:* `git ls-files docs | wc -l` returns 0; `docs/` in `.gitignore`; deployed
site unchanged after next render.

#### S0-7 — Fix the three wrong sentences

Curvature-at-vertices, "real data manifolds have creases too", and the $\theta$
definition in glossary and notation. See `PROJECT_CONCEPT.md`.

*Accept:* all three corrected; the creases-in-real-data sentence deleted, not hedged.

#### S0-8 — Fix the section contract

Pick the nine-slot anchored contract, write it into `00-how-to-use.Rmd`, delete
the two competing forms.

*Accept:* one contract documented; `scripts/lint-chapters.R` (S1-1) enforces it.

---

## E1 — the go/no-go experiment

**Runs immediately after S0 and before any prose.** This decides what book gets
written.

**Question.** Do crease patterns and Swiss rolls collapse onto one difficulty
curve when plotted against branch separation?

**Method.** Cheap — needs `sample_manifold()`, a `swiss_roll()` with arc-length
truth, and the short-circuit index (median ambient NN distance over median true
geodesic distance between those pairs). No Part II methods, no full grid, no
autoencoder. Plot method error against that index for both families.

**Second arm.** Hold $g/s$ fixed and vary crease count — a 3×3 against a 12×12
Miura at matched $g/s$. This isolates the crease contribution directly.

**Outcomes, all pre-drafted:**

- **Families separate** — at equal $g/s$ the crease family produces different
  rankings. Claim C is empirical and creases do real work. Proceed with the book
  as scoped in D4, and E1 becomes Chapter 11.
- **Families collapse** — Claim C as written is false. Replace it immediately,
  before any words are committed to defending it. The honest replacement is
  strong: *a generator that varies branch separation continuously, exactly, and
  with a computable critical value.* That is a real contribution to benchmark
  tooling and a much smaller claim. Claim B (irreducible loss) is untouched and
  becomes the spine.
- **Error flat in crease count at fixed $g/s$** — say so in Chapter 11 in the
  book's own voice. The book is better for containing that measurement than for
  being caught without it.

**Gate:** no chapter drafting begins until E1 is recorded in `GENERATION_LOG.md`
as a claim-set decision.

---

## E2 — pattern kinematics spike

Runs in parallel with E1. **Go/no-go on the third pattern, not an implementation
task** — this is the one place where the full-book scope meets an unsolved
problem, and it must not be discovered late inside Chapter 8.

**Miura and Yoshimura are settled.** Both derived and numerically verified in
design work (Miura $<10^{-12}$ over $\alpha \in [20°,85°]$; Yoshimura
$<10^{-15}$, with the ring closing at $\theta = \pi/2$). E2 reproduces both in
this repository, under test. Note the literature's negative result on Yoshimura
concerns the closed **cylinder**; a finite planar patch is a different object, and
the verification is against the patch.

**Waterbomb is genuinely open.** No closed-form rigid folding could be certified.
A degree-6 vertex with sectors (45, 45, 90, 45, 45, 90) satisfies Kawasaki and is
therefore flat-foldable *as an isolated vertex* — which does not imply the
tessellation admits a one-parameter rigid folding without extra symmetry.
Attempt: Gauss–Newton bar-and-joint continuation. It may not move at all, in which
case the tessellation is rigid and that is the answer.

*Accept:* `tests/testthat/test-folding.R` asserts, per pattern that folds, pairwise
facet distances preserved to $10^{-10}$ across the $\theta$ sweep, plus the
independent identity (major-crease dihedral $= 2\theta$) that was not built into
the derivation.

**Three outcomes, all pre-drafted, recorded in `GENERATION_LOG.md` as a claim-set
decision:**

- **All three fold** — proceed exactly as `CHAPTERS.md` specifies.
- **Waterbomb does not fold** — ship two families plus a documented negative
  result. Chapter 8 §3 is *already* titled "Three pattern families, and one honest
  gap", so the chapter absorbs this without restructuring, and it is a better
  chapter for containing a real negative result than for quietly dropping a
  pattern. Delete the waterbomb row from `run-benchmark-grid.R` and cut the grid
  from 2,700 cells to 1,800.
- **Continuation succeeds but only under imposed symmetry** — ship it, and say in
  §8.3 exactly which symmetry was imposed and what that costs the generality
  claim.

*Hard rule:* no `PATTERNS` entry may exist in `run-benchmark-grid.R` for a pattern
that cannot be built. A grid row that silently fails is worse than a missing one.

---

## S1 — required before content ships

#### S1-1 — `scripts/lint-chapters.R` + `lint.yml`

Six checks in one file, written in the same commit as the section contract:

1. **Any bare decimal or comma-grouped integer in prose outside an inline
   `` `r ` `` expression** — allowlist years and chapter numbers. The
   anti-fabrication gate; the most valuable line in the file. Roughly forty
   stand-in numbers from the accordion-fold probe are sitting in design notes
   ready to transcribe, all of them measured on a stand-in rather than a Miura.
2. The nine contract H2 anchors, in order, per body chapter.
3. Any figure chunk without `fig.alt` (standing rule 3).
4. `<div class="callout` or a line beginning `::: ` — enforces the knitr block
   form the stylesheet actually defines. This is exactly what shipped 80 unstyled
   divs in `methods-in-r`.
5. Any `\@ref()` target that does not resolve.
6. `set.seed` present in every chunk that samples.

#### S1-2 — Harden `scripts/verify-citations.R`

Two holes, both fatal for ~60 incoming citations. `verify()` returns `NA` for an
entry with no `doi`/`eprint`/`isbn`/`url`, and `NA` is reported as *tolerated* —
so an entry written from memory passes CI silently, directly contradicting
`CONTRIBUTING.md`. And there is no check that a cited key exists.

*Accept:* identifier-less entries fail hard, with an explicit `% NOIDENT-OK`
marker making each tolerance opt-in and greppable (Kawasaki 1989, Justin 1986 and
Murata 1966 legitimately need it); bidirectional key check extracts every `@key`
from sources with a regex excluding `\@ref`, fails on any key absent from
`book.bib`/`packages.bib`, warns on any entry cited nowhere.

#### S1-3 — Bibliography pass

From 9 entries to ~40. Add before drafting Chapter 9: Machado et al. 2025,
Lause et al. 2024, Kaski et al. 2003, Venna & Kaski 2001 and 2006, Lee &
Verleysen, Espadoto et al. 2021, Kruskal 1964, Balasubramanian & Schwartz 2002,
the Euler Isometric Swiss Roll papers, Schenk & Guest 2013, Miura 1985 (report
618). All identifiers verified before they are written.

#### S1-4 — Transcribe $A(k)$ from Kaski et al. 2003

Every number in Chapter 9 depends on the trustworthiness/continuity normalising
constant, and it has so far only been written from memory as
$2/(Nk(2N-3k-1))$.

*Accept:* transcribed from the primary; `tests/testthat/test-metrics.R` asserts
the invariants that hold regardless — $T(X,X,k) = 1$, $T \in [0,1]$, $T$ monotone
decreasing under increasing shuffle fraction — plus a skip-marked case un-skipped
only once the constant is transcribed, so the gate is visible in test output.

#### S1-5 — Per-chapter PDFs resolve cross-references

`scripts/render-chapter-pdfs.R` uses `rmarkdown::render()` with `--citeproc`, not
bookdown, so `\@ref(label)` never resolves — it emits as literal text. Sources
currently hold 6 `\@ref` calls and `00-how-to-use` is on the SKIP list, so nobody
has noticed. The plan multiplies that roughly twentyfold.

*Accept:* render through `bookdown::pdf_book` on a per-chapter `_bookdown.yml`, so
`\@ref` resolves within a chapter and degrades to a visible `??` across chapters;
drop `--citeproc` for the book's own citation path.

#### S1-6 — Fix the three method defects found in timing work

- `umap::umap`'s `preserve.seed = TRUE` **silently collapses 20 seeds to 1**, a
  direct violation of standing rule 1 that would have invalidated every UMAP
  result in the book.
- The `umap` stub's stated reason is backwards.
- `lle` is archived on CRAN and must be hand-rolled.

Add the five packages missing from `renv.lock`: FNN, kernlab, diffusionMap,
coRanking, uwot.

#### S1-7 — Add `98-citing-this-guide.Rmd`

Both siblings ship it; this book has `CITATION.cff` and `citation.bib` but no
reader-facing citation page. It also leaves `boxempty` — one of five declared
callout classes, declared at `style/style.css:177` with a LaTeX fallback — with
zero call sites by construction. ~150 words, one `vgwort_pixels.csv` row.

#### S1-8 — Decide the Chapter 12 dataset

Closes the standing `<!-- TODO -->` in `A2-datasets.Rmd`. Recommendation from the
design work is the Zheng et al. PBMC data. *Accept:* accession, version and
licence recorded in `A2-datasets.Rmd`; `scripts/prepare-single-cell.R` writes a
committed processed matrix under the same not-run-in-CI provenance convention as
the grid.

#### S1-9 — Settle redistribution

Whether the processed matrix may ship in the repository changes what the
repository contains. *Accept:* licence checked and stated in `A2-datasets.Rmd`;
if redistribution is not permitted, the script downloads and the artefact is
gitignored, and Chapter 12 says so.

#### S1-10 — Resolve label provenance

Chapter 12's only external evaluation channel is cell-type labels. If those labels
were themselves derived from a clustering on one of the embeddings under test, the
comparison is circular. *Accept:* provenance documented; if circular, the chapter
uses a different channel and states why.

#### S1-11 — Pre-register the selection rule

Written into Chapter 10 §10.8 and **committed before any Chapter 12 fit runs**.
*Accept:* the rule is in git history with a timestamp preceding
`data/processed/` Chapter 12 artefacts. *Rollback:* none — a rule applied
retroactively is not a pre-registration, and the chapter's null-result promise
would have to be withdrawn rather than quietly weakened.

---

## S2 — quality

- **S2-1** — `vgwort.yml` runs `check-vgwort-eligibility.R` against rendered
  `docs/` and writes `vgwort_pixels.csv` back, failing only if a previously
  eligible chapter drops below threshold. Converts a hand-maintained register into
  a computed one.
- **S2-2** — Collapse the nine planned artefacts to five. `evaluator-audit.rds`
  and `metric-calibration.rds` share every cell and every distance matrix;
  computing them separately doubles the Dijkstra cost for nothing.
- **S2-3** — Seed budgeting. Invert the pre-registered 0.02 reportability
  threshold: solve for the seed count that detects 0.02 given measured
  within-method spread at the $\theta$ where methods converge, and spend compute
  there rather than 20-everywhere.

---

## Build order

Artefact-first. The binding constraint is that **no chapter can be drafted before
the artefact it reads has been computed and committed** — S1-1 makes typing a
number a build failure, so there is no way to write ahead of the data.

1. **S0-1 … S0-8** — blockers. One afternoon. `.gitignore` first: until it is
   fixed nothing can be committed and Chapters 4–12 are all blocked.
2. **E1 and E2 in parallel** — the two go/no-go experiments. Neither needs Part II
   methods. Record both in `GENERATION_LOG.md` as claim-set decisions.
3. **`R/` implementation** — 9 files. `patterns`, `folding`, `sampling` first
   (they carry E2's verified kinematics), then `metrics`, `constructions`,
   `methods`, `baselines`, `plotting`, `constants`. Tests alongside, not after.
4. **S1-1 … S1-7** — gates and bibliography. These must precede drafting, because
   S1-1 is what enforces the artefact-first rule and S1-3/S1-4 are what make
   Chapter 9 writable.
5. **Part I chapters (1–3)** — the only chapters that can be drafted against small
   on-demand computations rather than the grid. Chapter 1 is drafted **last** of
   the three despite being first in the book: it forward-references Chapter 9's
   headline, which does not exist yet.
6. **Grid generation 1** — `benchmark-grid.rds`, `part2-sweeps.rds`,
   `classic-grid.rds`. Shard by (pattern, seed).
7. **Part II chapters (4–7)** and **Part III (8, 10, 11)**.
8. **S1-8 … S1-11** — Chapter 12's four decisions, with the selection rule
   committed before any Chapter 12 fit.
9. **Chapter 9** — after `evaluator-audit.rds`. It is the largest chapter (4,400
   words), the most cited (17), and the one whose framing depends on Machado et
   al. and Lause et al. being in the bibliography first.
10. **Grid generation 2** — regenerate everything on final `R/`. Every number
    currently in hand came from a stand-in.
11. **Chapter 12, conclusion, appendices, glossary** — A1 and A2 last, since they
    document notation and artefacts that only stabilise at the end.

## Budgets

| | Full book (D4) | Scoped alternative, not taken |
|:--|--:|--:|
| Body chapters | 12 + front/back | 8 + front/back |
| Prose words | **41,070** (+650 new back matter) | ~21,500 |
| Figures | **53** | ~30 |
| Code chunks | **145** | ~85 |
| Patterns | **3** (2 verified, 1 unresolved) | 1 (Miura) |
| R files | **9** | 6 |
| Artefacts | **9** → 5 after S2-2 | 2 |
| Citations | **~60** | ~40 |
| Compute | **60–100 h**, 2–3 generations | ~4 h on 4 cores |

Reference point: `scientometrics-in-r`, the largest completed sibling, carries
34,673 prose words across 39 chapter files — 889 per chapter. This plan asks 2,750
per body chapter.

**Measured compute — revised 2026-08-24, against the real registry.**

The 15.2 s figure below was measured before `R/methods.R` existed. Re-measured
with all nine methods actually wired up, one cell at $n = 800$ costs **~26 s for
the eight runnable methods**, before metrics. Scaling from $n = 400$ is 3.3×,
i.e. roughly $O(n^{1.7})$.

The grid is also smaller than planned: two patterns rather than three (E2), and
20 $\theta$ values rather than 15. So 2 × 20 × 3 × 20 = **2,400 cells**, at ~30 s
including metrics — about **20 h single-core / 5 h on four cores**. That is
roughly twice the estimate below, and the overall 60–100 h envelope still holds
once the Chapter 9 audit artefacts and the second grid generation are added.

Cost is spread, not concentrated, which matters for any decision to trim:

| method | s at $n = 800$ | | method | s at $n = 800$ |
|:--|--:|:-:|:--|--:|
| Laplacian eigenmaps | 5.8 | | UMAP | 3.5 |
| Isomap | 5.5 | | diffusion map | 2.7 |
| t-SNE | 4.5 | | LLE | 2.6 |
| classical MDS | 1.2 | | PCA | 0.0 |

No single method dominates, so dropping one buys little. An earlier reading of
these timings put diffusion maps at 42% of the cell and named it as the obvious
trim; that was one noisy measurement at $n = 400$ on a loaded machine and it is
wrong — at the grid's own sample size it is about a tenth. **Sharding is the
lever, not method selection.**

Measurements were taken on a contended machine and are therefore upper bounds.

The original estimate, kept for the record: one fit of the nine non-torch methods
plus metrics at $n = 800$ costs 15.2 s, so the main grid (3 patterns × 15
$\theta$ × 3 noise × 20 seeds = 2,700 cells) is 11.4 h single-core / 2.9 h on
four cores. Add:

- Chapter 7's autoencoder row at a measured 9.27 s per fit — plausibly the
  single largest line item, and the reason `torch` gets its own artefacts.
- Chapter 9's `evaluator-audit.rds` and `metric-calibration.rds`, which multiply
  every cell by 3 reference geometries (one requiring an all-pairs Dijkstra —
  Isomap's cost again) × 4 values of $k$ × 2 candidate embeddings. **S2-2 merges
  these two into one script**: they share every cell and every distance matrix, so
  computing them separately doubles the Dijkstra cost for nothing.
- Chapter 11's `classic-grid.rds` over the three classical benchmarks.
- At least one full regeneration, because every number currently in hand was
  measured on an accordion-fold stand-in rather than a Miura.

**Shard the main run by (pattern, seed)** — 60 shards of roughly eleven minutes —
with `set.seed(BENCH_SEEDS[i])` *inside* each shard, so a failed shard is cheap to
re-run and seeding stays reproducible under parallelism.

**CI ceiling.** The render budget is ~90 minutes and the workflow currently
triples it by calling `render_book` three times (S0-4). No artefact is generated
in CI; all nine are committed and read.

## Risk register

| # | Risk | Severity | Mitigation |
|:--|:--|:--|:--|
| R1 | E1 shows crease patterns and Swiss rolls collapse onto one curve | **Fatal to Claim C** | E1 runs first; replacement claim pre-drafted (D1) |
| R2 | Chapter 9's finding is judged a restatement of Machado et al. 2025 | **Fatal** | Split the theorem out (D3); state the complement in the first paragraph; cite before drafting |
| R3 | The informative $\theta$ window is too narrow to resolve methods | Serious | Report against the irreducible-loss bound, not zero; add the product-construction axis; budget seeds (S2-3) |
| R4 | Numbers from the accordion-fold stand-in get transcribed into prose | Serious | S1-1 check 1 fails the build on any typed number |
| R5 | A failed PDF render deploys a green build with dead download links | Serious | S0-3 |
| R6 | Waterbomb admits no rigid folding | Moderate | E2 decides before Ch 8 drafts; two-family fallback pre-drafted, §8.3 already framed for it |
| R7 | $A(k)$ was written from memory and is wrong | Serious | S1-4; invariant tests hold regardless of the constant |
| R8 | Prose outruns the grid — chapters drafted against stand-in numbers | **Serious** | Artefact-first sequencing (below); S1-1 blocks typed numbers; no chapter drafts before its artefact is committed |
| R9 | Ch 12's null-result promise is hollow because the rule came after the result | Serious | S1-11: rule committed to git before any Ch 12 fit; no retroactive weakening |
| R10 | 60–100 h compute lands as a surprise mid-project | Moderate | Budgeted here as a decision, not a discovery; sharded by (pattern, seed); S2-2 merges the two Ch 9 artefacts |

---

## Progress log

- **2026-08-21, later** — **S0 closed, all eight.** `.gitignore` negation
  verified with `git add --dry-run`; Phase-11 tree committed; `docs/` untracked;
  render tolerance removed and replaced with a size-floor assertion on both
  artefacts; every download link probed; one `render_book` call; `write_bib()`
  moved to `scripts/write-package-bib.R` and `packages.bib` regenerated (`R-fs`
  and `R-yaml`, the fingerprint of the per-chapter overwrite, are gone); the
  three wrong sentences corrected; the nine-slot contract written into
  `00-how-to-use.Rmd`.

  Two items were not in this plan and had to be:

  - **The book had never rendered in CI.** Every push since 2026-08-07 died in
    `renv::restore()` on `libglpk.so.40`. `render-book.yml` had no apt step;
    `helpers.yml` has had one since it was written. Fixed, and the restore now
    passes.
  - **S1-7** (the citation page) was pulled forward, because the callout
    section of the section contract needs a call site for `boxempty` and
    inventing a cross-reference to a file that does not exist is how dead links
    start.

- **2026-08-21, later still** — **S1-2, S1-3 and S1-4 closed.**

  `verify-citations.R` hardened: identifier-less entries now fail unless marked
  `% NOIDENT-OK` in the bib file, and a bidirectional key check catches a `@key`
  cited in the sources but absent from the bibliography. Both holes were tested
  by deliberately breaking the bibliography four ways; all four now exit 1.

  Bibliography 9 → 25 entries, every field transcribed from a fetched metadata
  record. Three corrections came out of doing that, all recorded in
  `PROJECT_CONCEPT.md`: the Euler Isometric Swiss Roll is a *dataset* inside an
  SDM 2017 paper about streaming error metrics, not a paper title, and the
  second arXiv ID was a user of it rather than a co-primary; the Miura
  repository URL had to be found rather than assumed, since every record id on
  that host returns 200; and the unconfirmed ISSN was dropped.

  **$A(k)$ is transcribed from the primary** — Kaski et al. 2003, section
  *Measuring trustworthiness…*, with Eqs. (3) and (4). It matches what had been
  written from memory. The paper's own caveat, that $A(k)$ is a scaling and not
  a proven worst-case bound, is now recorded and belongs in Chapter 9.

- **2026-08-21** — Concept baseline. `foldbench` dissolved into `R/` (Phase 11,
  `GENERATION_LOG.md`); Miura and Yoshimura folding maps derived and numerically
  verified; Machado et al. 2025, Lause et al. 2024 and the Euler Isometric Swiss
  Roll confirmed as uncited direct antecedents; Kaski et al. 2003 and Miura report
  618 resolved; `.gitignore` `.rds` blocker and the `continue-on-error` render
  path identified. Phase-11 tree still uncommitted.
