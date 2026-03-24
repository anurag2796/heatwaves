###############################################################################
# 04_hca_clustering.R
# Reproduction of Previtali et al. (2026)
# Section 5: Hierarchical Clustering Analysis
###############################################################################

load("output/03_features.RData")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(cluster)
  library(factoextra)
})

cat("=== Section 5: Hierarchical Clustering Analysis ===\n\n")

if (!dir.exists("figures")) dir.create("figures")

cat("Running cluster optimisation diagnostics...\n")

# --- Custom wrapper to avoid fviz_nbclust/hcut bug in recent R versions ---
my_hclust <- function(x, k) {
  hc <- hclust(dist(x, method = "euclidean"), method = "ward.D2")
  list(cluster = cutree(hc, k = k))
}

# 1. WSS (Elbow Method)
suppressWarnings(suppressMessages({
  p_wss <- fviz_nbclust(scaled_features, FUNcluster = my_hclust, method = "wss", k.max = 10) +
    theme_minimal() + 
    labs(title = "Elbow Method (WSS)")
  ggsave("figures/supp_fig6_wss.png", p_wss, width=6, height=4, bg="white")
}))

# 2. Silhouette Method
suppressWarnings(suppressMessages({
  p_sil <- fviz_nbclust(scaled_features, FUNcluster = my_hclust, method = "silhouette", k.max = 10) +
    theme_minimal() + 
    labs(title = "Silhouette Method")
  ggsave("figures/supp_fig6_silhouette.png", p_sil, width=6, height=4, bg="white")
}))

# 3. Gap Statistic
suppressWarnings(suppressMessages({
  gap_stat <- clusGap(scaled_features, FUN = hcut, K.max = 10, B = 50, hc_func = "hclust", hc_method="ward.D2")
  p_gap <- fviz_gap_stat(gap_stat) +
    theme_minimal() + 
    labs(title = "Gap Statistic")
  ggsave("figures/supp_fig6_gap.png", p_gap, width=6, height=4, bg="white")
}))

cat("  Saved Supplemental Figure 6 panels to figures/\n")
cat("  Expected: all three methods converge on k = 3\n\n")

cat("Running HCA with Ward.D2 linkage, k = 3...\n\n")

d <- dist(scaled_features, method = "euclidean")
hc <- hclust(d, method = "ward.D2")
raw_clusters <- cutree(hc, k = 3)

cat("Cluster sizes (raw assignment):\n")
print(table(raw_clusters))
cat("\n")

feature_df <- as.data.frame(feature_matrix)
feature_df$cluster_raw <- raw_clusters

# -----------------------------------------------------------------------------
# SUMMARY BLOCK: Mapping perfectly to the strict Table S1 names
# -----------------------------------------------------------------------------
cluster_chars <- feature_df %>%
  group_by(cluster_raw) %>%
  summarise(
    n = n(),
    VER_H_mean_tmax    = mean(Tmax_VERtoH, na.rm = TRUE),
    FL_VER_mean_tmax   = mean(Tmax_BLtoVER, na.rm = TRUE),
    VER_H_n_heat_days  = mean(heat_days_VERtoH, na.rm = TRUE),
    FL_VER_n_heat_days = mean(heat_days_BLtoVER, na.rm = TRUE),
    Full_n_heat_days   = mean(heat_days_100, na.rm = TRUE),
    VER_H_max_hw_vpd   = mean(max_hw_vpd_VERtoH, na.rm = TRUE),
    VER_H_avg_hw_dur   = mean(avg_hw_duration_VERtoH, na.rm = TRUE)
  )

cat("Cluster characteristics for label assignment:\n")
print(as.data.frame(cluster_chars), digits = 4)
cat("\n")

# Assignment logic based on Previtali et al. 2026:
c1_raw <- cluster_chars$cluster_raw[which.max(cluster_chars$VER_H_mean_tmax)]

remaining <- cluster_chars %>% filter(cluster_raw != c1_raw)
c2_raw <- remaining$cluster_raw[which.max(remaining$FL_VER_mean_tmax)]
c3_raw <- remaining$cluster_raw[remaining$cluster_raw != c2_raw]

cat("Raw-to-label mapping:\n")
cat("  Raw", c1_raw, "-> C1 (POST-V heat)\n")
cat("  Raw", c2_raw, "-> C2 (PRE-V heat)\n")
cat("  Raw", c3_raw, "-> C3 (Cool baseline)\n\n")

site_year_pheno$cluster <- NA
site_year_pheno$cluster[raw_clusters == c1_raw] <- "C1"
site_year_pheno$cluster[raw_clusters == c2_raw] <- "C2"
site_year_pheno$cluster[raw_clusters == c3_raw] <- "C3"
site_year_pheno$cluster <- factor(site_year_pheno$cluster, levels = c("C1", "C2", "C3"))

cat("Final cluster sizes:\n")
print(table(site_year_pheno$cluster))
cat("\n")

cat("Expected: C1 = 21, C2 = 70, C3 = 124\n")
act_c1 <- sum(site_year_pheno$cluster == "C1")
act_c2 <- sum(site_year_pheno$cluster == "C2")
act_c3 <- sum(site_year_pheno$cluster == "C3")

check_dev <- function(expected, actual, name) {
  dev <- abs(actual - expected) / expected * 100
  status <- if(dev > 25) "[WARNING]" else "[OK]"
  cat(sprintf("  %s: expected=%d, actual=%d, deviation=%.1f%% %s\n", name, expected, actual, dev, status))
}
check_dev(21, act_c1, "C1")
check_dev(70, act_c2, "C2")
check_dev(124, act_c3, "C3")
cat("\n")

cat("Detailed cluster verification:\n")
verif_df <- cluster_chars %>%
  mutate(cluster = case_when(
    cluster_raw == c1_raw ~ "C1",
    cluster_raw == c2_raw ~ "C2",
    cluster_raw == c3_raw ~ "C3"
  )) %>%
  select(cluster, n, VER_H_mean_tmax, VER_H_n_heat_days, VER_H_max_hw_vpd, 
         VER_H_avg_hw_dur, FL_VER_mean_tmax, FL_VER_n_heat_days) %>%
  arrange(cluster)

print(as.data.frame(verif_df), digits = 3)
cat("\n")

cat("Expected (from paper Table / Section 5c):\n")
cat("  C1 (POST-V): Tmax avg 42.2°C post-VER, 5.20 heat days, VPD 7.2, dur 3.2\n")
cat("  C2 (PRE-V):  Tmax avg 40.1°C FL-VER, 2.94 heat days\n")
cat("  C3 (Cool):   Tmax avg 37.9°C, ~0 heat days\n\n")

save(site_year_pheno, scaled_features, feature_matrix, raw_clusters, hc,
     file = "output/04_clusters.RData")

cat("=== Section 5 Complete ===\n")
cat("Saved to: output/04_clusters.RData\n")