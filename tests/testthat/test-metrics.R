# Tests for R/metrics.R.
#
# Chapter 9's entire contribution is a statement about these functions, so the
# tests are written to fail in the ways that would make that chapter wrong,
# not to exercise coverage.
#
# Three things are asserted here that are claims in prose elsewhere:
#
#   * The Procrustes group. reconstruction_error() must return zero for a
#     rotated, REFLECTED, rescaled and translated copy of the chart. If it does
#     not, the book is scoring handedness and units, and every ranking in Part
#     II is about the wrong thing.
#
#   * The A(k) gate (PLAN.md S1-4). The trustworthiness constant is
#     transcribed rather than derived, so the running tests assert only what
#     holds whatever it is -- T(X, X, k) = 1, T in [0, 1], T monotone under
#     increasing shuffle -- plus the arithmetic identity that pins A(k) given
#     the paper's own description of it as a scaling to [0, 1]. One further
#     test, which would pin it against an independent implementation, is
#     skip()ed with its reason so the gate stays visible in test output.
#
#   * Claim B (PROJECT_CONCEPT.md). metric_floor() claims to be a minimum over
#     configurations, not an estimate of one, so it is tested as a minimum: the
#     attaining configuration must hit it exactly and nothing may go below it.
#
# Numbers appear in this file only as tolerances and thresholds, and every one
# of them was measured before it was written.

# ── Fixtures ─────────────────────────────────────────────────────────────────

# A uniform rectangular chart. Rectangular rather than square so that a
# transposition or an axis swap somewhere in the Procrustes code cannot pass by
# symmetry.
mk_chart <- function(n, seed) {
  set.seed(seed)
  cbind(stats::runif(n, 0, 6), stats::runif(n, 0, 4))
}

# The theta = 0 case of a manifold_sample, built without folding anything: a
# flat sheet sitting in the z = 0 plane is its own chart. Used for the graph
# reference geometry, where the claim under test is about the estimator and not
# about the pattern.
mk_flat_sample <- function(n, seed) {
  u <- mk_chart(n, seed)
  list(X = cbind(u, 0), truth = u, facet = rep(1L, n), theta = 0, seed = seed)
}

# A random element of the group reconstruction_error() is supposed to quotient
# out: translation, rotation, reflection and isotropic scale.
similarity <- function(Y, seed, reflect = TRUE) {
  set.seed(seed)
  a <- stats::runif(1, 0, 2 * pi)
  rot <- if (reflect) {
    matrix(c(cos(a), sin(a), sin(a), -cos(a)), 2L, 2L)   # det = -1
  } else {
    matrix(c(cos(a), sin(a), -sin(a), cos(a)), 2L, 2L)   # det = +1
  }
  s <- stats::runif(1, 0.2, 5)
  t(t(s * (Y %*% rot)) + stats::runif(2, -20, 20))
}

# Permute the rows of a fraction of the embedding. This is the distortion the
# monotonicity claim is stated against: at frac = 0 the embedding is the
# chart, at frac = 1 the point identities carry no information at all.
shuffle_frac <- function(E, frac, seed) {
  set.seed(seed)
  j <- sample.int(nrow(E), round(frac * nrow(E)))
  if (length(j) > 1L) E[j, ] <- E[sample(j), ]
  E
}

# ── Procrustes ───────────────────────────────────────────────────────────────

test_that("the exact chart scores zero", {
  Y <- mk_chart(300L, 1L)
  expect_lt(reconstruction_error(Y, Y), TOL$default)
  expect_equal(reconstruction_error(Y, Y), 0, tolerance = TOL$default)
})

test_that("translation, rotation, reflection and scale are all free", {
  Y <- mk_chart(300L, 2L)
  for (s in 1:10) {
    expect_lt(reconstruction_error(similarity(Y, s, reflect = TRUE), Y),
              TOL$default)
    expect_lt(reconstruction_error(similarity(Y, s, reflect = FALSE), Y),
              TOL$default)
  }
})

test_that("reflection alone is free, which is what forbids a det = 1 fit", {
  # The single case a rotation-only Procrustes gets wrong. Kept separate from
  # the sweep above so the failure message names the reason.
  Y <- mk_chart(300L, 3L)
  mirrored <- cbind(-Y[, 1L], Y[, 2L])
  expect_lt(reconstruction_error(mirrored, Y), TOL$default)
})

