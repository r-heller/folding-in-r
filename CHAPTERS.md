# CHAPTERS.md — Folding in R

Per-chapter specification for the full twelve-chapter book.

> **Re-budgeted 2026-08-26, and the total corrected 2026-08-30.** The original
> figure was set before either experiment ran and survived both unexamined. It
> was sized for a three-family book led by Claim C. The per-chapter figures
> below were revised for the book that survived: one verified pattern family, a
> headline claim that was refuted, and a spine whose evidence is a product suite
> rather than a 2,700-cell grid. See § "Re-budget" at the end of this file.
>
> **The re-budget's stated total, ~36,700 words, was not the sum of its own
> rows.** The rows sum to **41,670**, against **41,720** before — a redistribution
> of 50 words, not a reduction of 5,000. Two chapters grew by 1,550 between them
> and three shrank by 2,000, and the ~36,700 came from neither column. Both
> totals below are now computed from the table and nothing quantifies the
> "smaller book" claim, because the rows do not support one.
>
> That is a finding, not a correction: **the reduction the re-budget describes
> has not actually been made.** Whether one verified family can carry 41,670
> words is `ROADMAP.md` risk R4, and it is open. Re-deriving the budget
> bottom-up from what each chapter can now evidence is a decision for the author,
> and it should be made before Chapter 2 is drafted, not after.

Original scope: **53 figures, 145 code chunks, ~60 citations**, plus a new
`13-conclusion.Rmd` and a 150-word `98-citing-this-guide.Rmd`.

Companion to `PLAN.md` (sequencing, gates, budgets) and `PROJECT_CONCEPT.md`
(claims and corrections). Build order is in `PLAN.md`; it is **artefact-first**,
and no chapter may be drafted before the artefact it reads is committed.

**Every existing stub's `{#anchor}` and italic opening question is preserved
unless a replacement is justified below.** The stubs' bullet outlines are the
author's intent; they are expanded, not replaced. Where a bullet is reshaped it is
said so explicitly.

**Section contract.** One contract, nine slots, namespaced anchors — chosen
because it is the only form that survives pandoc id-collision across twelve
chapters:

```
## What this chapter answers  {#<mn>-question}
## Setup                      {#<mn>-setup}
## Background                 {#<mn>-background}
## <free-wording core>        {#<mn>-core}
## Results                    {#<mn>-results}
## Diagnostics                {#<mn>-diagnostics}
## Where it fails             {#<mn>-limits}
## Reproduce this             {#<mn>-reproduce}
## Further reading            {#<mn>-reading}
```

Part II's drafted headings map onto it: *Learning objectives* → merged into
`-question`; *Conceptual background* → `-background`; *On a crease pattern* →
`-core`; *Reading the curve* → `-results`; *Common pitfalls* → `-diagnostics`;
*Where it fails* → `-limits` (drop the `-fails` suffix, which is a second name for
the same slot). *Exercises* and *Session info* are either promoted to the contract
for all twelve chapters or dropped — not left in four chapters only.

**The narrative subset.** Nine slots suit a chapter that presents a method and
measures something. Chapters 1 and 13 present neither, and `-setup`, `-results`,
`-diagnostics` and `-reproduce` buy a reader nothing there — an introduction's
"Results" section is a forward reference to an artefact that does not exist yet,
which is the same thing this file already warns about two paragraphs into
Chapter 1's entry. They carry five slots — `-question`, `-background`, `-core`,
`-limits`, `-reading` — in the same order, and may carry more. `lint-chapters.R`
enforces the distinction rather than leaving it to be remembered.

**The appendices carry anchors, not slots.** `A1` and `A2` are reference
material; what they need is that every section is a cross-reference target in one
namespace, which is now checked — it was not, because the check looped over the
twelve chapters, every one of them an exempt stub, and never over the only two
written files in the tree. The contract's nine slots are not asked of them. The
anchor goes on the `{-}` heading as `{#datasets-generated -}`: only the H1 anchor
feeds `render-chapter-pdfs.R`'s filename, so an anchored level-2 unnumbered
heading is safe where an anchored H1 would not be.

---

## Front matter

### `index.Rmd` — Preface · 420 w · 1 figure

Unnumbered, **no `{#id}`** — bookdown slugs this file to `index.html` and both the
sidebar and landing page key off the untitled front-matter slot.

Opens on a claim rather than a question, which is right and stays. Four edits
only:

- **P1** (+30 w) — add the sentence distinguishing **intrinsic** from **ambient**
  isometry. This is the book's crux and its absence is the single most
  consequential gap in the current text. See `PROJECT_CONCEPT.md`.
- **P3** (+5 w) — repair a false implication in the benchmark contrast.
- **P4** — optional edit to the Chari & Pachter framing, author's call. If
  Chapter 11 §1's concession stands, this paragraph must be tightened or an
  attentive reader will catch the contradiction.
- **"What this book is not"** (+24 w) — add the clause disclaiming arbitration of
  the Chari–Pachter dispute.

### `00-how-to-use.Rmd` — How to use this book · 750 w

Unnumbered, no `{#id}`; nothing cross-references it and adding an anchor invites
`\@ref()` links into front matter, which bookdown numbers oddly.

- **Standing methodological rules** (330 w) — expand from three to **four** and
  make each operational. The fourth is the reporting standard relocated from
  Chapter 10 §10.6, which is where a rule has to live to survive.
- **What you need** (150 w) — correction plus the execution policy. No install
  step: helpers are sourced from `R/`.
- **How the chapters are shaped** (170 w) — **new.** The nine-slot contract above.
  This section is what `scripts/lint-chapters.R` enforces.
