###############################################################################
# 04_hca_clustering.R
# Reproduction of Previtali et al. (2026)
# Section 5: Hierarchical Clustering Analysis (HCA)
###############################################################################

load("output/01_data_loaded.RData")
load("output/03_features.RData")

suppressPackageStartupMessages({
  library(factoextra)
  library(dplyr)
})

SEED <- 42

cat("=== Section 5: Hierarchical Clustering Analysis ===\n\n")

# --- 5a. Determine Optimal Number of Clusters -----------------------------
cat("Running cluster optimisation diagnostics...\n")

# Custom wrapper to avoid fviz_nbclust/hcut bug in recent R versions
my_hclust <- function(x, k) {
  hc <- hclust(dist(x, method = "euclidean"), method = "ward.D2")
  list(cluster = cutree(hc, k = k))
}

# 1. Within-cluster Sum of Squares (WSS) - Elbow method
p_wss <- fviz_nbclust(scaled_features, FUNcluster = my_hclust, method = "wss", k.max = 10) +
  theme_minimal() + 
  labs(title = "Elbow Method (WSS)")
ggsave(file.path(fig_dir, "supp_fig6_wss.png"), p_wss,
       width = 8, height = 5, dpi = 300)

# 2. Silhouette Method
p_sil <- fviz_nbclust(scaled_features, FUNcluster = my_hclust, method = "silhouette", k.max = 10) +
  theme_minimal() + 
  labs(title = "Silhouette Method")
ggsave(file.path(fig_dir, "supp_fig6_silhouette.png"), p_sil,
       width = 8, height = 5, dpi = 300)

# 3. Gap Statistic
set.seed(SEED) # Required for reproducible gap statistic
p_gap <- fviz_nbclust(scaled_features, FUNcluster = my_hclust, method = "gap_stat", k.max = 10, print.summary = FALSE) +
  theme_minimal() + 
  labs(title = "Gap Statistic Method")
ggsave(file.path(fig_dir, "supp_fig6_gap.png"), p_gap,
       width = 8, height = 5, dpi = 300)

cat("  Saved Supplemental Figure 6 panels to figures/\n")
cat("  Expected: all three methods converge on k = 3\n\n")

# --- 5b. Run HCA -----------------------------------------------------------

cat("Running HCA with Ward.D2 linkage, k = 3...\n")

hc <- hclust(dist(scaled_features), method = "ward.D2")
clusters <- cutree(hc, k = 3)

# --- 5c. Assign cluster labels based on expected characteristics -----------

# The plan specifies:
# C1 (POST-V heat): n=21, Tmax avg 42.2°C post-VER, 5.20 heat days
# C2 (PRE-V heat):  n=70, Tmax avg 40.1°C during FL-VER, 2.94 heat days
# C3 (Cool baseline): n=124, Tmax avg 37.9°C, ~0 heat days

# Check cluster sizes
cluster_sizes <- table(clusters)
cat("\nCluster sizes (raw assignment):\n")
print(cluster_sizes)

# Characterize each cluster to assign correct labels
feature_df <- as.data.frame(feature_matrix)
feature_df$cluster_raw <- clusters
feature_df$site_year <- rownames(feature_matrix)

# Compute key discriminating statistics per cluster
cluster_chars <- feature_df %>%
  group_by(cluster_raw) %>%
  summarise(
    n = n(),
    VER_H_mean_tmax = mean(VER_H_mean_tmax, na.rm = TRUE),
    FL_VER_mean_tmax = mean(FL_VER_mean_tmax, na.rm = TRUE),
    VER_H_n_heat_days = mean(VER_H_n_heat_days, na.rm = TRUE),
    FL_VER_n_heat_days = mean(FL_VER_n_heat_days, na.rm = TRUE),
    Full_n_heat_days = mean(Full_n_heat_days, na.rm = TRUE),
    .groups = "drop"
  )

cat("\nCluster characteristics for label assignment:\n")
print(as.data.frame(cluster_chars))

