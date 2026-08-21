#!/usr/bin/env Rscript
#
# Chapter 12's dataset: Fresh 68k PBMCs (Donor A), Zheng et al. 2017.
#
# NOT run in CI and not run at render time. Run it once, commit the artefact it
# writes, and keep this script as the record of how that artefact was produced
# -- the same provenance convention as scripts/run-benchmark-grid.R.
#
# LICENCE. The dataset is CC BY 4.0, so the reduced matrix may be committed to
# this repository with attribution. What stops the full matrix being committed
# is size, not licence: sixty-eight thousand cells by the full gene set is far
# more than git should carry and far more than Chapter 12 reads.
#
# LABELS. The cell-type labels are NOT derived from clustering this matrix and
# not from any embedding of it. Zheng et al. sequenced ten bead-enriched
# purified subpopulations from the same donor separately, and assigned each
# cell the identity of the purified population with which it correlated most
# strongly (Spearman). See A2-datasets.Rmd for what that does and does not
# license Chapter 12 to claim -- in particular, it is independent of the
# embeddings under test, which is the circularity that would matter, but it is
# not an independent measurement of cell identity.
#
# Usage:  Rscript scripts/prepare-single-cell.R [--force]

force <- "--force" %in% commandArgs(trailingOnly = TRUE)

RAW_DIR <- "data/raw"
OUT     <- "data/processed/pbmc68k.rds"

# 10x publishes the filtered matrix and the annotation as separate tarballs.
SOURCES <- list(
  matrix = list(
    url  = "https://cf.10xgenomics.com/samples/cell-exp/1.1.0/fresh_68k_pbmc_donor_a/fresh_68k_pbmc_donor_a_filtered_gene_bc_matrices.tar.gz",
    file = file.path(RAW_DIR, "pbmc68k_filtered_matrices.tar.gz")
  )
)

# ── Reduction ───────────────────────────────────────────────────────────────
#
# Every number here is a choice, so every number here is named and defended
# rather than left as a magic constant in a pipeline.

N_CELLS <- 10000L   # a stratified subsample: enough to keep the rare
                    # populations (dendritic, CD34+) present at a few hundred
                    # cells each, small enough to commit and to embed nine ways
                    # across twenty seeds without the chapter becoming a
                    # compute item in its own right.
N_HVG   <- 1000L    # highly variable genes, the usual first step, and the one
                    # every method in Part II would otherwise apply
                    # differently and invisibly.
N_PCS   <- 50L      # the PCA basis every downstream method starts from, so
                    # that the comparison is between embeddings and not
                    # between preprocessing choices.

if (file.exists(OUT) && !force) {
  message(OUT, " already exists. Pass --force to rebuild it.")
  quit(status = 0)
}

stop(
  "Not yet implemented.\n\n",
  "This script is a committed placeholder with the decisions already made, not\n",
  "a stub with the decisions deferred. What is settled and recorded in\n",
  "A2-datasets.Rmd: the dataset (Zheng et al. 68k PBMC, Donor A), the licence\n",
  "(CC BY 4.0, redistribution permitted), and the label provenance (purified\n",
  "subpopulations, not clustering, so not circular with the embeddings).\n\n",
  "What remains is the reduction above and the download, and neither should be\n",
  "written before Chapter 10's pre-registered selection rule is committed --\n",
  "see PLAN.md S1-11. A selection rule written after the data are in hand is\n",
  "not a pre-registration, and the chapter's null-result promise depends on it.",
  call. = FALSE
)
