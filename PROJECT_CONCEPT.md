# PROJECT_CONCEPT.md — Folding in R

What this book claims, what it does not, and every decision that a later reader
would otherwise have to reverse-engineer from the sources.

Companion to `PLAN.md`, which sequences the work. Where the two disagree,
`PLAN.md` is the schedule and this file is the reason.

---

## The thesis, stated at the right resolution

The preface is correct and stays. It is stated one level too coarsely, and that
coarseness is the single most consequential thing to fix before any chapter is
written.

A rigid folding of a flat sheet is an isometry of the **intrinsic** (path)
metric. It is emphatically **not** an isometry of the ambient metric: for a
symmetric pair of points across a crease of dihedral angle $\rho$, the ratio of
ambient to geodesic distance is exactly $\sin(\rho/2)$ — folding is a strict
ambient contraction for every $\theta > 0$.

Re-derived and re-checked here rather than carried over: over 360 configurations
spanning $\rho \in (0, \pi]$ and varying both the distance from the crease and
the position along it, $|d_A/d_U - \sin(\rho/2)|$ has a maximum of
$1.11\times10^{-16}$ — one unit in the last place. The ratio depends on $\rho$
alone, which is the substance of the claim; it is not an approximation that
degrades with distance.

**The strictness has a numerical floor, and the book should say so.** Since
$1 - \sin(\rho/2) \approx (\pi-\rho)^2/8$, the contraction falls below machine
epsilon while the fold angle is still far above it: it stops being representable
in double precision below a fold angle of about $3\times10^{-8}$ rad, against an
analytic prediction of $\sqrt{8\varepsilon/2} = 2.98\times10^{-8}$. Two
consequences.

- A test asserting "ambient distance is strictly less than chart distance for
  every $\theta > 0$" is false as stated in floating point. It must be qualified
  by the grid: the book's smallest non-zero $\theta$ is far above the floor, and
  the test should say that rather than pretend the general statement holds.
- It sharpens the Claim C argument below. At $\theta = 0.001$ the contraction is
  of order $10^{-7}$ *relative* — genuinely present, and roughly seven orders of
  magnitude below anything a rank- or distance-based metric on $n = 800$ sampled
  points can resolve. "The geometry is fully present where nothing measurable
  happens" is not hand-waving; it is quantifiable, and quantifying it is a
  better paragraph than asserting it.

That distinction is the whole book:

- **Isomap** consumes geodesics. Its assumption is satisfied *exactly* on a
  crease pattern. It is the only method in Part II that claims what the answer
  key measures.
- **PCA, MDS, t-SNE, UMAP, autoencoders** consume ambient distances. They are
  being scored against a target they never consume.

Scoring t-SNE against isometric truth and reporting that it loses is not a
finding about t-SNE. It is a category error dressed as a measurement. The book
must say this in Chapter 1, in its own voice, before a reader says it first.

**Consequence for the metric design.** The book reports **two** headline numbers
per cell, not one, and says in Chapter 1 that this is deliberate:

1. **Normalised Procrustes RMSE** — the isometry-recovery score. Permits
   translation, rotation, reflection, isotropic scale.
2. **Truth-referenced co-ranking $Q_{NX}(K)$** — computed with the exact chart as
   reference geometry. Invariant under any diffeomorphism of the plane, so it is
   neutral between distance-preservation and neighbourhood-preservation.

The **gap between them, as a function of $\theta$**, is a measurement of how much
observed "error" is genuine structural loss versus harmless reparameterisation.
That gap is the actual content of the Chari–Pachter dispute, expressed as a
curve. Reporting only (1) would build the book's scoring function out of one
side of the dispute it claims to arbitrate.

---

## Three sentences already committed are wrong

Fix these before drafting. All three are in files that render today.

1. **`02-folding-geometry.Rmd`** — the outline says curvature is "concentrated at
   vertices". False, and self-defeating. A folded flat sheet has vertex angle
   sums of exactly $2\pi$; discrete Gaussian curvature is identically **zero**.
   If curvature were concentrated at vertices the isometry claim would collapse.
   The correct statement: the **extrinsic** second fundamental form is a measure
   supported on the creases, and consequently the **reach is exactly zero**.

