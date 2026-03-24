###############################################################################
# R/utils/gdd_utils.R
# GDD and phenological imputation helpers
# Extracted from 02_gdd_phenology.R
###############################################################################

#' Look up GDD value at a specific DOY for a given site-year
#'
#' @param site Site ID (e.g., "S1")
#' @param year Growing season year
#' @param doy Day of year
#' @param gdd_df Data frame with columns: Site, Year, DOY, and the GDD column
#' @param gdd_col Name of the GDD column to look up (default: "GDD_Mar1")
#' @return Numeric GDD value, or NA if not found
get_gdd_at_doy <- function(site, year, doy, gdd_df, gdd_col = "GDD_Mar1") {
  row <- gdd_df %>%
    dplyr::filter(Site == site, Year == year, DOY == doy)
  if (nrow(row) == 0) return(NA_real_)
  return(row[[gdd_col]][1])
}

#' Find the DOY when cumulative GDD first reaches a threshold
#'
#' @param gdd_series Data frame with columns: DOY, GDD_Mar1, date
#' @param threshold GDD threshold to reach
#' @return DOY (integer), or end-of-October fallback
find_doy_for_threshold <- function(gdd_series, threshold) {
  reached <- gdd_series %>% dplyr::filter(GDD_Mar1 >= threshold)
  if (nrow(reached) > 0) return(reached$DOY[1])
  # Fallback: last DOY in October if threshold never reached
  if (nrow(gdd_series) > 0) {
    oct_days <- gdd_series$DOY[lubridate::month(gdd_series$date) <= 10]
    return(max(oct_days, na.rm = TRUE))
  }
  return(304L)  # End of October default
}

#' Impute missing phenological DOY values using GDD thresholds
#'
#' Priority: (1) site-specific mean, (2) year-specific mean, (3) global mean
#'
#' @param pheno_df Phenology data frame
#' @param gdd_df Cumulative GDD data frame
#' @param stage_doy_col Column name for target DOY (e.g., "BB_DOY")
#' @param gdd_col Column name for the GDD at that stage (e.g., "GDD_Mar1_BB")
#' @return Numeric vector of imputed DOY values
impute_phenology <- function(pheno_df, gdd_df, stage_doy_col, gdd_col) {
  observed <- pheno_df %>%
    dplyr::filter(!is.na(.data[[stage_doy_col]]) & !is.na(.data[[gdd_col]]))

  # Priority 1: site-specific mean threshold
  site_means <- observed %>%
    dplyr::group_by(Site) %>%
    dplyr::summarise(gdd_threshold = mean(.data[[gdd_col]], na.rm = TRUE), .groups = "drop")

  # Priority 2: year-specific mean threshold
  year_means <- observed %>%
    dplyr::group_by(Season) %>%
    dplyr::summarise(gdd_threshold = mean(.data[[gdd_col]], na.rm = TRUE), .groups = "drop")

  # Priority 3: global mean threshold
  global_mean <- mean(observed[[gdd_col]], na.rm = TRUE)

  missing_idx <- which(is.na(pheno_df[[stage_doy_col]]))
  imputed_doys <- pheno_df[[stage_doy_col]]

  for (i in missing_idx) {
    site <- pheno_df$Site[i]
    year <- pheno_df$Season[i]

    threshold <- site_means$gdd_threshold[site_means$Site == site]
    if (length(threshold) == 0 || is.na(threshold)) {
      threshold <- year_means$gdd_threshold[year_means$Season == year]
    }
    if (length(threshold) == 0 || is.na(threshold)) {
      threshold <- global_mean
    }

    gdd_series <- gdd_df %>%
      dplyr::filter(Site == site, Year == year) %>%
      dplyr::arrange(DOY)

    imputed_doys[i] <- find_doy_for_threshold(gdd_series, threshold)
  }

  return(imputed_doys)
}
