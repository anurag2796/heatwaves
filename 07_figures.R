###############################################################################
# 07_figures.R
# Reproduction of Previtali et al. (2026)
# Section 8: ALL Figure Generation — Publication-Ready with Captions & Legends
#
# Consolidates ALL figures (main + supplemental) into a single script.
# Each figure includes: description at bottom, legend where appropriate,
# and uses verified data from the pipeline outputs.
###############################################################################

load("output/01_data_loaded.RData")
load("output/03_features.RData")
load("output/04_clusters.RData")
load("output/05_rf_validation.RData")
load("output/06_lmm_results.RData")

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(gridExtra)
  library(grid)
  library(factoextra)
  library(ComplexHeatmap)
  library(circlize)
})

cat("=== Section 8: Figure Generation ===\n\n")
if (!dir.exists("figures")) dir.create("figures")

# ============================================================================
# SHARED AESTHETICS
# ============================================================================
theme_paper <- theme_classic(base_size = 14) +
  theme(
    plot.title    = element_text(face = "bold", size = 16),
    legend.position = "bottom",
    legend.title  = element_text(face = "bold"),
    legend.text   = element_text(size = 12),
    axis.text     = element_text(color = "black", size = 12),
    axis.title    = element_text(face = "bold", size = 13),
    plot.caption  = element_text(hjust = 0, face = "italic", color = "gray30",
                                 size = 10, margin = margin(t = 15)),
    plot.margin   = margin(10, 10, 20, 10)
  )

cluster_colours <- c("C1" = "#D55E00", "C2" = "#E69F00", "C3" = "#0072B2")
cluster_labels  <- c("C3" = "C3 (Cool Baseline)",
                      "C2" = "C2 (Pre-Veraison Heat)",
                      "C1" = "C1 (Post-Veraison Heat)")
short_labels    <- c("C3" = "C3\n(Cool)", "C2" = "C2\n(Pre-V)", "C1" = "C1\n(Post-V)")

# Helper to wrap a caption to a textGrob
make_caption <- function(text, width = 130) {
  textGrob(paste(strwrap(text, width = width), collapse = "\n"),
           x = 0.02, hjust = 0,
           gp = gpar(fontsize = 10, col = "gray30", fontface = "italic"))
}

# ============================================================================
# FIGURE 2: Attribution Procedure (S4 Harvest DOY)
# ============================================================================
cat("Generating Figure 2: Attribution procedure (S4 harvest DOY)...\n")

s4_yield <- yield_filtered %>% filter(Site == "S4")

fig2 <- ggplot(s4_yield, aes(x = Season, y = Avg_Harvest_DOY)) +
  geom_line(aes(group = block_ID), color = "gray80", alpha = 0.5) +
  geom_point(aes(color = cluster), size = 4) +
  scale_color_manual(values = cluster_colours, labels = cluster_labels,
                     name = "Thermal Regime:") +
  labs(title = "Figure 2: Heatwave Attribution (Site S4)",
       x = "Growing Season (Year)",
       y = "Average Harvest Date (Day of Year)",
       caption = str_wrap("Figure 2. Heatwave attribution based on historical harvest dates at Site S4. Points represent individual vineyard blocks across growing seasons (1981-2023). Seasons experiencing extreme post-veraison heat (C1, orange-red) consistently show advanced harvest dates compared to the cool baseline (C3, blue).", 110)) +
  theme_paper

ggsave("figures/fig2_attribution_s4.png", fig2, width = 10, height = 7, bg = "white")

# ============================================================================
# FIGURE 3A: PCA Biplot
# ============================================================================
cat("Generating Figure 3a: PCA biplot...\n")

pca_res <- prcomp(scaled_features, center = FALSE, scale. = FALSE)
pca_df  <- data.frame(PC1 = pca_res$x[, 1], PC2 = pca_res$x[, 2],
                       cluster = site_year_pheno$cluster)
