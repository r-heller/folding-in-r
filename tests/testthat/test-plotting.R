# Every figure in the book.
#
# R/plotting.R is 23 KB and fifteen functions, and had no test file at all --
# the largest untested surface in the repository, and the one a reader sees.
#
# What is tested here is not that the plots render. ggplot builds almost
# anything, and a figure that is wrong is a figure that renders. It is the four
# quantities that decide whether a figure says something true:
#
#   the projection      an orthographic camera, or the reader is measuring
#                       foreshortening they were told was not there
#   the painter's order  or the far half of a folded sheet reads as the near half
#   the crease segments  or every crease connects the wrong two points, and the
#                       picture is still plausible -- the exact failure mode the
#                       mountain/valley labels had for four days
#   the level sets       the redundant channel standing rule 3 requires

miura <- miura_ori(4L, 4L)

# ── The camera ──────────────────────────────────────────────────────────────

test_that(".project() is a rotation, so the figure measures what it shows", {
  # The comment above .project() promises "a projection rather than a
  # perspective, because the book measures distances in these figures by eye".
  # That promise is exactly the statement that the map to (px, py, near) is
  # orthonormal: lengths and angles in any plane parallel to the picture plane
  # survive it. One wrong sign or one swapped trig call breaks it, and breaks
  # nothing else visible.
  for (az in c(0, 35, 90, 137.5, 215)) for (el in c(0, 25, 60, -40)) {
    M <- unname(as.matrix(.project(diag(3L), az, el)))   # columns: px, py, near
    expect_equal(t(M) %*% M, diag(3L), tolerance = 1e-12,
                 info = sprintf("az=%g el=%g", az, el))
    expect_equal(abs(det(M)), 1, tolerance = 1e-12,
                 info = sprintf("az=%g el=%g", az, el))
  }
})

test_that("the camera moves the way the argument names say", {
  # At azimuth and elevation zero the picture plane is the x-z plane seen along
  # +y, so px is -x... and that is the sort of assertion that just restates the
  # code. What is asserted instead is behaviour: raising the elevation must move
  # a point that is FURTHER along the view axis further down the picture, and
  # turning the azimuth by a full circle must return the same picture.
  v <- rbind(c(1, 0, 0), c(0, 1, 0), c(0, 0, 1), c(1, 1, 1))
  expect_equal(.project(v, 35, 25), .project(v, 35 + 360, 25))

  low  <- .project(v, 35, 5)
  high <- .project(v, 35, 55)
  far  <- which.max(low$near)
  expect_lt(high$py[far], low$py[far])
})

# ── Hidden-line removal ─────────────────────────────────────────────────────

test_that(".polygon_frame() puts the far facet first, which is the whole trick", {
  # grid draws polygons by ascending group id, so opaque fills give hidden-line
  # removal for free -- but only if group 1 really is the farthest. Reversing
  # the sort renders a wireframe in which the far half of the sheet reads as the
  # near half, and it renders perfectly happily.
  f  <- fold(miura, 0.6)
  pr <- .project(f$vertices3)
  fr <- .polygon_frame(cbind(pr$px, pr$py), miura$facets, depth = pr$near)

  d <- vapply(split(fr$depth, fr$group), unique, numeric(1))
  expect_false(is.unsorted(d))                      # ascending: far to near
  expect_length(d, length(miura$facets))

  # The depth of each group is the mean depth of the facet it came from, not
  # some other facet's: a sort that reordered the rows without reordering the
  # vertex indices would still be sorted.
  drawn <- lapply(split(fr[, c("x", "y")], fr$group), as.matrix)
  actual <- lapply(order(vapply(miura$facets, function(v) mean(pr$near[v]), numeric(1))),
                   function(k) unname(cbind(pr$px[miura$facets[[k]]],
                                            pr$py[miura$facets[[k]]])))
  for (g in seq_along(drawn)) {
    expect_equal(unname(drawn[[g]]), actual[[g]], info = paste("group", g))
  }
})

