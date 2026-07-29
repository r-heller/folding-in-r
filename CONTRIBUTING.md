# Contributing

## Before you write code

Open an issue first. A short description of the problem and the intended fix
saves both of us a rewrite.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/). One logical
change per commit; the subject line says what changed, the body says why.

## Dependencies

Any new package goes into the same commit as the code that needs it, together
with the `renv::snapshot()` that records it. A lockfile that drifts from the
code is worse than no lockfile.

## Citations

Never add a citation you have not verified. `scripts/verify-citations.R`
resolves every identifier in `book.bib` and gates CI. If an identifier will not
resolve, drop the claim rather than the check.

## Results

Stochastic results are reported across at least 20 seeds, as distributions.
Results that depend on fold angle are reported as curves. Both rules are
stated in "How to use this book" and apply without exception.

## Figures

Every figure carries `fig.alt`. Nothing is encoded by colour alone — mountain
and valley creases, for instance, differ in linetype as well as hue.
