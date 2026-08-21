#!/usr/bin/env Rscript
#
# Chapter lint. Six checks, one file, and the first of them is the reason this
# script exists.
#
# Usage:  Rscript scripts/lint-chapters.R [--quiet]
# Exits 1 on any error. Warnings do not fail the build.
#
# The rule these checks encode is that a claim in this book is either computed
# at render time or it is not made. Roughly forty numbers from an accordion-fold
# probe are sitting in design notes ready to be transcribed into prose, and
# every one of them was measured on a stand-in rather than on a Miura. Check 1
# is what stops that happening; the rest keep the book's structure honest.

args  <- commandArgs(trailingOnly = TRUE)
quiet <- "--quiet" %in% args

errors   <- character(0)
warnings <- character(0)
err  <- function(f, l, msg) errors[[length(errors) + 1L]]   <<- sprintf("%s:%s: %s", f, l, msg)
warn <- function(f, l, msg) warnings[[length(warnings) + 1L]] <<- sprintf("%s:%s: %s", f, l, msg)

# ── What counts as a body chapter ───────────────────────────────────────────
# The nine-slot contract applies to numbered body chapters and to the two
# appendices. Front and back matter are unnumbered, have no anchors by design
# (see 00-how-to-use.Rmd), and are exempt.

all_rmd  <- sort(list.files(".", pattern = "\\.Rmd$"))
body_rmd <- grep("^(0[1-9]|1[0-2])-", all_rmd, value = TRUE)
prose_rmd <- c(body_rmd, grep("^A[12]-", all_rmd, value = TRUE))

CONTRACT <- c("question", "setup", "background", "core", "results",
              "diagnostics", "limits", "reproduce", "reading")

# ── Masking ─────────────────────────────────────────────────────────────────
# Several checks ask "is this in prose?", which means: not inside a fenced code
# block, not inside an inline code span, and not inside an inline `r ` result.
#
# Fences are matched by length, not by a fixed three backticks: the callout
# example in 00-how-to-use.Rmd wraps a three-backtick chunk inside a
# four-backtick fence, and a regex that closes on the first ``` gets it wrong.

fence_mask <- function(lines) {
  inside <- logical(length(lines))
  fence  <- 0L
  for (i in seq_along(lines)) {
    ticks <- regmatches(lines[i], regexpr("^\\s*`{3,}", lines[i]))
    n <- if (length(ticks)) nchar(gsub("[^`]", "", ticks)) else 0L
    if (fence == 0L && n >= 3L) { fence <- n; inside[i] <- TRUE; next }
    if (fence >  0L && n >= fence) { fence <- 0L; inside[i] <- TRUE; next }
    inside[i] <- fence > 0L
  }
  inside
}

# Blank out inline code spans and inline r expressions, leaving the line length
# unchanged so reported columns stay meaningful.
strip_inline <- function(x) {
  x <- gsub("`r [^`]*`", "", x)     # the only sanctioned source of a number
  x <- gsub("`[^`\n]*`", "", x)
  x <- gsub("<!--.*?-->", "", x)
  x
}

read_lines_safe <- function(f) readLines(f, warn = FALSE)

# ── Check 1 — no typed numbers in prose ─────────────────────────────────────
#
# A bare decimal or a comma-grouped integer in prose is a number somebody typed.
# Years are allowed (they are not results), as are pure integers, which are too
# common in ordinary prose to police usefully -- "three patterns", "Chapter 4",
# "20 seeds". What is caught is exactly the shape a measurement takes.
#
# An unavoidable case gets an explicit escape on the line above:
#     <!-- lint-allow-number: R version, not a result -->
# which is deliberate, greppable, and reviewable.

check_typed_numbers <- function(f) {
  lines <- read_lines_safe(f)
  incode <- fence_mask(lines)
  allow  <- grepl("<!--\\s*lint-allow-number", lines)
  # an escape covers the line it is on and the line after it
  allow  <- allow | c(FALSE, head(allow, -1))

  for (i in seq_along(lines)) {
    if (incode[i] || allow[i]) next
    txt <- strip_inline(lines[i])
    txt <- gsub("https?://\\S+", "", txt)          # URLs carry version numbers
    txt <- gsub("10\\.\\d{4,9}/\\S+", "", txt)     # DOIs
    txt <- gsub("@[A-Za-z][A-Za-z0-9_:.#$%&+?<>~/-]*", "", txt)  # citation keys
    txt <- gsub("\\{#[^}]*\\}", "", txt)           # anchors

    dec <- regmatches(txt, gregexpr("(?<![\\d.])\\d+\\.\\d+(?![\\d.])", txt, perl = TRUE))[[1]]
    dec <- dec[!grepl("^(19|20)\\d{2}\\.", dec)]
    grp <- regmatches(txt, gregexpr("\\b\\d{1,3}(,\\d{3})+\\b", txt, perl = TRUE))[[1]]

    for (d in unique(c(dec, grp))) {
      err(f, i, sprintf(
        "typed number '%s' in prose. Every number in this book comes from an inline `r ` expression, or it is not made. If this one genuinely is not a result, put <!-- lint-allow-number: why --> above it.", d))
    }
  }
}

