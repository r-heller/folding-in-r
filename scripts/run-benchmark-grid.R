#!/usr/bin/env Rscript
#
# Chapter 10 benchmark grid: method x pattern x theta x noise, over BENCH_SEEDS.
#
# @artefact data/processed/benchmark-grid.rds
#
# NOT run in CI and not run at render time -- the full grid takes hours. Run it
# locally, commit the .rds, and keep this script as the provenance record for
# how that file was produced. If the grid is regenerated, note the date and the
# commit SHA of R/ in GENERATION_LOG.md.
#
# Usage:  Rscript scripts/run-benchmark-grid.R [--quick]
#         --quick  runs a small grid for smoke-testing the pipeline

# The helpers are plain scripts in R/, not a package — source them the same way
# _common.R does. Run this script from the repository root.
for (f in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) source(f)

quick <- "--quick" %in% commandArgs(trailingOnly = TRUE)

source("_common.R")   # BENCH_SEEDS, N_SEEDS

# No waterbomb row. PLAN.md E2's hard rule: no PATTERNS entry may exist for a
# pattern that cannot be built, because a grid row that silently fails is worse
# than a missing one. Whether the waterbomb tessellation admits a one-parameter
# rigid folding is an open question, not a coding task -- waterbomb() stops with
# a message saying so, and this list will gain a third row if and only if that
# question is answered yes.
# One family. The waterbomb has no certified folding (E2); the Yoshimura has
# two, and each leaves a crease family flat, which makes the folded object a
# parallelogram tessellation rather than a diamond one (PLAN.md R1-1). The rule
# is the same in both cases: no entry here for a pattern that cannot be built.
PATTERNS <- list(
  miura = function() miura_ori(6, 6)
)

# THETA_GRID comes from R/constants.R: theta is the fraction of the way to the
# flat-folded state, on [0, 1], not the [0, 1.4] this script used to sweep --
# see the note there and in R/folding.R.
THETA <- if (quick) c(0, 0.5) else THETA_GRID
NOISE <- list(
  none    = list(type = "none",    sd = 0),
  ambient = list(type = "ambient", sd = 0.02),
  outlier = list(type = "outlier", sd = 0.05)
)
SEEDS <- if (quick) BENCH_SEEDS[1:2] else BENCH_SEEDS
N     <- if (quick) 150L else 800L

# The methods come from R/methods.R, which is the single registry Chapters 4
# to 7 all describe. Adding one there adds it here.
METHODS <- names(METHOD_REGISTRY)

STARTED <- Sys.time()

