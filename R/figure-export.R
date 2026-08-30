# ── Geometry export for the interactive figures ─────────────────────────────
#
# The book's interactive figures are rendered in the browser, but their geometry
# is computed here, where it is tested. The JavaScript draws; it does not know
# what a crease pattern is and cannot get one wrong.
#
# What is exported per facet is the pair the whole book is about: the facet's
# polygon in the flat chart, and the same facet's polygon in the folded ambient
# embedding. Every figure that shows both panels is showing that pair.

#' Export a folded pattern as the facet pairs an interactive figure needs.
#'
#' @return a list ready for jsonlite::toJSON(auto_unbox = TRUE)
figure_geometry <- function(pattern, theta, name = pattern$family) {
  f <- fold(pattern, theta)

  flat   <- lapply(pattern$facets, function(v) pattern$vertices[v, , drop = FALSE])
  folded <- lapply(pattern$facets, function(v) f$vertices3[v, , drop = FALSE])

  # Centre both panels on the origin and scale the folded one to unit radius, so
  # the renderer needs no knowledge of the model to frame it.
  cflat <- colMeans(do.call(rbind, flat))
  cfold <- colMeans(do.call(rbind, folded))
  flat   <- lapply(flat,   function(P) sweep(P, 2, cflat))
  folded <- lapply(folded, function(P) sweep(P, 2, cfold))
  r <- max(sqrt(rowSums(do.call(rbind, folded)^2)))
  folded <- lapply(folded, function(P) P / r)
  rf <- max(sqrt(rowSums(do.call(rbind, flat)^2)))
  flat <- lapply(flat, function(P) P / rf)

  # Isometry is asserted at export. A figure that showed a flat panel which was
  # not the exact unfolding of the folded panel would be making the book's
  # central claim and quietly breaking it.
  err <- max(vapply(seq_along(flat), function(i) {
    a <- as.matrix(stats::dist(flat[[i]]))   * rf
    b <- as.matrix(stats::dist(folded[[i]])) * r
    max(abs(a - b))
  }, numeric(1)))
  if (err > 1e-9) {
    stop("the flat and folded panels are not isometric (worst ", format(err),
         "). Refusing to export a figure that contradicts the book.", call. = FALSE)
  }

  list(
    name    = name,
    theta   = theta,
    n_facet = length(flat),
    isometry_error = err,
    flat    = lapply(flat,   function(P) unname(as.data.frame(round(P, 6)))),
    folded  = lapply(folded, function(P) unname(as.data.frame(round(P, 6)))),
    creases = local({
      cr <- pattern$creases[pattern$creases$assignment != "B", , drop = FALSE]
      lapply(seq_len(nrow(cr)), function(k) list(
        a = unname(round((pattern$vertices[cr$i[k], ] - cflat) / rf, 6)),
        b = unname(round((pattern$vertices[cr$j[k], ] - cflat) / rf, 6)),
        assignment = cr$assignment[k]))
    })
  )
}

#' Write the geometry as a JSON file the figure can inline.
write_figure_geometry <- function(pattern, theta, path, name = pattern$family) {
  g <- figure_geometry(pattern, theta, name)
  writeLines(jsonlite::toJSON(g, auto_unbox = TRUE, digits = 6), path)
  invisible(g)
}

# ── Static fallback ─────────────────────────────────────────────────────────
#
# The interactive figure is HTML. PDF and EPUB readers get this instead: the
# same two panels at one fixed view, with the same visibility computation, so
# the printed figure makes the identical point and cannot disagree with the
# interactive one.

#' The camera, written once.
#'
#' Azimuth about z, then elevation about the rotated x-axis. Returns the three
#' quantities every consumer needs, named, because they were previously derived
#' twice from the same four trig calls and the second derivation had two of them
#' the other way round:
#'
#'   sx     screen horizontal
#'   sy     screen vertical
#'   depth  toward the camera, which sits at +y; nearest is largest
#'
#' `visible_facets()` decided which facets reach the eye using (sx, sy) as the
#' picture plane and `depth` to break ties, and `fold_figure_static()` then DREW
#' the panel with those last two exchanged -- so the greyed-out facets in panel A
#' were the ones hidden in a view that panel B did not show, and the subtitle
#' counting them was counting the wrong view. One function, so the two cannot
#' disagree again; tests/testthat/test-figure-export.R checks the drawn panel
#' against an independent projection rather than against this one.
.view_project <- function(V3, az, el) {
  ca <- cos(az); sa <- sin(az); ce <- cos(el); se <- sin(el)
  x <- V3[, 1] * ca - V3[, 2] * sa
  y <- V3[, 1] * sa + V3[, 2] * ca
  z <- V3[, 3]
  cbind(sx = x, depth = y * ce - z * se, sy = y * se + z * ce)
}

