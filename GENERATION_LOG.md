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

## Phase 14 — the library, and E2 decided

`R/` is complete apart from `methods.R` and `constructions.R`: patterns,
folding, sampling, metrics, baselines, constants and plotting, with 993
assertions passing and no skips.

**The kinematics agent died and the failure is worth recording**, because the
same mistake is easy to repeat. It was asked to derive two closed-form rigid
foldings, implement them, verify four properties across a fine sweep, and write
the test file — all in one task. After four long reasoning turns it hit
*"Claude's response exceeded the 64000 output token maximum"* and returned
nothing. The work was re-scoped and done in three passes instead.

**Both foldings are derived rather than fitted.** Write down the folded vertex
positions with unknown metric constants, impose edge-length and facet-angle
preservation, and solve. For the Miura that is three equations in four
unknowns — a one-parameter family, which is the rigid folding. The construction
buys something stronger than a numerical result: `fold()` places *vertices* on a
lattice and every facet reads its corners from that one shared set, so facets
cannot disagree about a shared crease, and shared vertices plus per-facet
congruence is exactly what a rigid folding is. Worst facet isometry error over
the whole sweep is 7.8e-16 (Miura) and 5.6e-16 (Yoshimura), against a contract
of 1e-10.

**θ is rescaled to [0, 1]**, the fraction of the way to flat-folded. The
inherited [0, 1.4] was not a dihedral range — the glossary already said that —
but it was not a legal parameter range either: a Miura with α = π/3 is fully
collapsed at 1.047. Normalising also makes families comparable at equal fold
fraction, which is what E1 needs.

**Two measurement defects were found by testing rather than by reading.** The
Swiss roll's `turns` was adding revolutions at constant sheet spacing, so the
short-circuit index sat at 0.999 however tightly the roll was wound. And
`branch_gap()` took its length scale from the sampling density and returned
g/s = 2.00 for every pattern at every θ — the nearest pair separated by more
than L sits at about L, so the statistic was measuring its own definition. Both
fixed; the axis now runs 17.5 → 4.9 (Miura), 18.3 → 3.2 (Yoshimura) and
21.4 → 1.7 (Swiss roll), which overlap.

Pinning that down produced a constraint the chapters must carry: g is a property
of the surface and is constant in n, while s falls as n^(-1/2), so g/s grows as
sqrt(n) — measured 2.832 against sqrt(8) = 2.828. **Comparing g/s across
families is only meaningful at fixed n.**

**A(k) is verified by two independent routes** and the planned third turned out
not to exist. The primary gives 2/(Nk(2N−3k−1)); first principles give the same
number as the reciprocal of the largest attainable penalty sum, brute-forced
against the closed form. `coRanking`, which S1-4 named as the gate, exports no
trustworthiness or continuity at all — so that comparison could never have been
made as written. It still earns its place in the lockfile: `qnx()` agrees with
`coRanking::Q_NX` to 1e-10 across four values of K.

### E2 — claim-set decision

**Verdict: the waterbomb tessellation folds, but only under an imposed symmetry,
and it is not usable as a benchmark row.** Evidence and numbers in
`experiments/e2-waterbomb/README.md`.

Cell-translation uniformity alone leaves a 2-dimensional variety. Adding the
pattern's vertical mirror leaves exactly one degree of freedom, with the closed
form `tan(rho_h/2) = -tan(rho_d/2)/sqrt(2)` — found numerically, holding to
1.7e-15 over 155 points, and cross-checked by an independent developing-map
reconstruction to 4.2e-15.

The trap `PLAN.md` warned about is real and had to be routed around: at the flat
state every *z* column of the Jacobian is identically zero, so the non-trivial
flex count is V − 3 for *any* planar pattern and proves nothing. Second order
and a finite continuation are what decide.

Three things nonetheless disqualify it as a grid row, and none of the three
outcomes E2 pre-drafted anticipated them: the embedding is not proved (facet
clearance falls to 0.026 at θ = 0.9), fold amplitude is *not monotone* in θ (it
peaks at θ = 0.4 and then falls, so the pattern cannot share the difficulty axis
the other families use), and θ does not determine the configuration — 27 degrees
of freedom remain on the free boundary.

So the book ships **two pattern families plus a documented result**, which §8.3
was already framed to absorb. `waterbomb()` stops with an error and
`run-benchmark-grid.R` has no waterbomb row, per E2's hard rule.

## Phase 15 — E1, and the claim the book has to give up

### E1 — claim-set decision

**Claim C — "crease patterns are a better benchmark" — is not supported, and the
evidence points the other way.** Artefacts: `data/processed/e1-difficulty.rds`
(arm A), `e1-controlled.rds` (arm A2/A3), `e1-armB.rds`. Script:
`scripts/experiment-e1.R`.

**Arm A, as the plan specified it, could not have answered the question.** It
sweeps θ and nothing else, and folding a crease pattern raises branch separation
*and* lifts the sheet out of the plane at the same time. At g/s ≈ 21 a Miura is a
flat plane and PCA recovers it with error 0.000; a Swiss roll at the same
separation is still curved and PCA scores 0.403. The families' ranges of ambient
non-planarity are **disjoint** — crease 0.000–0.056, Swiss roll 0.101–0.126 — so
over arm A's whole design there is no setting at which they are comparable. It
reported a family term at F = 1203, p < 2e-16, and that number is a statement
about the confound, not about creases.

**Arm A2 fixed the design.** θ is not the only knob and it is not the important
one: *cell count* dominates non-planarity. A 2×2 Miura at α = 1.05, θ = 0.9
reaches 0.157, above anything the Swiss roll produces, where a 6×6 at the same
angles reaches 0.027. Sweeping (nx, α, θ) creates the joint overlap arm A lacked
— 9 crease settings against 5 Swiss rolls, g/s ∈ [3.3, 15.6], non-planarity ∈
[0.085, 0.129].

The family effect survives controlling for both axes, and its **sign is the
problem**: crease patterns are *easier*, for every method and both metrics
(PCA/cMDS RMSE effect −0.674, F = 2211; Isomap RMSE −0.283, F = 22.7; Q_NX +0.148
and +0.041).

**Arm A3 asks the question that actually matters.** A benchmark earns its keep by
telling methods apart, so the statistic is the spread across methods within a
cell at matched difficulty:

| family | mean PCA−Isomap spread | sd | n |
|:--|--:|--:|--:|
| Swiss roll | **0.574** | 0.393 | 21 |
| crease patterns | **0.113** | 0.070 | 35 |

The Swiss roll separates the methods **five times better**. At matched
difficulty PCA scores 0.922 on a Swiss roll against Isomap's 0.348 — the
textbook result, and the right one, since Isomap consumes geodesics and PCA does
not. On crease patterns the same pair is 0.286 against 0.183: PCA does nearly as
well as Isomap, because a folded Miura is still close to planar in the ambient
sense.

So crease patterns are not a harder benchmark. They are an easier one that
discriminates less.

**What replaces it** is what `PLAN.md` D1 pre-drafted for the "families collapse"
branch, and this result argues for it a fortiori. The crease pattern's
contribution is not that it is difficult — it is that it comes with an **exact**
answer key, which permits two things no other benchmark permits: auditing the
evaluators themselves (Claim A), and computing the smallest error any 2-D
embedding of a dataset could achieve (Claim B). The Swiss roll can do neither,
because its truth is a convention — and, as Chapter 11 now measures, usually the
wrong one: the customary angle chart is off by
about 1070% in worst local distortion against roughly 2% under arc length,
measured at the 2% neighbourhood quantile on a two-turn roll
(`tests/testthat/test-contraction.R`).

