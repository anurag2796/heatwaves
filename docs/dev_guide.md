# Developer Guide

## Running the Pipeline

```bash
bash run_complete_pipeline.sh
```

Scripts run sequentially: `01` → `02` → `03` → `04` → `05` → `06` → `07` → `08`.
Each script loads the previous stage's `.RData` from `output/`.

## Project Structure

```
heatwaves/
├── 01_setup_and_data.R          # Data loading + package installation
├── 02_gdd_phenology.R           # GDD, phenological imputation
├── 03_feature_engineering.R     # 220 weather features + scaling
├── 04_hca_clustering.R          # Ward.D2 HCA, k=3
├── 05_random_forest_validation.R # OOB RF + bootstrap validation
├── 06_linear_mixed_models.R     # LMMs for all response variables
├── 07_figures.R                 # Publication figures
├── 08_verification_report.R     # Automated paper target checks
├── run_complete_pipeline.sh     # End-to-end runner
├── R/utils/                     # Reusable helper functions
│   ├── log_utils.R              #   log_step(), log_check()
│   ├── heat_utils.R             #   compute_generic(), compute_heatwave()
│   ├── gdd_utils.R              #   impute_phenology(), find_doy_for_threshold()
│   ├── model_utils.R            #   sanitize_fruit_columns(), get_cluster_median()
│   └── plot_theme.R             #   theme_paper, cluster_colours/labels
├── data/                        # Raw Excel files (gitignored)
├── output/                      # .RData intermediates + logs
├── figures/                     # Generated PNGs
├── docs/                        # This documentation
└── Heatwaves.pdf                # Source paper
```

## Naming Conventions

| Entity | Convention | Examples |
|---|---|---|
| R functions | `snake_case`, verb-first | `compute_generic()`, `run_model()` |
| Variables | `snake_case` | `site_year_pheno`, `scaled_features` |
| Feature names | `Metric_interval` | `Tmax_BLtoVER`, `HWU_Apr_Oct` |
| Output files | `NN_description.RData` | `03_features.RData` |
| Constants | `UPPER_SNAKE` | `HEAT_THRESHOLD_C`, `ANALYTE_NAMES` |

## Key Parameters

| Parameter | Value | Location |
|---|---|---|
| GDD base temp | 10 °C | `02_gdd_phenology.R` L63 |
| GDD start date | March 1 | `02_gdd_phenology.R` L61 |
| Heat threshold | 38 °C | `R/utils/heat_utils.R` L8 |
| Min heatwave days | 2 | `R/utils/heat_utils.R` L64 |
| HCA linkage | Ward.D2 | `04_hca_clustering.R` L59 |
| HCA distance | Euclidean | `04_hca_clustering.R` L58 |
| RF ntree | 500 | `05_random_forest_validation.R` L22 |
| RF mtry | sqrt(p) | `05_random_forest_validation.R` L23 |
| RF iterations | 50 | `05_random_forest_validation.R` L90 |

## Adding New Analyses

1. Create `NN_description.R` following the pattern:
   - `load("output/NN-1_previous.RData")` at top
   - Main logic with `cat()` section headers
   - `save(..., file = "output/NN_description.RData")` at bottom
2. Add to the `SCRIPTS` array in `run_complete_pipeline.sh`
3. Add target checks to `08_verification_report.R`
4. Update `docs/experiments.md` with expected outputs

## Using Utility Functions

To use the shared helpers in a script:

```r
source("R/utils/heat_utils.R")    # compute_generic(), compute_heatwave()
source("R/utils/log_utils.R")     # log_step()
source("R/utils/plot_theme.R")    # theme_paper, cluster_colours
```

Utility functions are **pure** — they do not modify global state or load data.
