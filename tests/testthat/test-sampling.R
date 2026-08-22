# Tests for R/sampling.R.
#
# R/README.md invariant 5 is the headline: sample_manifold() returns truth rows
# that lie in the facet they claim and X rows that lie on the folded surface.
# Three further properties are asserted here because every number in the book
# depends on them and nothing else in the tree checks them -- the sampler is
# uniform over surface area rather than over facets, a sample is reproducible
# from its seed, and drawing one does not cost the caller their RNG stream.
#
# Every tolerance below is a measured number and the comment beside it records
# what was measured, on the patterns and seeds named in the test.
#
# The facet areas here come from the shoelace formula on the whole polygon and
# the facet planes from a cross product of two folded edges. Neither route goes
# through sampling.R's own fan triangulation or its facet frames, so a common
# error in that arithmetic cannot make these tests agree with it.

# ── Fixtures ─────────────────────────────────────────────────────────────────

# waterbomb() stops by design while PLAN.md E2 is open, so it drops out here
# rather than being named and skipped. Any family that builds and folds joins
# the sweep automatically, which is what makes this file survive E2 either way.
sampling_patterns <- function() {
  builders <- c(miura = "miura_ori", yoshimura = "yoshimura",
                waterbomb = "waterbomb")
  out <- list()
  for (fam in names(builders)) {
    size <- PATTERN_GRID[[fam]]
    p <- try(do.call(builders[[fam]], list(size[["nx"]], size[["ny"]])),
             silent = TRUE)
    if (!inherits(p, "crease_pattern")) next
    if (inherits(try(fold(p, 0.8), silent = TRUE), "try-error")) next
    out[[fam]] <- p
  }
  out
}

# Shoelace area of one polygon, independent of .fan_triangles().
polygon_area <- function(poly) {
  k <- nrow(poly)
  nxt <- c(seq_len(k - 1L) + 1L, 1L)
  abs(sum(poly[, 1L] * poly[nxt, 2L] - poly[nxt, 1L] * poly[, 2L])) / 2
}

facet_area_share <- function(pattern) {
  a <- vapply(pattern$facets,
              function(f) polygon_area(pattern$vertices[f, 1:2, drop = FALSE]),
              numeric(1L))
  a / sum(a)
}

# Signed distance from each point to the facet, positive outside. Valid for the
# convex facets these families build. The orientation is read off the polygon
# rather than assumed, so a clockwise facet does not silently invert the sign
# and turn this into a test that everything is outside.
outside_facet <- function(pts, poly) {
  k <- nrow(poly)
  nxt <- c(seq_len(k - 1L) + 1L, 1L)
  s <- sign(sum(poly[, 1L] * poly[nxt, 2L] - poly[nxt, 1L] * poly[, 2L]))
  worst <- rep(-Inf, nrow(pts))
  for (e in seq_len(k)) {
    a <- poly[e, ]
    d <- poly[nxt[e], ] - a
    len <- sqrt(sum(d^2))
    worst <- pmax(worst, ((pts[, 1L] - a[1L]) * (s * d[2L]) +
                          (pts[, 2L] - a[2L]) * (-s * d[1L])) / len)
  }
  worst
}

# Distance from each point to the plane of a folded facet.
plane_offset <- function(pts, poly3) {
  d3 <- sweep(poly3, 2L, poly3[1L, ])
  u1 <- d3[2L, ] / sqrt(sum(d3[2L, ]^2))
  j  <- which.max(rowSums(d3^2) - as.vector(d3 %*% u1)^2)
  u2 <- d3[j, ]
  nrm <- c(u1[2L] * u2[3L] - u1[3L] * u2[2L],
           u1[3L] * u2[1L] - u1[1L] * u2[3L],
           u1[1L] * u2[2L] - u1[2L] * u2[1L])
  nrm <- nrm / sqrt(sum(nrm^2))
  abs(as.vector(sweep(pts, 2L, poly3[1L, ]) %*% nrm))
}

