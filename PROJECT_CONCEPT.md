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
ambient contraction for every $\theta > 0$. This was verified in closed form to
$1.06\times10^{-15}$.

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
   `scripts/run-benchmark-grid.R` already sweeps it over $[0, 1.4]$, which is not
   a dihedral range. Define it once, as the parameter of the folding map, and
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

### Claim B — the irreducible-loss bound **(strongest available, currently buried)**

The product construction gives "here is the exact smallest error any 2-D
embedding of this dataset could possibly achieve." No existing benchmark can
compute that number. It speaks directly to Chari & Pachter's actual complaint
about unavoidable distortion, and — decisively — **it does not depend on creases
being special**, so it survives every objection to Claim C.

Currently one subsection of Chapter 8. **Promote it.** It is the book's spine.

Report every result against this bound rather than against zero, so the hard end
of the range stops being "everything failed" and becomes "the best achievable
error here is $X$ and every method achieves $0.98X$" — a substantive finding
about a regime rather than a shrug.

### Claim C — "crease patterns are a better benchmark" **(unsupported; gated on E1)**

This is the claim the book currently leads with, and the book's own numbers
undercut it. Short-circuit fraction is exactly **0.00** at $\theta = 0.0, 0.2,
0.4, 0.6, 0.8$; the transition is confined to $[0.9, 1.4]$. But piecewise
flatness, curvature on the 1-skeleton and zero reach are all fully present at
$\theta = 0.001$ where nothing measurable happens, and unchanged at $\theta =
1.4$ where all of it happens. **A property constant across the entire phenomenon
cannot be its cause.**

What does vary and does track difficulty is $g/s$ — gap-to-spacing — falling
monotonically 21.8 → 4.2. That is exactly the ratio Balasubramanian & Schwartz
identified for Isomap's topological instability, and exactly what tightening a
Swiss roll's turn count varies.

So Claim C is **not yet supported by anything in the plan**, and the experiment
that would decide it currently sits in chapter 11 of 12. It runs first instead.
See `PLAN.md` E1.

---

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
53 figures, 145 code chunks, ~60 citations, 9 committed artefacts**, three
pattern families, and 60–100 h of compute across two or three grid generations.
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
  × 3 noise × 20 seeds = 2,700 cells). Chapter 7's autoencoder row plausibly
  dominates everything else at a measured 9.27 s per fit. Chapter 9's two audit
  artefacts multiply every cell by 3 reference geometries — one of which needs an
  all-pairs Dijkstra, i.e. Isomap's cost again — × 4 values of $k$.
- **Two grid generations minimum.** Every number currently in hand was measured on
  a rigid accordion-fold stand-in, not on a Miura. All of it must be re-measured.

### Three patterns, and one honest gap

Miura and Yoshimura are **derived and numerically verified**. Miura: all six
pairwise facet distances preserved to $<10^{-12}$ for $\alpha \in [20°, 85°]$,
$\theta \in [0, \pi/2]$, reducing exactly to the flat sheet at $\theta = 0$, and
satisfying an independent identity not built into the derivation (major-crease
dihedral exactly $2\theta$). Yoshimura: edge error $<10^{-15}$, and the ring
closes at $\theta = \pi/2$ giving a perfect short-circuit — ambient distance 0
against true geodesic 6.0. The literature's negative result about Yoshimura
concerns the closed **cylinder**, where circumferential closure kills the
mechanism; a finite planar patch is a different object.

**Waterbomb is unresolved, and this is mathematics rather than scheduling.** No
closed-form rigid folding could be certified. The degree-6 vertex with sectors
(45, 45, 90, 45, 45, 90) satisfies Kawasaki, so it is flat-foldable as an
*isolated vertex* — that does not imply the *tessellation* admits a one-parameter
rigid folding without imposing extra symmetry. Do not assert one.

E2 attempts it by bar-and-joint continuation with a documented fallback. Chapter
8 §3 is already titled *"Three pattern families, and one honest gap"*, which is
the right posture: if waterbomb does not fold, the chapter ships **two families
plus a documented negative result**, and that is a better chapter than one that
quietly drops a pattern. What must not happen is a `PATTERNS` entry in
`run-benchmark-grid.R` that cannot be built.

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
