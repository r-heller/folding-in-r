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

# The anchors on a file's level-2 headings, or NULL when the file is a stub.
#
# A stub declares itself with the TODO marker every chapter file was created
# with. Exempting it is not a loophole: the marker is what a reader sees, the
# chapter is visibly unwritten, and deleting the marker -- which is the first
# thing drafting does -- turns both checks on. The exemption removes itself.
heading_ids <- function(f, what) {
  lines <- read_lines_safe(f)
  if (any(grepl("<!--\\s*TODO: chapter content", lines))) {
    warn(f, 1, sprintf("stub: %s not enforced until the TODO marker is removed", what))
    return(NULL)
  }
  incode <- fence_mask(lines)

  # The mnemonic is the prefix every section anchor shares.
  #
  # Two earlier rules both failed, and on the same chapters. Stripping a trailing
  # "-word" off the first anchor cannot tell `intro-answer-key` (mnemonic
  # `intro`) from `folding-geometry-question` (`folding-geometry`). Taking the
  # H1's anchor instead is wrong the other way: the specification pairs
  # `{#folding-geometry}` with `geom-`, `{#comparison}` with `comp-` and
  # `{#linear}` with `lin-`, deliberately, because a section anchor is typed by
  # hand far more often than a chapter anchor.
  #
  # What the rule is actually for is pandoc id collision -- twelve headings
  # called "Results" silently renumber each other's cross-references. So the
  # mnemonic is derived from the anchors themselves, as their longest common
  # prefix ending in "-", and check_anchors() enforces what matters: that there
  # IS one, and that no two chapters have chosen the same one.
  h1 <- which(grepl("^#\\s+\\S", lines) & !incode)

  h2 <- which(grepl("^##\\s+\\S", lines) & !incode)
  ids <- vapply(lines[h2], anchor_on, character(1), USE.NAMES = FALSE)

  known <- ids[!is.na(ids)]
  mn <- if (!length(known)) NA_character_ else if (length(known) == 1L) {
    sub("-[^-]+$", "", known)
  } else {
    parts <- strsplit(known, "-", fixed = TRUE)
    n <- min(lengths(parts)) - 1L                # never the whole anchor
    keep <- 0L
    while (keep < n && length(unique(vapply(parts, function(x) x[keep + 1L],
                                            character(1)))) == 1L) keep <- keep + 1L
    if (keep == 0L) NA_character_
    else paste(parts[[1]][seq_len(keep)], collapse = "-")
  }
  list(lines = lines, h1 = h1, mn = mn, h2 = h2, ids = ids)
}

# ── Check 2a — every level-2 heading is anchored, in one namespace ──────────
#
# Runs over prose_rmd, which is what line 30 built it for. It used to run over
# body_rmd, so the appendices -- the only written prose in the tree, and the
# only files it could have enforced anything on today -- were never checked at
# all, while the twelve chapters it did check were all exempt stubs. A check
# whose entire input is exempt reports "clean" forever.
#
# Namespacing is the whole point: twelve headings called "Results" collide in
# pandoc and silently renumber each other's cross-references.
anchor_on <- function(l) {
  m <- regmatches(l, regexpr("\\{#[^} \t]+", l))
  if (length(m)) sub("^\\{#", "", m) else NA_character_
}

MNEMONIC <- list()

check_anchors <- function(f) {
  g <- heading_ids(f, "anchors")
  if (is.null(g)) return(invisible())

  if (!length(g$h2)) {
    err(f, 1, "no level-2 sections: nothing to anchor and nothing to cross-reference")
    return(invisible())
  }
  for (l in g$h2[is.na(g$ids)]) {
    err(f, l, "level-2 heading with no {#anchor}; every section is a cross-reference target")
  }
  ids <- g$ids[!is.na(g$ids)]
  if (!length(ids)) return(invisible())

  if (is.na(g$mn)) {
    err(f, g$h2[1], sprintf(
      "the section anchors share no namespace (%s). Twelve headings called \"Results\" collide in pandoc and silently renumber each other's cross-references, which is what the prefix prevents.",
      paste(utils::head(ids, 4), collapse = ", ")))
    return(invisible())
  }
  MNEMONIC[[f]] <<- g$mn

  # The H1 must be anchored too: bookdown names the page after it and every
  # \@ref() to the chapter resolves against it.
  if (is.na(anchor_on(g$lines[g$h1[1]]))) {
    err(f, g$h1[1], "the chapter's level-1 heading carries no {#anchor}; bookdown names the page after it")
  }
}