**Correction, 2026-08-26.** This entry originally read 637%, and nothing in the
repository produced that number — it was quoted rather than computed, which is
the practice this book forbids. The measured value is about 1070% and is stable
across neighbourhood quantiles; the ratio between the two charts is what should
be reported, since the absolute figure depends on the quantile chosen. There is
now a test that computes it.

The honest positioning is **complementary, not competing**. The Swiss roll is the
better discriminator of methods; the crease pattern is the only one of the two
with truth. Claim B becomes the spine, as the plan already said it should.

**Caveats that travel with this.** The overlap is a specific corner — 2×2 to 4×4
Miura at large α and θ ∈ [0.70, 0.95], nine settings. The finding covers three
methods and two metrics. And under Q_NX, Isomap scores 0.773 on creases against
0.778 on Swiss rolls: for the neighbourhood metric the families very nearly *do*
collapse, and the whole difference is concentrated in how badly the linear
methods fail, which is a fact about ambient non-planarity rather than about
creases.

### Arm B — crease count

At matched g/s, error is flat in crease count: 9 / 36 / 144 creases give Isomap
0.0299 / 0.0279 / 0.0381 and PCA 0.0705 / 0.0387 / 0.0513. Not monotone, and the
differences sit near the seed noise. Crease count does nothing, which is the
third outcome `PLAN.md` E1 pre-drafted, and Chapter 11 should say so in the
book's own voice.

### Also settled here

PCA and classical MDS agree to 5.8e-15 across the whole grid, which is correct
rather than a bug — `cmdscale` on a Euclidean distance matrix *is* PCA. The grid
carries two distinct linear methods, not three, and `run-benchmark-grid.R`
should not pretend otherwise.

## Phase 16 — audit, and the remediation it started

Six independent read-only sweeps against what E1 and E2 actually decided. 108
findings; 30 put through adversarial verification, which confirmed 17,
downgraded 11 as overstated and refuted 2. Only what survived is acted on. The
roadmap is `PLAN.md` § "R — remediation".

The uncomfortable pattern: **three of the four confirmed blockers were
regressions introduced in the previous three days**, and all three are the same
shape — a guard written against a condition that had already been shown to be
false.

- `verify-citations.R` had exited 1 since 22 August. The bidirectional key check
  scans `R/*.R`; roxygen tags begin with `@`, so it read `@return` as a citation
  key. The gate that stops a fabricated reference reaching the book was red for
  four days and nothing noticed — precisely the failure it exists to prevent.
- Helper tests failed in CI because `torch` **is** installed there. This
  repository discovered that `setup-renv` restores the whole lockfile, wrote it
  into its own README, and then shipped a torch-conditional `stop()` anyway.
- Chapter 1's figure rendered nothing: it inherited `eval = FALSE`.
- EPUB took the iframe branch, because `is_html_output()` is TRUE for EPUB.

### The Yoshimura is withdrawn

The shipped folding was **an accordion pleat**: twelve horizontal creases folded
and all twenty-eight diagonals sat at ρ = π. It passed the facet-isometry test
perfectly, because a pleat *is* a rigid folding, and it passed Kawasaki, because
the flat pattern was never the problem.

Two corrected foldings were derived, one with the corrugation along the rows and
one with a checkerboard height. **Each leaves one of the three crease families
flat.** Both are exact — isometry 7.8e-16, flat at θ = 0 — which is what makes
the result worth recording rather than patching around. A folding that leaves a
family flat is a folding of a coarser pattern: fuse the facets across the
unfolded creases and what remains is a parallelogram tessellation. It is a Miura
wearing the Yoshimura's crease pattern, and shipping it as a second independent
family would have been a claim about pattern variety the geometry does not
support.

So the book ships **one verified family and two documented kinematics results**.
E1's decisive arms swept `miura_ori` only, so nothing downstream depends on it.

**What caught it is the transferable part.** An isometry test cannot tell a fold
from a pleat. Deriving the mountain/valley assignment from the folded dihedral
and testing Maekawa on the result can: 12 of 16 interior vertices failed. That
diagnostic also found the Miura's labels had been assigned by a parity rule
chosen to satisfy Maekawa and matched the actual folding on 36 of 60 creases;
derived from the geometry they now satisfy Maekawa at 16 of 16.

> **Corrected in Phase 18 — this closure was wrong, and wrongly evidenced.**
> "They now satisfy Maekawa at 16 of 16" was true and proved nothing. So did the
> parity labels it replaced, and so does the global inverse of either, because
> |M - V| = 2 is invariant under swapping M with V. The derivation shipped here
> ordered the two facets sharing a crease by facet index and the axis by the
> crease's stored (i, j); both are arbitrary and each negates the sign, so the
> new labels agreed with the geometry on exactly half the interior creases --
> the same half-right as the rule they replaced, differently arranged. See
> ROADMAP.md section 5 and the Phase 18 entry below.

### Other remediation in this phase

- `irreducible_loss()` and `metric_floor()` were separate implementations of the
  same bound, each documented as the complement of the other. They agree to
  1.1e-16 — classical-MDS eigenvalues of a centred chart are the squared
  singular values. One is now an alias.
- `embed_laplacian()` could return an arbitrary vector out of a degenerate null
  space when the heat kernel underflowed, recording nothing. It now detects the
  disconnection and returns NULL.
- The E1 artefacts carry provenance, and `--quick` writes its own files rather
  than overwriting the evidence for the decision that changed the book's spine.

  > **Half of this was false when written, and stayed false for four days.**
  > `.e1_save()` landed here at `8640a2d`; the three artefacts on disk dated from
  > `94833e7`, four days earlier, and nothing regenerated them. All three carried
  > `attr(x, "provenance") == NULL` while this line and `CHAPTERS.md` both
  > asserted otherwise. The `--quick` half was true. Regenerated in Phase 18,
  > and `scripts/check-artefact-producers.R` now fails on any committed artefact
  > without a provenance block carrying an `r_sha`.
- `experiments/e2-waterbomb/*.R` could not run: every `source()` pointed at the
  pre-move directory.
- The ambient contraction and the Swiss-roll chart defect now have producers in
  `tests/testthat/test-contraction.R`, rather than being quoted.

## Phase 17 — the spine gets an artefact, and E1 survives its worst objection

### The boundary convention, checked rather than defended

The audit raised the one thing that could still have overturned E1. Its decisive
arm sampled with `boundary = TRUE`, and `R/metrics.R` documents that under that
setting the sampler can draw into the zigzag teeth of the unfolded outline,
where the chart distance becomes a *lower bound* on the geodesic rather than
equal to it. That is a corrupted answer key — and one that would penalise the
geodesic method specifically, which is exactly the comparison arm A3 turns on.

It could not simply be re-run: the small patterns E1 needed in order to reach the
Swiss roll's ambient non-planarity leave no room for the `boundary = FALSE`
margin. So it was measured instead. `chart_exit_fraction()` reports the share of
sampled pairs whose straight chart segment leaves the sheet; across the settings
that actually entered the overlap it runs from 0.00% to 4.31%.

And the finding **strengthens** as the affected settings are dropped: the
method-separation ratio goes 5.1× (all settings) → 5.4× (excluding those above
0.5%) → 5.5× (excluding every setting with any exiting pair). The approximation
biased against the conclusion, not for it. E1 stands.

### Claim B has an artefact

