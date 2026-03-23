###############################################################################
# 07_figures.R
# Reproduction of Previtali et al. (2026)
# Section 8: Complete Figure Generation
###############################################################################

load("output/01_data_loaded.RData")
load("output/02_phenology.RData")
load("output/03_features.RData")
load("output/04_clusters.RData")
load("output/05_rf_validation.RData")
load("output/06_lmm_results.RData")

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(factoextra)
  library(ComplexHeatmap)
  library(circlize)
  library(viridis)
  library(gridExtra)
  library(lubridate)
  library(scales)
})

cat("=== Section 8: Figure Generation ===\n\n")

# Common theme
theme_paper <- theme_bw(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "bottom"
  )

cluster_colours <- c("C1" = "#E63946", "C2" = "#F4A261", "C3" = "#457B9D")

# ==========================================================================
# Figure 2: Attribution procedure — S4 harvest DOY
# ==========================================================================

cat("Generating Figure 2: Attribution procedure (S4 harvest DOY)...\n")

s4_data <- yield_filtered %>%
  filter(Site == "S4", !is.na(Avg_Harvest_DOY))

fig2 <- ggplot(s4_data, aes(x = Season, y = Avg_Harvest_DOY, colour = cluster)) +
  geom_point(size = 3, alpha = 0.7) +
  geom_line(aes(group = Block_ID), alpha = 0.3, linewidth = 0.5) +
  scale_colour_manual(values = cluster_colours, name = "Cluster") +
  labs(
    title = "Figure 2: Attribution of Harvest DOY to Weather Clusters — Site S4",
    x = "Season", y = "Harvest Day of Year (DOY)"
  ) +
  theme_paper +
  scale_y_continuous(limits = c(250, 310))

ggsave(file.path(fig_dir, "fig2_attribution_s4.png"), fig2,
       width = 10, height = 6, dpi = 300)

# ==========================================================================
# Figure 3A: PCA score plot (factoextra)
# ==========================================================================

cat("Generating Figure 3A: PCA score plot...\n")

pca_res <- prcomp(scaled_features)

fig3a <- fviz_pca_ind(
  pca_res,
  col.ind = as.factor(clusters_labelled),
  palette = unname(cluster_colours),
  addEllipses = TRUE,
  ellipse.type = "convex",
  repel = TRUE,
  legend.title = "Cluster",
  title = "Figure 3A: PCA Score Plot of Weather Clusters"
) + theme_paper

ggsave(file.path(fig_dir, "fig3a_pca.png"), fig3a,
       width = 9, height = 7, dpi = 300)

# Report variance explained
cat(sprintf("  PC1: %.1f%% variance (expected ~22%%)\n",
            summary(pca_res)$importance[2, 1] * 100))
cat(sprintf("  PC2: %.1f%% variance (expected ~11%%)\n",
            summary(pca_res)$importance[2, 2] * 100))

# ==========================================================================
# Figure 3B1-B3: Temperature radial charts per cluster
# ==========================================================================

cat("Generating Figure 3B: Temperature radial charts...\n")

# Representative site-years from paper: C1 = S1_2022, C2 = S4_2006, C3 = S2_2011
representative <- data.frame(
  cluster = c("C1", "C2", "C3"),
  Site = c("S1", "S4", "S2"),
  Year = c(2022, 2006, 2011),
  label = c("S1_2022 (POST-V Heat)", "S4_2006 (PRE-V Heat)", "S2_2011 (Cool Baseline)"),
  stringsAsFactors = FALSE
)

for (idx in 1:nrow(representative)) {
  rep <- representative[idx, ]

  w <- db1_data %>%
    filter(Site == rep$Site, year(date) == rep$Year,
           month(date) >= 4, month(date) <= 10) %>%
    mutate(DOY = yday(date))

  p <- ggplot(w, aes(x = DOY)) +
    geom_ribbon(aes(ymin = tmin, ymax = tmax), fill = "steelblue", alpha = 0.3) +
    geom_line(aes(y = tmean), colour = "darkblue", linewidth = 0.6) +
    geom_hline(yintercept = 38, colour = "red", linetype = "dashed", linewidth = 0.8) +
    coord_polar(start = 0) +
    scale_x_continuous(
      breaks = c(91, 121, 152, 182, 213, 244, 274),
      labels = month.abb[4:10]
    ) +
    labs(
      title = paste("Figure 3B:", rep$label),
      x = NULL, y = "Temperature (°C)"
    ) +
    theme_paper +
    theme(axis.text.x = element_text(size = 10))

  fname <- sprintf("fig3b%d_radial_%s.png", idx, rep$cluster)
  ggsave(file.path(fig_dir, fname), p, width = 7, height = 7, dpi = 300)
}

