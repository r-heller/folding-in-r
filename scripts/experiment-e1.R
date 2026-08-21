#!/usr/bin/env Rscript
#
# E1 -- the go/no-go experiment. See PLAN.md.
#
# THE QUESTION. Do crease patterns and classical benchmarks collapse onto one
# difficulty curve when plotted against branch separation?
#
# WHY IT RUNS FIRST. The book's headline claim is that crease patterns are a
# better benchmark than the Swiss roll. Nothing currently supports that, and the
# feasibility numbers actively undercut it: the geometric properties the claim
# rests on -- piecewise flatness, curvature on the 1-skeleton, zero reach -- are
# fully present at theta = 0.001, where nothing measurable happens, and
# unchanged at theta = 1.4, where all of it happens. A property constant across
# the entire phenomenon cannot be its cause. What does vary is g/s, and g/s is
# exactly the ratio Balasubramanian & Schwartz identified for Isomap's
# topological instability -- and exactly what tightening a Swiss roll's turn
# count varies. If the two families collapse onto one curve in g/s, the crease
# pattern is a more convenient generator of a known difficulty axis, not a new
# kind of benchmark, and thirty thousand words should not say otherwise.
#
# WHAT IS PRE-REGISTERED. All three outcomes are written down in PLAN.md before
# the run, and this script does not choose between them -- it reports the
# numbers that do. That is the whole point of running it before the prose.
#
# Usage:  Rscript scripts/experiment-e1.R [--quick]
# Writes: data/processed/e1-difficulty.rds  (one row per fit)
#         data/processed/e1-armB.rds        (crease count at matched g/s)

for (f in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) source(f)
source("_common.R")

quick <- "--quick" %in% commandArgs(trailingOnly = TRUE)

N       <- if (quick) 300L else 800L
SEEDS   <- if (quick) BENCH_SEEDS[1:3] else BENCH_SEEDS[1:10]
K_NN    <- 10L
K_QNX   <- 20L

# ── The difficulty axes ─────────────────────────────────────────────────────
#
# Each family is swept over its OWN natural parameter, and the sweeps are not
# comparable to each other -- that is the point. They are made comparable by
# plotting against g/s, which is measured the same way for all of them.

THETA <- if (quick) c(0, 0.6, 1.2) else seq(0, 1.4, by = 0.1)
TURNS <- if (quick) c(1.5, 3.0)     else seq(1.0, 4.0, by = 0.25)

FAMILIES <- list(
  miura = list(
    kind = "crease",
    par  = THETA,
    make = function(p, seed) sample_manifold(miura_ori(6L, 6L), theta = p,
                                             n = N, seed = seed)
  ),
  yoshimura = list(
    kind = "crease",
    par  = THETA,
    make = function(p, seed) sample_manifold(yoshimura(6L, 6L), theta = p,
                                             n = N, seed = seed)
  ),
  swiss_roll = list(
    kind = "classic",
    par  = TURNS,
    make = function(p, seed) swiss_roll(n = N, turns = p, seed = seed)
  )
)

# ── The methods ─────────────────────────────────────────────────────────────
#
# Three, not nine. E1 needs no autoencoder and no neighbour embedding: the
# question is about the difficulty axis, not about method ranking, and Isomap is
# the method the axis is a theory OF. PCA and classical MDS are here as the
# ambient-metric controls -- they consume a target the answer key does not
# measure, which Chapter 1 says out loud.

METHODS <- list(
  pca = function(m) stats::prcomp(m$X, rank. = 2L)$x[, 1:2, drop = FALSE],

  cmds = function(m) stats::cmdscale(reference_dist(m, "ambient"), k = 2L),

  isomap = function(m) {
    d <- reference_dist(m, "graph", k = K_NN)
    if (any(!is.finite(d))) return(NULL)   # disconnected graph: report, not guess
    stats::cmdscale(d, k = 2L)
  }
)

# ── One cell ────────────────────────────────────────────────────────────────

one_cell <- function(fam, fname, p, seed) {
  m <- fam$make(p, seed)

  bg <- branch_gap(m)
  sc <- short_circuit_index(m, k = K_NN)

  do.call(rbind, lapply(names(METHODS), function(mn) {
    emb <- tryCatch(METHODS[[mn]](m), error = function(e) NULL)
    if (is.null(emb)) {
      return(data.frame(family = fname, kind = fam$kind, par = p, seed = seed,
                        method = mn, gs = bg$ratio, sc = sc,
                        rmse = NA_real_, qnx = NA_real_, ok = FALSE,
                        stringsAsFactors = FALSE))
    }
    data.frame(
      family = fname, kind = fam$kind, par = p, seed = seed, method = mn,
      gs   = bg$ratio,
      sc   = sc,
      rmse = reconstruction_error(emb, m$truth),
      qnx  = qnx(emb, m$truth, K = K_QNX),
      ok   = TRUE,
      stringsAsFactors = FALSE
    )
  }))
}

# ── Arm A — do the families collapse? ───────────────────────────────────────

