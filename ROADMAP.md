# ROADMAP.md — Folding in R

**Status audit and improvement plan. Baseline: commit `85fe50a`, 2026-08-30.**

Companion to `PLAN.md` (sequencing and gates), `CHAPTERS.md` (per-chapter
specification), `PROJECT_CONCEPT.md` (claims) and `GENERATION_LOG.md` (history).
Where this file disagrees with those, this file is the later measurement and the
disagreement is itself the finding.

Severity follows the house convention: **S0** blocks everything, **S1** is
required before content ships, **S2** is quality, **S3** is optional.

---

## 0. The one-paragraph version

The engine is far ahead of the prose, and it is also ahead of its own
verification — which is the finding that should reorder the plan. Roughly 3.6k
words of prose exist against a target the budget table states as ~36,700 and its
own rows sum to ~41,670: about 91% of the book is unwritten. Against that, five
items the remediation ledger records as *closed* are still open in this tree, and
one of them is worse than open — the crease-label derivation the log certifies as
fixed disagrees with the labels it was meant to replace on 60% of interior
creases, and the property used to certify it cannot tell the two apart. Each of
the three claims is broken at a different joint: **Claim A** (Chapter 9, the
declared novel contribution, 4,400 words) has no producer script anywhere,
**Claim B** (Chapter 8, the post-E1 spine) has a producer that has never been run
to completion and no committed artefact, and **E1** has committed artefacts but a
producer that halts on its first cell. Most of this is cheap to fix. The
expensive and genuinely uncertain item is Claim A. The ledger has to become
trustworthy before 38,000 words are written on top of it.

---

## 0.1 Progress against this roadmap

Updated as items close. An item closes only when a named executable assertion
fails on the pre-fix tree and passes after, and the commit message says which.

| # | Item | State | Gate |
|---|---|---|---|
| 0.1 | `crease_assignment()` handedness; stored labels; regenerate the figure | **closed** | `test-crease-assignment.R`, 6 of 7 tests red pre-fix (167 assertions); figure block reproduces byte for byte apart from the 12 corrected labels |
| 0.2 | Orientation-independent M/V test over the size x alpha x theta sweep | **closed** | same file; also settles open question 1 (section 11) |
| 0.3 | Re-verify every R- and S-series closure by measurement | **mostly closed** | `EMBED_DIM` drift test; `PATTERN_GRID` via `check-artefact-producers.R`; figure-export and neighbour-method mutations demonstrated red. S1-3 (bibliography) deferred to 2.4/2.5 |
| 0.6 | `check-artefact-producers.R` | **closed** | reports the 3 real gaps; fails on a registry naming an unfoldable family, on a missing provenance block, on a `--quick` artefact committed as evidence |
| 0.4 | E1 producer and artefacts | open | |
| 0.5 | Correct the two documents that describe what E1 shipped | open | |

---

## 1. How this audit was produced, and what that means for confidence

Eight independent read-only audits (prose gap, R source quality, test suite,
CI/build/reproducibility, scientific integrity, plan-vs-reality, publishing
metadata, compute pipeline), followed by adversarial verification of every
S0/S1 finding, followed by synthesis.

**19 findings went to adversarial verification. 2 were confirmed as stated; 17
were downgraded or partially refuted.** That ratio is the most important
methodological fact in this document: the first-pass findings were substantially
overstated, and several proposed *fixes* would have made things worse. The
verification pass ran mutation tests, re-ran E1 arms under cluster bootstrap, and
re-ran the product grid at production settings rather than re-reading code.

Everything below is stated at its post-verification scope. Findings marked
**[measured here]** were verified directly against this working tree during the
audit, with the command and output recorded.

**Known gap:** the *plan-vs-reality* auditor failed to return (schema retry cap),
so a systematic item-by-item reconciliation of `PLAN.md`'s S- and R-series
against the tree was not completed. Partial coverage came from the other seven
dimensions. **Completing that reconciliation is itself Phase 0 work** (item 0.3).

---

## 2. Where the project actually stands

### 2.1 Prose

Measured by stripping YAML, code chunks and headings from all 28 `.Rmd` files:

| Scope | Words |
|---|---:|
| Whole book, all `.Rmd` | **3,631** |
| The twelve body chapters (`01`–`12`) | **1,387** |
| Largest real prose: `00-how-to-use` / `A2-datasets` / `90-glossary` | 598 / 513 / 340 |
| Target stated in `CHAPTERS.md:11` and `PLAN.md:36` | ~36,700 |
| Target implied by summing the table's own rows | **~41,670** |

Structurally: **1 of 53** specified figures exists, **2 of 145** specified code
chunks exist, **2** real citation instances against ~162 specified, and
`book.bib` holds 26 entries against S1-3's own ~40 criterion. All twelve body
chapters carry `<!-- TODO: chapter content -->`. The nine-slot section contract
appears in **zero** chapters.

### 2.2 Engine

~3,950 LOC across ten files in `R/`, ~1,950 LOC in `scripts/`, ~95 KB across ten
test files, 59 top-level functions, 147 packages pinned in `renv.lock` at R
4.6.1.

### 2.3 CI

Six workflows. **All green on all 44 commits.** Book renders in ~11 minutes, not
the 90-minute ceiling `PLAN.md` feared. `Link check` is the exception — it has
run once (2026-08-24) and failed, and five of its six errors are true positives.

### 2.4 Evidence ledger

