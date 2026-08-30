#!/usr/bin/env Rscript
#
# The chain from producer to artefact to prose, checked as a chain.
#
# Each of the book's three claims broke at a DIFFERENT joint of that chain, and
# each break was invisible because nothing checked the chain as a whole:
#
#   Claim A  chapter specified, 4,400 words budgeted, no producer script at all.
#   Claim B  producer exists, has never been run to completion, no artefact.
#   E1       artefacts committed, producer halts on its first cell -- it still
#            declared a pattern family that R/folding.R had withdrawn, and
#            nothing runs the script in CI, so it stayed broken for four days.
#
# Three independent failures of one structure. This script is that structure's
# test. It is deliberately base R and readRDS only: it must run before any
# library is restored, so a green library is not a precondition for noticing
# that the evidence layer is broken.
#
# Usage:  Rscript scripts/check-artefact-producers.R
# Exit:   0 all checks pass (declared-open items are reported, not failed)
#         1 something is broken, or an OPEN entry has become true

root <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=",
          commandArgs(FALSE), value = TRUE)[1])), ".."), mustWork = TRUE)
setwd(root)

failures <- character(0)
notes    <- character(0)
fail <- function(...) failures <<- c(failures, paste0(...))
note <- function(...) notes    <<- c(notes,    paste0(...))

# ── What is known to be open ────────────────────────────────────────────────
#
# An artefact with no producer is a finding, not necessarily a defect: the book
# is written in an order, and Claim A's producer is genuinely Phase 1 work. What
# is NOT acceptable is an unowned gap. Every entry here names the roadmap item
# that closes it, and the check fails if an entry stops being true -- a producer
# that appears without its OPEN line being removed is as much a drift as one
# that disappears.
OPEN <- list(
  "evaluator-audit.rds" = "ROADMAP.md item 1.5 -- Claim A has no producer yet",
  "part2-sweeps.rds"    = "ROADMAP.md item 3.6",
  "classic-grid.rds"    = "ROADMAP.md item 3.6",
  "autoencoder-grid.rds" = "ROADMAP.md -- gated on the Chapter 7 cut decision",
  "metric-calibration.rds" = "ROADMAP.md item 1.5 -- folded into the evaluator audit"
)

DOCS    <- c("CHAPTERS.md", "PLAN.md", "PROJECT_CONCEPT.md")
SCRIPTS <- sort(list.files("scripts", pattern = "\\.R$", full.names = TRUE))
# This script names every artefact it knows about, so it would report itself as
# the producer of all of them.
SELF    <- "scripts/check-artefact-producers.R"
SCRIPTS <- setdiff(SCRIPTS, SELF)

# ── 1. Every artefact the documents name has exactly one producer ───────────
#
# Producers DECLARE their outputs, in a header line:
#
#     # @artefact data/processed/e1-difficulty.rds
#
# rather than being detected by grepping for the filename. Grep cannot tell a
# producer from a consumer or from a comment: `benchmark-grid` appears in
# run-benchmark-grid.R, which writes it, in prepare-single-cell.R, which reads
# it, and in experiment-e1.R, which only mentions it. A declaration is also the
# thing a reader of the script wants at the top of it.
#
# The declaration is checked against the code below, so it cannot drift into a
# promise: a script that declares an artefact must actually write one.

named <- unique(unlist(lapply(DOCS[file.exists(DOCS)], function(f) {
  txt <- readLines(f, warn = FALSE)
  unlist(regmatches(txt, gregexpr("[A-Za-z0-9][A-Za-z0-9._-]*\\.rds", txt)))
})))
named <- setdiff(named, "")

decl_of <- function(f) {
  txt <- readLines(f, warn = FALSE)
  hits <- grep("^#[[:space:]]*@artefact[[:space:]]+", txt, value = TRUE)
  # The path, then optionally a description of what is in it. Take the path.
  sub("[[:space:]].*$", "", trimws(sub("^#[[:space:]]*@artefact[[:space:]]+", "", hits)))
}
declared_by <- setNames(lapply(SCRIPTS, decl_of), SCRIPTS)

# A script that writes an .rds must say which. Otherwise the declaration is
# opt-in, and the one producer that forgets is invisible again.
for (f in SCRIPTS) {
  writes <- any(grepl("saveRDS", readLines(f, warn = FALSE), fixed = TRUE))
  if (writes && !length(declared_by[[f]])) {
    fail(f, " calls saveRDS() and declares no `# @artefact` line.")
  }
  if (!writes && length(declared_by[[f]])) {
    fail(f, " declares an artefact and never calls saveRDS().")
  }
}

producers_of <- function(artefact) {
  names(Filter(function(d) basename(artefact) %in% basename(d), declared_by))
}

cat("-- artefacts named in ", paste(DOCS, collapse = ", "), "\n", sep = "")
for (a in sort(named)) {
  p <- producers_of(a)
  open_reason <- OPEN[[a]]
  if (length(p) == 1L) {
    cat(sprintf("   %-24s <- %s\n", a, p))
    if (!is.null(open_reason)) {
      fail(a, " now has a producer (", p, ") but is still listed in OPEN. ",
           "Remove the OPEN entry -- the ledger has to move when the tree does.")
    }
  } else if (length(p) == 0L) {
    if (is.null(open_reason)) {
      fail(a, " is named in the book's specification and no script declares it. ",
           "Either write the producer or add it to OPEN with the roadmap item ",
           "that will.")
    } else {
      cat(sprintf("   %-24s -- OPEN: %s\n", a, open_reason))
      note(a, ": ", open_reason)
    }
  } else {
    fail(a, " is declared by ", length(p), " scripts (",
         paste(basename(p), collapse = ", "), "). One artefact, one producer.")
  }
}

