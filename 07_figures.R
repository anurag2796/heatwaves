###############################################################################
# 07_figures.R
# Reproduction of Previtali et al. (2026)
# Section 8: Figure Generation (Publication-Ready Aesthetics & Captions)
###############################################################################

load("output/01_data_loaded.RData")
load("output/04_clusters.RData")
load("output/06_lmm_results.RData")

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(gridExtra)
  library(grid) # Required for adding textGrobs to arranged plots
})

cat("=== Section 8: Figure Generation ===\n\n")
if (!dir.exists("figures")) dir.create("figures")

# Common theme with restored legends, clear axis titles, and caption formatting
theme_paper <- theme_classic(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", size = 16),
    legend.position = "bottom",
    legend.title = element_text(face = "bold"),
    legend.text = element_text(size = 12),
    axis.text = element_text(color = "black", size = 12),
    axis.title = element_text(face = "bold", size = 13),
    plot.caption = element_text(hjust = 0, face = "italic", color = "gray30", size = 11, margin = margin(t = 15))
  )

# Strict color palette and explicit biological labels for the clusters
cluster_colours <- c("C1" = "#D55E00", "C2" = "#E69F00", "C3" = "#0072B2")
cluster_labels <- c("C3" = "C3 (Cool Baseline)", 
                    "C2" = "C2 (Pre-Veraison Heat)", 
                    "C1" = "C1 (Post-Veraison Heat)")

short_labels <- c("C3" = "C3 (Cool)", "C2" = "C2 (Pre-V)", "C1" = "C1 (Post-V)")

# ==========================================================================
# Figure 2: Attribution procedure (S4 harvest DOY)
# ==========================================================================
cat("Generating Figure 2: Attribution procedure (S4 harvest DOY)...\n")

s4_yield <- yield_filtered %>% filter(Site == "S4")

cap2 <- "Figure 2. Heatwave attribution based on historical harvest dates at Site S4. Points represent individual growing seasons (1981-2023). Seasons experiencing extreme post-veraison heat (C1) consistently show advanced, earlier harvest dates compared to the cool baseline (C3) and pre-veraison heat (C2)."

fig2 <- ggplot(s4_yield, aes(x = Season, y = Avg_Harvest_DOY)) +
  geom_line(aes(group = block_ID), color = "gray80", alpha = 0.5) + 
  geom_point(aes(color = cluster), size = 4) +
  scale_color_manual(values = cluster_colours, labels = cluster_labels, name = "Thermal Regime:") +
  labs(title = "Figure 2: Heatwave Attribution (Site S4)", 
       x = "Growing Season (Year)", 
       y = "Average Harvest Date (Day of Year)",
       caption = paste(strwrap(cap2, width = 110), collapse = "\n")) +
  theme_paper

ggsave("figures/fig2_attribution_s4.png", fig2, width = 9, height = 6, bg="white")

# ==========================================================================
# Figure 6: Harvest Date and Yield (Violin + Connected Lines + Points)
# ==========================================================================
cat("Generating Figure 6: Harvest date and yield distributions...\n")

yield_filtered$cluster <- factor(yield_filtered$cluster, levels = c("C3", "C2", "C1"))

# 6A: Harvest Date
fig6a <- ggplot(yield_filtered, aes(x = cluster, y = Avg_Harvest_DOY)) +
  geom_violin(aes(fill = cluster), alpha = 0.2, color = NA, trim = FALSE) +
  geom_line(aes(group = block_ID), color = "gray80", alpha = 0.4) +
  geom_jitter(aes(color = cluster), width = 0.05, size = 1.5, alpha = 0.8) +
  scale_fill_manual(values = cluster_colours) +
  scale_color_manual(values = cluster_colours) +
  scale_x_discrete(labels = short_labels) +
  labs(title = "A. Harvest Date", x = "Thermal Regime", y = "Harvest Date (Day of Year)") +
  theme_paper + theme(legend.position = "none") 

# 6B: Yield
fig6b <- ggplot(yield_filtered, aes(x = cluster, y = Yield_tha)) +
  geom_violin(aes(fill = cluster), alpha = 0.2, color = NA, trim = FALSE) +
  geom_line(aes(group = block_ID), color = "gray80", alpha = 0.4) +
  geom_jitter(aes(color = cluster), width = 0.05, size = 1.5, alpha = 0.8) +
  scale_fill_manual(values = cluster_colours) +
  scale_color_manual(values = cluster_colours) +
  scale_x_discrete(labels = short_labels) +
  labs(title = "B. Yield", x = "Thermal Regime", y = "Yield (t/ha)") +
  theme_paper + theme(legend.position = "none")

