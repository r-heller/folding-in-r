# Neighbour embeddings {#neighbor}

*Why do t-SNE and UMAP disagree about the same data?*

<!-- TODO: chapter content. Outline below is the plan of record. -->

- `Rtsne` with `check_duplicates = TRUE`; document the duplicate-row failure mode.
- `umap(method = "naive")` — the default backend pulls Python `umap-learn`.
- Perplexity and `n_neighbors` sweeps.
- All results across `BENCH_SEEDS`, reported as distributions rather than means.
- Separate real disagreement from seed noise.