# ── Check 2 — the nine-slot contract ────────────────────────────────────────

check_contract <- function(f) {
  lines <- read_lines_safe(f)

  # A stub declares itself with the TODO marker every chapter file was created
  # with. Exempting it is not a loophole: the marker is what a reader sees, the
  # chapter is visibly unwritten, and deleting the marker -- which is the first
  # thing drafting does -- turns the contract on. The exemption removes itself.
  if (any(grepl("<!--\\s*TODO: chapter content", lines))) {
    warn(f, 1, "stub: contract not enforced until the TODO marker is removed")
    return(invisible())
  }

  incode <- fence_mask(lines)
  h2 <- which(grepl("^##\\s+\\S", lines) & !incode)
  if (!length(h2)) { err(f, 1, "no level-2 sections: the nine-slot contract is not applied"); return(invisible()) }

  ids <- rep(NA_character_, length(h2))
  for (j in seq_along(h2)) {
    m <- regmatches(lines[h2[j]], regexpr("\\{#[^}]+\\}", lines[h2[j]]))
    if (length(m)) ids[j] <- sub("^\\{#", "", sub("\\}$", "", m))
  }

  missing_id <- h2[is.na(ids)]
  for (l in missing_id) err(f, l, "level-2 heading with no {#anchor}; the contract requires one on every slot")

  ids <- ids[!is.na(ids)]
  if (!length(ids)) return(invisible())

  # One mnemonic per chapter, taken from the first anchor, and every anchor must
  # use it. Namespacing is the whole point: twelve headings called "Results"
  # collide in pandoc and silently renumber each other's cross-references.
  mn <- sub("-[a-z]+$", "", ids[1])
  bad_ns <- ids[!startsWith(ids, paste0(mn, "-"))]
  for (b in bad_ns) err(f, 1, sprintf("anchor '%s' is not in this chapter's '%s-' namespace", b, mn))

  slots <- sub(paste0("^", mn, "-"), "", ids[startsWith(ids, paste0(mn, "-"))])
  missing <- setdiff(CONTRACT, slots)
  if (length(missing)) err(f, 1, sprintf("missing contract slots: %s", paste(missing, collapse = ", ")))

  # Order: the fixed slots must appear in the contract's order. The core slot is
  # freely worded, so it is checked by position rather than by name.
  seen <- slots[slots %in% CONTRACT]
  if (is.unsorted(match(seen, CONTRACT))) {
    err(f, 1, sprintf("contract slots out of order: %s", paste(seen, collapse = " -> ")))
  }
}

# ── Check 3 — every figure chunk carries fig.alt ────────────────────────────
# Standing rule 3. A figure without alt text is a result encoded by picture
# alone, which is the same failure as encoding one by colour alone.

chunk_headers <- function(lines) {
  i <- grep("^\\s*```+\\{r[ ,}]", lines)
  i[!grepl("^\\s*```+\\{r[ ,}].*\\}\\s*$", lines[i]) == FALSE]
}

check_fig_alt <- function(f) {
  lines <- read_lines_safe(f)
  hdr <- grep("^\\s*```+\\{r[ ,}]", lines)
  for (i in hdr) {
    h <- lines[i]
    is_fig <- grepl("fig\\.(cap|width|height|asp)", h) || grepl("^\\s*```+\\{r\\s+fig-", h)
    if (is_fig && !grepl("fig\\.alt\\s*=", h)) {
      err(f, i, "figure chunk without fig.alt (standing rule 3)")
    }
  }
}

# ── Check 4 — callouts use the knitr block form ─────────────────────────────
# A raw <div> renders unstyled in HTML and vanishes in PDF, where the boxes are
# LaTeX environments. A pandoc fenced div does the same. This is exactly what
# shipped eighty unstyled boxes in a sibling volume.

BOXES <- c("boxinfo", "boximportant", "boxreport", "boxquestion", "boxempty")

