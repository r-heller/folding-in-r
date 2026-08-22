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

# theta is the fraction of the way to flat-folded, on [0, 1] -- see
# R/folding.R. THETA_GRID comes from R/constants.R.
THETA <- if (quick) c(0, 0.5, 0.9) else THETA_GRID

# The Swiss roll's own difficulty parameter. The range is chosen so that its
# measured g/s brackets what the crease families reach, which is what makes the
# families comparable at matched separation -- the question E1 exists to ask.
TURNS <- if (quick) c(1, 3) else seq(0.5, 6.5, by = 0.5)

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

# ── Arm A2 — the redesign that arm A forced ─────────────────────────────────
#
# Arm A sweeps theta and nothing else, and that turns out not to be a controlled
# comparison. Folding a crease pattern raises branch separation AND lifts the
# sheet out of the plane, and the two move together, so g/s alone does not
# isolate what it is supposed to isolate. Measured: at g/s about 21 a Miura is a
# FLAT PLANE, recovered by PCA with error 0.000, while a Swiss roll at the same
# separation is still curved and PCA scores 0.403. Worse, the two families'
# ranges of ambient non-planarity are DISJOINT -- crease patterns 0.000 to 0.056,
# Swiss rolls 0.101 to 0.126 -- so over arm A's design there is no setting at
# which the families are comparable at all, and the large family term it reports
# is a statement about that, not about creases.
#
# The generator has more knobs than theta. Cell count dominates non-planarity: a
# 2x2 Miura at alpha = 1.05, theta = 0.9 reaches 0.157, above anything the Swiss
# roll produces, while a 6x6 at the same angles reaches 0.027. So sweeping
# (nx, alpha, theta) decouples the two axes and creates the overlap arm A lacks.
#
# This arm is the experiment that can actually decide Claim C.

ARM2_CREASE <- expand.grid(
  nx    = c(2L, 3L, 4L, 6L),
  alpha = c(pi/4, pi/3, 1.2, 1.35),
  theta = c(0.3, 0.5, 0.7, 0.85, 0.95)
)
ARM2_TURNS <- c(0.5, 0.75, 1, 1.5, 2, 3, 4, 5, 6.5)
ARM2_SEEDS <- if (quick) BENCH_SEEDS[1:2] else BENCH_SEEDS[1:5]
ARM2_N     <- if (quick) 200L else 600L

# The second axis: the share of ambient variance no plane captures. Zero for a
# flat sheet. This is what arm A left uncontrolled.
non_planarity <- function(m) {
  v <- stats::prcomp(m$X)$sdev^2
  v[3] / sum(v)
}

message("E1 arm A2: ", nrow(ARM2_CREASE), " crease settings + ",
        length(ARM2_TURNS), " Swiss rolls x ", length(ARM2_SEEDS), " seeds")

a2 <- list()
for (i in seq_len(nrow(ARM2_CREASE))) {
  g <- ARM2_CREASE[i, ]
  for (s in ARM2_SEEDS) {
    m <- sample_manifold(miura_ori(g$nx, g$nx, alpha = g$alpha), theta = g$theta,
                         n = ARM2_N, seed = s, boundary = TRUE)
    bg <- branch_gap(m); npl <- non_planarity(m)
    for (mn in names(METHODS)) {
      emb <- tryCatch(METHODS[[mn]](m), error = function(e) NULL)
      a2[[length(a2) + 1L]] <- data.frame(
        kind = "crease", label = sprintf("miura%d/%.2f/%.2f", g$nx, g$alpha, g$theta),
        seed = s, method = mn, gs = bg$ratio, np = npl,
        rmse = if (is.null(emb)) NA_real_ else reconstruction_error(emb, m$truth),
        qnx  = if (is.null(emb)) NA_real_ else qnx(emb, m$truth, K = K_QNX),
        stringsAsFactors = FALSE)
    }
  }
}
message("  crease settings done")
for (tn in ARM2_TURNS) for (s in ARM2_SEEDS) {
  m <- swiss_roll(n = ARM2_N, turns = tn, seed = s)
  bg <- branch_gap(m); npl <- non_planarity(m)
  for (mn in names(METHODS)) {
    emb <- tryCatch(METHODS[[mn]](m), error = function(e) NULL)
    a2[[length(a2) + 1L]] <- data.frame(
      kind = "classic", label = sprintf("roll/%.2f", tn), seed = s, method = mn,
      gs = bg$ratio, np = npl,
      rmse = if (is.null(emb)) NA_real_ else reconstruction_error(emb, m$truth),
      qnx  = if (is.null(emb)) NA_real_ else qnx(emb, m$truth, K = K_QNX),
      stringsAsFactors = FALSE)
  }
}
armA2 <- do.call(rbind, a2)
saveRDS(armA2, "data/processed/e1-controlled.rds")

