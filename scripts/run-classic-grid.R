#!/usr/bin/env Rscript
#
# The three classical benchmarks, scored exactly as the crease patterns are.
#
# @artefact data/processed/classic-grid.rds
#
# Chapter 11 asks whether the crease-pattern benchmark adds anything the Swiss
# roll does not already give, and E1 answered that at the level of one difficulty
# axis. This is the other half: the Swiss roll, the S-curve and the severed
# sphere, the same eight methods, the same metrics, the same floor. Without it
# the comparison is a curve against an anecdote.
#
# The point is that NOTHING is special-cased. Every method, every metric and the
# irreducible-loss floor come from R/grid.R's grid_cell(), which is the same
# function the main grid and the Part II sweeps call. A comparison in which the
# two sides are scored by two code paths is not a comparison.
#
# Each family is swept over its own natural parameter, because they do not share
# one -- the Swiss roll tightens in turns, the severed sphere widens in cap
# angle, and the S-curve has no difficulty knob at all and appears once. Making
# them comparable is the analysis's job, not the generator's, and E1's arm A is
# the record of what happens when a generator pretends otherwise.
#
# Usage:  Rscript scripts/run-classic-grid.R [--quick] [--cores N]

for (f in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) source(f)
source("_common.R")

args  <- commandArgs(trailingOnly = TRUE)
quick <- "--quick" %in% args
.arg  <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[i + 1L]
}
cores   <- as.integer(.arg("--cores", "1"))
STARTED <- Sys.time()

N     <- if (quick) 200L else 800L
SEEDS <- if (quick) BENCH_SEEDS[1:2] else BENCH_SEEDS
NOISE <- list(none    = list(type = "none",    sd = 0),
              ambient = list(type = "ambient", sd = 0.02))
if (quick) NOISE <- NOISE["none"]

# One entry per (family, difficulty). `make` takes n, noise and seed and returns
# a manifold_sample, so the loop below knows nothing about any family.
FAMILIES <- local({
  out <- list()
  turns <- if (quick) c(1, 3) else c(0.5, 1, 1.5, 2, 3, 4, 5, 6.5)
  for (t in turns) {
    out[[length(out) + 1L]] <- list(
      family = "swiss_roll", par = t,
      make = local({ tt <- t; function(n, noise, seed)
        swiss_roll(n = n, turns = tt, noise = noise, seed = seed) }))
  }
  caps <- if (quick) c(0.6) else c(0.4, 0.6, 0.8, 0.95)
  for (cp in caps) {
    out[[length(out) + 1L]] <- list(
      family = "severed_sphere", par = cp,
      make = local({ cc <- cp; function(n, noise, seed)
        severed_sphere(n = n, cap = cc, noise = noise, seed = seed) }))
  }
  # No difficulty parameter. It appears once, at par = NA, and Chapter 11 says
  # so rather than inventing an axis for it.
  out[[length(out) + 1L]] <- list(
    family = "s_curve", par = NA_real_,
    make = function(n, noise, seed) s_curve(n = n, noise = noise, seed = seed))
  out
})

CELLS <- expand.grid(fi = seq_along(FAMILIES), noise = names(NOISE), seed = SEEDS,
                     stringsAsFactors = FALSE)
CELLS <- CELLS[order(CELLS$fi, CELLS$noise, CELLS$seed), ]

message("classic grid: ", length(FAMILIES), " family settings x ", length(NOISE),
        " noise x ", length(SEEDS), " seeds = ", nrow(CELLS), " cells, ",
        cores, " core(s)")

run_one <- function(r) {
  cell <- CELLS[r, ]
  fam  <- FAMILIES[[cell$fi]]
  m <- fam$make(N, NOISE[[cell$noise]], cell$seed)
  grid_cell(m, seed = cell$seed, k = K_DEFAULT, d = EMBED_DIM,
            family = fam$family, par = fam$par, noise = cell$noise)
}

rows <- if (cores > 1L) {
  parallel::mclapply(seq_len(nrow(CELLS)), run_one, mc.cores = cores,
                     mc.preschedule = FALSE)
} else {
  lapply(seq_len(nrow(CELLS)), run_one)
}
if (any(vapply(rows, function(x) inherits(x, "try-error") || is.null(x), logical(1)))) {
  stop("at least one cell failed outright", call. = FALSE)
}

grid <- do.call(rbind, rows)
grid <- grid[order(grid$family, grid$par, grid$noise, grid$seed, grid$method), ]
rownames(grid) <- NULL

out <- if (quick) "data/processed/classic-grid-quick.rds" else
  "data/processed/classic-grid.rds"
write_run(grid, out, quick = quick, families = unique(grid$family),
          noise = names(NOISE), seeds = SEEDS, n = N,
          k_tck = K_DEFAULT, k_qnx = K_QNX, embed_dim = EMBED_DIM,
          workers = cores, started = STARTED)

invisible(report_failures(grid))

cat("\nmean excess over the floor by family and method (no noise):\n")
ok <- grid[grid$ran & grid$noise == "none", ]
ok$excess <- ok$rmse - ok$floor
print(stats::reshape(
  stats::aggregate(excess ~ method + family, data = ok,
                   FUN = function(x) round(mean(x), 4)),
  idvar = "method", timevar = "family", direction = "wide"), row.names = FALSE)

cat("\nthe floor itself, which is what makes these comparable to the crease grid:\n")
print(stats::aggregate(floor ~ family, data = ok,
                       FUN = function(x) round(mean(x), 4)), row.names = FALSE)