#' Which facets reach the eye, at a given view.
#'
#' Sampled rather than reasoned about. A front-facing test alone answers a
#' different and easier question -- it cannot see that a facet is hidden BEHIND
#' another one, which is exactly what a fold does. So the projected scene is
#' sampled on a grid and, at each sample, the nearest facet containing it wins.
#'
#' The camera sits at +y looking toward -y, so nearest means largest depth.
#'
#' Sampling has a floor: a facet whose visible sliver is narrower than the grid
#' spacing is reported hidden. `grid` sets that floor, and the default is fine
#' for the patterns in this book -- raise it if a figure disagrees with what the
#' rendered panel plainly shows.
visible_facets <- function(pattern, theta, az = 35 * pi / 180, el = -0.42,
                           grid = 260L) {
  f <- fold(pattern, theta)
  R <- .view_project(f$vertices3, az, el)
  polys <- lapply(pattern$facets, function(v) R[v, , drop = FALSE])

  rng <- range(c(R[, 1], R[, 3]))
  gx <- seq(rng[1], rng[2], length.out = grid)
  seen <- integer(0)
  inpoly <- function(px, py, P) {
    n <- nrow(P); c <- FALSE; j <- n
    for (i in seq_len(n)) {
      if ((P[i, 3] > py) != (P[j, 3] > py) &&
          px < (P[j, 1] - P[i, 1]) * (py - P[i, 3]) / (P[j, 3] - P[i, 3]) + P[i, 1]) c <- !c
      j <- i
    }
    c
  }
  for (px in gx) for (py in gx) {
    best <- NA_integer_; bd <- -Inf
    for (k in seq_along(polys)) {
      P <- polys[[k]]
      if (inpoly(px, py, P)) {
        d <- mean(P[, 2])
        if (d > bd) { bd <- d; best <- k }
      }
    }
    if (!is.na(best)) seen <- c(seen, best)
  }
  sort(unique(seen))
}

#' The polygons the static figure draws, separated from the drawing.
#'
#' A grob cannot be asserted against, so the geometry the figure is made of is
#' built here and tested here. Panel B's `y` is the projection's screen vertical
#' and its `depth` is the projection's depth -- which is the whole content of the
#' defect this seam exists to make visible.
fold_figure_data <- function(pattern, theta, az = 35 * pi / 180, el = -0.42) {
  vis <- visible_facets(pattern, theta, az, el)
  f   <- fold(pattern, theta)
  nf  <- length(pattern$facets)
  R   <- .view_project(f$vertices3, az, el)

  flatdf <- do.call(rbind, lapply(seq_len(nf), function(i) {
    P <- pattern$vertices[pattern$facets[[i]], , drop = FALSE]
    data.frame(facet = i, x = P[, 1], y = P[, 2],
               visible = i %in% vis, stringsAsFactors = FALSE)
  }))

  folddf <- do.call(rbind, lapply(seq_len(nf), function(i) {
    v <- pattern$facets[[i]]
    data.frame(facet = i, x = R[v, "sx"], y = R[v, "sy"],
               depth = mean(R[v, "depth"]),
               visible = i %in% vis, stringsAsFactors = FALSE)
  }))
  folddf$facet <- factor(folddf$facet,
                         levels = unique(folddf$facet[order(folddf$depth)]))

  list(flat = flatdf, fold = folddf, visible = vis, n_facet = nf)
}

#' The two-panel figure, as a static graphic.
fold_figure_static <- function(pattern, theta, az = 35 * pi / 180, el = -0.42) {
  d      <- fold_figure_data(pattern, theta, az, el)
  vis    <- d$visible
  nf     <- d$n_facet
  flatdf <- d$flat
  folddf <- d$fold
  pal    <- viridis::viridis(nf, option = BOOK_VIRIDIS_OPTION)

  fill_for <- function(i, visible) ifelse(visible, pal[i], "grey78")

  gA <- ggplot2::ggplot(flatdf, ggplot2::aes(x, y, group = facet)) +
    ggplot2::geom_polygon(fill = fill_for(flatdf$facet, flatdf$visible),
                          colour = "grey25", linewidth = 0.25) +
    ggplot2::coord_equal() + ggplot2::theme_void() +
    ggplot2::labs(title = "A  The flat sheet",
                  subtitle = sprintf("%d of %d facets visible in B", length(vis), nf))

  # B is the view, so every facet in it is drawn in its own colour. Grey means
  # "you cannot see this from here" and belongs only in A -- greying a facet in
  # B would grey the very thing the reader is looking at.
  gB <- ggplot2::ggplot(folddf, ggplot2::aes(x, y, group = facet)) +
    ggplot2::geom_polygon(fill = pal[as.integer(as.character(folddf$facet))],
                          colour = "grey25", linewidth = 0.25) +
    ggplot2::coord_equal() + ggplot2::theme_void() +
    ggplot2::labs(title = "B  The same sheet, folded",
                  subtitle = sprintf("fold parameter θ = %.2f", theta))

  gridExtra::arrangeGrob(gA, gB, ncol = 2)
}
