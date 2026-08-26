# The folding map.
#
# Every assertion here is a claim the book makes in prose, and the first two are
# the ones the whole argument rests on.
#
# Note what the construction buys. fold() places VERTICES on a lattice, and
# every facet reads its corners from that one shared set. So facets cannot
# disagree about where a shared crease is -- consistency is structural, not
# something a solver has to achieve. What remains to check is that each facet is
# congruent to its flat self, and that plus shared vertices is exactly what it
# means to be a rigid folding. The tolerances below are therefore not
# solver tolerances; they are floating-point noise on a closed form.

THETAS <- seq(0, 1, by = 0.05)
ALPHAS <- seq(20, 85, by = 5) * pi / 180

test_that("folding is an isometry on every facet, for every theta", {
  # Pairwise distances, not edge lengths. An implementation that preserves every
  # edge of a parallelogram while shearing it passes an edge test and is not a
  # rigid folding.
  for (p in list(miura_ori(5L, 5L))) {
    worst <- max(vapply(THETAS, function(t) facet_isometry_error(p, t), numeric(1)))
    expect_lt(worst, 1e-10)          # the contract in R/README.md
    expect_lt(worst, 1e-12)          # what it actually achieves
  }
})

test_that("the Miura is isometric across the alpha range the book sweeps", {
  worst <- 0
  for (al in ALPHAS) {
    p <- miura_ori(4L, 4L, alpha = al)
    worst <- max(worst, max(vapply(seq(0, 1, by = 0.1),
                                   function(t) facet_isometry_error(p, t),
                                   numeric(1))))
  }
  expect_lt(worst, 1e-12)
})

test_that("theta = 0 is the flat sheet exactly, not in the limit", {
  for (p in list(miura_ori(5L, 5L))) {
    f <- fold(p, 0)
    expect_equal(max(abs(f$vertices3[, 3])), 0)
    expect_equal(f$vertices3[, 1:2], p$vertices, ignore_attr = TRUE)
    # A crease in a flat sheet sits at pi, not at 0. The earlier draft of the
    # glossary had this backwards, which is why it is asserted here.
    expect_true(all(abs(f$rho - pi) < 1e-9))
  }
})

test_that("theta is a parameter on [0, 1] and says so when it is not", {
  p <- miura_ori(3L, 3L)
  expect_error(fold(p, -0.1), "folding parameter")
  expect_error(fold(p, 1.4), "folding parameter")
  # 1.4 is the value the inherited grid swept, so it is worth its own case:
  # it is not a dihedral range and it is not a legal parameter either.
})

test_that("folding is monotone over the whole sweep", {
  for (p in list(miura_ori(4L, 4L))) {
    ts <- seq(0, 1, by = 0.02)
    z <- vapply(ts, function(t) diff(range(fold(p, t)$vertices3[, 3])), numeric(1))
    y <- vapply(ts, function(t) diff(range(fold(p, t)$vertices3[, 2])), numeric(1))
    expect_false(is.unsorted(z))          # corrugation grows
    expect_false(is.unsorted(rev(y)))     # the sheet contracts
  }
})

test_that("folding contracts ambient distance and never expands it", {
  # The book's crux. Pairs inside one facet keep their distance exactly; every
  # pair separated by a fold is strictly closer in R^3 than along the surface.
  for (p in list(miura_ori(4L, 4L))) {
    dU <- as.matrix(stats::dist(p$vertices))
    for (t in c(0.1, 0.5, 0.9)) {
      dA <- as.matrix(stats::dist(fold(p, t)$vertices3))
      off <- upper.tri(dA) & dU > 1e-9
      expect_lte(max(dA[off] / dU[off]), 1 + 1e-12)
    }
  }
})

test_that("an independently derived closed form reproduces the measured dihedral", {
  # .dihedrals() measures rho by projecting into the plane normal to the crease.
  # The expression below was derived by hand from the placement:
  #
  #   cos(rho) = (c^2 sin^2(phi) - 1 + c^2) / (c^2 sin^2(phi) + 1 - c^2),
  #   c = cos(alpha) / cos(phi),  phi = theta * alpha
  #
  # Two different routes to the same number. Agreement is a check on both; if
  # the placement were wrong, the projection would not match the algebra.
  rho_h <- function(alpha, phi) {
    c2 <- (cos(alpha) / cos(phi))^2
    acos((c2 * sin(phi)^2 - 1 + c2) / (c2 * sin(phi)^2 + 1 - c2))
  }
  worst <- 0
  for (al in c(pi / 6, pi / 4, pi / 3, 1.3)) {
    p <- miura_ori(4L, 4L, alpha = al)
    horizontal <- which(
      abs(p$vertices[p$creases$i, 2] - p$vertices[p$creases$j, 2]) < 1e-12 &
        p$creases$assignment != "B")
    for (t in seq(0.05, 0.95, by = 0.05)) {
      worst <- max(worst, max(abs(fold(p, t)$rho[horizontal] - rho_h(al, t * al))))
    }
  }
  expect_lt(worst, 1e-12)
})