`scripts/run-product-grid.R`. The spine's operative instruction — report every
result against the floor — did nothing on the main grid, where a 2-D chart in a
2-D target makes the floor identically zero. The product construction gives
intrinsic dimension 4 with the chart still exact and closed-form, so the floor
is strictly positive, computable, and attained.

The first run, on 64 fits: **no method beat the floor**, and the mean excess
above it at d = 2 separates the methods cleanly by what they consume —

| method | consumes | excess |
|:--|:--|--:|
| PCA, classical MDS | ambient | 0.0060 |
| Isomap | geodesic | 0.0351 |
| LLE | neighbourhood | 0.0633 |
| Laplacian eigenmaps | neighbourhood | 0.1034 |
| UMAP | neighbourhood | 0.1492 |
| t-SNE | neighbourhood | 0.1651 |
| diffusion map | ambient | 0.1682 |

PCA sits six thousandths above the best any 2-D embedding of this data could
achieve. Reported against zero its raw error reads as failure; reported against
the floor it says the loss belongs to the data. That contrast is the whole of
Claim B, and it now has numbers.

### R5 decisions

The autoencoder is out of the main grid — it occupied a ninth of every cell with
no implementation, and `CHAPTERS.md` already gives Chapter 7 its own three
artefacts. `torch` stays in the lockfile. The registry declares the method
unavailable, `embed()` returns NULL before attempting anything, and the grid
records the declared reason rather than dropping the row.

## Phase 18 — trust repair

`ROADMAP.md` is the status audit this phase works from: eight read-only audits at
commit `85fe50a`, then adversarial verification of every S0/S1 finding, then
synthesis. **19 findings went to verification; 2 were confirmed as stated and 17
were downgraded or refuted** — several of the proposed fixes would have made
things worse, and section 9 records them as things not to do. The phase order
follows section 7.

### The crease labels, and what "closed" has to mean

The finding that reorders the plan. Phase 16 recorded the Miura's
mountain/valley labels as fixed, on the evidence that the new derivation
satisfies Maekawa at 16 of 16 interior vertices. It does. So does the parity rule
it replaced, and so does the global inverse of either: **|M − V| = 2 is invariant
under swapping M with V**, so it cannot discriminate between a labelling and its
opposite, let alone between two that differ on half the creases. The acceptance
property was exactly symmetric to the class of error present.

`crease_assignment()` took the two facets sharing a crease in **facet-index**
order and the axis in the crease's **stored (i, j)** order, then read the sign of
a triple product. Both orderings are arbitrary and each negates that sign. On
`miura_ori(5, 5)` the derived labels agreed with the stored ones on 16 of 40
interior creases, and — measured against a criterion that shares no code with
either — both were right on exactly 50%.

The fix makes the ordering canonical rather than incidental. In a consistently
wound mesh every interior edge is walked once in each direction, so "the facet
that walks i → j" names one facet without reference to how the facets happen to
be numbered. With `nP` its winding normal, `nM` the other's and `u` the crease
direction, `(nP × nM) · u > 0` is mountain — and reversing the stored crease
direction swaps `nP` with `nM` *and* negates `u`, leaving the product alone.
`.check_winding()` refuses the whole computation on a mesh that is not oriented,
rather than returning labels that are a coin flip.

`miura_ori()`'s stored labels are now the geometry's, in closed form: the zigzag
creases are constant in `i` (each is a ridge or a trough of the corrugation along
its entire length) and the horizontal creases alternate, mountain when `i + j` is
even. That is 3M/1V at every interior vertex, so Maekawa still holds — it was
never the constraint that fixed the labels. The comment in `patterns.R` that
derived the old rule *from* Maekawa is replaced; the reasoning was valid and the
conclusion was one of two labellings the argument could not separate.

**What settles ROADMAP.md's open question 1.** The audit's two ridge-versus-trough
measurements disagreed (0/N against 25%) and neither was authoritative. Both
compared heights: crease-midpoint z against the mean z of the opposite facet
points. On the Miura's horizontal creases both adjacent facets span the same two
heights, so that difference is identically zero and the test was reading
floating-point noise. Projecting onto the facet normals instead keeps the
horizontal component of the fold, which is where those creases carry their whole
signal. The criterion is well posed at every size, α and θ swept, and it agrees
with the corrected derivation everywhere.

### The closure rule this phase adopts

*An item closes when there is a named executable assertion that fails on the
pre-fix tree and passes after, and the commit message says which.*

For this one that is `tests/testthat/test-crease-assignment.R`, which recomputes
the labels by an independent route — normals flipped to +z and the side of the
sheet the surrounding material sits on, rather than the winding — and compares.
On the pre-fix tree, six of its seven tests fail, 167 assertions in all:

| test | pre-fix |
|---|---|
| the independent criterion is well posed | 160 pass (it is the reference) |
| `crease_assignment()` agrees with it | **80 fail** |
| the stored labels agree with it | **84 fail** |
| assignment is invariant to crease direction | **fails** |
| assignment is invariant to facet order | **fails** |
| Maekawa holds, and is too weak to catch this | **fails** |
| an unwound mesh is refused | **errors** (no such guard) |

The last of those tests asserts the weakness directly: the correct labelling, its
global inverse and the retired parity rule all satisfy Maekawa, and the parity
rule agrees with the correct labelling on exactly half the creases.

### `js/fold-figure.html` gets a producer

The figure had been drawing the retired labels — solid for mountain, dashed for
valley — and nothing in the repository could regenerate it. An artefact with no
producer cannot be corrected, only replaced by hand, which is how it came to
disagree with the code in the first place.

`scripts/build-fold-figure.R` rebuilds the `window.__FOLD_GEOM__` block from
`miura_ori()` and `fold()`, asserts isometry over all twenty frames, refuses to
write if the stored labels disagree with `crease_assignment()`, and takes
`--check` for CI. It reproduces the shipped block **byte for byte** apart from
the twelve corrected labels — same 16 facets, same 20 frames, same 3,840
coordinates, same isometry error — which is the evidence that nothing about the
figure moved except what was wrong with it.

### Re-verifying the closures, by measurement

Six items the remediation ledger recorded as closed were still open. Each is now
closed against an assertion that fails on the tree as it stood.

**`EMBED_DIM_DEFAULT` still shadowed `EMBED_DIM`** after R1-4 recorded the
duplicate removed. Two names, one quantity, both spelled `2L`, and six functions
defaulting to the second. Collapsed onto `EMBED_DIM`; `test-methods.R` now greps
`R/` for `EMBED_DIM[A-Za-z0-9_]*` and asserts there is exactly one such name, so
the next duplicate cannot arrive quietly either.

**`PATTERN_GRID` still carried sizes for the yoshimura and the waterbomb.** The
defence was that a size is not a promise the pattern folds, and that the hard
rule lived on `run-benchmark-grid.R`'s `PATTERNS` list. That distinction did not
survive contact: E1's `FAMILIES` named the withdrawn yoshimura for four days and
halted on its first cell every time, because the rule was stated about one list
and this one looked exempt. A registry keyed by family name *is* a declaration.
`PATTERN_GRID` now names one family, and the check below enforces it on every
registry it can find.

**`rank_metrics()` had zero callers** and a comment written in the present tense
about compute that has never been spent. The measurement in it is real -- 5.85 s
of separate calls against 0.44 s -- and the function is tested; what was wrong
was describing a prepared optimisation as a live one. Corrected in place; items
1.5 and 3.2 are where it gets its two consumers.

