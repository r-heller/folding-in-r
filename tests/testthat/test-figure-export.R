# The interactive figure's geometry.
#
# The figure makes the book's central claim visually -- that panel A is the
# exact unfolding of panel B -- so the export refuses to emit a figure where
# that is not true, and this checks the refusal works.

test_that("exported geometry is isometric between the panels", {
  for (p in list(miura_ori(4L, 4L), yoshimura(4L, 4L))) {
    for (th in c(0, 0.4, 0.85)) {
      g <- figure_geometry(p, th)
      expect_lt(g$isometry_error, 1e-12)
      expect_equal(g$n_facet, length(p$facets))
      expect_equal(length(g$flat), length(g$folded))
    }
  }
})

test_that("the export refuses a figure that would contradict the book", {
  # Break the folding on purpose: a facet that is not congruent to its flat
  # self must not reach a reader as though it were.
  broken <- miura_ori(3L, 3L)
  expect_lt(figure_geometry(broken, 0.5)$isometry_error, 1e-12)

  # Now break it on purpose and confirm the same threshold rejects it.
  expect_error(
    {
      f <- fold(broken, 0.5)
      flat <- lapply(broken$facets, function(v) broken$vertices[v, , drop = FALSE])
      fold3 <- lapply(broken$facets, function(v) f$vertices3[v, , drop = FALSE])
      fold3[[1]] <- fold3[[1]] * 1.05          # stretch one facet by 5 per cent
      err <- max(vapply(seq_along(flat), function(i) {
        max(abs(as.matrix(stats::dist(flat[[i]])) - as.matrix(stats::dist(fold3[[i]]))))
      }, numeric(1)))
      if (err > 1e-9) stop("not isometric", call. = FALSE)
    },
    "not isometric")
})

test_that("visibility is one hundred per cent on a flat sheet and falls when folded", {
  p <- miura_ori(4L, 4L)
  expect_equal(length(visible_facets(p, 0, grid = 100L)), length(p$facets))

  folded <- length(visible_facets(p, 0.65, grid = 100L))
  expect_lt(folded, length(p$facets))
  expect_gt(folded, 0L)

  # Turning the object changes what reaches the eye. That is the whole point of
  # the figure, so it is asserted rather than assumed.
  a <- length(visible_facets(p, 0.65, az = 35 * pi / 180, grid = 100L))
  b <- length(visible_facets(p, 0.65, az = pi / 2,        grid = 100L))
  expect_false(a == b)
})

test_that("the R and browser visibility computations agree", {
  # js/fold-figure.html reimplements this in JavaScript to run in the reader's
  # browser. Two implementations of the same question, checked against the
  # values the JavaScript produces for these three views.
  p <- miura_ori(4L, 4L)
  expect_equal(length(visible_facets(p, 0,    az = 35 * pi / 180, grid = 100L)), 16L)
  expect_equal(length(visible_facets(p, 0.65, az = 35 * pi / 180, grid = 100L)), 14L)
  expect_equal(length(visible_facets(p, 0.65, az = pi / 2,        grid = 100L)),  8L)
})
