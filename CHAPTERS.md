# CHAPTERS.md — Folding in R

Per-chapter specification for the full twelve-chapter book. **41,070 words, 53
figures, 145 code chunks, ~60 citations** — plus a new 500-word `13-conclusion.Rmd`
and a 150-word `98-citing-this-guide.Rmd`, giving a book total of **~41,720
words**.

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

### `01-introduction.Rmd` · `{#intro}` · 2,200 w · 1 fig · 4 chunks · 8 cites

> *Why should a crease pattern tell you anything about a gene expression matrix?*
> — **preserve verbatim.** The best of the twelve opening questions.

| Section | Anchor | Words |
|:--|:--|--:|
| What this chapter answers | `intro-question` | 170 |
| The answer key | `intro-answer-key` | 500 |
| The argument this book joins | `intro-argument` | 550 |
| What is claimed, and what is not | `intro-claims` | 450 |
| How the book is organised | `intro-roadmap` | 350 |
| Further reading | `intro-reading` | 180 |

`intro-claims` is where the **category-error concession** lands: only Isomap and
the answer key claim what the headline metric measures; t-SNE, UMAP, LLE and
autoencoders never claim isometry recovery, and scoring them against isometric
truth and reporting they lose is a category error unless said so first.

**Draft this chapter LAST of Part I.** Every instinct says the introduction comes
first; it must not. `intro-argument` forward-references Chapter 9's headline
finding, which does not exist until `evaluator-audit.rds` does.

*Risks.* Over-claiming in `intro-argument` — the scope-limit paragraph is load
bearing, not a courtesy. `fig-01-answer-key` is doing a great deal of work and may
collapse into four cramped panels; split it if it does not read at 9 cm.

### `02-folding-geometry.Rmd` · `{#folding-geometry}` · 3,400 w · 4 figs · 9 chunks · 13 cites

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
2,700 grid cells were spent demonstrating a definition.

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

### `03-generative-model.Rmd` · `{#generative}` · 3,200 w · 5 figs · 11 chunks · 9 cites

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

### `05-geodesic-methods.Rmd` · `{#geodesic}` · 3,000 w · 5 figs · 15 chunks · 10 cites

> *If the data lie on a folded sheet, how do you flatten it back out?*

**The chapter where the book's premise is satisfied exactly.** Isomap consumes
geodesics; a crease pattern gives them in closed form. Extra slot beyond the
contract: *When does the graph bridge?* (520 w), which pairs the analytic
short-circuit onset with the measured one.

*Needs new mathematics.* `facet_gap(pattern, theta)` — exact minimum ambient
distance between non-adjacent facets, a convex-polygon-to-convex-polygon distance
in $\mathbb{R}^3$. This is genuinely new code for this repository and could stall
the chapter. **Test it against a brute-force dense minimum over sampled facet
points at coarse $\theta$**, where brute force is affordable and unambiguous.

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

### `07-autoencoders.Rmd` · `{#autoencoders}` · 2,200 w · 4 figs · 14 chunks · 6 cites

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

### `08-building-benchmarks.Rmd` · `{#benchmarks}` · 3,000 w · 5 figs · 13 chunks · 16 cites

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

### `10-benchmark-results.Rmd` · `{#results}` · 3,400 w · 5 figs · 12 chunks · 11 cites

> *Which method survives — and can the benchmark tell?*

§3 *Where the benchmark has resolving power* (600 w) is the honest core: report
$R(\theta) < 1$ where it holds. §8 fixes **the pre-registered selection rule for
Chapter 12** and must be committed before any Chapter 12 fit (S1-11).

*Risks.* The informative window may be narrow — every method near-exact at
$\theta = 0.2$, every method at the floor at $\theta = 1.4$. **The temptation on
discovering $R < 1$ will be to raise the seed count until something separates.
That is p-hacking with a different knob and the plan forbids it**; the seed budget
is set in advance (S2-3) and reported.

*Artefact schema.* LONG form with an explicit `status` column, plus a provenance
block: repo SHA, `R/` SHA, run date, package versions. `run-benchmark-grid.R` must
**stop sourcing `_common.R`** — that file ends with `write_bib()` (S0-5).

### `11-versus-swiss-roll.Rmd` · `{#comparison}` · 2,600 w · 3 figs · 8 chunks · 9 cites

> *Does the new benchmark actually add anything?*

**This chapter is E1 written up**, and E1 runs first (`PLAN.md` D1). §4 *A shared
difficulty coordinate* and §5 *Do the rankings flip?* are the experiment; if they
collapse onto one curve, the book's Claim C changes before 41,000 words are
committed to defending it.

§1 *A concession, first* (400 w) — and note this concession **contradicts the
natural reading of the preface**. If `index.Rmd` is not tightened (P3/P4 above),
an attentive reader catches it.

§2 restates the arc-length point correctly: the customary Swiss-roll answer key is
not the isometric one — **a defect noted before and corrected in the Euler
Isometric Swiss Roll** — and here is how large it is: 0.807 normalised Procrustes
against 0.999 for a random embedding. Quantification of a known problem is
respectable; claiming the problem is not.

*Needs* `R/baselines.R` (a ninth R file): `swiss_roll()` with arc-length truth,
`s_curve()`, `severed_sphere()`, and `classic-grid.rds` produced by the same grid
script under a `--suite classic` flag so the code path is shared.

---

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

### `13-conclusion.Rmd` — new · ~500 w

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

## `R/` — nine files

`R/README.md`'s planned layout covers six. Three more are required by the chapter
specs and must be added to it:

| File | Holds | First needed |
|:--|:--|:--|
| `constants.R` | seeds, $\theta$ grid, $n$, palette option "C" | Ch 3 |
| `patterns.R` | `miura_ori()`, `yoshimura()`, `waterbomb()` | Ch 2 |
| `folding.R` | `fold()`, ambient embedding, `facet_gap()` | Ch 2 |
| `sampling.R` | `sample_manifold()`, noise models, `boundary=` | Ch 3 |
| `constructions.R` | product, lift, irreducible-loss bound | Ch 8 |
| `metrics.R` | Procrustes RMSE, $Q_{NX}$, T/C/kNN, `reference_dist()`, `metric_floor()` | Ch 4 |
| **`methods.R`** | the embedding registry — nine methods | Ch 4 |
| **`baselines.R`** | `swiss_roll()`, `s_curve()`, `severed_sphere()` | Ch 11 |
| `plotting.R` | crease-pattern and embedding plots | Ch 2 |

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