- **Callouts** (110 w) — **new.** Four lines naming the five `box*` classes and
  what each is for. `boxempty` is the suggested-citation block and gets its call
  site in `98-citing-this-guide.Rmd` (S1-7).
- **How to read it** (60 w) — keep, with one addition.

---

## Part I — Folding

### `01-introduction.Rmd` · `{#intro}` · 2,400 w · 1 fig · 4 chunks · 8 cites

> *Why should a crease pattern tell you anything about a gene expression matrix?*
> — **preserve verbatim.** The best of the twelve opening questions.

| Section | Anchor | Words |
|:--|:--|--:|
| What this chapter answers | `intro-question` | 170 |
| The argument this book joins | `intro-background` | 550 |
| The answer key | `intro-core` | 500 |
| What is claimed, and what is not | `intro-limits` | 650 |
| How the book is organised | `intro-roadmap` | 350 |
| Further reading | `intro-reading` | 180 |

Three of these anchors used to be `intro-answer-key`, `intro-argument` and
`intro-claims`. Each named a contract slot by other words, and
`scripts/lint-chapters.R` rejected all of them; the chapter was exempt only
because it is still a stub, so the conflict was going to surface on the first
commit of real prose. `intro-roadmap` is not a contract slot and does not have to
be: the contract fixes what must be present, not what may.

`intro-limits` carries the 200 words the re-budget gave this chapter: the
concession that the Swiss roll discriminates better is exactly a statement of
what is not claimed, and the rows now sum to the 2,400 the budget table gives it.
They summed to 2,200 before, which is what the heading said before the re-budget.

**The two middle rows have swapped.** The contract's order is fixed and
`background` precedes `core` in it. That is also the better introduction — pose
the question, place it in the argument it joins, then produce the device that
answers it — but it is an editorial change and it is recorded as one.

`intro-limits` is where the **category-error concession** lands: only Isomap and
the answer key claim what the headline metric measures; t-SNE, UMAP, LLE and
autoencoders never claim isometry recovery, and scoring them against isometric
truth and reporting they lose is a category error unless said so first.

**Draft this chapter LAST of Part I.** Every instinct says the introduction comes
first; it must not. `intro-background` forward-references Chapter 9's headline
finding, which does not exist until `evaluator-audit.rds` does.

*Risks.* Over-claiming in `intro-background` — the scope-limit paragraph is load
bearing, not a courtesy. `fig-01-answer-key` is doing a great deal of work and may
collapse into four cramped panels; split it if it does not read at 9 cm.

### `02-folding-geometry.Rmd` · `{#folding-geometry}` · 3,900 w · 4 figs · 9 chunks · 13 cites

> **Replace the question.** Current: *What makes a crease pattern a valid
> manifold?* → Proposed: ***What does folding preserve, and what does it
> destroy?*** The replacement names the chapter's actual content and sets up the
> intrinsic/ambient split.

| Section | Anchor | Words |
|:--|:--|--:|
| What this chapter answers | `geom-question` | 150 |
| Setup | `geom-setup` | 40 |
| Background | `geom-background` | 700 |
| The isometry, in five steps | `geom-core` | 1,400 |
| Results | `geom-results` | 400 |
| Diagnostics | `geom-diagnostics` | 250 |
| Where it fails | `geom-limits` | 500 |
| Reproduce this | `geom-reproduce` | 100 |
| Further reading | `geom-reading` | 160 |

**This chapter now carries the stress proposition** (see `PROJECT_CONCEPT.md`
Claim A). Ambient-referenced stress measures reproduction of $d_A$; Proposition 4
gives $d_A < d_U$ strictly for every $\theta > 0$; two-component PCA is the
least-squares-optimal linear approximant to that same ambient configuration.
Therefore `stress(truth) > stress(PCA)` — one line, no simulation. It is stronger
as a theorem than as an experiment, and moving it here removes the objection that
1,200 grid cells were spent demonstrating a definition.

**Three corrections land here** (`PROJECT_CONCEPT.md`): curvature is *not*
concentrated at vertices — write *against* that misconception rather than merely
avoiding it, since it is the natural wrong intuition; delete the "real data
manifolds have creases too" sentence rather than hedging it; and the $\theta$
definition, in the same commit as `90-glossary.Rmd` and `A1-notation.Rmd`.

*Reshaped bullet.* The stub asks for a "boxed aside, one page, labelled
background: the Huzita–Hatori axioms." One page is too much for material the book
never uses again — reduce to a four-sentence demarcation box explaining why
construction axioms are *not* what makes a crease pattern a manifold.

*Risk.* Maekawa and Kawasaki will try to expand — they are the most familiar
material in the chapter and therefore the most tempting. Hold them to
`geom-background`. `style/preamble.tex` already loads `amsmath`/`amssymb`
"because this volume is theorem-heavy", which is now true.

---

**Post-audit additions (2026-08-26). These are not optional colour; they are the
chapter's strongest material and all of it is computed.**

**`geom-core` gains the numerical floor of the contraction.** The ratio of
ambient to geodesic distance across a crease of dihedral $\rho$ is exactly
$\sin(\rho/2)$ — verified over 360 configurations to one unit in the last place,
and the ratio depends on $\rho$ alone rather than degrading with distance, which
is the substance of the claim. But the strictness has a floor: since
$1 - \sin(\rho/2) \approx (\pi-\rho)^2/8$, the contraction stops being
representable in double precision below a fold angle of about $3\times10^{-8}$
rad, against an analytic $\sqrt{8\varepsilon/2}$. Say it, because "ambient is
strictly less than chart for every $\theta > 0$" is false as written in floating
point, and because it is what makes the vanishing-$\theta$ end of every curve in
Part III behave as it does. Producer: `tests/testthat/test-contraction.R`.

