# Learned folds {#autoencoders}

*Can a network learn the fold and the unfold at once?*

<!-- TODO: chapter content. Outline below is the plan of record. -->

- A `torch` autoencoder with a two-unit bottleneck. (`keras` would pull TensorFlow and break clean-clone reproducibility.)
- The only method here that learns an explicit inverse: encoder = fold, decoder = unfold.
- Reconstruction loss is the fold–unfold identity made computable.
- Compare the learned decoder against the true unfolding, not just against the input.
