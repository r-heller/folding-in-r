# The flat crease patterns.
#
# Every assertion here is a claim Chapter 2 makes in prose. A failure is a
# chapter to rewrite, not a tolerance to widen.

PATTERNS <- list(
  miura     = function(n = 5L) miura_ori(n, n),
  yoshimura = function(n = 5L) yoshimura(n, n)
)

test_that("the contract is satisfied", {
  for (nm in names(PATTERNS)) {
    p <- PATTERNS[[nm]]()
    expect_s3_class(p, "crease_pattern")
    expect_true(is.matrix(p$vertices) && ncol(p$vertices) == 2L, info = nm)
    expect_true(is.list(p$facets) && length(p$facets) > 0L, info = nm)
    expect_true(all(c("i", "j", "assignment") %in% names(p$creases)), info = nm)
    expect_true(all(p$creases$assignment %in% c("M", "V", "B")), info = nm)
    expect_identical(p$family, nm)
    expect_true(all(unlist(p$facets) %in% seq_len(nrow(p$vertices))), info = nm)
  }
})

test_that("no two vertices coincide", {
  # A duplicated vertex would make the facet graph wrong in a way that only
  # shows up as a folding inconsistency much later.
  for (nm in names(PATTERNS)) {
    p <- PATTERNS[[nm]]()
    expect_equal(nrow(unique(round(p$vertices, 12))), nrow(p$vertices), info = nm)
  }
})

test_that("facets are simple, counter-clockwise, and tile the sheet", {
  for (nm in names(PATTERNS)) {
    p <- PATTERNS[[nm]]()
    area <- vapply(p$facets, function(f) {
      v <- p$vertices[f, , drop = FALSE]
      w <- v[c(seq_len(nrow(v))[-1], 1L), , drop = FALSE]
      0.5 * sum(v[, 1] * w[, 2] - w[, 1] * v[, 2])
    }, numeric(1))
    expect_true(all(area > 0), info = paste(nm, "counter-clockwise"))

    # The facets tile the sheet exactly: the total facet area equals the closed
    # form for the cell area times the number of cells. Overlap or a gap breaks
    # this, and both are easy to introduce by an off-by-one in the facet loop.
    expected <- switch(
      nm,
      miura     = with(p$params, nx * ny * a * b * sin(alpha)),
      yoshimura = with(p$params, nx * ny * a * height)
    )
    expect_equal(sum(area), expected, tolerance = 1e-12, info = nm)
  }
})

test_that("every facet is congruent to every other", {
  # Both families tile with a single cell shape. If this ever fails, the
  # sampler's area weighting and the isometry argument both need revisiting.
  for (nm in names(PATTERNS)) {
    p <- PATTERNS[[nm]]()
    sig <- t(vapply(p$facets, function(f) {
      v <- p$vertices[f, , drop = FALSE]
      w <- v[c(seq_len(nrow(v))[-1], 1L), , drop = FALSE]
      sort(round(sqrt(rowSums((w - v)^2)), 10))
    }, numeric(length(p$facets[[1]]))))
    expect_equal(nrow(unique(sig)), 1L, info = nm)
  }
})

test_that("Kawasaki's condition holds at every interior vertex", {
  # Alternating sector-angle sums are equal, and therefore each equals pi.
  # This is the flat-foldability condition, and it is what licenses the book to
  # call these patterns foldable at all.
  for (nm in names(PATTERNS)) {
    p  <- PATTERNS[[nm]]()
    iv <- interior_vertices(p)
    expect_gt(length(iv), 0L)
    for (v in iv) {
      a <- sector_angles(p, v)
      expect_true(length(a) %% 2L == 0L,
                  info = paste(nm, "even degree at vertex", v))
      odd  <- sum(a[seq(1L, length(a), by = 2L)])
      even <- sum(a[seq(2L, length(a), by = 2L)])
      expect_equal(odd, even, tolerance = 1e-12,
                   info = paste(nm, "vertex", v))
      expect_equal(odd, pi, tolerance = 1e-12,
                   info = paste(nm, "vertex", v))
    }
  }
})

test_that("the vertex angle sum is exactly 2 pi, so discrete curvature is zero", {
  # The correction recorded in PROJECT_CONCEPT.md, asserted rather than
  # asserted-in-prose: curvature is NOT concentrated at the vertices of a
  # folded flat sheet. If it were, the isometry claim would collapse.
  for (nm in names(PATTERNS)) {
    p <- PATTERNS[[nm]]()
    for (v in interior_vertices(p)) {
      expect_equal(sum(sector_angles(p, v)), 2 * pi, tolerance = 1e-12,
                   info = paste(nm, "vertex", v))
    }
  }
})

test_that("Maekawa's theorem holds at every interior vertex", {
  # |M - V| = 2, as a necessary condition on the stored labels of every family.
  #
  # It is not what FIXES those labels, and the comment here used to say it was --
  # that the Miura's zigzag creases must alternate in (i + j) because alternating
  # in i alone gives 2M/2V. The geometry says the opposite: the zigzag creases are
  # constant in i (each is a ridge or a trough of the corrugation along its whole
  # length) and it is the horizontal creases that alternate, which is 3M/1V and
  # satisfies Maekawa just as well. Two labellings that disagree on half the
  # creases both pass here, which is exactly why this is a sanity check and
  # test-crease-assignment.R is the test.
  for (nm in names(PATTERNS)) {
    p <- PATTERNS[[nm]]()
    for (v in interior_vertices(p)) {
      e <- p$creases[(p$creases$i == v | p$creases$j == v) &
                       p$creases$assignment != "B", , drop = FALSE]
      expect_equal(abs(sum(e$assignment == "M") - sum(e$assignment == "V")), 2,
                   info = paste(nm, "vertex", v))
    }
  }
})

test_that("interior vertices have the degree the family claims", {
  expect_true(all(vapply(interior_vertices(miura_ori(5L, 5L)),
                         function(v) length(sector_angles(miura_ori(5L, 5L), v)),
                         numeric(1)) == 4))
  expect_true(all(vapply(interior_vertices(yoshimura(5L, 5L)),
                         function(v) length(sector_angles(yoshimura(5L, 5L), v)),
                         numeric(1)) == 6))
})

test_that("miura_ori is congruent across the alpha range the book sweeps", {
  # PROJECT_CONCEPT.md claims verification over alpha in [20, 85] degrees.
  for (alpha in seq(20, 85, by = 5) * pi / 180) {
    p <- miura_ori(4L, 4L, alpha = alpha)
    for (v in interior_vertices(p)) {
      a <- sector_angles(p, v)
      expect_equal(sum(a[c(1L, 3L)]), sum(a[c(2L, 4L)]), tolerance = 1e-12,
                   info = paste("alpha", round(alpha, 4)))
    }
  }
})

test_that("waterbomb refuses to be built", {
  # PLAN.md E2's hard rule: no pattern may exist that cannot be folded. A grid
  # row that silently fails is worse than a missing one.
  expect_error(waterbomb(), "not implemented")
})
