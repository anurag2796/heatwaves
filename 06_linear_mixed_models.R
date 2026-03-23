###############################################################################
# 06_linear_mixed_models.R
# Reproduction of Previtali et al. (2026)
# Section 7: Linear Mixed Models for Impact Assessment
###############################################################################

load("output/01_data_loaded.RData")
load("output/02_phenology.RData")
load("output/04_clusters.RData")

suppressPackageStartupMessages({
  library(dplyr)
  library(lme4)
  library(lmerTest)
  library(emmeans)
  library(car)
})

cat("=== Section 7: Linear Mixed Models ===\n\n")

# --- LIMITATION: Unmeasured management confounders -------------------------
# Irrigation, canopy management, and fruit thinning vary by block and year
# and are absent from the dataset. The LMM random intercept partially absorbs
# baseline block differences but cannot remove within-block year-to-year
# management variation.

# --- 7a. Data attribution: merge cluster labels into block-level data ------

# cluster_assignments has: site_year, Site, Season, cluster
# DB3 has: Site, Block_ID, Season, Avg_Harvest_DOY, Yield_tha

# Merge cluster into yield/harvest data
yield_data <- db3_data %>%
  left_join(cluster_assignments %>% select(Site, Season, cluster),
            by = c("Site", "Season")) %>%
  filter(!is.na(cluster))

cat("Yield data with cluster labels:", nrow(yield_data), "block-year observations\n")

# Filter: only blocks with >= 2 observations across >= 2 different clusters
block_eligibility <- yield_data %>%
  filter(!is.na(Yield_tha) | !is.na(Avg_Harvest_DOY)) %>%
  group_by(Site, Block_ID) %>%
  summarise(
    n_obs = n(),
    n_clusters = n_distinct(cluster),
    .groups = "drop"
  ) %>%
  filter(n_obs >= 2, n_clusters >= 2)

cat("Eligible blocks (>= 2 obs, >= 2 clusters):", nrow(block_eligibility), "\n")

yield_filtered <- yield_data %>%
  semi_join(block_eligibility, by = c("Site", "Block_ID"))

cat("Filtered observations:", nrow(yield_filtered), "\n\n")

# Merge cluster into fruit composition data
comp_data <- db4_data %>%
  left_join(cluster_assignments %>% select(Site, Season, cluster),
            by = c("Site", "Season")) %>%
  filter(!is.na(cluster))

# LIMITATION: Small biochemical sample — DB4 spans only 2017-2023 (7 seasons).
# All 12-analyte LMMs rest on far fewer observations than the 42-year yield
# and harvest analyses. Report with proportionally wider confidence intervals.
cat("Fruit composition data with cluster labels:", nrow(comp_data), "obs\n")
cat("LIMITATION: Small biochemical sample (2017-2023 only, 7 seasons)\n\n")

# --- 7b. Helper function: run LMM with assumption checks -------------------

