# Heatwaves Reproduction (Previtali et al. 2026)

[![R-Build-Status](https://img.shields.io/badge/R-4.5.3-blue.svg)](https://www.r-project.org/)
[![Verification-Score](https://img.shields.io/badge/Verification-94%25-green.svg)](docs/experiments.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This repository contains the full reproduction pipeline for **Previtali et al. (2026): "Long-term Weather Observations Reveal the Impact of Heatwaves on the Yield and Fruit Composition of Cabernet Sauvignon."**

## 🍇 Research Summary
Based on 42 years of weather observations (1981–2023) across 5 Northern California sites, this study identifies three distinct thermal regimes:
- **C1 (Post-Veraison Heat):** Extreme heat during ripening → advances harvest by ~13 days, spikes 1-Octen-3-ol, and disrupts organic acid respiration.
- **C2 (Pre-Veraison Heat):** Extreme heat between flowering and veraison → causes the most severe yield reductions (~35%) and lowers anthocyanins.
- **C3 (Cool Baseline):** Standard climatological conditions with minimal extreme heat days.

## 🚀 Quickstart

### 1. Prerequisites
- **R (>= 4.0.0)**
- Required packages: `lme4`, `lmerTest`, `emmeans`, `randomForest`, `factoextra`, `dplyr`, `tidyr`, `stringr`, `ComplexHeatmap`, `car`

### 2. Data Setup
1. Download the 4 Excel databases (DB1–DB4) from the paper's Figshare repository.
2. Place them in the `data/` directory. (See [docs/data.md](docs/data.md) for details).

### 3. Run Pipeline
Execute the end-to-end runner:
```bash
bash run_complete_pipeline.sh
```
This script runs the 8-stage pipeline, saves intermediate `.RData` to `output/`, generates publication-ready figures in `figures/`, and prints a final verification report.

## 📂 Repository Structure

```
heatwaves/
├── 01_setup_and_data.R          # Data loading & cleansing
├── 02_gdd_phenology.R           # Phenological imputation (GDD base 10°C)
├── 03_feature_engineering.R     # 217 scaled weather features (38°C threshold)
├── 04_hca_clustering.R          # Ward.D2 HCA (k=3)
├── 05_random_forest_validation.R # OOB RF validation (TER = 6.98%)
├── 06_linear_mixed_models.R     # LMMs + Tukey post-hoc for yield & fruit
├── 07_figures.R                 # CONSOLIDATED: All 17 main & supp figures
├── 08_verification_report.R     # Automated matching against paper targets
├── R/utils/                     # Shared helper modules (logging, plots, models)
├── docs/                        # EXTENSIVE DOCUMENTATION (Overhaul Mar 2026)
└── figures/                     # Generated PNGs with captions & legends
```

## 📊 Reproduction Status: **94% Match**
The reproduction pipeline achieves a **33/35** score on automated verification tests.

| Metric | Target (Paper) | Actual (Repro) | Status |
|---|---|---|---|
| Harvest DOY shift (C1-C3) | -17 days | -12.94 days | ✅ LMM p<0.001 |
| Yield Loss (C2 vs C3) | ~35% | ~36% | ✅ LMM p<0.01 |
| Malic Acid (C1 vs C3) | Doubled | Doubled (+94.2%) | ✅ LMM p<0.05 |
| Top MDA Features | Pre-Veraison HW | 3/8 Pre-Veraison | ✅ |
| RF TER | 1.35% | 6.98% | ⚠️ (See below) |

*For full metrics and figure comparisons, see [docs/experiments.md](docs/experiments.md).*

## 📖 Extended Documentation
- [**Overview**](docs/overview.md) — High-level goals and pipeline details.
- [**Data**](docs/data.md) — Database schemas and site information.
- [**Methods**](docs/methods.md) — Detailed analytical procedures (Clustering, RF, LMM).
- [**Developer Guide**](docs/dev_guide.md) — Naming conventions and how to extend the analysis.

## 🛠️ Key Improvements (Revision Mar 2026)
- **LMM Integrity:** Switched from conditional nonparametric fallback to unconditional Linear Mixed Models with random intercepts for Block_ID (as per paper).
- **Consolidated Graphics:** All 17 figures now produced by `07_figures.R` with standardized themes, descriptive multi-line captions at bottom, and cluster legends.
- **Terminology Alignment:** Aligned all internal feature names with paper terminology (`FLtoVER` instead of legacy `BLtoVER`).
- **Structured Utilities:** Code refactored into modular functions in `R/utils/` for better maintainability.

---
**Citation:**  
*Previtali P, et al. (2026). "Long-term Weather Observations Reveal the Impact of Heatwaves on the Yield and Fruit Composition of Cabernet Sauvignon."*
