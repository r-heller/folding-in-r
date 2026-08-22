# Figures.
#
# Every function here returns a ggplot object and none of them prints. Chapters
# call these inside chunks, where knitr prints the returned value; a function
# that printed as a side effect would emit each figure twice, once from the
# side effect and once from the value.
#
# Two kinds of bad input, handled differently on purpose, because these run at
# render time:
#
#   * Malformed input is fatal. Wrong class, wrong column count, a crease index
#     past the end of the vertex table, a non-finite coordinate. A figure drawn
#     from a broken object is worse than a build that stops, and every one of
#     these conditions means some helper upstream returned something it should
#     not have.
#
#   * Empty input is annotated, not fatal. Zero vertices, zero creases, zero
#     points. A theta sweep can legitimately produce a degenerate cell, and the
#     panel for it has to say so on its face -- an empty panel and a panel of a
#     genuinely empty object look identical, which is the failure mode this
#     avoids.
#
# No base graphics and no rgl. plot_folded() projects to 2-D and hands the
# result to ggplot2 like everything else, so the folded figures inherit the
# theme, the palette, the fig.alt discipline and the PDF path instead of
# forking a second rendering stack that none of that applies to.
#
# Internal helpers carry a leading dot. R/ is sourced into the global
# environment, so everything in this file is visible from a chapter; the dot
# marks what is not part of the interface.

# ── Scales and theme ─────────────────────────────────────────────────────────

# _common.R defines the discrete pair scale_fill_book() / scale_colour_book()
# for the chapters. These are the continuous counterparts, and they live here
# rather than there because tests/testthat/setup.R sources R/ without
# _common.R: a plotting function that reached for scale_colour_book() would be
# unreachable from the tests, which are the only place these functions run
# outside a render. Both read BOOK_VIRIDIS_OPTION at call time, not source
# time, so constants.R is a call-time dependency exactly as R/README.md
# requires.
#
# viridis exports scale_colour_viridis(discrete = ) and nothing suffixed --
# the scale_*_viridis_c and _d forms belong to ggplot2, not to viridis. Getting
# that wrong fails at render time with "not an exported object", which is a
# poor way to discover it, so these name the package that actually exports the
# function.
scale_colour_book_c <- function(...) {
  viridis::scale_colour_viridis(discrete = FALSE,
                                option = BOOK_VIRIDIS_OPTION, ...)
}

scale_color_book_c <- scale_colour_book_c

scale_fill_book_c <- function(...) {
  viridis::scale_fill_viridis(discrete = FALSE,
                              option = BOOK_VIRIDIS_OPTION, ...)
}

# Matches theme_sci() in the sibling volume: bold title, legend below the panel
# so a wide legend does not steal width from a figure printed at out.width
# 90%, and no minor grid, which on a geometry figure reads as more creases.
theme_fold <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title       = ggplot2::element_text(face = "bold"),
      plot.subtitle    = ggplot2::element_text(colour = "grey30"),
      legend.position  = "bottom",
      panel.grid.minor = ggplot2::element_blank()
    )
}

# ── Validation ───────────────────────────────────────────────────────────────

# Coordinate tables arrive as matrices from the helpers and as data frames from
# anything a reader assembles by hand, so accept both and normalise to a
# matrix. Non-finite coordinates are fatal rather than dropped: ggplot2 would
# drop them with a warning that reads as cosmetic, and a method that returned
# NA for a third of its points would then produce a figure that looks fine.
.as_coords <- function(x, what, ncol_min = 2L) {
  if (is.data.frame(x)) x <- as.matrix(x)
  if (!is.matrix(x) || !is.numeric(x)) {
    stop(what, " must be a numeric matrix or data frame; got ",
         paste(class(x), collapse = "/"), call. = FALSE)
  }
  if (ncol(x) < ncol_min) {
    stop(what, " needs at least ", ncol_min, " columns; got ", ncol(x),
         call. = FALSE)
  }
  bad <- sum(!is.finite(x))
  if (bad > 0L) {
    stop(what, " holds ", bad, " non-finite value(s). Fix the object rather ",
         "than the figure -- these would be silently dropped.", call. = FALSE)
  }
  x
}