**`geom-diagnostics` becomes the chapter's best section, and it is about two
failures of this project's own making.** Both are cheap to state and both
generalise:

1. *An isometry test cannot tell a fold from a pleat.* The Yoshimura
   implementation that shipped folded its horizontal creases and left every
   diagonal at $\rho = \pi$. It passed the facet-isometry test perfectly —
   because a pleat **is** a rigid folding — and passed Kawasaki, because the flat
   pattern was never the problem. What caught it was deriving the mountain/valley
   assignment from the folded dihedral and testing Maekawa on the *result*: 12 of
   16 interior vertices failed. The same check showed the Miura's hand-assigned
   labels matched the real folding on 36 of 60 creases.

2. *A first-order flex at the flat state proves nothing.* At $\theta = 0$ every
   $z$ column of the rigidity Jacobian vanishes, so the non-trivial flex count is
   $V - 3$ for **any** planar pattern whatsoever. Second order and a finite
   continuation are what decide. This is E2's finding and it belongs here as much
   as in Chapter 8.

The moral for the reader is the one this book keeps earning: a test that a
correct implementation passes is not the same as a test a wrong one fails.

**`geom-limits` gains the boundary caveat.** Chart distance equals geodesic
distance only when the straight segment between two chart points stays on the
sheet. A Miura's unfolded outline is not convex — its edge is a zigzag with teeth
— so for pairs straddling a tooth the chart distance is a *lower bound*.
`chart_exit_fraction()` measures how often that happens; on the settings E1 used
it ranges from 0.00% to 4.31%. State it as a bound-not-equality where it applies,
and say how it was checked.

**Word budget.** 3,400 → **3,900**. The additions are load-bearing and the
chapter is now the book's methodological anchor: it is where a reader learns why
the rest of the volume is trustworthy.

**`geom-reproduce` can name real files**, which no other chapter can yet:
`tests/testthat/test-folding.R`, `test-patterns.R`, `test-contraction.R`. All
pass; nothing here is promised.

### `03-generative-model.Rmd` · `{#generative}` · 2,500 w · 5 figs · 11 chunks · 9 cites

> *How do you turn one pattern into a family of test problems?* — **preserve
> verbatim.**

The **most cross-referenced anchor in the book**: `00-how-to-use` routes readers
here explicitly, and Chapter 8 builds on it.

| Section | Anchor | Words |
|:--|:--|--:|
| What this chapter answers | `gen-question` | 200 |
| Setup | `gen-setup` | 60 |
| Background | `gen-background` | 350 |
| The Miura-ori in four scalars | `gen-core` | 650 |
| Sampling and noise | `gen-sampling` | 500 |
| Results: what theta does | `gen-results` | 600 |
| Diagnostics | `gen-diagnostics` | 250 |
| Where it fails | `gen-limits` | 300 |
| Reproduce this | `gen-reproduce` | 200 |
| Further reading | `gen-reading` | 140 |

All five stub bullets preserved and expanded; none dropped.

**The closed form in `gen-core` is derived and verified here, not quoted.** It must
not acquire a citation by osmosis. Schenk & Guest 2013 is verified in the
bibliography and covers the unit-cell quantities under a *different* $\alpha$
convention — if the two forms are reconciled, say so and show the map; if not,
cite them as related and keep the derivation self-contained.

*Dependency.* This chapter cannot be drafted before `R/` exists. Everything in
Part I except the Preface is downstream of it.

---

## Part II — Methods

Each chapter both **teaches** the method and **runs** it on a crease pattern.
Reading order matters: Chapter 4 establishes `read_run()`, the digest check and
the `R/methods.R` registry that the other three reuse.

### `04-linear-projections.Rmd` · `{#linear}` · 2,400 w · 4 figs · 13 chunks · 8 cites

> *When is a projection just a shadow?*

Core: PCA and classical MDS. `lin-core` (640 w) runs them across the $\theta$
sweep; `lin-results` (400 w) reads the curve.

*Risk.* The ground layer's `prcomp` versus `princomp` argument **does not
reproduce** and must not be written as given. The headline curve may be visually
dull if PCA degrades smoothly with no feature — that is an acceptable outcome and
should be reported as one, not engineered away.

*Blocked on:* `.gitignore` fix (S0-1), the committed Phase-11 tree (S0-2),
`eval = TRUE`, and `R/metrics.R` exporting `reconstruction_error(emb, truth,
normalise = TRUE)` and `procrustes_align()`. **Chapter 9 owns the alignment
convention** — Chapter 4 must not invent one.

---

**Respecified 2026-08-26.** The chapter was specified as a comparison between PCA
and classical MDS. They are the same thing: `cmdscale` on a Euclidean distance
matrix *is* PCA, and the two agree to 5.8e-15 across the whole E1 grid and to
1e-8 on every pattern tested.

Make the coincidence the result rather than an unremarked duplication. It is a
genuinely useful thing for a reader to know, it takes one figure and one
paragraph, and it sets up the chapter's real subject: what "linear" costs on an
object that is intrinsically flat but ambiently folded. The registry keeps both
entries because Chapter 4 shows they coincide; Chapter 10 must not report them as
two independent results, and `R/methods.R` says so at the definition.

The chapter also gains its best single number from the product suite: on a 4-D
chart forced into 2-D, PCA lands 0.0060 above the theoretical floor — closer to
optimal than any other method in the book, on a problem where the answer is
known exactly. A chapter titled "linear projections and where they break" should
open by admitting where they emphatically do not.

### `05-geodesic-methods.Rmd` · `{#geodesic}` · 3,000 w · 5 figs · 15 chunks · 10 cites

> *If the data lie on a folded sheet, how do you flatten it back out?*