# ==========================================================================
# Figure 4A: TER per RF iteration
# ==========================================================================

cat("Generating Figure 4A: TER per RF iteration...\n")

ter_df <- data.frame(
  iteration = 1:length(TER_results),
  TER = TER_results
)

fig4a <- ggplot(ter_df, aes(x = iteration, y = TER)) +
  geom_point(colour = "#457B9D", size = 2, alpha = 0.7) +
  geom_hline(yintercept = mean(TER_results), colour = "red",
             linetype = "dashed", linewidth = 0.8) +
  geom_hline(yintercept = 2, colour = "darkred",
             linetype = "dotted", linewidth = 0.8) +
  annotate("text", x = max(ter_df$iteration) * 0.8,
           y = mean(TER_results) + 0.15,
           label = sprintf("Mean = %.2f%%", mean(TER_results)),
           colour = "red", size = 4) +
  labs(
    title = "Figure 4A: Test Error Rate per RF Bootstrap Iteration",
    x = "Iteration", y = "Test Error Rate (%)"
  ) +
  theme_paper

ggsave(file.path(fig_dir, "fig4a_ter.png"), fig4a,
       width = 9, height = 5, dpi = 300)

# ==========================================================================
# Figure 4B: Variable importance (MDA) — factoextra style
# ==========================================================================

cat("Generating Figure 4B: Variable importance (MDA)...\n")

top30 <- head(mda_sorted, 30)
mda_df <- data.frame(
  feature = factor(names(top30), levels = rev(names(top30))),
  MDA = top30
)

# Colour FL_VER features differently
mda_df$group <- ifelse(grepl("FL_VER", mda_df$feature), "FL-VER", "Other")

fig4b <- ggplot(mda_df, aes(x = MDA, y = feature, fill = group)) +
  geom_col(width = 0.7) +
  scale_fill_manual(values = c("FL-VER" = "#E63946", "Other" = "#457B9D"),
                    name = "Feature group") +
  labs(
    title = "Figure 4B: Variable Importance (Mean Decrease Accuracy)",
    x = "Mean Decrease Accuracy (%)", y = NULL
  ) +
  theme_paper +
  theme(axis.text.y = element_text(size = 8))

ggsave(file.path(fig_dir, "fig4b_mda.png"), fig4b,
       width = 10, height = 10, dpi = 300)

# ==========================================================================
# Figure 5: Tmax distributions, heat days, heatwave counts by cluster
# ==========================================================================

cat("Generating Figure 5: Heat metrics by cluster and stage...\n")

feature_df <- as.data.frame(feature_matrix)
feature_df$cluster <- clusters_labelled

# Figure 5A: Tmax distributions by cluster and phenological stage
tmax_long <- feature_df %>%
  select(cluster, BB_FL_mean_tmax, FL_VER_mean_tmax, VER_H_mean_tmax) %>%
  pivot_longer(-cluster, names_to = "stage", values_to = "tmax") %>%
  mutate(stage = factor(stage,
    levels = c("BB_FL_mean_tmax", "FL_VER_mean_tmax", "VER_H_mean_tmax"),
    labels = c("BB to FL", "FL to VER", "VER to H")
  ))

fig5a <- ggplot(tmax_long, aes(x = stage, y = tmax, fill = cluster)) +
  geom_boxplot(alpha = 0.8, outlier.size = 1) +
  scale_fill_manual(values = cluster_colours) +
  geom_hline(yintercept = 38, colour = "red", linetype = "dashed") +
  labs(
    title = "Figure 5A: Tmax Distribution by Cluster and Phenological Stage",
    x = "Phenological Stage", y = "Mean Tmax (°C)"
  ) +
  theme_paper

ggsave(file.path(fig_dir, "fig5a_tmax_dist.png"), fig5a,
       width = 9, height = 6, dpi = 300)

# Figure 5B: Heat days by cluster
heat_long <- feature_df %>%
  select(cluster, Early_n_heat_days, FL_VER_n_heat_days, VER_H_n_heat_days) %>%
  pivot_longer(-cluster, names_to = "stage", values_to = "heat_days") %>%
  mutate(stage = factor(stage,
    levels = c("Early_n_heat_days", "FL_VER_n_heat_days", "VER_H_n_heat_days"),
    labels = c("BB to FL", "FL to VER", "VER to H")
  ))

