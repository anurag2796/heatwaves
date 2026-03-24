# Heatwaves Reproduction

Reproduction of Previtali et al. (2026) *"Long-term Weather Observations Reveal the Impact of Heatwaves on the Yield and Fruit Composition of Cabernet Sauvignon."*

## Research Question

How do the timing and severity of heatwaves affect Cabernet Sauvignon yield and fruit composition across 42 years of data from 5 Northern California vineyard sites?

## Pipeline

```
01_setup_and_data.R      Load 4 Figshare databases, install packages
02_gdd_phenology.R       GDD (base 10°C, March 1), impute phenology
03_feature_engineering.R  220 weather features → scale → ~217 final
04_hca_clustering.R      Ward.D2 HCA → 3 clusters (POST-V, PRE-V, Cool)
05_random_forest.R       OOB RF validation (TER) + MDA feature importance
06_linear_mixed_models.R LMMs for yield, harvest date, 12 fruit analytes
07_figures.R             Reproduce paper Figures 2, 6, 7 + supplementals
08_verification_report.R Automated checks against paper targets
```

## Quickstart

```bash
# 1. Place raw Excel files in data/ (see docs/data.md)
# 2. Run end-to-end:
bash run_complete_pipeline.sh

# Output directories:
#   output/  — .RData files + logs
#   figures/ — publication-ready PNGs
# Verification: last section of output/complete_run.log
```

## Current Status

- **Verification:** 33/35 checks passing (94%)
- **Date:** 2026-03-24
- **Environment:** R 4.5.3, macOS aarch64

## Documentation

| File | Contents |
|---|---|
| [data.md](data.md) | Data sources, preprocessing, filters |
| [methods.md](methods.md) | GDD, features, clustering, RF, LMMs |
| [experiments.md](experiments.md) | Figure/table → script mapping |
| [dev_guide.md](dev_guide.md) | Structure, naming, how to extend |

## Known Limitations

1. **DB4 spans only 2017–2023** (7 seasons) — small biochemical sample
2. **Cluster sizes deviate ~17%** from paper — likely due to feature matrix differences
3. **OOB TER ~7%** vs paper's 1.35% — cascade from cluster size deviation
4. **Unmeasured confounders:** irrigation, canopy management, thinning not in data
5. **Single variety/region:** Cabernet Sauvignon, Northern California only

## Citation

Previtali P et al. (2026) "Long-term Weather Observations Reveal the Impact of Heatwaves on the Yield and Fruit Composition of Cabernet Sauvignon." [Heatwaves.pdf](../Heatwaves.pdf)
