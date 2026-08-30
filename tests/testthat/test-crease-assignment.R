# Mountain and valley, checked by a second route.
#
# This file exists because the first derivation of crease_assignment() was wrong
# and the suite could not see it. The acceptance evidence recorded at the time
# was Maekawa's theorem, |M - V| = 2 at every interior vertex -- and Maekawa is
# invariant under a global M<->V swap, so it is exactly symmetric to the class of
# error that had occurred. Three mutually contradictory labellings of the same
# Miura all satisfied it. See ROADMAP.md section 5.
#
# So the check here does not test a property of the labels. It recomputes the
# labels by an independent route and compares. The two routes share no code and
# disagree in what they rely on:
#
#   production   orients each facet by its WINDING (Newell's normal follows the
#                vertex cycle) and picks the two adjacent facets by which one
#                walks the crease i -> j. Combinatorial. Works on a surface with
#                vertical or overhanging facets; fails if the mesh is unwound.
#
#   here         orients each facet by flipping its normal to +z, and asks which
#                side of the sheet the surrounding material sits on. Metric.
#                Needs no winding at all; requires only that no facet is vertical,
#                which is asserted rather than assumed.
#
# A handedness error in either is invisible to itself and visible to the other.
#
# Demonstrated to fail before the fix, which is the point of it (ROADMAP.md item
# 0.2). On the pre-fix tree, at every size, alpha and theta in the sweep below:
#
#   stored labels  (parity rule)          agreed on 50.0% of interior creases
#   derived labels (crease_assignment)    agreed on 50.0% of interior creases
#
# and both passed the Maekawa test that was standing in for this one.

SIZES  <- c(3L, 4L, 5L, 6L)
ALPHAS_MV <- c(pi / 5, pi / 4, pi / 3, 5 * pi / 12)
THETAS_MV <- c(0.05, 0.2, 0.5, 0.9, 0.999)

# ── The independent criterion ───────────────────────────────────────────────

# Newell's normal, then flipped to +z. The flip is the whole independence: it
# takes the sheet's front face from the ambient frame instead of from the vertex
# order, so nothing about how patterns.R happens to wind its facets can reach it.
.up_normal <- function(P) {
  m <- nrow(P)
  n <- c(0, 0, 0)
  for (k in seq_len(m)) {
    a <- P[k, ]
    b <- P[if (k == m) 1L else k + 1L, ]
    n <- n + c((a[2] - b[2]) * (a[3] + b[3]),
               (a[3] - b[3]) * (a[1] + b[1]),
               (a[1] - b[1]) * (a[2] + b[2]))
  }
  n <- n / sqrt(sum(n^2))
  if (n[3] < 0) -n else n
}

# A crease is a mountain when the material around it lies BEHIND the sheet --
# the crease is the part sticking out toward the front. Both quantities are
# symmetric in the two facets and unchanged by reversing the crease's stored
# direction, so neither ordering that broke the first derivation exists here.
mv_by_up_normals <- function(pattern, theta) {
  V3 <- fold(pattern, theta)$vertices3
  N  <- lapply(pattern$facets, function(v) .up_normal(V3[v, , drop = FALSE]))

  # The criterion is undefined for a vertical facet. On this family none occurs;
  # assert it rather than discover it as a wrong label.
  expect_true(all(vapply(N, function(n) abs(n[3]) > 1e-8, logical(1))))

  vapply(seq_len(nrow(pattern$creases)), function(e) {
    i <- pattern$creases$i[e]; j <- pattern$creases$j[e]
    fs <- which(vapply(pattern$facets, function(v) all(c(i, j) %in% v), logical(1)))
    if (length(fs) < 2L) return("B")

    mid  <- (V3[i, ] + V3[j, ]) / 2
    bulk <- rowMeans(vapply(fs, function(k) {
      o <- setdiff(pattern$facets[[k]], c(i, j))
      colMeans(V3[o, , drop = FALSE])
    }, numeric(3)))
    nn <- rowMeans(vapply(fs, function(k) N[[k]], numeric(3)))

    s <- sum((bulk - mid) * nn)
    if (abs(s) < 1e-12) return("?")   # degenerate: refuse to guess, and fail loudly
    if (s < 0) "M" else "V"
  }, character(1))
}

# ── The tests ───────────────────────────────────────────────────────────────

test_that("the independent criterion is well posed on this family", {
  # If it ever returns "?" the comparison tests below would be comparing against
  # a non-answer, so the guard is checked first and on its own.
  #
  # This is also the measurement that settles ROADMAP.md's open question 1. The
  # audit's two ridge-versus-trough tests disagreed (0/N against 25%) because
  # both compared HEIGHTS: crease-midpoint z against the mean z of the opposite
  # facet points. On the Miura's horizontal creases both adjacent facets span the
  # same two heights, so that difference is identically zero and the test was
  # reading floating-point noise. Projecting onto the facet normals instead keeps
  # the horizontal component of the fold, which is where those creases carry
  # their entire signal.
  for (n in SIZES) for (al in ALPHAS_MV) for (th in THETAS_MV) {
    a <- mv_by_up_normals(miura_ori(n, n, alpha = al), th)
    expect_false(any(a == "?"),
                 info = sprintf("miura %dx%d alpha=%.3f theta=%.3f", n, n, al, th))
  }
})