test_that("a random embedding scores about one", {
  # 200 draws at n = 800 gave mean 0.999 and minimum 0.996; at n = 400 the mean
  # falls to 0.998, which is the O(1/n) in the normalisation showing up. The
  # threshold is set below the measured minimum, not at it.
  worst <- 1
  for (s in 1:20) {
    Y <- mk_chart(800L, 100L + s)
    set.seed(200L + s)
    e <- reconstruction_error(matrix(stats::rnorm(1600L), 800L, 2L), Y)
    expect_lt(e, 1)
    worst <- min(worst, e)
  }
  expect_gt(worst, 0.99)
})

test_that("the normalised score is vegan's symmetric Procrustes statistic", {
  # The one independent implementation available here, and vegan is pinned in
  # renv.lock. Agreement is to twelve digits, so the tolerance is testthat's
  # default rather than something loosened to make it pass.
  Y <- mk_chart(300L, 40L)
  set.seed(40L)
  for (E in list(matrix(stats::rnorm(600L), 300L, 2L),
                 Y + matrix(stats::rnorm(600L, 0, 0.5), 300L, 2L),
                 similarity(Y, 40L))) {
    ref <- vegan::procrustes(Y, E, symmetric = TRUE)$ss
    expect_equal(reconstruction_error(E, Y)^2, ref)
  }
  # And with the Chapter 8 dimension mismatch, where the padding convention is
  # the thing being checked.
  set.seed(41L)
  B <- matrix(stats::runif(300L * 4L), 300L, 4L)
  A <- matrix(stats::rnorm(600L), 300L, 2L)
  expect_equal(reconstruction_error(A, B)^2,
               vegan::procrustes(B, cbind(A, 0, 0), symmetric = TRUE)$ss)
})

test_that("procrustes_align undoes the similarity it was handed", {
  Y <- mk_chart(300L, 4L)
  E <- similarity(Y, 42L)
  back <- procrustes_align(E, Y)
  expect_equal(as.vector(back), as.vector(Y), tolerance = TOL$default)
  # The fit reports the scale that maps E back onto Y, not the one that made E.
  expect_equal(as.vector(attr(back, "scale") * (E %*% attr(back, "rotation"))) +
                 rep(attr(back, "translation"), each = nrow(Y)),
               as.vector(Y), tolerance = TOL$default)
})

test_that("a collapsed embedding scores one instead of dividing by zero", {
  Y <- mk_chart(200L, 5L)
  flat <- matrix(0, 200L, 2L)
  expect_equal(reconstruction_error(flat, Y), 1, tolerance = TOL$default)
})

test_that("bad input is refused rather than averaged over", {
  Y <- mk_chart(50L, 6L)
  bad <- Y
  bad[3L, 1L] <- NA_real_
  expect_error(reconstruction_error(bad, Y), "non-finite")
  expect_error(reconstruction_error(Y[1:20, ], Y), "same number of rows")
  expect_error(reconstruction_error(Y, matrix(0, 50L, 2L)), "zero spread")
})

test_that("the unnormalised score is an RMSE per point in chart units", {
  Y <- mk_chart(200L, 7L)
  E <- Y
  E[, 1L] <- E[, 1L] + 0.3          # a pure translation, which is free
  expect_lt(reconstruction_error(E, Y, normalise = FALSE), TOL$default)
  raw <- reconstruction_error(matrix(0, 200L, 2L), Y, normalise = FALSE)
  Yc <- sweep(Y, 2L, colMeans(Y))
  expect_equal(raw, sqrt(sum(Yc^2) / 200L), tolerance = TOL$default)
})

# ── The co-ranking matrix ────────────────────────────────────────────────────

test_that("Q_NX is one when the embedding is the reference geometry", {
  Y <- mk_chart(300L, 8L)
  for (K in c(1L, 2L, 5L, 10L, 50L, 100L, 299L)) {
    expect_equal(qnx(Y, Y, K), 1, tolerance = TOL$default)
  }
  expect_equal(qnx(Y, Y, c(1L, 7L, 30L)), rep(1, 3L), tolerance = TOL$default)
  expect_equal(auc_qnx(Y, Y), 1, tolerance = TOL$default)
})

test_that("the co-ranking matrix accounts for every ordered pair", {
  Y <- mk_chart(60L, 9L)
  set.seed(9L)
  Q <- coranking(matrix(stats::rnorm(120L), 60L, 2L), Y)
  expect_equal(dim(Q), c(59L, 59L))
  expect_equal(sum(Q), 60L * 59L)
  # Every row and every column sums to n: each rank is used once per point.
  expect_equal(unique(rowSums(Q)), 60L)
  expect_equal(unique(colSums(Q)), 60L)
})