chart_diameter <- function(pattern) {
  max(stats::dist(pattern$vertices[, 1:2, drop = FALSE]))
}

# ── The fixture is real ──────────────────────────────────────────────────────

test_that("the patterns this file samples exist and fold", {
  pats <- sampling_patterns()
  # Miura and Yoshimura are settled per PROJECT_CONCEPT.md. If either were
  # missing, every loop below would iterate over a shorter list and pass by
  # testing less.
  expect_true(all(c("miura", "yoshimura") %in% names(pats)))
  for (p in pats) expect_s3_class(p, "crease_pattern")
})

# ── 1. Uniform over area, not over facets ────────────────────────────────────

test_that("facets are drawn in proportion to their area", {
  n <- 200000L
  for (p in sampling_patterns()) {
    share <- facet_area_share(p)
    s <- sample_manifold(p, theta = 0.7, n = n, seed = 2024L, boundary = TRUE)
    obs <- tabulate(s$facet, nbins = length(p$facets)) / n
    # Measured over 12 seeds at this n: worst 1.03e-3 for the 36-facet Miura,
    # 8.6e-4 for the 72-facet Yoshimura. The bound is the sampling error of a
    # multinomial, so it scales as 1/sqrt(n) and is not a property of the code.
    expect_lt(max(abs(obs - share)), 0.005)
  }
})

test_that("unequal facets are drawn unequally", {
  # The shipped patterns cannot test this. Both tessellate the sheet with
  # congruent facets -- measured max|share - 1/F| is 4.9e-17 for Miura and
  # 3.8e-17 for Yoshimura, i.e. exact congruence -- so on them the
  # area-proportional sampler and the facet-proportional one are the same
  # sampler and the check above would pass either way.
  #
  # This fixture is a real Miura with one parallelogram cut down to half of
  # itself, which is exactly the shape a boundary strip has in a pattern that
  # has one. fold() is untouched by the edit: the Miura placement is computed
  # from the vertex lattice, not from the facet list.
  p <- miura_ori(2L, 2L)
  p$facets[[1L]] <- p$facets[[1L]][1:3]

  share <- facet_area_share(p)
  # 1/7, 2/7, 2/7, 2/7. A facet-uniform sampler would sit 0.107 away from that
  # on the cut facet, twenty times the tolerance asserted below.
  expect_gt(max(abs(share - 1 / length(share))), 0.1)

  n <- 200000L
  s <- sample_manifold(p, theta = 0.7, n = n, seed = 2024L, boundary = TRUE)
  obs <- tabulate(s$facet, nbins = length(p$facets)) / n
  # Measured over 12 seeds: worst 2.7e-3.
  expect_lt(max(abs(obs - share)), 0.005)
})

# ── 2. truth lies in the facet it claims ─────────────────────────────────────

test_that("every truth row lies inside the facet it claims", {
  for (p in sampling_patterns()) {
    for (bd in c(TRUE, FALSE)) {
      s <- sample_manifold(p, theta = 0.8, n = N_DEFAULT, seed = 7L,
                           boundary = bd)
      worst <- -Inf
      for (k in unique(s$facet)) {
        ii <- which(s$facet == k)
        worst <- max(worst, max(outside_facet(
          s$truth[ii, , drop = FALSE],
          p$vertices[p$facets[[k]], 1:2, drop = FALSE])))
      }
      # Signed, so a point strictly inside gives a negative number and this
      # bound is the closest approach to an edge, not a violation of it.
      # Measured across both patterns, both boundary settings, and theta over
      # THETA_COARSE and 0.8: the closest any point came to its facet's edge
      # was 7.2e-6 on the inside for Yoshimura and 2.7e-4 for Miura. Nothing
      # landed outside, at any tolerance.
      expect_lt(worst, 1e-12)
    }
  }
})

# ── 3. X lies on the folded surface ──────────────────────────────────────────