# The other direction: an artefact produced and referenced by nothing is either
# dead compute or a chapter that forgot to cite its evidence.
orphans <- setdiff(unlist(declared_by), unlist(lapply(named, function(a) {
  unlist(lapply(declared_by, function(d) d[basename(d) == basename(a)]))
})))
for (o in unique(orphans)) {
  note(o, " is produced but named in none of ", paste(DOCS, collapse = ", "))
}

# ── 2. Every committed artefact carries provenance ──────────────────────────
#
# GENERATION_LOG.md and CHAPTERS.md both asserted the E1 artefacts carried
# provenance. All three had attr(x, "provenance") == NULL: the helper that
# writes it landed four days after the artefacts did, and nothing regenerated
# them. An artefact whose provenance is asserted in prose and absent on disk is
# worse than one with no provenance at all.

cat("\n-- provenance on committed artefacts\n")
rds <- sort(list.files("data/processed", pattern = "\\.rds$", full.names = TRUE))
rds <- rds[!grepl("-quick\\.rds$", rds)]      # smoke tests are not evidence
if (!length(rds)) {
  cat("   (none committed yet)\n")
}
for (f in rds) {
  x  <- tryCatch(readRDS(f), error = function(e) e)
  if (inherits(x, "error")) {
    fail(f, " cannot be read: ", conditionMessage(x)); next
  }
  pr <- attr(x, "provenance")
  if (is.null(pr)) {
    fail(f, " carries no provenance attribute. Regenerate it with its producer.")
    next
  }
  sha <- pr[["r_sha"]]
  if (is.null(sha) || length(sha) != 1L || is.na(sha) || !nzchar(sha)) {
    fail(f, " has a provenance block with no r_sha. It cannot be traced to the ",
         "code that made it.")
    next
  }
  cat(sprintf("   %-40s %6d rows  r_sha %s%s\n", f,
              if (is.null(nrow(x))) NA_integer_ else nrow(x), sha,
              if (isTRUE(pr[["quick"]])) "  [QUICK -- not evidence]" else ""))
  if (isTRUE(pr[["quick"]])) {
    fail(f, " was written by a --quick run and is committed as if it were ",
         "evidence.")
  }
}

# ── 3. Every family a producer declares can be built AND folded ─────────────
#
# The rule PLAN.md E2 states -- no registry entry may exist for a pattern that
# cannot be built -- enforced instead of restated. The parser is used rather
# than grep so that a family named only in a comment explaining its ABSENCE
# does not count as declaring it, which is the case in run-benchmark-grid.R.

cat("\n-- pattern families declared in registries\n")

for (f in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) source(f)

constructors <- Filter(function(nm) {
  is.function(get(nm)) && identical(names(formals(get(nm)))[1:2], c("nx", "ny"))
}, ls(envir = globalenv()))

# The registry names a producer may assign a list of families to.
REGISTRY <- c("FAMILIES", "PATTERNS", "PATTERN_GRID")

# A registry may key on the constructor's name (`miura_ori`) or on the family's
# (`miura`). Both have to resolve, or PATTERN_GRID's one live entry -- keyed on
# the family -- would be the one thing this check silently skipped.
ctor_of <- setNames(as.list(constructors), constructors)
for (ctor in constructors) {
  fam <- tryCatch(get(ctor)(3L, 3L)$family, error = function(e) NULL)
  if (!is.null(fam) && nzchar(fam)) ctor_of[[fam]] <- ctor
}
KEYS <- names(ctor_of)

declared <- list()
for (f in c(SCRIPTS, "R/constants.R")) {
  exprs <- tryCatch(parse(f), error = function(e) NULL)
  if (is.null(exprs)) { fail(f, " does not parse"); next }
  for (e in exprs) {
    if (!is.call(e) || !is.name(e[[1]]) ||
        !as.character(e[[1]]) %in% c("<-", "=", "<<-")) next
    lhs <- e[[2]]
    if (!is.name(lhs) || !as.character(lhs) %in% REGISTRY) next
    nms <- all.names(e[[3]])
    # A registry keyed BY family name declares the family whether or not it
    # names the constructor: PATTERN_GRID is a list of sizes, and listing a size
    # for a pattern that cannot fold is exactly how a dead arm survives.
    keys <- names(if (is.call(e[[3]])) as.list(e[[3]])[-1] else list())
    hits <- unique(c(intersect(nms, constructors), intersect(keys, KEYS)))
    if (length(hits)) {
      declared[[f]] <- unique(c(declared[[f]],
                                unlist(ctor_of[hits], use.names = FALSE)))
    }
  }
}

if (!length(declared)) cat("   (no registries found)\n")
for (f in names(declared)) {
  for (ctor in declared[[f]]) {
    built <- tryCatch(get(ctor)(3L, 3L), error = function(e) e)
    if (inherits(built, "error")) {
      fail(f, " declares family '", ctor, "', which cannot be BUILT: ",
           conditionMessage(built))
      next
    }
    folded <- tryCatch({ fold(built, 0.5); TRUE }, error = function(e) e)
    if (inherits(folded, "error")) {
      fail(f, " declares family '", ctor, "' in a registry, and it cannot be ",
           "FOLDED: ", sub("\n.*", "", conditionMessage(folded)))
      next
    }
    cat(sprintf("   %-34s %s: builds and folds\n", f, ctor))
  }
}

# ── Report ──────────────────────────────────────────────────────────────────

if (length(notes)) {
  cat("\nOpen, with an owner:\n")
  for (n in notes) cat("  - ", n, "\n", sep = "")
}

if (length(failures)) {
  cat("\nFAILED:\n")
  for (f in failures) cat("  * ", f, "\n", sep = "")
  cat("\n", length(failures), " problem(s).\n", sep = "")
  quit(status = 1L)
}

cat("\nartefact chain intact.\n")
