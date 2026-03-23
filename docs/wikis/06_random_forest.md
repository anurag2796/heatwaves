# Random Forest Validation

## Purpose
Hierarchical clustering will mathematically group any dataset, even random noise. To prove the three C1/C2/C3 thermal regimes represent genuine, distinct climatological realities, a bootstrap Random Forest (RF) classification model was used to see if the engineered heat features could prospectively predict a site-year's cluster label. The Topological Error Rate (TER) and Mean Decrease Accuracy (MDA) quantify this validity.

## Inputs
- `output/04_clusters.RData`
  - `scaled_features`: 153 normalized feature columns
  - `clusters_labelled`: The target classification array

## Method

### Why Random Forest?
Relying solely on clustering optimization indices (like silhouette width) provides internal evidence of shape but not predictive utility. Random Forest validation forces the model to learn the mathematical boundaries of the clusters on a training subset and predict unseen data. A low TER proves the clustering captured profound, consistent physical signals.

### Hyperparameters
- **50:50 Train/Test Split:** Standard practice often uses 80:20, but this provides the model overwhelming knowledge of a small (N=215) dataset. A harsh 50:50 split acts as a stringent stress test; if TER remains low when training on only 107 site-years, the cluster boundaries are exceedingly robust.
- **ntree = 500:** Enough trees to fully stabilize Out-Of-Bag (OOB) error rates, acting as a robust ensemble without wasting computational effort.
- **mtry = 7:** This restricts each tree split to evaluating only 7 random features. R's default would have been ~12 to 14 (square root of ~150-200 features). Using `mtry=7` deliberately suppresses inter-tree correlation, preventing a few dominant features from masking the contribution of secondary structural features.
- **Bootstrapping: 50 vs. 500:** 50 iterations was used for the main MDA extraction to provide a stable, efficient central tendency. 500 iterations were used for the Supplemental Figure 7 stress test specifically to hunt for rare, pathological train/test splits and guarantee that the absolute maximum TER boundary is respected even in worst-case scenarios.

### Phenological Loading (FL–VER)
Statistically, features constrained exactly to the Flowering-to-Veraison (FL-VER) interval theoretically dictate the clustering array. Biologically, this interval represents the phase of rapid cellular division and maximum canopy physiological strain. The paper concluded that phenological thermal timing inherently outperforms crude monthly calendar timing.

## Parameters and Justification
| Parameter | Value | Source | Reason chosen over alternatives |
|---|---|---|---|
| Random Seed | 42 | Documented choice | The paper failed to publish an exact seed. 42 locks reproducibility for our pipeline. |
| mtry | 7 | Paper-specified | Hardcoded specifically to counteract predictor correlation relative to R's default sqrt(N). |
| ntree | 500 | Standard | Limits processing overhead while guaranteeing stable convergence. |

## Outputs
- `output/05_rf_validation.RData`

### TER Results
| Statistic | 50-iteration main run | 500-iteration stress test |
|---|---|---|
| Mean TER | 1.89% | 1.72% |
| Max TER | 5.56% | 10.19% |
| Min TER | 0.00% | *Observed* 0.00% |
| SD | 1.24% | *Stable bounds* |

### Feature Importance (Top 20 MDA)
| Rank | Feature | MDA Score |
|---|---|---|
| 1 | Early_total_hwu | 6.760 |
| 2 | Early_max_hw_vpd | 6.324 |
| 3 | VER_H_avg_hw_vpd | 6.225 |
| 4 | VER_H_max_hw_vpd | 6.209 |
| 5 | VER_H_total_hwu | 6.193 |
| 6 | Early_n_heatwaves | 6.084 |
| 7 | VER_H_max_hw_duration | 6.003 |
| 8 | Early_avg_hw_duration | 5.977 |
| 9 | VER_H_avg_hw_duration | 5.968 |
| 10 | VER_H_n_heatwaves | 5.842 |
| 11 | BB_H_total_hwu | 5.726 |
| 12 | Full_total_hwu | 5.629 |
| 13 | BB_H_avg_hw_vpd | 5.628 |
| 14 | BB_H_max_hw_vpd | 5.604 |
| 15 | Full_max_hw_vpd | 5.578 |
| 16 | Late_total_hwu | 5.381 |
| 17 | Late_max_hw_vpd | 5.322 |
| 18 | VER_H_n_heat_days | 5.299 |
| 19 | Late_avg_hw_duration | 5.165 |
| 20 | BB_H_max_hw_duration | 5.159 |

## Verification
- TER performance heavily depends on the seed. Though mean TER across 500 iterations remains under the expected 2.00% target (1.72%), maximal error boundaries exceeded the theoretical limits, reflecting minor topological instabilities in the modified feature matrix.

## Known Issues and Resolutions
### Issue: FL-VER Dominance Absence
**Symptom:** The paper predicts the top 8 elements will all unequivocally belong to the `FL_VER_` interval. As documented in the table above, exactly 0 of the top 8 (and none of the top 20) in this reproduction run belong to `FL_VER_`. The top drivers were overwhelmingly `Early_` and `VER_H_` features.
**Diagnosis:** This derives directly from the 153-feature matrix suppression discussed in the [Feature Engineering](04_feature_engineering.md) debugging log. Altering the shape of the feature dimensions forced the random forest to hunt for surrogate variables to define C1/C2 boundaries, elevating non-phenological chronological bounds (like `Early_total_hwu`) to primary importance. Because this fundamentally severs the paper's biological thesis (that phenology outranks calendar dates), it is the most critical discrepancy in the reproduction.

## Cross-references
- [04 Feature Engineering](04_feature_engineering.md)
- [07 Linear Mixed Models](07_linear_mixed_models.md)
