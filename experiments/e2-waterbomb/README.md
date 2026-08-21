# E2 — does the waterbomb tessellation fold?

**Verdict: it folds, but only under an imposed symmetry — and it is not usable
as a benchmark row as it stands.**

This is the third of the three outcomes `PLAN.md` E2 pre-drafted, plus a
qualification that none of the three anticipated. The scripts here are the
evidence, kept rather than deleted because Chapter 8 §3 is already titled
*"Three pattern families, and one honest gap"* and this is the gap.

## What was asked

A degree-6 vertex with sectors (45, 45, 90, 45, 45, 90) satisfies Kawasaki and
is therefore flat-foldable **as an isolated vertex**. That does not imply the
*tessellation* admits a one-parameter rigid folding. `PLAN.md` E2 says: attempt
it, and an honest negative is the successful outcome if that is what the
mathematics says.

## What was found

**The patch is not rigid.** A 5×5-cell patch has V = 61 vertices, E = 150 bars,
90 facets, χ = 1 (a disk). All 31 interior vertices carry the named signature.
Generic degrees of freedom: 3V − 6 − E = 27.

**The obvious first-order count is worthless, and this is the trap.** At the
flat state every *z* column of the Jacobian is identically zero, so rank(J) =
119 = 2V − 3 — the rank of the purely two-dimensional framework — and the
non-trivial flex count comes out at V − 3 = 58 for *any* planar pattern
whatsoever. A first-order flex at the flat state is not evidence of folding.
The second-order test and a finite continuation are what decide.

**Second order does not obstruct.** The 31 self-stresses give 31 quadratic
conditions on the 58 heights; no definite combination was found in 300 random
draws, and a common real zero was found with max |Q(w)| = 2.9 × 10⁻¹⁷.

**Continuation moves and stays rigid.** 25 of 25 predictor-corrector steps held
every bar length to better than 10⁻¹⁰; worst bar-length error 7.8 × 10⁻¹⁶.

**Uniformity alone is not enough.** Requiring every cell to fold identically
leaves a 2-dimensional variety, not a one-parameter folding. Imposing the
pattern's vertical mirror as well — equal fold angle on the two diagonal
families — leaves exactly one degree of freedom.

**The branch has a closed form, found numerically rather than assumed:**

```
tan(rho_horizontal / 2) = -tan(rho_diagonal / 2) / sqrt(2)
```

Max deviation of the ratio from −1/√2 over 155 points in t ∈ [0.02, 3.10]:
1.7 × 10⁻¹⁵. Substituted directly, with no solving, vertex closure residual
≤ 7.8 × 10⁻¹⁶.

**Cross-checked by an independent route.** A developing-map reconstruction,
which never touches the bar framework, reproduces the configuration to
4.2 × 10⁻¹⁵ over θ ∈ [0, 1.5]; worst bar-length error 3.8 × 10⁻¹⁵; dihedral
angles read back off the coordinates agree to 6.0 × 10⁻¹⁵. Two known-answer
vertex controls run through the same code and reproduce their published folding
dimensions.

## Why it is still not a benchmark row

Three things, any one of which is disqualifying on its own.

1. **Embedding is not proved.** Clearance between facets sharing no vertex
   falls from 0.486 at θ = 0.8 to 0.026 at θ = 0.9, measured on a
   15-point-per-facet sample that detects contact rather than excluding it. A
   self-intersecting surface makes every ambient-metric method in Part II a
   measurement of nothing. An exact triangle–triangle test is needed before any
   θ above roughly 0.8 is sampled.

2. **θ is not a difficulty axis here.** Fold amplitude on a 5×5 patch rises to
   max |z| = 3.875 at θ = 0.4 and then *falls* to 2.939 at θ = 1.0: the sheet
   curls into a bowl and tightens rather than opening further. Neither the
   folding nor `g/s` is monotone, so the pattern cannot share the difficulty
   axis the other two families use without re-parameterisation.

3. **θ does not determine the configuration.** The finite patch keeps 27
   degrees of freedom after θ is fixed, nearly all of them on the free
   boundary. `fold()` would return the symmetric uniform branch; the physical
   object is not pinned down by θ alone near the edge. §8.3 must say so rather
   than let a reader infer otherwise.

## Two decisions the book still owes

**Which pattern "waterbomb" means.** Two readings were built. The one analysed
is the three-line arrangement at 0°/45°/135° in which *every* vertex is the
degree-6 vertex `PLAN.md` names. The other also creases the vertical grid lines
and has degree-8 corners and degree-4 midline vertices; it was built, analysed
and set aside because only one of its three vertex types matches. If the book
means that one, this analysis has to be redone — its uniform folding variety
has a different branch structure.

**Whether the classical alternating fold is wanted.** Only the fully uniform
one-cell-period folding was characterised. Period-2 supercells, where an
alternating magic-ball fold would live, were surveyed only on the rejected
variant.

## Consequence for the book

`R/patterns.R::waterbomb()` stops with an error, and
`scripts/run-benchmark-grid.R` has no waterbomb row. That is `PLAN.md` E2's
hard rule — no `PATTERNS` entry for a pattern that cannot be built, because a
grid row that silently fails is worse than a missing one — and it stands: what
was demonstrated is that a folding *exists* under stated symmetry, not that the
resulting family is a usable benchmark instance.

The book therefore ships **two pattern families plus this documented result**,
which §8.3 was already framed to absorb. That is a better chapter than one
which quietly dropped a pattern, and a considerably better one than a chapter
whose third family was silently self-intersecting.

## Note for anyone reading the scripts

They use ρ = 0 at the flat sheet. `R/README.md` and the glossary use ρ = π at
the flat sheet, which is the correct convention for a dihedral angle. The
conversion is `dihedral = pi - rho_spike`, verified here to 6.0 × 10⁻¹⁵ against
the reconstructed coordinates.