fig5b <- ggplot(heat_long, aes(x = stage, y = heat_days, fill = cluster)) +
  geom_boxplot(alpha = 0.8) +
  scale_fill_manual(values = cluster_colours) +
  labs(
    title = "Figure 5B: Heat Days by Cluster and Phenological Stage",
    subtitle = "Heat day = Tmax >= 38°C",
    x = "Phenological Stage", y = "Number of Heat Days"
  ) +
  theme_paper

ggsave(file.path(fig_dir, "fig5b_heat_days.png"), fig5b,
       width = 9, height = 6, dpi = 300)

# Figure 5C: Heatwaves by cluster
heatwv_long <- feature_df %>%
  select(cluster, Early_n_heatwaves, FL_VER_n_heatwaves, VER_H_n_heatwaves) %>%
  pivot_longer(-cluster, names_to = "stage", values_to = "heatwaves") %>%
  mutate(stage = factor(stage,
    levels = c("Early_n_heatwaves", "FL_VER_n_heatwaves", "VER_H_n_heatwaves"),
    labels = c("BB to FL", "FL to VER", "VER to H")
  ))

fig5c <- ggplot(heatwv_long, aes(x = stage, y = heatwaves, fill = cluster)) +
  geom_boxplot(alpha = 0.8) +
  scale_fill_manual(values = cluster_colours) +
  labs(
    title = "Figure 5C: Heatwave Counts by Cluster and Phenological Stage",
    subtitle = "Heatwave = >= 2 consecutive days with Tmax >= 38°C",
    x = "Phenological Stage", y = "Number of Heatwaves"
  ) +
  theme_paper

ggsave(file.path(fig_dir, "fig5c_heatwaves.png"), fig5c,
       width = 9, height = 6, dpi = 300)

# ==========================================================================
# Figure 6: Harvest date and yield distributions
# ==========================================================================

cat("Generating Figure 6: Harvest date and yield distributions...\n")

# Figure 6A-B: Harvest date distributions
harvest_df <- yield_filtered %>%
  filter(!is.na(Avg_Harvest_DOY)) %>%
  mutate(cluster = factor(cluster, levels = c("C3", "C2", "C1")))

fig6a <- ggplot(harvest_df, aes(x = cluster, y = Avg_Harvest_DOY, fill = cluster)) +
  geom_boxplot(alpha = 0.8, outlier.shape = 1) +
  scale_fill_manual(values = cluster_colours) +
  labs(
    title = "Figure 6A: Harvest Date by Cluster",
    x = "Cluster", y = "Harvest DOY"
  ) +
  theme_paper + theme(legend.position = "none")

fig6b <- ggplot(harvest_df, aes(x = Avg_Harvest_DOY, fill = cluster)) +
  geom_density(alpha = 0.5) +
  scale_fill_manual(values = cluster_colours) +
  labs(
    title = "Figure 6B: Harvest Date Density by Cluster",
    x = "Harvest DOY", y = "Density"
  ) +
  theme_paper

fig6ab <- grid.arrange(fig6a, fig6b, ncol = 2)
ggsave(file.path(fig_dir, "fig6ab_harvest.png"), fig6ab,
       width = 12, height = 5, dpi = 300)

# Figure 6C-D: Yield distributions
yield_df <- yield_filtered %>%
  filter(!is.na(Yield_tha)) %>%
  mutate(cluster = factor(cluster, levels = c("C3", "C2", "C1")))

fig6c <- ggplot(yield_df, aes(x = cluster, y = Yield_tha, fill = cluster)) +
  geom_boxplot(alpha = 0.8, outlier.shape = 1) +
  scale_fill_manual(values = cluster_colours) +
  labs(
    title = "Figure 6C: Yield by Cluster",
    x = "Cluster", y = "Yield (tons/ha)"
  ) +
  theme_paper + theme(legend.position = "none")

fig6d <- ggplot(yield_df, aes(x = Yield_tha, fill = cluster)) +
  geom_density(alpha = 0.5) +
  scale_fill_manual(values = cluster_colours) +
  labs(
    title = "Figure 6D: Yield Density by Cluster",
    x = "Yield (tons/ha)", y = "Density"
  ) +
  theme_paper

fig6cd <- grid.arrange(fig6c, fig6d, ncol = 2)
ggsave(file.path(fig_dir, "fig6cd_yield.png"), fig6cd,
       width = 12, height = 5, dpi = 300)