check_callouts <- function(f) {
  lines <- read_lines_safe(f)
  incode <- fence_mask(lines)
  for (i in seq_along(lines)) {
    # Inline code is how this book *documents* the wrong forms -- see the
    # callout section of 00-how-to-use.Rmd, which names them in order to
    # forbid them. Strip spans before looking, or the lint fails the very file
    # that explains the rule.
    bare <- strip_inline(lines[i])
    if (grepl("<div\\s+class\\s*=\\s*[\"'][^\"']*\\b(box[a-z]+|callout)", bare, perl = TRUE)) {
      err(f, i, "raw <div> callout: use ```{block, type='boxinfo'} -- a div renders unstyled in HTML and disappears in PDF")
    }
    if (!incode[i] && grepl("^:::", bare)) {
      err(f, i, "pandoc fenced div: the stylesheet does not target it. Use ```{block, type='...'}")
    }
    m <- regmatches(lines[i], regexpr("type\\s*=\\s*['\"]([a-z]+)['\"]", lines[i], perl = TRUE))

    if (length(m)) {
      cls <- sub(".*['\"]([a-z]+)['\"].*", "\\1", m)
      if (startsWith(cls, "box") && !cls %in% BOXES) {
        err(f, i, sprintf("callout class '%s' is not defined in style/style.css (have: %s)",
                          cls, paste(BOXES, collapse = ", ")))
      }
    }
  }
}

# ── Check 5 — every \@ref() resolves ────────────────────────────────────────

collect_targets <- function(files) {
  out <- character(0)
  for (f in files) {
    lines <- read_lines_safe(f)
    ids <- regmatches(lines, gregexpr("\\{#[^} ]+", lines))
    ids <- unlist(ids)
    out <- c(out, sub("^\\{#", "", ids))
    eqs <- unlist(regmatches(lines, gregexpr("\\(\\\\#eq:[^)]+\\)", lines)))
    out <- c(out, sub("^\\(\\\\#", "", sub("\\)$", "", eqs)))
    hdr <- grep("^\\s*```+\\{r[ ,}]", lines, value = TRUE)
    lab <- sub("^\\s*```+\\{r\\s*,?\\s*([A-Za-z0-9_.-]+).*$", "\\1", hdr)
    lab <- lab[lab != hdr & nzchar(lab)]
    out <- c(out, paste0("fig:", lab), paste0("tab:", lab))
  }
  unique(sub("\\s.*$", "", out))
}

check_refs <- function(files, targets) {
  for (f in files) {
    lines <- read_lines_safe(f)
    for (i in seq_along(lines)) {
      refs <- unlist(regmatches(lines[i], gregexpr("\\\\@ref\\(([^)]+)\\)", lines[i])))
      for (r in refs) {
        tgt <- sub("^\\\\@ref\\(", "", sub("\\)$", "", r))
        if (!tgt %in% targets) err(f, i, sprintf("\\@ref(%s) has no target; it will render as '??'", tgt))
      }
    }
  }
}

# ── Check 6 — a chunk that samples sets a seed ──────────────────────────────

SAMPLERS <- c("sample_manifold", "swiss_roll", "s_curve", "severed_sphere",
              "\\bsample\\(", "\\brnorm\\(", "\\brunif\\(", "\\brbinom\\(",
              "\\brpois\\(", "Rtsne\\(", "umap\\(", "uwot::")

check_seeds <- function(f) {
  lines <- read_lines_safe(f)
  hdr <- grep("^\\s*```+\\{r[ ,}]", lines)
  end <- grep("^\\s*```+\\s*$", lines)
  for (i in hdr) {
    j <- end[end > i]
    if (!length(j)) next
    body <- lines[(i + 1L):(j[1] - 1L)]
    if (!length(body)) next
    samples <- any(vapply(SAMPLERS, function(p) any(grepl(p, body)), logical(1)))
    if (!samples) next
    seeded <- any(grepl("set\\.seed\\(", body)) ||
              any(grepl("BENCH_SEEDS|seed\\s*=", body))
    if (!seeded) {
      err(f, i, "chunk samples but sets no seed. Standing rule 1: every stochastic result is reported across BENCH_SEEDS, and a chunk nobody seeded is not reproducible.")
    }
  }
}

# ── Run ─────────────────────────────────────────────────────────────────────

if (!length(all_rmd)) {
  message("no .Rmd files found -- run from the repository root.")
  quit(status = 1)
}

targets <- collect_targets(all_rmd)

for (f in prose_rmd) check_typed_numbers(f)
for (f in body_rmd)  check_contract(f)
for (f in all_rmd)   check_fig_alt(f)
for (f in all_rmd)   check_callouts(f)
for (f in all_rmd)   check_seeds(f)
check_refs(all_rmd, targets)

if (!quiet) {
  cat("lint-chapters: ", length(all_rmd), " files, ", length(body_rmd),
      " body chapters, ", length(targets), " cross-reference targets\n", sep = "")
}

if (length(warnings)) {
  cat("\nWarnings:\n"); cat(paste0("  ", unlist(warnings), "\n"), sep = "")
}

if (length(errors)) {
  cat("\n", length(errors), " errors:\n", sep = "")
  cat(paste0("  ", unlist(errors), "\n"), sep = "")
  quit(status = 1)
}

cat("clean.\n")
