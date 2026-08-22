# Values shared by every chapter, script and test.
#
# Values only. Nothing in this file is computed from a helper and nothing in it
# calls one. R/ is sourced alphabetically and constants.R sorts first, so a
# source-time call into folding.R or patterns.R would be exactly the dependency
# R/README.md forbids -- and the failure would be an ordering accident, visible
# only when someone renamed a file.
#
# N_SEEDS and BENCH_SEEDS are deliberately absent. They are defined in
# _common.R, which is what scripts/run-benchmark-grid.R sources to get them. A
# second copy here would be a second seed vector, free to drift from the one
# the committed grid was computed under, and standing rule 1 in
# 00-how-to-use.Rmd promises the reader those are the seeds. Reference them
# from _common.R; do not redefine them.

# ── The folding parameter ────────────────────────────────────────────────────
# theta parameterises the folding map. It is not a dihedral angle: the dihedral
# angle of a crease in a flat sheet is pi, not 0. The glossary and A1-notation
# now say so, and PROJECT_CONCEPT.md records the earlier draft getting it wrong.

# The sweep scripts/run-benchmark-grid.R runs.
#
# theta is a FRACTION OF THE WAY TO FLAT-FOLDED, on [0, 1]. It is not an angle,
# and the inherited [0, 1.4] was neither: a Miura with acute angle alpha folds
# flat at corrugation angle alpha, so for alpha = pi/3 the sheet is already
# fully collapsed at 1.047 and everything past it is undefined. R/folding.R
# derives that bound; fold() now rejects anything outside [0, 1].
#
# Normalising also makes the families comparable. Miura and Yoshimura reach
# their flat-folded states at different dihedral angles, so equal theta means
# "equally far through the fold" rather than "equal angle", which is the
# comparison Chapter 11 and E1 actually need.
#
# The sweep stops at 0.95 rather than 1: at theta = 1 the sheet has zero
# extent in one direction, every method is embedding a degenerate object, and
# the cell measures nothing. Past that point the pattern is a different object,
# not a harder instance of the same one, and a difficulty axis that crosses it
# is not one axis.
THETA_GRID <- seq(0, 0.95, by = 0.05)

# The reduced sweep for figures. Indexed out of THETA_GRID rather than written
# as five literals so that a coarse panel always lands on cells the committed
# grid actually holds -- these values are join keys against
# data/processed/benchmark-grid.rds, not decorations, and a literal that missed
# by one ulp would join to nothing.
#
# Five values spanning the sweep: flat, three interior, and the last cell before
# degeneracy. What this constant encodes is the bracketing, not the numbers --
# where the interesting transition sits is exactly what E1 is being run to find
# out, and the accordion-fold probe that suggested the old bracketing was
# measured on a stand-in that no longer exists.
THETA_COARSE <- THETA_GRID[c(1L, 6L, 11L, 16L, 20L)]

# ── Sample sizes ─────────────────────────────────────────────────────────────

# The budget. At n = 800 an all-pairs distance matrix is 640,000 doubles, or
# 5.1 MB, which is nothing; the binding cost is time, and PROJECT_CONCEPT.md
# records 15.2 s per cell for nine non-torch methods plus metrics at this n
# against a 2,700-cell grid. Raising it is a decision about the grid's
# wall-clock, not about a plot.
N_DEFAULT <- 800L

# What --quick passes in scripts/run-benchmark-grid.R. Enough points that every
# method actually fits and every metric is defined, few enough that the whole
# pipeline runs in seconds. It exists to smoke-test the plumbing; no number
# reported in the book may come from a run at this n.
N_QUICK <- 150L

# ── Pattern geometry ─────────────────────────────────────────────────────────

# Default tessellation size per family: the sizes scripts/run-benchmark-grid.R
# builds. Crease count is a difficulty knob in its own right and PLAN.md E1's
# second arm varies it deliberately -- a 3x3 against a 12x12 Miura at matched
# gap-to-spacing -- so this is the default, not the only size a chapter asks
# for.
#
# waterbomb is listed because this is a size, not a promise that the pattern
# folds. PLAN.md E2 decides that. The hard rule is on run-benchmark-grid.R's
# PATTERNS list, which must not name a pattern that cannot be built.
PATTERN_GRID <- list(
  miura     = c(nx = 6L, ny = 6L),
  yoshimura = c(nx = 6L, ny = 6L),
  waterbomb = c(nx = 6L, ny = 6L)
)