test_that(".polygon_frame() drops what cannot be a polygon, and says nothing", {
  # A degenerate strip at a sheet edge is a legitimate thing for a constructor
  # to return; it is not an error and it is not drawable.
  xy <- cbind(c(0, 1, 1, 0, 2), c(0, 0, 1, 1, 2))
  fr <- .polygon_frame(xy, list(c(1L, 2L, 3L, 4L), c(1L, 2L), 5L))
  expect_equal(length(unique(fr$group)), 1L)
  expect_null(.polygon_frame(xy, list(c(1L, 2L), 3L)))
})

# ── Creases ─────────────────────────────────────────────────────────────────

test_that(".crease_segments() connects the two vertices the crease names", {
  # Both endpoints, and in the right order. Swapping i and j draws exactly the
  # same picture, which is why the endpoints are checked separately from the
  # segment: a test on the set of drawn lines would pass on a transposed table.
  seg <- .crease_segments(miura)
  expect_equal(nrow(seg), nrow(miura$creases))
  v <- as.matrix(miura$vertices)
  expect_equal(seg$x,    unname(v[miura$creases$i, 1L]))
  expect_equal(seg$y,    unname(v[miura$creases$i, 2L]))
  expect_equal(seg$xend, unname(v[miura$creases$j, 1L]))
  expect_equal(seg$yend, unname(v[miura$creases$j, 2L]))

  # Every crease keeps its own assignment, and the factor carries all three
  # levels whether or not this pattern uses them -- otherwise the legend loses
  # a key on a pattern with no boundary, and two figures disagree.
  expect_equal(as.character(seg$assignment), as.character(miura$creases$assignment))
  expect_equal(levels(seg$assignment), names(CREASE_COLOUR))
})

test_that("mountain and valley are separated twice over, per standing rule 3", {
  # "No result is encoded by colour alone." On this one figure the distinction
  # IS the content, so colour and linetype must both carry it. A palette edit
  # that made two linetypes equal would leave a figure that is correct in colour
  # and unreadable in greyscale, and nothing else would notice.
  expect_setequal(names(CREASE_COLOUR), names(CREASE_LINETYPE))
  expect_setequal(names(CREASE_COLOUR), names(CREASE_LABEL))
  expect_equal(anyDuplicated(CREASE_COLOUR), 0L)
  expect_equal(anyDuplicated(CREASE_LINETYPE[c("M", "V")]), 0L)

  # One merged legend: both scales carry the same name, limits and labels, which
  # is what makes ggplot draw one key instead of two, and drop = FALSE keeps all
  # three entries whether the pattern uses them or not -- a legend that gains and
  # loses rows across a theta sweep makes those panels unreadable against each
  # other.
  sc <- .crease_scales()
  expect_equal(length(sc), 2L)
  expect_true(all(vapply(sc, function(s) identical(s$name, "crease"), logical(1))))
  expect_true(all(vapply(sc, function(s) isFALSE(s$drop), logical(1))))
  expect_true(all(vapply(sc, function(s) identical(s$limits, names(CREASE_COLOUR)),
                         logical(1))))
})

# ── Level sets ──────────────────────────────────────────────────────────────

test_that(".iso_bands() draws interior level sets of the coordinate it is given", {
  # x and y are set to u and w here so the returned band can be read back in the
  # coordinates it was selected and ordered by. The levels are recomputed in the
  # test from the documented rule -- equally spaced in the interior of the range
  # -- rather than read off the function.
  set.seed(4L)
  n <- 800L
  u <- runif(n, -2, 3)
  w <- runif(n)
  b <- .iso_bands(x = u, y = w, u = u, w = w, n_iso = 5L, width = 0.02)

  expect_equal(sort(unique(b$band)), 1:5)

  rng <- range(u)
  lv  <- seq(rng[1L], rng[2L], length.out = 7L)[-c(1L, 7L)]
  expect_gt(min(lv), min(u))                       # interior, not at the ends
  expect_lt(max(lv), max(u))
  half <- 0.02 * diff(rng)

  for (k in 1:5) {
    got <- b$x[b$band == k]
    # every point in the band is within the half-width of THAT band's level, so
    # a band built from the wrong coordinate -- which would still be a band --
    # fails here
    expect_true(all(abs(got - lv[k]) <= half + 1e-12), info = paste("band", k))
    expect_gte(length(got), 3L)
    # and the band is a path: its points come out ordered by the other chart
    # coordinate, or geom_path joins them into a scribble
    expect_false(is.unsorted(b$y[b$band == k]), info = paste("band", k))
  }
})

