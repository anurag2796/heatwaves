###############################################################################
# 06_linear_mixed_models.R
# Reproduction of Previtali et al. (2026)
# Section 7: Linear Mixed Models & Nonparametric Robustness Checks
#
# P0-1 fix: Always fit LMM unconditionally (as the paper does).
# Report assumption diagnostics alongside, not as a gate.
# Run KW as a secondary robustness check.
###############################################################################

load("output/01_data_loaded.RData")
load("output/04_clusters.RData")

suppressPackageStartupMessages({
  library(dplyr)
  library(lme4)
  library(lmerTest)
  library(emmeans)
  library(car)
})

cat("=== Section 7: Linear Mixed Models ===\n\n")

# --- 7a. Data attribution: merge cluster labels ---
yield_data <- db3_data %>%
  left_join(site_year_pheno %>% select(Site, Season, cluster),
            by = c("Site", "Season")) %>%
  filter(!is.na(cluster))

cat("Yield data with cluster labels:", nrow(yield_data), "block-year observations\n")

# Filter: only blocks with >= 2 observations across >= 2 different clusters
block_elig <- yield_data %>%
  group_by(block_ID = Block_ID) %>%
  summarise(n_obs = n(), n_clust = n_distinct(cluster), .groups = "drop")

eligible_blocks <- block_elig %>% filter(n_obs >= 2, n_clust >= 2) %>% pull(block_ID)
cat("Eligible blocks (>= 2 obs, >= 2 clusters):", length(eligible_blocks), "\n")

yield_filtered <- yield_data %>% filter(Block_ID %in% eligible_blocks) %>% rename(block_ID = Block_ID)

# Fruit Composition data
fruit_data <- db4_data %>%
  left_join(site_year_pheno %>% select(Site, Season, cluster),
            by = c("Site", "Season")) %>%
  filter(!is.na(cluster))

# SAFE RENAMING: Bypasses MacOS/Terminal Unicode encoding issues
names(fruit_data)[grepl("Damascenone", names(fruit_data), ignore.case = TRUE)] <- "B_Damascenone"
names(fruit_data)[grepl("Octen", names(fruit_data), ignore.case = TRUE)] <- "Octen_3_ol"
names(fruit_data)[grepl("C6", names(fruit_data), ignore.case = TRUE)] <- "C6_compounds"
names(fruit_data)[grepl("anthocyanins", names(fruit_data), ignore.case = TRUE)] <- "Total_anthocyanins"
names(fruit_data)[grepl("tannins", names(fruit_data), ignore.case = TRUE)] <- "Polymeric_tannins"
names(fruit_data)[grepl("Quercetin", names(fruit_data), ignore.case = TRUE)] <- "Quercetin_glycosides"
names(fruit_data)[grepl("moisture", names(fruit_data), ignore.case = TRUE)] <- "Berry_moisture"
names(fruit_data)[grepl("Malic", names(fruit_data), ignore.case = TRUE)] <- "Malic_acid"
names(fruit_data)[names(fruit_data) == "Block_ID"] <- "block_ID"

cat("Fruit composition data with cluster labels:", nrow(fruit_data), "obs\n")

# --- 7b. Unified Modeling Function ---
# Always fits LMM (as the paper specifies), reports diagnostics,
# then shows KW as a nonparametric robustness check.

