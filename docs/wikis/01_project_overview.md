# Project Overview

## Purpose
This page provides a high-level summary of the entire reproduction effort for Previtali et al. (2026), detailing the original paper's citation, the core research question, the overarching analytical workflow, and the key findings targeted for reproduction.

## Paper Details
**Citation:** Previtali P, Giorgini F, Sanchez LA, Dokoozlian NK. *Long-term Weather Observations Reveal the Impact of Heatwaves on the Yield and Fruit Composition of Cabernet Sauvignon*. Am J Enol Vitic. 77:0770001.  
**DOI:** 10.5344/ajev.2025.25017  
**Figshare Data DOI:** https://doi.org/10.6084/m9.figshare.28486232

## Research Question
The paper aims to quantify the discrete impact of severe heatwaves on the yield, harvest timing, and resulting fruit composition of commercially grown Cabernet Sauvignon. Specifically, it asks whether the timing of heat extremes relative to vine phenology (e.g., pre-veraison vs. post-veraison) causes fundamentally different agricultural and biochemical penalties compared to normal or cool growing years.

## Analytical Workflow
The reproduction workflow precisely mirrors Figure 1 of the paper and flows sequentially through the following steps:
1. **Data Inputs:** Aggregation of four distinct databases combining 42 years of PRISM climatological data, phenological records (budbreak, flowering, veraison, harvest), yield, and 12-analyte fruit composition profiles.
2. **Feature Engineering:** Calculation of extreme heat indices and translation of calendar-based weather data into dynamic, phenologically grounded features (e.g., thermal accumulations from Flowering to Veraison).
3. **Clustering:** Unsupervised Ward's hierarchical clustering (HCA) of scaled features to parse 213 unique site-years into three distinct thermal regimes: POST-V heat, PRE-V heat, and Cool baselines.
4. **RF Validation:** Robust Bootstrap Random Forest classification to validate cluster reliability via the Topological Error Rate (TER), and to extract Mean Decrease Accuracy (MDA) rankings proving the superiority of phenological heat intervals.
5. **Linear Mixed Models (LMMs):** Application of mixed-effects modeling to robustly infer differences in harvest dates, yield, and secondary metabolites between the three thermal regimes, controlling for baseline block-level variation.
6. **Figures:** Generation of publication-quality geospatial, PCA, and comparative results visualizations.

## Key Findings Reproduced
The objective is to computationally verify the five central discoveries of the original paper:
1. **Cluster Sizes:** That unsupervised analysis robustly partitions the dataset into three stable, non-overlapping regimes (C1: POST-V heat, C2: PRE-V heat, C3: Cool).
2. **Topological Error Rate (TER):** That the feature subset strictly defines the thermal regimes with high predictive accuracy (TER < 2%).
3. **Harvest Date Advancement:** That PRE-V heat (C2) advances harvest by ~13 days and POST-V heat (C1) by ~17 days compared to cool baselines (C3).
4. **Yield Penalties:** That extreme heat significantly penalizes yield, with PRE-V heat (C2) causing the steepest losses (-30%) and POST-V heat (C1) causing -22% losses relative to C3.
5. **Fruit Composition Shifts:** That elevated heat profoundly limits flavor precursors (e.g., YAN dropping severely in C2) and dramatically alters acid profiles, with C1 distinctively elevating malic acid and TSS concentrations, ostensibly via dehydration effects.

## Cross-references
- [00 Index](00_index.md)
- [02 Data Sources](02_data_sources.md)