test_that("every X row lies in the plane of its folded facet", {
  for (p in sampling_patterns()) {
    for (th in THETA_COARSE) {
      s <- sample_manifold(p, theta = th, n = N_DEFAULT, seed = 13L,
                           noise = list(type = "none", sd = 0))
      f <- fold(p, th)
      worst <- 0
      for (k in unique(s$facet)) {
        ii <- which(s$facet == k)
        worst <- max(worst, max(plane_offset(
          s$X[ii, , drop = FALSE],
          f$vertices3[p$facets[[k]], 1:3, drop = FALSE])))
      }
      # Measured worst over this sweep: 5.6e-16 for Miura, 2.2e-16 for
      # Yoshimura, against a tolerance of 1e-10.
      expect_lt(worst, TOL$on_surface)
    }
  }
})

# ── 4. The isometry survives the sampler ─────────────────────────────────────

test_that("within a facet, ambient distance equals chart distance", {
  for (p in sampling_patterns()) {
    for (th in THETA_COARSE) {
      s <- sample_manifold(p, theta = th, n = N_DEFAULT, seed = 21L)
      worst <- 0
      for (k in unique(s$facet)) {
        ii <- which(s$facet == k)
        if (length(ii) < 2L) next
        if (length(ii) > 40L) ii <- ii[seq_len(40L)]
        worst <- max(worst, max(abs(
          as.vector(stats::dist(s$X[ii, , drop = FALSE])) -
          as.vector(stats::dist(s$truth[ii, , drop = FALSE])))))
      }
      # Measured worst over this sweep: 1.3e-15 for Miura, 6.7e-16 for
      # Yoshimura, against a tolerance of 1e-10. This is invariant 1 read
      # through the sampler rather than at the vertices, which is the only
      # place it could be broken by interpolating vertices3 instead of
      # applying the facet's rigid motion.
      expect_lt(worst, TOL$isometry)
    }
  }
})

test_that("at theta = 0 the whole sample is a rigid image of the chart", {
  # Not just within a facet: invariant 2 says the flat sheet is the chart up to
  # a rigid motion, so at theta = 0 every pairwise ambient distance equals its
  # chart distance, creases crossed included. Measured worst: exactly 0 for
  # Miura, 8.9e-16 for Yoshimura.
  for (p in sampling_patterns()) {
    s <- sample_manifold(p, theta = 0, n = 300L, seed = 33L)
    d <- max(abs(as.vector(stats::dist(s$X)) - as.vector(stats::dist(s$truth))))
    expect_lt(d, TOL$isometry)
  }
})

# ── 5. Reproducibility and the caller's RNG stream ───────────────────────────

test_that("a seed reproduces the sample exactly", {
  p <- sampling_patterns()[["miura"]]
  for (nz in list(list(type = "none", sd = 0),
                  list(type = "ambient", sd = 0.02),
                  list(type = "outlier", sd = 0.05))) {
    a <- sample_manifold(p, theta = 0.9, n = 500L, noise = nz, seed = 11L)
    b <- sample_manifold(p, theta = 0.9, n = 500L, noise = nz, seed = 11L)
    expect_identical(a$X, b$X)
    expect_identical(a$truth, b$truth)
    expect_identical(a$facet, b$facet)
    expect_identical(a$seed, 11L)
  }
  other <- sample_manifold(p, theta = 0.9, n = 500L, seed = 12L)
  same  <- sample_manifold(p, theta = 0.9, n = 500L, seed = 11L)
  expect_false(identical(same$truth, other$truth))
})