| Claim | Chapter | Words | Producer | Artefact | State |
|---|---|---:|---|---|---|
| **A** — evaluators are optimistic, with a quantitative law | 9 | 4,400 | **none** | **none** | no code at all |
| **B** — irreducible loss; report against the floor | 8 | 3,650 | `run-product-grid.R` | **none committed** | run once in `--quick`, never saved |
| **E1** — branch separation (replaced Claim C) | 11 | 3,000 | `experiment-e1.R` | 3 committed | **producer cannot run** |

Five of the seven artefacts named across `CHAPTERS.md` and `PLAN.md` have no
producer script: `part2-sweeps`, `classic-grid`, `evaluator-audit`,
`metric-calibration`, `autoencoder-grid`.

---

## 3. What is finished — do not reopen

Re-opening these is the most tempting way to avoid writing.

- **RNG and seeding discipline** across `sampling.R`, `baselines.R`, `methods.R`.
  Tests confirm methods leave the caller's stream alone and repeat exactly.
- **The E2 waterbomb spike** — the only experiment in the repository that
  reproduces end to end from its own scripts.
- **The Eckart–Young derivation** of the irreducible-loss bound and its four
  explicitly stated assumptions.
- **`A2-datasets.Rmd`'s external-data determination** — the CC BY 4.0 finding,
  the label-provenance argument, and two named caveats. S1-8/9/10 are genuinely
  closed *in prose*, not merely in a log.
- **The download-probe fix** in `style/after-body.html` — S0-3 is properly
  closed; both remaining `continue-on-error` uses in `render-book.yml` are benign
  (a `tinytex` install and a comment). **[measured here]**
- **`lint-chapters.R`'s self-removing stub exemption** — it disarms at exactly
  the moment drafting starts. Verified: exits 0 today, exits 1 in a scratch copy
  with a chapter's TODO removed.
- **The renv CI cache** — 110 packages in ~8 seconds.
- **Chapter 11's headline numbers**, which reproduce from the committed
  artefacts to three decimals.

---

## 4. The five systemic themes

Individual defects are listed in §7. These are the patterns behind them, and
they are what actually needs fixing.

### T1 — "Recorded as closed" is not verified closed

*Appears in: r-code-quality, tests, ci-build-repro, scientific-integrity,
compute-experiments, content-gap.*

Closure is verified by re-reading the changed code rather than by measuring the
property the change was supposed to establish. Confirmed still-open items that
the ledger records as closed:

1. **The crease labels** (see §5 — the worst case).
2. **E1 provenance.** All three `data/processed/*.rds` have
   `attr(x, "provenance") == NULL`, while `GENERATION_LOG.md:460` and
   `CHAPTERS.md:588` both assert they carry it. The `.e1_save()` helper landed at
   `8640a2d` (2026-08-26); the artefacts date from `94833e7` (2026-08-22). The
   code was fixed and the artefact was never regenerated. **[measured here]**
3. **`rank_metrics()`** — written, benchmarked at 5.85 s vs 0.44 s, documented as
   existing precisely to de-duplicate the grid's rank matrices, and it has **zero
   callers** in `scripts/`.
4. **`EMBED_DIM_DEFAULT`** still shadows `EMBED_DIM` after R1-4 closed.
5. **`PATTERN_GRID`** still names `yoshimura` and `waterbomb` after E2 withdrew
   both.
6. **S1-3** closed at 26 bibliography entries against its own ~40 criterion.

**Systemic fix.** Redefine closure: *an item closes when there exists a named
executable assertion that fails on the pre-fix tree and passes after.* Put the
demonstration in the commit message. Re-open every closure that cannot produce
one.

### T2 — The invariants under test are symmetric to the errors that occur

*Appears in: tests, r-code-quality, ci-build-repro.*

Tests assert a property that is cheap to compute rather than measuring the
claimed quantity by an independent route. Confirmed instances:

- **Maekawa is invariant under global M↔V inversion**, so it passes on
  labellings that contradict each other (§5).
- **`test-figure-export.R:25-36` is tautological** — it re-implements the
  isometry check inline and asserts its own `stop()` fires. Deleting the
  production guard at `R/figure-export.R:39-42` leaves the file at 27/27 passing.
- **`embed_lle()` and `embed_laplacian()` can return `NULL` for every input with
  the suite green.** Replacing both bodies with `return(NULL)` gives FAIL 0. So
  does flipping `order(...)[2:(d+1L)]` to `[1:d]` at `R/methods.R:163` and `:197`
  — while qnx@10 collapses from 0.9363 to 0.2507 (LLE) and 0.7357 to 0.3413
  (Laplacian).
- **"The R and browser visibility computations agree"** executes no JavaScript.

**Systemic fix.** Make *mutation* the acceptance criterion, not coverage. For
each stated invariant and each production guard, require a test whose passing
depends on the implementation being right — demonstrated by breaking the
implementation and watching it go red.

> **Adopted.** The figure-export guard, the static figure's view, and both
> neighbour methods now have tests demonstrated red under the exact mutation
> described. The parity claim about the browser was renamed rather than fixed and
> stays open: a real check needs `js/fold-figure.html` run under Node with a
> canvas, compared against `visible_facets()` at several views.

### T3 — Each claim is broken at a different joint of producer → artefact → prose

There is no single check that the chain is intact, so each link failed
independently and invisibly. See the table in §2.4.

**Systemic fix.** `scripts/check-artefact-producers.R` in CI, asserting that
every artefact named in `CHAPTERS.md` resolves to exactly one script, that every
script's declared registries can actually be built and folded (this would have
caught the dead yoshimura arm), and that every file under `data/processed/`
carries a provenance attribute. Base R and `readRDS` only, so it needs no library
restore.

### T4 — The anti-fabrication gate stops at the boundary between prose and the documents prose is written from

