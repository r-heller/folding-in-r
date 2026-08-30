# The interactive figure's geometry.
#
# The figure makes the book's central claim visually -- that panel A is the
# exact unfolding of panel B -- so the export refuses to emit a figure where
# that is not true, and this checks the refusal works.

test_that("exported geometry is isometric between the panels", {
  for (p in list(miura_ori(4L, 4L), miura_ori(3L, 5L))) {
    for (th in c(0, 0.4, 0.85)) {
      g <- figure_geometry(p, th)
      expect_lt(g$isometry_error, 1e-12)
      expect_equal(g$n_facet, length(p$facets))
      expect_equal(length(g$flat), length(g$folded))
    }
  }
})

test_that("the export refuses a figure that would contradict the book", {
  # This test used to re-implement the isometry check inline and assert that its
  # OWN stop() fired. It never called figure_geometry() on anything broken, so
  # deleting the production guard left it at 27 of 27 passing. Confirmed by
  # deleting it -- which is the only way to find out.
  #
  # The guard is reached instead. .fold_miura() derives the folded placement from
  # pattern$params and never reads pattern$vertices, so moving one flat vertex
  # leaves fold() working and makes the flat panel stop being the unfolding of
  # the folded one -- exactly the figure the export exists to refuse.
  ok <- miura_ori(3L, 3L)
  expect_lt(figure_geometry(ok, 0.5)$isometry_error, 1e-12)

  broken <- ok
  broken$vertices[1L, 1L] <- broken$vertices[1L, 1L] + 0.05
  expect_error(figure_geometry(broken, 0.5), "not isometric")

  # And it is the threshold doing the work, not the mere fact of a change: a
  # perturbation below it must still export.
  nudged <- ok
  nudged$vertices[1L, 1L] <- nudged$vertices[1L, 1L] + 1e-13
  expect_silent(figure_geometry(nudged, 0.5))
})

test_that("the static panel is drawn in the view its visibility was computed in", {
  # visible_facets() takes (sx, sy) as the picture plane and `depth` toward the
  # camera. fold_figure_static() re-derived all three from the same four trig
  # calls and had the last two exchanged, so panel A greyed the facets hidden in
  # a view panel B never showed, and its subtitle counted them.
  #
  # Checked as a property of the drawn panel rather than against a second copy of
  # the projection, which would only assert that two spellings of the same four
  # products agree. A facet is hidden when something nearer the camera covers it,
  # so: every facet panel A greys must, in the coordinates panel B is actually
  # drawn in, sit under a facet the panel draws in front of it. That is false
  # when the two axes are exchanged, and it needs no view matrix to say so.
  p  <- miura_ori(4L, 4L)
  th <- 0.65
  d  <- fold_figure_data(p, th)

  inside <- function(px, py, X, Y) {           # ray cast, test-local
    n <- length(X); c <- FALSE; j <- n
    for (i in seq_len(n)) {
      if ((Y[i] > py) != (Y[j] > py) &&
          px < (X[j] - X[i]) * (py - Y[i]) / (Y[j] - Y[i]) + X[i]) c <- !c
      j <- i
    }
    c
  }

  fid    <- as.integer(as.character(d$fold$facet))
  depth  <- vapply(split(d$fold$depth, fid), unique, numeric(1))
  hidden <- setdiff(seq_len(d$n_facet), d$visible)
  expect_gt(length(hidden), 0L)                # the view has to hide something

  for (i in hidden) {
    v  <- d$fold[fid == i, ]
    cx <- mean(v$x); cy <- mean(v$y)           # a parallelogram's centroid is interior
    covered <- vapply(setdiff(seq_len(d$n_facet), i), function(j) {
      w <- d$fold[fid == j, ]
      depth[[as.character(j)]] > depth[[as.character(i)]] && inside(cx, cy, w$x, w$y)
    }, logical(1))
    expect_true(any(covered), info = paste("facet", i, "is greyed but nothing covers it"))
  }

  # And the converse, at the one point it is cheapest to check: whatever the
  # panel draws last is nearest the camera, so it cannot be hidden.
  ord <- as.integer(levels(d$fold$facet))
  expect_true(ord[length(ord)] %in% d$visible)

  # Panel A greys exactly the facets panel B hides, which is the claim its
  # subtitle makes out loud.
  expect_setequal(unique(d$flat$facet[d$flat$visible]), d$visible)
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

test_that("visible_facets() is pinned at three views", {
  # These are R's numbers, pinned so a change to the view or the sampler has to
  # be deliberate.
  #
  # This test was called "the R and browser visibility computations agree" and
  # said it checked "the values the JavaScript produces". It executes no
  # JavaScript. js/fold-figure.html computes visibility by filling an offscreen
  # canvas with per-facet id colours and reading the buffer back, and nothing in
  # this repository has ever run it -- so the agreement was asserted in a test
  # name, which is the one place an unchecked claim is hardest to see.
  #
  # Renamed rather than made true: a real parity check needs the shipped script
  # executed under Node with a canvas, and that is worth doing where the two
  # implementations are most likely to diverge -- the VIEW, which is exactly
  # where R's own two copies had just diverged. ROADMAP.md carries it as open.
  p <- miura_ori(4L, 4L)
  expect_equal(length(visible_facets(p, 0,    az = 35 * pi / 180, grid = 100L)), 16L)
  expect_equal(length(visible_facets(p, 0.65, az = 35 * pi / 180, grid = 100L)), 14L)
  expect_equal(length(visible_facets(p, 0.65, az = pi / 2,        grid = 100L)),  8L)
})