cat("\n== arm A2: family effect once BOTH axes are controlled ==\n")
for (mn in names(METHODS)) for (metric in c("rmse", "qnx")) {
  s <- armA2[armA2$method == mn & is.finite(armA2[[metric]]), ]
  s$lg <- log(s$gs)
  keep <- s$lg >= max(tapply(s$lg, s$kind, min)) & s$lg <= min(tapply(s$lg, s$kind, max)) &
          s$np >= max(tapply(s$np, s$kind, min)) & s$np <= min(tapply(s$np, s$kind, max))
  s <- s[keep, ]
  if (length(unique(s$kind)) < 2L || nrow(s) < 40L) {
    cat(sprintf("  %-7s %-4s  still no joint overlap (n = %d)\n", mn, metric, nrow(s))); next
  }
  f0 <- stats::lm(s[[metric]] ~ splines::ns(lg, 3) + splines::ns(np, 3), data = s)
  f1 <- stats::lm(s[[metric]] ~ splines::ns(lg, 3) + splines::ns(np, 3) + kind, data = s)
  an <- stats::anova(f0, f1)
  cat(sprintf("  %-7s %-4s  n=%3d  g/s [%.1f,%.1f] np [%.3f,%.3f]  F=%7.2f  p=%-9s  family effect=%+.4f\n",
              mn, metric, nrow(s), exp(min(s$lg)), exp(max(s$lg)), min(s$np), max(s$np),
              an$F[2], format.pval(an$`Pr(>F)`[2], digits = 2),
              coef(f1)[["kindcrease"]]))
}

# ── Arm A3 — the question a benchmark is actually for ───────────────────────
#
# "Harder" is not the property that matters. A benchmark earns its keep by
# telling methods APART, so the statistic to report is the spread across methods
# within a cell, at matched difficulty. A benchmark on which everything scores
# the same discriminates nothing, however difficult it is.

cat("\n== arm A3: does each family separate the methods? ==\n")
local({
  s <- armA2[is.finite(armA2$rmse), ]
  s$lg <- log(s$gs)
  keep <- s$lg >= max(tapply(s$lg, s$kind, min)) & s$lg <= min(tapply(s$lg, s$kind, max)) &
          s$np >= max(tapply(s$np, s$kind, min)) & s$np <= min(tapply(s$np, s$kind, max))
  s <- s[keep, ]
  if (!nrow(s)) { cat("  no joint overlap\n"); return(invisible()) }

  cat("  overlap covers ", length(unique(s$label[s$kind == "crease"])),
      " crease settings and ", length(unique(s$label[s$kind == "classic"])),
      " Swiss rolls\n", sep = "")

  w <- stats::reshape(s[, c("kind", "label", "seed", "method", "rmse")],
                      idvar = c("kind", "label", "seed"), timevar = "method",
                      direction = "wide")
  w$spread <- abs(w$rmse.pca - w$rmse.isomap)
  agg <- stats::aggregate(spread ~ kind, data = w,
                          FUN = function(x) c(mean = mean(x), sd = stats::sd(x),
                                              n = length(x)))
  print(do.call(data.frame, agg), row.names = FALSE)

  cat("\n  mean score at matched difficulty:\n")
  print(stats::aggregate(cbind(rmse, qnx) ~ kind + method, data = s,
                         FUN = function(x) round(mean(x), 4)), row.names = FALSE)
})

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
  grid <- seq(0, 0.95, by = 0.05)
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