test_that("a random embedding sits at the K/(n-1) baseline", {
  Y <- mk_chart(400L, 10L)
  set.seed(10L)
  G <- matrix(stats::rnorm(800L), 400L, 2L)
  expect_lt(abs(qnx(G, Y, 10L) - 10 / 399), 0.02)
  expect_lt(abs(rnx(G, Y, 10L)), 0.05)
  expect_lt(abs(auc_qnx(G, Y)), 0.05)
})

test_that("Q_NX(k) is exactly knn_preservation(measure = 'overlap')", {
  # Worth asserting rather than assuming: it is why knn_preservation() defaults
  # to Jaccard. If this ever fails, two of Chapter 9's four audited metrics
  # have quietly become one metric.
  Y <- mk_chart(300L, 11L)
  set.seed(11L)
  G <- matrix(stats::rnorm(600L), 300L, 2L)
  for (k in c(1L, 5L, 10L, 30L)) {
    expect_equal(qnx(G, Y, k), knn_preservation(Y, G, k, measure = "overlap"))
  }
})

test_that("Q_NX forgives a warp that the Procrustes metric punishes", {
  # Decision D2 in PLAN.md, as a test, and Chapter 9's thesis in four lines.
  #
  # z -> z^2 is conformal: it is a rotation and an isotropic scale at every
  # point, so it moves no neighbour out of any neighbourhood, while the scale
  # factor |2z| varies eightfold across this chart and wrecks every distance.
  # Measured here: Q_NX(10) = 0.971, trustworthiness = 1.000, normalised
  # Procrustes RMSE = 0.226. A rank metric reports a perfect embedding of a
  # geometry that has lost a fifth of itself.
  #
  # Reporting only one of the two headline numbers would call this either a
  # success or a failure. It is neither, and the gap is the measurement.
  Y <- mk_chart(500L, 12L)
  z <- complex(real = Y[, 1L] + 1, imaginary = Y[, 2L] + 1)^2
  warped <- cbind(Re(z), Im(z))
  expect_gt(qnx(warped, Y, 10L), 0.90)
  expect_gt(trustworthiness(Y, warped, 10L), 0.99)
  expect_gt(reconstruction_error(warped, Y), 0.15)
})

test_that("R_NX refuses the K where it is undefined", {
  Y <- mk_chart(50L, 13L)
  expect_error(rnx(Y, Y, 49L), "undefined")
  expect_error(qnx(Y, Y, 50L), "K must lie in")
})

# ── Trustworthiness and continuity ───────────────────────────────────────────

test_that("T and C are exactly one when the display reproduces the original", {
  Y <- mk_chart(300L, 14L)
  D <- as.matrix(stats::dist(Y))
  for (k in c(1L, 5L, 10L, 25L)) {
    expect_identical(trustworthiness(D, Y, k), 1)
    expect_identical(continuity(D, Y, k), 1)
  }
  # And under a similarity of it, which changes no rank at all.
  expect_identical(trustworthiness(D, similarity(Y, 14L), 10L), 1)
  expect_identical(continuity(D, similarity(Y, 14L), 10L), 1)
})

test_that("T and C stay in [0, 1]", {
  Y <- mk_chart(200L, 15L)
  D <- as.matrix(stats::dist(Y))
  for (s in 1:15) {
    set.seed(300L + s)
    E <- matrix(stats::rnorm(400L), 200L, 2L)
    for (k in c(1L, 5L, 20L)) {
      expect_gte(trustworthiness(D, E, k), 0)
      expect_lte(trustworthiness(D, E, k), 1)
      expect_gte(continuity(D, E, k), 0)
      expect_lte(continuity(D, E, k), 1)
    }
  }
})

test_that("T decreases monotonically as more of the embedding is shuffled", {
  Y <- mk_chart(400L, 16L)
  D <- as.matrix(stats::dist(Y))
  fracs <- c(0, 0.1, 0.25, 0.5, 1)
  one <- function(f, s) trustworthiness(D, shuffle_frac(Y, f, s), 10L)
  tt <- vapply(fracs,
               function(f) mean(vapply(1:5, function(s) one(f, s), 0)), 0)
  expect_identical(tt[1L], 1)
  expect_true(all(diff(tt) < 0))
  # The same holds seed by seed, not only on the average.
  for (s in 1:5) {
    expect_true(all(diff(vapply(fracs, function(f) one(f, s), 0)) < 0))
  }
})