2. **`02-folding-geometry.Rmd`** — "real data manifolds have creases too", stated
   unhedged as the chapter's closing beat. No evidence is offered and the
   literature points elsewhere: work on non-manifold structure in single-cell
   data finds **stratification** (regions of differing intrinsic dimension,
   branch points, singular loci), not creases. A crease is a codimension-1
   concentration of *extrinsic* curvature on an object of *constant* intrinsic
   dimension admitting a global isometric planar chart. Stratified data has
   neither. **Cut the sentence** rather than hedge it — a hedged version still
   invites the quote.

   The transfer argument that replaces it is the **disqualification argument**: a
   method that fails where an exact answer exists has no claim on a problem where
   none does. That is a necessary-condition test, it is honest, and it asserts
   nothing about biology.

3. **`90-glossary.Rmd`** and `A1-notation.Rmd` — $\theta$ is defined as "the
   dihedral angle at a crease. Runs from 0 (flat sheet)". A crease dihedral angle
   in a flat sheet is $\pi$, not 0. $\theta$ is the **folding parameter**, and
   `scripts/run-benchmark-grid.R` swept it over $[0, 1.4]$, which is neither
   a dihedral range nor a legal parameter range — it is now the fraction of the
   way to flat-folded, on $[0, 1]$ (`R/folding.R`). Define it once, as the parameter of the folding map, and
   derive the dihedral angle from it.

---

## Claim ledger

The book makes three claims. They are not equally defensible and the plan ranks
them accordingly.

### Claim A — the false-negative audit **(novel, keep, promote)**

Hand a metric the exact isometric chart as a *candidate embedding* and ask
whether it recognises it. This requires exact ground truth and therefore cannot
be done on any existing benchmark.

Already demonstrated on a rigid accordion-fold stand-in: at fold angle 1.0 rad,
ambient-referenced Kruskal stress ranks the exact truth at **0.188** against
**0.022** for a plainly wrong embedding (2-component PCA of the folded cloud), in
**10 of 10 seeds** at every fold angle from 0.4 to 1.4. Substituting estimated
geodesics does not fix it.

**But split it.** The stress half is a *theorem*, not a finding: ambient-referenced
stress measures reproduction of $d_A$; Chapter 2 proves $d_A < d_U$ strictly for
every $\theta>0$; two-component PCA is the least-squares-optimal linear
approximant to that same ambient configuration. So `stress(truth) > stress(PCA)`
follows in one line with no simulation. **Move it to Chapter 2 as a proposition
with a one-line proof.** It is stronger as a theorem and spends no compute.

What remains in Chapter 9 is genuinely not entailed: the **rank-based** metrics
(trustworthiness, continuity, kNN-preservation) are invariant to a monotone
contraction of distances until neighbour *identity* changes — which is why the
probe found them inverting only above $\theta \approx 0.8$ while stress inverts
everywhere. The contribution is a **quantitative law**: the location and sharpness
of the inversion threshold as a function of $(\theta, k, n)$, and its coincidence
with the short-circuit onset predicted analytically in Chapter 5. Nobody has
drawn that curve and it needs exact truth to draw.

### Claim B — the irreducible-loss bound **(the spine, after E1)**

The product construction gives "here is the exact smallest error any 2-D
embedding of this dataset could possibly achieve." No existing benchmark can
compute that number. It speaks directly to Chari & Pachter's actual complaint
about unavoidable distortion, and it does not depend on creases being special,
so it survived E1 intact while Claim C did not.

**Two things it needs before Chapters 1, 8 and 11 can be drafted.**

**(i) An artefact where the bound is not zero.** The floor for a $p$-dimensional
chart embedded in $d$ dimensions is the tail of the chart's spectrum, so on the
main grid — a 2-D chart embedded in 2-D — it is **identically zero in every
cell**. Claim B's operative instruction, *report every result against the floor*,
therefore cannot be executed on the book's own grid. The product construction is
what makes it positive: `product_manifold()` at intrinsic dimension 4 forced
into 2-D gives a floor around 0.61–0.66 depending on the factors. That needs to
be a numbered artefact with its own suite, and the main grid should either drop
the `floor` column or say in Chapter 10 that it is zero by construction — which
is itself worth one sentence, because it means every error on that grid is loss
the method is responsible for.

**(ii) A differentiator that survives the book's own baseline.** "Exact ground
truth" does not distinguish a crease pattern from an arc-length-charted Swiss
roll. `R/baselines.R` ships exactly that, with `isometric = TRUE` as the default,
and it is published prior art (Schoeneman et al. 2017). It supports an evaluator
audit and a floor just as well. Claiming exactness as the differentiator would
be a plausible-but-wrong claim of precisely the kind this project keeps getting
caught by.

