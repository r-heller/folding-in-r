# The embedding registry.

flat   <- function(n = 200L) sample_manifold(miura_ori(4L, 4L), theta = 0,
                                             n = n, seed = 1001L, boundary = TRUE)
folded <- function(n = 200L) sample_manifold(miura_ori(4L, 4L), theta = 0.75,
                                             n = n, seed = 1001L, boundary = TRUE)

test_that("every registry entry has a complete specification", {
  for (nm in names(METHOD_REGISTRY)) {
    s <- METHOD_REGISTRY[[nm]]
    expect_true(all(c("label", "family", "consumes", "stochastic", "chapter", "fn")
                    %in% names(s)), info = nm)
    expect_true(s$consumes %in% c("ambient", "geodesic", "neighbourhood"), info = nm)
    expect_true(s$family %in% c("linear", "geodesic", "neighbour", "learned"), info = nm)
    expect_true(is.function(s$fn), info = nm)
  }
  expect_equal(nrow(method_table()), length(METHOD_REGISTRY))
})

test_that("every method returns an n by d matrix, or NULL", {
  m <- suppressMessages(flat())
  for (nm in names(METHOD_REGISTRY)) {
    sd <- if (isTRUE(METHOD_REGISTRY[[nm]]$stochastic)) 1001L else NULL
    e <- suppressMessages(embed(nm, m, seed = sd))
    if (is.null(e)) next                       # torch absent, or graph broken
    expect_true(is.matrix(e), info = nm)
    expect_equal(nrow(e), nrow(m$X), info = nm)
    expect_equal(ncol(e), 2L, info = nm)
    expect_true(all(is.finite(e)), info = nm)
  }
})

test_that("the ambient-metric methods recover a flat sheet exactly", {
  # A flat sheet IS a linear subspace, so PCA and classical MDS must find it to
  # machine precision. Anything else means the sampler or the metric is wrong,
  # not the method.
  m <- suppressMessages(flat())
  expect_lt(reconstruction_error(embed("pca", m), m$truth), 1e-9)
  expect_lt(reconstruction_error(embed("mds", m), m$truth), 1e-9)
})

test_that("PCA and classical MDS agree, because they are the same thing", {
  # cmdscale on a Euclidean distance matrix is PCA. Chapter 4 makes this point;
  # the grid must not report them as two independent results.
  for (m in list(suppressMessages(flat()), suppressMessages(folded()))) {
    a <- embed("pca", m); b <- embed("mds", m)
    expect_lt(reconstruction_error(a, b), 1e-8)
  }
})

test_that("a stochastic method refuses to run without a seed", {
  m <- suppressMessages(flat(120L))
  expect_error(embed("tsne", m), "without a seed")
  expect_error(embed("umap", m), "without a seed")
  expect_silent(invisible(embed("pca", m)))      # deterministic, no seed needed
})

test_that("seeds actually vary the stochastic methods, and repeat exactly", {
  m <- suppressMessages(flat(120L))
  for (nm in c("tsne", "umap")) {
    a <- suppressMessages(embed(nm, m, seed = 11L))
    b <- suppressMessages(embed(nm, m, seed = 11L))
    c <- suppressMessages(embed(nm, m, seed = 22L))
    expect_equal(a, b, info = paste(nm, "same seed reproduces"))
    expect_false(isTRUE(all.equal(a, c)), info = paste(nm, "different seed differs"))
  }
})

test_that("fitting a method leaves the caller's random stream alone", {
  m <- suppressMessages(flat(120L))
  set.seed(4242L); before <- stats::runif(1L)
  set.seed(4242L)
  invisible(suppressMessages(embed("tsne", m, seed = 7L)))
  invisible(suppressMessages(embed("umap", m, seed = 7L)))
  expect_equal(stats::runif(1L), before)
})

