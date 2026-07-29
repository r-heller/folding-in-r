#!/usr/bin/env Rscript
#
# Regenerate the table of contents in README.md from _bookdown.yml.
#
# Titles are read from each file's first H1, not from a YAML block: bookdown
# chapter files carry no YAML front matter, so the version of this script
# inherited from methods-in-r fell back to filenames for every chapter. It also
# only printed to stdout and never touched README.md.
#
# Writes between the <!-- TOC:START --> and <!-- TOC:END --> markers and leaves
# the rest of the README alone.

suppressPackageStartupMessages({
  library(yaml)
})

cfg   <- yaml::read_yaml("_bookdown.yml")
files <- cfg$rmd_files

heading_of <- function(f) {
  if (!file.exists(f)) return(NULL)
  raw <- readLines(f, warn = FALSE)
  h1 <- raw[grepl("^#\\s+", raw)]
  if (!length(h1)) return(NULL)
  h1 <- h1[1]
  ttl <- sub("^#\\s+", "", h1)
  ttl <- sub("\\s*\\{[^}]*\\}\\s*$", "", ttl)   # drop {#anchor} or {-}
  list(title = trimws(ttl), numbered = !grepl("\\{-\\}", h1))
}

lines <- character()
numbered <- 0L

for (f in files) {
  if (identical(basename(f), "index.Rmd")) next

  if (grepl("^_part-", basename(f))) {
    # Both markers appear as part files: "# (PART) ..." and "# (APPENDIX) ...".
    ttl <- readLines(f, n = 1, warn = FALSE)
    ttl <- sub("^#\\s*\\((PART|APPENDIX)\\)\\s*", "", ttl)
    ttl <- trimws(sub("\\s*\\{-\\}\\s*$", "", ttl))
    if (!nzchar(ttl)) ttl <- "Appendix"
    lines <- c(lines, "", sprintf("**%s**", ttl), "")
    next
  }

  h <- heading_of(f)
  if (is.null(h)) next

  if (h$numbered) {
    numbered <- numbered + 1L
    lines <- c(lines, sprintf("%d. %s", numbered, h$title))
  } else {
    lines <- c(lines, sprintf("- %s", h$title))
  }
}

readme <- readLines("README.md", warn = FALSE)
i <- which(readme == "<!-- TOC:START -->")
j <- which(readme == "<!-- TOC:END -->")
if (length(i) != 1L || length(j) != 1L || j <= i) {
  stop("README.md must contain exactly one <!-- TOC:START --> ... ",
       "<!-- TOC:END --> pair.", call. = FALSE)
}

writeLines(c(readme[seq_len(i)], lines, readme[j:length(readme)]), "README.md")

cat("README table of contents updated — ", numbered,
    " numbered chapters.\n", sep = "")
