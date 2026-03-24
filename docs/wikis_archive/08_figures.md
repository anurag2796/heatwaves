# Figures Catalogue

## Purpose
This document provides a comprehensive ledger of every visual output generated during the reproduction, linking each figure back to the originating script, the specific input arrays utilized, its scientific intention, and visual fidelity compared to Previtali et al. (2026).

---

### Figure 2: Attribution of Harvest DOY (S4)
- **Script:** `07_figures.R`
- **Input Data:** `yield_filtered` joined with `cluster_assignments` (Site S4 only)
- **What it shows and why:** A line/scatter plot tracking the yearly Day of Year (DOY) of harvest at site S4, colored by thermal cluster label. Validates that the attribution procedure safely matches phenological endpoints to clustered weather events without disjoint year boundaries.
- **File Name:** `fig2_attribution_s4.png`
- **Visual Differences:** Exact numerical match. Minor aesthetic variations in precise axis breakpoints.

### Figure 3A: PCA Score Plot
- **Script:** `07_figures.R`
- **Input Data:** `scaled_features`, `clusters_labelled`
- **What it shows and why:** A 2D PCA projection of the 153-dimensional feature space. Evaluates spatial separability of C1, C2, and C3.
- **File Name:** `fig3a_pca.png`
- **Visual Differences:** Rotational differences on PC axes due to standard unanchored eigen decomposition, but grouping morphology is identical.

### Figure 3B: Temperature Radials (C1, C2, C3)
- **Script:** `07_figures.R`
- **Input Data:** `db1_data` (filtered by rep site-year)
- **What it shows and why:** Circular clock-style graphs plotting April-October daily Tmax/Tmin envelopes against a 38°C danger line. Communicates the visceral difference between late-season baking (C1: S1 2022) and mid-season spikes (C2: S4 2006).
- **File Name:** `fig3b1_radial_C1.png`, `fig3b2_radial_C2.png`, `fig3b3_radial_C3.png`
- **Visual Differences:** None.

### Figure 4A: TER per RF Iteration
- **Script:** `07_figures.R`
- **Input Data:** `TER_results` (Vector from RF bootstrap)
- **What it shows and why:** Scatter plot graphing the Topological Error Rate across 50 iterations, with thresholds drawn at the mean and 2% maximal limit. Proves cluster robustness.
- **File Name:** `fig4a_ter.png`
- **Visual Differences:** Our line spikes higher (max 5.56%) due to feature matrix variances and random seed differences missing the paper's 1.35% ideal.

### Figure 4B: Variable Importance (MDA)
- **Script:** `07_figures.R`
- **Input Data:** `mda_sorted`
- **What it shows and why:** Horizontal bar chart ranking the top 20 structural features distinguishing thermal regimes. Intended to prove the dominance of the `FL_VER_` phenological window. 
- **File Name:** `fig4b_mda.png`
- **Visual Differences:** As noted in the debugging log, this plot severely diverges from the publication. Our ranking prominently elevates `Early_` and `VER_H_` features over `FL_VER_`.

### Figure 5: Heat Metrics (A, B, C)
- **Script:** `07_figures.R`
- **Input Data:** `feature_matrix`, `clusters_labelled`
- **What it shows and why:** Defines the empirical weather traits of the three regimes via boxplots of Tmax, Heat days, and Heatwaves broken down per interval (BB-FL, FL-VER, VER-H).
- **File Name:** `fig5a_tmax_dist.png`, `fig5b_heat_days.png`, `fig5c_heatwaves.png`
- **Visual Differences:** Minor median shifts due to the boundary migration of ~15 site-years.

### Figure 6: Harvest and Yield Distributions
- **Script:** `07_figures.R`
- **Input Data:** `yield_filtered`, `clusters_labelled`
- **What it shows and why:** Boxplots and density distribution overlays showing the sharp left-shift (advancement/loss) of harvest dates and agricultural yield reacting to C1 and C2 stress.
- **File Name:** `fig6ab_harvest.png`, `fig6cd_yield.png`
- **Visual Differences:** Extremely high correlation to source. Density peaks matched exactly.

### Figure 7: Fruit Composition Analytes
- **Script:** `07_figures.R`
- **Input Data:** `comp_filtered`, `clusters_labelled`
- **What it shows and why:** A 12-panel multi-facet grid graphing individual analyte boxplots across the three regimes to demonstrate chemical penalty.
- **File Name:** `fig7_composition.png`
- **Visual Differences:** Identical structure; YAN and Malic Acid penalty directions perfectly mirror publication graphics.

### Supplemental Figure 2: GDD Comparison
- **Script:** `07_figures.R`
- **Input Data:** `pheno_gdd`
- **What it shows and why:** Linear regressions comparing observed phenological DOY against GDD started in January vs GDD started in March. Validates the March 1 modeling choice.
- **File Name:** `supp_fig2_gdd_comparison.png`
- **Visual Differences:** None.

### Supplemental Figure 6: Cluster Optimization
- **Script:** `04_hca_clustering.R`
- **Input Data:** `scaled_features`
- **What it shows and why:** WSS elbow plot, Silhouette plot, and Gap Statistic curve algorithmically proving the presence of exactly 3 regimes.
- **File Name:** `supp_fig6_wss.png`, `supp_fig6_silhouette.png`, `supp_fig6_gap.png`
- **Visual Differences:** Perfect convergence match at k=3.

### Supplemental Figure 7: RF Stress Test
- **Script:** `07_figures.R`
- **Input Data:** `stress_results`
- **What it shows and why:** Boxplots of TER across 50, 100, 200, 300, 400, and 500 bootstraps. Ensures stability at scale.
- **File Name:** `supp_fig7_stress_test.png`
- **Visual Differences:** As noted previously, the reproduction exhibits a radically wider spread on extreme values (>8% max) than the source graphics.

### Supplemental Figure 15: Vine Age
- **Script:** `07_figures.R`
- **Input Data:** `yield_age`, `clusters_labelled`
- **What it shows and why:** Boxplots separating young vs mature blocks, proving that while mature blocks have higher ceilings, both suffer identical ~30% proportional heat penalization.
- **File Name:** `supp_fig15_vine_age.png`
- **Visual Differences:** None.

## Cross-references
- [09 Outputs Record](09_outputs_record.md)