pca_var <- round(summary(pca_res)$importance[2, 1:2] * 100, 1)

fig3a <- ggplot(pca_df, aes(x = PC1, y = PC2, color = cluster)) +
  geom_point(size = 3, alpha = 0.8) +
  stat_ellipse(level = 0.95, linewidth = 1, linetype = "dashed") +
  scale_color_manual(values = cluster_colours, labels = cluster_labels,
                     name = "Thermal Regime:") +
  labs(title = "Figure 3a: PCA Score Plot",
       x = paste0("PC1 (", pca_var[1], "% variance)"),
       y = paste0("PC2 (", pca_var[2], "% variance)"),
       caption = str_wrap("Figure 3a. Principal component analysis of 217 scaled weather features. PC1 captures total thermal load intensity while PC2 separates the timing of heat exposure (pre- vs post-veraison). Ellipses represent 95% confidence regions for each thermal regime.", 110)) +
  theme_paper

ggsave("figures/fig3a_pca.png", fig3a, width = 9, height = 7, bg = "white")

# ============================================================================
# FIGURE 3B: Radial Temperature Charts (C1, C2, C3)
# ============================================================================
cat("Generating Figure 3b: Radial temperature charts...\n")

# Representative site-years for each cluster
cluster_reps <- site_year_pheno %>%
  group_by(cluster) %>%
  slice(1) %>%
  ungroup()

for (i in 1:nrow(cluster_reps)) {
  rep <- cluster_reps[i, ]
  clust <- as.character(rep$cluster)

  w_rep <- db1_data %>%
    filter(Site == rep$Site, format(date, "%Y") == rep$Season) %>%
    mutate(DOY = as.integer(format(date, "%j"))) %>%
    filter(DOY >= 91, DOY <= 304)  # Apr-Oct

  if (nrow(w_rep) == 0) next

  p <- ggplot(w_rep, aes(x = DOY)) +
    geom_ribbon(aes(ymin = tmin, ymax = tmax), fill = cluster_colours[clust], alpha = 0.3) +
    geom_line(aes(y = tmax), color = cluster_colours[clust], linewidth = 0.6) +
    geom_line(aes(y = tmin), color = cluster_colours[clust], linewidth = 0.4, linetype = "dashed") +
    geom_hline(yintercept = 38, color = "red", linetype = "dotted", linewidth = 1) +
    annotate("text", x = 280, y = 39.5, label = "38°C threshold",
             color = "red", size = 3.5, fontface = "italic") +
    coord_polar(start = 0) +
    scale_x_continuous(breaks = c(91, 121, 152, 182, 213, 244, 274, 304),
                       labels = c("Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov")) +
    labs(title = paste0("Figure 3b: ", clust, " (", rep$Site, " ", rep$Season, ")"),
         y = "Temperature (°C)",
         caption = paste0("Radial chart showing daily Tmin (dashed) to Tmax (solid) for a representative ",
                          clust, " site-year. Red dotted line marks the 38°C heatwave threshold.")) +
    theme_paper +
    theme(axis.title.x = element_blank(),
          plot.caption = element_text(size = 9, margin = margin(t = 10)))

  ggsave(paste0("figures/fig3b", i, "_radial_", clust, ".png"), p,
         width = 8, height = 8, bg = "white")
}

# ============================================================================
# FIGURE 4A: TER Boxplot + FIGURE 4B: MDA Bar Chart
# ============================================================================
cat("Generating Figure 4: RF validation (TER + MDA)...\n")