`lint-chapters.R` check 1 runs over `prose_rmd` only, and `PLAN.md:485` calls it
"the anti-fabrication gate and the most valuable line in that file". But a
drafter works from `CHAPTERS.md` — and `CHAPTERS.md`, `PLAN.md`,
`PROJECT_CONCEPT.md` and `GENERATION_LOG.md` are all outside the gate. What has
accumulated there:

- The re-budget table where **neither total matches its own column** (rows sum to
  41,670 vs a stated ~36,700; 41,720 vs a stated 41,070).
- A quick-mode `0.0060` elevated to "the book's thesis in one table".
- Three different values for the Swiss-roll contraction (1059%, 1070%, 1071.27%).
- A floor quoted as 0.61–0.66 that measures 0.576–0.596.
- A compute budget derived from a cell count that is 2× the real one.

**Systemic fix.** Require every decimal in the four governing documents to carry
a provenance marker naming an artefact path or a test file; CI greps for a bare
decimal without one. Cheaper than it sounds, because most of these should be
inline `r` expressions eventually anyway.

### T5 — Standing rules stated unconditionally to the reader are violated by every experiment that has run

`00-how-to-use.Rmd:7` states "Every stochastic result is reported across at least
20 seeds" with no qualification. `experiment-e1.R:35` uses `BENCH_SEEDS[1:10]`;
`:192` uses `[1:5]` for the arm that produced the 5.1× headline;
`run-product-grid.R:46` uses `[1:10]`. Only the ungenerated main grid uses 20.
Likewise `00-how-to-use.Rmd:16` promises every figure carries `fig.alt`; the lint
checks the *source*, while Chapter 1's HTML branch returns `asis_output()` and
discards caption, alt text and the `fig:` anchor.

**Systemic fix.** Move each standing rule from prose to a check over the
*rendered or committed output*. Where the rule cannot hold, amend the rule rather
than leaving the promise standing.

---

## 5. The crease labels — the finding that reorders the plan

`GENERATION_LOG.md:445-449` records the crease-label defect as fixed: the labels
are now "derived from the geometry" and "satisfy Maekawa at 16 of 16". Both
statements are true. The conclusion drawn from them is not.

**Measured on `miura_ori(5,5)` at θ = 0.5 [measured here]:**

| Labelling | Maekawa | Agreement with stored |
|---|---|---:|
| Stored (parity rule, what every figure draws) | **16/16** | — |
| Derived (`crease_assignment()`, the recorded fix) | **16/16** | **16/40 (40%)** |
| Derived, globally inverted | **16/16** | 24/40 (60%) |

Three mutually inconsistent labellings all satisfy Maekawa. Two of them disagree
on 60% of interior creases and both pass. **Maekawa's |M − V| = 2 is invariant
under global M↔V inversion, so it cannot discriminate — it is exactly symmetric
to the class of error present.** This is T2 in its purest form, and the property
was used as the acceptance evidence.

Against an independent height-based ridge/trough criterion (crease midpoint z
against the mean z of the two opposite facet points), neither labelling is
right: derived agrees on exactly **25.0%** at every size and every θ tested
(4×4, 5×5, 6×6 × θ ∈ {0.2, 0.5, 0.9}), stored on **42–55%**. **[measured here]**

The mechanism is visible on inspection at `R/folding.R:219`. `fs[1:2]` orders the
two adjacent facets by facet index and the axis runs `i → j`; both orderings are
arbitrary, and swapping either negates the triple product. The handedness is
therefore family-dependent rather than fixed.

> **Do not** adopt the proposed assertion
> `expect_identical(crease_assignment(p), p$creases$assignment)`. Pinning stored
> to derived would take a figure that is substantially wrong and make it
> uniformly wrong, dashing physical ridges as valleys. **Fix the derivation's
> facet ordering first**, then repoint stored at it.

Two independent measurements (the synthesis pass and this one) used different
ridge/trough criteria and produced different agreement rates — 0/N versus 25% —
but agree on both facts that matter: **the derived labels are no better than the
labels they replace, and Maekawa cannot tell them apart.** Establishing the
correct criterion is the first task in Phase 0, and the disagreement between the
two measurements is itself a reason to write an orientation-consistent test
rather than trusting either number.

---

## 6. Critical path

The honest answer to "what is the ONE next thing", in dependency order.

1. **Fix `crease_assignment()`'s handedness** and gate it with an
   orientation-independent test. Not because the labels are cosmetic — because
   this is the proof that the remediation ledger cannot be trusted, and every
   later step is an act of trusting or re-verifying that ledger.
   *Gate:* a test computing M/V from facet-normal orientation, sharing no code
   with `crease_assignment()`, fails on today's stored **and** derived labels and
   passes only after the fix — run over the existing θ × α sweep in
   `test-folding.R`, not at a single point. Then regenerate
   `js/fold-figure.html` and check its embedded assignment string matches.

2. **Re-verify by measurement every remediation recorded as closed.** Six known
   misses (§4/T1) in one pass, one of them inverted.
   *Gate:* every item marked closed in the R- and S-series carries a named
   executable assertion demonstrated to fail on the pre-fix tree. Items that
   cannot produce one are reopened. This subsumes the plan-vs-reality
   reconciliation that the audit failed to complete.