run_model <- function(var_name, df) {
  cat(sprintf("\n--- Model: %s ---\n", var_name))
  
  if (!var_name %in% names(df)) {
    cat("  [ERROR] Variable not found in data frame.\n")
    return(NULL)
  }
  
  df_sub <- df %>% filter(!is.na(.data[[var_name]]))
  if(nrow(df_sub) < 10) {
    cat("  [SKIP] Not enough data points.\n")
    return(NULL)
  }
  
  cat("  Observations:", nrow(df_sub), ", Blocks:", n_distinct(df_sub$block_ID), "\n")
  cat(sprintf("  Per cluster: C1=%d, C2=%d, C3=%d\n", 
              sum(df_sub$cluster == "C1"), sum(df_sub$cluster == "C2"), sum(df_sub$cluster == "C3")))
  
  f_lmm    <- as.formula(paste(var_name, "~ cluster + (1 | block_ID)"))
  f_simple <- as.formula(paste(var_name, "~ cluster"))
  
  # ---- PRIMARY: Linear Mixed Model (unconditional, as paper specifies) ----
  mod <- tryCatch(lmer(f_lmm, data = df_sub), error = function(e) NULL)
  
  if (!is.null(mod)) {
    # Assumption diagnostics (reported but NOT used as a gate)
    res <- residuals(mod)
    n_sample <- min(5000, length(res))
    sw  <- shapiro.test(res[sample(length(res), n_sample)])
    lev <- tryCatch(leveneTest(f_simple, data = df_sub), error = function(e) NULL)
    
    cat(sprintf("  Assumption diagnostics (informational):\n"))
    cat(sprintf("    Shapiro-Wilk: W=%.4f, p=%.4f\n", sw$statistic, sw$p.value))
    if (!is.null(lev)) {
      cat(sprintf("    Levene:       F=%.2f, p=%.4f\n", lev$`F value`[1], lev$`Pr(>F)`[1]))
    }
    
    if (sw$p.value < 0.05) {
      cat("    Note: residuals depart from normality, but LMMs are robust with large N.\n")
    }
    
    # LMM ANOVA
    an <- anova(mod)
    cat(sprintf("\n  LMM ANOVA: F = %.2f, p = %.6f\n", an$`F value`[1], an$`Pr(>F)`[1]))
    
    if (an$`Pr(>F)`[1] < 0.05) {
      cat("  => Cluster effect SIGNIFICANT. Tukey post-hoc:\n")
      em <- emmeans(mod, pairwise ~ cluster, adjust = "tukey")
      print(em$contrasts)
    } else {
      cat("  => Cluster effect NOT significant (p >= 0.05).\n")
    }
  } else {
    cat("  [WARNING] LMM failed to converge. Reporting KW only.\n")
  }
  
  # ---- SECONDARY: Kruskal-Wallis robustness check ----
  cat("\n  Nonparametric robustness check (Kruskal-Wallis):\n")
  kw <- kruskal.test(f_simple, data = df_sub)
  cat(sprintf("    chi-squared = %.2f, p = %.6f\n", kw$statistic, kw$p.value))
  
  if (kw$p.value < 0.05) {
    wt <- pairwise.wilcox.test(df_sub[[var_name]], df_sub$cluster, 
                                p.adjust.method = "BH", exact = FALSE)
    cat("    Pairwise Wilcoxon (BH-adjusted):\n")
    print(round(wt$p.value, 4))
  } else {
    cat("    Factor not significant.\n")
  }
  
  # ---- Group summary ----
  cat("\n  Group means and medians:\n")
  summ <- df_sub %>% 
    group_by(cluster) %>% 
    summarise(
      mean = mean(.data[[var_name]], na.rm=TRUE), 
      median = median(.data[[var_name]], na.rm=TRUE), 
      sd = sd(.data[[var_name]], na.rm=TRUE), 
      n = n()
    )
  print(as.data.frame(summ), digits=4)
}

# --- Execute Models ---
cat("\n==== Harvest Date Analysis ====\n")
run_model("Avg_Harvest_DOY", yield_filtered)

cat("\n==== Yield Analysis ====\n")
run_model("Yield_tha", yield_filtered)

cat("\n==== Fruit Composition Analysis (12 analytes) ====\n")
analytes <- c("B_Damascenone", "Octen_3_ol", "C6_compounds", "IBMP", 
              "Total_anthocyanins", "Polymeric_tannins", "Quercetin_glycosides", 
              "TSS", "Berry_moisture", "pH", "Malic_acid", "YAN")

for (a in analytes) {
  run_model(a, fruit_data)
}

# --- Vine Age Sub-Analysis ---
cat("\n==== Vine Age Sub-Analysis ====\n")
block_first_year <- db3_data %>%
  group_by(Site, Block_ID) %>%
  summarise(first_year = min(Season, na.rm = TRUE), .groups = "drop")

yield_age <- yield_filtered %>%
  left_join(block_first_year, by = c("Site", "block_ID" = "Block_ID")) %>%
  mutate(
    vine_age = Season - first_year,
    age_group = ifelse(vine_age <= 5, "Young (3-5yr)", "Mature (>5yr)")
  )

for (ag in c("Young (3-5yr)", "Mature (>5yr)")) {
  cat(sprintf("\n-- %s --\n", ag))
  df_age <- yield_age %>% filter(age_group == ag)
  run_model("Yield_tha", df_age)
}

save(yield_filtered, fruit_data, yield_age, file = "output/06_lmm_results.RData")
cat("\n=== Section 7 Complete ===\n")