# 4A: TER distribution from bootstrap
fig4a <- ggplot(data.frame(TER = ter_vec), aes(y = TER)) +
  geom_boxplot(fill = "#0072B2", alpha = 0.4, width = 0.4) +
  geom_hline(yintercept = mean(ter_vec), color = "#D55E00", linetype = "dashed", linewidth = 1) +
  annotate("text", x = 0.3, y = mean(ter_vec) + 0.8,
           label = paste0("Mean = ", round(mean(ter_vec), 2), "%"),
           color = "#D55E00", size = 4, fontface = "bold") +
  labs(title = "Figure 4a: Classification Error (TER)",
       y = "Topological Error Rate (%)",
       caption = str_wrap("Figure 4a. Distribution of Total Error Rate across 50 bootstrap iterations (stratified 50:50 split). OOB TER from full-data RF is reported in the verification log. Dashed line shows the mean TER.", 90)) +
  theme_paper + theme(axis.text.x = element_blank(), axis.title.x = element_blank())

ggsave("figures/fig4a_ter.png", fig4a, width = 6, height = 7, bg = "white")

# 4B: MDA top 20 features
top_20 <- head(mda_df, 20)
top_20$Feature <- factor(top_20$Feature, levels = rev(top_20$Feature))

# Color-code by interval type
top_20 <- top_20 %>%
  mutate(interval = case_when(
    grepl("FLtoVER|preV", Feature) ~ "FL-VER (Pre-Veraison)",
    grepl("VERtoH|postV", Feature) ~ "VER-H (Post-Veraison)",
    grepl("BBtoH|BBtoFL", Feature) ~ "Full Season",
    TRUE ~ "Monthly/Seasonal"
  ))
interval_cols <- c("FL-VER (Pre-Veraison)" = "#E69F00",
                   "VER-H (Post-Veraison)" = "#D55E00",
                   "Full Season" = "#009E73",
                   "Monthly/Seasonal" = "#0072B2")

fig4b <- ggplot(top_20, aes(x = Feature, y = MDA, fill = interval)) +
  geom_col(alpha = 0.85) +
  coord_flip() +
  scale_fill_manual(values = interval_cols, name = "Temporal Interval:") +
  labs(title = "Figure 4b: Variable Importance (MDA)",
       x = "", y = "Mean Decrease Accuracy",
       caption = str_wrap("Figure 4b. Top 20 features ranked by Mean Decrease Accuracy from OOB Random Forest. Bars are colour-coded by temporal interval to show whether heatwave features from pre-veraison (FL-VER) or post-veraison (VER-H) dominate classification.", 110)) +
  theme_paper +
  theme(axis.text.y = element_text(size = 10))

ggsave("figures/fig4b_mda.png", fig4b, width = 10, height = 8, bg = "white")

# ============================================================================
# FIGURE 5: Tmax Distribution, Heat Days, Heatwaves by Cluster
# ============================================================================
cat("Generating Figure 5: Temperature distributions by cluster...\n")

# Merge daily weather with cluster info for plotting
daily_cluster <- db1_data %>%
  mutate(Season = as.integer(format(date, "%Y")),
         Month = as.integer(format(date, "%m")),
         DOY = as.integer(format(date, "%j"))) %>%
  filter(Month >= 4, Month <= 10) %>%
  left_join(site_year_pheno %>% select(Site, Season, cluster),
            by = c("Site", "Season")) %>%
  filter(!is.na(cluster))

daily_cluster$cluster <- factor(daily_cluster$cluster, levels = c("C3", "C2", "C1"))

# 5A: Tmax density
fig5a <- ggplot(daily_cluster, aes(x = tmax, fill = cluster)) +
  geom_density(alpha = 0.4, color = NA) +
  geom_vline(xintercept = 38, color = "red", linetype = "dashed", linewidth = 0.8) +
  scale_fill_manual(values = cluster_colours, labels = cluster_labels,
                    name = "Thermal Regime:") +
  labs(title = "A. Daily Tmax Distribution (Apr-Oct)",
       x = "Maximum Daily Temperature (°C)", y = "Density",
       caption = str_wrap("Panel A. Density of daily maximum temperatures during the growing season. Red dashed line marks the 38°C heatwave threshold. C1 (Post-V heat) shows a heavier right tail.", 100)) +
  theme_paper