3. **Restore the E1 producer and regenerate its three artefacts with real
   provenance.** `experiment-e1.R:61-66` still declares the withdrawn `yoshimura`
   FAMILIES entry; `.fold_yoshimura()` (`R/folding.R:158-166`) is now a bare
   `stop()`; `one_cell()` calls `fam$make()` outside any `tryCatch` — the four
   `tryCatch` calls all wrap the embedding method, never the generator. The
   script halts after `done: miura`, **before** the arm A save, **before** arm
   A2/A3 writes `e1-controlled.rds` (the decisive artefact), and **before** arm
   B. The evidence that retired Claim C and rewrote the book's spine cannot be
   regenerated, extended, or given more seeds. Minutes of work.
   *Gate:* `--quick` exits 0; all three artefacts carry non-NULL
   `provenance$r_sha`; `e1-difficulty.rds` drops from 1,590 to 990 rows as the
   600 pleat-era yoshimura rows go.

4. **Produce and commit `product-grid.rds` at production settings** — Claim B's
   only artefact, carrying Chapter 8's 3,650 words. The genuine defect is
   `boundary = TRUE` at `run-product-grid.R:51-54`, which gives a 10.55%
   chart-exit fraction against 0.0000 with `boundary = FALSE`, and moves the
   floor by 0.066 — **eleven times the headline excess**.
   *Gate:* runs without `--quick` at `boundary = FALSE`, artefact committed with
   provenance recording the boundary setting and a measured chart-exit fraction
   of 0, and every Chapter 8 §5 number reads from it via an inline `r` expression.

5. **Settle the eval policy and close the lint gaps that fire on the first line
   of real prose.** `_common.R:3` sets `eval = FALSE` globally with no lint
   check; 145 chunks are specified; the failure is silent and takes the figure,
   its caption and its `fig.alt` with it. Simultaneously
   `lint-chapters.R:275` loops `check_contract` over `body_rmd` although line 30
   built `prose_rmd` for it, so the appendices — the only files it could enforce
   on today — are never checked.

6. **Write `scripts/run-evaluator-audit.R`** — Claim A has no code at all. Its
   only numbers came from the accordion pleat now documented as a negative
   result, in the θ parameterisation retired in Phase 14. Run the pilot first
   (§8, R1).

7. **Generate the main grid, then draft — Chapter 2 first, Chapter 1 last.** The
   grid is 1 × 20 × 3 × 20 = **1,200 cells**, not the 2,400 `PLAN.md:416` still
   computes, at roughly **4–6 hours** single-core rather than the quoted 20.
   Chapter 10's pre-registered selection rule must be committed **in its own
   commit** before `prepare-single-cell.R`'s deliberate `stop()` is removed, so
   the git timestamp proves the rule preceded the result.

---

## 7. Phased plan

### Phase 0 — Trust repair · 2–3 days

*Goal: make the evidence layer correct and regenerable, and make "closed" mean
something. Nothing after this is worth doing until this is done.*

| # | Item | Sev |
|---|---|---|
| 0.1 | Fix `crease_assignment()` handedness (order facets by edge traversal, not index); repoint `miura_ori()`'s stored labels at it; regenerate `js/fold-figure.html` | S0 |
| 0.2 | Add an orientation-independent M/V test over the existing size × α × θ sweep, demonstrated to fail on both current label sets | S0 |
| 0.3 | Re-verify every closure in the R- and S-series by measurement; reopen those without an executable assertion. **Includes the plan-vs-reality reconciliation this audit did not complete** | S1 |
| 0.4 | Delete the `yoshimura` entry from `experiment-e1.R` FAMILIES; add `np` to arm A; re-run and commit all three artefacts with provenance | S1 |
| 0.5 | Correct `GENERATION_LOG.md:460-462` and `CHAPTERS.md:588` to describe what actually shipped | S1 |
| 0.6 | Add `scripts/check-artefact-producers.R` to CI (T3) | S1 |

**Exit:** the new M/V test is green and was demonstrated red on both label sets;
`provenance$r_sha` non-NULL on all three E1 artefacts; `e1-difficulty.rds` at 990
rows; `check-artefact-producers.R` in CI with failures either fixed or recorded
as open with a named owner.

### Phase 1 — Evidence the claims · 1–2 weeks, mostly wall-clock

*Goal: give each claim a producer and a committed artefact, so the artefact-first
rule can actually gate drafting.*

| # | Item | Sev |
|---|---|---|
| 1.1 | Run and commit `product-grid.rds` at production settings, `boundary = FALSE`; add a `chart_exit_fraction` assertion to its self-check | S1 |
| 1.2 | Restate Chapter 8 §5 as a curve over θ; correct "nine methods" to eight; reframe "unbeaten" as a regression check on a proved bound | S1 |
| 1.3 | Add a Swiss-roll-product arm so Claim B's family-agnosticism is a stated finding rather than a refuted differentiator (§8, R5) | S1 |
| 1.4 | **Pilot the evaluator audit** — 3 θ × 4 k × 2 n × 20 seeds, ~1 h compute — to establish whether the inversion threshold exists on the Miura in [0,1] | S1 |
| 1.5 | Write `scripts/run-evaluator-audit.R` using `rank_metrics()`; commit `evaluator-audit.rds` | S1 |
| 1.6 | Settle the seed budget: measure within-cell sd for the three stochastic methods, set a per-method count in `_common.R`, reconcile with standing rule 1 (T5) | S1 |

**Exit:** `product-grid.rds` and `evaluator-audit.rds` committed with full
provenance; the Claim A pilot has returned a yes or a no and Chapter 9's budget
reflects the answer; the seed floor is either met by every artefact or carries a
named per-artefact exemption.

### Phase 2 — Drafting preconditions · 3–5 days

*Goal: close every gate that would fire on the first commit of real prose.*