What a crease pattern has that the Euler Swiss roll does not:

- **Zero reach and a non-smooth answer key.** The Swiss roll is a smooth
  developable surface with positive reach; every manifold-learning guarantee
  that assumes smoothness applies to it. A creased sheet has reach exactly zero,
  so it sits outside that theory rather than at its edge. This is the honest
  differentiator and the book measures it.
- **Intrinsic dimension above two, still in closed form.** Products of crease
  patterns raise intrinsic dimension while keeping the chart exact. A Swiss roll
  is 2-D and stays 2-D. This is what makes (i) possible at all, and it is why
  the product construction is load-bearing rather than decorative.
- **A difficulty parameter with a computable critical value**, rather than one
  found by sweeping and looking.

The chapters must argue from those, not from exactness alone.

### Claim C — "crease patterns are a better benchmark" **(REFUTED by E1, retired)**

Kept rather than deleted. A claim that failed is a result, and this one is the
reason the book has the spine it now has.

E1 ran on 2026-08-22. Evidence in `data/processed/e1-*.rds`, method in
`scripts/experiment-e1.R`, decision recorded in `GENERATION_LOG.md` Phase 15.

**The experiment as this plan specified it could not have answered the
question.** Arm A sweeps $\theta$ alone, and folding a crease pattern raises
branch separation *and* lifts the sheet out of the plane at the same time. At
$g/s \approx 21$ a Miura is a flat plane that PCA recovers with error 0.000,
while a Swiss roll at the same separation is still curved and PCA scores 0.403.
The two families' ranges of ambient non-planarity are **disjoint** — crease
0.000–0.056, Swiss roll 0.101–0.126 — so across arm A's whole design there is no
setting at which they are comparable. Arm A reports a family term at
$F = 1203$, $p < 2\times10^{-16}$, and that number is about the confound.

**Arm A2 fixed the design.** $\theta$ is not the important knob; *cell count*
dominates non-planarity. Sweeping $(n_x, \alpha, \theta)$ creates the overlap
arm A lacked. The family effect survives control for both axes — and crease
patterns come out **easier**.

**Arm A3 asks what a benchmark is for.** A benchmark earns its keep by telling
methods apart, so the statistic is the spread across methods within a cell at
matched difficulty: **Swiss roll 0.574, crease patterns 0.113**. The Swiss roll
separates PCA from Isomap five times better. At matched difficulty PCA scores
0.922 against Isomap's 0.348 on a Swiss roll — the textbook result, and the
right one, since Isomap consumes geodesics and PCA does not — against 0.286 and
0.183 on creases, where PCA does nearly as well because a folded Miura is still
close to planar.

Crease patterns are not a harder benchmark. They are an easier one that
discriminates less.

**Arm B**: at matched $g/s$, error is flat in crease count. Crease count does
nothing.

**Caveats that travel with this.** The overlap is a specific corner — nine
crease settings, 2×2 to 4×4 Miura at large $\alpha$ and $\theta \in [0.70,
0.95]$. Three methods, two metrics. And under $Q_{NX}$ Isomap scores 0.773 on
creases against 0.778 on Swiss rolls, so for the neighbourhood metric the
families very nearly *do* collapse, and the whole difference sits in how badly
the linear methods fail — a fact about ambient non-planarity rather than about
creases.

**What E1's pre-registration got wrong.** `PLAN.md` pre-drafted three outcomes
and none occurred. The families neither collapsed nor "separated" in the sense
registered, which was *different rankings*; the ranking is identical in both
families. What happened was a fourth thing: they separate, in the opposite
direction, with less method discrimination. The replacement claim from outcome 2
is adopted because it fits the evidence, not because its antecedent was met, and
saying so is the whole point of pre-registering.

### The difficulty axis is two-dimensional, not one

$g/s$ alone is not it, and every place this document previously implied
otherwise was wrong. Difficulty here has at least two axes — branch separation
**and** ambient non-planarity — and a $\theta$-only sweep moves both together,
which is what made arm A uninterpretable. Any comparison across families must
control both, and because $g$ is a property of the surface while $s$ falls as
$n^{-1/2}$, $g/s$ grows as $\sqrt{n}$: comparisons are only meaningful at fixed
$n$.