# Assign labels: C1 = highest post-VER heat, C2 = highest pre-VER heat, C3 = coolest
# C1 (POST-V): highest VER_H_mean_tmax
# C3 (Cool): lowest Full heat days
# C2 (PRE-V): remaining

# Sort by post-VER Tmax to find C1 candidate
c1_raw <- cluster_chars$cluster_raw[which.max(cluster_chars$VER_H_mean_tmax)]
c3_raw <- cluster_chars$cluster_raw[which.min(cluster_chars$Full_n_heat_days)]
c2_raw <- setdiff(cluster_chars$cluster_raw, c(c1_raw, c3_raw))

# Create label mapping
label_map <- setNames(c("C1", "C2", "C3"), c(c1_raw, c2_raw, c3_raw))
clusters_labelled <- label_map[as.character(clusters)]

cat("\nRaw-to-label mapping:\n")
cat("  Raw", c1_raw, "-> C1 (POST-V heat)\n")
cat("  Raw", c2_raw, "-> C2 (PRE-V heat)\n")
cat("  Raw", c3_raw, "-> C3 (Cool baseline)\n")

# --- 5d. Verify cluster assignments ----------------------------------------

final_sizes <- table(clusters_labelled)
cat("\nFinal cluster sizes:\n")
print(final_sizes)
cat("\nExpected: C1 = 21, C2 = 70, C3 = 124\n")

# Check deviations
verify_cluster <- function(label, expected_n, actual_n) {
  pct_dev <- abs(actual_n - expected_n) / expected_n * 100
  status  <- ifelse(pct_dev <= 5, "OK", "WARNING")
  cat(sprintf("  %s: expected=%d, actual=%d, deviation=%.1f%% [%s]\n",
              label, expected_n, actual_n, pct_dev, status))
}

verify_cluster("C1", 21, as.integer(final_sizes["C1"]))
verify_cluster("C2", 70, as.integer(final_sizes["C2"]))
verify_cluster("C3", 124, as.integer(final_sizes["C3"]))

# Detailed cluster characteristics
cat("\nDetailed cluster verification:\n")
feature_df$cluster <- clusters_labelled

cluster_detail <- feature_df %>%
  group_by(cluster) %>%
  summarise(
    n = n(),
    VER_H_mean_tmax = round(mean(VER_H_mean_tmax, na.rm = TRUE), 1),
    VER_H_n_heat_days = round(mean(VER_H_n_heat_days, na.rm = TRUE), 2),
    VER_H_max_hw_vpd = round(mean(VER_H_max_hw_vpd, na.rm = TRUE), 1),
    VER_H_avg_hw_dur = round(mean(VER_H_avg_hw_duration, na.rm = TRUE), 1),
    FL_VER_mean_tmax = round(mean(FL_VER_mean_tmax, na.rm = TRUE), 1),
    FL_VER_n_heat_days = round(mean(FL_VER_n_heat_days, na.rm = TRUE), 2),
    .groups = "drop"
  )
print(as.data.frame(cluster_detail))

cat("\nExpected (from paper Table / Section 5c):\n")
cat("  C1 (POST-V): Tmax avg 42.2°C post-VER, 5.20 heat days, VPD 7.2, dur 3.2\n")
cat("  C2 (PRE-V):  Tmax avg 40.1°C FL-VER, 2.94 heat days\n")
cat("  C3 (Cool):   Tmax avg 37.9°C, ~0 heat days\n")

# --- Save -------------------------------------------------------------------

# Create site-year to cluster mapping for downstream scripts
cluster_assignments <- data.frame(
  site_year = rownames(scaled_features),
  cluster   = clusters_labelled,
  stringsAsFactors = FALSE
) %>%
  tidyr::separate(site_year, into = c("Site", "Season"), sep = "_",
                  remove = FALSE, convert = TRUE)

save(hc, clusters, clusters_labelled, cluster_assignments,
     scaled_features, feature_matrix, cluster_detail,
     file = file.path(output_dir, "04_clusters.RData"))

cat("\n=== Section 5 Complete ===\n")
cat("Saved to:", file.path(output_dir, "04_clusters.RData"), "\n")
