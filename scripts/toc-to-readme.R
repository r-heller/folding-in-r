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

# The part files carry the bare title: bookdown supplies the numeral itself in
# the PDF, and style/after-body.html supplies it in the HTML sidebar. Neither is
# reachable from here, so the README applies the same rule — roman numerals for
# the parts, the word "Appendix" for the appendix, which does not advance the
# count.
ROMAN  <- c("I", "II", "III", "IV", "V", "VI", "VII", "VIII")
part_n <- 0L

for (f in files) {
  if (identical(basename(f), "index.Rmd")) next

  if (grepl("^part-", basename(f))) {
    # Both markers appear as part files: "# (PART) ..." and "# (APPENDIX) ...".
    head1 <- readLines(f, n = 1, warn = FALSE)
    ttl <- sub("^#\\s*\\((PART|APPENDIX)\\)\\s*", "", head1)
    ttl <- trimws(sub("\\s*\\{-\\}\\s*$", "", ttl))
    kicker <- if (grepl("\\(APPENDIX\\)", head1)) {
      "Appendix"
    } else {
      part_n <- part_n + 1L
      paste("Part", ROMAN[part_n])
    }
    lines <- c(lines, "", sprintf("**%s — %s**", kicker, ttl), "")
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