run_lmm_with_checks <- function(response_var, data, formula_str = NULL) {
  # response_var: column name (string)
  # Returns list with model results, assumption tests, post-hoc

  cat(sprintf("\n--- LMM: %s ---\n", response_var))

  # Prepare data — drop NA for this response
  df <- data %>%
    filter(!is.na(.data[[response_var]])) %>%
    mutate(
      cluster  = factor(cluster, levels = c("C3", "C1", "C2")),  # C3 as reference
      block_ID = factor(paste(Site, Block_ID, sep = "_"))
    )

  cat(sprintf("  Observations: %d, Blocks: %d\n", nrow(df), n_distinct(df$block_ID)))
  cat(sprintf("  Per cluster: C1=%d, C2=%d, C3=%d\n",
              sum(df$cluster == "C1"), sum(df$cluster == "C2"), sum(df$cluster == "C3")))

  # Check if enough data
  if (nrow(df) < 10 || n_distinct(df$cluster) < 2) {
    cat("  SKIPPED: insufficient data\n")
    return(NULL)
  }

  # Try LMM first
  use_parametric <- TRUE

  tryCatch({
    model <- lmer(as.formula(paste(response_var, "~ cluster + (1 | block_ID)")),
                  data = df)

    # Assumption tests
    resids <- residuals(model)

    # Shapiro-Wilk (normality) — sample max 5000
    if (length(resids) > 5000) {
      shap_test <- shapiro.test(sample(resids, 5000))
    } else {
      shap_test <- shapiro.test(resids)
    }
    cat(sprintf("  Shapiro-Wilk: W=%.4f, p=%.4f", shap_test$statistic, shap_test$p.value))

    # Levene's test (homoscedasticity)
    lev_test <- leveneTest(as.formula(paste(response_var, "~ cluster")), data = df)
    lev_p <- lev_test$`Pr(>F)`[1]
    cat(sprintf("  |  Levene: F=%.2f, p=%.4f\n", lev_test$`F value`[1], lev_p))

    if (shap_test$p.value < 0.05 || lev_p < 0.05) {
      cat("  => Assumptions VIOLATED. Switching to nonparametric.\n")
      use_parametric <- FALSE
    } else {
      cat("  => Assumptions MET. Using LMM.\n")
    }
  }, error = function(e) {
    cat(sprintf("  LMM failed: %s\n", e$message))
    cat("  => Switching to nonparametric.\n")
    use_parametric <<- FALSE
  })

  results <- list(
    variable = response_var,
    parametric = use_parametric,
    means = tapply(df[[response_var]], df$cluster, mean, na.rm = TRUE)
  )

  if (use_parametric) {
    model <- lmer(as.formula(paste(response_var, "~ cluster + (1 | block_ID)")),
                  data = df)
    results$model_summary <- summary(model)

    # Tukey post-hoc
    emm <- emmeans(model, pairwise ~ cluster, adjust = "tukey")
    results$emmeans <- emm
    cat("\n  Estimated marginal means:\n")
    print(summary(emm$emmeans))
    cat("\n  Pairwise comparisons:\n")
    print(summary(emm$contrasts))
  } else {
    # Kruskal-Wallis + pairwise Wilcoxon
    kw <- kruskal.test(as.formula(paste(response_var, "~ cluster")), data = df)
    cat(sprintf("  Kruskal-Wallis: chi-sq=%.2f, df=%d, p=%.4f\n",
                kw$statistic, kw$parameter, kw$p.value))
    results$kruskal <- kw

    if (kw$p.value < 0.05) {
      pw <- pairwise.wilcox.test(df[[response_var]], df$cluster, p.adjust.method = "BH")
      cat("  Pairwise Wilcoxon (BH-adjusted):\n")
      print(pw$p.value)
      results$pairwise <- pw
    }
  }

  # Group means
  cat("\n  Group means:\n")
  grp_means <- df %>%
    group_by(cluster) %>%
    summarise(
      mean = round(mean(.data[[response_var]], na.rm = TRUE), 3),
      sd = round(sd(.data[[response_var]], na.rm = TRUE), 3),
      n = n(),
      .groups = "drop"
    )
  print(as.data.frame(grp_means))
  results$group_means <- grp_means

  return(results)
}

# --- 7c. Harvest date LMM --------------------------------------------------

cat("==== Harvest Date Analysis ====\n")
harvest_results <- run_lmm_with_checks("Avg_Harvest_DOY", yield_filtered)

cat("\n  VERIFICATION TARGETS (Harvest DOY):\n")
cat("    C3 (Cool): 291 | C2 (PRE-V): 277 (-13d) | C1 (POST-V): 274 (-17d)\n")
cat("    C1 vs C2: p = 0.001\n")

# --- 7d. Yield LMM --------------------------------------------------------

cat("\n==== Yield Analysis ====\n")
yield_results <- run_lmm_with_checks("Yield_tha", yield_filtered)

cat("\n  VERIFICATION TARGETS (Yield):\n")
cat("    C3: 7.0 t/ha | C1: 5.5 (-22%) | C2: 5.0 (-30%)\n")
cat("    C1 vs C2: p = 0.010\n")