# ==========================================================================
# Figure 7: All 12 fruit analytes by cluster
# ==========================================================================

cat("Generating Figure 7: Fruit composition analytes...\n")

analyte_cols <- c("B_Damascenone", "Octen_3_ol", "C6_compounds", "IBMP",
                  "Total_anthocyanins", "Polymeric_tannins",
                  "Quercetin_glycosides", "TSS", "Berry_moisture",
                  "pH", "Malic_acid", "YAN")

analyte_labels <- c(
  "B_Damascenone" = "β-Damascenone (µg/L)",
  "Octen_3_ol" = "1-Octen-3-ol (µg/L)",
  "C6_compounds" = "C6 Compounds (µg/L)",
  "IBMP" = "IBMP (ng/L)",
  "Total_anthocyanins" = "Total Anthocyanins (mg/g)",
  "Polymeric_tannins" = "Polymeric Tannins (mg/L)",
  "Quercetin_glycosides" = "Quercetin Glycosides (mg/L)",
  "TSS" = "TSS (°Brix)",
  "Berry_moisture" = "Berry Moisture (%)",
  "pH" = "pH",
  "Malic_acid" = "Malic Acid (mg/L)",
  "YAN" = "YAN (mg/L)"
)

comp_plot_data <- comp_filtered %>%
  select(cluster, all_of(analyte_cols)) %>%
  mutate(cluster = factor(cluster, levels = c("C3", "C2", "C1"))) %>%
  pivot_longer(-cluster, names_to = "analyte", values_to = "value") %>%
  mutate(analyte_label = analyte_labels[analyte])

fig7 <- ggplot(comp_plot_data, aes(x = cluster, y = value, fill = cluster)) +
  geom_boxplot(alpha = 0.8, outlier.size = 0.8) +
  scale_fill_manual(values = cluster_colours) +
  facet_wrap(~ analyte_label, scales = "free_y", ncol = 4) +
  labs(
    title = "Figure 7: Fruit Composition by Weather Cluster",
    x = "Cluster", y = NULL
  ) +
  theme_paper +
  theme(
    strip.text = element_text(size = 9, face = "bold"),
    axis.text.x = element_text(size = 9),
    legend.position = "none"
  )

ggsave(file.path(fig_dir, "fig7_composition.png"), fig7,
       width = 14, height = 10, dpi = 300)

# ==========================================================================
# Supplemental Figure 2: GDD_Mar1 vs GDD_Jan1 scatter
# ==========================================================================

cat("Generating Supplemental Figure 2: GDD comparison...\n")

# Use observed phenological events and their GDD values
pheno_gdd_long <- pheno_gdd %>%
  filter(!is.na(BB_DOY)) %>%
  select(Site, Season, BB_DOY, FL_DOY, VER_DOY, H_DOY,
         GDD_Mar1_BB, GDD_Mar1_FL, GDD_Mar1_VER, GDD_Mar1_H,
         GDD_Jan1_BB, GDD_Jan1_FL, GDD_Jan1_VER, GDD_Jan1_H) %>%
  pivot_longer(
    cols = c(BB_DOY, FL_DOY, VER_DOY, H_DOY),
    names_to = "stage", values_to = "DOY"
  ) %>%
  mutate(
    stage = gsub("_DOY", "", stage),
    GDD_Mar1 = case_when(
      stage == "BB" ~ GDD_Mar1_BB, stage == "FL" ~ GDD_Mar1_FL,
      stage == "VER" ~ GDD_Mar1_VER, stage == "H" ~ GDD_Mar1_H
    ),
    GDD_Jan1 = case_when(
      stage == "BB" ~ GDD_Jan1_BB, stage == "FL" ~ GDD_Jan1_FL,
      stage == "VER" ~ GDD_Jan1_VER, stage == "H" ~ GDD_Jan1_H
    ),
    stage = factor(stage, levels = c("BB", "FL", "VER", "H"))
  ) %>%
  filter(!is.na(DOY), !is.na(GDD_Mar1), !is.na(GDD_Jan1))

supp2a <- ggplot(pheno_gdd_long, aes(x = GDD_Mar1, y = DOY, colour = stage)) +
  geom_point(alpha = 0.5, size = 2) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 0.8) +
  labs(title = "Supp. Fig. 2A: DOY vs GDD (March 1 start)",
       x = "GDD (March 1 base 10°C)", y = "Day of Year") +
  theme_paper

