# ── Constructions ───────────────────────────────────────────────────────────
#
# Ways of building a manifold whose exact answer is still known after the
# building. This file carries the book's spine.
#
# E1 settled what that spine is. Crease patterns are not a harder benchmark
# than a Swiss roll -- at matched branch separation and matched ambient
# non-planarity they are easier, and they separate PCA from Isomap five times
# less well. What they have that no classical benchmark has is an EXACT answer
# key, and the two things that buys are the reason the book exists:
#
#   * the evaluators can be audited, because a metric can be handed the true
#     chart as a candidate embedding and asked whether it recognises it;
#   * the irreducible loss can be computed -- the smallest error ANY
#     d-dimensional embedding of a dataset could achieve.
#
# The second is what `irreducible_loss()` below is for, and it is the number
# every result in Part III should be reported against. Scoring a method at
# 0.31 says little; scoring it at 0.31 against a floor of 0.30 says the method
# is at the limit of what the data permit, and scoring it at 0.31 against a
# floor of 0.00 says it threw away everything.

# ── Product construction ────────────────────────────────────────────────────

#' The product of two folded patterns.
#'
#' Take a sample of n points from each of two patterns and pair them up: the
#' result lives in R^(3+3) and has intrinsic dimension 4, with the exact chart
#' being the pair of exact charts. Distances multiply in the Pythagorean sense,
#' so the truth stays exact and closed-form -- which is the whole point. It is
#' the only way in this book to build an object of intrinsic dimension above 2
#' whose answer is still known.
#'
#' This is what makes an irreducible-loss floor interesting. A 2-D chart
#' embedded in 2-D has a floor of zero, and nothing to say. A 4-D chart forced
#' into 2-D has a floor that is strictly positive and computable, and every
#' method can be measured against it.
product_manifold <- function(a, b) {
  stopifnot(nrow(a$X) == nrow(b$X))
  structure(list(
    X     = cbind(a$X, b$X),
    truth = cbind(a$truth, b$truth),
    facet = cbind(a$facet, b$facet),
    theta = c(a$theta, b$theta),
    seed  = c(a$seed, b$seed),
    exact_truth = isTRUE(a$exact_truth %||% TRUE) && isTRUE(b$exact_truth %||% TRUE),
    family = paste0("product(", a$family %||% "?", ",", b$family %||% "?", ")"),
    factors = list(a, b)
  ), class = c("product_sample", "manifold_sample"))
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# ── Linear lift ─────────────────────────────────────────────────────────────

#' Lift a sample into a higher ambient dimension by a random isometry.
#'
#' An orthonormal map into R^D moves the data without changing a single
#' intrinsic distance, so the chart is untouched and remains exact. What it does
#' change is the setting: real data does not arrive in three dimensions, and a
#' method that only works when the ambient dimension is small should be caught
#' by that rather than flattered by it.
#'
#' Orthonormality is the load-bearing part and is asserted, not assumed: a
#' merely random matrix would distort distances and quietly invalidate the
#' answer key.
lift <- function(sample, D = 50L, seed = NULL) {
  p <- ncol(sample$X)
  stopifnot(D >= p)
  Q <- .seeded(seed, {
    M <- matrix(stats::rnorm(D * p), D, p)
    qr.Q(qr(M))
  })
  stopifnot(nrow(Q) == D, ncol(Q) == p)
  err <- max(abs(crossprod(Q) - diag(p)))
  if (err > 1e-10) {
    stop("the lift matrix is not orthonormal (", format(err),
         "); it would change intrinsic distances and invalidate the chart.",
         call. = FALSE)
  }
  out <- sample
  out$X <- sample$X %*% t(Q)
  out$lift <- list(D = D, seed = seed)
  out
}

# ── The irreducible-loss bound ──────────────────────────────────────────────

#' The smallest reconstruction error any d-dimensional embedding could achieve.
#'
#' An alias for `metric_floor()` in R/metrics.R, kept because Chapter 8 argues
#' about the *construction* and Chapter 9 argues about the *metric*, and a
#' reader following either should find the bound under the name that chapter
#' uses.
#'
#' They were separate implementations, with comments in both files asserting
#' they measured different things -- one "for the Procrustes side", one "for the
#' co-ranking side". They did not. Measured across a product chart at every
#' target dimension, the two agree to 1.1e-16: classical-MDS eigenvalues of a
#' centred chart are the squared singular values, so
#' sqrt(tail(lambda)/sum(lambda)) and sqrt(tail(s^2)/sum(s^2)) are the same
#' number written twice. Two implementations of one bound, each documented as
#' the complement of the other, is how a book ends up quoting a floor in one
#' chapter that contradicts the floor in the next.
#'
#' What the bound is, stated once: for normalised Procrustes error against a
#' p-dimensional chart, no d-dimensional configuration can do better than the
#' tail of the chart's spectrum, because Procrustes permits translation,
#' rotation, reflection and isotropic scale, and the optimum over that group is
#' the rank-d truncation. It is exact, it depends on the data alone, and no
#' method appears in it.
#'
#' It does NOT bound a rank-based score. A co-ranking metric has its own floor
#' and this is not it.
irreducible_loss <- function(sample, d = EMBED_DIM) {
  metric_floor(sample, d)
}

#' Report a method's error against the floor rather than against zero.
#'
#' The gap is the part of the error the method is responsible for. Reporting
#' error alone at the hard end of a sweep produces "everything failed", which is
#' a shrug; reporting it against the floor produces "the best achievable here is
#' X and every method achieved 0.98X", which is a finding about a regime.
against_floor <- function(err, sample, d = EMBED_DIM) {
  fl <- irreducible_loss(sample, d)
  list(error = err, floor = fl, excess = err - fl,
       ratio = if (fl > 0) err / fl else NA_real_)
}
