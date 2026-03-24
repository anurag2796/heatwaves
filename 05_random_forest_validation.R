###############################################################################
# 05_random_forest_validation.R
# Cleaned Random Forest using stratified 50:50 splits
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

n_iter <- 50
n_trees <- 500
m_try <- 7

y_labels <- site_year_pheno$cluster
n_obs <- nrow(scaled_features)

cat(sprintf("Parameters: ntree=%d, mtry=%d, n_iter=%d, Stratified 50:50 split\n", n_trees, m_try, n_iter))
cat(sprintf("Data: %d observations, %d features\n\n", n_obs, ncol(scaled_features)))

cat("Running bootstrap iterations:\n")
ter_vec <- numeric(n_iter)
mda_matrix <- matrix(0, nrow = ncol(scaled_features), ncol = n_iter)
rownames(mda_matrix) <- colnames(scaled_features)

for (i in 1:n_iter) {
  # Stratified 50:50 Train/Test split
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

cat("\n=== TER Results ===\n")
cat(sprintf("  Mean TER:   %.2f%%\n", mean(ter_vec)))
cat(sprintf("  Median TER: %.2f%%\n", median(ter_vec)))
cat(sprintf("  Max TER:    %.2f%%\n", max(ter_vec)))
cat(sprintf("  Min TER:    %.2f%%\n", min(ter_vec)))
cat(sprintf("  SD TER:     %.2f%%\n", sd(ter_vec)))

mean_mda <- rowMeans(mda_matrix)
top_features <- sort(mean_mda, decreasing = TRUE)

cat("\n=== Top 20 Features by Mean Decrease Accuracy ===\n")
top_20_names <- names(top_features)[1:20]
for (j in 1:20) {
  cat(sprintf("  %2d. %-35s MDA = %.3f\n", j, top_20_names[j], top_features[j]))
}

cat("\n=== Verification: Top 8 features ===\n")
top_8 <- names(top_features)[1:8]
cat("  Top 8 features:\n")
for (f in top_8) cat("    ", f, "\n")

is_fl_ver <- grepl("BLtoVER|preV", top_8) 
cat(sprintf("  All FL-VER related?: %s (%d of 8)\n", ifelse(sum(is_fl_ver)==8, "YES", "NO"), sum(is_fl_ver)))

mda_df <- data.frame(Feature = names(mean_mda), MDA = mean_mda) %>% arrange(desc(MDA))
save(ter_vec, mda_df, file = "output/05_rf_validation.RData")

cat("\n=== Section 6 Complete ===\n")