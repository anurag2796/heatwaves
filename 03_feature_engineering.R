###############################################################################
# 03_feature_engineering.R
# Reproduction of Previtali et al. (2026)
# Section 4: Feature Engineering (~200+ features)
###############################################################################

load("output/01_data_loaded.RData")
load("output/02_phenology.RData")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(lubridate)
})

cat("=== Section 4: Feature Engineering ===\n\n")

# --- 4a. Core definitions ---------------------------------------------------
# Heat day:  Tmax >= 38°C
# Heatwave:  >= 2 consecutive heat days
# HWU:       sum(Tmax - 38) across all days of a heatwave (positive deviations)

HEAT_THRESHOLD <- 38  # degrees C
MIN_HW_DAYS    <- 2   # minimum consecutive days for a heatwave

# --- 4b. Helper function: compute heat features for a date range -----------

compute_heat_features <- function(weather_subset) {
  # weather_subset: data.frame with columns tmax, tmin, tmean, rain, vpdmin, vpdmax, DOY
  # Returns a named vector of features

  if (nrow(weather_subset) == 0) {
    return(c(
      mean_tmax = NA, mean_tmin = NA, mean_tavg = NA,
      total_precip = NA, mean_vpdmin = NA, mean_vpdmax = NA,
      n_heat_days = 0, n_heatwaves = 0, total_hwu = 0,
      avg_hw_duration = 0, max_hw_duration = 0, max_hw_vpd = 0, avg_hw_vpd = 0, n_days = 0
    ))
  }

  # Basic climate stats
  mean_tmax   <- mean(weather_subset$tmax, na.rm = TRUE)
  mean_tmin   <- mean(weather_subset$tmin, na.rm = TRUE)
  mean_tavg   <- mean(weather_subset$tmean, na.rm = TRUE)
  total_precip <- sum(weather_subset$rain, na.rm = TRUE)
  mean_vpdmin <- mean(weather_subset$vpdmin, na.rm = TRUE)
  mean_vpdmax <- mean(weather_subset$vpdmax, na.rm = TRUE)

  # Heat day identification
  heat_days   <- weather_subset$tmax >= HEAT_THRESHOLD
  n_heat_days <- sum(heat_days, na.rm = TRUE)

  # Heatwave detection: runs of >= 2 consecutive heat days
  n_heatwaves    <- 0
  total_hwu      <- 0
  hw_durations   <- c()
  hw_vpds        <- c()
  hw_all_vpds    <- c()

  if (n_heat_days >= MIN_HW_DAYS) {
    # Find runs of consecutive heat days
    rle_heat <- rle(heat_days)
    hw_mask  <- rle_heat$values == TRUE & rle_heat$lengths >= MIN_HW_DAYS
    n_heatwaves <- sum(hw_mask)

    if (n_heatwaves > 0) {
      # Extract each heatwave's properties
      end_pos <- cumsum(rle_heat$lengths)
      start_pos <- end_pos - rle_heat$lengths + 1

      for (j in which(hw_mask)) {
        hw_rows <- weather_subset[start_pos[j]:end_pos[j], ]
        hw_durations <- c(hw_durations, nrow(hw_rows))

        # HWU = sum(Tmax - 38) for positive deviations
        hwu <- sum(pmax(0, hw_rows$tmax - HEAT_THRESHOLD))
        total_hwu <- total_hwu + hwu

        # Max VPDmax during this heatwave
        hw_vpds <- c(hw_vpds, max(hw_rows$vpdmax, na.rm = TRUE))
        hw_all_vpds <- c(hw_all_vpds, hw_rows$vpdmax)
      }
    }
  }

  avg_hw_duration <- ifelse(length(hw_durations) > 0, mean(hw_durations), 0)
  max_hw_duration <- ifelse(length(hw_durations) > 0, max(hw_durations), 0)
  max_hw_vpd      <- ifelse(length(hw_vpds) > 0, max(hw_vpds), 0)
  avg_hw_vpd      <- ifelse(length(hw_all_vpds) > 0, mean(hw_all_vpds, na.rm = TRUE), 0)

  c(
    mean_tmax = mean_tmax, mean_tmin = mean_tmin, mean_tavg = mean_tavg,
    total_precip = total_precip, mean_vpdmin = mean_vpdmin, mean_vpdmax = mean_vpdmax,
    n_heat_days = n_heat_days, n_heatwaves = n_heatwaves, total_hwu = total_hwu,
    avg_hw_duration = avg_hw_duration, max_hw_duration = max_hw_duration, 
    max_hw_vpd = max_hw_vpd, avg_hw_vpd = avg_hw_vpd,
    n_days = nrow(weather_subset)
  )
}