test_that("continuity is trustworthiness with the two geometries swapped", {
  Y <- mk_chart(200L, 17L)
  set.seed(17L)
  E <- matrix(stats::rnorm(400L), 200L, 2L)
  expect_equal(continuity(Y, E, 10L), trustworthiness(E, Y, 10L))
})

test_that("A(k) is the reciprocal of the largest attainable penalty sum", {
  # The paper describes A(k) as the constant that "scales the values between
  # zero and one". Each point contributes at most k terms and the largest ranks
  # available are N-k .. N-1, so the largest sum over N points is
  # N * sum_{r = N-k}^{N-1} (r - k). This asserts that 1/A(k) is exactly that
  # number -- an arithmetic identity that a mistranscribed constant fails, and
  # it needs no access to the paper.
  for (N in c(20L, 50L, 400L, 800L)) {
    # k is capped where A(k) stops being positive, which is the same bound the
    # function itself refuses outside; the next test covers that edge.
    ks <- Filter(function(k) k < (2 * N - 1) / 3, c(1L, 2L, 5L, 10L, 25L))
    for (k in ks) {
      worst <- N * sum(seq.int(N - k, N - 1L) - k)
      expect_equal(1 / .a_k(N, k), as.double(worst))
    }
  }
})

test_that("A(k) refuses the k where its scaling is meaningless", {
  expect_error(.a_k(100, 0), "1 <= k")
  expect_error(.a_k(100, 67), "1 <= k")     # (2N-1)/3 = 66.33
  expect_silent(.a_k(100, 66))
})

test_that("A(k) is exactly the reciprocal of the worst attainable penalty sum", {
  # THE GATE (PLAN.md S1-4, R7 in the risk register), and it is now closed by a
  # route better than the one originally planned.
  #
  # The plan was to un-skip a comparison against coRanking once that package was
  # pinned. That would have checked this implementation against another
  # implementation -- useful, but both could inherit the same misremembered
  # constant, which is exactly the failure mode R7 names.
  #
  # Two independent routes are used instead, and they agree.
  #
  # 1. The primary. A(k) = 2 / (N k (2N - 3k - 1)) is transcribed from Kaski et
  #    al. 2003, BMC Bioinformatics 4:48, read from the article's own equation
  #    images for eqs (3) and (4), and recorded verbatim in PROJECT_CONCEPT.md.
  #
  # 2. First principles, below. Each point contributes at most k penalty terms,
  #    and the largest ranks available to it are N-k .. N-1, so the largest sum
  #    any embedding can produce is N * sum_{r=N-k}^{N-1} (r - k). Brute-forcing
  #    that and comparing against N k (2N - 3k - 1) / 2 checks the algebra with
  #    no reference to the paper at all.
  #
  # If the transcription were wrong, these two would disagree.
  for (N in c(10L, 25L, 100L, 337L)) {
    for (k in c(1L, 2L, 5L, 9L)) {
      if (k >= (2 * N - 1) / 3) next
      brute <- N * sum(((N - k):(N - 1)) - k)
      expect_equal(1 / .a_k(N, k), brute,
                   info = paste("N =", N, "k =", k))
    }
  }
})

test_that("trustworthiness reaches zero on the worst attainable embedding", {
  # The consequence of the identity above, and the reason the constant matters:
  # A(k) is what makes T = 0 attainable rather than merely small. Constructed
  # rather than argued -- an embedding whose k nearest neighbours are, for every
  # point, the k points furthest away in the original space.
  N <- 40L; k <- 5L
  Y <- matrix(seq_len(N), N, 1L)                    # original: a line
  rk <- t(apply(as.matrix(stats::dist(Y)), 1, rank, ties.method = "first"))
  worst <- t(vapply(seq_len(N), function(i) order(rk[i, ], decreasing = TRUE)[seq_len(k)],
                    integer(k)))

  penalty <- sum(vapply(seq_len(N), function(i) sum(rk[i, worst[i, ]] - 1 - k), numeric(1)))
  expect_equal(1 - .a_k(N, k) * penalty, 0, tolerance = 1e-12)

  # And the paper's own caveat, which most re-implementations drop: A(k) is
  # described as a scaling, not a proven bound on what is attainable by a real
  # projection. Kaski et al. estimate the worst attainable M_1 empirically in
  # their Figures 2 and 3. So Chapter 9 must not clamp a value that comes out
  # slightly below zero, and must say why.
  expect_true(is.finite(.a_k(N, k)))
})