test_that("crease_assignment() agrees with the independent criterion", {
  # The gate for ROADMAP.md item 0.1. Run over the sweep rather than at one
  # point: the handedness bug was a fixed sign, so a single (n, alpha, theta)
  # could have agreed by luck.
  for (n in SIZES) for (al in ALPHAS_MV) for (th in THETAS_MV) {
    p <- miura_ori(n, n, alpha = al)
    expect_identical(crease_assignment(p, th), mv_by_up_normals(p, th),
                     info = sprintf("miura %dx%d alpha=%.3f theta=%.3f", n, n, al, th))
  }
})

test_that("the stored labels are the geometry's labels, not a parity rule", {
  # miura_ori() writes its assignment in closed form so that patterns.R stays
  # ignorant of folding. This is what stops the closed form and the derivation
  # from drifting apart -- and it is what the figures actually draw.
  for (n in SIZES) for (al in ALPHAS_MV) for (th in THETAS_MV) {
    p <- miura_ori(n, n, alpha = al)
    expect_identical(p$creases$assignment, mv_by_up_normals(p, th),
                     info = sprintf("miura %dx%d alpha=%.3f theta=%.3f", n, n, al, th))
  }
  # Non-square patches and unequal side lengths, where an index-parity rule that
  # happened to work on a square would be most likely to come apart.
  for (nx in c(3L, 5L)) for (ny in c(4L, 6L)) {
    p <- miura_ori(nx, ny, a = 1.7, b = 0.6, alpha = pi / 3)
    expect_identical(p$creases$assignment, mv_by_up_normals(p, 0.6),
                     info = sprintf("miura %dx%d a=1.7 b=0.6", nx, ny))
  }
})

test_that("the assignment does not depend on how the crease happens to be stored", {
  # The bug in one line. Swapping (i, j) negates the crease axis AND exchanges
  # the two adjacent facets, so a correct criterion is unchanged and an
  # ordering-dependent one inverts. Every interior label flipping is the exact
  # signature of the defect this file was written for.
  p <- miura_ori(5L, 5L)
  q <- p
  q$creases <- data.frame(i = p$creases$j, j = p$creases$i,
                          assignment = p$creases$assignment,
                          stringsAsFactors = FALSE)
  expect_identical(crease_assignment(q, 0.5), crease_assignment(p, 0.5))
})

test_that("the assignment does not depend on the order facets are listed in", {
  # The other half of the same bug: fs[1:2] took the two adjacent facets in
  # facet-index order. Permuting the list must not move a single label.
  p <- miura_ori(5L, 5L)
  set.seed(11L)
  q <- p
  q$facets <- p$facets[sample(length(p$facets))]
  expect_identical(crease_assignment(q, 0.5), crease_assignment(p, 0.5))
})

test_that("Maekawa holds -- and is shown to be too weak to have caught this", {
  # Kept as a necessary condition, and immediately followed by the demonstration
  # of why it was never sufficient. |M - V| = 2 counts labels at a vertex; it
  # cannot see which crease got which label, so it passes on the correct
  # labelling, on its global inverse, and on the retired parity rule that agreed
  # with neither on half the creases.
  p <- miura_ori(5L, 5L)
  a <- crease_assignment(p)
  expect_setequal(unique(a), c("M", "V", "B"))

  maekawa <- function(lab) {
    vapply(interior_vertices(p), function(v) {
      sel <- (p$creases$i == v | p$creases$j == v) & lab != "B"
      abs(sum(lab[sel] == "M") - sum(lab[sel] == "V"))
    }, numeric(1))
  }
  expect_true(all(maekawa(a) == 2))

  inverted <- ifelse(a == "M", "V", ifelse(a == "V", "M", "B"))
  expect_true(all(maekawa(inverted) == 2))          # passes, and is wrong
  expect_false(identical(inverted, a))

  retired <- character(nrow(p$creases))              # the pre-fix parity rule
  k <- 0L; nx <- 5L; ny <- 5L
  for (j in 0:ny) for (i in 0:(nx - 1L)) {
    k <- k + 1L
    retired[k] <- if (j == 0L || j == ny) "B" else if (j %% 2L == 1L) "M" else "V"
  }
  for (j in 0:(ny - 1L)) for (i in 0:nx) {
    k <- k + 1L
    retired[k] <- if (i == 0L || i == nx) "B" else if ((i + j) %% 2L == 1L) "M" else "V"
  }
  expect_true(all(maekawa(retired) == 2))           # passes, and is also wrong
  sel <- a != "B"
  expect_equal(mean(retired[sel] == a[sel]), 0.5)   # on exactly half the creases
})

test_that("an unwound mesh is refused rather than labelled", {
  # crease_assignment() reads the sheet's front face off the facet winding. If a
  # constructor ever emits a facet the other way round, the labels around it
  # invert silently -- so the precondition is checked, not assumed.
  p <- miura_ori(4L, 4L)
  expect_silent(.check_winding(p))

  q <- p
  q$facets[[3L]] <- rev(q$facets[[3L]])
  expect_error(.check_winding(q), "not consistently wound")
  expect_error(crease_assignment(q), "not consistently wound")
})
