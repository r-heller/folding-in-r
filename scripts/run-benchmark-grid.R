#!/usr/bin/env Rscript
#
# Chapter 10 benchmark grid: method x pattern x theta x noise, over
# BENCH_SEEDS. Writes data/processed/benchmark-grid.rds.
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
PATTERNS <- list(
  miura     = function() miura_ori(6, 6),
  yoshimura = function() yoshimura(6, 6)
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

rows <- list()
for (pname in names(PATTERNS)) {
  pat <- PATTERNS[[pname]]()
  for (th in THETA) {
    for (nname in names(NOISE)) {
      for (seed in SEEDS) {
        m <- sample_manifold(pat, theta = th, n = N,
                             noise = NOISE[[nname]], seed = seed)
        dA <- reference_dist(m, "ambient")
        for (mname in METHODS) {
          spec <- METHOD_REGISTRY[[mname]]
          # Stochastic methods are seeded per fit and never left to inherit
          # position in the RNG stream: umap::umap does not advance it, so a
          # loop that seeds once collapses every replicate onto one answer.
          sd  <- if (isTRUE(spec$stochastic)) seed else NULL
          emb <- tryCatch(embed(mname, m, seed = sd),
                          error = function(e) NULL)
          na <- is.null(emb)
          rows[[length(rows) + 1L]] <- data.frame(
            pattern = pname, theta = th, noise = nname,
            seed = seed, method = mname, consumes = spec$consumes,
            ran = !na,
            # The k Isomap actually used, which is not always the k it was
            # asked for -- a disconnected graph is repaired by raising k, and
            # the artefact records that rather than only warning about it.
            k_effective = if (na) NA_integer_ else
              (attr(emb, "k_effective") %||% NA_integer_),
            # Anything else a method had to change about its own settings in
            # order to run at all -- a widened diffusion bandwidth, say. NA
            # means it ran as asked.
            tuning = if (na) NA_character_ else
              (attr(emb, "tuning") %||% NA_character_),
            rmse  = if (na) NA_real_ else reconstruction_error(emb, m$truth),
            qnx   = if (na) NA_real_ else qnx(emb, m$truth, K = 20L),
            trust = if (na) NA_real_ else trustworthiness(dA, emb, k = 10L),
            cont  = if (na) NA_real_ else continuity(dA, emb, k = 10L),
            knn   = if (na) NA_real_ else knn_preservation(dA, emb, k = 10L),
            # Reported against the floor, not against zero. E1 made this the
            # book's spine: an error of 0.31 says little, an error of 0.31
            # against a floor of 0.30 says the method is at the limit of what
            # the data permit.
            floor = irreducible_loss(m, 2L),
            stringsAsFactors = FALSE
          )
        }
      }
    }
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

attr(grid, "provenance") <- list(
  quick    = quick,
  patterns = names(PATTERNS),
  thetas   = THETA,
  noise    = names(NOISE),
  seeds    = SEEDS,
  n        = N,
  methods  = METHODS,
  r_sha    = tryCatch(system2("git", c("rev-parse", "--short", "HEAD"),
                              stdout = TRUE), error = function(e) NA_character_)
)

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
saveRDS(grid, out)
message("wrote ", out, " — ", nrow(grid), " rows",
        if (quick) "  (QUICK smoke test, not the book's grid)" else "")