test_that("sampling does not perturb the caller's RNG stream", {
  p <- sampling_patterns()[["miura"]]

  set.seed(999L)
  before <- get(".Random.seed", envir = globalenv())
  invisible(sample_manifold(p, theta = 0.9, n = 500L, seed = 11L,
                            noise = list(type = "outlier", sd = 0.05)))
  expect_identical(get(".Random.seed", envir = globalenv()), before)

  # The same claim stated where it bites: the caller's next draws are the draws
  # they would have got had the sampler never been called.
  set.seed(999L)
  want <- stats::runif(5L)
  set.seed(999L)
  invisible(sample_manifold(p, theta = 0.9, n = 500L, seed = 11L))
  expect_identical(stats::runif(5L), want)

  # And the branch for a session that has never drawn a random number: the
  # sampler must leave .Random.seed absent rather than invent one, because a
  # left-behind seed would make the caller's first draw depend on whether they
  # had sampled first.
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    rm(".Random.seed", envir = globalenv())
  }
  invisible(sample_manifold(p, theta = 0.9, n = 200L, seed = 11L))
  expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  set.seed(1L)
})

test_that("without a seed the sample is fresh and says so", {
  p <- sampling_patterns()[["miura"]]
  set.seed(4L)
  a <- sample_manifold(p, theta = 0.9, n = 300L)
  b <- sample_manifold(p, theta = 0.9, n = 300L)
  expect_true(is.na(a$seed))
  expect_false(identical(a$truth, b$truth))
})

# ── Noise ────────────────────────────────────────────────────────────────────

test_that("noise moves X and never truth", {
  p <- sampling_patterns()[["miura"]]
  clean <- sample_manifold(p, theta = 0.9, n = N_DEFAULT, seed = 5L)
  for (nz in list(list(type = "ambient", sd = 0.02),
                  list(type = "outlier", sd = 0.05))) {
    dirty <- sample_manifold(p, theta = 0.9, n = N_DEFAULT, noise = nz,
                             seed = 5L)
    expect_identical(dirty$truth, clean$truth)
    expect_identical(dirty$facet, clean$facet)
    expect_false(identical(dirty$X, clean$X))
  }
  # sd = 0 is the identity, so switching the model on cannot displace anything
  # by itself.
  zero <- sample_manifold(p, theta = 0.9, n = N_DEFAULT, seed = 5L,
                          noise = list(type = "ambient", sd = 0))
  expect_identical(zero$X, clean$X)
})

test_that("ambient sd is a multiple of the chart diameter", {
  p <- sampling_patterns()[["miura"]]
  diam <- chart_diameter(p)
  clean <- sample_manifold(p, theta = 0.9, n = N_DEFAULT, seed = 5L)
  for (sd in c(0.01, 0.05)) {
    dirty <- sample_manifold(p, theta = 0.9, n = N_DEFAULT, seed = 5L,
                             noise = list(type = "ambient", sd = sd))
    ratio <- stats::sd(as.vector(dirty$X - clean$X)) / (sd * diam)
    # Measured over 8 seeds x sd in {0.01, 0.02, 0.05} on both patterns: worst
    # |ratio - 1| was 0.034. This is the sampling error of an sd estimated from
    # 2,400 draws, not a bias.
    expect_lt(abs(ratio - 1), 0.06)
  }
  # The scale is read from the chart, so it does not drift along the theta
  # sweep as the folded pattern closes up. Same seed, same displacements.
  flat    <- sample_manifold(p, theta = 0, n = N_DEFAULT, seed = 5L,
                             noise = list(type = "ambient", sd = 0.02))
  flat0   <- sample_manifold(p, theta = 0, n = N_DEFAULT, seed = 5L)
  folded  <- sample_manifold(p, theta = 1, n = N_DEFAULT, seed = 5L,
                             noise = list(type = "ambient", sd = 0.02))
  folded0 <- sample_manifold(p, theta = 1, n = N_DEFAULT, seed = 5L)
  expect_equal(flat$X - flat0$X, folded$X - folded0$X)
})

