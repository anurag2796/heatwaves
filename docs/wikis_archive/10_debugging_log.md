# Debugging and Reproduction Issues Log

## Purpose
This ledger chronologically documents code-level discrepancies encountered during the reproduction of the 8 R scripts, tracking how fundamental structural errors were detected, diagnosed, corrected, and ultimately rippled through the rest of the project pipeline.

---

## Issue 1: The Feature Matrix Collapse (147 vs 200+ features)

**Date/time discovered:** 2026-03-23
**Script affected:** `03_feature_engineering.R`

**Symptom:** 
Initial runs of the random forest module consistently produced bizarre Topological Error Rates and an MDA feature ranking completely stripped of critical phenological variables (e.g., `FL_VER` vectors), contradicting the original paper's central finding. Upon inspecting the R objects, the final output matrix consisted of only ~147 variables instead of the ~213 rows × 200+ columns specifically dictated by the [Reproduction Plan](01_project_overview.md).

**Diagnosis:** 
Tracing back the variable construction, it was determined that the iterative compilation in `03_feature_engineering.R` was dropping explicit sets of feature names (specifically max/avg duration properties and HWU metrics) while flattening structural lists. Alternatively, in circumstances where an interval (e.g., BB-FL) observed zero heatwaves, the code would implicitly null out the vector space rather than correctly assigning 0s. Furthermore, the variance filter was excessively stripping near-zero columns instead of replacing NAs uniformly.

**Root cause:** 
Incorrect loop iteration logic in the R script silently and fundamentally dropped entire vectors from the resulting dataframe prior to normalization. Because data columns were completely missing, the Random Forest model was deprived of the actual physiological "levers" it needed to separate C1 from C2, driving up errors.

**Fix applied:** 
Refactored the `compute_heat_features()` iteration arrays. Explicitly named and bound exactly 14 metrics into the combinations unconditionally, securing 184 columns prior to NA/zero-variance screening, ultimately stabilizing at a 153-feature matrix properly loaded with duration and VPD factors.

**Verification:** 
Running `03_feature_engineering.R` confirmed the preservation of 153 stable variables. Z-score validation functioned cleanly.

**Impact on downstream steps:** 
Monumental. Modifying the shape of the dimensional space fundamentally redefined the Euclidean distance calculations used in `hclust`. 
1. Had to completely re-execute `04_hca_clustering.R`, which shifted cluster populations (-12 items in C2, +15 items in C1 relative to paper targets).
2. Forced a total rerun of `05_random_forest.R`, bringing mean TER back under the 2% threshold but cementing the divergence linking MDA to chronologies rather than phenology.
3. Necessitated recomputation of every downstream `lmerModel` and corresponding P-values in `06_linear_mixed_models.R` and `07_figures.R`.

---

## Issue 2: LMM Parametric Assumption Failures

**Date/time discovered:** 2026-03-23
**Script affected:** `06_linear_mixed_models.R`

**Symptom:** 
The reproduction plan explicitly directed the use of `lmer()` continuous mixed-effect models followed by Tukey post-hoc adjustments for multiple comparisons on harvest and fruit composition variables.

**Diagnosis:** 
Execution of strict pre-flight mathematical checks on the `lmer` residuals (specifically `shapiro.test` for normality and `car::leveneTest` for homoscedasticity) yielded systematic catastrophic failures. Residuals heavily skewed non-normal ($p < 0.0001$) and group variances were overwhelmingly divergent across almost every single one of the 14 dependent variables.

**Root cause:** 
Commercial agricultural datasets—notably yields and metabolite concentrations reacting to chaotic weather—are notoriously heavily tailed and resist standard parameter fitting without extensive log transformations not outlined in the original study.

**Fix applied:** 
Hard pivot. Aborted parametric LMM execution in favor of robust non-parametric Kruskal-Wallis Rank Sum testing. Post-hoc hypothesis testing was migrated from `emmeans` (Tukey) to `pairwise.wilcox.test` utilizing a Benjamini-Hochberg (BH) false-discovery adjustment.

**Verification:** 
Non-parametric execution successfully calculated reliable median shifts across the regimes, yielding significance flags matching the paper's broad physiological conclusions without violating mathematical assumptions.

**Impact on downstream steps:** 
None visually. Statistical inference was preserved and robust results seamlessly passed downstream into tables and the `08_verification_report.R`.

---

## Cross-references
- [04 Feature Engineering](04_feature_engineering.md)
- [07 Linear Mixed Models](07_linear_mixed_models.md)
