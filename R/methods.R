# ── The embedding registry ──────────────────────────────────────────────────
#
# One entry per method under test. Chapters 4 to 7 each describe a slice of this
# list and every one of them fits it through the same call, so a result in one
# chapter is comparable with a result in another.
#
# Each entry records what the method CONSUMES, and that field is not
# bookkeeping. It is the book's opening argument in machine-readable form:
# Isomap consumes geodesic distance, which a crease pattern satisfies exactly,
# so it is the only method here that claims what the headline metric measures.
# PCA and MDS consume ambient distance. t-SNE, UMAP and the neighbour methods
# consume neighbourhood structure and never claimed isometry at all. Scoring
# them against isometric truth and reporting that they lose is a category error
# unless the book says so first -- Chapter 1 says so, and this field is what
# stops a later chapter forgetting.

EMBED_DIM_DEFAULT <- 2L

# ── Seeding ─────────────────────────────────────────────────────────────────
#
# Every stochastic method is seeded EXPLICITLY here, per call, and never left to
# inherit position in the RNG stream.
#
# That is not defensive style, it is a measured defect. umap::umap 0.2.10.0 does
# not advance R's random stream: three consecutive calls after a single
# set.seed() return byte-identical embeddings, where Rtsne and uwot return three
# different ones. A replicate loop that seeds once and trusts the stream --
# which is the natural idiom, and the one the standing rules invite -- therefore
# collapses twenty UMAP seeds into one while every other method varies
# correctly. The failure is silent and the numbers look fine.
#
# PLAN.md S1-6 predicted this and named the wrong mechanism: it blamed a
# preserve.seed argument, which the pinned version does not have. The effect is
# real, the cause is not what was recorded, and tests/testthat/test-methods.R
# asserts the behaviour rather than the explanation.
.seeded <- function(seed, expr) {
  if (is.null(seed)) return(force(expr))
  if (exists(".Random.seed", .GlobalEnv)) {
    old <- get(".Random.seed", .GlobalEnv)
    on.exit(assign(".Random.seed", old, .GlobalEnv), add = TRUE)
  } else {
    on.exit(suppressWarnings(rm(".Random.seed", envir = .GlobalEnv)), add = TRUE)
  }
  set.seed(seed)
  force(expr)
}

.knn <- function(X, k) {
  # Indices of the k nearest neighbours of each row, self excluded.
  d <- as.matrix(stats::dist(X))
  diag(d) <- Inf
  t(apply(d, 1L, function(r) order(r)[seq_len(k)]))
}

# ── Linear ──────────────────────────────────────────────────────────────────

embed_pca <- function(m, d = EMBED_DIM_DEFAULT, k = NULL, seed = NULL) {
  stats::prcomp(m$X, rank. = d)$x[, seq_len(d), drop = FALSE]
}

embed_mds <- function(m, d = EMBED_DIM_DEFAULT, k = NULL, seed = NULL) {
  # Classical MDS on the ambient Euclidean distances. This is PCA -- provably,
  # not approximately, and measured at 5.8e-15 across the whole E1 grid. It is
  # kept as a separate entry because the book compares them in Chapter 4 and
  # showing that they coincide is the point; it must not be reported as two
  # independent results.
  stats::cmdscale(stats::dist(m$X), k = d)
}

# ── Geodesic ────────────────────────────────────────────────────────────────

embed_isomap <- function(m, d = EMBED_DIM_DEFAULT, k = K_DEFAULT, seed = NULL) {
  # reference_dist() repairs a disconnected neighbourhood graph by raising k
  # until it connects, and warns when it does. That is the right behaviour --
  # Isomap on a disconnected graph is undefined, and refusing outright would
  # lose the cell -- but a warning is not a record. In a 2,700-cell run warnings
  # scroll past, and a number computed at k = 4 sitting in a column labelled
  # k = 1 is how a wrong sentence gets into a chapter.
  #
  # So the k actually used travels with the embedding, and the grid records it.
  g <- reference_dist(m, "graph", k = k)
  k_used <- attr(g, "k")
  if (any(!is.finite(as.matrix(g)))) return(NULL)   # backstop; repair should prevent it
  out <- stats::cmdscale(g, k = d)
  attr(out, "k_effective") <- if (is.null(k_used)) as.integer(k) else k_used
  out
}