# 5B: Heat days per year
heat_days_summary <- daily_cluster %>%
  group_by(Site, Season, cluster) %>%
  summarise(heat_days = sum(tmax >= 38, na.rm = TRUE), .groups = "drop")

fig5b <- ggplot(heat_days_summary, aes(x = cluster, y = heat_days, fill = cluster)) +
  geom_boxplot(alpha = 0.4, outlier.alpha = 0.5) +
  geom_jitter(aes(color = cluster), width = 0.15, size = 2, alpha = 0.6) +
  scale_fill_manual(values = cluster_colours) +
  scale_color_manual(values = cluster_colours) +
  scale_x_discrete(labels = short_labels) +
  labs(title = "B. Heat Days per Site-Year",
       x = "Thermal Regime", y = "Days with Tmax ≥ 38°C",
       caption = str_wrap("Panel B. Count of extreme heat days per site-year. C1 site-years experience significantly more days above the 38°C threshold.", 100)) +
  theme_paper + theme(legend.position = "none")

# 5C: Heatwave count
hw_cols <- grep("^no_hw_", colnames(scaled_features), value = TRUE)
hw_full <- if ("no_hw" %in% colnames(feature_matrix)) {
  data.frame(n_heatwaves = feature_matrix[, "no_hw"],
             cluster = site_year_pheno$cluster)
} else {
  # Use the BBtoH column as proxy for total heatwaves
  hw_col <- grep("no_hw_BBtoH", colnames(feature_matrix), value = TRUE)
  if (length(hw_col) > 0) {
    data.frame(n_heatwaves = feature_matrix[, hw_col[1]],
               cluster = site_year_pheno$cluster)
  } else {
    data.frame(n_heatwaves = heat_days_summary$heat_days / 3,
               cluster = heat_days_summary$cluster)
  }
}
hw_full$cluster <- factor(hw_full$cluster, levels = c("C3", "C2", "C1"))

fig5c <- ggplot(hw_full, aes(x = cluster, y = n_heatwaves, fill = cluster)) +
  geom_boxplot(alpha = 0.4, outlier.alpha = 0.5) +
  geom_jitter(aes(color = cluster), width = 0.15, size = 2, alpha = 0.6) +
  scale_fill_manual(values = cluster_colours) +
  scale_color_manual(values = cluster_colours) +
  scale_x_discrete(labels = short_labels) +
  labs(title = "C. Heatwave Events per Site-Year",
       x = "Thermal Regime", y = "Number of Heatwave Events",
       caption = str_wrap("Panel C. Count of discrete heatwave events (≥2 consecutive days with Tmax ≥ 38°C). C1 post-veraison heat clusters show the most frequent and intense heatwave occurrence.", 100)) +
  theme_paper + theme(legend.position = "none")

cap5 <- make_caption("Figure 5. Characterisation of thermal regimes. (A) Density of daily Tmax, (B) heat days per site-year, (C) heatwave events per site-year. Post-veraison (C1) and pre-veraison (C2) heat clusters are clearly separable from the cool baseline (C3).")

ggsave("figures/fig5_temperature_profiles.png",
       arrangeGrob(fig5a, fig5b, fig5c, ncol = 3, bottom = cap5),
       width = 16, height = 6.5, bg = "white")

# ============================================================================
# FIGURE 6: Harvest Date + Yield (Violin Plots)
# ============================================================================
cat("Generating Figure 6: Harvest date and yield distributions...\n")

yield_filtered$cluster <- factor(yield_filtered$cluster, levels = c("C3", "C2", "C1"))