cat("\n== arm A: do the families lie on one curve in g/s? ==\n")
ok <- armA[armA$ok & is.finite(armA$gs), ]

# Binning was the first instinct and it reads badly: the families cover
# different parts of the axis, so most bins hold one family and the comparison
# is empty exactly where it matters. Fit instead, and compare where they
# actually overlap.
#
# The test is whether a smooth of error on log(g/s) needs a family term. If the
# crease patterns and the Swiss roll lie on one difficulty curve, adding `kind`
# buys nothing; if creases do something the Swiss roll does not, it buys a lot.
for (metric in c("rmse", "qnx")) {
  cat("\n--- ", metric, " ---\n", sep = "")
  for (mn in names(METHODS)) {
    sub <- ok[ok$method == mn & is.finite(ok[[metric]]), ]
    if (nrow(sub) < 20L) next
    sub$lg <- log(sub$gs)

    # The overlap region: where both kinds have data.
    rng <- range(c(max(tapply(sub$lg, sub$kind, min)),
                   min(tapply(sub$lg, sub$kind, max))))
    if (!all(is.finite(rng)) || diff(rng) <= 0) {
      cat(sprintf("  %-7s no overlap in g/s between families\n", mn)); next
    }
    inside <- sub[sub$lg >= rng[1] & sub$lg <= rng[2], ]
    if (length(unique(inside$kind)) < 2L) {
      cat(sprintf("  %-7s no overlap in g/s between families\n", mn)); next
    }

    f0 <- stats::lm(inside[[metric]] ~ splines::ns(lg, df = 4), data = inside)
    f1 <- stats::lm(inside[[metric]] ~ splines::ns(lg, df = 4) * kind, data = inside)
    an <- stats::anova(f0, f1)

    grid <- seq(rng[1], rng[2], length.out = 5L)
    pred <- vapply(unique(inside$kind), function(k) {
      d <- inside[inside$kind == k, ]
      stats::predict(stats::lm(d[[metric]] ~ splines::ns(lg, df = 3), data = d),
                     newdata = data.frame(lg = grid))
    }, numeric(length(grid)))

    cat(sprintf("  %-7s overlap g/s [%.2f, %.2f], n = %d\n",
                mn, exp(rng[1]), exp(rng[2]), nrow(inside)))
    cat(sprintf("          family term: F = %.2f, p = %s\n",
                an$F[2], format.pval(an$`Pr(>F)`[2], digits = 3)))
    cat("          at matched g/s: ",
        paste(sprintf("%.2f", exp(grid)), collapse = "  "), "\n", sep = "")
    for (k in colnames(pred)) {
      cat(sprintf("            %-8s %s\n", k,
                  paste(sprintf("%5.3f", pred[, k]), collapse = "  ")))
    }
    cat(sprintf("            %-8s %s\n", "gap",
                paste(sprintf("%5.3f", abs(pred[, 1] - pred[, 2])), collapse = "  ")))
  }
}

# Seed spread, so "different" can be read against "noisy".
cat("\n  within-cell spread (sd across seeds, median over cells):\n")
sp <- stats::aggregate(rmse ~ family + par + method, data = ok, FUN = stats::sd)
print(stats::aggregate(rmse ~ family + method, data = sp,
                       FUN = function(x) round(stats::median(x, na.rm = TRUE), 4)),
      row.names = FALSE)

cat("\n== arm B: error against crease count at matched g/s ==\n")
print(stats::aggregate(cbind(gs, rmse, qnx) ~ creases + method, data = armB,
                       FUN = function(x) round(mean(x), 4)), row.names = FALSE)

cat("\nWrote data/processed/e1-difficulty.rds (", nrow(armA), " rows) and ",
    "data/processed/e1-armB.rds (", nrow(armB), " rows).\n", sep = "")
cat("Record the claim-set decision in GENERATION_LOG.md before drafting.\n")