## Prior work the book must cite before drafting

`book.bib` holds nine entries and **zero** dimension-reduction evaluation
literature. The book intends to contribute to a field it does not cite. Three
items are direct antecedents and an uncited direct antecedent is the fastest
available desk reject.

- **Machado, Behrisch & Telea (2025)**, *Necessary but not Sufficient:
  Limitations of Projection Quality Metrics*, Computer Graphics Forum 44(3),
  `10.1111/cgf.70101`. **Verified.** Generates adversarial projections scoring
  high on trustworthiness and continuity while showing patterns unrelated to the
  data; released the code.

  This is the false-*positive* direction and it is scooped. The complement is
  real and must be stated in Chapter 9's first paragraph: *they show a bad
  embedding scores high, which needs no ground truth; this book shows the right
  embedding scores low, which cannot be done without it.*

- **Lause, Berens & Kobak (2024)**, *The art of seeing the elephant in the room:
  2D embeddings of single-cell data do make sense*, PLOS Comp Biol,
  `10.1371/journal.pcbi.1012403`. **Verified.** Concludes Chari & Pachter's
  result rested on metrics that "focused on preservation of distances, where 2D
  PCA was unsurprisingly the best."

  That is the book's planned headline result, already published, about this exact
  dispute. The book's "third position" — that the disagreement has migrated from
  the embeddings to the evaluators — **is the published position of one of the two
  parties.** Cite it as such and claim the increment, not the position.

- **The Euler Isometric Swiss Roll.** **Verified, and the citation corrected.**
  It is not the title of a paper. It is a *dataset* proposed inside
  Schoeneman, Mahapatra, Chandola, Napp & Zola, *Error Metrics for Learning
  Reliable Manifolds from Streaming Data*, SDM 2017, pp. 750–758,
  `10.1137/1.9781611974973.84` (arXiv `1611.04067`). The second arXiv ID this
  file previously listed as a co-primary, `1804.08833`, is Mahapatra &
  Chandola, *Learning Manifolds from Non-stationary Streaming Data* — it only
  *uses* the dataset, citing the first as its reference [30]. Cite the SDM
  paper as the primary and the second only if the streaming context is
  relevant.

  Their construction and their stated reason for it are worth separating. They
  replace $\hat{x}(t) = \alpha t\cos\beta t$, $\hat{y}(t) = \alpha t\sin\beta t$
  with the Fresnel integrals $x(t) = \int_0^t \sin(s^2)\,ds$,
  $y(t) = \int_0^t \cos(s^2)\,ds$, and justify it by the Euler spiral having
  "curvature proportional to the distance from the origin", giving "constant
  angular acceleration along the curve thus ensuring that isometry is
  preserved". The construction is right; the reason is not quite. What makes it
  isometric is that the Fresnel parameterisation is **unit speed** —
  $|(x'(t), y'(t))| = 1$ — so $t$ *is* arc length. Chapter 11 can say that in
  one line, and it should, because it is checkable and the paper's own
  phrasing is not.

  Either way, Chapter 11's "genuine technical contribution" — that the
  customary Swiss-roll answer key is not the isometric one — is a **known**
  defect, already corrected.

  Restate as quantification, which is respectable and safe: *"a defect noted
  before and corrected in the Euler Isometric Swiss Roll — and here is how large
  it is: 0.807 normalised Procrustes, against 0.999 for a random embedding."*

Also add before Chapter 9: Lee & Verleysen (co-ranking), Espadoto et al. 2021,
Kruskal 1964, Balasubramanian & Schwartz 2002.

---

## Parked citations — resolved

Two of the three UNVERIFIED entries are now resolved and may be written.

