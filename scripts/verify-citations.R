#!/usr/bin/env Rscript
#
# Verify that every bibliography entry carries an identifier that actually
# resolves. Exits 1 if any entry fails, so it can gate CI.
#
# DOIs are checked against the Handle System resolver at doi.org, not by
# fetching the publisher's landing page and not against a single registration
# agency. Two false-negative modes are avoided that way:
#
#   * Landing pages. Several publishers -- AAAS most notably -- answer
#     automated requests with HTTP 403 whatever the DOI. The two Science DOIs
#     here (Isomap and LLE, Science 290(5500)) are correct and were reported
#     unresolved by the landing-page check inherited from methods-in-r.
#
#   * Single-agency lookup. Crossref does not index DataCite DOIs. arXiv
#     registers under DataCite, so 10.48550/arXiv.* returns 404 from Crossref
#     while being perfectly valid.
#
# doi.org/api/handles/<doi> is the Handle System itself and answers for every
# registration agency, which is exactly the question being asked.

suppressPackageStartupMessages({
  library(bibtex)
  library(httr2)
  library(purrr)
})

bib_file <- if (file.exists("book.bib")) "book.bib" else "references.bib"
if (!file.exists(bib_file)) {
  message("No bibliography file found; skipping verification.")
  quit(status = 0)
}

bib  <- bibtex::read.bib(bib_file)
keys <- names(bib)

# Identify the tool. Named user agents are treated better by both the
# Handle resolver and the arXiv API than anonymous requests.
UA <- "folding-in-r citation checker (https://github.com/r-heller/folding-in-r)"

check_doi <- function(doi) {
  tryCatch({
    resp <- request(paste0("https://doi.org/api/handles/", doi)) |>
      req_user_agent(UA) |>
      req_timeout(20) |>
      req_error(is_error = function(r) FALSE) |>
      req_perform()
    resp_status(resp) == 200L
  }, error = function(e) FALSE)
}

check_arxiv <- function(id) {
  tryCatch({
    resp <- request(paste0("http://export.arxiv.org/api/query?id_list=", id)) |>
      req_user_agent(UA) |>
      req_timeout(20) |>
      req_error(is_error = function(r) FALSE) |>
      req_perform()
    resp_status(resp) == 200L && grepl("<entry>", resp_body_string(resp))
  }, error = function(e) FALSE)
}

check_url <- function(url) {
  tryCatch({
    resp <- request(url) |>
      req_user_agent(UA) |>
      req_timeout(20) |>
      req_error(is_error = function(r) FALSE) |>
      req_perform()
    resp_status(resp) < 400L
  }, error = function(e) FALSE)
}

# An ISBN is checked for shape only. There is no free, reliable, complete ISBN
# resolver; a well-formed ISBN on a book entry is accepted and counted in the
# summary rather than silently trusted.
check_isbn <- function(isbn) {
  digits <- gsub("[^0-9Xx]", "", isbn)
  nchar(digits) %in% c(10L, 13L)
}

verify <- function(entry) {
  if (!is.null(entry$doi))    return(check_doi(entry$doi))
  if (!is.null(entry$eprint)) return(check_arxiv(entry$eprint))
  if (!is.null(entry$isbn))   return(check_isbn(entry$isbn))
  if (!is.null(entry$url))    return(check_url(entry$url))
  NA
}

results <- map(bib, verify)

bad     <- keys[map_lgl(results, isFALSE)]
skipped <- keys[map_lgl(results, is.na)]
ok      <- sum(map_lgl(results, isTRUE))

if (length(skipped)) {
  cat(length(skipped), " entries carry no identifier at all — tolerated:\n",
      sep = "")
  cat(paste0("  - ", skipped, "\n"), sep = "")
}

if (length(bad)) {
  cat("Unresolved citation keys:\n")
  cat(paste0("  - ", bad, "\n"), sep = "")
  cat("\nAn entry listed here either has a wrong identifier or names a work\n",
      "that does not exist. Fix the identifier or drop the claim that needs\n",
      "it — do not cite from memory.\n", sep = "")
  quit(status = 1)
}

cat("All ", ok, " identifiers resolved",
    if (length(skipped)) sprintf(" (%d skipped)", length(skipped)) else "",
    ".\n", sep = "")