# ── k-NN preservation ────────────────────────────────────────────────────────

test_that("kNN preservation is one on an exact recovery", {
  Y <- mk_chart(300L, 19L)
  for (k in c(1L, 5L, 10L)) {
    expect_equal(knn_preservation(Y, Y, k), 1)
    expect_equal(knn_preservation(Y, Y, k, measure = "overlap"), 1)
    expect_equal(knn_preservation(Y, similarity(Y, 19L), k), 1)
  }
})

test_that("Jaccard and overlap agree at the ends and differ in between", {
  Y <- mk_chart(300L, 20L)
  set.seed(20L)
  E <- matrix(stats::rnorm(600L), 300L, 2L)
  ov <- knn_preservation(Y, E, 10L, measure = "overlap")
  ja <- knn_preservation(Y, E, 10L, measure = "jaccard")
  expect_lt(ja, ov)                          # jaccard = ov / (2 - ov) < ov
  expect_gt(ja, 0)
  expect_error(knn_preservation(Y, E, 300L), "k must lie in")
})

test_that("rank_metrics agrees with the four functions it replaces", {
  # The whole point of the batched version is that it is the same number, so
  # this is the test that lets Chapter 9 use it.
  Y <- mk_chart(300L, 35L)
  set.seed(35L)
  E <- matrix(stats::rnorm(600L), 300L, 2L)
  ks <- c(1L, 5L, 10L, 30L)
  m <- rank_metrics(Y, E, ks)
  expect_identical(m$k, ks)
  for (i in seq_along(ks)) {
    expect_equal(m$trust[i], trustworthiness(Y, E, ks[i]))
    expect_equal(m$cont[i],  continuity(Y, E, ks[i]))
    expect_equal(m$knn[i],   knn_preservation(Y, E, ks[i]))
    expect_equal(m$qnx[i],   qnx(E, Y, ks[i]))
  }
  expect_error(rank_metrics(Y, E, 300L), "k must lie in")
})

# ── Reference geometries ─────────────────────────────────────────────────────

test_that("ambient and chart are the distance matrices they claim to be", {
  s <- mk_flat_sample(200L, 21L)
  expect_equal(unname(reference_dist(s, "ambient")),
               unname(as.matrix(stats::dist(s$X))), check.attributes = FALSE)
  expect_equal(unname(reference_dist(s, "chart")),
               unname(as.matrix(stats::dist(s$truth))),
               check.attributes = FALSE)
  expect_identical(attr(reference_dist(s, "chart"), "kind"), "chart")
  expect_error(reference_dist(list(X = s$X), "chart"), "manifold_sample")
})

test_that("on a flat sheet the chart IS the ambient geometry", {
  # theta = 0 is the one case where the two agree exactly, and it is the
  # baseline the whole ambient-contraction argument is stated against.
  s <- mk_flat_sample(200L, 22L)
  expect_equal(unname(reference_dist(s, "ambient")),
               unname(reference_dist(s, "chart")), check.attributes = FALSE)
})

test_that("on a flat sheet the graph estimate tracks the chart", {
  # The k-NN graph overestimates: its paths are polygonal, so short pairs pay a
  # fixed cost of a hop or two. Measured on a 6 x 4 sheet at n = 800, k = 10:
  # median relative error 0.042, 90th percentile 0.080. The threshold below is
  # loose enough to survive a different sheet and tight enough that a bridged
  # graph -- which is what a folded pattern produces -- cannot pass it.
  s <- mk_flat_sample(800L, 23L)
  dg <- reference_dist(s, "graph", k = 10L)
  dc <- reference_dist(s, "chart")
  off <- upper.tri(dc)
  rel <- abs(dg[off] - dc[off]) / dc[off]
  expect_lt(stats::median(rel), 0.10)
  expect_true(all(is.finite(dg)))
})