test_that("umap::umap does not advance the random stream, which is why it is not used", {
  # The measured defect behind the seeding discipline in R/methods.R, asserted
  # so that a future change of package cannot reintroduce it unnoticed.
  #
  # PLAN.md S1-6 attributed this to a preserve.seed argument. That argument does
  # not exist in the pinned version; the behaviour does. The test is on the
  # behaviour.
  skip_if_not_installed("umap")
  set.seed(1L); X <- matrix(stats::rnorm(240L), 80L, 3L)
  set.seed(99L)
  r <- replicate(3L, umap::umap(X, n_neighbors = 8L, n_epochs = 20L)$layout[1, 1])
  expect_equal(length(unique(round(r, 10))), 1L)   # three calls, one answer

  # uwot, which the registry does use, varies as a caller would expect.
  skip_if_not_installed("uwot")
  set.seed(99L)
  u <- replicate(3L, uwot::umap(X, n_neighbors = 8L, n_epochs = 20L,
                                verbose = FALSE)[1, 1])
  expect_gt(length(unique(round(u, 10))), 1L)
})

test_that("an unknown method is refused by name", {
  expect_error(embed("tSNE", suppressMessages(flat(80L)), seed = 1L),
               "no method 'tSNE'")
})

test_that("isomap records the k it actually used, not the k it was asked for", {
  # k = 1 disconnects the neighbourhood graph on almost any spread sample, and
  # Isomap on a disconnected graph is undefined. reference_dist() repairs it by
  # raising k until the graph connects, and warns. The repair is right; the
  # warning alone is not enough, because in a 2,700-cell run a number computed
  # at k = 4 would sit in a column labelled k = 1. The effective k travels with
  # the embedding so the grid can record it.
  m <- suppressMessages(flat(150L))
  e <- suppressWarnings(suppressMessages(embed("isomap", m, k = 1L)))
  expect_true(is.matrix(e))
  expect_false(is.null(attr(e, "k_effective")))
  expect_gt(attr(e, "k_effective"), 1L)
  expect_warning(embed("isomap", m, k = 1L), "disconnected")

  # When the graph connects at the k asked for, that is what is recorded.
  ok <- suppressMessages(embed("isomap", m, k = 10L))
  expect_equal(attr(ok, "k_effective"), 10L)
})

test_that("diffusion maps is treated as the stochastic method it is", {
  # Nearly recorded wrongly. diffusionMap::diffuse uses a randomised ARPACK
  # eigensolver: it advances R's random stream, and on a hard input it converges
  # or not depending where in that stream it began. Marked deterministic it
  # would have run unseeded, and twenty replicates would have differed for
  # reasons nothing recorded.
  skip_if_not_installed("diffusionMap")
  expect_true(METHOD_REGISTRY$diffusion$stochastic)
  expect_error(embed("diffusion", suppressMessages(flat(120L))), "without a seed")

  m <- suppressMessages(flat(150L))
  a <- suppressMessages(embed("diffusion", m, seed = 3L))
  b <- suppressMessages(embed("diffusion", m, seed = 3L))
  expect_equal(a, b)
})

test_that("a widened diffusion bandwidth is recorded, not hidden", {
  # The bandwidth comes from the median NEAREST-NEIGHBOUR distance rather than
  # the median pairwise distance, because the pairwise median is not robust to
  # the outlier noise model and inflating it broke the eigensolver -- 5 of 24
  # cells on the quick grid, every one of them an outlier cell. Reporting that
  # as "diffusion maps fails under outlier noise" would have been a finding
  # about the heuristic wearing the method's name.
  #
  # Where the solver still will not converge the bandwidth escalates, and the
  # factor that worked travels with the result.
  skip_if_not_installed("diffusionMap")
  ran <- 0L; tuned <- 0L
  for (sd in 1001:1004) {
    m <- suppressMessages(sample_manifold(
      miura_ori(6L, 6L), theta = 0, n = 150L,
      noise = list(type = "outlier", sd = 0.05), seed = sd))
    e <- suppressMessages(embed("diffusion", m, seed = sd))
    if (is.null(e)) next
    ran <- ran + 1L
    if (!is.null(attr(e, "tuning"))) {
      tuned <- tuned + 1L
      expect_match(attr(e, "tuning"), "^eps x")
    }
  }
  expect_gt(ran, 2L)          # the robust bandwidth recovers most cells
})