**`R/README.md` still listed three pattern families and nine methods.** One
family folds and the autoencoder is declared unavailable.

**The E1 provenance claim** was false in both documents that made it -- see the
Phase 16 entry above.

### Tests that could not fail

`scripts/check-artefact-producers.R` is the check the chain never had. It runs on
base R and `readRDS` alone, deliberately: the check that the evidence layer is
intact must not be gated on a library restore. It asserts that every artefact the
governing documents name has exactly one declaring producer (producers now carry
`# @artefact` lines), that every committed artefact carries a provenance block
with an `r_sha` and was not written by `--quick`, and that every family named in
a registry can be built *and folded*. Genuinely open artefacts are listed with
the roadmap item that closes them, and the check fails if one of those entries
stops being true in either direction.

**`test-figure-export.R`'s refusal test never called the guard it claimed to
test.** It re-implemented the isometry check inline and asserted that its own
`stop()` fired; deleting the production guard left the file at 27 of 27 passing.
Confirmed by deleting it. It now reaches the guard the only way that works --
`.fold_miura()` derives the placement from `pattern$params` and never reads
`pattern$vertices`, so moving one flat vertex leaves `fold()` working and makes
the flat panel stop being the unfolding of the folded one. With the guard
deleted the test now fails.

**`fold_figure_static()` drew a different view from the one it measured.**
Confirmed: `visible_facets()` takes `(sx, sy)` as the picture plane and `depth`
toward the camera; the static figure re-derived all three from the same four trig
calls with the last two exchanged. Panel A therefore greyed the facets hidden in
a view panel B never showed, and its subtitle counted them. There is now one
`.view_project()`, and `fold_figure_data()` separates the geometry from the
drawing so it can be asserted against. The test is a property of the drawn panel
rather than a second copy of the projection: every facet panel A greys must, in
the coordinates panel B is drawn in, sit under a facet drawn in front of it.
Restoring the swap turns it red.

**`embed_lle()` and `embed_laplacian()` could return `NULL` for every input** with
the suite green, and so could return the wrong eigenvectors. Measured on
`miura_ori(6, 6)` at theta = 0.5, n = 400, over three seeds:

| | correct | with the trivial eigenvector kept |
|---|---|---|
| `embed_lle` | qnx@10 0.871-0.921 | 0.190-0.198 |
| `embed_laplacian` | 0.757-0.784 | 0.342-0.395 |

The floors sit in the gap. Both mutations are now caught -- `return(NULL)` in
both bodies gives 2 failures and 2 errors, `[1:d]` for `[2:(d + 1L)]` gives 8.

**`non_planarity()` lived only in `scripts/experiment-e1.R`.** It is the x-axis
of Chapter 11's core figure, and a quantity defined inside a script has no
producer a chapter can call. Moved to `R/baselines.R`, beside
`short_circuit_index()`, and arm A now records it per cell rather than only the
redesign that had to add it.

**Renamed rather than made true:** `"the R and browser visibility computations
agree"` executes no JavaScript and never did. It is now called what it is, a pin
on `visible_facets()` at three views. A real parity check needs the shipped
script run under Node with a canvas; ROADMAP.md carries it as open.

### Phase 2 — the gates that fire on the first line of prose

Done ahead of Phase 1's compute rather than after it: every one of these is a
check that would have fired on the first real chapter, and finding that out
during drafting is the expensive way.

**The contract lint was checking twelve exempt stubs and nothing else.** Line 275
looped `check_contract` over `body_rmd` although line 30 had built `prose_rmd`
for it, so the appendices -- the only written prose in the tree -- were never
checked, while every file it did check was an exempt stub. A check whose entire
input is exempt reports clean forever. It is split now: `check_anchors` over
`prose_rmd`, `check_contract` over the chapters.

The mnemonic no longer comes from stripping a trailing word off the first
section anchor. That cannot tell `intro-answer-key` (mnemonic `intro`) from
`folding-geometry-question` (mnemonic `folding-geometry`) -- one regex strips too
little and the other too much, and there is no regex that gets both. It comes
from the chapter's H1 anchor, which says which it is.

**The nine-slot contract gets a narrative subset.** Chapters 1 and 13 present no
method and measure nothing; `-setup`, `-results`, `-diagnostics` and `-reproduce`
buy a reader nothing there, and an introduction's "Results" section is a forward
reference to an artefact that does not exist yet -- which `CHAPTERS.md` already
warns about two paragraphs into Chapter 1's own entry. They carry five slots in
the same order and may carry more.

That is also what `Chapter 1's four anchors conflict with the lint` really
needed. Renaming all four would still have left `results`, `diagnostics` and
`reproduce` missing and the chapter still failing; the roadmap's fix was
incomplete. Three anchors renamed onto contract slots, `intro-roadmap` kept as a
non-contract extra, and the two middle rows swapped because `background` precedes
`core` in the contract's order -- recorded as the editorial change it is.

**`eval = FALSE` was the global default,** with 145 chunks specified against it
and no check. A figure chunk that does not evaluate produces no figure, and knitr
drops its caption, its `fig.alt` and its `fig:` anchor with it: the figure leaves
the book's numbering, every `\@ref()` to it resolves to nothing, and the build is
green. `_common.R` sets `eval = TRUE`; a chunk shown without being run says so per
chunk, with a label beginning `norun-`, and the lint rejects any other
`eval = FALSE` and rejects it outright on a figure chunk.

**Chapter 1's HTML branch dropped the figure out of HTML's numbering.**
`asis_output()` emits raw HTML and knitr applies `fig.cap` and `fig.alt` to plot
output only, so the iframe branch carried none of them: the figure was numbered in
PDF and EPUB and not in HTML, which shifts every later figure number in the book
between formats. The branch writes the `figure` div, the `(\#fig:)` marker
bookdown numbers from, and the iframe title itself -- all three read from the
chunk's own options, so the two branches cannot describe the figure differently.
The fixed 940 px height becomes `clamp(520px, 78vh, 940px)` while it is open.

**`read_run()` did not exist.** `PLAN.md` and `CHAPTERS.md` both say every chapter
from 4 onward opens with one, plus a digest check. What a chapter would have used
instead is `readRDS()`, which accepts a `--quick` smoke test, an artefact with no
provenance, and a regenerated run whose numbers no longer match the sentence
beside them -- all three silently. `R/artefacts.R` holds `read_run()`,
`write_run()`, `provenance()` and `run_digest()`, with the provenance block
`PLAN.md` asks for: repo SHA, `R/` SHA, dirty-tree state, R version, platform,
BLAS, package versions, date, elapsed, cores.

The digest strips provenance before hashing. That is the design, not an
oversight: provenance carries a SHA, a timestamp and an elapsed time, so hashing
it would fire the check on every regeneration even when the numbers did not, and
a check that always fires is one that gets deleted.

**The bibliography could not cite the methods the book is about.** Part II names
a method per chapter; `book.bib` carried Isomap, LLE, t-SNE and UMAP and stopped.
Thirteen entries added -- the method primaries (Pearson, Hotelling, Torgerson,
Sammon, Schölkopf, Belkin & Niyogi, Coifman & Lafon, Hinton & Salakhutdinov) and
the apparatus the book's own derivations rest on and were using uncited
(Eckart-Young for the irreducible-loss bound, Schönemann and Gower for the
Procrustes fit, Federer for the reach, Niyogi-Smale-Weinberger for what a zero
reach costs a sampler). 26 entries to 39, against S1-3's own ~40 criterion, and
`verify-citations.R` resolves all 39 against the Handle System.