embed_diffusion <- function(m, d = EMBED_DIM_DEFAULT, k = K_DEFAULT, seed = NULL) {
  if (!requireNamespace("diffusionMap", quietly = TRUE)) return(NULL)
  D <- stats::dist(m$X)
  eps <- stats::median(as.matrix(D)[upper.tri(as.matrix(D))])^2 / 10
  out <- try(diffusionMap::diffuse(D, eps.val = eps, neigen = d, maxdim = d),
             silent = TRUE)
  if (inherits(out, "try-error")) return(NULL)
  as.matrix(out$X)[, seq_len(d), drop = FALSE]
}

# ── Neighbourhood ───────────────────────────────────────────────────────────

embed_lle <- function(m, d = EMBED_DIM_DEFAULT, k = K_DEFAULT, seed = NULL) {
  # Hand-rolled, because the lle package was archived from CRAN and cannot be
  # pinned. Roweis & Saul's algorithm in three steps: neighbours, reconstruction
  # weights, then the null space of (I - W)'(I - W).
  X <- m$X; n <- nrow(X)
  nb <- .knn(X, k)
  W <- matrix(0, n, n)
  for (i in seq_len(n)) {
    Z <- sweep(X[nb[i, ], , drop = FALSE], 2L, X[i, ])
    G <- Z %*% t(Z)
    # Regularisation is required, not optional: with k > ambient dimension the
    # Gram matrix is singular by construction, which is the usual case here.
    G <- G + diag(k) * 1e-3 * sum(diag(G)) / k
    w <- solve(G, rep(1, k))
    W[i, nb[i, ]] <- w / sum(w)
  }
  M <- diag(n) - W
  M <- t(M) %*% M
  e <- eigen(M, symmetric = TRUE)
  # Discard the trivial constant eigenvector at the bottom of the spectrum.
  idx <- order(e$values)[2:(d + 1L)]
  e$vectors[, idx, drop = FALSE] * sqrt(n)
}

embed_laplacian <- function(m, d = EMBED_DIM_DEFAULT, k = K_DEFAULT, seed = NULL) {
  X <- m$X; n <- nrow(X)
  D <- as.matrix(stats::dist(X))
  nb <- .knn(X, k)
  t2 <- stats::median(D[cbind(rep(seq_len(n), each = k), as.vector(t(nb)))])^2
  W <- matrix(0, n, n)
  for (i in seq_len(n)) W[i, nb[i, ]] <- exp(-D[i, nb[i, ]]^2 / t2)
  W <- pmax(W, t(W))                       # symmetrise
  Dg <- diag(rowSums(W))
  L <- Dg - W
  e <- try(eigen(solve(Dg + diag(1e-9, n)) %*% L, symmetric = FALSE), silent = TRUE)
  if (inherits(e, "try-error")) return(NULL)
  v <- Re(e$vectors)
  idx <- order(Re(e$values))[2:(d + 1L)]
  v[, idx, drop = FALSE]
}

embed_tsne <- function(m, d = EMBED_DIM_DEFAULT, k = K_DEFAULT, seed = NULL) {
  .seeded(seed, {
    p <- min(30, floor((nrow(m$X) - 1) / 3))
    Rtsne::Rtsne(m$X, dims = d, perplexity = p, check_duplicates = FALSE,
                 verbose = FALSE)$Y
  })
}

embed_umap <- function(m, d = EMBED_DIM_DEFAULT, k = K_DEFAULT, seed = NULL) {
  # uwot rather than umap. Both are pinned; uwot consumes R's random stream,
  # which means a caller who forgets to seed gets visibly different answers
  # instead of twenty identical ones. See the seeding note above.
  .seeded(seed, {
    uwot::umap(m$X, n_components = d, n_neighbors = min(k * 2L, nrow(m$X) - 1L),
               verbose = FALSE)
  })
}

# ── Learned ─────────────────────────────────────────────────────────────────