- **Trustworthiness and continuity do not come from one paper.** Venna & Kaski
  (ICANN 2001, `10.1007/3-540-44668-0_68` — *Neighborhood Preservation in
  Nonlinear Projection Methods: An Experimental Study*) propose trustworthiness
  alone. **Kaski et al. (BMC Bioinformatics 4:48, 2003,
  `10.1186/1471-2105-4-48`) is where both measures appear with their scaling.**
  Venna & Kaski (Neural Networks 19(6–7):889–899, 2006,
  `10.1016/j.neunet.2006.05.014`) is *Local multidimensional scaling* — a
  method paper that uses the pair, not a paper about the measures; cite it for
  the tradeoff framing and not as their definition. **Chapter 9's primary is
  `kaski2003trustworthiness`**, with 2001 for priority.

  **$A(k)$ is transcribed and it was right.** Verbatim from the paper's section
  *Measuring trustworthiness and detecting genes for which the visualization is
  suspect*: "where $A(k) = 2/(Nk(2N-3k-1))$ scales the values between zero and
  one." Equations (3) and (4):

  $$M_1(k) = 1 - A(k)\sum_{i=1}^{N}\sum_{x_j \in U_k(x_i)}\big(r(x_i,x_j) - k\big)$$
  $$M_2(k) = 1 - A(k)\sum_{i=1}^{N}\sum_{x_j \in V_k(x_i)}\big(\hat{r}(x_i,x_j) - k\big)$$

  with $r$ the rank in the **original** space, $\hat{r}$ the rank in the
  **display**, $U_k(x_i)$ the points in the display neighbourhood but not the
  original (trustworthiness, $M_1$), and $V_k(x_i)$ the points in the original
  neighbourhood but not the display (continuity, $M_2$). Ties are handled by
  averaging over all compatible rank orders.

  One caveat the book must carry, because the authors state it and most
  re-implementations drop it: $A(k)$ is a *scaling*, not a proven worst-case
  bound. The paper says "the worst attainable values of $M_1$ may, at least in
  principle, vary with $k$, and were estimated in Figures 2 and 3 with random
  projections and with random neighborhoods." So a value slightly below zero is
  not necessarily a bug, and Chapter 9 should say so rather than clamping.

- **Miura's report number is 618, and the record URL is now pinned.** Koryo
  Miura, *Method of Packaging and Deployment of Large Membranes in Space*, The
  Institute of Space and Astronautical Science report **618**, pp. 1–9,
  December 1985. No DOI was ever assigned. The identifier
  `verify-citations.R` checks is the JAXA repository record,
  <https://jaxa.repo.nii.ac.jp/records/31382>; CiNii carries the same record at
  CRID `1050003824960950144`, which is where the volume and page range come
  from. Note that *any* record id on that host returns 200, so "it returns 200"
  is not on its own evidence that the URL is the right one — this one was
  checked by reading the record.

  The ISSN previously recorded here (0285-6808) is **not** confirmed and is
  dropped rather than carried; the entry does not need it.

  Miura's own abstract is worth quoting in Chapter 3, because he frames the
  construction exactly as this book does: the result "represents the isometric
  transfer of an infinite plane subject to biaxial shortening", giving "the
  concave polyhedral surface … composed of a repetition of a fundamental
  region, which is further composed of four congruent parallelograms."

- **Maekawa/Kawasaki primaries stay parked.** Kawasaki (1989, 1OSME Ferrara) has
  no resolvable identifier; Justin (1986, *British Origami* 118) is a society
  magazine with no DOI; Murata (1966) has no scan or resolver record. Hull's
  *Origametry* is already verified in the bib and is the honest citation until a
  primary resolves. Say in the text that the attribution history is tangled —
  that is true and more interesting than a fake primary.

**The normalising constant $A(k)$ has been transcribed from Kaski et al. 2003**
and is recorded above with both equations. It agrees with what had been written
from memory — but it was checked, and that is the difference between a gate and
a hope.

---

## Scope

### The full twelve-chapter book

Twelve body chapters in four parts, plus front and back matter: **41,070 words,
53 figures, 145 code chunks, ~60 citations, 9 committed artefacts**, one verified pattern family, and 60–100 h of compute across two or three grid generations.
Chapter-by-chapter specification is in `CHAPTERS.md`.

This is the ambitious version and it was chosen deliberately over a scoped
alternative. What that costs is recorded here so it is not rediscovered later as
a surprise:

- **Prose density.** 2,750 words per body chapter against `scientometrics-in-r`'s
  889 — the largest completed sibling. Unlike the siblings, every paragraph here
  is gated on a computed number, so the drafting burst that produced those books
  in a day does not transfer. Prose cannot outrun the grid.
- **Compute.** ~11.4 h single-core for the main grid alone (measured: 15.2 s per
  fit of nine non-torch methods plus metrics at $n=800$; 3 patterns × 15 $\theta$
  × 3 noise × 20 seeds = 1,200 cells). Chapter 7's autoencoder row plausibly
  dominates everything else at a measured 9.27 s per fit. Chapter 9's two audit
  artefacts multiply every cell by 3 reference geometries — one of which needs an
  all-pairs Dijkstra, i.e. Isomap's cost again — × 4 values of $k$.
