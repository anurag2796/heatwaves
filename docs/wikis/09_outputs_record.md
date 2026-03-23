# Complete Outputs and Verification Record

## Purpose
This page documents the absolute, system-level manifest of every object created during the reproduction, culminating in a tabular verification scorecard assessing the project's fidelity to the Previtali et al. (2026) source publication.

## Files Generated

| Script | Output file | Location | Format | Size | Contents |
|---|---|---|---|---|---|
| `01_setup_and_data.R` | `01_data_loaded.RData` | `output/` | R Image | 1.1MB | `db1`–`db4` objects, `site_info`, `block_stats` |
| `02_gdd_phenology.R` | `02_phenology.RData` | `output/` | R Image | 652KB | `pheno_imputed`, `site_year_pheno`, `gdd_cumulative` |
| `03_feature_engineering.R` | `03_features.RData` | `output/` | R Image | 267KB | `feature_matrix` (raw 184 features), `scaled_features` (153 cols) |
| `04_hca_clustering.R` | `04_clusters.RData` | `output/` | R Image | 271KB | `hc` dendrogram, `clusters_labelled`, `cluster_assignments` |
| `04_hca_clustering.R` | `supp_fig6_*.png` (3x) | `figures/` | PNG | ~150KB | WSS, Silhouette, and Gap optimization curves |
| `05_random_forest.R` | `05_rf_validation.RData` | `output/` | R Image | <10KB | `TER_results`, `mda_sorted`, `stress_results` |
| `06_linear_mixed_models.R`| `06_lmm_results.RData` | `output/` | R Image | 53KB | All 14 LMM hypothesis test readouts and filtered subsets |
| `07_figures.R` | `fig*.png` / `supp_fig*.png`| `figures/` | PNG | ~5MB | 17 separate visualization grids |
| `08_verification_report.R`| `verification_log.txt` | `output/` | TXT | 7KB | Plaintext programmatic evaluation of metrics |

## Final Verification Report

| Check | Expected | Actual | Pass/Fail |
|---|---|---|---|
| GDD Start Date | March 1 | March 1 | **Pass** |
| Z-score Mean | 0.00 | 0.00 | **Pass** |
| Z-score SD | 1.00 | 1.00 | **Pass** |
| WSS/Sil/Gap optimize | k=3 | k=3 | **Pass** |
| C3 (Cool) 'n' count | 124 | 121 (dev 2%)| **Pass** |
| C2 (PRE-V) 'n' count | 70 | 58 (dev 17%)| Fail |
| C1 (POST-V) 'n' count| 21 | 36 (dev 71%)| Fail |
| RF Mean TER | < 2% | 1.89% | **Pass** |
| RF Max TER | < 2% | 5.56% | Fail |
| Top 8 MDA features | All FL_VER | 0 are FL_VER | Fail |
| C3 Harvest DOY | 291 | 288.6 | **Pass** |
| C2 Harvest Shift | -13 days | -8 days | Fail |
| C1 Harvest Shift | -17 days | -13 days | Fail |
| C3 Yield Baseline | 7.0 t/ha | 7.75 t/ha| Fail |
| C1 Yield Penalty | -22% | -24.6% | **Pass** |
| C2 Yield Penalty | -30% | -13.7% | Fail |
| TSS (C1 elevated) | Sig higher | Sig higher | **Pass** |
| Malic Acid (C1 spike)| Sig higher | Sig higher | **Pass** |
| YAN (C2 drop) | Sig lower | Sig lower | **Pass** |
| Berry Moisture | p > 0.05 | p = 0.8336 | **Pass** |
| C6 Compounds | p > 0.05 | p = 0.0000 | Fail |
| Assumption Tests run | Yes | Yes | **Pass** |
| All 20 Figures Present | Yes (20 files) | Yes (20 files) | **Pass** |

> Note: For exhaustive 68-item verification limits, consult the raw output log in the reproduction environment. The table above highlights critical gates.

### Overall Match Score
**53 / 68 checks passed (78%)**

## Cross-references
- [10 Debugging Log](10_debugging_log.md)
