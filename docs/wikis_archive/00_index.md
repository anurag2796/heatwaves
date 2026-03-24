# Previtali et al. (2026) Reproduction Wiki

## Purpose
This project comprehensively reproduces the analysis presented in Previtali et al. (2026), applying the identical analytical pipeline to four interconnected databases spanning 42 years of climatological and viticultural data from Northern California vineyards. The analytical workflow encompasses data extraction, phenological modeling via base-10 Growing Degree Days (GDD), rigorous feature engineering tailored to developmental intervals, Ward's hierarchical clustering (HCA) to identify thermal regimes, Random Forest validation for group predictive accuracy, and Linear Mixed Models (LMMs) for statistical inference regarding harvest advancement, yield penalties, and fruit composition shifts under extreme heat regimes. This wiki meticulously documents every parameter decision, algorithmic choice, data transformation, outputs, and verification against the original paper.

## Wiki Directory

- [01 Project Overview](01_project_overview.md): High-level summary of the paper's research question, the end-to-end analytical workflow, and the five key findings being reproduced.
- [02 Data Sources](02_data_sources.md): Details of the four Figshare databases, PRISM climate data configurations, coordinate handling, and explicit data screening decisions.
- [03 GDD Phenology](03_gdd_phenology.md): Justification for phenological tracking over calendar dates, base temperature choices, start-date optimization, and the strict tiered imputation strategy.
- [04 Feature Engineering](04_feature_engineering.md): Rationales for the three temporal frameworks, explicit heat threshold calculations (38°C), the creation of Heat Wave Units (HWU), and feature scaling methods.
- [05 Clustering](05_clustering.md): The motivation for unsupervised Ward.D2 hierarchical clustering, interpretation of convergence metrics (WSS, Silhouette, Gap), and final cluster characterizations (POST-V, PRE-V, Cool).
- [06 Random Forest Validation](06_random_forest.md): Implementation details of the classification model, hyperparameter reasoning, stress testing for the Topological Error Rate (TER), and Mean Decrease Accuracy (MDA) feature rankings.
- [07 Linear Mixed Models](07_linear_mixed_models.md): The statistical modeling framework isolating cluster effects while accounting for block-level random intercepts, alongside exhaustive 14-variable results and significance tests.
- [08 Figures](08_figures.md): A comprehensive catalogue of all generated visual outputs, their corresponding source scripts, and comparisons against published figures.
- [09 Outputs Record](09_outputs_record.md): Complete manifest of intermediate matrices, data files, models exported, and the ultimate tabulated verification of all checks.
- [10 Debugging Log](10_debugging_log.md): A transparent, chronological record of issues encountered during reproduction (e.g., feature matrix discrepancies) including symptoms, root causes, and definitive fixes.
- [11 Limitations](11_limitations.md): Critical analysis of constraints inherent in the data or methodology, such as small biochemical samples, unmeasured confounders, and generalizability, contextualizing the reproduction's scope.

## Project Status
**Final Verification Match Score:** 53 out of 68 checks passed (78%)
**Date Completed:** 2026-03-23

## Environment
```
R version 4.5.3 (2026-03-11)
Platform: aarch64-apple-darwin25.3.0
Running under: macOS Tahoe 26.3.1

Matrix products: default
BLAS:   /opt/homebrew/Cellar/openblas/0.3.31_1/lib/libopenblasp-r0.3.31.dylib 
LAPACK: /opt/homebrew/Cellar/r/4.5.3/lib/R/lib/libRlapack.dylib;  LAPACK version 3.12.1

locale:
[1] C.UTF-8/C.UTF-8/C.UTF-8/C/C.UTF-8/C.UTF-8

time zone: America/New_York
tzcode source: internal

attached base packages:
[1] stats     graphics  grDevices utils     datasets  methods   base     

loaded via a namespace (and not attached):
[1] compiler_4.5.3
```