# The crease_pattern contract in R/README.md, checked field by field. Every
# message names the field, because the caller is a chapter chunk and the
# traceback stops here.
.check_crease_pattern <- function(pattern, what = "pattern") {
  if (!inherits(pattern, "crease_pattern")) {
    stop(what, " must be a crease_pattern (see R/README.md); got ",
         paste(class(pattern), collapse = "/"), call. = FALSE)
  }
  missing <- setdiff(c("vertices", "facets", "creases"), names(pattern))
  if (length(missing)) {
    stop(what, " is missing required field(s): ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  v <- .as_coords(pattern$vertices, paste0(what, "$vertices"), ncol_min = 2L)

  if (!is.list(pattern$facets)) {
    stop(what, "$facets must be a list of vertex-index vectors", call. = FALSE)
  }
  fidx <- unlist(pattern$facets, use.names = FALSE)
  if (anyNA(fidx)) {
    stop(what, "$facets holds a missing vertex index", call. = FALSE)
  }
  fmax <- max(c(0L, fidx))
  if (fmax > nrow(v)) {
    stop(what, "$facets indexes vertex ", fmax, " but there are only ",
         nrow(v), call. = FALSE)
  }

  cr <- pattern$creases
  if (!is.data.frame(cr)) {
    stop(what, "$creases must be a data frame with columns i, j, assignment",
         call. = FALSE)
  }
  missing <- setdiff(c("i", "j", "assignment"), names(cr))
  if (length(missing)) {
    stop(what, "$creases is missing column(s): ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  if (nrow(cr) > 0L) {
    idx <- c(cr$i, cr$j)
    if (!is.numeric(idx) || any(is.na(idx)) ||
        any(idx < 1L) || any(idx > nrow(v))) {
      stop(what, "$creases has endpoint indices outside 1:", nrow(v),
           call. = FALSE)
    }
    unknown <- setdiff(unique(as.character(cr$assignment)),
                       names(CREASE_COLOUR))
    if (length(unknown)) {
      stop(what, "$creases has assignment(s) outside ",
           paste(names(CREASE_COLOUR), collapse = "/"), ": ",
           paste(unknown, collapse = ", "), call. = FALSE)
    }
  }
  invisible(TRUE)
}

# ── Geometry helpers ─────────────────────────────────────────────────────────

# Creases as a segment table. Returns NULL for an uncreased sheet, which the
# callers turn into a stated caption rather than an unexplained blank.
.crease_segments <- function(pattern) {
  cr <- pattern$creases
  if (nrow(cr) == 0L) return(NULL)
  v <- as.matrix(pattern$vertices)
  data.frame(
    x          = v[cr$i, 1L],
    y          = v[cr$i, 2L],
    xend       = v[cr$j, 1L],
    yend       = v[cr$j, 2L],
    assignment = factor(as.character(cr$assignment),
                        levels = names(CREASE_COLOUR)),
    stringsAsFactors = FALSE
  )
}

# Facets as a polygon table, in painter's order: group 1 is the farthest facet
# and grid draws polygons by ascending group id, so opaque fills give hidden-
# line removal for free. Without it a folded pattern is a wireframe in which
# the far half of the sheet reads as the near half.
#
# Facets with fewer than three vertices are dropped; they cannot be drawn as a
# polygon and are not an error, since a degenerate strip at the sheet edge is a
# legitimate thing for a pattern constructor to return.
.polygon_frame <- function(xy, facets, depth = NULL) {
  keep <- which(lengths(facets) >= 3L)
  if (!length(keep)) return(NULL)
  d <- if (is.null(depth)) {
    rep(0, length(keep))
  } else {
    vapply(keep, function(k) mean(depth[facets[[k]]]), numeric(1))
  }
  ord <- order(d)
  parts <- lapply(seq_along(ord), function(g) {
    idx <- facets[[keep[ord[g]]]]
    data.frame(x = xy[idx, 1L], y = xy[idx, 2L],
               group = g, depth = d[ord[g]])
  })
  do.call(rbind, parts)
}

# Axonometric projection: yaw about the sheet normal by `azimuth`, then lift
# the camera by `elevation`. `near` increases toward the viewer, which is what
# .polygon_frame() sorts on.
#
# A projection rather than a perspective, because the book measures distances
# in these figures by eye -- a reader comparing facet widths across a fold
# should not be reading a foreshortening that varies with depth.
.project <- function(v3, azimuth = 35, elevation = 25) {
  a <- azimuth * pi / 180
  e <- elevation * pi / 180
  along <- v3[, 1L] * cos(a) + v3[, 2L] * sin(a)
  data.frame(
    px   = -v3[, 1L] * sin(a) + v3[, 2L] * cos(a),
    py   = -along * sin(e) + v3[, 3L] * cos(e),
    near =  along * cos(e) + v3[, 3L] * sin(e)
  )
}

# Level sets of the chart coordinate, drawn in the embedding. See
# plot_embedding() for why they are there.
#
# Bands are taken at equally spaced levels in the interior of the coordinate's
# range and are `width` of that range wide on each side. A band holding fewer
# than three points is dropped rather than drawn as a stub: with 800 points and
# the default width a band holds tens of points, and a band that does not is
# reporting sampling noise, not a level set.
.iso_bands <- function(x, y, u, w, n_iso, width) {
  if (n_iso < 1L) return(NULL)
  rng <- range(u)
  span <- diff(rng)
  if (!is.finite(span) || span <= 0) return(NULL)
  levels_u <- seq(rng[1L], rng[2L], length.out = n_iso + 2L)[-c(1L, n_iso + 2L)]
  half <- width * span
  parts <- lapply(seq_along(levels_u), function(k) {
    sel <- which(abs(u - levels_u[k]) <= half)
    if (length(sel) < 3L) return(NULL)
    sel <- sel[order(w[sel])]
    data.frame(x = x[sel], y = y[sel], band = k)
  })
  parts <- parts[!vapply(parts, is.null, logical(1))]
  if (!length(parts)) return(NULL)
  do.call(rbind, parts)
}

# The annotated blank. Both an in-panel label and a subtitle: the subtitle can
# be cropped by a tight out.width and the label cannot, and the point of this
# panel is that it cannot be mistaken for a result.
.empty_panel <- function(note, title = NULL) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0, y = 0, label = note,
                      size = 3.5, colour = "grey30") +
    ggplot2::labs(title = title, subtitle = note, x = NULL, y = NULL) +
    theme_fold() +
    ggplot2::theme(
      axis.text  = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank()
    )
}

# Colour and linetype for crease assignment, as one merged legend. Both scales
# carry the same name, limits and labels, which is what makes ggplot2 draw one
# key instead of two, and drop = FALSE keeps all three entries present whether
# or not the pattern uses them -- a legend that gains and loses rows between
# panels of a theta sweep makes those panels unreadable against each other.
.crease_scales <- function() {
  list(
    ggplot2::scale_colour_manual(
      name   = "crease",
      values = CREASE_COLOUR,
      limits = names(CREASE_COLOUR),
      labels = CREASE_LABEL,
      drop   = FALSE
    ),
    ggplot2::scale_linetype_manual(
      name   = "crease",
      values = CREASE_LINETYPE,
      limits = names(CREASE_COLOUR),
      labels = CREASE_LABEL,
      drop   = FALSE
    )
  )
}

# ── The flat pattern ─────────────────────────────────────────────────────────

# The unfolded crease pattern: the chart, and the book's ground truth. Mountain
# and valley are separated by colour and by linetype together, per standing
# rule 3 -- the figure has to survive greyscale printing and a colour-blind
# reader, and this is the one figure in the book where that distinction carries
# the whole content.
plot_crease_pattern <- function(pattern,
                                title      = NULL,
                                subtitle   = NULL,
                                facet_fill = "grey95",
                                linewidth  = 0.6,
                                vertices   = FALSE) {
  .check_crease_pattern(pattern)
  v <- as.matrix(pattern$vertices)

  if (nrow(v) == 0L) {
    return(.empty_panel("crease pattern has no vertices", title))
  }

  p <- ggplot2::ggplot()

  # Facet fill under the creases, not over them. It is a reading aid for the
  # tessellation and carries no variable, so it takes a flat colour and no
  # legend.
  if (length(facet_fill) == 1L && !is.na(facet_fill)) {
    poly <- .polygon_frame(v, pattern$facets)
    if (!is.null(poly)) {
      p <- p + ggplot2::geom_polygon(
        data = poly,
        ggplot2::aes(x = x, y = y, group = group),
        fill = facet_fill, colour = NA
      )
    }
  }

  # An uncreased sheet is a legitimate object -- it is what a pattern
  # constructor returns at the degenerate end of its parameter range -- so draw
  # its vertices and say in the caption that there are no creases. The caption
  # rather than the subtitle, because the caller may have supplied one and this
  # note must not displace it.
  caption <- NULL
  seg <- .crease_segments(pattern)
  if (is.null(seg)) {
    p <- p + ggplot2::geom_point(
      data = data.frame(x = v[, 1L], y = v[, 2L]),
      ggplot2::aes(x = x, y = y), size = 0.9, colour = "grey30"
    )
    caption <- "no creases -- an uncreased sheet"
  } else {
    p <- p + ggplot2::geom_segment(
      data = seg,
      ggplot2::aes(x = x, y = y, xend = xend, yend = yend,
                   colour = assignment, linetype = assignment),
      linewidth = linewidth
    ) + .crease_scales()
  }

  if (isTRUE(vertices)) {
    p <- p + ggplot2::geom_point(
      data = data.frame(x = v[, 1L], y = v[, 2L]),
      ggplot2::aes(x = x, y = y), size = 0.7, colour = "grey20"
    )
  }

  p +
    ggplot2::coord_equal() +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption,
                  x = quote(u[1]), y = quote(u[2])) +
    theme_fold()
}

