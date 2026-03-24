# Limitations and Interpretation

## Purpose
Every model is an abstraction of reality. This section comprehensively lists the structural blind spots and methodological constraints inherent in both the original Previtali et al. (2026) study and this specific reproduction attempt.

## 1. Small Biochemical Sample Size
- **Scope:** While Database 3 (Yield and Harvest) covers 42 years of continuous harvest reports, Database 4 (Fruit Composition) is constrained entirely to 2017–2023 (7 seasons).
- **Consequence:** 752 block-year observations limit statistical power, forcing wide confidence intervals on rarer metabolites. Parametric conditions comprehensively failed, mandating weaker nonparametric tests.

## 2. Unmeasured Commercial Confounders
- **Scope:** The dataset is derived entirely from operational commercial vineyards, not isolated academic test plots.
- **Consequence:** Critical vineyard interventions—winter pruning severity, cover crop competition, canopy architecture, fruit thinning, and crucially, emergency irrigation schedules—were not recorded in the database. While the Linear Mixed Model's (LMM) random intercept statistically absorbs the block's baseline potential, it cannot absorb dynamic human interventions specific to one hot year. An "artificial" dampening of the heat signal may be present because commercial growers reflexively intervene to protect crops during known heatwaves.

## 3. Methodological: The Missing Random Seed
- **Scope:** Machine learning validation (Random Forest and Hierarchical Clustering optimization) relies on random start states.
- **Consequence:** The original manuscript failed to publish the precise Random Seed used for their models. The 1.35% Mean Topological Error Rate published simply cannot be exactly replicated; the `set.seed(42)` run generated a ~1.89% error rate. It remains mathematically indistinguishable whether this 0.5% variance gap represents algorithmic noise or a fundamental disparity in the feature architecture.

## 4. Climatic Resolution Limitations (PRISM)
- **Scope:** All daily weather figures derive from PRISM data interpolated on a 4km × 4km spatial grid.
- **Consequence:** Vineyard microclimates are notoriously granular. Elevation changes, specifically on terraced blocks or high-altitude sites like S3 (455m), feature vast intra-block temperature gradients that a 4km smoothing cell fundamentally obliterates.

## 5. Dehydration vs. Accumulation Ambiguity
- **Scope:** Total Soluble Solids (TSS) significantly spiked under C1 (POST-V) heat conditions.
- **Consequence:** Because destructive berry-weight sampling was not performed or supplied, there is no biological mechanism to prove whether this Brix inflation came from forced active sugar transport (accumulation) or sheer physical desiccation (concentration via water evaporation).

## 6. Single Cultivar / Single Appellation
- **Scope:** The entire study was locked exclusively to *Vitis vinifera* cv. Cabernet Sauvignon situated entirely within the Napa Valley AVA of Northern California.
- **Consequence:** Cabernet Sauvignon is a late-ripening, thick-skinned, heat-resilient varietal. The specific 38°C (100.4°F) damage thresholds and the 10°C Base GDD algorithms cannot be portably transferred to Pinot Noir, Chardonnay, or regions with radically different soil geologies without total recalibration.

## 7. Commercial Sampling Bias
- **Scope:** The analyte samples (Database 4) were extracted strictly from harvested commercial must intended for fermentation.
- **Consequence:** Professional picking crews visually identify and actively discard critically raisined, deeply sunburnt, or rotting clusters during the harvest haul. Therefore, the "C1" heat penalty recorded in the chemical tanks inherently represents a *best-case scenario* survivors-bias sample.

## Cross-references
- [00 Index](00_index.md)
- [01 Project Overview](01_project_overview.md)
