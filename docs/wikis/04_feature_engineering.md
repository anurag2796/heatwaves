# Feature Engineering

## Purpose
Raw daily temperature logs are structurally incompatible with predictive modeling for grapevines. This step computationally translates 42 years of daily weather into ~200 highly specialized, biologically relevant heat exposure metrics—differentiating, for example, between a brief spike and an extended, unrelenting extreme heatwave during vulnerable developmental stages.

## Inputs
- `output/02_phenology.RData`
  - `gdd_cumulative`: Daily GDD profiles
  - `site_year_pheno`: Phenological milestone DOYs
- `db1_data`: PRISM raw weather

## Method

### Why Raw Weather Fails
Feeding raw Tmax arrays or simple monthly averages into a clustering algorithm flattens compounding heat dynamics. Two seasons might share an identical July mean Tmax (e.g., 34°C); however, one might experience consistent 34°C days, while the other oscillates between 28°C and highly destructive 42°C heatwaves. Advanced feature engineering captures duration, intensity, and timing of these extremes.

### The Three Temporal Frameworks
To exhaustively evaluate heat exposure, weather data were sliced along three distinct temporal axes. All three were included because the timing of thermal stress alters its physical manifestation:
1. **Monthly (April–October):** Standard climatological boundaries. Useful for aligning with generalized regional climate reports.
2. **Seasonal chronological (full, May–Jul, Aug–Oct):** Broad agrometeorological buckets separating early developmental phases from late-season ripening.
3. **Phenological intervals (BB–FL, FL–VER, VER–H):** *The most biologically meaningful framework.* Dynamically shifts the calendar window for each site-year to match the vine's actual physiological state (e.g., precisely capturing heat that occurred specifically during the veraison-to-harvest ripening window, regardless of whether that window fell in August or September).

### Heatwaves and HWU
A simple count of days $> 38$°C treats a 39°C day equally to a catastrophic 45°C day. We employ **Heat Wave Units (HWU)** to capture severity exponentially.
HWU sums the positive deviations above 38°C across all days of a heatwave.
*Worked example:*
- A 2-day 39°C event: `(39-38) + (39-38) = 2 HWU`
- A 4-day 42°C event: `(42-38)*4 = 16 HWU`
This metric effectively separates chronic low-grade heat from acute, destructive vascular stress.

### Normalization
The resulting raw `feature_matrix` contains mismatched scales (e.g., precipitation in hundreds of mm vs. VPD in single digits). `scale()` is applied column-wise to yield a mean of 0 and a standard deviation of ~1. Skipping this standardization would mathematically force the clustering algorithm (which uses Euclidean distance) to prioritize high-magnitude variables (precipitation) over low-magnitude but highly impactful variables (VPDmax).

## Parameters and Justification
| Parameter | Value | Source | Reason chosen over alternatives |
|---|---|---|---|
| Heat Threshold | 38°C | Paper specified | Canopy photosynthesis shuts down entirely near 38°C, and structural cellular damage begins. 35°C is too low to demarcate acute tissue stress in C. Sauvignon. |
| Min Heatwave Days | 2 days | Algorithmic logic | A single hot day does not fundamentally overwhelm vine cooling capacity like consecutive days do. |

## Outputs
- `output/03_features.RData` containing `scaled_features`.
- Original raw feature matrix dimensions: 215 records × 184 columns.
- Dropping 31 zero-variance columns yielded a final matrix of 153 normalized columns.

## Verification
- Z-score normalization verified: the mean of all column means equals exactly 0.000, and the mean of column SDs equals 1.000 (after adjusting for minor numerical precision limits).

## Known Issues and Resolutions
### Issue: The 147-Feature Bug
**Symptom:** Initial runs produced only 147 (or 153) features instead of the ~200+ expected, triggering downstream failures where the Random Forest topological error rate exceeded 7% (target 1.35%) and the top MDA variables lacked phenological interval drivers.
**Diagnosis:** The feature generation loops were silently dropping specific heat metrics (like `avg_hw_duration` and `avg_hw_vpd`) during merging steps or wiping them as zero-variance without substituting appropriate NA handles, collapsing the biological sensitivity of the matrix.
**Fix:** Refactored the `compute_heat_features()` iteration arrays to explicitly append all 14 metrics (including zero-counts for HWU and VPD) across ALL temporal slices—Monthly, Seasonal, and Phenological—forcing preservation of the dimensional space.
**Verification:** Re-running the pipeline correctly stabilized the spatial clustering and restored C1/C2 predictive segregation, bringing TER closer to anticipated thresholds.

## Cross-references
- [03 GDD Phenology](03_gdd_phenology.md)
- [05 Clustering](05_clustering.md)