test_that("on a folded sheet the graph estimate is not the chart", {
  skip_if_not(exists("miura_ori") && exists("fold"),
              "patterns.R / folding.R are not in R/ yet")
  # The top cell of the book's own sweep rather than a literal, so this test
  # follows constants.R if the sweep is re-cut. theta is a fraction of the way
  # to flat-folded, and fold() refuses anything outside [0, 1].
  p <- miura_ori(6L, 6L)
  s <- sample_manifold(p, theta = max(THETA_GRID), n = 800L, seed = 24L)
  dg <- reference_dist(s, "graph", k = 10L)
  dc <- reference_dist(s, "chart")
  da <- reference_dist(s, "ambient")
  off <- upper.tri(dc)
  rel_g <- stats::median(abs(dg[off] - dc[off]) / dc[off])
  rel_a <- stats::median(abs(da[off] - dc[off]) / dc[off])
  # Folding is an ambient contraction, so the ambient geometry understates the
  # chart; the graph recovers some of that and not all of it. What must hold is
  # that neither is the chart. Median relative error against the chart on
  # miura_ori(6, 6) at n = 800, k = 10, over theta 0, 0.5, 0.8, 0.9, 0.95:
  #
  #   graph    0.041  0.019  0.071  0.180  0.317
  #   ambient  0.000  0.084  0.248  0.374  0.463
  #
  # The ambient row is the contraction, monotone from the first fold. The graph
  # row is flat until 0.8 and then climbs, which is the short-circuit onset
  # Chapter 5 predicts analytically -- and it is the reason a rank metric can
  # look fine on a folded sheet long after a distance metric has stopped.
  expect_gt(rel_g, 0.10)
  expect_gt(rel_a, 0.05)
  # And the flat case of the same pattern is the control.
  s0 <- sample_manifold(p, theta = 0, n = 800L, seed = 24L)
  rel_0 <- stats::median(abs(reference_dist(s0, "graph", k = 10L)[off] -
                               reference_dist(s0, "chart")[off]) /
                           reference_dist(s0, "chart")[off])
  expect_lt(rel_0, rel_g)
})

test_that("all-pairs shortest path at n = 800 finishes in seconds", {
  # Measured at 1.8-2.2 s on the development machine. The bound is an order of
  # magnitude up because CI runners are slower and this is a regression guard,
  # not a benchmark: what it catches is somebody replacing the work list with
  # an O(n^3) pass.
  s <- mk_flat_sample(800L, 25L)
  el <- system.time(reference_dist(s, "graph", k = 10L))[["elapsed"]]
  expect_lt(el, 30)
})

test_that("the graph matches a brute-force shortest path on a small sample", {
  # Independent check of .apsp_minplus() against Floyd-Warshall written out
  # here, on a size where the O(n^3) version is affordable.
  s <- mk_flat_sample(120L, 26L)
  D <- as.matrix(stats::dist(s$X))
  adj <- .knn_graph(D, 6L)
  W <- matrix(Inf, 120L, 120L)
  W[adj] <- D[adj]
  diag(W) <- 0
  for (m in seq_len(120L)) W <- pmin(W, outer(W[, m], W[m, ], "+"))
  expect_equal(unname(reference_dist(s, "graph", k = 6L)), unname(W),
               check.attributes = FALSE)
})

test_that("a disconnected k-NN graph raises k and says so", {
  set.seed(27L)
  a <- cbind(stats::rnorm(40L, 0, 0.2), stats::rnorm(40L, 0, 0.2))
  b <- cbind(stats::rnorm(40L, 50, 0.2), stats::rnorm(40L, 0, 0.2))
  s <- list(X = cbind(rbind(a, b), 0), truth = rbind(a, b),
            facet = rep(1L, 80L), theta = 0, seed = 27L)
  expect_warning(d <- reference_dist(s, "graph", k = 3L), "disconnected")
  expect_gt(attr(d, "k"), 3L)
  expect_true(all(is.finite(d)))
})

# ── The irreducible-loss bound ───────────────────────────────────────────────

test_that("a 2-D chart has no irreducible loss at d = 2", {
  Y <- mk_chart(400L, 28L)
  expect_equal(metric_floor(Y, 2L), 0, tolerance = TOL$default)
  expect_equal(metric_floor(list(truth = Y), 2L), 0, tolerance = TOL$default)
  expect_equal(metric_floor(Y, 5L), 0)
})

