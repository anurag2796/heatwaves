# Methods

## 1. GDD and Phenological Imputation

- **Script:** `02_gdd_phenology.R` | **Helpers:** `R/utils/gdd_utils.R`
- **GDD formula:** `max(0, Tmean − 10)`, accumulated daily from March 1, no upper cap.
- **Imputation** (3-tier priority for missing BB/FL/VER/H dates):
  1. Site-specific mean GDD threshold from observed years
  2. Year-specific mean across sites
  3. Global mean across all site-years
  4. Fallback: end-of-October DOY if threshold never reached
- **Output:** 215 site-year combinations with complete phenology → `02_phenology.RData`

## 2. Feature Engineering

- **Script:** `03_feature_engineering.R` | **Helpers:** `R/utils/heat_utils.R`
- **220 features** across 3 temporal frameworks:

| Framework | Intervals | Purpose |
|---|---|---|
| Monthly | Mar–Oct individually | Standard climatological |
| Seasonal | May–Jul, Aug–Oct, Apr–Oct | Broad agro buckets |
| Phenological | BB→FL, FL→VER, VER→H, BB→H | Biologically aligned |

- **Metrics per interval:** GDD, Tmax, Tmean, Tmin, HWU, PPT, frost days, frost units, VPDmin, VPDmax, VPDavg, heat days, heatwave count/duration/intensity/VPD
- **Heatwave definition:** ≥ 2 consecutive days with Tmax ≥ 38 °C
- **HWU (Eq. 1):** `∑ max(0, Tmax − 38)` over heatwave days
- **Scaling:** Column-wise z-score; zero-variance columns dropped (220 → ~217)
- **Output:** `03_features.RData`

## 3. Hierarchical Clustering

- **Script:** `04_hca_clustering.R`
- **Algorithm:** Ward.D2 linkage, Euclidean distance on scaled features
- **k selection:** WSS elbow + silhouette + gap statistic → all converge on k = 3
- **Label assignment:**
  - C1 = highest VER→H Tmax → POST-Veraison heat
  - C2 = highest FL→VER Tmax (of remainder) → PRE-Veraison heat
  - C3 = Cool baseline
- **Output:** `04_clusters.RData`

## 4. Random Forest Validation

- **Script:** `05_random_forest_validation.R`
- **Primary:** OOB error from full-data RF (ntree=500, mtry=√p≈14)
- **Secondary:** 50-iteration stratified 50:50 bootstrap (stress test)
- **MDA:** Top features should be pre-veraison heatwave metrics
- **Output:** `05_rf_validation.RData`

## 5. Linear Mixed Models

- **Script:** `06_linear_mixed_models.R` | **Helpers:** `R/utils/model_utils.R`
- **Model:** `response ~ cluster + (1 | block_ID)`
  - Fixed effect: `cluster` (C1/C2/C3)
  - Random intercept: `block_ID` — absorbs permanent vineyard-level confounders
- **14 response variables:** Harvest DOY, Yield, 12 fruit analytes
- **Post-hoc:** Tukey-adjusted emmeans for significant LMM effects
- **Robustness:** Kruskal-Wallis + BH-adjusted pairwise Wilcoxon reported alongside
- **Sub-analysis:** Yield stratified by vine age (Young 3–5yr, Mature >5yr)
- **Output:** `06_lmm_results.RData`
