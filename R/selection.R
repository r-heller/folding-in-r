# ── The pre-registered selection rule ───────────────────────────────────────
#
# Chapter 12 takes the benchmark to a real dataset and picks a method with it.
# The whole value of that chapter rests on the rule having been fixed BEFORE the
# answer was known, and the only thing that can establish that is a git
# timestamp: this file is committed in its own commit, before the grid it reads
# has ever been generated, and before `scripts/prepare-single-cell.R`'s
# deliberate stop() is removed. PLAN.md S1-11, CHAPTERS.md Chapter 10 section 8.
#
# It is written as an executable decision procedure rather than as prose because
# prose can be read generously afterwards. `select_method()` is a total function
# of the grid's columns: given a grid and a regime it returns a decision, every
# time, with no argument left to be chosen once the numbers are in.
#
# THE PARAMETERS ARE FIXED HERE AND NOWHERE ELSE. Each one is either already
# pre-registered elsewhere in the plan or is stated here for the first and last
# time:
#
#   MIN_REPORTABLE   0.02 normalised RMSE. PROJECT_CONCEPT.md's reportability
#                    threshold, and the quantity S2-3 inverts to set the seed
#                    budget. A gap smaller than this is not a finding.
#   MIN_RUN_RATE     0.90. A method that cannot run is not a candidate, however
#                    well it scores where it does run -- Chapter 12 has to
#                    actually fit the thing.
#   MIN_RESOLVING    1.0. Below it the benchmark cannot tell the methods apart
#                    at all and the rule DECLINES. This is the chapter's
#                    null-result promise, and it is the reason the rule has to
#                    exist in advance: the temptation on discovering R < 1 is to
#                    raise the seed count until something separates, which is
#                    p-hacking with a different knob.
#
# What it does NOT do is choose the regime. The theta range and noise level that
# resemble the application are Chapter 12's argument to make, in prose, from the
# data's own properties and before it fits anything -- and they are arguments to
# this function so that the choice is visible in the call rather than buried in
# the rule.

MIN_REPORTABLE <- 0.02
MIN_RUN_RATE   <- 0.90
MIN_RESOLVING  <- 1.0

# The order in which a tie is broken toward the method that assumes least. A
# method consuming ambient distance claims the least about the geometry it is
# given; one consuming neighbourhood structure claims the most. Between two
# methods a benchmark cannot separate, the book's own argument says take the
# weaker assumption.
CONSUMES_ORDER <- c("ambient", "geodesic", "neighbourhood")

#' Can the benchmark tell these methods apart in this regime?
#'
#' R = (spread ACROSS methods) / (spread WITHIN a method across seeds).
#'
#' Above 1, the differences between methods are larger than the noise between
#' repeated runs of the same method, and a ranking means something. At or below
#' 1 the benchmark has no resolving power here and any ranking read off it is
#' seed noise with an ordering imposed on it.
#'
#' Both spreads are of the same quantity -- excess over the irreducible floor --
#' so R is dimensionless and comparable across regimes.
#'
#' @return a list with `R`, the two spreads it is built from, and the per-method
#'   means, so a chapter can report the components rather than one number.
resolving_power <- function(cells) {
  stopifnot(is.data.frame(cells), all(c("method", "seed", "excess") %in% names(cells)))
  ok <- cells[is.finite(cells$excess), , drop = FALSE]
  if (!nrow(ok)) {
    return(list(R = NA_real_, between = NA_real_, within = NA_real_,
                means = numeric(0)))
  }

  means <- tapply(ok$excess, ok$method, mean)
  between <- if (length(means) > 1L) stats::sd(means) else 0

  # Within-cell, then pooled: the spread that matters is between repeated runs
  # of one method in one cell, not the spread of that method across the whole
  # regime, which is difficulty variation and belongs in the numerator.
  cell <- interaction(ok$method, ok$theta, ok$noise, drop = TRUE)
  within_by_cell <- tapply(ok$excess, cell, function(x) if (length(x) > 1L) stats::sd(x) else NA_real_)
  within <- stats::median(within_by_cell, na.rm = TRUE)

  list(R = if (is.finite(within) && within > 0) between / within else NA_real_,
       between = between, within = within, means = means)
}

