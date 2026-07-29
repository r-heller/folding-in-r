# How to use this book {-}

## Standing methodological rules {-}

Three rules apply throughout and are not restated in each chapter.

1. **Every stochastic result is reported across at least 20 seeds.** t-SNE and
   UMAP are seed-dependent; a single run is an anecdote. Seeds are fixed in
   `_common.R` as `BENCH_SEEDS` and disclosed with every figure.

2. **Every $\theta$-dependent result is reported as a curve, never as a single
   number.** Fold angle is a continuous difficulty parameter. Reporting one
   value invites cherry-picking, and hides exactly the regime changes the
   benchmark exists to expose.

3. **Every figure carries `fig.alt`.** No result is encoded by colour alone.

## What you need {-}

R 4.1 or newer and the packages pinned in `renv.lock`. Run `renv::restore()`
once after cloning. The companion package `foldbench` provides the pattern
constructors, the sampler, and the evaluation metrics; the book loads it but
does not reproduce its source.

The Chapter \@ref(results) benchmark grid takes hours to compute. It is
precomputed and committed under `data/processed/`; `scripts/run-benchmark-grid.R`
is kept as the provenance record rather than run during the build.

## How to read it {-}

Part I builds the object. Part II tests four families of method against it.
Part III is the benchmark proper and contains the book's main contribution —
Chapter \@ref(evaluation), where the evaluation metrics themselves are checked
against exact truth. Part IV asks whether any of it changes a real decision.

Readers who only want the benchmark can start at Chapter \@ref(benchmarks) and
refer back to Chapter \@ref(generative) for the generative model.