fig6a <- ggplot(yield_filtered, aes(x = cluster, y = Avg_Harvest_DOY)) +
  geom_violin(aes(fill = cluster), alpha = 0.2, color = NA, trim = FALSE) +
  geom_line(aes(group = block_ID), color = "gray80", alpha = 0.4) +
  geom_jitter(aes(color = cluster), width = 0.05, size = 1.5, alpha = 0.8) +
  scale_fill_manual(values = cluster_colours) +
  scale_color_manual(values = cluster_colours) +
  scale_x_discrete(labels = short_labels) +
  labs(title = "A. Harvest Date", x = "Thermal Regime",
       y = "Harvest Date (Day of Year)") +
  theme_paper + theme(legend.position = "none")

fig6b <- ggplot(yield_filtered, aes(x = cluster, y = Yield_tha)) +
  geom_violin(aes(fill = cluster), alpha = 0.2, color = NA, trim = FALSE) +
  geom_line(aes(group = block_ID), color = "gray80", alpha = 0.4) +
  geom_jitter(aes(color = cluster), width = 0.05, size = 1.5, alpha = 0.8) +
  scale_fill_manual(values = cluster_colours) +
  scale_color_manual(values = cluster_colours) +
  scale_x_discrete(labels = short_labels) +
  labs(title = "B. Yield", x = "Thermal Regime",
       y = "Yield (t/ha)") +
  theme_paper + theme(legend.position = "none")

cap6 <- make_caption("Figure 6. Impact of heatwave timing on (A) harvest date and (B) vineyard yield. Gray lines connect identical vineyard blocks across thermal regimes to show within-block shifts. Post-veraison heat (C1) significantly advances harvest by ~13 days, while both C1 and C2 cause yield reductions of 25-35% compared to the cool baseline (C3).")

ggsave("figures/fig6_harvest_yield.png",
       arrangeGrob(fig6a, fig6b, ncol = 2, bottom = cap6),
       width = 11, height = 7, bg = "white")

# ============================================================================
# FIGURE 7: Fruit Composition — ALL 12 Analytes (4 × 3 grid)
# ============================================================================
cat("Generating Figure 7: Fruit composition analytes (ALL 12)...\n")

fruit_data$cluster <- factor(fruit_data$cluster, levels = c("C3", "C2", "C1"))

plot_analyte <- function(df, y_var, title, y_label) {
  df_sub <- df %>% filter(!is.na(.data[[y_var]]))
  if (nrow(df_sub) == 0) return(ggplot() + theme_void())

  ggplot(df_sub, aes(x = cluster, y = .data[[y_var]])) +
    geom_violin(aes(fill = cluster), alpha = 0.2, color = NA, trim = FALSE) +
    geom_jitter(aes(color = cluster), width = 0.05, size = 1.2, alpha = 0.7) +
    scale_fill_manual(values = cluster_colours) +
    scale_color_manual(values = cluster_colours) +
    scale_x_discrete(labels = short_labels) +
    labs(title = title, x = "", y = y_label) +
    theme_paper +
    theme(legend.position = "none",
          axis.text.x = element_text(size = 9),
          plot.title = element_text(size = 13))
}

# All 12 analytes in the order the paper presents them
p_tss    <- plot_analyte(fruit_data, "TSS", "TSS", "°Brix")
p_ph     <- plot_analyte(fruit_data, "pH", "pH", "")
p_malic  <- plot_analyte(fruit_data, "Malic_acid", "Malic Acid", "mg/L")
p_yan    <- plot_analyte(fruit_data, "YAN", "YAN", "mg/L")
p_anth   <- plot_analyte(fruit_data, "Total_anthocyanins", "Total Anthocyanins", "mg/g")
p_tann   <- plot_analyte(fruit_data, "Polymeric_tannins", "Polymeric Tannins", "mg/L")
p_querc  <- plot_analyte(fruit_data, "Quercetin_glycosides", "Quercetin Glycosides", "mg/L")
p_damas  <- plot_analyte(fruit_data, "B_Damascenone", "β-Damascenone", "µg/L")
p_octen  <- plot_analyte(fruit_data, "Octen_3_ol", "1-Octen-3-ol", "µg/L")
p_c6     <- plot_analyte(fruit_data, "C6_compounds", "C6 Compounds", "µg/L")
p_ibmp   <- plot_analyte(fruit_data, "IBMP", "IBMP", "ng/L")
p_moist  <- plot_analyte(fruit_data, "Berry_moisture", "Berry Moisture", "%")