| # | Item | Sev |
|---|---|---|
| 2.1 | Settle the `eval` policy in `_common.R`; add the lint check that enforces it | S1 |
| 2.2 | Fix `lint-chapters.R:275` to loop over `prose_rmd`; add anchors to `A2-datasets.Rmd` | S1 |
| 2.3 | Rename Chapter 1's four anchors in `CHAPTERS.md` to the nine-slot contract. **Leave 8, 9 and 12 alone** — verified as anchor-free budget tables | S1 |
| 2.4 | Add `uwot`, `diffusionMap`, `FNN`, `kernlab`, `coRanking` to `write-package-bib.R`'s PKGS; regenerate `packages.bib` | S1 |
| 2.5 | Add method-primary references (Belkin, Coifman, Schölkopf, Torgerson, Sammon, Hinton); reopen S1-3 against a target derived from the chapter specs | S1 |
| 2.6 | Implement `read_run()` with the digest check — the helper both `PLAN.md` and `CHAPTERS.md` say every chapter from 4 onward opens with, which does not exist | S1 |
| 2.7 | Delete the three refuted stub bullets: Yoshimura/waterbomb at `08:8`, "rankings that flip" at `11:8`, the pattern axis at `10:7` | S2 |
| 2.8 | Restate both re-budget totals from the rows; propagate to `PLAN.md`, `PROJECT_CONCEPT.md` and the five stale chapter headings | S2 |
| 2.9 | Fix Chapter 1's HTML figure to emit the `fig:` anchor, caption and alt text so numbering does not diverge between formats | S2 |

**Exit:** a scratch chapter containing a figure chunk, a package citation, a
`read_run()` call and the nine contract headings passes lint, citation-check and
a full three-format render **with the figure numbered identically in all three**.

### Phase 3 — Grid generation · 3–4 days work plus ~1 day compute

| # | Item | Sev |
|---|---|---|
| 3.1 | Refactor `run-benchmark-grid.R`'s loop body into `one_cell()`; add `--shard`/`--merge` and `parallel::mclapply` | S2 |
| 3.2 | Hoist the rank matrices and `irreducible_loss()` out of the method loop; wire `rank_metrics()` to its only consumer | S2 |
| 3.3 | Replace hard-coded `k` literals with `K_DEFAULT`; record metric reference geometry and `k` in provenance | S2 |
| 3.4 | Split the failure columns into `status` and `reason`; capture `conditionMessage` rather than discarding it | S1 |
| 3.5 | Factor one `.provenance()` helper: repo SHA, `R/` SHA, dirty-tree state, R version, BLAS, package versions, date, elapsed, cores | S2 |
| 3.6 | Write `run-part2-sweeps.R` and `run-classic-grid.R` as thin wrappers over `one_cell` | S2 |
| 3.7 | **Write §10.8's pre-registered selection rule as a decision procedure over grid columns, in its own commit, before the grid runs** | S1 |

> Sharding must stamp each shard with its own `R/` SHA, or resume-by-file-existence
> will silently merge rows from different code states under one provenance block.

**Exit:** `benchmark-grid.rds`, `part2-sweeps.rds`, `classic-grid.rds` committed
with full provenance; serial and parallel `--quick` runs produce identical
artefacts after sorting; §10.8 committed before any Chapter 12 prose.

### Phase 4 — Drafting · 3–5 months at a sustained weekly rate

1. **Chapter 2 (3,900 w) first, to completion**, to prove the drafting loop and
   measure its real cost per thousand words.
2. Part I: Chapter 3, then **Chapter 1 last**.
3. Part II: Chapters 4, 5, 6. **Decide and most likely cut Chapter 7.**
4. Part III: Chapters 8, 9, 10, then 11, then 12.
5. Chapter 13, accounting for two refutations, two withdrawals and any cut chapter.
6. Extend `A2-datasets.Rmd`'s precomputed-results list as each artefact lands.

**Exit:** every body chapter carries the nine contract sections, every number
resolves from a committed artefact through an inline `r` expression,
`lint-chapters.R` reports zero stubs, three-format render green.

### Phase 5 — Publication · 3–4 days

| # | Item |
|---|---|
| 5.1 | Enable GitHub Pages on `gh-pages`; add `.nojekyll`; fix the two stale comments asserting `gh-pages` does not exist (`link-check.yml:54-56`, `GENERATION_LOG.md:15`) — **after** there is a book (§8, anti-goals) |
| 5.2 | Fix `CITATION.cff` to `type: software` with a `preferred-citation` book block; add validation to `citation-check.yml` |
| 5.3 | Add `lang`, `identifier`, `rights`, `publisher`, `keywords` to `index.Rmd` YAML; add `epubcheck` to CI; set `papersize: a4`, `lof: true` |
| 5.4 | Add the dark-mode highlight palette and search-dropdown overrides; add a contrast check over both themes |
| 5.5 | Write real CHANGELOG sections; tag `v1.0.0`; cut a release; enable Zenodo; propagate the DOI to all five citation surfaces |
| 5.6 | Add `LICENSE-DATA.md` and `THIRD-PARTY.md`; add issue templates and `97-errata.Rmd` |
| 5.7 | Land the VG Wort pixel injection and the eligibility `--check` mode |
| 5.8 | Add dependabot; pin actions to SHAs; add a `concurrency` group to `render-book.yml`; pin `r-version` |

**Exit:** canonical URL returns 200; `link-check.yml` green including the site
job; `epubcheck` zero errors; DOI resolves; `CITATION.cff` renders a BibTeX entry
in GitHub's sidebar.

---

## 8. Risk register

