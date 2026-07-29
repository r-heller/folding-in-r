#!/usr/bin/env Rscript
#
# One PDF per chapter, for the "This chapter (PDF)" button in the right-hand
# panel of the HTML book.
#
# Three things here are easy to get wrong and were wrong in the version
# inherited from methods-in-r:
#
#   * The chapter list comes from _bookdown.yml, not from a recursive glob for
#     *.Rmd. Once renv is set up, a glob also picks up the vignettes shipped
#     inside renv/ and cheerfully renders packrat.pdf and docker.pdf into the
#     book's download directory.
#
#   * Output files are named after the chapter's HTML anchor, not after the
#     source file. The download button is built client-side from the current
#     page's filename, so 01-introduction.Rmd must produce intro.pdf — named
#     after {#intro} — or every button 404s. The script checks each name
#     against docs/ and fails loudly rather than producing dead links.
#
#   * _common.R is sourced into the render environment. bookdown applies
#     before_chapter_script on its own; rmarkdown::render() does not.

suppressPackageStartupMessages({
  library(rmarkdown)
  library(fs)
  library(yaml)
})

SKIP <- c("index.Rmd", "00-impressum.Rmd", "00-acknowledgments.Rmd",
          "95-colophon.Rmd")

cfg <- yaml::read_yaml("_bookdown.yml")
chapters <- cfg$rmd_files
chapters <- chapters[!chapters %in% SKIP & !grepl("^part-", chapters)]

# bookdown names each page after the explicit {#anchor} on the chapter's H1,
# falling back to a slug of the title.
anchor_of <- function(f) {
  h1 <- grep("^#\\s+", readLines(f, warn = FALSE), value = TRUE)[1]
  if (is.na(h1)) return(path_ext_remove(path_file(f)))
  id <- regmatches(h1, regexpr("\\{#[^}]+\\}", h1))
  if (length(id)) return(sub("^\\{#", "", sub("\\}$", "", id)))
  title <- trimws(sub("\\s*\\{[^}]*\\}\\s*$", "", sub("^#\\s+", "", h1)))
  tolower(gsub("(^-|-$)", "", gsub("[^A-Za-z0-9]+", "-", title)))
}

out_dir <- "docs/pdf-chapters"
dir_create(out_dir)

fmt <- rmarkdown::pdf_document(
  latex_engine = "xelatex",
  includes     = rmarkdown::includes(in_header = "style/preamble.tex"),
  pandoc_args  = c("--citeproc",
                   "--bibliography=book.bib",
                   "--bibliography=packages.bib",
                   "--csl=style/vancouver.csl")
)

failed <- character()
missing_page <- character()

for (ch in chapters) {
  slug <- anchor_of(ch)
  if (!file_exists(path("docs", paste0(slug, ".html")))) {
    missing_page <- c(missing_page, sprintf("%s -> %s.html", ch, slug))
  }
  env <- new.env(parent = globalenv())
  sys.source("_common.R", envir = env)
  tryCatch({
    rmarkdown::render(
      input         = ch,
      output_format = fmt,
      output_file   = paste0(slug, ".pdf"),
      output_dir    = out_dir,
      envir         = env,
      quiet         = TRUE
    )
  }, error = function(e) {
    failed <<- c(failed, sprintf("%s: %s", ch, conditionMessage(e)))
  })
}

if (length(missing_page)) {
  cat("No HTML page matches these chapter anchors, so their download buttons\n",
      "would 404:\n", sep = "")
  cat(paste0("  - ", missing_page, "\n"), sep = "")
}
if (length(failed)) {
  cat("Failed to render:\n")
  cat(paste0("  - ", failed, "\n"), sep = "")
}
if (length(missing_page) || length(failed)) quit(status = 1)

cat(length(chapters), " chapter PDFs written to ", out_dir, ".\n", sep = "")