#' Apply the rule.
#'
#' @param grid   the benchmark grid, as `run-benchmark-grid.R` writes it.
#' @param theta  the theta values judged to resemble the application. Chapter 12
#'               argues for these in prose, before fitting anything.
#' @param noise  the noise condition, likewise.
#' @return a list: `decision` is "select" or "decline", `method` the winner or
#'   NA, and the components any honest report of it needs.
select_method <- function(grid, theta, noise) {
  need <- c("theta", "noise", "seed", "method", "consumes", "ran", "rmse", "floor")
  missing <- setdiff(need, names(grid))
  if (length(missing)) {
    stop("the grid is missing column(s) ", paste(missing, collapse = ", "),
         ". This rule is written against the schema run-benchmark-grid.R ",
         "produces; if that schema has changed, the rule has to be re-registered ",
         "rather than adapted.", call. = FALSE)
  }

  cells <- grid[grid$theta %in% theta & grid$noise %in% noise, , drop = FALSE]
  if (!nrow(cells)) {
    stop("no cells in the stated regime (theta in {", paste(theta, collapse = ", "),
         "}, noise in {", paste(noise, collapse = ", "), "})", call. = FALSE)
  }
  cells$excess <- cells$rmse - cells$floor

  # ── 1. Eligibility ────────────────────────────────────────────────────────
  run_rate <- tapply(cells$ran, cells$method, mean)
  eligible <- names(run_rate)[run_rate >= MIN_RUN_RATE]
  excluded <- setdiff(names(run_rate), eligible)

  if (!length(eligible)) {
    return(list(decision = "decline", reason = "no method ran in this regime",
                method = NA_character_, eligible = character(0),
                excluded = excluded, run_rate = run_rate,
                resolving = NA, ranking = NULL))
  }

  fit <- cells[cells$method %in% eligible & cells$ran, , drop = FALSE]

  # ── 2. Resolving power, before any ranking is looked at ───────────────────
  rp <- resolving_power(fit)
  ranking <- sort(rp$means)

  if (!is.finite(rp$R) || rp$R <= MIN_RESOLVING) {
    return(list(decision = "decline",
                reason = sprintf(
                  "resolving power R = %s is at or below %.1f: the spread across methods does not exceed the spread across seeds within a method, so any ranking here is noise",
                  format(rp$R, digits = 3), MIN_RESOLVING),
                method = NA_character_, eligible = eligible, excluded = excluded,
                run_rate = run_rate, resolving = rp, ranking = ranking))
  }

  # ── 3. The winner, and whether the win is reportable ──────────────────────
  best  <- names(ranking)[1L]
  rest  <- ranking[-1L]
  gap   <- if (length(rest)) unname(rest[1L] - ranking[1L]) else Inf

  if (gap < MIN_REPORTABLE) {
    # A tie by the pre-registered threshold. Break it, in this order, and say
    # that is what happened -- a tie broken silently reads as a win.
    tied <- names(ranking)[ranking - ranking[1L] < MIN_REPORTABLE]
    tie_tbl <- data.frame(
      method   = tied,
      failures = as.numeric(tapply(!cells$ran, cells$method, sum)[tied]),
      consumes = match(cells$consumes[match(tied, cells$method)], CONSUMES_ORDER),
      stringsAsFactors = FALSE
    )
    tie_tbl <- tie_tbl[order(tie_tbl$failures, tie_tbl$consumes, tie_tbl$method), ]
    best <- tie_tbl$method[1L]
    return(list(decision = "select", method = best,
                reason = sprintf(
                  "the leading margin is %.4f, below the pre-registered reportable difference of %.2f: %d methods are tied and the tie is broken on failures, then on assuming least, then alphabetically",
                  gap, MIN_REPORTABLE, length(tied)),
                tied = tied, eligible = eligible, excluded = excluded,
                run_rate = run_rate, resolving = rp, ranking = ranking))
  }

  list(decision = "select", method = best,
       reason = sprintf(
         "lowest mean excess over the floor, ahead of the next method by %.4f, which exceeds the pre-registered reportable difference of %.2f, at resolving power R = %s",
         gap, MIN_REPORTABLE, format(rp$R, digits = 3)),
       tied = character(0), eligible = eligible, excluded = excluded,
       run_rate = run_rate, resolving = rp, ranking = ranking)
}