**The chapter where the book's premise is satisfied exactly.** Isomap consumes
geodesics; a crease pattern gives them in closed form. Extra slot beyond the
contract: *When does the graph bridge?* (520 w), which pairs the analytic
short-circuit onset with the measured one.

*New mathematics — written and validated 2026-08-26.* `facet_gap(pattern,
theta)` gives the exact minimum ambient distance between non-adjacent facets, by
segment-to-segment and point-to-polygon distance in $\mathbb{R}^3$ with a
bounding-sphere reject. Validated as this spec asked: a point sample can only
overestimate a true minimum, and brute force converges down onto the exact value
from 2.83% over at a 4×4 grid to 0.004% at 30×30. That is a stronger check than
agreement at one resolution, which a wrong constant would also pass.

It is the sampling-free companion to `branch_gap()`, and the distinction matters
for this chapter: `branch_gap()` measures separation in units of sampling
density, so it grows as $\sqrt{n}$ and cannot support an analytic onset;
`facet_gap()` is a property of the surface alone, so it can be swept finely and
differentiated.

*Risk.* If the analytic and empirical onset angles disagree substantially, the
chapter's headline promise fails as stated — decide in advance whether that
becomes a reported discrepancy (preferable) or a retreat to the empirical curve.

### `06-neighbor-embeddings.Rmd` · `{#neighbor}` · 2,800 w · 5 figs · 15 chunks · 13 cites

> *Why do t-SNE and UMAP disagree about the same data?*

**Carries the `preserve.seed` finding.** `umap::umap`'s `preserve.seed = TRUE`
silently collapses 20 seeds to 1 — a direct violation of standing rule 1 that
would have invalidated every UMAP result in the book. Adds `uwot` as a second
implementation via an `impl` argument, so the chapter can show that the choice of
implementation moves the answer.

*Risk.* The chapter predicts flat curves through the first half of the $\theta$
range. Flat curves read as "nothing happening" unless the text says in advance
that flatness is the prediction and why.

*Decide before the sweep:* whether to store embedding coordinates. Storing them
inflates the artefact substantially; storing for a subset is the likely
compromise.

### `07-autoencoders.Rmd` · `{#autoencoders}` · 1,600 w · 4 figs · 14 chunks · 6 cites

> *Can a network learn the fold and the unfold at once?*

**The best result in Part II and the most fragile.** Reconstruction loss falls 18×
while distance from the true unfolding *rises* 40% — the network learns the fold
and does not learn the unfold. Measured on real `torch`, not estimated.

*Risks, all serious.* The headline is **one seed at one fold angle on stand-in
geometry** — if it does not reproduce on a Miura across seeds, the chapter has no
result. The rising distance may be a **harmless reparameterisation** rather than
structural loss; that question is exactly what truth-referenced $Q_{NX}(K)$ exists
to answer, so this chapter must report both headline metrics or it hands an
unanswerable question forward to Chapter 9.

*Cost.* 9.27 s per fit at 500 epochs, $n = 800$ — plausibly the largest single
line item in the book's compute. Three committed artefacts.
`embed_autoencoder()` must call `library(torch)` **inside its body**, and every
autoencoder test wraps in `skip_if_not_installed('torch')`.

---

## Part III — Benchmark

### `08-building-benchmarks.Rmd` · `{#benchmarks}` · 3,650 w · 5 figs · 13 chunks · 16 cites

> *How do you build a manifold whose true geometry you already know?*

| Section | Words |
|:--|--:|
| What a benchmark has to provide | 300 |
| The helper API, end to end | 450 |
| Three pattern families, and one honest gap | 500 |
| The isometry certificate | 400 |
| **Products: raising intrinsic dimension without losing truth** | 450 |
| Lifting to arbitrary ambient dimension | 300 |
| Why a benchmark stuck at intrinsic dimension 2 is not a serious benchmark | 300 |
| Building your own | 200 |
| What this chapter does not settle | 100 |

**§5 carries Claim B — the irreducible-loss bound — which `PROJECT_CONCEPT.md`
identifies as the book's strongest available claim.** Give it the weight that
implies. A product of two folded sheets is isometric to a product of two
rectangles, hence to a convex box in $\mathbb{R}^4$: truth is 4-dimensional and
the alignment group is $O(4) \ltimes \mathbb{R}^4$. That is what makes "the exact
smallest error any 2-D embedding could achieve" computable.

**§3 is where E2's outcome lands.** The title already anticipates the gap.

*Risk.* This chapter documents an API that does not exist yet, so every signature
is a proposal until `R/` is written. Write `tests/testthat/test-folding.R` — the
isometry certificate — **before any prose here**, and let the tests fix the
signatures rather than the prose.

---

**Respecified 2026-08-26, after E1 and E2.**

**§3 is retitled: "One pattern family, and two honest gaps."** The Yoshimura
joins the waterbomb as a withdrawal, and the chapter is better for carrying both
than for having quietly shipped either.

- *Waterbomb* (E2). It folds, but only under an imposed symmetry, with the closed
  form $\tan(\rho_h/2) = -\tan(\rho_d/2)/\sqrt2$ holding to 1.7e-15 and
  cross-checked by an independent developing-map reconstruction. Three things
  disqualify it as a grid row: the embedding is unproved (facet clearance falls
  to 0.026 at $\theta = 0.9$), fold amplitude is not monotone in $\theta$, and 27
  degrees of freedom remain on the free boundary so $\theta$ does not determine
  the configuration.
- *Yoshimura* (2026-08-26). Two rigid foldings were derived and **each leaves one
  of the three crease families flat**, which makes the folded object a
  parallelogram tessellation rather than a diamond one — a Miura wearing this
  pattern's crease lines. Both are exact, which is what makes it a result rather
  than a bug to patch.