- **Two grid generations minimum.** Every number currently in hand was measured on
  a rigid accordion-fold stand-in, not on a Miura. All of it must be re-measured.

### One verified pattern, and two honest gaps

**Miura is derived and numerically verified.** All pairwise facet distances
preserved to $<10^{-15}$ across $\alpha \in [20°, 85°]$ and the whole $\theta$
sweep, reducing exactly to the flat sheet at $\theta = 0$, and satisfying an
independently derived closed form for the major-crease dihedral that was not
built into the construction (agreement $3.6\times10^{-15}$). Its mountain/valley
assignment is derived from the folded dihedral, and Maekawa's theorem then holds
at every interior vertex as a consequence rather than as an input.

**Yoshimura is withdrawn** (2026-08-26). The implementation that shipped was an
accordion pleat: the horizontal creases folded and every diagonal sat at
$\rho = \pi$. Two corrected foldings were derived, and *each leaves one of the
three crease families flat* — which makes the folded object a parallelogram
tessellation rather than a diamond one, a Miura wearing this pattern's crease
lines. Shipping it as a second independent family would have claimed a variety
the geometry does not support.

**Waterbomb is withdrawn** (E2). It folds, but only under an imposed symmetry,
and three things disqualify it as a grid row: the embedding is unproved (facet
clearance falls to 0.026 at $\theta = 0.9$), fold amplitude is not monotone in
$\theta$, and $\theta$ does not determine the configuration — 27 degrees of
freedom remain on the free boundary.

So Chapter 8 §3 ships **one family and two documented negative results**. That is
a smaller chapter than planned and a true one, and §3's existing title — "Three
pattern families, and one honest gap" — needs to become "One pattern family, and
two honest gaps".

**What the two withdrawals have in common is the lesson.** An isometry test
cannot tell a fold from a pleat, because a pleat *is* a rigid folding. A
first-order flex at the flat state proves nothing, because at the flat state
every $z$ column of the Jacobian vanishes for *any* planar pattern. Both traps
were sprung and both were caught by a second, independent check — Maekawa on
derived labels in one case, a second-order test and finite continuation in the
other.

### What this book is not

Unchanged from the preface, and still correct: not rigidity theory, not
computational origami design, not deep generative modelling, not a tutorial on
project tooling.

Added: **not an arbitration of the Chari–Pachter dispute.** The defensible claim
is narrower — the book measures how far each evaluator sits from the
truth-referenced evaluator. That is a statement about metrics and requires no
position on what embeddings are for.

---

## Standing decisions

- **No companion package.** Executed in Phase 11 (see `GENERATION_LOG.md`). The
  helpers live in `R/` as plain scripts sourced by `_common.R`; `foldbench` was
  never published and the book described an install step no reader could perform.
  Helpers are versioned with the chapters that use them, at the same commit.

- **One section contract, nine slots, namespaced anchors.** The drafted plan
  contained three mutually incompatible contracts. The nine-slot anchored form
  wins because it is the only one that survives pandoc id-collision across 12
  chapters. Fixed in `00-how-to-use.Rmd` before any chapter is drafted, and
  enforced by `scripts/lint-chapters.R`.

- **`eval = TRUE`.** Inherited `eval = FALSE` from methods-in-r, which is
  defensible in a lookup reference of static recipes and indefensible in a book
  whose stated contribution is measured reconstruction error. Flips when the
  first chapter goes live, in the same commit that moves `write_bib()` out of
  `_common.R`.

- **Numbers come from `` `r ` `` expressions, never typed.** Roughly forty
  stand-in numbers from the accordion-fold probe are sitting in the drafted
  plan text ready to transcribe. `scripts/lint-chapters.R` fails the build on any
  bare decimal in prose outside an inline expression. This is the
  anti-fabrication gate and the most valuable line in that file.

- **Seeds are budgeted, not uniform.** Twenty-everywhere is a convention
  inherited from the sibling volumes, not a design derived from this book's
  effect sizes. Standing rule 1 sets a floor of 20; the plan spends *more* where
  the pre-registered 0.02 reportability threshold requires it, and the floor
  everywhere else.