# --- 7e. Fruit composition LMMs (12 analytes) -----------------------------

cat("\n==== Fruit Composition Analysis (12 analytes) ====\n")

analyte_cols <- c("B_Damascenone", "Octen_3_ol", "C6_compounds", "IBMP",
                  "Total_anthocyanins", "Polymeric_tannins",
                  "Quercetin_glycosides", "TSS", "Berry_moisture",
                  "pH", "Malic_acid", "YAN")

# For comp_data, eligibility filtering is looser because of small sample
# We still require blocks appearing in >= 2 clusters where possible
comp_block_elig <- comp_data %>%
  group_by(Site, Block_ID) %>%
  summarise(n_obs = n(), n_clusters = n_distinct(cluster), .groups = "drop") %>%
  filter(n_obs >= 2, n_clusters >= 2)

comp_filtered <- comp_data %>%
  semi_join(comp_block_elig, by = c("Site", "Block_ID"))

# If filtering removes too many rows, use all comp_data
if (nrow(comp_filtered) < 20) {
  cat("  NOTE: Strict block eligibility yields too few obs (<20).\n")
  cat("        Using all composition data with cluster labels.\n")
  comp_filtered <- comp_data
}

composition_results <- list()
for (analyte in analyte_cols) {
  composition_results[[analyte]] <- run_lmm_with_checks(analyte, comp_filtered)
}

cat("\n\n  VERIFICATION TARGETS (Fruit Composition):\n")
cat("    TSS: C3=26.0, C2=26.0, C1=26.4 (C1 only significant)\n")
cat("    pH: C3=3.60, C2=3.60, C1=3.65 (C1 only significant)\n")
cat("    Malic acid: C3=1338, C2=1338, C1=1996 (C1 only)\n")
cat("    YAN: C3=124, C2=66, C1=94 (C2 worst)\n")
cat("    1-octen-3-ol: C3=17.1, C2=27.8, C1=50.2 (both sig)\n")
cat("    Berry moisture: NOT significant (p=0.299)\n")
cat("    C6 compounds: NOT significant (p=0.371)\n")

# --- 7f. Vine age sub-analysis --------------------------------------------

cat("\n==== Vine Age Sub-Analysis ====\n")

# We need vine age information. The paper splits blocks into:
#   young: 3-5 years, mature: >5 years
# This info may be derivable from DB2/DB3 based on first appearance year
# (proxy for planting year)

# Determine first observation year per block as proxy for planting year
block_first_year <- db3_data %>%
  group_by(Site, Block_ID) %>%
  summarise(first_year = min(Season, na.rm = TRUE), .groups = "drop")

yield_age <- yield_filtered %>%
  left_join(block_first_year, by = c("Site", "Block_ID")) %>%
  mutate(
    vine_age = Season - first_year,
    age_group = ifelse(vine_age <= 5, "Young (3-5yr)", "Mature (>5yr)")
  )

cat("Vine age distribution:\n")
print(table(yield_age$age_group))

# Run LMM separately for each age group
for (ag in c("Young (3-5yr)", "Mature (>5yr)")) {
  cat(sprintf("\n-- %s --\n", ag))
  df_age <- yield_age %>% filter(age_group == ag)
  if (nrow(df_age) >= 10) {
    run_lmm_with_checks("Yield_tha", df_age)
  } else {
    cat("  Insufficient observations for this age group.\n")
  }
}

cat("\n  VERIFICATION TARGETS (Vine Age):\n")
cat("    Young: C1 = C2 = ~5.4 t/ha; both below C3 (6.5 t/ha, p <= 0.001)\n")
cat("    Mature: C1=5.4, C2=4.9, C3=7.1; all sig different (p <= 0.029)\n")

# --- Save -------------------------------------------------------------------

save(yield_filtered, comp_filtered,
     harvest_results, yield_results, composition_results,
     yield_age,
     file = file.path(output_dir, "06_lmm_results.RData"))

cat("\n=== Section 7 Complete ===\n")
cat("Saved to:", file.path(output_dir, "06_lmm_results.RData"), "\n")