test_that("the outlier model displaces a fixed fraction, far", {
  p <- sampling_patterns()[["miura"]]
  diam <- chart_diameter(p)
  clean <- sample_manifold(p, theta = 0.9, n = N_DEFAULT, seed = 5L)
  dirty <- sample_manifold(p, theta = 0.9, n = N_DEFAULT, seed = 5L,
                           noise = list(type = "outlier", sd = 0.05))
  moved <- sqrt(rowSums((dirty$X - clean$X)^2))
  expect_equal(sum(moved > 0), round(0.05 * N_DEFAULT))
  expect_equal(moved[moved > 0], rep(0.5 * diam, sum(moved > 0)))
  # frac is the name that says what 0.05 means, and wins when both are given.
  named <- sample_manifold(p, theta = 0.9, n = N_DEFAULT, seed = 5L,
                           noise = list(type = "outlier", frac = 0.05,
                                        sd = 0.9))
  expect_identical(named$X, dirty$X)
})

test_that("an unknown noise type is an error, not a silent no-op", {
  p <- sampling_patterns()[["miura"]]
  expect_error(sample_manifold(p, theta = 0.5, n = 50L, seed = 1L,
                               noise = list(type = "gaussian", sd = 0.1)),
               "unknown noise")
})

# ── boundary = ───────────────────────────────────────────────────────────────

test_that("boundary = FALSE clears a margin of the sheet edge", {
  for (p in sampling_patterns()) {
    edge <- p$creases[p$creases$assignment == "B", , drop = FALSE]
    p0 <- p$vertices[edge$i, 1:2, drop = FALSE]
    p1 <- p$vertices[edge$j, 1:2, drop = FALSE]
    margin <- .boundary_margin(p)

    trimmed <- sample_manifold(p, theta = 0.6, n = N_DEFAULT, seed = 3L,
                               boundary = FALSE)
    full    <- sample_manifold(p, theta = 0.6, n = N_DEFAULT, seed = 3L,
                               boundary = TRUE)
    expect_identical(nrow(trimmed$X), N_DEFAULT)
    expect_identical(nrow(full$X), N_DEFAULT)
    expect_gte(min(.dist_to_segments(trimmed$truth, p0, p1)), margin)
    # And the trimming is doing something. Measured: the untrimmed draw reaches
    # to 4.4e-4 of the edge on Miura and 2.0e-4 on Yoshimura, against a margin
    # of 0.5, so the assertion above is not vacuously true of any draw.
    expect_lt(min(.dist_to_segments(full$truth, p0, p1)), margin)
  }
})

# ── The object contract ──────────────────────────────────────────────────────

test_that("the returned object matches the manifold_sample contract", {
  p <- sampling_patterns()[["yoshimura"]]
  s <- sample_manifold(p, theta = 0.9, n = 137L, seed = 8L,
                       noise = list(type = "ambient", sd = 0.01))
  expect_s3_class(s, "manifold_sample")
  expect_named(s, c("X", "truth", "facet", "theta", "seed"))
  expect_true(is.matrix(s$X) && is.double(s$X))
  expect_identical(dim(s$X), c(137L, 3L))
  expect_true(is.matrix(s$truth) && is.double(s$truth))
  expect_identical(dim(s$truth), c(137L, 2L))
  expect_true(is.integer(s$facet) && length(s$facet) == 137L)
  expect_true(all(s$facet >= 1L & s$facet <= length(p$facets)))
  expect_identical(s$theta, 0.9)
  expect_identical(s$seed, 8L)
  expect_true(all(is.finite(s$X)) && all(is.finite(s$truth)))
})

test_that("a malformed call fails at the call, not later", {
  p <- sampling_patterns()[["miura"]]
  expect_error(sample_manifold(list(), theta = 0, n = 10L), "crease_pattern")
  expect_error(sample_manifold(p, theta = c(0, 1), n = 10L), "single finite")
  expect_error(sample_manifold(p, theta = 0.5, n = 0L), "positive integer")
  expect_error(sample_manifold(p, theta = 0.5, n = 10L, boundary = NA),
               "TRUE or FALSE")
})