**R1 — Claim A does not reproduce.** *Likelihood medium · Impact high.*
The inversion threshold — the declared novel contribution, Chapter 9's 4,400
words — has never been computed on the Miura in the [0,1] parameterisation. Its
only supporting numbers came from an accordion pleat now documented as a negative
result, in a θ range retired in Phase 14.
*Mitigation:* run the narrow pilot (item 1.4) **before** committing to the
chapter — 3 θ × k ∈ {5,10,20,40} × n ∈ {400,800} × 20 seeds on `miura_ori`,
handing each evaluator the exact chart as a candidate against a 2-component PCA
of the folded cloud. ~1 hour. If the inversion is absent or pleat-only, report
the pleat result as a property of a degenerate surface and re-budget Chapter 9
down — a decision worth making at 4,400 words rather than discovering at 3,000
drafted.
*Early warning:* the pilot shows no θ at which an ambient-referenced evaluator
ranks the exact truth below a PCA embedding.

**R2 — Writing velocity.** *Likelihood high · Impact high.*
~38,000 words remain against ~3,600 written, and the engine has held the
project's attention for months. Every incremental piece of infrastructure is more
attractive than the first paragraph of Chapter 2.
*Mitigation:* timebox Phases 0 and 2 hard; treat Phase 1 as the last permitted
engineering. Draft Chapter 2 to completion before touching anything else. Set a
weekly word floor and record it in `GENERATION_LOG.md` alongside the compute
figures.
*Early warning:* two consecutive working sessions produce commits touching only
`R/`, `scripts/` or the planning documents.

**R3 — More closures are wrong.** *Likelihood high · Impact medium.*
Six confirmed in one pass, one of them inverted. A second inverted sign
discovered after chapters are drafted on top of it means rewriting prose, not
just code.
*Mitigation:* item 0.3, done before drafting rather than during. Prioritise
anything feeding a figure or a reported number: the folding invariants, the
metric floor, the contraction claim, the isometry guards.
*Early warning:* any closed item whose recorded acceptance evidence is a property
invariant to the class of error it was meant to catch — the exact signature of
the crease-label miss, and greppable by reading each closure's criterion and
asking what it would still pass on.

**R4 — One pattern family cannot honestly carry 41,670 words.**
*Likelihood medium · Impact medium.*
E2 reduced the book to a single verified family. Chapter 3 lost 750 words for
exactly this reason and its section table still overshoots by 30%; Chapter 10's
grid is a third of its planned size; Chapter 7 has no implementation.
*Mitigation:* re-derive the budget bottom-up from what each chapter can now
evidence rather than patching a table that is internally inconsistent in both
columns. **Decide Chapter 7 now** — cut it, account for the cut in Chapter 13,
reclaim 1,600 words. Accept a 35,000-word book that is fully evidenced over a
41,670-word one that pads.
*Early warning:* a drafted chapter comes in >20% under budget without feeling
thin, or a section's allocation cannot be spent without restating the previous
section.

**R5 — Claim B's crease-specificity does not hold.** *Likelihood medium · Impact
medium.*
`product_manifold()` imposes no family constraint; on two isometric Swiss rolls
it gives intrinsic dimension 4 with an exact chart and a computable floor — which
refutes the second of the three differentiators at `PROJECT_CONCEPT.md:183-186`,
and it is the one the spine's artefact is meant to demonstrate.
*Mitigation:* do not delete the differentiator quietly. Add the Swiss-roll-product
arm (item 1.3) and make the comparison itself the finding: the bound is
family-agnostic, and here are the two families' floors side by side. Stronger and
more honest than the claim it replaces, and it costs one arm on a grid you are
running anyway. Rest crease-specificity on zero reach and the non-smooth answer
key.
*Early warning:* Chapter 8 §5 cannot state in one sentence what the product bound
owes to creases and what it does not.

**R6 — The last two content chapters sit at the end of the longest dependency
chain.** *Likelihood medium · Impact medium.*
Chapter 12 (3,000 w) is gated on the selection rule, gated on the main grid;
Chapter 9 (4,400 w) is gated on an artefact with no producer. Together 7,400
words — 18% of the book — behind everything else.
*Mitigation:* write the selection rule as soon as the grid's **schema** is fixed,
which is before the grid runs — the rule needs the columns, not the values.
Commit it separately so the timestamp is unambiguous. Start the evaluator-audit
producer in parallel with the grid; they share no inputs.
*Early warning:* the grid finishes and §10.8 is still unwritten, or three
different section numbers for the selection rule survive into drafting —
`CHAPTERS.md:79`, `CHAPTERS.md:500` and `PLAN.md:54` currently disagree.

---

## 9. The anti-roadmap — what NOT to do

Every item here was proposed by an auditor and **refuted or materially downgraded
under verification**. Acting on them would waste effort or cause harm.

**Would actively make things worse**

- **Do not pin stored crease labels to `crease_assignment()`.** §5. It would take
  a figure that is substantially wrong and make it uniformly wrong.
- **Do not implement the proposed `embed_laplacian()` bandwidth ladder.**
  Measured at the grid's real n = 800 it gives a **40% run rate**, failing the
  proposal's own "~100%" criterion. The diagnosis is inverted — `t2` is already
  the robust kNN scale; the failure is that outlier points sit 17.6× further from
  their neighbours than the bulk, which calls for a per-point or self-tuning
  bandwidth. And do not swap in symmetric normalisation without the D^(-1/2)
  back-transform: raw symmetric gives qnx 0.6050 against the current 0.7638.
- **Do not implement `attr(NULL, "unran_reason")`.** It is an error in R, and any
  substitute breaks the `is.null(emb)` contract in both grid scripts and in
  `embed()`. Keep the sound parts: capture `conditionMessage`, split `status` from
  `reason`.