embed_autoencoder <- function(m, d = EMBED_DIM_DEFAULT, k = NULL, seed = NULL) {
  # torch is recorded in renv.lock and deliberately not installed in a working
  # checkout: only Chapter 7 needs it and it pulls a large binary backend.
  # Returning NULL rather than erroring lets the rest of the grid run; the grid
  # records the NULL, so a missing autoencoder row is visible in the artefact
  # rather than absent from it.
  if (!requireNamespace("torch", quietly = TRUE)) return(NULL)
  stop("the autoencoder is written in Chapter 7, not here", call. = FALSE)
}

# ── The registry ────────────────────────────────────────────────────────────

METHOD_REGISTRY <- list(
  pca         = list(label = "PCA",                 family = "linear",
                     consumes = "ambient",       stochastic = FALSE, chapter = 4,
                     fn = embed_pca),
  mds         = list(label = "Classical MDS",       family = "linear",
                     consumes = "ambient",       stochastic = FALSE, chapter = 4,
                     fn = embed_mds),
  isomap      = list(label = "Isomap",              family = "geodesic",
                     consumes = "geodesic",      stochastic = FALSE, chapter = 5,
                     fn = embed_isomap),
  diffusion   = list(label = "Diffusion map",       family = "geodesic",
                     consumes = "ambient",       stochastic = FALSE, chapter = 5,
                     fn = embed_diffusion),
  lle         = list(label = "LLE",                 family = "neighbour",
                     consumes = "neighbourhood", stochastic = FALSE, chapter = 6,
                     fn = embed_lle),
  laplacian   = list(label = "Laplacian eigenmaps", family = "neighbour",
                     consumes = "neighbourhood", stochastic = FALSE, chapter = 6,
                     fn = embed_laplacian),
  tsne        = list(label = "t-SNE",               family = "neighbour",
                     consumes = "neighbourhood", stochastic = TRUE,  chapter = 6,
                     fn = embed_tsne),
  umap        = list(label = "UMAP",                family = "neighbour",
                     consumes = "neighbourhood", stochastic = TRUE,  chapter = 6,
                     fn = embed_umap),
  autoencoder = list(label = "Autoencoder",         family = "learned",
                     consumes = "ambient",       stochastic = TRUE,  chapter = 7,
                     fn = embed_autoencoder)
)

#' Fit one method to one sample.
#'
#' @return an n x d matrix, or NULL when the method could not run -- a
#'   disconnected neighbourhood graph, an absent optional package. NULL is a
#'   result and the grid records it; silently substituting something that did
#'   run would put a number in the book that no method produced.
embed <- function(method, sample, d = EMBED_DIM_DEFAULT, k = K_DEFAULT,
                  seed = NULL) {
  spec <- METHOD_REGISTRY[[method]]
  if (is.null(spec)) {
    stop("no method '", method, "' in the registry. Have: ",
         paste(names(METHOD_REGISTRY), collapse = ", "), call. = FALSE)
  }
  if (isTRUE(spec$stochastic) && is.null(seed)) {
    stop(method, " is stochastic and was called without a seed. Standing rule 1: ",
         "every stochastic result in this book is reported across BENCH_SEEDS, ",
         "and an unseeded fit cannot be one of them.", call. = FALSE)
  }
  out <- spec$fn(sample, d = d, k = k, seed = seed)
  if (is.null(out)) return(NULL)
  keff <- attr(out, "k_effective")
  out <- as.matrix(out)
  if (nrow(out) != nrow(sample$X)) {
    stop(method, " returned ", nrow(out), " rows for ", nrow(sample$X),
         " input points", call. = FALSE)
  }
  out <- unname(out[, seq_len(d), drop = FALSE])
  # Carried through, so a caller that stores the embedding also stores the
  # conditions it was produced under.
  if (!is.null(keff)) attr(out, "k_effective") <- keff
  out
}

#' The registry as a data frame, for the chapter tables that describe it.
method_table <- function() {
  do.call(rbind, lapply(names(METHOD_REGISTRY), function(nm) {
    s <- METHOD_REGISTRY[[nm]]
    data.frame(method = nm, label = s$label, family = s$family,
               consumes = s$consumes, stochastic = s$stochastic,
               chapter = s$chapter, stringsAsFactors = FALSE)
  }))
}