# One cell, factored out of the loop.
#
# Three things move with it. The two rank matrices behind trust, cont, knn and
# qnx were being rebuilt from scratch by each of the four metric functions --
# .rank_matrix() at n = 800 costs 0.20 s against 0.017 s for a whole Procrustes
# fit, so four calls per method per cell was most of the metric budget.
# rank_metrics() does one pass for all four and was written for exactly this,
# and had no caller anywhere. Measured at n = 800 over four values of k: 5.85 s
# of separate calls against 0.44 s.
#
# irreducible_loss() moves out of the method loop too: it is a property of the
# sample and does not know a method exists, so computing it nine times per cell
# was computing it eight times too often.
#
# And the two k's are named constants rather than a literal 10 in three call
# sites and a literal 20 in a fourth. They mean different things and are asked
# against different reference geometries -- see R/constants.R, where that is now
# written down, and the row records both.
one_cell <- function(pat, pname, th, nname, seed) {
  m  <- sample_manifold(pat, theta = th, n = N, noise = NOISE[[nname]], seed = seed)
  dA <- reference_dist(m, "ambient")
  dU <- reference_dist(m, "chart")
  fl <- irreducible_loss(m, EMBED_DIM)

  do.call(rbind, lapply(METHODS, function(mname) {
    spec <- METHOD_REGISTRY[[mname]]
    # Stochastic methods are seeded per fit and never left to inherit position
    # in the RNG stream: umap::umap does not advance it, so a loop that seeds
    # once collapses every replicate onto one answer.
    sd  <- if (isTRUE(spec$stochastic)) seed else NULL

    # A failed fit used to record nothing but ran = FALSE, and three different
    # causes collapsed into one indistinguishable state: the method declared
    # itself unavailable, the method returned NULL by design, or the method
    # threw. `status` names which, and `reason` carries conditionMessage()
    # rather than discarding it. The is.null(emb) contract is untouched --
    # every consumer still reads `ran`.
    err <- NULL
    emb <- tryCatch(embed(mname, m, seed = sd),
                    error = function(e) { err <<- conditionMessage(e); NULL })
    status <- if (!is.null(err)) "error"
              else if (is.null(emb)) {
                if (!is.null(spec$unavailable)) "unavailable" else "declined"
              } else "ok"
    reason <- if (!is.null(err)) sub("\n.*", "", err)
              else if (status == "unavailable") spec$unavailable
              else if (status == "declined")
                "the method returned NULL on this cell; see R/methods.R"
              else NA_character_
    na <- is.null(emb)

    # Two passes, not one, and not four. Trust, continuity and kNN preservation
    # are asked against AMBIENT distance at K_DEFAULT; Q_NX is asked against the
    # CHART at K_QNX. That is what this grid has always done and what nothing
    # had ever written down -- see R/constants.R. Unifying them would have been
    # a silent change to what the headline column means.
    rk_a <- if (na) NULL else rank_metrics(dA, emb, k = K_DEFAULT)
    rk_u <- if (na) NULL else rank_metrics(dU, emb, k = K_QNX)

    data.frame(
      pattern = pname, theta = th, noise = nname,
      seed = seed, method = mname, consumes = spec$consumes,
      ran = !na,
      status = status,
      reason = reason,
      # The k Isomap actually used, which is not always the k it was asked for
      # -- a disconnected graph is repaired by raising k, and the artefact
      # records that rather than only warning about it.
      k_effective = if (na) NA_integer_ else
        (attr(emb, "k_effective") %||% NA_integer_),
      # Anything else a method had to change about its own settings in order to
      # run at all -- a widened diffusion bandwidth, say. NA means it ran as
      # asked.
      tuning = if (na) NA_character_ else (attr(emb, "tuning") %||% NA_character_),
      # The two k's and the two reference geometries, in the row that used them.
      k_tck = K_DEFAULT, ref_tck = "ambient",
      k_qnx = K_QNX,     ref_qnx = "chart",
      rmse  = if (na) NA_real_ else reconstruction_error(emb, m$truth),
      qnx   = if (na) NA_real_ else rk_u$qnx,
      trust = if (na) NA_real_ else rk_a$trust,
      cont  = if (na) NA_real_ else rk_a$cont,
      knn   = if (na) NA_real_ else rk_a$knn,
      # Reported against the floor, not against zero. E1 made this the book's
      # spine: an error of 0.31 says little, an error of 0.31 against a floor of
      # 0.30 says the method is at the limit of what the data permit.
      floor = fl,
      stringsAsFactors = FALSE
    )
  }))
}

rows <- list()
for (pname in names(PATTERNS)) {
  pat <- PATTERNS[[pname]]()
  for (th in THETA) for (nname in names(NOISE)) for (seed in SEEDS) {
    rows[[length(rows) + 1L]] <- one_cell(pat, pname, th, nname, seed)
  }
  message("done: ", pname)
}

grid <- do.call(rbind, rows)

# A --quick run writes to its own file and is gitignored. It smoke-tests the
# pipeline on a handful of cells; it is not the grid the chapters read, and
# giving it the same name as the real artefact is how a book ends up reporting
# two seeds as twenty. The provenance convention only works if the committed
# file can only ever have come from a full run.
# Written as one expression: at top level R closes the `if` at the newline and
# then meets a bare `else`, which is a syntax error rather than a warning.
out <- if (quick) "data/processed/benchmark-grid-quick.rds" else
  "data/processed/benchmark-grid.rds"

write_run(grid, out,
          quick    = quick,
          patterns = names(PATTERNS),
          thetas   = THETA,
          noise    = names(NOISE),
          seeds    = SEEDS,
          n        = N,
          k_tck    = K_DEFAULT, ref_tck = "ambient",
          k_qnx    = K_QNX,     ref_qnx = "chart",
          embed_dim = EMBED_DIM,
          methods  = METHODS,
          started  = STARTED)

# What could not be fitted, and why -- printed rather than buried in a column
# nobody reads. Three causes used to collapse into one indistinguishable state.
bad <- grid[!grid$ran, ]
if (nrow(bad)) {
  cat("\n", nrow(bad), " of ", nrow(grid), " fits did not run:\n", sep = "")
  print(stats::aggregate(seed ~ method + status + reason, data = bad,
                         FUN = length), row.names = FALSE)
} else {
  cat("\nevery fit ran.\n")
}
