# Data Sources

## Figshare Databases

| DB | File | Rows | Key Columns | Coverage |
|---|---|---|---|---|
| DB1 | `DB1_PRISM_Weather_Daily_1981_2023.xlsx` | 78,525 | Site, date, tmin, tmean, tmax, rain, vpdmin, vpdmax | 5 sites × 43 years |
| DB2 | `DB2_Phenology.xlsx` | 2,063 | Site, Block_ID, Season, Budbreak, Flowering, Veraison, Harvest | 2002–2023, block-level |
| DB3 | `DB3_Yield_Harvest_date.xlsx` | 1,441 | Site, Block_ID, Season, Avg_Harvest_DOY, Yield_tha | Block-year level |
| DB4 | `DB4_Fruit_composition.xlsx` | 752 | Site, Block_ID, Season, 12 analytes (see below) | 2017–2023, block-level |

**How to obtain:** Download all 4 files from the paper's Figshare repository and place in `data/`.

## Site Information (Table 1)

| Site | AVA | Lat | Lon | Elevation (m) | Blocks |
|---|---|---|---|---|---|
| S1 | Napa Valley | 38.638 | -122.450 | 340 | 30 |
| S2 | Moon Mountain | 38.333 | -122.467 | 280 | 56 |
| S3 | Atlas Peak | 38.450 | -122.300 | 455 | 218 |
| S4 | Napa Valley | 38.642 | -122.454 | 340 | 18 |
| S5 | Napa Valley | 38.350 | -122.267 | 114 | 33 |

> **Note:** S1 and S4 share reported GPS coordinates (likely rounding). DB1 confirms distinct weather series.

## DB4 Fruit Composition Analytes

| Analyte | Unit | Measurement |
|---|---|---|
| β-Damascenone | µg/L | GC-MS |
| 1-Octen-3-ol | µg/L | GC-MS |
| C6 compounds | µg/L | GC-MS |
| IBMP | ng/L | GC-MS |
| Total anthocyanins | mg/g | HPLC |
| Polymeric tannins | mg/L | HPLC |
| Quercetin glycosides | mg/L | HPLC |
| TSS | °Brix | FT-IR |
| Berry moisture | % | FT-IR |
| pH | — | FT-IR |
| Malic acid | mg/L | FT-IR |
| YAN | mg/L | FT-IR |

## Preprocessing

- **DB1:** `date` cast to `Date` type.
- **DB2:** Phenological date columns cast to `Date`; DOY computed via `yday()`.
- **DB4:** Column names sanitized — Unicode β removed, line breaks stripped (see `R/utils/model_utils.R:sanitize_fruit_columns()`).

## Filters

- **Block area stability:** Blocks with yield CV > 100% flagged for manual inspection (1 block: S3/C85).
- **LMM eligibility:** Blocks with ≥ 2 observations across ≥ 2 clusters → 187 of 192 blocks.