# --- 4c. Build feature matrix for all site-years ---------------------------

# Add year info to weather
weather <- db1_data %>%
  mutate(Year = year(date), DOY = yday(date))

# Define month windows (April=4 through October=10)
months_list <- setNames(4:10, month.name[4:10])

# We iterate over site_year_pheno (the ~213 site-year combos after imputation)
cat("Building feature matrix for", nrow(site_year_pheno), "site-years...\n")

all_features <- list()

for (i in 1:nrow(site_year_pheno)) {
  sy <- site_year_pheno[i, ]
  site <- sy$Site
  year <- sy$Season

  w <- weather %>% filter(Site == site, Year == year)

  if (nrow(w) == 0) next

  features <- c()
  feature_names <- c()

  # --- Monthly features (April through October) ---
  for (m in 4:10) {
    m_name <- month.abb[m]
    w_month <- w %>% filter(month(date) == m)
    f <- compute_heat_features(w_month)
    # Drop max_hw_duration and avg_hw_vpd as they are not listed for monthly
    f <- f[!names(f) %in% c("max_hw_duration", "avg_hw_vpd")]
    names(f) <- paste0(m_name, "_", names(f))
    features <- c(features, f)
    feature_names <- c(feature_names, names(f))
  }

  # --- Seasonal chronological aggregations ---
  # Full season: April-October
  w_full <- w %>% filter(month(date) >= 4 & month(date) <= 10)
  f_full <- compute_heat_features(w_full)
  f_full <- f_full[!names(f_full) %in% c("max_hw_duration", "avg_hw_vpd")]
  names(f_full) <- paste0("Full_", names(f_full))
  features <- c(features, f_full)

  # Early season: May-July
  w_early <- w %>% filter(month(date) >= 5 & month(date) <= 7)
  f_early <- compute_heat_features(w_early)
  f_early <- f_early[!names(f_early) %in% c("max_hw_duration", "avg_hw_vpd")]
  names(f_early) <- paste0("Early_", names(f_early))
  features <- c(features, f_early)

  # Late season: August-October
  w_late <- w %>% filter(month(date) >= 8 & month(date) <= 10)
  f_late <- compute_heat_features(w_late)
  f_late <- f_late[!names(f_late) %in% c("max_hw_duration", "avg_hw_vpd")]
  names(f_late) <- paste0("Late_", names(f_late))
  features <- c(features, f_late)

  # --- Phenological interval features ---
  # BB to FL
  if (!is.na(sy$BB_DOY) && !is.na(sy$FL_DOY) && sy$FL_DOY > sy$BB_DOY) {
    w_bb_fl <- w %>% filter(DOY >= sy$BB_DOY & DOY <= sy$FL_DOY)
    f_bb_fl <- compute_heat_features(w_bb_fl)
    names(f_bb_fl) <- paste0("BB_FL_", names(f_bb_fl))
    features <- c(features, f_bb_fl)
  } else {
    f_bb_fl <- rep(NA, 14)
    names(f_bb_fl) <- paste0("BB_FL_", c("mean_tmax", "mean_tmin", "mean_tavg",
      "total_precip", "mean_vpdmin", "mean_vpdmax", "n_heat_days", "n_heatwaves",
      "total_hwu", "avg_hw_duration", "max_hw_duration", "max_hw_vpd", "avg_hw_vpd", "n_days"))
    features <- c(features, f_bb_fl)
  }

  # FL to VER  <- highest importance for clustering; do not skip
  if (!is.na(sy$FL_DOY) && !is.na(sy$VER_DOY) && sy$VER_DOY > sy$FL_DOY) {
    w_fl_ver <- w %>% filter(DOY >= sy$FL_DOY & DOY <= sy$VER_DOY)
    f_fl_ver <- compute_heat_features(w_fl_ver)
    names(f_fl_ver) <- paste0("FL_VER_", names(f_fl_ver))
    features <- c(features, f_fl_ver)
  } else {
    f_fl_ver <- rep(NA, 14)
    names(f_fl_ver) <- paste0("FL_VER_", c("mean_tmax", "mean_tmin", "mean_tavg",
      "total_precip", "mean_vpdmin", "mean_vpdmax", "n_heat_days", "n_heatwaves",
      "total_hwu", "avg_hw_duration", "max_hw_duration", "max_hw_vpd", "avg_hw_vpd", "n_days"))
    features <- c(features, f_fl_ver)
  }

  # VER to H
  if (!is.na(sy$VER_DOY) && !is.na(sy$H_DOY) && sy$H_DOY > sy$VER_DOY) {
    w_ver_h <- w %>% filter(DOY >= sy$VER_DOY & DOY <= sy$H_DOY)
    f_ver_h <- compute_heat_features(w_ver_h)
    names(f_ver_h) <- paste0("VER_H_", names(f_ver_h))
    features <- c(features, f_ver_h)
  } else {
    f_ver_h <- rep(NA, 14)
    names(f_ver_h) <- paste0("VER_H_", c("mean_tmax", "mean_tmin", "mean_tavg",
      "total_precip", "mean_vpdmin", "mean_vpdmax", "n_heat_days", "n_heatwaves",
      "total_hwu", "avg_hw_duration", "max_hw_duration", "max_hw_vpd", "avg_hw_vpd", "n_days"))
    features <- c(features, f_ver_h)
  }

  # BB to H (full phenological season)
  if (!is.na(sy$BB_DOY) && !is.na(sy$H_DOY) && sy$H_DOY > sy$BB_DOY) {
    w_bb_h <- w %>% filter(DOY >= sy$BB_DOY & DOY <= sy$H_DOY)
    f_bb_h <- compute_heat_features(w_bb_h)
    names(f_bb_h) <- paste0("BB_H_", names(f_bb_h))
    features <- c(features, f_bb_h)
  } else {
    f_bb_h <- rep(NA, 14)
    names(f_bb_h) <- paste0("BB_H_", c("mean_tmax", "mean_tmin", "mean_tavg",
      "total_precip", "mean_vpdmin", "mean_vpdmax", "n_heat_days", "n_heatwaves",
      "total_hwu", "avg_hw_duration", "max_hw_duration", "max_hw_vpd", "avg_hw_vpd", "n_days"))
    features <- c(features, f_bb_h)
  }

  # Add phenological DOYs as features
  pheno_feats <- c(
    BB_DOY  = sy$BB_DOY,
    FL_DOY  = sy$FL_DOY,
    VER_DOY = sy$VER_DOY,
    H_DOY   = sy$H_DOY,
    BB_FL_interval  = sy$FL_DOY - sy$BB_DOY,
    FL_VER_interval = sy$VER_DOY - sy$FL_DOY,
    VER_H_interval  = sy$H_DOY - sy$VER_DOY,
    BB_H_interval   = sy$H_DOY - sy$BB_DOY
  )
  features <- c(features, pheno_feats)

  all_features[[i]] <- features
}

