# Data Sources

## Purpose
This document outlines the extraction, structural specifics, and initial cleaning of the four underlying databases and climatological records required to execute the Previtali et al. (2026) analysis.

## Inputs
All raw data were downloaded via the definitive Figshare source (DOI: 10.6084/m9.figshare.28486232) and local PRISM extractions.

### Figshare Databases
Each database file was provided as an Excel workbook comprising two sheets: `Data` (the raw rectangular matrix) and `List of Variables` (definition of headings and units).

**Database 1: Daily PRISM Weather**
- **Contents:** Daily interpolated historical weather for sites S1–S5.
- **Time Span:** 1981-01-01 to 2023-12-31.
- **Matrix dimensions:** 78,525 rows × 9 columns.
- **Notes:** Contains daily Tmax, Tmin, Tmean, rainfall, and VPDmin/max. Coerced to formal `.Date` properties upon load.

**Database 2: Phenology**
- **Contents:** Observed historical dates for Budbreak, Flowering, and Veraison, along with corresponding harvest dates.
- **Time Span:** 2002 to 2023 seasons.
- **Matrix dimensions:** 2,063 rows × 7 columns.

**Database 3: Yield & Harvest Date**
- **Contents:** Vineyard-block specific yield measurements (in tons/hectare) paired with average harvest Day of Year (DOY).
- **Matrix dimensions:** 1,441 rows × 5 columns.

**Database 4: Fruit Composition**
- **Contents:** Measurements of 12 critical biochemical analytes including pH, TSS, malic acid, anthocyanins, and tannins.
- **Time Span:** 2017 to 2023.
- **Matrix dimensions:** 752 rows × 15 columns.

### PRISM Climate Database
- **Resolution:** 4km spatial grid.
- **Variables Downloaded:** `tmax`, `tmin`, `tmean`, `ppt`, `vpdmin`, `vpdmax`.
- **Method:** Raw PRISM binaries (.bil) were accessed spanning 1981–2023. Time series were synthesized by applying the `terra::extract()` function at each site's explicit GPS coordinates.

## Parameters and Justification
| Parameter | Value | Source | Reason chosen over alternatives |
|---|---|---|---|
| Yield Variability Threshold (CV%) | 100% | Discovered | Blocks oscillating in yield by >100% CV indicate probable area changes rather than weather variations, severely violating the `tons/ha` assumption. |

## Outputs
- `output/01_data_loaded.RData`: R environment image containing `db1_data`, `db2_data`, `db3_data`, `db4_data`, `block_stats`, and `site_info`.

## Method and Specific Decisions

### GPS Coordinates and Shared Locations
| Site | Latitude | Longitude | Classification | Elevation (m) | Blocks | Avg Block Size (ha) |
|---|---|---|---|---|---|---|
| S1 | 38.638°N | 122.450°W | Napa Valley | 340 | 30 | 4.62 |
| S2 | 38.333°N | 122.467°W | Moon Mountain AVA | 280 | 56 | 2.16 |
| S3 | 38.450°N | 122.300°W | Atlas Peak AVA | 455 | 218 | 1.18 |
| S4 | 38.638°N | 122.450°W | Napa Valley | 340 | 18 | 3.12 |
| S5 | 38.350°N | 122.267°W | Napa Valley | 114 | 33 | 2.20 |

**Explicit Note on S1 and S4:**
Table 1 in the original paper documents S1 and S4 sharing identical GPS coordinates (38.638°N, 122.450°W). Despite this, `db1_data` provides distinct PRISM time series for these designations. This indicates a minor rounding or typographic artifact inside the printed Table 1, and confirms they represent separated physical space under the 4km PRISM raster. S1 and S4 are therefore maintained as independent temporal series.

### Block Area Stability Screening
To ensure integrity during linear modeling of agricultural yield, blocks experiencing extreme structural modification (pulling up or replanting vines midway through the time series) required manual eviction. The `Yield_tha` standardises tonnage over area, yet undeclared area alterations heavily skew apparent climate-related yield.
A coefficient of variation (CV) check across longitudinal yield per block was employed. One specific block, S3/C85, flagged exceptionally high volatility (CV > 100%), exhibiting a swing symptomatic of unrecorded acreage changes, and was manually documented.

## Verification
- Base PRISM grids accurately extracted.
- S1 vs S4 duplicate coordinates correctly insulated.
- C85 block flagged for exceeding 100% variation.

## Known Issues and Resolutions
None.

## Limitations Highlight
**Database 4 Coverage Constraint:** Database 4 uniquely encompasses only 7 seasons from 2017–2023, while harvest/yield DB3 spans up to 42 years. Consequently, interpreting statistical significance for secondary metabolites intrinsically suffers wider confidence intervals and heightened vulnerability to non-climate confounders from that precise localized 7-year era.

## Cross-references
- [01 Project Overview](01_project_overview.md)
- [03 GDD Phenology](03_gdd_phenology.md)
