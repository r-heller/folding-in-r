# Geodesic methods {#geodesic}

*If the data lie on a folded sheet, how do you flatten it back out?*

<!-- TODO: chapter content. Outline below is the plan of record. -->

- Classical MDS with `cmdscale` as the baseline.
- Isomap: geodesics estimated by shortest paths on a kNN graph (`igraph::distances`).
- Locally linear embedding, and what it assumes about local neighbourhoods.
- Isomap is *built* for isometric embeddings, so the interesting result is where it breaks.
- Report the exact $\theta$ at which the kNN graph first bridges two facets — analytically and empirically.