# ── Check 2b — the section contract, on the chapters that carry one ─────────
#
# Nine slots for a chapter that presents a method and measures something. The
# introduction and the conclusion present neither, and requiring `results`,
# `diagnostics`, `reproduce` and `setup` of them buys nothing a reader wants:
# an introduction's "results" section is a forward reference to an artefact that
# does not exist yet, which CHAPTERS.md already warns against in the same
# breath as telling the author to draft Chapter 1 last. They carry the five
# slots that mean something in narrative prose, and the order check is the same.
#
# Anchors outside the contract are allowed -- `intro-roadmap` is one -- provided
# they are in the namespace. The contract fixes what must be there, not what may.
NARRATIVE <- c("01-introduction.Rmd", "13-conclusion.Rmd")
CONTRACT_CORE <- c("question", "background", "core", "limits", "reading")

check_contract <- function(f) {
  g <- heading_ids(f, "the contract")
  if (is.null(g)) return(invisible())

  ids <- g$ids[!is.na(g$ids)]
  if (!length(ids) || is.na(g$mn)) return(invisible())   # check_anchors has erred

  required <- if (f %in% NARRATIVE) CONTRACT_CORE else CONTRACT
  slots <- sub(paste0("^", g$mn, "-"), "", ids[startsWith(ids, paste0(g$mn, "-"))])

  missing <- setdiff(required, slots)
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

# ── Check 3b — eval = FALSE is per chunk, labelled, and never on a figure ───
#
# _common.R sets eval = TRUE. A chunk that is shown without being run is a
# deliberate exception and says so in its label, so that grepping for `norun-`
# finds every place the book prints code it did not execute.
#
# On a figure chunk there is no such thing as a deliberate exception: knitr
# attaches fig.cap, fig.alt and the `fig:` anchor to the plot output, so a
# figure chunk that does not evaluate silently loses all three and drops out of
# the book's figure numbering, taking every cross-reference to it along.

check_eval <- function(f) {
  lines <- read_lines_safe(f)
  for (i in grep("^\\s*```+\\{r[ ,}]", lines)) {
    h <- lines[i]
    if (!grepl("eval\\s*=\\s*(FALSE|F)\\b", h)) next
    label <- sub("^\\s*```+\\{r[ ,]*", "", h)
    label <- sub("[,}].*$", "", trimws(label))
    is_fig <- grepl("fig\\.(cap|width|height|asp|alt)", h) ||
              grepl("^\\s*```+\\{r\\s+fig-", h)
    if (is_fig) {
      err(f, i, "figure chunk with eval = FALSE: it emits no figure, and knitr drops the caption, the fig.alt and the fig: anchor with it")
    } else if (!startsWith(label, "norun-")) {
      err(f, i, sprintf("chunk '%s' sets eval = FALSE; label it 'norun-%s' so that code the book prints but does not run is greppable", label, label))
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
for (f in prose_rmd) check_anchors(f)

# Two chapters cannot share a mnemonic: that is the collision the namespace
# exists to prevent, and it is invisible from inside either file.
local({
  mn <- unlist(MNEMONIC)
  for (d in unique(mn[duplicated(mn)])) {
    err(paste(names(mn)[mn == d], collapse = " + "), 1,
        sprintf("both use the '%s-' anchor namespace; pandoc will collide their sections", d))
  }
})
for (f in body_rmd)  check_contract(f)
for (f in all_rmd)   check_fig_alt(f)
for (f in all_rmd)   check_eval(f)
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