test_that(".iso_bands() refuses to invent a level set", {
  expect_null(.iso_bands(1:10, 1:10, rep(1, 10), 1:10, 5L, 0.02))  # no range
  expect_null(.iso_bands(1:10, 1:10, 1:10, 1:10, 0L, 0.02))        # none asked for
})

# ── The figures themselves ──────────────────────────────────────────────────

test_that("plot_crease_pattern() draws every crease the pattern has", {
  p <- plot_crease_pattern(miura, title = "t")
  expect_s3_class(p, "ggplot")
  seg <- Filter(function(l) inherits(l$geom, "GeomSegment"), p$layers)
  expect_equal(length(seg), 1L)
  expect_equal(nrow(seg[[1L]]$data), nrow(miura$creases))
})

test_that("plot_folded() refuses the inputs that would still look plausible", {
  f <- fold(miura, 0.5)
  expect_s3_class(plot_folded(f), "ggplot")

  expect_error(plot_folded(miura), "must be a folded_pattern")

  # Row misalignment is the dangerous one: every crease connects the wrong two
  # points and the figure is still a picture of a folded sheet.
  bad <- f
  bad$vertices3 <- bad$vertices3[-1L, , drop = FALSE]
  expect_error(plot_folded(bad), "row-aligned by contract")

  bad2 <- f; bad2$theta <- c(0.1, 0.2)
  expect_error(plot_folded(bad2), "single finite number")

  bad3 <- f; bad3$vertices3 <- NULL
  expect_error(plot_folded(bad3), "missing required field")
})

test_that("an empty pattern gets a panel that says so, not a broken figure", {
  # A constructor returning nothing is a bug upstream, and a chapter that renders
  # an empty axis instead of a message hides it.
  empty <- miura
  empty$vertices <- empty$vertices[0L, , drop = FALSE]
  empty$facets <- list()
  empty$creases <- empty$creases[0L, , drop = FALSE]
  expect_s3_class(plot_crease_pattern(empty), "ggplot")
  expect_s3_class(plot_embedding(matrix(numeric(0), 0L, 2L),
                                 matrix(numeric(0), 0L, 2L)), "ggplot")
})

test_that("plot_embedding() checks that its two arguments are the same points", {
  set.seed(9L)
  emb <- matrix(rnorm(200L), 100L, 2L)
  tru <- matrix(rnorm(200L), 100L, 2L)
  expect_s3_class(plot_embedding(emb, tru), "ggplot")

  expect_error(plot_embedding(emb, tru[1:50, , drop = FALSE]),
               "the same points seen two ways")
  expect_error(plot_embedding(emb, tru, dims = 1:3), "two columns")
  expect_error(plot_embedding(emb, tru, coord = 5L), "one column")
  expect_error(plot_embedding(emb, tru, n_iso = NULL), "single non-negative")
  expect_error(plot_embedding(emb, tru, iso_width = 0), "positive fraction")
})

test_that("n_iso = 0 drops the level sets and nothing else", {
  set.seed(9L)
  emb <- matrix(rnorm(400L), 200L, 2L)
  tru <- matrix(rnorm(400L), 200L, 2L)
  with_iso <- plot_embedding(emb, tru, n_iso = 5L)
  without  <- plot_embedding(emb, tru, n_iso = 0L)
  expect_lt(length(without$layers), length(with_iso$layers))
  expect_gte(length(without$layers), 1L)
})