Both withdrawals share a moral and §3 should state it once, plainly: **a test a
correct implementation passes is not the same as a test a wrong one fails.** An
isometry check cannot tell a fold from a pleat; a first-order flex at the flat
state is $V-3$ for any planar pattern whatsoever. Each trap was sprung and each
was caught only by a second, independent check.

**§5 grows from 450 words into the chapter's spine.** E1 retired Claim C, so the
irreducible-loss bound is what the book now rests on, and 450 words inside
someone else's section is not enough to carry it.

State the bound precisely — for normalised Procrustes against a $p$-dimensional
chart, no $d$-dimensional configuration beats the tail of the chart's spectrum,
exact, depending on the data alone with no method in it. Then show the property
that makes it a bound rather than a guess: it is **attained**, because the optimal
rank-$d$ projection sits exactly on it. That is a proof, and it is where the
weight goes.

**"Unbeaten" is a regression check, not evidence.** The grid tests every method
in the registry against the floor and none beats it — but the bound is *proved*,
so a method beating it would mean the implementation is wrong, not that the claim
is. Report it as what it is: the assertion the producer exits non-zero on. Do not
write it as though eight independent methods had corroborated a conjecture, and
do not write "nine methods": the registry holds nine entries and the autoencoder
declares itself unavailable, so eight run.

**Every number in this section reads from `product-grid.rds` through an inline
`r` expression, and as a curve.** The provisional figures this section carried —
excess sorting by what each method consumes, ambient below geodesic below
neighbourhood — came from a `--quick` run that was never saved, at two values of
$\theta$. Re-measured at production settings the ordering survives and the
headline number moves: standing rule 2 applies to this section as much as to any
other, and one number quoted from two $\theta$ values is exactly the
cherry-picking the rule exists to prevent.

**The bound is family-agnostic, and that is the finding rather than a concession.**
`PROJECT_CONCEPT.md` listed crease-specificity among the book's three
differentiators. `product_manifold()` imposes no family constraint: two isometric
Swiss rolls give intrinsic dimension 4, an exact chart and a computable floor
exactly as two Miura sheets do, so the differentiator as written is refuted. The
grid now carries a Swiss-roll-product arm for precisely this reason, and §5
reports the two families' floors side by side. Read it as a statement about the
CONSTRUCTION and not about which family is harder — the two arms are swept over
their own parameters and matched on nothing, which is the error E1's arm A had to
be redesigned around. What crease-specificity rests on afterwards is zero reach
and a non-smooth answer key, and §5 should say so in one sentence.

*Risk.* §5 cannot be drafted until it can state in one sentence what the product
bound owes to creases and what it does not (ROADMAP.md R5). If that sentence will
not come, the differentiator is the thing to cut, not the section.
Reported against zero its raw error reads as failure; reported against the floor
it says the loss belongs to the data. *That contrast is the book's thesis in one
table.*

**Say why the main grid's floor is zero.** A 2-D chart in a 2-D target has floor
0 in every cell, so the `floor` column there is identically zero — which is not a
defect but a statement worth one sentence: on that grid every error is loss the
method is responsible for. The product suite is where the bound bites.

*Artefact:* `data/processed/product-grid.rds`, producer
`scripts/run-product-grid.R`, which self-checks that no method beat the bound.

**Word budget.** §3 loses the third family and gains two negative results, about
even. §5 goes 450 → 1,100. Chapter total 3,000 → **3,650**.

### `09-ground-truth-evaluation.Rmd` · `{#evaluation}` · 4,400 w · 6 figs · 13 chunks · 17 cites

> *Your embedding looks good. Is it correct?*

The largest and most-cited chapter. **Restructured** per `PROJECT_CONCEPT.md`
Claim A: the stress result has moved to Chapter 2 as a theorem, and what remains
is the part that is genuinely not entailed.

| Section | Words |
|:--|--:|
| What "correct" means here | 400 |
| The headline metric: normalised Procrustes RMSE | 450 |
| The four metrics under audit | 400 |
| Three reference geometries | 350 |
| **The known-answer test** | 650 |
| Why the obvious fix fails | 350 |
| How optimistic, and in what units | 600 |
| Four metrics, one number | 450 |
| Does k change the answer? | 250 |
| What to report when you have no answer key | 350 |
| What this chapter does not settle | 150 |

---

**Pilot run 2026-08-31, before a word of this chapter was drafted.**
`scripts/run-evaluator-audit.R --pilot`, 3 θ × k ∈ {5, 10, 20, 40} × n ∈ {400,
800} × 20 seeds on `miura_ori(6, 6)`, handing each evaluator the exact chart as a
candidate against a two-component PCA of the folded cloud. `ROADMAP.md` item 1.4
and risk R1. **The chapter survives, and its claim has to change.**

*The inversion exists.* Ambient-referenced continuity ranks the exact unfolding
below PCA, and the rate is a clean monotone function of both k and θ — at k = 5
it essentially never happens, at k = 40 it is certain at every θ tested, and at
fixed k it rises with θ. That is the quantitative law the chapter was budgeted
for, and it was never observable on the accordion pleat this claim originally
came from.

*The margin is negligible, and that is the stronger finding.* Continuity's
preference for PCA never exceeds 0.003 — two orders of magnitude below the book's
own reportable difference — while the two candidates' reconstruction errors are
0.000 and 0.108. The claim the numbers support is not "the evaluator prefers a
wrong embedding by X". It is that **continuity cannot distinguish a perfect
embedding from a plainly wrong one at all**, and reports both as excellent. Write
that, not the weaker version.

