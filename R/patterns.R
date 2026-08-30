# ── Crease patterns ─────────────────────────────────────────────────────────
#
# The flat, unfolded patterns. Everything here lives in the plane: these
# functions know nothing about folding, and R/folding.R knows nothing about how
# a pattern was constructed.
#
# The unfolded vertex coordinates are the book's ground truth. Not an
# approximation of the correct two-dimensional embedding -- the embedding
# itself. That is the whole premise, and it is why this file is short and
# exact rather than long and fitted.
#
# See R/README.md for the crease_pattern contract.

# ── Constructors ────────────────────────────────────────────────────────────

crease_pattern <- function(vertices, facets, creases, family, params) {
  stopifnot(is.matrix(vertices), ncol(vertices) == 2L,
            is.list(facets), is.data.frame(creases))
  structure(
    list(vertices = vertices, facets = facets, creases = creases,
         family = family, params = params),
    class = "crease_pattern"
  )
}

#' Miura-ori
#'
#' The parallelogram tessellation of Miura (1985). Cell parameters are the two
#' side lengths a and b and the acute angle alpha.
#'
#' Layout. Vertex (i, j) sits at
#'
#'     x = i * a + (j mod 2) * b * cos(alpha)
#'     y = j * b * sin(alpha)
#'
#' The (j mod 2) term is the whole pattern: it makes the "vertical" crease lines
#' zigzag with period two instead of running straight, which is what turns a
#' plain parallelogram lattice into a developable fold. Every facet is then a
#' parallelogram with sides a and b, congruent to every other -- asserted in the
#' tests rather than assumed here.
miura_ori <- function(nx = 6L, ny = 6L, a = 1, b = 1, alpha = pi / 3) {
  stopifnot(nx >= 1L, ny >= 1L, a > 0, b > 0, alpha > 0, alpha < pi / 2)

  idx <- function(i, j) j * (nx + 1L) + i + 1L      # 0-based (i, j) -> 1-based

  ii <- rep(0:nx, times = ny + 1L)
  jj <- rep(0:ny, each  = nx + 1L)
  vertices <- cbind(
    x = ii * a + (jj %% 2L) * b * cos(alpha),
    y = jj * b * sin(alpha)
  )

  facets <- vector("list", nx * ny)
  k <- 0L
  for (j in 0:(ny - 1L)) for (i in 0:(nx - 1L)) {
    k <- k + 1L
    # counter-clockwise
    facets[[k]] <- c(idx(i, j), idx(i + 1L, j), idx(i + 1L, j + 1L), idx(i, j + 1L))
  }

  # Creases.
  #
  # These labels are a RECORD of what the folding does, not a choice. They are
  # the closed form of crease_assignment() on this family, and the suite asserts
  # the two agree across the size x alpha x theta sweep -- so the constructor
  # stays ignorant of R/folding.R, as the file header requires, without the two
  # being free to drift apart.
  #
  # The folded placement is z = (i mod 2) H (see .fold_miura): the corrugation
  # runs across the columns, so the ZIGZAG lines at constant i are its ridges and
  # troughs. A zigzag line at odd i sits a height H above both its neighbours
  # along its whole length and is therefore mountain end to end; at even i it is
  # valley end to end. The assignment depends on i alone -- j does not enter.
  #
  # The horizontal lines cross that corrugation, climbing a slope and descending
  # the next, and their creases alternate M, V, M, V along each row: mountain
  # when (i + j) is even. Their fold is purely horizontal -- both adjacent facets
  # span the same two heights, so the crease midpoint and the material around it
  # sit at exactly the same z -- which is why a ridge-versus-trough test on
  # height alone reads them as degenerate and cannot label them at all.
  #
  # Maekawa follows rather than being imposed. At an interior vertex the two
  # zigzag creases share an i and so agree, while the two horizontal creases have
  # left indices i - 1 and i and so differ: 3 of one and 1 of the other,
  # |M - V| = 2, at every interior vertex.
  #
  # An earlier rule had this transposed -- horizontals constant along a row,
  # zigzags alternating in (i + j) -- reasoning from Maekawa alone. It also gives
  # 3/1 at every vertex, which is the whole problem: Maekawa constrains the
  # counts at a vertex and cannot see which crease got which label. It agreed
  # with the geometry on exactly half the interior creases, and every figure in
  # the book drew mountain-solid and valley-dashed on that basis. See
  # ROADMAP.md section 5 and the note above crease_assignment().
  #
  # Boundary edges fold not at all and are marked "B" so that folding can skip
  # them without a special case.
  cr <- list()
  add <- function(i1, j1, i2, j2, assignment) {
    cr[[length(cr) + 1L]] <<- data.frame(
      i = idx(i1, j1), j = idx(i2, j2), assignment = assignment,
      stringsAsFactors = FALSE
    )
  }
  for (j in 0:ny) for (i in 0:(nx - 1L)) {              # horizontal: straight rows
    boundary <- (j == 0L || j == ny)
    add(i, j, i + 1L, j, if (boundary) "B" else if ((i + j) %% 2L == 0L) "M" else "V")
  }
  for (j in 0:(ny - 1L)) for (i in 0:nx) {             # zigzag: the corrugation
    boundary <- (i == 0L || i == nx)
    add(i, j, i, j + 1L, if (boundary) "B" else if (i %% 2L == 1L) "M" else "V")
  }
  creases <- do.call(rbind, cr)

  crease_pattern(vertices, facets, creases, "miura",
                 list(nx = nx, ny = ny, a = a, b = b, alpha = alpha))
}