# ── The folded pattern ───────────────────────────────────────────────────────

# A folded_pattern at its theta, projected to 2-D. Facets are drawn far-first
# and opaque so that the near half of the sheet hides the far half; the crease
# lines go on top with the same colour-and-linetype encoding the flat figure
# uses, so the two read as the same object.
#
# Depth shading is a reading aid, not a variable, and its legend is suppressed
# for exactly that reason: a colourbar next to it would invite the reader to
# treat the grey ramp as a measurement.
plot_folded <- function(folded,
                        azimuth   = 35,
                        elevation = 25,
                        title     = NULL,
                        subtitle  = NULL,
                        shade     = TRUE,
                        linewidth = 0.5) {
  if (!inherits(folded, "folded_pattern")) {
    stop("folded must be a folded_pattern (see R/README.md); got ",
         paste(class(folded), collapse = "/"), call. = FALSE)
  }
  missing <- setdiff(c("pattern", "theta", "vertices3"), names(folded))
  if (length(missing)) {
    stop("folded is missing required field(s): ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  if (!is.numeric(folded$theta) || length(folded$theta) != 1L ||
      !is.finite(folded$theta)) {
    stop("folded$theta must be a single finite number", call. = FALSE)
  }
  .check_crease_pattern(folded$pattern, "folded$pattern")

  v3 <- .as_coords(folded$vertices3, "folded$vertices3", ncol_min = 3L)
  # vertices3 is row-aligned with the chart by contract. If it is not, every
  # crease in the figure connects the wrong two points and the picture is still
  # plausible, which is why this is checked rather than trusted.
  if (nrow(v3) != nrow(as.matrix(folded$pattern$vertices))) {
    stop("folded$vertices3 has ", nrow(v3), " rows but the pattern has ",
         nrow(as.matrix(folded$pattern$vertices)),
         " vertices; they are row-aligned by contract", call. = FALSE)
  }

  if (nrow(v3) == 0L) {
    return(.empty_panel("folded pattern has no vertices", title))
  }
  if (is.null(subtitle)) subtitle <- .theta_label(folded$theta)

  pr <- .project(v3, azimuth, elevation)
  xy <- cbind(pr$px, pr$py)

  p <- ggplot2::ggplot()

  poly <- .polygon_frame(xy, folded$pattern$facets, depth = pr$near)
  if (!is.null(poly)) {
    if (isTRUE(shade)) {
      p <- p +
        ggplot2::geom_polygon(
          data = poly,
          ggplot2::aes(x = x, y = y, group = group, fill = depth),
          colour = NA
        ) +
        ggplot2::scale_fill_gradient(low = "grey80", high = "grey97",
                                     guide = "none")
    } else {
      p <- p + ggplot2::geom_polygon(
        data = poly,
        ggplot2::aes(x = x, y = y, group = group),
        fill = "grey92", colour = NA
      )
    }
  }

  # The subtitle carries theta as a plotmath expression, so the no-creases note
  # goes in the caption rather than being pasted onto it -- paste() would
  # deparse the expression and print the call.
  caption <- NULL
  seg <- .crease_segments(
    list(vertices = xy, creases = folded$pattern$creases)
  )
  if (is.null(seg)) {
    p <- p + ggplot2::geom_point(
      data = data.frame(x = pr$px, y = pr$py),
      ggplot2::aes(x = x, y = y), size = 0.9, colour = "grey30"
    )
    caption <- "no creases -- an uncreased sheet"
  } else {
    p <- p + ggplot2::geom_segment(
      data = seg,
      ggplot2::aes(x = x, y = y, xend = xend, yend = yend,
                   colour = assignment, linetype = assignment),
      linewidth = linewidth
    ) + .crease_scales()
  }

  # A projection has no meaningful axes: the units are not the chart's and not
  # the ambient space's, they are the screen's. Labelling them would invite
  # measurement off the page.
  p +
    ggplot2::coord_equal() +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption,
                  x = NULL, y = NULL) +
    theme_fold() +
    ggplot2::theme(
      axis.text  = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank()
    )
}