*Optimism is not uniform across the four metrics, and the chapter's structure
should follow that rather than a single law.* At n = 800, kNN preservation and
$Q_{NX}$ rank the exact chart first, by margins that clear the reportable
difference in a third to a half of cells; trustworthiness is inert either way,
moving by 1e-4; continuity is the one that inverts. §7 "How optimistic, and in
what units" therefore cannot be one number, and §8 "Four metrics, one number"
is the wrong title for what is there — four metrics, four different answers.

*The reference geometry dominates the metric.* Graph-referenced results are
identical to ambient-referenced ones to three decimals on every metric, and
chart-referenced results **never invert, at any k, θ or n**. §4 "Three reference
geometries" is where the chapter's real content is, and §5's known-answer test is
what makes it visible. The law to state is which question each evaluator is
answering, not a correction factor to apply.

*And a sample-size caveat that must not be buried.* The rank metrics' inversions
are largely a small-sample effect — at n = 400 kNN inverts on 30% of cells, at
n = 800 on 3%. Continuity's is not: it holds at 44% at n = 800. Any figure in
this chapter that pools over n is reporting two different phenomena as one.

**Budget: unchanged at 4,400.** The risk register allowed for re-budgeting this
chapter down if the pilot came back empty. It did not.

**The first paragraph must position against Machado et al. 2025 explicitly:**
*they show a bad embedding scores high, which needs no ground truth; this book
shows the right embedding scores low, which cannot be done without it.* That is a
real complement and it survives review — but only if said first. Lause et al. 2024
must be cited where the "disagreement has migrated to the evaluators" framing
appears, because that is their published position, not this book's.

The contribution is the **threshold law**: rank-based metrics are invariant to
monotone contraction until neighbour *identity* changes, so they invert only above
$\theta \approx 0.8$ while stress inverts everywhere. Locate and characterise that
threshold as a function of $(\theta, k, n)$, and show its coincidence with Chapter
5's analytic short-circuit onset.

**Be honest that optimism is a band, not a number.** Three distortions with
essentially identical true error (0.390, 0.387, 0.454 normalised RMSE) produced
trustworthiness 0.874, 0.993 and 0.995.

*Hard gate.* $A(k)$, the trustworthiness/continuity normalising constant, must be
**transcribed from Kaski et al. 2003** before a word is drafted (S1-4). Every
number in this chapter depends on it and it has so far only been written from
memory.

### `10-benchmark-results.Rmd` · `{#results}` · 2,700 w · 5 figs · 12 chunks · 11 cites

> *Which method survives — and can the benchmark tell?*

| Section | Anchor | Words |
|:--|:--|--:|
| What this chapter answers | `results-question` | 180 |
| Setup | `results-setup` | 100 |
| What the grid holds | `results-background` | 250 |
| Where the benchmark has resolving power | `results-core` | 600 |
| Results | `results-results` | 500 |
| Diagnostics | `results-diagnostics` | 300 |
| Where it fails | `results-limits` | 250 |
| **The pre-registered selection rule** | `results-rule` | 300 |
| Reproduce this | `results-reproduce` | 120 |
| Further reading | `results-reading` | 100 |

`results-core` is the honest core: report $R(\theta) < 1$ where it holds.

`results-rule` fixes **the pre-registered selection rule for Chapter 12** and
must be committed before any Chapter 12 fit (S1-11).

**It is committed, and it is code.** `R/selection.R` holds `select_method()`, a
total function of the grid's columns registered before the grid it reads has ever
been generated. Prose can be read generously afterwards; a function cannot. Its
three thresholds are fixed there and nowhere else — the 0.02 reportability
threshold `PROJECT_CONCEPT.md` already pre-registers, a 0.90 run-rate floor
because a method Chapter 12 cannot fit is not a candidate, and a resolving-power
floor of 1 below which the rule **declines** and the chapter reports a null
result. `tests/testthat/test-selection.R` demonstrates that each of the three
changes the decision, and that raising the seed count does not buy one: $R$ is a
ratio of two spreads and neither is a standard error, so more seeds estimate both
more precisely and move the ratio nowhere. That is the specific abuse the risk
note below names, closed rather than warned about.

The rule is referred to by its **anchor**, never by a section number. Three
places in this repository gave it three different numbers — the numbering is what
moves when a section is added, and the anchor is what a cross-reference resolves
against.

*Risks.* The informative window may be narrow — every method near-exact at
$\theta = 0.2$, every method at the floor at $\theta = 1.4$. **The temptation on
discovering $R < 1$ will be to raise the seed count until something separates.
That is p-hacking with a different knob and the plan forbids it**; the seed budget
is set in advance (S2-3) and reported.

*Artefact schema.* LONG form with an explicit `status` column, plus a provenance
block: repo SHA, `R/` SHA, run date, package versions. `run-benchmark-grid.R` must
**stop sourcing `_common.R`** — that file ends with `write_bib()` (S0-5).

### `11-versus-swiss-roll.Rmd` · `{#comparison}` · 3,000 w · 4 figs · 9 chunks · 11 cites

**Respecified 2026-08-26. The previous specification was the pre-E1 design: it
asked whether the rankings flip and whether the families collapse onto one
curve, and the committed artefacts answer no to both. Drafting from it would
have produced a chapter whose sections have no content.**

This chapter is E1 written up, and E1 went against the book. That makes it the
most interesting chapter in the volume, not the most awkward one, provided it is
written as a measurement rather than a defence.

| Section | Anchor | Words |
|:--|:--|--:|
| What this chapter answers | `comp-question` | 180 |
| Setup | `comp-setup` | 60 |
| Background | `comp-background` | 500 |
| Difficulty has two axes, not one | `comp-core` | 900 |
| Results | `comp-results` | 700 |
| Diagnostics | `comp-diagnostics` | 300 |
| Where it fails | `comp-limits` | 250 |
| Reproduce this | `comp-reproduce` | 60 |
| Further reading | `comp-reading` | 190 |

