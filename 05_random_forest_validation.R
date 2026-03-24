###############################################################################
# 05_random_forest_validation.R
# Reproduction of Previtali et al. (2026)
# Section 6: Bootstrap Random Forest Validation
#
# P0-2 fix: add OOB-based TER (primary) alongside stratified split (secondary)
###############################################################################

load("output/04_clusters.RData")

suppressPackageStartupMessages({
  library(randomForest)
  library(dplyr)
})

cat("=== Section 6: Bootstrap Random Forest Validation ===\n\n")

SEED <- 42
set.seed(SEED)
cat("Random seed:", SEED, "\n")

n_trees <- 500
m_try   <- floor(sqrt(ncol(scaled_features)))  # default for classification RF

y_labels <- site_year_pheno$cluster
n_obs    <- nrow(scaled_features)

cat(sprintf("Data: %d observations, %d features\n\n", n_obs, ncol(scaled_features)))

# ============================================================================
# PRIMARY METHOD: Full-data RF with OOB error
# The paper reports TER ~1.35%. RF's internal OOB mechanism uses bootstrap
# sampling (~63% train / 37% test per tree), which is the standard way to
# report RF classification error without a separate holdout.
# ============================================================================

cat("=== PRIMARY: OOB-based Random Forest ===\n")
cat(sprintf("Parameters: ntree=%d, mtry=%d (sqrt(p)=%d)\n", n_trees, m_try, m_try))

rf_oob <- randomForest(
  x = scaled_features,
  y = y_labels,
  ntree = n_trees,
  mtry = m_try,
  importance = TRUE
)

oob_ter <- rf_oob$err.rate[n_trees, "OOB"] * 100

cat(sprintf("\n  OOB Total Error Rate: %.2f%%\n", oob_ter))
cat(sprintf("  Paper target:        ~1.35%%\n"))

# Per-class OOB error
cat("\n  Per-class OOB error rates:\n")
for (cl in levels(y_labels)) {
  cl_err <- rf_oob$err.rate[n_trees, cl] * 100
  cat(sprintf("    %s: %.2f%%\n", cl, cl_err))
}

cat("\n  OOB Confusion matrix:\n")
print(rf_oob$confusion)

# Variable importance from the full OOB model
oob_mda <- importance(rf_oob, type = 1)[, 1]
oob_mda_sorted <- sort(oob_mda, decreasing = TRUE)

cat("\n=== Top 20 Features by Mean Decrease Accuracy (OOB) ===\n")
top_20_names <- names(oob_mda_sorted)[1:20]
for (j in 1:20) {
  cat(sprintf("  %2d. %-35s MDA = %.3f\n", j, top_20_names[j], oob_mda_sorted[j]))
}

cat("\n=== Verification: Top 8 features (OOB) ===\n")
top_8 <- names(oob_mda_sorted)[1:8]
cat("  Top 8 features:\n")
for (f in top_8) cat("    ", f, "\n")

is_fl_ver <- grepl("FLtoVER|preV", top_8)
cat(sprintf("  FL-VER/Pre-V related: %d of 8\n", sum(is_fl_ver)))

# ============================================================================
# SECONDARY METHOD: Bootstrap stratified 50:50 split (stress test)
# ============================================================================

cat("\n=== SECONDARY: Bootstrap Stratified 50:50 Split (Stress Test) ===\n")

n_iter <- 50
cat(sprintf("Parameters: ntree=%d, mtry=%d, n_iter=%d\n\n", n_trees, m_try, n_iter))

set.seed(SEED)
ter_vec <- numeric(n_iter)
mda_matrix <- matrix(0, nrow = ncol(scaled_features), ncol = n_iter)
rownames(mda_matrix) <- colnames(scaled_features)

cat("Running bootstrap iterations:\n")
for (i in 1:n_iter) {
  train_idx <- c()
  for (c_level in levels(y_labels)) {
    idx <- which(y_labels == c_level)
    train_idx <- c(train_idx, sample(idx, size = floor(length(idx) * 0.5)))
  }
  
  test_idx <- setdiff(seq_len(n_obs), train_idx)
  
  rf_mod <- randomForest(
    x = scaled_features[train_idx, ],
    y = y_labels[train_idx],
    ntree = n_trees,
    mtry = m_try,
    importance = TRUE
  )
  
  preds <- predict(rf_mod, scaled_features[test_idx, ])
  ter_vec[i] <- mean(preds != y_labels[test_idx]) * 100
  
  imp <- importance(rf_mod, type = 1)
  mda_matrix[, i] <- imp[, 1]
  
  if (i %% 10 == 0) cat(sprintf("  Iteration %d/%d: TER = %.2f%%\n", i, n_iter, ter_vec[i]))
}

cat("\n  Stress-test TER Results:\n")
cat(sprintf("    Mean TER:   %.2f%%\n", mean(ter_vec)))
cat(sprintf("    Median TER: %.2f%%\n", median(ter_vec)))
cat(sprintf("    Range:      %.2f%% – %.2f%%\n", min(ter_vec), max(ter_vec)))

# ============================================================================
# Save outputs
# ============================================================================

# Use OOB MDA as the primary feature importance
mean_mda <- oob_mda
mda_df <- data.frame(Feature = names(mean_mda), MDA = as.numeric(mean_mda)) %>% arrange(desc(MDA))

# Save both OOB and bootstrap TER
save(oob_ter, ter_vec, mda_df, rf_oob, file = "output/05_rf_validation.RData")

cat("\n=== Section 6 Complete ===\n")