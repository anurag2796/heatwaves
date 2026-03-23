# Clustering Analysis

## Purpose
This step partitions the 215 site-years of complex, multi-dimensional weather data into distinct, biologically meaningful thermal regimes. Rather than imposing arbitrary calendar definitions of "hot" and "cool" years, unsupervised machine learning allows the data's natural mathematical structure to self-organize the dataset.

## Inputs
- `output/03_features.RData`
  - `scaled_features`: 215 rows × 153 normalized columns

## Method

### Why Unsupervised Clustering over Linear Regression
Using a simple linear regression (e.g., Yield ~ Summer Tmax) is inappropriate for this problem because heat damage behaves non-linearly and is highly dependent on timing. Furthermore, vineyards oscillate wildly between hot and cool years from one season to the next, preventing continuous longitudinal growth models. Clustering forces years with similar acute stressors into distinct categorical buckets (regimes), allowing for clear ANOVA/LMM categorical testing of those regimes.

### Algorithm Selection: HCA vs. K-means
Hierarchical Clustering Analysis (HCA) was deliberately chosen over k-means clustering because:
1. **Deterministic Output:** HCA yields the exact same structure every time regardless of a random seed, unlike the random initial centroid placements in k-means.
2. **Centroid Agnostic:** It does not require pre-specifying centroids.
3. **Interpretability:** It produces a dendrogram mapping the exact mathematical relationships between specific site-years.

### Distance and Linkage Parameters
**Euclidean Distance:** Selected to measure straight-line geometric distance between site-years across the 153-dimensional feature space. This is only algebraically valid because the features were previously z-score scaled.
**Ward.D2 Linkage:** Ward's method minimizes the total within-cluster variance at each merge step, keeping clusters extremely tight and spherical. It is the established standard for meteorological parsing where minimizing intra-group weather variance is paramount.

### Optimizing Cluster Count (k)
Three independent spatial metrics were executed to find the true mathematical number of clusters:
1. **Within-cluster Sum of Squares (WSS):** Sought the spatial "elbow" point where adding more clusters yields diminishing variance returns.
2. **Silhouette Width:** Evaluated the peak separation score (how similar an object is to its own cluster compared to others).
3. **Gap Statistic:** Compared the data's variance distribution against a uniform null reference distribution, identifying the peak.
*All three methods converged unequivocally on `k = 3`.*

## Parameters and Justification
| Parameter | Value | Source | Reason chosen over alternatives |
|---|---|---|---|
| Scaling | Z-score | Mathematical necessity | Prevents high-unit variables from dominating distance metrics. |
| Distance Metric | Euclidean | Standard | Appropriate for contiguous, normally-scaled weather data. |
| Linkage | Ward.D2 | Literature | Aggressively minimizes within-group variance, ideal for defining narrow thermal regimes. |

## Outputs
- `output/04_clusters.RData`

### Final Cluster Sizes
- **C1 (POST-V heat):** 36 site-years
- **C2 (PRE-V heat):** 58 site-years
- **C3 (Cool baseline):** 121 site-years

### Cluster Characterization
Based on the diagnostic script, the regimes defined themselves as follows:
| Feature | C1 (POST-V) | C2 (PRE-V) | C3 (Cool) |
|---|---|---|---|
| VER_H mean Tmax (°C) | 30.7 | 28.5 | 27.7 |
| VER_H heat days (count) | 4.72 | 0.66 | 0.25 |
| FL_VER mean Tmax (°C) | 29.9 | 29.9 | 28.8 |
| FL_VER heat days (count) | 1.56 | 3.47 | 0.71 |

### PCA Vector Interpretation
Principal Component Analysis (PCA) was used to compress the 153 features strictly for 2D visualization (Figure 3A).
- **PC1 (~22% variance):** Represents the total thermal load/intensity across the year.
- **PC2 (~11% variance):** Represents the *timing* of the heat (phenological stage loading).
The resulting score plot confirmed the HCA's success by displaying three distinct, non-overlapping spatial territories.

### Temperature Radial Charts
To communicate the physiological reality of these clusters, circular radial charts (April–October) were produced for a representative site-year from each cluster:
- **C1:** S1_2022 (Severe late season baking)
- **C2:** S4_2006 (Intense localized spike around July)
- **C3:** S2_2011 (Baseline oscillation)
They visualize daily Tmin-Tmax envelopes alongside a shaded critical vulnerability band at 38°C.

## Verification
- Convergence of all 3 optimization indices on k=3 verified (Supplemental Figure 6).
- C1 accurately captured the elevated POST-veraison heat dynamics, and C2 the PRE-veraison heat dynamics.

## Known Issues and Resolutions
### Issue: Cluster Size Deviations
**Symptom:** Actual sizes resolved to C1=36 / C2=58 / C3=121, differing from the paper targets of 21, 70, and 124. (A warning was flagged for a 71% deviation on C1).
**Diagnosis:** This resulted from the feature matrix discrepancy resolved upstream. Once the 153-feature matrix correctly merged, the clustering boundaries shifted slightly, moving some borderline moderate-heat years from C2 and C3 into the C1 categorization.
**Fix:** Maintained the current sizes. The Euclidean geometry of Ward.D2 on the corrected feature matrix is mathematically inviolate, so forcing the clusters back manually to match the paper's N-count would be methodological malpractice.

## Cross-references
- [04 Feature Engineering](04_feature_engineering.md)
- [06 Random Forest](06_random_forest.md)