**`comp-core` — why a $\theta$-only sweep cannot answer the question.** Folding a
crease pattern raises branch separation *and* lifts the sheet out of the plane,
together. At $g/s \approx 21$ a Miura is a flat plane that PCA recovers with error
0.000; a Swiss roll at the same separation is still curved and PCA scores 0.403.
The families' ranges of ambient non-planarity are disjoint — crease 0.000–0.056,
Swiss roll 0.101–0.126 — so over the original design there is no setting at which
they are comparable. The chapter shows the two-axis plane with both families on
it and the empty overlap; that figure is the argument.

Then the fix: cell count, not $\theta$, is what moves non-planarity. Sweeping
$(n_x, \alpha, \theta)$ creates the overlap.

**`comp-results` — the finding.** At matched difficulty on both axes, crease
patterns are *easier*, and the Swiss roll separates PCA from Isomap five times
better: spread 0.574 against 0.113. PCA scores 0.922 against Isomap's 0.348 on a
Swiss roll — the textbook result, and the right one — against 0.286 and 0.183 on
creases, where PCA nearly matches Isomap because a folded Miura is still close to
planar.

State the conclusion in the book's own voice: **crease patterns are not a harder
benchmark; they are an easier one that discriminates less.** The contribution is
exact truth, not difficulty, and Chapters 8 and 9 are where that pays.

Arm B belongs here too: at matched $g/s$, error is flat in crease count.

**`comp-diagnostics` — the robustness check, and why it is in the chapter rather
than a footnote.** E1's decisive arm sampled with `boundary = TRUE`, where chart
distance is a lower bound on the geodesic for pairs straddling a tooth — an
answer key that would penalise the geodesic method specifically, which is the
very comparison being made. Measured: 0.00–4.31% of pairs, and the ratio
*strengthens* 5.1× → 5.5× as the affected settings are dropped. A reader is
entitled to ask this question and the chapter should answer it before they do.

**`comp-limits`.** The overlap is a corner: nine crease settings, three methods,
two metrics. And under $Q_{NX}$ Isomap scores 0.773 on creases against 0.778 on
Swiss rolls — for the neighbourhood metric the families very nearly *do* collapse,
and the whole difference sits in how badly the linear methods fail, which is a
fact about ambient non-planarity rather than about creases. Say so.

**Also state what the pre-registration got wrong.** `PLAN.md` pre-drafted three
outcomes and none occurred: the families neither collapsed nor separated in the
registered sense, which was *different rankings* — the ranking is identical in
both. The replacement claim was adopted because it fits the evidence, not because
its antecedent was met. Recording that is what pre-registration is for.

*Artefacts:* `data/processed/e1-difficulty.rds`, `e1-controlled.rds`,
`e1-armB.rds`. Producer: `scripts/experiment-e1.R`. All committed with provenance.

*Risk.* The temptation is to soften this into "both benchmarks have their place".
They do — but the measurement is that one of them discriminates five times better
and the chapter must say the number before it says the moral.

## Part IV — Application

### `12-benchmark-to-decision.Rmd` · `{#application}` · 3,000 w · 4 figs · 9 chunks · 15 cites

> *What happens when the data are real?*

| Section | Words |
|:--|--:|
| The rule, fixed in advance | 400 |
| The dataset, and the partial truth it carries | 450 |
| What "wins" means when there is no answer key | 500 |
| The head-to-head | 450 |
| The result, reported under the rule | 400 |
| What the benchmark licenses, and what it does not | 400 |
| Reporting standards | 300 |
| Close | 100 |

**Four decisions gate this chapter** and each is now an S1 item: dataset (S1-8),
redistribution licence (S1-9), label provenance (S1-10), pre-registered selection
rule (S1-11).

*The chapter keeps its null-result promise only if the selection rule and the
decision criterion both predate the result.* Applied retroactively it is not a
pre-registration and the promise must be withdrawn rather than quietly weakened.

*Risks.* There is no answer key on real data, so "win" is a construct and the
conclusion is only as good as it. If the cell-type labels were themselves derived
from a clustering on one of the embeddings under test, the evaluation is
**circular** — S1-10 exists to catch that. Preprocessing choices can dominate
method choice entirely; fix them identically across arms.

### `13-conclusion.Rmd` — new · 700 w

Closes on what Chapter 9 established and what it did not. Add to
`_bookdown.yml` and `vgwort_pixels.csv`.

---

## Back matter

### `A1-notation.Rmd` · `{#notation}` · 1,100 w · 7 cites

No opening question — appendices in this book carry none, and adding one breaks
the reference-material register. Sections: how to read this appendix (150),
Greek (200), Latin and sets (200), distances/operators/metrics (250),
abbreviations (100), code conventions (200).

**Carries the $\theta$ correction**, and needs a row disambiguating the fold angle
from `Rtsne`'s Barnes–Hut $\theta$ parameter — a genuine collision.

### `A2-datasets.Rmd` · `{#datasets}` · 1,400 w · 4 chunks · 3 cites

Generated data (450), precomputed results (500), external data (350). Documents
all nine artefacts with their provenance blocks, plus $n = 800$ and the $\theta$
grid as part of the difficulty specification. Closes the standing single-cell TODO
via S1-8.

### `90-glossary.Rmd` · 1,800 w · 15 cites