test_that("dihedral angles decrease monotonically from pi as the sheet folds", {
  p <- miura_ori(4L, 4L)
  interior <- which(p$creases$assignment != "B")
  prev <- rep(pi, length(interior))
  for (t in seq(0.05, 1, by = 0.05)) {
    r <- fold(p, t)$rho[interior]
    expect_true(all(r <= prev + 1e-12))
    prev <- r
  }
  expect_true(all(prev < 1e-6))     # flat-folded at theta = 1
})

test_that("no two distinct vertices collide before the flat-folded state", {
  # A self-intersecting surface would invalidate every ambient distance measured
  # on it, so this is a precondition for the benchmark rather than a nicety.
  for (p in list(miura_ori(4L, 4L))) {
    for (t in c(0.5, 0.9, 0.99)) {
      d <- as.matrix(stats::dist(fold(p, t)$vertices3))
      diag(d) <- Inf
      expect_gt(min(d), 1e-3)
    }
  }
})

test_that("the folded object satisfies its contract", {
  p <- miura_ori(4L, 4L)
  f <- fold(p, 0.5)
  expect_s3_class(f, "folded_pattern")
  expect_identical(f$theta, 0.5)
  expect_equal(nrow(f$vertices3), nrow(p$vertices))
  expect_equal(ncol(f$vertices3), 3L)
  expect_equal(length(f$rho), nrow(p$creases))
  expect_true(all(f$rho[p$creases$assignment == "B"] == pi))
})

test_that("the Yoshimura refuses to fold, and says why", {
  # Withdrawn (PLAN.md R1-1). Two rigid foldings were derived and each leaves one
  # of the three crease families flat, which makes the folded object a
  # parallelogram tessellation rather than a diamond one. The flat pattern is
  # still built -- it is a valid crease pattern and Chapter 8 discusses it.
  expect_s3_class(yoshimura(3L, 3L), "crease_pattern")
  expect_error(fold(yoshimura(3L, 3L), 0.5), "three crease families")
})

test_that("mountain and valley are derived from the fold, and Maekawa follows", {
  # The labels used to be assigned by a parity rule chosen to satisfy Maekawa,
  # and matched the actual folding on barely half the creases. Deriving them
  # from the folded dihedral makes Maekawa a consequence to test rather than an
  # assumption -- and it is the test that caught the Yoshimura being a pleat.
  p <- miura_ori(5L, 5L)
  a <- crease_assignment(p)
  expect_setequal(unique(a), c("M", "V", "B"))
  for (v in interior_vertices(p)) {
    sel <- (p$creases$i == v | p$creases$j == v) & a != "B"
    expect_equal(abs(sum(a[sel] == "M") - sum(a[sel] == "V")), 2,
                 info = paste("vertex", v))
  }
})

test_that("facet_gap is the exact minimum, and brute force converges to it", {
  # CHAPTERS.md Ch 5 asks for exactly this check: test the analytic
  # polygon-to-polygon distance against a dense sampled minimum, where brute
  # force is affordable and unambiguous.
  #
  # A point sample can only ever OVERestimate a true minimum, so the exact value
  # must sit below it and the sample must converge down onto it. That is a
  # stronger test than agreement at one resolution, which a wrong constant would
  # also pass.
  p <- miura_ori(3L, 3L)
  th <- 0.7
  exact <- facet_gap(p, th)$gap

  brute <- function(m) {
    V3 <- fold(p, th)$vertices3
    fs <- p$facets
    best <- Inf
    pts <- function(P) {
      g <- seq(0, 1, length.out = m)
      do.call(rbind, lapply(g, function(u) do.call(rbind, lapply(g, function(v)
        (1 - u) * (1 - v) * P[1, ] + u * (1 - v) * P[2, ] +
          u * v * P[3, ] + (1 - u) * v * P[4, ]))))
    }
    for (i in seq_along(fs)) for (j in seq_along(fs)) {
      if (j <= i || length(intersect(fs[[i]], fs[[j]]))) next
      A <- pts(V3[fs[[i]], , drop = FALSE]); B <- pts(V3[fs[[j]], , drop = FALSE])
      D <- as.matrix(stats::dist(rbind(A, B)))
      best <- min(best, min(D[seq_len(nrow(A)), nrow(A) + seq_len(nrow(B))]))
    }
    best
  }

  b8 <- brute(8L); b20 <- brute(20L)
  expect_lte(exact, b8  + 1e-12)          # never above a sampled minimum
  expect_lte(exact, b20 + 1e-12)
  expect_lt(b20, b8)                       # the sample descends toward it
  expect_lt(b20 / exact - 1, 0.01)         # and gets within one per cent
})

test_that("facet_gap falls as the sheet folds, and needs no sample to say so", {
  # The point of having it alongside branch_gap(): this is a property of the
  # surface, so it carries no dependence on n. branch_gap() grows as sqrt(n) by
  # construction, which is right for what it measures and wrong for predicting
  # an onset analytically.
  p <- miura_ori(3L, 3L)
  g <- vapply(c(0.2, 0.5, 0.8, 0.95), function(t) facet_gap(p, t)$gap, numeric(1))
  expect_false(is.unsorted(rev(g)))
  expect_gt(g[1] / g[length(g)], 1.5)
  expect_true(all(g > 0))                  # nothing touches before flat-folded
})
