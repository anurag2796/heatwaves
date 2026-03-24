# GDD Phenology and Imputation

## Purpose
This step tracks physiological vine development using cumulative thermal time rather than fixed calendar dates, generating phenologically meaningful boundaries for extracting specialized extreme heat features. Because detailed phenology is rarely tracked uniformly across 42 years, a robust missing-data imputation strategy is implemented.

## Inputs
- `output/01_data_loaded.RData`
  - `db1_data`: PRISM daily weather (Tmean)
  - `db2_data`: Raw observed phenological dates

## Method

### Phenology over Calendar Time
Calendar dates are insufficient for tracking grapevine development because the start and progression of the physiological season (and susceptibility to extreme heat) shift annually depending on cumulative thermal load. A 40°C day on July 10 might strike during the resistant pre-veraison lag phase in a late year, but during the vulnerable ripening phase in an early year. Tracking by Growing Degree Days (GDD) standardizes this exposure.

### Base Temperature: 10°C
The 10°C base temperature is the established minimum threshold for active vegetative growth in *Vitis vinifera*. At daily mean temperatures strictly below 10°C, zero developmental progress is recorded. Selecting a different threshold (e.g., 5°C or 12°C) fundamentally distorts the thermal time required to reach critical stages, disconnecting the model from regional Cabernet Sauvignon physiological realities.

### The Four Stages Tracked
1. **BB (Budbreak):** The initiation of active growth from dormancy.
2. **FL (Flowering):** Capfall and pollination; a critical yield-determining window deeply sensitive to extreme heat.
3. **VER (Veraison):** The onset of ripening, marked by berry softening and color change. Shifts the vine focus to sugar accumulation and flavor metabolism.
4. **H (Harvest):** Commercial maturity.

### Start Date Optimization: March 1
Accumulating GDD from March 1 rather than January 1 provides significantly superior predictive fit. January and February in Northern California routinely accumulate small false-positive heat units that do not drive vine development due to day-length requirements and deep winter dormancy. Supplemental Figure 2 demonstrates that March 1 GDD accumulation (measured via $R^2$ to actual DOY) sharply outperforms January 1 accumulation models.

### Phenological Imputation
A strict priority waterfall was utilized to estimate the calendar date of missing phenological stages by tracking when their expected GDD threshold was crossed.

**Priority Levels for Threshold Selection:**
1. **Site-specific average:** Uses the mean target GDD from years *with* observations at that specific site. Preferred because it captures site-unique topography, mesoclimate, and localized rootstock genetics.
2. **Year-specific average across sites:** Used when a site lacked sufficient history. Captures regional idiosyncratic stressors of a given vintage.
3. **Global long-term average:** Used as an absolute last resort when neither site nor vintage provided reliable threshold histories.

## Parameters and Justification
| Parameter | Value | Source | Reason chosen over alternatives |
|---|---|---|---|
| Base Temperature | 10°C | Established literature | Represents the biological zero point for active vine metabolism. |
| Start Date | March 1 | Tested comparison | Excludes biologically irrelevant winter heat anomalies. Proven via Supp Fig 2. |
| Fallback Date | DOY 304 (Oct 31) | Algorithmic bounds | If an impossibly cool year fails to reach a threshold, DOY 304 defines an absolute late ceiling. |

## Outputs
- `output/02_phenology.RData` containing `pheno_imputed` and the structured 215 site-year grid.

## Verification
- **Supp Figure 2 Replication:** Successfully confirmed that March 1 modeling fits the historical observations tightly compared to January 1 baselines.
- **NA Count Clearance:** 2,245 original matrix observations contained sweeping gaps (903 missing BB, 1,108 missing FL, 1,144 missing VER, 840 missing H). The imputation waterfall correctly populated the dates by dynamically tracking individual site-year thermal accumulations, shrinking data loss to exactly 0 across the final 215 site-year continuous grid.

## Known Issues and Resolutions
None.

## Cross-references
- [02 Data Sources](02_data_sources.md)
- [04 Feature Engineering](04_feature_engineering.md)