supp2b <- ggplot(pheno_gdd_long, aes(x = GDD_Jan1, y = DOY, colour = stage)) +
  geom_point(alpha = 0.5, size = 2) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 0.8) +
  labs(title = "Supp. Fig. 2B: DOY vs GDD (January 1 start)",
       x = "GDD (January 1 base 10°C)", y = "Day of Year") +
  theme_paper

supp2 <- grid.arrange(supp2a, supp2b, ncol = 2)
ggsave(file.path(fig_dir, "supp_fig2_gdd_comparison.png"), supp2,
       width = 14, height = 6, dpi = 300)

# ==========================================================================
# Supplemental Figure 3: Scaled weather heatmap (ComplexHeatmap)
# ==========================================================================

cat("Generating Supplemental Figure 3: Weather heatmap...\n")

# Use ComplexHeatmap with dendrograms on both rows and columns
ha_col <- HeatmapAnnotation(
  Cluster = clusters_labelled,
  col = list(Cluster = cluster_colours),
  show_annotation_name = TRUE
)

# Limit to top 50 most variable features for readability
feature_var <- apply(scaled_features, 2, var)
top_features <- names(sort(feature_var, decreasing = TRUE))[1:min(50, ncol(scaled_features))]

png(file.path(fig_dir, "supp_fig3_heatmap.png"),
    width = 16, height = 12, units = "in", res = 300)

ht <- Heatmap(
  t(scaled_features[, top_features]),
  name = "Z-score",
  top_annotation = ha_col,
  show_column_names = FALSE,
  row_names_gp = gpar(fontsize = 7),
  column_title = "Supp. Fig. 3: Scaled Weather Feature Heatmap",
  column_title_gp = gpar(fontsize = 14, fontface = "bold"),
  clustering_distance_columns = "euclidean",
  clustering_method_columns = "ward.D2",
  clustering_distance_rows = "euclidean",
  clustering_method_rows = "ward.D2"
)
draw(ht)
dev.off()

# ==========================================================================
# Supplemental Figure 7: TER across iteration counts (stress test)
# ==========================================================================

cat("Generating Supplemental Figure 7: TER stress test...\n")

stress_df <- do.call(rbind, lapply(names(stress_results), function(n) {
  data.frame(
    n_iterations = as.numeric(n),
    TER = stress_results[[n]],
    iteration = 1:length(stress_results[[n]])
  )
}))

supp7 <- ggplot(stress_df, aes(x = factor(n_iterations), y = TER)) +
  geom_boxplot(fill = "#457B9D", alpha = 0.7) +
  geom_hline(yintercept = 2, colour = "red", linetype = "dashed") +
  labs(
    title = "Supp. Fig. 7: TER Across Different Bootstrap Iteration Counts",
    x = "Number of Iterations", y = "Test Error Rate (%)"
  ) +
  theme_paper

ggsave(file.path(fig_dir, "supp_fig7_stress_test.png"), supp7,
       width = 9, height = 5, dpi = 300)

# ==========================================================================
# Supplemental Figure 15: Yield by vine age group
# ==========================================================================

cat("Generating Supplemental Figure 15: Yield by vine age...\n")

if (exists("yield_age") && nrow(yield_age) > 0) {
  yield_age_plot <- yield_age %>%
    filter(!is.na(Yield_tha)) %>%
    mutate(cluster = factor(cluster, levels = c("C3", "C2", "C1")))

  supp15 <- ggplot(yield_age_plot,
                   aes(x = cluster, y = Yield_tha, fill = cluster)) +
    geom_boxplot(alpha = 0.8) +
    scale_fill_manual(values = cluster_colours) +
    facet_wrap(~ age_group) +
    labs(
      title = "Supp. Fig. 15: Yield by Cluster and Vine Age",
      x = "Cluster", y = "Yield (tons/ha)"
    ) +
    theme_paper + theme(legend.position = "none")

  ggsave(file.path(fig_dir, "supp_fig15_vine_age.png"), supp15,
         width = 10, height = 5, dpi = 300)
}

# ==========================================================================
# Summary
# ==========================================================================

cat("\n=== All figures saved to", fig_dir, "===\n")
cat("Files generated:\n")
fig_files <- list.files(fig_dir, pattern = "[.]png$")
for (f in fig_files) {
  finfo <- file.info(file.path(fig_dir, f))
  cat(sprintf("  %-40s %s\n", f, format(finfo$size, big.mark = ",")))
}
cat(sprintf("\nTotal: %d figures\n", length(fig_files)))

cat("\n=== Section 8 Complete ===\n")
