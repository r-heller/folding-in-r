test_that("figure sync canonicalizes signed zero and rejects changed coordinates", {
  skip_if_not_installed("jsonlite")
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
  fixture <- tempfile("figure-source-"); dir.create(fixture)
  on.exit(unlink(fixture, recursive = TRUE), add = TRUE)
  dir.create(file.path(fixture, "scripts")); dir.create(file.path(fixture, "js"))
  file.copy(file.path(root, "R"), fixture, recursive = TRUE)
  script <- file.path(fixture, "scripts", "build-fold-figure.R")
  file.copy(file.path(root, "scripts", "build-fold-figure.R"), script)
  html <- file.path(fixture, "js", "fold-figure.html")
  file.copy(file.path(root, "js", "fold-figure.html"), html)
  check <- function() {
    out <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                    c("--vanilla", shQuote(script), "--check"),
                                    stdout = TRUE, stderr = TRUE))
    attr(out, "status") %||% 0L
  }
  expect_equal(check(), 0L)
  lines <- readLines(html)
  i <- grep("^window.__FOLD_GEOM__ = ", lines)
  # One real coordinate change must still fail the exact comparison.
  lines[i] <- sub('-0.7905', '-0.7915', lines[i], fixed = TRUE)
  writeLines(lines, html)
  expect_equal(check(), 1L)
})
