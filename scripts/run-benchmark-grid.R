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

args  <- commandArgs(trailingOnly = TRUE)
quick <- "--quick" %in% args

# ── Parallelism and shards ──────────────────────────────────────────────────
#
# 1,200 cells at roughly 26 s of fitting each is hours on one core, and the
# seeding design already makes it safe to spread: every sample and every
# stochastic fit takes its seed explicitly, so no cell depends on where the RNG
# stream happens to be. Nothing was exploiting that.
#
#   --cores N     fork N workers over the cell list (default 1)
#   --shard i/n   compute only cells i mod n, write a shard file of its own
#   --merge       read the shards back, check them, write the artefact
#
# Sharding stamps each shard with its own `R/` tree hash and REFUSES TO MERGE
# shards that disagree. Resume-by-file-existence is the obvious way to build this
# and it is a trap: a shard computed before an edit and a shard computed after it
# merge into one table under one provenance block, and nothing downstream can
# tell. The check is the reason the feature is safe to have.
.arg <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[i + 1L]
}
cores <- as.integer(.arg("--cores", "1"))
shard <- .arg("--shard", NA_character_)
merge_only <- "--merge" %in% args

shard_i <- shard_n <- NA_integer_
if (!is.na(shard)) {
  parts <- as.integer(strsplit(shard, "/", fixed = TRUE)[[1]])
  if (length(parts) != 2L || anyNA(parts) || parts[1] < 1L || parts[1] > parts[2]) {
    stop("--shard takes i/n with 1 <= i <= n, e.g. --shard 2/4", call. = FALSE)
  }
  shard_i <- parts[1]; shard_n <- parts[2]
}
if (!is.na(shard) && merge_only) {
  stop("--shard and --merge are the two halves of the same job; run them ",
       "separately", call. = FALSE)
}

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

# One cell is R/grid.R's grid_cell(), which the Part II sweeps and the classic
# grid also use. It lived here, so those two could not have it -- which is a
# large part of why they did not exist. What stays here is this grid's own
# design: which pattern, which theta, which noise.
one_cell <- function(pat, pname, th, nname, seed) {
  m <- sample_manifold(pat, theta = th, n = N, noise = NOISE[[nname]], seed = seed)
  grid_cell(m, seed = seed, methods = METHODS, k = K_DEFAULT, d = EMBED_DIM,
            pattern = pname, theta = th, noise = nname)
}

# The cell list, built before anything runs, so a shard is a deterministic slice
# of it rather than whatever the loops happen to reach.
CELLS <- expand.grid(pattern = names(PATTERNS), theta = THETA,
                     noise = names(NOISE), seed = SEEDS,
                     stringsAsFactors = FALSE)
CELLS <- CELLS[order(CELLS$pattern, CELLS$theta, CELLS$noise, CELLS$seed), ]
rownames(CELLS) <- NULL

SHARD_PATH <- function(i, n) {
  sprintf("data/processed/benchmark-grid-shard-%02d-of-%02d.rds", i, n)
}

out <- if (quick) "data/processed/benchmark-grid-quick.rds" else
  "data/processed/benchmark-grid.rds"

if (merge_only) {
  files <- sort(Sys.glob("data/processed/benchmark-grid-shard-*.rds"))
  if (!length(files)) stop("no shards to merge", call. = FALSE)
  parts <- lapply(files, readRDS)

  # Every shard must come from the same R/. This is the check that makes
  # sharding safe rather than a way to silently mix code states.
  shas <- vapply(parts, function(x) attr(x, "provenance")$r_sha %||% NA_character_,
                 character(1))
  if (length(unique(shas)) != 1L || anyNA(shas)) {
    stop("the shards were produced from different versions of R/:\n",
         paste(sprintf("  %s  %s", basename(files), shas), collapse = "\n"),
         "\nMerging them would put rows from different code under one ",
         "provenance block. Recompute the odd ones out.", call. = FALSE)
  }
  if (any(vapply(parts, function(x) isTRUE(attr(x, "provenance")$dirty), logical(1)))) {
    stop("at least one shard was produced from a dirty tree; its r_sha names ",
         "code that was never committed", call. = FALSE)
  }
  ns <- vapply(parts, function(x) attr(x, "provenance")$shard_n, integer(1))
  is <- vapply(parts, function(x) attr(x, "provenance")$shard_i, integer(1))
  if (length(unique(ns)) != 1L || !setequal(is, seq_len(ns[1]))) {
    stop("expected shards 1..", ns[1], " and found ", paste(sort(is), collapse = ", "),
         call. = FALSE)
  }

  grid <- do.call(rbind, parts)
  grid <- grid[order(grid$pattern, grid$theta, grid$noise, grid$seed, grid$method), ]
  rownames(grid) <- NULL
  message("merged ", length(files), " shards -> ", nrow(grid), " rows, all from R/ at ", shas[1])
} else {
  todo <- if (is.na(shard_i)) seq_len(nrow(CELLS)) else
    which((seq_len(nrow(CELLS)) - 1L) %% shard_n == (shard_i - 1L))

  message(if (is.na(shard_i)) "grid: " else sprintf("shard %d/%d: ", shard_i, shard_n),
          length(todo), " of ", nrow(CELLS), " cells, ", length(METHODS),
          " methods, ", cores, " core(s)")

  built <- new.env(parent = emptyenv())
  run_one <- function(r) {
    cell <- CELLS[r, ]
    key <- cell$pattern
    if (is.null(built[[key]])) built[[key]] <- PATTERNS[[key]]()
    one_cell(built[[key]], cell$pattern, cell$theta, cell$noise, cell$seed)
  }

  # Forked workers, not a cluster: the helpers are sourced scripts rather than a
  # package, so there is nothing to load on a worker and a fork inherits them.
  rows <- if (cores > 1L) {
    parallel::mclapply(todo, run_one, mc.cores = cores, mc.preschedule = FALSE)
  } else {
    lapply(todo, run_one)
  }
  bad <- vapply(rows, function(x) inherits(x, "try-error") || is.null(x), logical(1))
  if (any(bad)) {
    stop(sum(bad), " cell(s) failed outright: ",
         paste(utils::head(which(bad), 5), collapse = ", "), call. = FALSE)
  }

  grid <- do.call(rbind, rows)
  grid <- grid[order(grid$pattern, grid$theta, grid$noise, grid$seed, grid$method), ]
  rownames(grid) <- NULL
}

# A --quick run writes to its own file and is gitignored. It smoke-tests the
# pipeline on a handful of cells; it is not the grid the chapters read, and
# giving it the same name as the real artefact is how a book ends up reporting
# two seeds as twenty. The provenance convention only works if the committed
# file can only ever have come from a full run. A shard likewise writes its own
# file and is not the artefact.
if (!is.na(shard_i)) out <- SHARD_PATH(shard_i, shard_n)

write_run(grid, out,
          shard_i  = shard_i,
          shard_n  = shard_n,
          workers  = cores,   # provenance() already records the machine's core count
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
invisible(report_failures(grid))
