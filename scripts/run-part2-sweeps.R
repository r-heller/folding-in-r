#!/usr/bin/env Rscript
#
# Part II's sweeps: what neighbourhood size does to each method.
#
# @artefact data/processed/part2-sweeps.rds
#
# Chapters 4, 5 and 6 take one family of methods each, and the question every one
# of them ends on is the same: how much of this method's result is the method,
# and how much is the k you handed it. The main grid holds k fixed at K_DEFAULT
# so that its cells are comparable; this is where k moves.
#
# It is the same cell as the main grid -- R/grid.R's grid_cell(), same metrics,
# same floor, same failure columns -- swept over k instead of over noise.
#
# A NOTE ON WHAT A FLAT CURVE WOULD HAVE MEANT. `embed_tsne()` accepted k and
# used a fixed perplexity of 30, so before this sweep existed it would have drawn
# a flat line and a chapter would have read it as "t-SNE is insensitive to
# neighbourhood size" -- false, and the opposite of what t-SNE is known for. k
# reaches the perplexity now (see R/methods.R). PCA and classical MDS genuinely
# take no k and are here as the flat reference the others are read against: their
# curve SHOULD be flat, and a sweep in which nothing is flat is a sweep whose
# axis is doing something it should not.
#
# Usage:  Rscript scripts/run-part2-sweeps.R [--quick] [--cores N]

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
THETA <- if (quick) c(0.5) else c(0.2, 0.5, 0.8)

# The k axis. Logarithmic-ish rather than even: the interesting behaviour of a
# k-NN graph is at the small end, where it disconnects, and doubling k at the
# large end changes little. 5 is below what several methods need and is here to
# show them failing rather than to be excluded for it.
KS <- if (quick) c(5L, 20L) else c(5L, 8L, 12L, 20L, 30L, 45L, 70L)

PAT <- miura_ori(6L, 6L)

CELLS <- expand.grid(theta = THETA, k = KS, seed = SEEDS, stringsAsFactors = FALSE)
CELLS <- CELLS[order(CELLS$theta, CELLS$k, CELLS$seed), ]

message("part II sweeps: ", length(THETA), " theta x ", length(KS), " k x ",
        length(SEEDS), " seeds = ", nrow(CELLS), " cells, ", cores, " core(s)")

run_one <- function(r) {
  cell <- CELLS[r, ]
  m <- sample_manifold(PAT, theta = cell$theta, n = N, seed = cell$seed)
  grid_cell(m, seed = cell$seed, k = cell$k, d = EMBED_DIM, theta = cell$theta)
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
grid <- grid[order(grid$theta, grid$k_tck, grid$seed, grid$method), ]
rownames(grid) <- NULL

out <- if (quick) "data/processed/part2-sweeps-quick.rds" else
  "data/processed/part2-sweeps.rds"
write_run(grid, out, quick = quick, theta = THETA, k = KS, seeds = SEEDS, n = N,
          k_qnx = K_QNX, embed_dim = EMBED_DIM, workers = cores,
          started = STARTED)

invisible(report_failures(grid))

cat("\nQ_NX against k, at theta = ", THETA[ceiling(length(THETA) / 2)], ":\n", sep = "")
mid <- grid[grid$ran & grid$theta == THETA[ceiling(length(THETA) / 2)], ]
print(stats::reshape(
  stats::aggregate(qnx ~ method + k_tck, data = mid,
                   FUN = function(x) round(mean(x), 4)),
  idvar = "method", timevar = "k_tck", direction = "wide"), row.names = FALSE)

# The check the sweep exists to make possible: a method whose curve does not move
# is either genuinely k-free or is ignoring the k it was given, and the two are
# indistinguishable from the artefact alone. Naming the k-free methods here means
# an unexpected flat line is a finding rather than a shrug.
# Compared on the MEAN at each k, not on the raw spread. Seed variation swamps
# k-insensitivity otherwise: a method that ignores k entirely still has a
# non-zero range across seeds, so a range test over raw rows reports every
# method as k-sensitive and the check never fires. Found by writing the check,
# running it on a method that does ignore k, and watching it pass.
K_FREE <- c("pca", "mds")
per_k <- stats::aggregate(qnx ~ method + k_tck, data = grid[grid$ran, ], FUN = mean)
span  <- stats::aggregate(qnx ~ method, data = per_k,
                          FUN = function(x) diff(range(x)))
flat <- span$method[span$qnx < 1e-8]
cat("\nmethods whose Q_NX does not move with k: ",
    if (length(flat)) paste(flat, collapse = ", ") else "none", "\n", sep = "")
unexpected <- setdiff(flat, K_FREE)
if (length(unexpected)) {
  cat("\n", paste(unexpected, collapse = ", "),
      " take a k and did not use it. A flat curve here would be read as ",
      "insensitivity to neighbourhood size, which is a claim about the method ",
      "rather than about the code.\n", sep = "")
  quit(status = 1L)
}