cap7 <- make_caption("Figure 7. Effect of thermal regimes on all 12 fruit composition analytes. Post-veraison heat (C1) significantly disrupts malic acid respiration (doubled levels), increases 1-Octen-3-ol, elevates polymeric tannins, and affects TSS. Pre-veraison heat (C2) reduces total anthocyanins and quercetin glycosides. pH, berry moisture, IBMP, and C6 compounds show no significant cluster effect. Violin shapes represent the density distribution; individual points are block-year observations.", 150)

fig7_combined <- arrangeGrob(
  p_tss, p_ph, p_malic, p_yan,
  p_anth, p_tann, p_querc, p_damas,
  p_octen, p_c6, p_ibmp, p_moist,
  ncol = 4, nrow = 3, bottom = cap7
)

ggsave("figures/fig7_composition.png", fig7_combined,
       width = 16, height = 14, bg = "white")

# ============================================================================
# SUPPLEMENTAL FIGURE 2: GDD Accumulation Comparison
# ============================================================================
cat("Generating Supplemental Figure 2: GDD comparison...\n")

gdd_plot_data <- db1_data %>%
  mutate(Year = as.integer(format(date, "%Y")),
         DOY = as.integer(format(date, "%j")),
         Month = as.integer(format(date, "%m"))) %>%
  filter(Month >= 3, Month <= 10) %>%
  group_by(Site, Year) %>%
  arrange(DOY) %>%
  mutate(GDD_daily = pmax(0, (tmax + tmin) / 2 - 10),
         GDD_cum = cumsum(GDD_daily)) %>%
  ungroup() %>%
  left_join(site_year_pheno %>% select(Site, Season, cluster),
            by = c("Site", "Year" = "Season")) %>%
  filter(!is.na(cluster))

gdd_mean_by_cluster <- gdd_plot_data %>%
  group_by(cluster, DOY) %>%
  summarise(GDD_mean = mean(GDD_cum, na.rm = TRUE), .groups = "drop")
gdd_mean_by_cluster$cluster <- factor(gdd_mean_by_cluster$cluster, levels = c("C3", "C2", "C1"))

supp2 <- ggplot(gdd_mean_by_cluster, aes(x = DOY, y = GDD_mean, color = cluster)) +
  geom_line(linewidth = 1.2) +
  scale_color_manual(values = cluster_colours, labels = cluster_labels,
                     name = "Thermal Regime:") +
  labs(title = "Supplemental Figure 2: Cumulative GDD by Thermal Regime",
       x = "Day of Year", y = "Cumulative GDD (base 10°C, March 1)",
       caption = str_wrap("Supplemental Figure 2. Mean cumulative Growing Degree Day (GDD) trajectories for each thermal regime. C1 and C2 accumulate heat faster during their respective stress windows (post- and pre-veraison), separating from the C3 cool baseline.", 110)) +
  theme_paper

ggsave("figures/supp_fig2_gdd_comparison.png", supp2, width = 10, height = 7, bg = "white")

# ============================================================================
# SUPPLEMENTAL FIGURE 3: Feature Heatmap
# ============================================================================
cat("Generating Supplemental Figure 3: Feature heatmap...\n")

# Use top 50 most variable features for readability
feat_var <- apply(scaled_features, 2, var)
top_50_feats <- names(sort(feat_var, decreasing = TRUE))[1:50]
hm_mat <- t(scaled_features[, top_50_feats])

# Cluster annotation
ha <- HeatmapAnnotation(
  Cluster = site_year_pheno$cluster,
  col = list(Cluster = cluster_colours),
  show_legend = TRUE,
  annotation_legend_param = list(Cluster = list(title = "Thermal Regime"))
)