# Combine into matrix
feature_matrix <- do.call(rbind, all_features)
rownames(feature_matrix) <- paste(site_year_pheno$Site,
                                   site_year_pheno$Season, sep = "_")

cat("  Raw feature matrix:", nrow(feature_matrix), "x", ncol(feature_matrix), "\n")

# --- 4d. Handle NA and zero-variance columns --------------------------------

# Remove columns that are entirely NA
na_cols <- colSums(is.na(feature_matrix)) == nrow(feature_matrix)
cat("  Columns entirely NA:", sum(na_cols), "\n")
feature_matrix <- feature_matrix[, !na_cols]

# For remaining NAs, impute with column median
for (j in 1:ncol(feature_matrix)) {
  na_mask <- is.na(feature_matrix[, j])
  if (any(na_mask)) {
    feature_matrix[na_mask, j] <- median(feature_matrix[, j], na.rm = TRUE)
  }
}

# Remove zero-variance columns (can't be scaled)
variances <- apply(feature_matrix, 2, var)
zero_var <- variances == 0 | is.na(variances)
cat("  Zero-variance columns removed:", sum(zero_var), "\n")
feature_matrix <- feature_matrix[, !zero_var]

cat("  Final feature matrix:", nrow(feature_matrix), "x", ncol(feature_matrix), "\n")
cat("  Expected: ~213 rows x ~200+ columns\n\n")

# --- 4e. Z-score normalisation ---------------------------------------------

scaled_features <- scale(feature_matrix)

# Verify: mean=0, sd=1 per column
cat("Normalisation check:\n")
cat("  Column means (should be ~0):", round(mean(colMeans(scaled_features)), 6), "\n")
cat("  Column SDs (should be ~1):", round(mean(apply(scaled_features, 2, sd)), 6), "\n\n")

# --- Save -------------------------------------------------------------------

save(feature_matrix, scaled_features, site_year_pheno,
     HEAT_THRESHOLD, MIN_HW_DAYS,
     file = file.path(output_dir, "03_features.RData"))

cat("=== Section 4 Complete ===\n")
cat("  Features:", ncol(scaled_features), "\n")
cat("  Site-years:", nrow(scaled_features), "\n")
cat("Saved to:", file.path(output_dir, "03_features.RData"), "\n")
