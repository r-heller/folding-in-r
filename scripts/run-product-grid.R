#!/usr/bin/env Rscript
#
# The product suite: the artefact Claim B needs.
#
# @artefact data/processed/product-grid.rds
#
# E1 retired Claim C and made Claim B -- the irreducible-loss bound -- the
# book's spine. Claim B's operative instruction is "report every result against
# the floor rather than against zero". On the main grid that instruction does
# nothing: the chart is two-dimensional and the target is two-dimensional, so
# the floor is identically 0 in every cell. The spine had no artefact.
#
# The product construction is what makes the bound bite. Pairing two crease
# patterns gives intrinsic dimension 4 with the chart still exact and still in
# closed form, so forcing it into 2 dimensions has a floor that is strictly
# positive, computable, and attained -- the optimal rank-2 projection sits
# exactly on it. Every method can then be scored by how far ABOVE the floor it
# lands, which separates the loss the data imposes from the loss the method is
# responsible for.
#
# That distinction is the whole of Claim B. "PCA scores 0.66" reads as failure;
# "PCA is 0.007 above the best any 2-D embedding could achieve" says the loss
# belongs to the data.
#
# TWO ARMS, and the second one is a concession made into a finding.
# PROJECT_CONCEPT.md listed crease-specificity among the book's three
# differentiators, and product_manifold() imposes no family constraint: two
# isometric Swiss rolls give intrinsic dimension 4, an exact chart and a
# computable floor exactly as two Miura sheets do. The differentiator is refuted.
# Deleting it quietly would be the wrong move -- the comparison is the stronger
# claim. The bound is family-agnostic, and here are the two families' floors side
# by side. What crease-specificity rests on afterwards is zero reach and a
# non-smooth answer key, not the bound.
#
# NOT run in CI and not run at render time. Run it locally, commit the .rds, and
# keep this script as the record of how.
#
# Usage:  Rscript scripts/run-product-grid.R [--quick]

for (f in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) source(f)
source("_common.R")

quick <- "--quick" %in% commandArgs(trailingOnly = TRUE)

# The factors. Both are Miura -- the only family with a certified folding -- but
# with different cell geometry, so the product is not a square of one object.
#
# theta is swept on the SECOND factor only, and the first is held at THETA_A.
# That is a design choice and not, as this comment used to claim, the correction
# of a confound: both thetas are recorded on every row, so sweeping the pair
# would separate their contributions perfectly well. It would just cost a
# two-dimensional design where a one-dimensional one answers the question, which
# is whether the excess over the floor is flat in difficulty.
FACTORS <- list(
  a = miura_ori(4L, 4L, alpha = pi / 3),
  b = miura_ori(3L, 5L, b = 1.4, alpha = pi / 4)
)

# boundary = FALSE, which is sample_manifold()'s default and was overridden here
# with no reason given. It matters more than a sampling detail: the headline
# metric scores an embedding against the FLAT CHART, and that is only the
# geodesic while the straight chart segment between two points stays on the
# paper. A Miura unfolds to a region with a zigzag edge, so with the boundary
# strip included some pairs straddle a tooth and their chart distance is a lower
# bound on the geodesic rather than equal to it -- the answer key is then wrong
# for those pairs, in the direction of making every method look better.
#
# Measured on this grid's two factors at n = 400: boundary = TRUE exits the chart
# on 1.34% and 8.61% of sampled pairs, boundary = FALSE on 0.00% of both. The
# floor moves by 0.066 between the two, which is an order of magnitude more than
# the excess the chapter reports. The self-check at the end asserts the zero
# rather than trusting this comment.
BOUNDARY <- FALSE

THETA_A <- 0.55
THETA   <- if (quick) c(0.2, 0.7) else seq(0.1, 0.9, by = 0.1)
DIMS    <- if (quick) c(2L, 3L)    else c(1L, 2L, 3L, 4L)
# All twenty. This used to be the first ten, which is below standing rule 1's
# floor and had no reason recorded -- and the rule is now checked over committed
# artefacts rather than stated in prose, so the first thing that check did was
# refuse this file. That is the rule working.
SEEDS   <- if (quick) BENCH_SEEDS[1:2] else BENCH_SEEDS
N       <- if (quick) 150L else 400L

# The Swiss-roll arm's difficulty parameter. Turns, not theta: each family is
# swept over its OWN natural parameter and made comparable by what is being
# measured, which is the excess over that cell's floor -- a quantity with the
# same meaning whatever produced the manifold. The range brackets the floors the
# crease arm reaches, so the two curves overlap where it matters.
TURNS_A <- 1.5
TURNS   <- if (quick) c(1, 3) else seq(0.5, 4.5, by = 0.5)

started <- Sys.time()