`write-package-bib.R` gains `uwot`, `diffusionMap`, `FNN`, `kernlab` and
`coRanking`: `verify-citations.R` builds its known set from the committed
`packages.bib`, so a chapter citing `@R-uwot` failed the citation check with the
package sitting in `renv.lock` all along. 26 to 31 package entries.

**The re-budget's total was the sum of nothing.** `CHAPTERS.md`'s table states
~36,700 words; its rows sum to **41,670**, against **41,720** before. The
2026-08-26 re-budget redistributed 50 words net -- two chapters grew by 1,550 and
three shrank by 2,000 -- and did not reduce the book by 5,000. Both totals are
now computed from the table, seven stale chapter headings match their rows, and
Chapter 1's section rows sum to its budget for the first time (`intro-limits`
takes the 200 words the re-budget gave the chapter, which is where the concession
that the Swiss roll discriminates better belongs).

The correction is a finding rather than a tidy-up: **the reduction the re-budget
describes has not been made.** Whether one verified family can carry 41,670 words
is ROADMAP.md R4, and it is open.

**Three refuted stub bullets deleted**, and replaced rather than removed --
Chapter 8 gains "why there is one family and not three", Chapter 10 loses the
pattern axis it cannot have (a factor with one level is not a factor) and gains
crease count, and Chapter 11 states the spread at matched difficulty instead of a
ranking flip that E1 looked for and did not find. The first draft of Chapter 11's
replacement quoted E1's numbers and the anti-fabrication gate rejected it, which
is the gate working exactly as designed on the first prose written since it was
sharpened.

**`renv.lock` was missing four of torch's dependencies** -- `bit`, `bit64`,
`coro`, `safetensors`. A clean `renv::restore()` installs torch and not what it
needs, so it would fail to load; CI never noticed because nothing loads it.
Snapshotted, 110 records to 114, no version changes.

With the pinned library restored locally the suite runs with **nothing skipped**
for the first time: 1,771 assertions, 0 failures, 0 skips.

### Every figure in the book gets a test

`R/plotting.R` -- 23 KB, fifteen functions, every figure a reader will see -- had
no test file at all. What is tested is not that the plots render: ggplot builds
almost anything, and a figure that is wrong is a figure that renders. It is the
four quantities that decide whether a figure says something true.

- **The camera is a rotation.** `.project()`'s own comment promises "a projection
  rather than a perspective, because the book measures distances in these figures
  by eye", and that promise is exactly the statement that the map to
  `(px, py, near)` is orthonormal. Asserted over five azimuths and four
  elevations. Turning one `cos` into a `sin` in the elevation term fails it 40
  times and changes nothing else visible.
- **The painter's order is the hidden-line removal.** Group 1 must be the
  farthest facet, and each group's polygon must be the facet whose depth it
  claims -- a sort that reordered rows without reordering vertex indices would
  still be sorted. `order(-d)` for `order(d)` fails it 17 times and renders
  perfectly happily, as a wireframe in which the far half of a folded sheet reads
  as the near half.
- **Both crease endpoints, separately.** Swapping i and j draws the same picture,
  so a test on the set of drawn segments would pass on a transposed table. This
  is the mountain/valley failure mode in a different place.
- **Colour and linetype both carry mountain against valley**, which is standing
  rule 3 turned into an assertion: a palette edit making two linetypes equal
  leaves a figure correct in colour and unreadable in greyscale, and nothing else
  would notice.

Plus the guards that exist because the wrong figure is still a plausible figure:
`plot_folded()` refuses a `vertices3` that is not row-aligned with the pattern,
and the empty-pattern branches return an annotated blank rather than an empty
axis.

### Chapter 8 §5, restated

Three corrections, all of them to text that would have been drafted as it stood.

**"Tested against all nine methods" is eight.** The registry holds nine entries
and the autoencoder declares itself unavailable.

**"Unbeaten" is a regression check, not evidence.** The bound is *proved* -- it is
the tail of the chart's spectrum, and the optimal rank-d projection attains it --
so a method beating it means the implementation is wrong, not that the claim is
corroborated. Reporting eight methods failing to beat a theorem as though they
had independently confirmed a conjecture is the kind of sentence that survives
because nobody re-reads it.

**The headline numbers were `--quick` output.** Excess sorting by what each method
consumes -- ambient 0.0060, geodesic 0.0351, neighbourhood 0.063-0.165 -- came
from a run that was never saved, at two values of theta, and was described in
this file as "the book's thesis in one table". Standing rule 2 says every
theta-dependent result is a curve; one number quoted from two theta values is
exactly the cherry-picking that rule exists to prevent. The section now reads
every number from `product-grid.rds` through an inline `r` expression.

`PLAN.md`'s compute budget was one pattern behind the tree. It said two patterns
rather than three, on E2's withdrawal of the waterbomb; the Yoshimura was
withdrawn six days later and the cell count was never revised. The grid is
1 x 20 x 3 x 20 = **1,200 cells**, not 2,400 -- a factor of two on the only
quantity the budget multiplies. Wall clock is left as a range, because the two
available estimates disagree by a factor of two and neither has been run to
completion; `write_run()` records `elapsed`, so the first full generation settles
it with a measurement instead of an argument.

### The selection rule, registered before the grid it reads

S1-11, and its own commit, because the only thing that can establish that a rule
preceded a result is a git timestamp. `benchmark-grid.rds` has never been
generated and `prepare-single-cell.R`'s deliberate `stop()` is still in place.

Written as code. `R/selection.R`'s `select_method()` is a total function of the
grid's columns: given a grid and a regime it returns a decision every time, with
no argument left to be chosen once the numbers are in. Prose can be read
generously afterwards; a function cannot.

The decline branch is the point of it. `R` is the spread across methods over the
spread across seeds within a method -- above 1 a ranking means something, at or
below it the ranking is noise with an ordering imposed on it, and the rule
returns no winner. `CHAPTERS.md` already warned that "the temptation on
discovering R < 1 will be to raise the seed count until something separates".
That is closed rather than warned about, and the test shows why it could never
have worked: R is a ratio of two spreads, neither a standard error, so 20, 100
and 400 seeds leave it where it was.

Two methods with nothing between them come out as a decline rather than a coin
flip, and for the right reason -- no spread across methods is no resolving power.

Chapter 10 gains the section table it never had, which is why three places in
this repository gave the rule three different section numbers. It is referred to
by its anchor, `results-rule`.

### Standing rule 1, made true

"Every stochastic result is reported across at least 20 seeds", stated
unconditionally to the reader, and **every experiment that has run broke it**:
E1's arm A used 10 and the arm behind its headline used 5; the product grid used
10; only the ungenerated main grid used 20.

Twenty was never a design either -- it is a convention inherited from the sibling
volumes. `PROJECT_CONCEPT.md` already says what the design should be, "the plan
spends more where the pre-registered 0.02 reportability threshold requires it",
and `PLAN.md` S2-3 says to invert that threshold for the count. Nobody had
measured the spread it has to be inverted against.

`scripts/measure-seed-budget.R` measures it: the within-cell standard deviation
of excess over the floor, for every method, over cells spanning the grid's theta
and noise, then inverted through the standard two-sample expression at 80% power.
Every method, not only the stochastic ones -- a deterministic method's spread
across seeds is the sampling variation alone, and that is the baseline the
stochastic ones have to be read against.