# Miura's opening angle alpha, in radians. This is the range R/README.md
# invariant 1 asserts facet isometry over -- 20 to 85 degrees -- so a test that
# sweeps alpha sweeps this and nothing wider. Widening it is a claim about the
# derivation that has to be verified before it is written here.
MIURA_ALPHA_RANGE <- c(20, 85) * pi / 180

# ── Embedding and neighbourhood ──────────────────────────────────────────────

# Every embedding in this book is two-dimensional, because the chart is
# two-dimensional and the whole comparison is against it. A 3-D embedding of a
# 3-D cloud would score well and measure nothing.
EMBED_DIM <- 2L

# The neighbourhood size the rank metrics use. scripts/run-benchmark-grid.R
# already calls trustworthiness(), continuity() and knn_preservation() at
# k = 10; naming it once is what stops those three call sites from drifting
# apart. Chapter 9 sweeps k instead of fixing it -- there k is the independent
# variable in the inversion-threshold law, not a setting.
K_DEFAULT <- 10L

# ── Palette and crease encoding ──────────────────────────────────────────────

# One viridis option per volume, so figures from different books stay separable
# when they sit side by side. _common.R records the assignment: strategy-in-r
# "D", scientometrics-in-r "A", this book "C" (plasma).
#
# Named here as well as there because tests/testthat/setup.R sources R/ without
# _common.R. A drawing helper that reached into _common.R for the option would
# be untestable, and the tests are the only thing that runs these functions
# outside a render.
BOOK_VIRIDIS_OPTION <- "C"

# Crease assignment, encoded once for the whole book. Standing rule 3 in
# 00-how-to-use.Rmd and the glossary entry for mountain/valley both commit to
# it: no result encoded by colour alone, so linetype carries the same
# distinction and the three vectors below are always applied together.
#
# The linetypes are the origami convention rather than a fresh choice -- valley
# dashed, mountain dash-dot, sheet edge solid -- so a reader who has seen a
# crease diagram before does not have to learn this book's dialect. Hull's
# Origametry, already verified in book.bib, is the reference.
#
# The two fold colours are viridis::viridis(2, option = "C", begin = 0.12,
# end = 0.70), the book's own ramp read at its dark and warm ends. Boundary is
# grey because it is not a fold: it is where the sheet stops.
CREASE_COLOUR   <- c(M = "#4A03A1",  V = "#F1844B", B = "grey55")
CREASE_LINETYPE <- c(M = "4212",     V = "22",      B = "solid")
CREASE_LABEL    <- c(M = "mountain", V = "valley",  B = "boundary")

# ── Tolerances ───────────────────────────────────────────────────────────────

# Every tolerance the tests use, in one place, so that changing what this book
# calls "preserved" is a one-line edit with a visible diff rather than a search
# for scattered literals.
#
# 1e-10 is the contract stated in R/README.md. The five kinematic invariants --
# facet isometry, flatness at theta = 0, the independent identity, strict
# ambient contraction, and sampled points lying on the folded surface -- are the
# same class of claim about the same closed-form arithmetic, so they share one
# number and it is written once. They are named separately anyway because a
# test reading TOL$contraction says what it is asserting; a test reading 1e-10
# says nothing.
#
# Nothing else in this file is a tolerance. If a metric needs one, it belongs
# here too, with the measurement that justified it.
TOL <- local({
  kinematics <- 1e-10
  list(
    isometry    = kinematics,
    flat        = kinematics,
    identity    = kinematics,
    contraction = kinematics,
    on_surface  = kinematics,
    # For everything that is not kinematics -- metric identities, Procrustes
    # round-trips -- testthat's own default, sqrt(.Machine$double.eps), which
    # is 1.490116e-08 on IEEE doubles. Named so that a test still never has to
    # write a bare number, and so that a deliberate loosening shows up in a
    # diff of this file.
    default     = sqrt(.Machine$double.eps)
  )
})

# The fold angle the Chapter 1 figure is drawn at, in the formats that cannot
# be turned. Far enough into the fold that facets genuinely occlude each other,
# short of the range where the sheet starts closing on itself.
FIG_INTRO_THETA <- 0.65