- **Do not pin the NULL-returning method set to an allowlist of
  `{"autoencoder"}`.** It fails on any checkout without `diffusionMap` and
  contradicts the deliberate design in which isomap's backstop and the R1-3
  laplacian guard also return NULL.
- **Do not apply the proposed lychee `--base .` fix.** `--base` was removed from
  lychee on 2026-05-30 and the action runs v0.24.2 — the step would fail. Use
  `--exclude-path style/header.html`.

**Would waste effort on a non-problem**

- **Do not retract or hedge E1's 5.1× separation.** A cluster bootstrap over
  settings gives **5.06, 95% CI [1.57, 10.18]**, with only 1.3% of replicates at
  or below 1; cluster-robust regression gives p = 0.026 (0.021 with a spline
  adjustment). Only the unadjusted Welch on 5 vs 9 raw setting means — the one
  test that discards the covariate shown to matter — is non-significant. *Do* add
  a CI, name nine settings rather than 35 rows, and state the roll/3.00 and
  roll/4.00 near-zero spreads. Do not rewrite the chapter as a failed comparison.
- **Do not rewrite Chapter 8 believing the product-grid ordering reverses at
  production scale.** Measured at production settings: PCA/MDS have the lowest
  excess at **all nine θ** (0.0018–0.0155 for θ 0.1–0.8; 0.1502 at θ 0.9), no
  method beats the floor, and ambient < geodesic < neighbourhood holds throughout.
  At the two θ quick mode used, production gives 0.0042 — *lower* than the
  reported 0.0060. Label 0.0060 provisional, run the real grid, restate as a
  curve. The claim survives.
- **Do not run a twelve-file stub reconciliation pass.** Overwriting stub outlines
  from `CHAPTERS.md` contradicts `CHAPTERS.md:23-25`, pasting its section tables
  trips lint check 1 on comma-grouped word counts, and the acceptance criterion is
  unsatisfiable. The real work is deleting three bullets (item 2.7). Minutes, not
  hours.
- **Do not respecify chapters 8, 9 and 12 onto the nine-slot contract**, and do
  not treat it as "the largest structural decision still open". Those are
  two-column budget tables carrying no anchors, and chapter 8's nine rows draft
  cleanly onto the nine contract anchors as H3 subsections. Only Chapter 1's four
  literal anchors conflict — a rename in one table.
- **Do not treat the re-budget arithmetic as S1** or spend a day redistributing
  against it. No workflow or lint rule reads a word budget, and the error makes
  the target too *low*. Restate both totals from the rows, drop the "~36,700"
  quantification, propagate, move on.
- **Do not prioritise sharding as an S0 blocker.** Nothing is committed to lose —
  the grid has never been produced; the in-memory accumulator is 28.8 MB, not an
  OOM risk; real single-core cost is ~4–6 h, not the 20 quoted. Do the `one_cell`
  refactor in Phase 3 for the recovery and speed benefit.
- **Do not enable GitHub Pages before there is a book.** Three audits called this
  S1; verification downgraded it twice. Publishing now puts a ~91%-unwritten
  scaffold at the URL `CITATION.cff` calls version 0.1.0, which is worse than an
  honest 404. The link-check failure it causes is a **true positive**, not a
  broken gate, and `render-book.yml` already runs a blocking internal-link check
  over `docs/` on every push.
- **Do not compute a Q_NX floor.** The most interesting open question the audit
  raises, and a research project rather than a book task — scored at weeks. Claim
  A has no producer yet; that is where research effort belongs. State the absence
  of a co-ranking floor as a *result*, and correct `run-product-grid.R:35-37`'s
  rationale, which describes a confound that cannot occur.
- **Do not build an R package, add roxygen across the codebase, or add covr and
  property-based testing now.** The plain-scripts decision is correct at this
  size, and `R CMD check`'s undefined-globals pass would not have caught the
  `EMBED_DIM` duplicate. Targeted mutation tests beat broad coverage
  instrumentation. `tests/testthat/setup.R` already gives the anti-drift property
  a package would buy. The one worthwhile piece is a cheap CI grep for bare
  tolerance literals and near-identical constant names.
- **Do not budget for Chapter 7.** No implementation, `torch` recorded-but-
  uninstalled, out of the main grid, three named artefacts with no producer, and
  `CHAPTERS.md:732-737` already flags it as likely cut. Decide now and reclaim
  1,600 words — which also disarms the latent `@R-torch` citation trap, where
  `write-package-bib.R` permanently exempts `R-torch` while `verify-citations.R`
  builds its known set from the committed `packages.bib`.

---

## 10. Finding ledger

Full per-dimension findings, with post-verification scope. **[V]** = adversarially
verified; **[M]** = measured directly against this tree during the audit.

### Scientific integrity

| Sev | Finding |
|---|---|
| S1 | `experiment-e1.R` cannot execute — the withdrawn yoshimura arm halts it before the decisive artefact is written **[V, confirmed]** |
| S1 | Claim A has no producer, no artefact; its numbers come from the withdrawn pleat in a retired parameterisation |
| S1 | Claim B's headline is `--quick` output, never saved; production settings *do* reproduce the ordering **[V]** |
| S1 | `product_manifold()` works on two isometric Swiss rolls, refuting the second stated differentiator |
| S1 | The product grid samples `boundary = TRUE` for no stated reason — 10.55% chart exit, floor moves 0.066 |
| S1 | E1 artefacts carry no provenance while two documents assert they do **[M]** |
| S2 | E1's 5.1× is reported on pseudoreplicated seed-level rows with no interval; the effect survives clustering **[V]** |
| S2 | Claim B's floor exists for only one of the two headline metrics |

