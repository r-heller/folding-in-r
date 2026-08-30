# Reading and writing runs.
#
# read_run() is the function PLAN.md and CHAPTERS.md both say every chapter from
# 4 onward opens with. It did not exist, so what a chapter would have done
# instead is readRDS() -- which accepts a --quick smoke test, an artefact with no
# provenance, and a regenerated run whose numbers no longer match the sentence
# beside them, all three silently. Those three are what this file tests.

tmp_run <- function(x, ...) {
  p <- tempfile(fileext = ".rds")
  write_run(x, p, ..., quiet = TRUE)
  p
}

DF <- data.frame(theta = c(0.1, 0.5), rmse = c(0.02, 0.31))

test_that("the digest is of the answer, not of how it was produced", {
  # Two runs of the same producer that agree on the numbers must agree on the
  # digest, or the check fires on every regeneration and gets deleted. Two that
  # disagree by one value in the last place must not.
  a <- DF; b <- DF
  attr(a, "provenance") <- list(r_sha = "aaaaaaa", date = "2026-01-01", elapsed = 12)
  attr(b, "provenance") <- list(r_sha = "bbbbbbb", date = "2026-08-30", elapsed = 900)
  expect_identical(run_digest(a), run_digest(b))

  c2 <- DF; c2$rmse[2] <- c2$rmse[2] + 1e-12
  expect_false(identical(run_digest(DF), run_digest(c2)))
})

test_that("provenance records what someone will actually ask", {
  pr <- provenance(started = Sys.time() - 3)
  for (f in c("repo_sha", "r_sha", "dirty", "r_version", "platform", "blas",
              "packages", "date", "elapsed", "cores")) {
    expect_true(f %in% names(pr), info = f)
  }
  expect_type(pr$dirty, "logical")
  expect_gte(pr$elapsed, 2)
  expect_true("base" %in% names(pr$packages))

  # r_sha is R/ alone, not the repository: prose commits move HEAD constantly and
  # would make every artefact look stale against code that never changed.
  expect_false(identical(pr$repo_sha, pr$r_sha))
})

test_that("a run written here reads back", {
  p <- tmp_run(DF, arm = "test")
  x <- read_run(p, quiet = TRUE)
  expect_equal(as.data.frame(x)[, c("theta", "rmse")], DF)
  expect_identical(attr(x, "digest"), run_digest(DF))
  expect_identical(attr(x, "provenance")$arm, "test")

  # And with the digest supplied, which is how a chapter calls it.
  expect_silent(read_run(p, run_digest(DF), quiet = TRUE))
})

test_that("a chapter cannot render against a run it was not written against", {
  p <- tmp_run(DF)
  moved <- DF; moved$rmse[1] <- 0.99
  q <- tmp_run(moved)

  err <- tryCatch(read_run(q, run_digest(DF), quiet = TRUE),
                  error = function(e) conditionMessage(e))
  expect_true(is.character(err))
  expect_match(err, "not the run this chapter was written against")
  expect_match(err, run_digest(DF), fixed = TRUE)   # names both digests
  expect_match(err, run_digest(moved), fixed = TRUE)
})

test_that("the three things readRDS would have accepted silently", {
  # 1. no artefact at all
  expect_error(read_run(file.path(tempdir(), "no-such-run.rds"), quiet = TRUE),
               "no artefact at")

  # 2. an artefact with no provenance -- which is what all three E1 files were
  #    while two documents asserted they carried it
  p <- tempfile(fileext = ".rds")
  saveRDS(DF, p)
  expect_error(read_run(p, quiet = TRUE), "carries no provenance")

  # 3. a --quick smoke test committed as evidence
  q <- tmp_run(DF, quick = TRUE)
  expect_error(read_run(q, quiet = TRUE), "smoke test, not the book's evidence")
})

test_that("a dirty tree is reported, not hidden", {
  # A SHA recorded from a tree with uncommitted changes names code that was
  # never committed. The run is still readable -- it is a warning, because
  # refusing it would make the working loop impossible -- but it is never silent.
  p <- tempfile(fileext = ".rds")
  x <- DF
  attr(x, "provenance") <- list(r_sha = "deadbee", dirty = TRUE, date = "2026-08-30")
  saveRDS(x, p)
  expect_warning(read_run(p, quiet = TRUE), "uncommitted changes")
})