cap6 <- "Figure 6. Impact of heatwave timing on (A) harvest date and (B) vineyard yield. Gray lines connect identical vineyard blocks across different thermal regimes to show localized shifts. Post-veraison heat (C1) significantly advances harvest, while pre-veraison heat (C2) causes the most severe yield reductions compared to the cool baseline (C3)."
cap6_grob <- textGrob(paste(strwrap(cap6, width = 130), collapse = "\n"), 
                      x = 0.02, hjust = 0, gp = gpar(fontsize = 11, col = "gray30", fontface = "italic"))

ggsave("figures/fig6_harvest_yield.png", arrangeGrob(fig6a, fig6b, ncol=2, bottom = cap6_grob), width = 11, height = 6.5, bg="white")

# ==========================================================================
# Figure 7: Fruit Composition Analytes
# ==========================================================================
cat("Generating Figure 7: Fruit composition analytes...\n")

fruit_data$cluster <- factor(fruit_data$cluster, levels = c("C3", "C2", "C1"))

plot_analyte <- function(df, y_var, title, y_label) {
  df_sub <- df %>% filter(!is.na(.data[[y_var]]))
  
  ggplot(df_sub, aes(x = cluster, y = .data[[y_var]])) +
    geom_violin(aes(fill = cluster), alpha = 0.2, color = NA, trim = FALSE) +
    geom_line(aes(group = block_ID), color = "gray80", alpha = 0.5) +
    geom_jitter(aes(color = cluster), width = 0.05, size = 1.5, alpha = 0.8) +
    scale_fill_manual(values = cluster_colours) +
    scale_color_manual(values = cluster_colours) +
    scale_x_discrete(labels = short_labels) +
    labs(title = title, x = "Thermal Regime", y = y_label) +
    theme_paper +
    theme(legend.position = "none", 
          axis.text.x = element_text(angle = 30, hjust = 1, size = 11)) 
}

p1 <- plot_analyte(fruit_data, "B_Damascenone", "B-Damascenone", "µg/L")
p2 <- plot_analyte(fruit_data, "Octen_3_ol", "1-Octen-3-ol", "µg/L")
p3 <- plot_analyte(fruit_data, "Total_anthocyanins", "Total Anthocyanins", "mg/g")
p4 <- plot_analyte(fruit_data, "Malic_acid", "Malic Acid", "mg/L")
p5 <- plot_analyte(fruit_data, "YAN", "YAN", "mg/L")
p6 <- plot_analyte(fruit_data, "TSS", "Total Soluble Solids", "°Brix")

cap7 <- "Figure 7. Effect of thermal regimes on key fruit composition analytes. Post-veraison heat (C1) significantly disrupts malic acid respiration and increases 1-Octen-3-ol concentration, while pre-veraison heat (C2) and cool seasons (C3) maintain standard baseline levels. Other metrics like Total Soluble Solids (TSS) show minor but statistically significant variations."
cap7_grob <- textGrob(paste(strwrap(cap7, width = 150), collapse = "\n"), 
                      x = 0.02, hjust = 0, gp = gpar(fontsize = 11, col = "gray30", fontface = "italic"))

fig7_combined <- arrangeGrob(p1, p2, p3, p4, p5, p6, ncol=3, nrow=2, bottom = cap7_grob)
ggsave("figures/fig7_composition.png", fig7_combined, width = 13, height = 10, bg="white")

# ==========================================================================
# Supplemental Figure 15: Yield by vine age group
# ==========================================================================
cat("Generating Supplemental Figure 15: Yield by vine age...\n")

if (exists("yield_age") && nrow(yield_age) > 0) {
  yield_age$cluster <- factor(yield_age$cluster, levels = c("C3", "C2", "C1"))
  
  cap15 <- "Supplemental Figure 15. Yield responses stratified by vine age. Both young (3-5 years) and mature (>5 years) vines experience significant yield losses under pre-veraison (C2) and post-veraison (C1) heat compared to the cool baseline (C3)."
  
  supp15 <- ggplot(yield_age %>% filter(!is.na(Yield_tha)), 
                   aes(x = cluster, y = Yield_tha)) +
    geom_violin(aes(fill = cluster), alpha = 0.2, color = NA, trim = FALSE) +
    geom_jitter(aes(color = cluster), width = 0.1, size = 1.2, alpha = 0.7) +
    scale_fill_manual(values = cluster_colours, labels = cluster_labels, name = "Thermal Regime:") +
    scale_color_manual(values = cluster_colours, labels = cluster_labels, name = "Thermal Regime:") +
    scale_x_discrete(labels = short_labels) +
    facet_wrap(~ age_group) +
    labs(title = "Supplemental Figure 15: Yield by Cluster and Vine Age", 
         x = "Thermal Regime", 
         y = "Yield (t/ha)",
         caption = paste(strwrap(cap15, width = 110), collapse = "\n")) +
    theme_paper +
    theme(legend.position = "bottom")
  
  ggsave("figures/supp_fig15_vine_age.png", supp15, width = 10, height = 6.5, bg="white")
}

cat("\n=== All figures saved to figures/ ===\n")
cat("=== Section 8 Complete ===\n")