# theta belongs on every folded figure: standing rule 2 makes it the difficulty
# axis, and a folded pattern shown without it is the single-number report that
# rule exists to prevent. plotmath rather than a Unicode theta, so the symbol
# survives into the PDF whatever font the device has.
.theta_label <- function(theta) {
  bquote(theta == .(signif(theta, 3)))
}

# ── Embeddings ───────────────────────────────────────────────────────────────

# An embedding, coloured by one exact chart coordinate. This is how the reader
# sees a fold that a method did not undo: the two sides of a crease carry
# colours from opposite ends of the ramp, and where the method has folded the
# chart back onto itself they land on top of each other.
#
# Colour alone would breach standing rule 3, so the level sets of that same
# coordinate are drawn over the points. They are the redundant channel and they
# are also the sharper signal. Read them as a family: an embedding that
# recovered the chart draws them nested, ordered and non-crossing; one that
# folded the chart draws two of them on top of each other. Checked on a chart
# folded at its midpoint -- seven requested bands collapse to four visible
# paths, and the collapse is legible with the colourbar covered. Set n_iso = 0
# to drop them.
plot_embedding <- function(emb, truth,
                           coord       = 1L,
                           dims        = 1:2,
                           title       = NULL,
                           subtitle    = NULL,
                           coord_label = NULL,
                           point_size  = 0.8,
                           alpha       = 0.85,
                           n_iso       = 5L,
                           iso_width   = 0.02) {
  emb   <- .as_coords(emb, "emb", ncol_min = 2L)
  truth <- .as_coords(truth, "truth", ncol_min = 1L)

  if (nrow(emb) != nrow(truth)) {
    stop("emb has ", nrow(emb), " rows and truth has ", nrow(truth),
         "; they are the same points seen two ways", call. = FALSE)
  }
  if (length(dims) != 2L || any(dims < 1L) || any(dims > ncol(emb))) {
    stop("dims must name two columns of emb (1:", ncol(emb), ")",
         call. = FALSE)
  }
  if (length(coord) != 1L || coord < 1L || coord > ncol(truth)) {
    stop("coord must name one column of truth (1:", ncol(truth), ")",
         call. = FALSE)
  }
  # NULL here would make the level-set branch below fail with "argument is of
  # length zero", which names nothing the caller passed.
  if (length(n_iso) != 1L || !is.finite(n_iso) || n_iso < 0L) {
    stop("n_iso must be a single non-negative number", call. = FALSE)
  }
  if (length(iso_width) != 1L || !is.finite(iso_width) || iso_width <= 0) {
    stop("iso_width must be a single positive fraction of the coordinate range",
         call. = FALSE)
  }

  if (is.null(coord_label)) {
    coord_label <- bquote(chart ~ u[.(as.integer(coord))])
  }
  if (nrow(emb) == 0L) {
    return(.empty_panel("embedding has no points", title))
  }

  df <- data.frame(
    x = emb[, dims[1L]],
    y = emb[, dims[2L]],
    u = truth[, coord]
  )

  p <- ggplot2::ggplot() +
    ggplot2::geom_point(
      data = df,
      ggplot2::aes(x = x, y = y, colour = u),
      size = point_size, alpha = alpha
    ) +
    scale_colour_book_c(name = coord_label)

  # The other chart coordinate orders each band into a path. With a
  # one-column truth there is no such ordering and the level sets are
  # meaningless, so they are simply not drawn.
  if (ncol(truth) >= 2L && n_iso > 0L) {
    other <- if (coord == 1L) 2L else 1L
    iso <- .iso_bands(df$x, df$y, df$u, truth[, other], n_iso, iso_width)
    if (!is.null(iso)) {
      p <- p + ggplot2::geom_path(
        data = iso,
        ggplot2::aes(x = x, y = y, group = band),
        colour = "grey20", linewidth = 0.3, alpha = 0.9
      )
    }
  }

  # coord_equal, because an embedding stretched to fill the panel is an
  # embedding whose distortion has been hidden by the aspect ratio -- which is
  # the thing every figure in Parts II and III is trying to show.
  p +
    ggplot2::coord_equal() +
    ggplot2::labs(title = title, subtitle = subtitle,
                  x = "embedding 1", y = "embedding 2") +
    theme_fold()
}