### Tests

| Sev | Finding |
|---|---|
| S0 | Crease labels disagree with the derived folding; the certifying property cannot discriminate **[M]** |
| S1 | `embed_lle()`/`embed_laplacian()` can return NULL for every input with the suite green **[V]** |
| S1 | `test-figure-export.R`'s refusal test never calls the guard it claims to test **[V]** |
| S1 | `R/plotting.R` — 23 KB, 15 functions, every figure in the book — has no test file **[M]** |
| S2 | `chart_exit_fraction()`, the diagnostic that defended E1, is never tested **[M]** |
| S2 | `renv.lock` changes do not trigger the suite; four `skip_if_not_installed()` let a partial library go green |
| S2 | No mutation, property-based or coverage measurement |

### R source quality

| Sev | Finding |
|---|---|
| S1 | `fold_figure_static()` computes visibility in a view 90° from the one it draws **[V, confirmed]** |
| S2 | The grid rebuilds the same two rank matrices per metric; `rank_metrics()` exists and has zero callers |
| S2 | `EMBED_DIM`/`EMBED_DIM_DEFAULT` duplicate one quantity |
| S2 | `embed_tsne()` declares `k` and never uses it — a k-sweep would draw a flat curve that means nothing |
| S2 | `PATTERN_GRID` and `R/README.md` still name withdrawn families |
| S2 | qnx scored against the chart at K=20, trust/cont/knn against ambient at k=10, undocumented |

### Compute pipeline

| Sev | Finding |
|---|---|
| S1 | A failed fit records no reason; three causes collapse into one indistinguishable state |
| S1 | `embed_laplacian()` returns NULL on **every** outlier-noise cell — 400 of 1,200 laplacian cells **[V]** |
| S1 | The pre-registered selection rule (S1-11) exists nowhere; three documents give it three section numbers |
| S1 | Standing rule "≥20 seeds" is violated by every experiment that has run **[V]** |
| S2 | No checkpointing: an interrupted grid restarts from zero (downgraded from S0 — nothing committed to lose) **[V]** |
| S2 | No parallelism, though the seeding design already makes it safe |
| S2 | `PLAN.md`'s compute budget is stale by 2× on cell count |
| S2 | Provenance records only a repo SHA — no R version, packages, BLAS, date, wall clock |

### CI, build, reproducibility

| Sev | Finding |
|---|---|
| S1 | The weekly link check has been red since 2026-08-24; 5 of 6 errors are true positives **[V]** |
| S2 | GitHub Pages never enabled — the advertised URL 404s after 18 successful deploys (downgraded from S1) **[V]** |
| S2 | LaTeX toolchain is 62% of the build, uncached, and its largest step masks four permanent errors |
| S2 | `output_format = "all"` still knits every chapter three times |
| S2 | No `concurrency` group on the deploying workflow; overlapping deploys have already happened |
| S2 | Nothing pins the R version or the repository snapshot |
| S2 | `lint-chapters.R` check 2 never runs on the appendices although the script says it does |
| S2 | `check-vgwort-eligibility.R` is in no workflow |
| S2 | No dependabot; every action on a mutable tag |

### Content gap

| Sev | Finding |
|---|---|
| S1 | Chapter 1's four specified anchors are rejected by the contract lint **[V]** |
| S1 | Nine of twelve stubs carry pre-E1/E2 outline text; three bullets state refuted claims **[V, downgraded to S2]** |
| S1 | Chapter 11's core figure has no producer — `non_planarity()` lives only in `scripts/` |
| S1 | `packages.bib` cannot resolve the package citations Part II is specified to make |
| S1 | `_common.R` sets `eval = FALSE` globally with no lint check, for 143 unwritten chunks |
| S2 | `read_run()` does not exist |
| S2 | S1-3 closed at 26 bibliography entries against its own ~40 criterion |
| S3 | `13-conclusion.Rmd` exists nowhere in the build |

### Publishing and reader experience

| Sev | Finding |
|---|---|
| S1 | `CITATION.cff:3` sets top-level `type: book`, invalid under CFF 1.2.0 — the citation dialog renders empty **[V]** |
| S1 | Dark mode half-applied: search dropdown at 1.40:1, syntax highlighting below 2:1 **[V]** |
| S1 | The EPUB has an invalid `dc:language`, a random per-build identifier, and no licence |
| S1 | Chapter 1's figure loses its caption, number and anchor in HTML only |
| S2 | No release, tag or DOI; four files assert a version git has never recorded |
| S2 | The dual-licence boundary leaves committed data artefacts uncovered |
| S2 | No errata mechanism, no issue templates |
| S2 | The interactive figure never receives the book's theme and is a fixed 940 px |
| S3 | Every page makes a 403-ing Font Awesome CDN request and loads Google Fonts twice |
| S3 | No canonical URL, sitemap, robots.txt or structured data |

---

## 11. Open questions this audit could not settle

1. **The correct M/V criterion.** Two independent measurements produced different
   agreement rates (0/N and 25%) using different ridge/trough tests. Neither is
   authoritative. Item 0.2 must establish an orientation-consistent criterion
   first, then measure against it.
2. **`PLAN.md` item-by-item reconciliation.** The dedicated auditor failed;
   coverage came indirectly from seven other dimensions. Item 0.3.
3. **Whether Claim A exists at all.** Only the Phase 1 pilot can answer this, and
   it is the largest single risk to the book's thesis.
4. **The real per-thousand-word drafting cost.** Unknown until Chapter 2 is
   drafted to completion. Every schedule estimate here is therefore provisional.