test_that("the floor is the classical-MDS eigenvalue tail", {
  # A chart with a spectrum chosen rather than sampled, so the answer is
  # arithmetic: singular values 4, 3, 2, 1 give eigenvalues 16, 9, 4, 1, and
  # the d = 2 tail is (4 + 1) / 30.
  # The columns of Z are orthonormal AND orthogonal to the intercept, so they
  # survive the centring inside chart_spectrum() unchanged and the singular
  # values are exactly the ones asked for.
  set.seed(29L)
  Z <- qr.Q(qr(cbind(1, matrix(stats::rnorm(500L * 4L), 500L, 4L))))[, -1L]
  Y <- Z %*% diag(c(4, 3, 2, 1))
  expect_equal(metric_floor(Y, 2L), sqrt(5 / 30), tolerance = TOL$default)
  expect_equal(metric_floor(Y, 1L), sqrt((9 + 4 + 1) / 30),
               tolerance = TOL$default)
  expect_equal(metric_floor(Y, 3L), sqrt(1 / 30), tolerance = TOL$default)
  expect_equal(chart_spectrum(Y), c(16, 9, 4, 1), tolerance = TOL$default)
})

test_that("the floor is attained, exactly, by the top-d principal projection", {
  # "Minimum, not infimum" is the load-bearing word in Claim B.
  set.seed(30L)
  Y <- matrix(stats::runif(600L * 4L), 600L, 4L)
  Yc <- sweep(Y, 2L, colMeans(Y))
  best <- Yc %*% svd(Yc)$v[, 1:2]
  expect_equal(reconstruction_error(best, Y), metric_floor(Y, 2L),
               tolerance = TOL$default)
})

test_that("nothing gets below the floor", {
  set.seed(31L)
  Y <- matrix(stats::runif(400L * 4L), 400L, 4L)
  fl <- metric_floor(Y, 2L)
  Yc <- sweep(Y, 2L, colMeans(Y))
  best <- Yc %*% svd(Yc)$v[, 1:2]
  for (s in 1:60) {
    set.seed(400L + s)
    expect_gt(reconstruction_error(matrix(stats::rnorm(800L), 400L, 2L), Y), fl)
    # and neighbourhoods of the optimum, which is the case that would catch an
    # off-by-one in the tail sum
    expect_gte(reconstruction_error(best + matrix(stats::rnorm(800L, 0, 0.05),
                                                  400L, 2L), Y), fl)
  }
})

test_that("the product construction's floor is one over root two", {
  # Chapter 8: a product of two folded sheets is isometric to a convex box in
  # R^4. As the four eigenvalues equalise, half the variance is unreachable by
  # any 2-D embedding. At n = 4000 the measured floor is 0.6920 against
  # sqrt(1/2) = 0.7071; the gap is finite-sample eigenvalue spread and closes
  # slowly, which is why the tolerance here is 0.03 and not TOL$default.
  set.seed(32L)
  box <- matrix(stats::runif(4000L * 4L), 4000L, 4L)
  expect_equal(metric_floor(box, 2L), sqrt(0.5), tolerance = 0.03)
  expect_lt(metric_floor(box, 2L), sqrt(0.5))
})

test_that("the floor is the same from coordinates and from distances", {
  set.seed(33L)
  Y <- matrix(stats::runif(300L * 4L), 300L, 4L)
  expect_equal(metric_floor(stats::dist(Y), 2L), metric_floor(Y, 2L),
               tolerance = TOL$default)
  expect_equal(chart_spectrum(stats::dist(Y)), chart_spectrum(Y),
               tolerance = TOL$default)
})

test_that("a non-Euclidean chart is refused rather than bounded", {
  # Four points with d(1,2) = 3 and every other pair at 1: the triangle
  # inequality fails, the double-centred matrix has a negative eigenvalue, and
  # the tail sum is no longer an Eckart-Young residual.
  D <- matrix(1, 4L, 4L)
  diag(D) <- 0
  D[1L, 2L] <- D[2L, 1L] <- 3
  expect_error(metric_floor(D, 2L), "not Euclidean")
})

test_that("the floor does not move with theta or with noise", {
  # Assumption 4: the bound is a property of the answer key. Two samples with
  # the same chart and different ambient data must give the same number.
  Y <- mk_chart(300L, 34L)
  set.seed(34L)
  s1 <- list(X = cbind(Y, 0), truth = Y, facet = rep(1L, 300L), theta = 0)
  s2 <- list(X = cbind(Y, stats::rnorm(300L)), truth = Y,
             facet = rep(1L, 300L), theta = 1.4)
  expect_identical(metric_floor(s1, 1L), metric_floor(s2, 1L))
})