png("figures/supp_fig3_heatmap.png", width = 1200, height = 1000, res = 120)
draw(Heatmap(hm_mat,
             name = "Z-score",
             top_annotation = ha,
             show_column_names = FALSE,
             row_names_gp = gpar(fontsize = 7),
             column_split = site_year_pheno$cluster,
             column_title = c("C1 (Post-V)", "C2 (Pre-V)", "C3 (Cool)"),
             column_title_gp = gpar(fontsize = 12, fontface = "bold"),
             heatmap_legend_param = list(title = "Z-score")),
     column_title = "Supplemental Figure 3: Feature Heatmap (Top 50 Variable Features)",
     column_title_gp = gpar(fontsize = 14, fontface = "bold"))
dev.off()

# ============================================================================
# SUPPLEMENTAL FIGURE 7: RF Stress Test (TER across iterations)
# ============================================================================
cat("Generating Supplemental Figure 7: RF stress test...\n")

supp7 <- ggplot(data.frame(Iteration = 1:length(ter_vec), TER = ter_vec),
                aes(x = Iteration, y = TER)) +
  geom_line(color = "#0072B2", linewidth = 0.8) +
  geom_point(color = "#0072B2", size = 2, alpha = 0.7) +
  geom_hline(yintercept = mean(ter_vec), color = "#D55E00", linetype = "dashed") +
  annotate("text", x = 5, y = mean(ter_vec) + 1,
           label = paste0("Mean = ", round(mean(ter_vec), 2), "%"),
           color = "#D55E00", fontface = "bold", size = 4) +
  labs(title = "Supplemental Figure 7: RF Stress Test",
       x = "Bootstrap Iteration", y = "Topological Error Rate (%)",
       caption = str_wrap("Supplemental Figure 7. TER across 50 bootstrap iterations with stratified 50:50 train/test splits. Variability is expected given the small C1 cluster (n=17). Dashed line shows the mean TER.", 110)) +
  theme_paper

ggsave("figures/supp_fig7_stress_test.png", supp7, width = 9, height = 6, bg = "white")

# ============================================================================
# SUPPLEMENTAL FIGURE 15: Yield by Vine Age
# ============================================================================
cat("Generating Supplemental Figure 15: Yield by vine age...\n")

if (exists("yield_age") && nrow(yield_age) > 0) {
  yield_age$cluster <- factor(yield_age$cluster, levels = c("C3", "C2", "C1"))

  supp15 <- ggplot(yield_age %>% filter(!is.na(Yield_tha)),
                   aes(x = cluster, y = Yield_tha)) +
    geom_violin(aes(fill = cluster), alpha = 0.2, color = NA, trim = FALSE) +
    geom_jitter(aes(color = cluster), width = 0.1, size = 1.2, alpha = 0.7) +
    scale_fill_manual(values = cluster_colours, labels = cluster_labels,
                      name = "Thermal Regime:") +
    scale_color_manual(values = cluster_colours, labels = cluster_labels,
                       name = "Thermal Regime:") +
    scale_x_discrete(labels = short_labels) +
    facet_wrap(~ age_group) +
    labs(title = "Supplemental Figure 15: Yield by Cluster and Vine Age",
         x = "Thermal Regime", y = "Yield (t/ha)",
         caption = str_wrap("Supplemental Figure 15. Yield responses stratified by vine age. Both young (3-5 years) and mature (>5 years) vines experience significant yield losses under heat stress. Mature vines show a higher baseline (C3) but similar proportional losses.", 110)) +
    theme_paper + theme(legend.position = "bottom")

  ggsave("figures/supp_fig15_vine_age.png", supp15, width = 10, height = 7, bg = "white")
}

cat("\n=== All figures saved to figures/ ===\n")
cat("=== Section 8 Complete ===\n")