The smoke run at n = 200 already suggests the answer is uncomfortable, with UMAP
and diffusion maps needing seed counts in the hundreds. The production
measurement is running; if it holds, it is a finding about the benchmark's
resolving power in exactly the regime the selection rule declines in, and Chapter
10 reports it rather than raising the count until something separates.

Meanwhile the rule is stated as what it is -- a floor, with named exemptions --
and moved out of prose into a check over committed output, which is T5's systemic
fix. `check-artefact-producers.R` reads the seed count from every committed
artefact's provenance and fails on one below the floor that is not named in
`SEED_EXEMPT` with the reason the chapter will print. It also fails on an
exemption that has stopped being true, in the other direction.

E1's three arms are exempted with their designs stated: arm A2 trades seeds for
settings deliberately, because it exists to establish overlap in the
(g/s, non-planarity) plane and coverage of the setting space is what buys that,
not precision within a setting -- and it is reported with a cluster bootstrap
over settings, which is the interval that accounts for exactly this.

### The grid's producer, before the grid runs

Phase 3's producer changes land now rather than after generation, because every
one of them would otherwise mean regenerating the artefact.

**`rank_metrics()` gets its first caller**, four days after being written for it.
Trustworthiness, continuity, kNN preservation and Q_NX each built both rank
matrices from scratch, and `.rank_matrix()` at n = 800 costs 0.20 s against
0.017 s for a whole Procrustes fit, so four calls per method per cell was most
of the metric budget. Measured at n = 800: **2.32 s per fit against 1.42 s**, and
the numbers agree with the four separate calls to **1.1e-16** across four metrics
x four methods x nine cells. That is the closure T1 asked for -- an assertion
that fails on the pre-fix tree, not a re-reading of the change.

**The two k's are named, and they were never the same number.** The grid has
always scored Q_NX at 20 against the CHART while scoring the other three at 10
against AMBIENT distance -- two k's and two reference geometries, in adjacent
columns of one table, with nothing saying so. The first version of this refactor
unified them, which would have silently changed what the headline column means.
Both are now constants in `R/constants.R` with the reason each is what it is, and
both travel in the row and in the provenance block, so a chapter reading one can
say which question it answers.

**A failed fit says why.** `ran = FALSE` collapsed three causes into one
indistinguishable state: the method declared itself unavailable, the method
returned NULL by design, or the method threw. `status` names which and `reason`
carries `conditionMessage()` rather than discarding it. On the smoke grid that
separates the autoencoder's twelve declared-unavailable cells from the
Laplacian's four genuine declines, which the old artefact could not have told
apart. The `is.null(emb)` contract is untouched -- every consumer still reads
`ran`, which is what the roadmap's anti-list warns against breaking.

`irreducible_loss()` also moves out of the method loop: it is a property of the
sample and does not know a method exists, so it was being computed nine times per
cell instead of once.

### Claim A has a producer

`scripts/run-evaluator-audit.R`. Chapter 9 is the book's largest chapter and its
declared novel contribution, and it had no code at all -- its only supporting
numbers came from an accordion pleat now documented as a negative result, in a
parameterisation retired two phases ago.

The question is made falsifiable by the thing only a benchmark with known truth
can do: hand the evaluator the exact answer as a candidate. If an evaluator is a
good judge, the exact unfolding must score at least as well as any wrong
embedding, and the sharpest wrong embedding to hand it is a two-component PCA of
the folded cloud -- a plainly bad chart and an excellent reproduction of ambient
distance. An **inversion** is an evaluator ranking the exact chart below PCA.

The smoke run already produces them: at theta = 0.5, ambient-referenced
continuity, kNN preservation and Q_NX all rank PCA above the exact chart on half
the seeds, while the same metrics against the chart never do. Margins are small
-- of order 0.001 -- and the pilot is running the design the risk register asks
for before any of Chapter 9 is drafted.

## Phase 19 — the pilot that decides Chapter 9

`ROADMAP.md` R1 was the largest single risk to the book's thesis: the inversion
threshold is the declared novel contribution and Chapter 9's 4,400 words, and it
had never been computed on the Miura in the [0, 1] parameterisation. Its only
supporting numbers came from an accordion pleat now documented as a negative
result. The mitigation was to run a narrow pilot **before** committing to the
chapter, and to re-budget down if it came back empty.

It did not come back empty. It came back with a better claim than the one it was
sent to test.

**Design.** 3 theta x k in {5, 10, 20, 40} x n in {400, 800} x 20 seeds on
`miura_ori(6, 6)`, three reference geometries, two candidates: the exact
unfolding and a two-component PCA of the folded cloud. The exact unfolding is
handed to the evaluator as though it were a submission, which is the one thing a
benchmark with known truth can do and a real dataset cannot. An **inversion** is
an evaluator ranking the exact answer below PCA.

**1. The inversion exists, and it obeys a law in k and theta.**

| ambient-referenced continuity | k = 5 | k = 10 | k = 20 | k = 40 |
|---|---:|---:|---:|---:|
| theta = 0.2 | 0.000 | 0.050 | 0.375 | 0.850 |
| theta = 0.5 | 0.000 | 0.225 | 0.825 | 1.000 |
| theta = 0.8 | 0.275 | 0.875 | 1.000 | 1.000 |

Monotone in both, and certain in the corner. That is the quantitative law the
chapter was budgeted for, and it was never observable on the pleat this claim
originally came from.

**2. The margin is negligible, and that is the stronger finding.** Continuity's
preference for PCA never exceeds **0.003** -- two orders of magnitude below the
book's own reportable difference -- while the two candidates' reconstruction
errors at theta = 0.8 are **0.000 and 0.108**. The claim the numbers support is
not "the evaluator prefers a wrong embedding by X". It is that continuity cannot
distinguish a perfect embedding from a plainly wrong one *at all*, and reports
both as excellent. The chapter must write that, and the temptation will be to
write the weaker version because it sounds bolder.

**3. Optimism is not uniform, and "four metrics, one number" is the wrong
frame.** At n = 800, kNN preservation and Q_NX rank the exact chart first, by
margins clearing the reportable difference in 44% and 33% of cells;
trustworthiness is inert either way at 1e-4; continuity is the one that inverts.
Four metrics, four different answers.

**4. The reference geometry dominates the metric.** Graph-referenced results
match ambient-referenced ones to three decimals on every metric, and
chart-referenced results **never invert at any k, theta or n**. The law to state
is which question each evaluator is answering, not a correction factor to apply
-- which is what the audit design hoped for and what the numbers deliver.

**5. A caveat that must not be buried.** The rank metrics' inversions are largely
a small-sample effect: kNN inverts on 30% of cells at n = 400 and 3% at n = 800.
Continuity's is not -- it holds at 44% at n = 800. Any figure pooling over n
reports two phenomena as one.

Chapter 9's budget stands at 4,400 and its specification is rewritten in
`CHAPTERS.md` against these numbers, before a word of it is drafted. The pilot
artefact is `data/processed/evaluator-audit-pilot.rds`, with provenance.

### Publishing: three surfaces that were silently broken

Not a tidy-up. Each of these is a surface that looked fine to anyone who built
the book and was broken for someone reading it, with no check that could see it.

**`CITATION.cff` rendered an empty citation dialog.** It carried `type: book` at
the top level. In CFF 1.2.0 the top level describes the REPOSITORY and its `type`
enum admits only `software` and `dataset`; GitHub answers an invalid type by
rendering nothing rather than by reporting an error, so the file had been broken
for as long as it had existed and looked correct in the source. The repository is
`software` now and the book is a `preferred-citation`, which is also the honest
statement -- the repository is not the work.