**Preserve `# Glossary {-}` with NO `{#anchor}` — verified.**
`scripts/render-chapter-pdfs.R` derives each output filename with the regex
`\{#[^}]+\}`, so adding an anchor to an unnumbered heading yields the slug
`glossary -` or `glossary .unnumbered` and the chapter PDF 404s. The bare `{-}`
produces `glossary.html` via the title-slug fallback, matching the existing
`vgwort_pixels.csv` row. **Cross-reference the glossary by link text, never by
`\@ref()`.**

Origami and folding terms (800 w); manifold-learning and evaluation terms (900 w).
Carries the $\theta$ correction.

### `98-citing-this-guide.Rmd` — new · ~150 w

Both siblings ship one. Gives `boxempty` its only call site (S1-7). Generate
`citation.ris` from `CITATION.cff`; add a `vgwort_pixels.csv` row.

---

## `R/` — eleven files

| File | Holds | First needed |
|:--|:--|:--|
| `artefacts.R` | `read_run()`, `write_run()`, `provenance()`, `run_digest()` | Ch 4 |
| `baselines.R` | `swiss_roll()`, `s_curve()`, `severed_sphere()`, `short_circuit_index()`, `non_planarity()` | Ch 11 |
| `constants.R` | seeds, $\theta$ grid, $n$, palette option "C" | Ch 3 |
| `constructions.R` | product, lift, irreducible-loss bound | Ch 8 |
| `figure-export.R` | geometry for the interactive figure, with isometry asserted | Ch 1 |
| `folding.R` | `fold()`, ambient embedding, `crease_assignment()`, `branch_gap()`, `facet_gap()` | Ch 2 |
| `methods.R` | the embedding registry — eight methods, plus the autoencoder declared unavailable | Ch 4 |
| `metrics.R` | Procrustes RMSE, $Q_{NX}$, T/C/kNN, `reference_dist()`, `metric_floor()` | Ch 4 |
| `patterns.R` | `miura_ori()`; `yoshimura()` builds but does not fold, `waterbomb()` stops | Ch 2 |
| `plotting.R` | crease-pattern and embedding plots | Ch 2 |
| `sampling.R` | `sample_manifold()`, noise models, `boundary=` | Ch 3 |

One file per concern, sourced alphabetically, so **no file may depend on another
at source time** — only at call time.

## Artefacts — nine

`benchmark-grid` · `part2-sweeps` · `evaluator-audit` · `metric-calibration` ·
`classic-grid` · `autoencoder-grid` · `autoencoder-example` ·
`autoencoder-decoder-lattice` · processed single-cell matrix.

S2-2 merges `evaluator-audit` and `metric-calibration` into one script — they
share every cell and every distance matrix, so computing them separately doubles
the Dijkstra cost for nothing.

All are committed and read; none is generated in CI. **All nine are blocked on the
`.gitignore` fix (S0-1).**


---

## Re-budget, 2026-08-26

The word total was set before E1 and E2 and was never revisited. Padding a book
to hit a number chosen before it knew what it was about is exactly the failure
this project keeps catching in smaller forms, so the budget is restated against
what each chapter now has to say.

| Chapter | Was | Now | Why |
|:--|--:|--:|:--|
| 1 Introduction | 2,200 | 2,400 | must now concede that the Swiss roll discriminates better, and say what the contribution actually is |
| 2 Geometry of folding | 3,400 | **3,900** | gains the contraction's numerical floor, the boundary caveat, and a diagnostics section built on two real failures |
| 3 Generative model | 3,200 | **2,500** | was three pattern families; it is one. The variety it was going to display no longer exists |
| 4 Linear projections | 2,400 | 2,400 | unchanged in size, changed in argument: the PCA/MDS coincidence is the result |
| 5 Geodesic methods | 3,000 | 3,000 | unchanged — `facet_gap()` now exists, so the analytic onset it promised is reachable |
| 6 Neighbour embeddings | 2,800 | 2,800 | unchanged |
| 7 Autoencoders | 2,200 | **1,600** | at risk: no implementation, no artefact, out of the main grid. Budget the chapter it can honestly be |
| 8 Building benchmarks | 3,000 | **3,650** | §5 grows from 450 words to the book's spine; §3 trades a family for two negative results |
| 9 Ground truth and evaluators | 4,400 | 4,400 | unchanged, and still the largest — Claim A is the book's novel contribution |
| 10 Benchmark results | 3,400 | **2,700** | one pattern rather than three, 1,200 cells rather than 2,700, and a floor column that is zero by construction |
| 11 Versus the Swiss roll | 2,600 | **3,000** | the finding went against the book, which takes more care to write than a confirmation would |
| 12 Benchmark to decision | 3,000 | 3,000 | unchanged |
| 13 Conclusion | 500 | 700 | has two refutations and two withdrawals to account for |
| Front and back matter | ~5,620 | ~5,620 | unchanged |
| **Total** (sum of the rows above) | **41,720** | **41,670** | net −50 |

**What this is and is not.** It is a redistribution, and reading the columns says
so: two chapters grew by 1,550 words between them and they are the ones carrying
the results that survived, while what shrank is the material that assumed variety
the geometry does not provide (Chapter 3), a grid that is now a third smaller
(Chapter 10), and a chapter with no implementation behind it (Chapter 7). The two
movements very nearly cancel.

It is **not** a reduction in the size of the book, and the paragraph that used to
stand here described one. The arithmetic was never done: `~36,700` stood in this
file, in `PLAN.md` twice and in `PROJECT_CONCEPT.md`, and was the sum of nothing.

**Chapter 7 is the one to watch.** It has no implementation, no artefact, no
script, and `torch` is deliberately uninstalled. It is budgeted at 1,600 words on
the assumption that it becomes a worked example with its own small artefacts
rather than a full method chapter. If it slips again, the honest move is to cut
it and say why in Chapter 13 — the book already carries two withdrawals and is
stronger for both.