# One cell: build the product, compute the floor at each target dimension, fit
# every method, and record how far above the floor it landed.
one_cell <- function(family, par, seed, a, b, exit) {
  p <- product_manifold(a, b)
  out <- list()
  for (d in DIMS) {
    fl <- irreducible_loss(p, d)
    for (mname in names(METHOD_REGISTRY)) {
      spec <- METHOD_REGISTRY[[mname]]
      sd   <- if (isTRUE(spec$stochastic)) seed else NULL
      # status and reason, as run-benchmark-grid.R records them: a failed fit
      # that says only `ran = FALSE` collapses three causes into one
      # indistinguishable state, and t-SNE declines a quarter of the cells here.
      e_msg <- NULL
      emb  <- tryCatch(embed(mname, p, d = d, seed = sd),
                       error = function(e) { e_msg <<- conditionMessage(e); NULL })
      na   <- is.null(emb)
      status <- if (!is.null(e_msg)) "error"
                else if (na) { if (!is.null(spec$unavailable)) "unavailable" else "declined" }
                else "ok"
      reason <- if (!is.null(e_msg)) sub("\n.*", "", e_msg)
                else if (status == "unavailable") spec$unavailable
                else if (status == "declined")
                  "the method returned NULL on this cell; see R/methods.R"
                else NA_character_
      err  <- if (na) NA_real_ else reconstruction_error(emb, p$truth)
      out[[length(out) + 1L]] <- data.frame(
        family = family, par = par, seed = seed, d = d, method = mname,
        consumes = spec$consumes, ran = !na, status = status, reason = reason,
        rmse = err, floor = fl,
        excess = if (na) NA_real_ else err - fl,
        # How much of the achievable range the method actually gave away. 0 is
        # optimal, 1 is as bad as a random embedding.
        gave_away = if (na) NA_real_ else (err - fl) / max(1e-12, 1 - fl),
        chart_exit = exit,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, out)
}

rows <- list()

message("arm 1/2: crease product, ", length(THETA), " theta x ", length(SEEDS),
        " seeds x ", length(DIMS), " dims x ", length(METHOD_REGISTRY), " methods")
for (th in THETA) for (seed in SEEDS) {
  a <- sample_manifold(FACTORS$a, theta = THETA_A, n = N, seed = seed,
                       boundary = BOUNDARY)
  b <- sample_manifold(FACTORS$b, theta = th, n = N, seed = seed + 500L,
                       boundary = BOUNDARY)
  # Measured per cell, not once: the chart-exit fraction is a property of this
  # sample at this theta, and it is the assumption the headline metric rests on.
  exit <- max(chart_exit_fraction(a, FACTORS$a),
              chart_exit_fraction(b, FACTORS$b))
  rows[[length(rows) + 1L]] <- one_cell("crease", th, seed, a, b, exit)
  message("  done: theta ", th, " seed ", seed)
}

# ── The arm that turns a refuted differentiator into a finding ──────────────
message("arm 2/2: Swiss-roll product, ", length(TURNS), " turn counts x ",
        length(SEEDS), " seeds")
for (tn in TURNS) for (seed in SEEDS) {
  a <- swiss_roll(n = N, turns = TURNS_A, seed = seed)
  b <- swiss_roll(n = N, turns = tn,      seed = seed + 500L)
  # No chart to exit: the roll's unfolding is a rectangle, which is convex.
  rows[[length(rows) + 1L]] <- one_cell("roll", tn, seed, a, b, 0)
  message("  done: turns ", tn, " seed ", seed)
}

grid <- do.call(rbind, rows)

out <- if (quick) "data/processed/product-grid-quick.rds" else
  "data/processed/product-grid.rds"
write_run(grid, out,
          quick = quick, boundary = BOUNDARY, theta_a = THETA_A, theta = THETA,
          turns_a = TURNS_A, turns = TURNS, dims = DIMS, seeds = SEEDS, n = N,
          methods = names(METHOD_REGISTRY), started = started)

# ── The checks that make it a bound ─────────────────────────────────────────
ok <- grid[grid$ran, ]

# 1. Nothing beats the floor. If anything does, it is not a bound and Chapter 8
#    has no claim.
viol <- ok[ok$excess < -1e-9, ]
if (nrow(viol)) {
  cat("\n", nrow(viol), " cells BEAT the floor -- it is not a bound:\n", sep = "")
  print(utils::head(viol[, c("family", "par", "d", "method", "rmse", "floor")]))
  quit(status = 1)
}
cat("\nno method beat the floor in any of ", nrow(ok), " fits.\n", sep = "")

# 2. The chart is the geodesic. The headline metric scores against the flat
#    chart on exactly that assumption, so a non-zero exit fraction means the
#    answer key is wrong for some pairs -- in the direction that flatters every
#    method. Asserted, because the previous version of this script sampled with
#    boundary = TRUE and said nothing about it.
worst_exit <- max(grid$chart_exit)
if (worst_exit > 1e-12) {
  cat("\nchart-exit fraction reaches ", format(worst_exit), " -- the flat chart is ",
      "not the geodesic for those pairs, so the answer key is wrong where it ",
      "matters most.\n", sep = "")
  quit(status = 1)
}
cat("chart-exit fraction is 0 in every cell: the chart IS the geodesic here.\n")

cat("\nmean excess over the floor, by family, method and target dimension:\n")
print(stats::reshape(
  stats::aggregate(excess ~ method + d + family, data = ok,
                   FUN = function(x) round(mean(x), 4)),
  idvar = c("method", "family"), timevar = "d", direction = "wide"),
  row.names = FALSE)

# 3. The two families, side by side. This is item 1.3: the bound is
#    family-agnostic, and saying so with both floors in one table is a stronger
#    statement than the crease-specificity claim it replaces.
#
#    Read as a comparison of the CONSTRUCTION, not of the two families'
#    difficulty. Each family is swept over its own parameter and the two are not
#    matched on anything -- which is precisely the error E1's arm A made and had
#    to be redesigned around. What this table supports is "the floor exists,
#    is computable, and is not beaten, in both families"; a claim that one family
#    is harder than the other needs matched difficulty and does not live here.
cat("\nthe floor itself, by family and target dimension",
    " (the quantity the differentiator claimed was crease-specific):\n", sep = "")
print(stats::reshape(
  stats::aggregate(floor ~ d + family, data = ok,
                   FUN = function(x) round(mean(x), 4)),
  idvar = "family", timevar = "d", direction = "wide"), row.names = FALSE)

cat("\nexcess over the floor as a curve in each family's own difficulty parameter:\n")
print(stats::aggregate(excess ~ family + par, data = ok[ok$d == 2L, ],
                       FUN = function(x) round(mean(x), 4)), row.names = FALSE)