`scripts/check-citation-cff.R` is the check. Not a full schema validator --
cffconvert is, and it is a Python dependency this repository does not otherwise
have -- but it covers the rules whose violation produces exactly that silent
failure, and it was demonstrated red on the file as shipped. It also notes that
four files claim version 0.1.0 against a repository with no tags at all.

**The dark mode was half-applied, and the half that was missing was unreadable.**
Measured, reproducing the audit's numbers exactly:

| surface | as shipped | now |
|---|---:|---:|
| search dropdown text | **1.40:1** | 10.27:1 |
| code comments | **1.90:1** | 9.17:1 |
| code variables | **1.01:1** | 9.02:1 |

The failure is structural rather than careless. `style/style.css` recolours the
page through custom properties, and the two surfaces it missed are ones bs4_book
paints with literals -- `background-color: #fff` on the dropdown, and the a11y
LIGHT syntax palette. **A token system hides exactly the places it does not
cover**, which is worth stating as a lesson rather than as a bug. Both are
replaced with the a11y dark palette, which is the same source's companion.

`scripts/check-contrast.R` computes all eighteen pairs the book renders text on,
in both themes, from WCAG relative luminance. Base R, no CSS parser and no
library, so it runs in the same job as the chapter lint. It also fails if a
colour it checks has disappeared from the stylesheet -- otherwise it drifts into
a green report about colours nobody renders.

**The EPUB had an invalid `dc:language`, a fresh random identifier on every
build, and no licence.** Two builds of the same text were two different
publications to a library system, and a CC-BY work shipped without the one field
it cannot omit. `lang`, `identifier`, `rights`, `publisher` and `keywords` are in
`index.Rmd`'s front matter, along with `papersize: a4` and a list of figures --
53 figures is past the point where a reader finds one by leafing.

### One cell, three producers -- and two methods that ignored their own k

**`one_cell()` lived inside `run-benchmark-grid.R`**, so the other two grids the
book specifies could not have it. That is a large part of why they did not
exist: `part2-sweeps.rds` and `classic-grid.rds` were two of the nine specified
artefacts with no producer, and the reason was not that the work was hard.

`R/grid.R`'s `grid_cell()` is that cell. Verified numerically identical on the
smoke grid -- every numeric column unchanged, plus a `d` column recording the
target dimension. `scripts/run-part2-sweeps.R` sweeps k where the main grid
holds it fixed; `scripts/run-classic-grid.R` scores the Swiss roll, the S-curve
and the severed sphere through the same function, the same metrics and the same
floor. A comparison in which the two sides are scored by two code paths is not a
comparison.

**Writing the k-sweep found that two methods never used k.** The audit had
flagged `embed_tsne()`, which declared `k` and passed a fixed perplexity of 30.
`embed_diffusion()` does the same thing: it took `k` and set its kernel bandwidth
from the 1-NN distance regardless.

Both would have drawn a flat curve, and a flat curve is a finding -- it reads as
"insensitive to neighbourhood size", which for t-SNE is the opposite of what it
is known for. Perplexity IS t-SNE's neighbourhood parameter, so k maps to it
directly; the diffusion bandwidth now comes from the k-th neighbour, which is
what `embed_laplacian()` already did, so the two kernel methods finally set their
scale the same way. Measured at n = 400 over k in {5, 10, 20, 40}, Q_NX@10 goes
0.759 to 0.871 for t-SNE and 0.762 to 0.847 for diffusion; both were constant
before.

This changes both methods at `K_DEFAULT`. That is deliberate and it is made
**now, before the main grid has ever been generated**, so no committed artefact
is invalidated by it. A grid that states a k which does not reach the method has
a column that lies.

The sweep carries the check that makes this catchable next time: it names PCA
and classical MDS as the genuinely k-free methods and fails if anything else
draws a flat curve. The first version of that check compared raw spreads and
passed on a method that ignores k entirely, because seed variation swamps
k-insensitivity -- it compares the mean at each k now, and reverting `embed_tsne`
turns it red and names t-SNE.

### A check that was not running

`check-artefact-producers.R` and `check-contrast.R` were described in two commit
messages as running in CI. They were not. The artefact step was added to
`lint.yml`, then removed again so that a commit would not land knowingly red
while the E1 artefacts were regenerating -- and the removal was never undone. The
later edit that meant to add the contrast step anchored on the text of the step
that had been removed, so it matched nothing and silently did nothing.

Both are in `lint.yml` now, and the edit that put them there asserts its anchor
rather than replacing on a best-effort basis. Recorded here rather than quietly
fixed, because it is precisely the failure this phase is about: a change that
looks applied and is not, described in prose as done.

The check, once running, immediately earned its keep. It refused three `OPEN`
entries that had stopped being true -- `evaluator-audit`, `part2-sweeps` and
`classic-grid` all have producers now -- and it refused the committed
`product-grid.rds`, which had been produced across ten seeds. That artefact is
removed from the tree rather than exempted: unlike E1's arms, which trade seeds
for coverage of a setting space and say so, ten seeds here was a default nobody
had defended.

## Phase 20 — the evidence layer, generated

Five artefacts, all from commit `f1bcc5f`, all with `dirty = FALSE` and one `R/`
tree hash between them. This is the first time the book has had an evidence layer
that `scripts/check-artefact-producers.R` reports as intact.

### E1, regenerated

Three arms, one `r_sha`, full provenance blocks, `e1-difficulty` at 990 rows.
The first regeneration of these had arm A produced under a different `R/` than
arms A2 and B, because a commit landed mid-run -- the difference was an unused
new file and could not have changed a number, which is exactly the reasoning the
`dirty` flag exists to stop anyone relying on. Re-run from a clean tree instead.

### The seed budget, and what it costs standing rule 1

Within-cell standard deviation of excess over the floor, worst cell over
3 theta x 2 noise at n = 800, 40 seeds, and the seeds needed to make a difference
of `MIN_REPORTABLE` detectable at 80% power:

| method | sd | seeds needed |
|---|---:|---:|
| t-SNE | 0.2873 | **3,241** |
| LLE | 0.2034 | **1,624** |
| Laplacian eigenmaps | 0.0446 | 79 |
| UMAP | 0.0438 | 76 |
| diffusion maps | 0.0339 | 46 |
| Isomap | 0.0159 | 10 |
| PCA / classical MDS | 0.0132 | 7 |

**Standing rule 1's floor of 20 is two orders of magnitude short for two
methods and short for five of the eight.** That is a finding about the benchmark,
not a compute plan: nobody is going to run 3,241 seeds, and the honest response
is to say that at 20 seeds this benchmark cannot resolve a 0.02 difference for
t-SNE, LLE, the Laplacian, UMAP or diffusion maps, and to let the pre-registered
selection rule decline where it must. The rule was written before this was
measured, which is the only reason that sentence can be written now.

Note that LLE and the Laplacian are registered as DETERMINISTIC. Their spread is
not method stochasticity -- it is sensitivity to which 800 points were drawn. A
seed budget derived from stochastic methods alone would have missed the two
worst offenders.

### The product grid, and a crossover the audit's own re-measurement missed

12,960 rows, 20 seeds, `boundary = FALSE`, chart-exit fraction asserted 0 in
every cell, 153 minutes. Mean excess over the floor at d = 2, crease arm:

| theta | PCA / MDS | Isomap | diffusion | Laplacian |
|---|---:|---:|---:|---:|
| 0.1 | **0.0063** | 0.0160 | 0.0771 | 0.0737 |
| 0.5 | **0.0034** | 0.0157 | 0.0535 | 0.0716 |
| 0.7 | **0.0047** | 0.0162 | 0.0248 | 0.0693 |
| 0.8 | 0.0201 | **0.0194** | 0.0291 | 0.0694 |
| 0.9 | 0.1839 | **0.0405** | 0.1901 | 0.0770 |

**The ordering crosses over at theta = 0.8.** ROADMAP.md section 9 states, as a
verified re-measurement, that "PCA/MDS have the lowest excess at all nine theta"
and that "ambient < geodesic < neighbourhood holds throughout". Neither survives
20 seeds at production settings: Isomap takes the lead at 0.8 and holds it at
0.9, where the ambient methods lose a factor of forty.

This is the strongest vindication standing rule 2 has had. A single summary
number reverses the ordering the curve shows at seven of nine theta, and the mean
over theta would have reported Isomap as the winner outright -- which is also
wrong. The benchmark's whole reason to exist is that method ranking is a function
of difficulty, and here it is.

### Part II's k-sweep

3,780 rows. Every method that takes a k now has a curve, because two of them did
not use theirs until this phase. Q_NX at theta = 0.5:

| method | k=5 | k=12 | k=20 | k=45 | k=70 |
|---|---:|---:|---:|---:|---:|
| Isomap | 0.851 | 0.941 | **0.950** | 0.942 | 0.936 |
| LLE | 0.428 | 0.906 | 0.929 | 0.931 | 0.930 |
| Laplacian | 0.701 | 0.766 | **0.777** | 0.766 | 0.759 |
| t-SNE | 0.726 | 0.786 | 0.820 | 0.867 | 0.881 |
| PCA / MDS | 0.944 | 0.944 | 0.944 | 0.944 | 0.944 |

Isomap and the Laplacian have interior optima at k = 20; LLE is catastrophic at
k = 5 and recovers by 12; t-SNE and UMAP rise monotonically over the whole range.
PCA and MDS are flat to the digit, which is the control the sweep needs and the
check it enforces.

### The classic grid

4,680 rows over the Swiss roll, the S-curve and the severed sphere, scored by the
same `grid_cell()`, the same metrics and the same floor. The floor is **0 in
every cell**, because all three have two-dimensional charts and the target is
two-dimensional -- the same statement the main crease grid makes, and the reason
the product construction exists. On these three, every unit of error is loss the
method is responsible for.

## Phase 21 — the grid, the audit, and the first chapter

### The main grid

10,800 rows, 1,200 cells, 20 seeds at n = 800, 294 minutes on four cores,
`dirty = FALSE`. The last artefact the book specifies that had never been
produced.

1,601 fits did not run and the artefact says why, which the old schema could
not: 1,200 autoencoder cells declared unavailable, 400 Laplacian declines and
one from diffusion maps. The 400 is the audit's S1 finding reproduced exactly --
`embed_laplacian()` returns NULL on **every** outlier-noise cell, 400 of its
1,200 -- and it is now a `status` and a `reason` in the table rather than an
indistinguishable `ran = FALSE`.

### The pre-registered rule, applied for the first time

`select_method()` was committed before this grid existed. Run against it, over
theta 0.4-0.6:

| noise | R | decision | why |
|---|---:|---|---|
| none | 3.67 | select **MDS** | Isomap leads at 0.0272 but PCA and MDS are 0.0120 behind -- **below the reportable difference**, so it is a tie, broken toward the method that assumes least |
| ambient | 4.78 | select **MDS** | the top three are within 0.0009 of each other |
| outlier | 14.9 | select **UMAP** | ahead by 0.0485, which clears the threshold; the Laplacian is **excluded** for declining more than a tenth of its cells |

Two things worth having written down before the numbers were seen. The rule
**declines to name Isomap the winner** in the clean regime even though it is
first, because the margin is not reportable -- that is the whole of what a
pre-registered threshold buys. And under outlier noise the ordering inverts: a
neighbourhood method beats the ambient methods outright, on a benchmark where
the ambient methods win everywhere else.

Read together with the seed budget, the two results are consistent and the pair
is the story. The benchmark **can** separate method families -- R runs from 3.67
to 14.9 -- and **cannot** separate methods within a family, because those
differences are smaller than a spread that would need thousands of seeds to
resolve. The rule says so instead of picking.

### The evaluator audit, at full size

19,200 rows, 20 theta x 4 k x 2 n x 20 seeds, 129 minutes. The pilot's finding
survives and gains two controls that make the mechanism unambiguous.

Ambient-referenced continuity's inversion rate, the share of cells where the
evaluator ranks the exact unfolding below a two-component PCA:

| | k = 5 | k = 10 | k = 20 | k = 40 |
|---|---:|---:|---:|---:|
| theta = 0 | 0.00 | 0.00 | 0.00 | 0.00 |
| theta = 0.1 | 0.05 | 0.15 | 0.25 | 0.58 |
| theta = 0.5 | 0.00 | 0.22 | 0.82 | 1.00 |
| theta = 0.9 | 0.98 | 1.00 | 1.00 | 1.00 |

**At theta = 0 the rate is exactly zero, at every k and every metric.** A flat
sheet contracts nothing, so ambient distance *is* chart distance and there is
nothing to invert. **Chart-referenced evaluators never invert either -- not once
in 19,200 rows.** Two controls, both predicted by the contraction and both
clean, which is what turns a rate into a mechanism.

The effect size is unchanged from the pilot and is the part that must not be
overstated: continuity's margin never exceeds 0.0223 and clears the reportable
difference in 0.3% of cells. kNN preservation and Q_NX have margins an order of
magnitude larger, and they mostly point the other way -- those two rank the truth
first. The supportable claim is that **continuity cannot distinguish a perfect
embedding from a plainly wrong one**, not that it prefers the wrong one by a
margin worth reporting.

### Chapter 2, drafted

The first chapter of the book, and the first measurement of what drafting costs.

3,404 words against a 3,900 budget -- **13% under**, inside the roadmap's own
tolerance for R4 and without feeling thin. That is data for the re-budget
question rather than a shortfall to pad: the section that came in shortest is
`geom-core`, and it came in shortest because the derivation it carries is
genuinely five steps long and not seven.

Four figures, thirteen chunks, fourteen citations, eighteen inline `r`
expressions and no typed number anywhere. It knits clean. Every claim in it is a
test: the isometry over the theta sweep, the exact sin(rho/2) contraction, the
floating-point floor under "strictly", Maekawa, and the clearance between
non-adjacent facets.

Its diagnostics section is about three of this project's own errors, which the
specification asked for and which turned out to be the easiest section to write:
an isometry test cannot tell a fold from a pleat; Maekawa cannot tell a labelling
from its inverse; and a first-order flex at the flat state is a property of being
flat rather than of being foldable. The moral the chapter draws is the one this
whole phase has been earning -- **a test that a correct implementation passes is
not the same as a test a wrong one fails.**

### The anchor namespace, third time

`check_anchors()` derives a chapter's mnemonic from the anchors themselves now,
as their longest common prefix. Two earlier rules failed on the same chapters:
stripping a trailing word off the first anchor cannot tell `intro-answer-key`
from `folding-geometry-question`, and taking the H1's anchor instead is wrong the
other way, because the specification deliberately pairs `{#folding-geometry}`
with `geom-` and `{#comparison}` with `comp-`. What the rule is actually for is
pandoc id collision, so it now checks the thing that matters and could not be
seen from inside one file: that no two chapters have chosen the same namespace.