#' Yoshimura (diamond) pattern
#'
#' A triangular tessellation. Rows of triangles alternate in orientation, with
#' consecutive rows offset by half a cell, so every interior vertex has degree
#' six and every facet is congruent.
#'
#' The literature's negative result on Yoshimura rigid-foldability concerns the
#' closed CYLINDER, where circumferential closure removes the mechanism. A
#' finite planar patch is a different object and is what this returns; the
#' verification in tests/testthat is against the patch.
yoshimura <- function(nx = 6L, ny = 6L, a = 1, height = NULL) {
  stopifnot(nx >= 1L, ny >= 1L, a > 0)
  h <- if (is.null(height)) a * sqrt(3) / 2 else height   # equilateral by default

  idx <- function(i, j) j * (nx + 1L) + i + 1L

  ii <- rep(0:nx, times = ny + 1L)
  jj <- rep(0:ny, each  = nx + 1L)
  vertices <- cbind(
    x = ii * a + (jj %% 2L) * a / 2,
    y = jj * h
  )

  # Each cell splits into two triangles. The diagonal alternates direction with
  # the row so that the pattern is a genuine diamond tessellation rather than a
  # sheared grid -- an unalternated diagonal gives every vertex the same
  # orientation and the sheet cannot fold.
  facets <- list()
  for (j in 0:(ny - 1L)) for (i in 0:(nx - 1L)) {
    if (j %% 2L == 0L) {
      facets[[length(facets) + 1L]] <- c(idx(i, j), idx(i + 1L, j), idx(i, j + 1L))
      facets[[length(facets) + 1L]] <- c(idx(i + 1L, j), idx(i + 1L, j + 1L), idx(i, j + 1L))
    } else {
      facets[[length(facets) + 1L]] <- c(idx(i, j), idx(i + 1L, j), idx(i + 1L, j + 1L))
      facets[[length(facets) + 1L]] <- c(idx(i, j), idx(i + 1L, j + 1L), idx(i, j + 1L))
    }
  }

  cr <- list()
  add <- function(v1, v2, assignment) {
    cr[[length(cr) + 1L]] <<- data.frame(i = v1, j = v2, assignment = assignment,
                                         stringsAsFactors = FALSE)
  }
  for (j in 0:ny) for (i in 0:(nx - 1L)) {
    add(idx(i, j), idx(i + 1L, j),
        if (j == 0L || j == ny) "B" else if (j %% 2L == 1L) "M" else "V")
  }
  for (j in 0:(ny - 1L)) for (i in 0:nx) {
    boundary <- (i == 0L || i == nx)
    add(idx(i, j), idx(i, j + 1L), if (boundary) "B" else "V")
  }
  # the alternating diagonals
  for (j in 0:(ny - 1L)) for (i in 0:(nx - 1L)) {
    if (j %% 2L == 0L) add(idx(i + 1L, j), idx(i, j + 1L), "M")
    else               add(idx(i, j),      idx(i + 1L, j + 1L), "M")
  }
  creases <- do.call(rbind, cr)

  crease_pattern(vertices, facets, creases, "yoshimura",
                 list(nx = nx, ny = ny, a = a, height = h))
}