message("E1 arm A: ", length(FAMILIES), " families x ",
        sum(vapply(FAMILIES, function(f) length(f$par), integer(1))),
        " parameter values x ", length(SEEDS), " seeds")

rows <- list()
for (fname in names(FAMILIES)) {
  fam <- FAMILIES[[fname]]
  for (p in fam$par) for (s in SEEDS) {
    rows[[length(rows) + 1L]] <- one_cell(fam, fname, p, s)
  }
  message("  done: ", fname)
}
armA <- do.call(rbind, rows)

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
saveRDS(armA, "data/processed/e1-difficulty.rds")

# ── Arm B — does crease count do anything at matched g/s? ───────────────────
#
# Arm A can only show whether the families lie on one curve. It cannot separate
# "creases do nothing" from "creases and turns happen to co-vary". Arm B holds
# g/s fixed and varies the number of creases: a 3x3 against a 12x12 Miura, with
# theta chosen per grid so that the measured g/s matches. If error is flat in
# crease count at matched g/s, the crease structure is not what makes these
# patterns hard, and Chapter 11 says so in the book's own voice.

match_theta <- function(nx, ny, target_gs, seed) {
  # Solve for the theta whose measured g/s is closest to the target. g/s falls
  # monotonically in theta, so a bisection would do; a coarse scan is used
  # instead because each evaluation is a full sample and the monotonicity is
  # measured rather than assumed.
  grid <- seq(0, 1.4, by = 0.05)
  gs <- vapply(grid, function(th) {
    branch_gap(sample_manifold(miura_ori(nx, ny), theta = th, n = N, seed = seed))$ratio
  }, numeric(1))
  list(theta = grid[which.min(abs(gs - target_gs))],
       gs = gs, grid = grid,
       monotone = !is.unsorted(rev(gs)))
}

message("E1 arm B: crease count at matched g/s")

GRIDS <- list(c(3L, 3L), c(6L, 6L), c(12L, 12L))
ref   <- match_theta(6L, 6L, NA_real_, SEEDS[1])          # measure the 6x6 range
target_gs <- stats::median(ref$gs[ref$gs > 0], na.rm = TRUE)
message("  matching on g/s = ", format(target_gs, digits = 4),
        " (6x6 median); monotone in theta: ", ref$monotone)

rowsB <- list()
for (g in GRIDS) {
  fit <- match_theta(g[1], g[2], target_gs, SEEDS[1])
  for (s in SEEDS) {
    m <- sample_manifold(miura_ori(g[1], g[2]), theta = fit$theta, n = N, seed = s)
    bg <- branch_gap(m)
    for (mn in names(METHODS)) {
      emb <- tryCatch(METHODS[[mn]](m), error = function(e) NULL)
      rowsB[[length(rowsB) + 1L]] <- data.frame(
        nx = g[1], ny = g[2], creases = g[1] * g[2],
        theta = fit$theta, seed = s, method = mn,
        gs = bg$ratio, sc = short_circuit_index(m, k = K_NN),
        rmse = if (is.null(emb)) NA_real_ else reconstruction_error(emb, m$truth),
        qnx  = if (is.null(emb)) NA_real_ else qnx(emb, m$truth, K = K_QNX),
        stringsAsFactors = FALSE
      )
    }
  }
  message("  done: ", g[1], "x", g[2], " at theta ", format(fit$theta, digits = 3))
}
armB <- do.call(rbind, rowsB)
saveRDS(armB, "data/processed/e1-armB.rds")

# ── Report ──────────────────────────────────────────────────────────────────
#
# The decision rule, stated before the numbers were seen:
#
#   COLLAPSE   -- at matched g/s the families agree within seed noise. Claim C
#                 as written is false; replace it with the generator claim.
#   SEPARATE   -- at matched g/s the crease family gives different rankings or
#                 materially different error. Claim C is empirical.
#   FLAT IN    -- arm B shows no effect of crease count at matched g/s. Say so
#   CREASES      in Chapter 11 whichever way arm A lands.

cat("\n== arm A: error against g/s ==\n")
ok <- armA[armA$ok, ]
for (mn in names(METHODS)) {
  sub <- ok[ok$method == mn, ]
  if (!nrow(sub)) next
  cat("\n", mn, ":\n", sep = "")
  # Compare families at matched g/s by binning on log(g/s).
  sub$bin <- cut(log(sub$gs), breaks = 6)
  agg <- stats::aggregate(rmse ~ bin + kind, data = sub, FUN = mean)
  print(stats::reshape(agg, idvar = "bin", timevar = "kind", direction = "wide"),
        row.names = FALSE)
}

cat("\n== arm B: error against crease count at matched g/s ==\n")
print(stats::aggregate(cbind(gs, rmse, qnx) ~ creases + method, data = armB,
                       FUN = function(x) round(mean(x), 4)), row.names = FALSE)

cat("\nWrote data/processed/e1-difficulty.rds (", nrow(armA), " rows) and ",
    "data/processed/e1-armB.rds (", nrow(armB), " rows).\n", sep = "")
cat("Record the claim-set decision in GENERATION_LOG.md before drafting.\n")