#' Waterbomb tessellation
#'
#' Deliberately not implemented. PLAN.md E2 is a go/no-go investigation into
#' whether this tessellation admits a one-parameter rigid folding at all: a
#' degree-6 vertex with sectors (45, 45, 90, 45, 45, 90) satisfies Kawasaki and
#' is therefore flat-foldable AS AN ISOLATED VERTEX, which does not imply the
#' tessellation folds without extra symmetry imposed.
#'
#' The hard rule from that plan is that no PATTERNS entry may exist in
#' run-benchmark-grid.R for a pattern that cannot be built, because a grid row
#' that silently fails is worse than a missing one. This stop() is that rule,
#' enforced where it cannot be forgotten.
waterbomb <- function(nx = 6L, ny = 6L, ...) {
  stop("waterbomb() is not implemented: whether this tessellation admits a ",
       "one-parameter rigid folding is an open question in this project, not a ",
       "coding task. See PLAN.md E2 and scratch-waterbomb/. Until it is ",
       "resolved the book ships two pattern families plus a documented ",
       "negative result, which is the pre-drafted outcome.",
       call. = FALSE)
}

# ── Accessors ───────────────────────────────────────────────────────────────

#' Interior vertices -- those not on the boundary of the sheet.
#'
#' Found combinatorially rather than geometrically: a vertex is interior when
#' every edge at it is shared by two facets. That is robust to the pattern's
#' shape and does not need a convex hull.
interior_vertices <- function(pattern) {
  edges <- facet_edges(pattern)
  key <- paste(pmin(edges$i, edges$j), pmax(edges$i, edges$j), sep = "-")
  shared <- table(key)
  boundary_edges <- edges[key %in% names(shared)[shared == 1L], , drop = FALSE]
  boundary_v <- unique(c(boundary_edges$i, boundary_edges$j))
  setdiff(seq_len(nrow(pattern$vertices)), boundary_v)
}

#' Every (facet, edge) pair, as a data frame of vertex index pairs.
facet_edges <- function(pattern) {
  do.call(rbind, lapply(seq_along(pattern$facets), function(f) {
    v <- pattern$facets[[f]]
    data.frame(facet = f, i = v, j = c(v[-1], v[1]), stringsAsFactors = FALSE)
  }))
}

#' Sector angles at a vertex, in cyclic order.
#'
#' Kawasaki's condition is a statement about these, so they are computed once
#' here and tested rather than recomputed in three places.
sector_angles <- function(pattern, v) {
  fe <- facet_edges(pattern)
  at <- fe[fe$i == v | fe$j == v, , drop = FALSE]
  fs <- unique(at$facet)
  ang <- vapply(fs, function(f) {
    vs <- pattern$facets[[f]]
    k <- which(vs == v)
    prv <- vs[if (k == 1L) length(vs) else k - 1L]
    nxt <- vs[if (k == length(vs)) 1L else k + 1L]
    u <- pattern$vertices[prv, ] - pattern$vertices[v, ]
    w <- pattern$vertices[nxt, ] - pattern$vertices[v, ]
    acos(max(-1, min(1, sum(u * w) / (sqrt(sum(u^2)) * sqrt(sum(w^2))))))
  }, numeric(1))

  # Cyclic order, by the bearing of each facet's centroid from the vertex.
  cen <- t(vapply(fs, function(f) colMeans(pattern$vertices[pattern$facets[[f]], , drop = FALSE]),
                  numeric(2)))
  d <- cen - matrix(pattern$vertices[v, ], nrow(cen), 2, byrow = TRUE)
  ang[order(atan2(d[, 2], d[, 1]))]
}
