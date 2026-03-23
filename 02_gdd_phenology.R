###############################################################################
# 02_gdd_phenology.R
# Reproduction of Previtali et al. (2026)
# Section 3: Phenological Data, GDD Calculation, and Imputation
###############################################################################

load("output/01_data_loaded.RData")

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(ggplot2)
})

cat("=== Section 3: Phenological Data and GDD ===\n\n")

# --- 3a. Convert phenological dates to DOY ----------------------------------

pheno <- db2_data %>%
  mutate(
    BB_DOY  = yday(Budbreak),
    FL_DOY  = yday(Flowering),
    VER_DOY = yday(Veraison),
    H_DOY   = yday(Harvest)
  )

# Merge harvest DOY from DB3 where available
# DB3 already has Avg_Harvest_DOY as numeric DOY
# If harvest spanned multiple days, DB3 contains the midpoint (as per plan)
harvest_info <- db3_data %>%
  select(Site, Block_ID, Season, Avg_Harvest_DOY)

pheno <- pheno %>%
  left_join(harvest_info, by = c("Site", "Block_ID", "Season")) %>%
  mutate(
    # Prefer DB3's Avg_Harvest_DOY (midpoint); fall back to DB2 harvest DOY
    H_DOY = coalesce(Avg_Harvest_DOY, H_DOY)
  )

cat("Phenological DOY summary:\n")
cat("  BB range:  ", range(pheno$BB_DOY, na.rm = TRUE), "\n")
cat("  FL range:  ", range(pheno$FL_DOY, na.rm = TRUE), "\n")
cat("  VER range: ", range(pheno$VER_DOY, na.rm = TRUE), "\n")
cat("  H range:   ", range(pheno$H_DOY, na.rm = TRUE), "\n")
cat("  BB NA count:", sum(is.na(pheno$BB_DOY)), "of", nrow(pheno), "\n")
cat("  FL NA count:", sum(is.na(pheno$FL_DOY)), "of", nrow(pheno), "\n")
cat("  VER NA count:", sum(is.na(pheno$VER_DOY)), "of", nrow(pheno), "\n")
cat("  H NA count:", sum(is.na(pheno$H_DOY)), "of", nrow(pheno), "\n\n")

# --- 3b. GDD calculation ---------------------------------------------------
# Base temperature: 10°C, no upper cap
# Start date: March 1 (paper selected this over Jan 1)

cat("Computing GDD from March 1 (base 10°C)...\n")

weather <- db1_data %>%
  mutate(
    Year = year(date),
    DOY  = yday(date),
    # March 1 is DOY 60 in non-leap years, DOY 61 in leap years
    Mar1_DOY = ifelse(leap_year(date), 61, 60),
    # GDD daily contribution (only count days from March 1 onward)
    GDD_daily = pmax(0, tmean - 10)
  )

# Cumulative GDD from March 1 for each site-year
gdd_cumulative <- weather %>%
  filter(DOY >= Mar1_DOY) %>%
  group_by(Site, Year) %>%
  arrange(DOY) %>%
  mutate(GDD_Mar1 = cumsum(GDD_daily)) %>%
  ungroup() %>%
  select(Site, Year, date, DOY, tmean, GDD_daily, GDD_Mar1)

# Also compute GDD from Jan 1 for comparison (Supplemental Figure 2)
gdd_jan1 <- weather %>%
  group_by(Site, Year) %>%
  arrange(DOY) %>%
  mutate(GDD_Jan1 = cumsum(GDD_daily)) %>%
  ungroup() %>%
  select(Site, Year, DOY, GDD_Jan1)

gdd_cumulative <- gdd_cumulative %>%
  left_join(gdd_jan1, by = c("Site", "Year", "DOY"))

cat("  GDD computed for", length(unique(paste(gdd_cumulative$Site, gdd_cumulative$Year))),
    "site-years\n\n")

# --- 3c. GDD at observed phenological stages --------------------------------

# Function: find GDD on a given DOY for a site-year
get_gdd_at_doy <- function(site, year, doy, gdd_df, gdd_col = "GDD_Mar1") {
  row <- gdd_df %>%
    filter(Site == site, Year == year, DOY == doy)
  if (nrow(row) == 0) return(NA_real_)
  return(row[[gdd_col]][1])
}

# Compute GDD at each observed phenological event
pheno_gdd <- pheno %>%
  rowwise() %>%
  mutate(
    GDD_Mar1_BB  = get_gdd_at_doy(Site, Season, BB_DOY, gdd_cumulative, "GDD_Mar1"),
    GDD_Mar1_FL  = get_gdd_at_doy(Site, Season, FL_DOY, gdd_cumulative, "GDD_Mar1"),
    GDD_Mar1_VER = get_gdd_at_doy(Site, Season, VER_DOY, gdd_cumulative, "GDD_Mar1"),
    GDD_Mar1_H   = get_gdd_at_doy(Site, Season, H_DOY, gdd_cumulative, "GDD_Mar1"),
    GDD_Jan1_BB  = get_gdd_at_doy(Site, Season, BB_DOY, gdd_cumulative, "GDD_Jan1"),
    GDD_Jan1_FL  = get_gdd_at_doy(Site, Season, FL_DOY, gdd_cumulative, "GDD_Jan1"),
    GDD_Jan1_VER = get_gdd_at_doy(Site, Season, VER_DOY, gdd_cumulative, "GDD_Jan1"),
    GDD_Jan1_H   = get_gdd_at_doy(Site, Season, H_DOY, gdd_cumulative, "GDD_Jan1")
  ) %>%
  ungroup()

cat("GDD thresholds at observed phenological events (mean ± sd):\n")
cat("  BB:   GDD_Mar1 =", round(mean(pheno_gdd$GDD_Mar1_BB, na.rm = TRUE)),
    "±", round(sd(pheno_gdd$GDD_Mar1_BB, na.rm = TRUE)), "\n")
cat("  FL:   GDD_Mar1 =", round(mean(pheno_gdd$GDD_Mar1_FL, na.rm = TRUE)),
    "±", round(sd(pheno_gdd$GDD_Mar1_FL, na.rm = TRUE)), "\n")
cat("  VER:  GDD_Mar1 =", round(mean(pheno_gdd$GDD_Mar1_VER, na.rm = TRUE)),
    "±", round(sd(pheno_gdd$GDD_Mar1_VER, na.rm = TRUE)), "\n")
cat("  H:    GDD_Mar1 =", round(mean(pheno_gdd$GDD_Mar1_H, na.rm = TRUE)),
    "±", round(sd(pheno_gdd$GDD_Mar1_H, na.rm = TRUE)), "\n\n")

# --- 3c (cont). Imputation of missing phenological records ------------------
# Priority order:
#   1. Site-specific average GDD threshold from years with observations
#   2. Year-specific average across sites
#   3. Long-term average across all sites and years (final fallback only)

cat("Imputing missing phenological records via GDD thresholds...\n")

impute_phenology <- function(pheno_df, gdd_df, stage_doy_col, gdd_col) {
  # Compute GDD thresholds from observed data
  observed <- pheno_df %>%
    filter(!is.na(.data[[stage_doy_col]]) & !is.na(.data[[gdd_col]]))

  # Priority 1: site-specific mean
  site_means <- observed %>%
    group_by(Site) %>%
    summarise(gdd_threshold = mean(.data[[gdd_col]], na.rm = TRUE), .groups = "drop")

  # Priority 2: year-specific mean
  year_means <- observed %>%
    group_by(Season) %>%
    summarise(gdd_threshold = mean(.data[[gdd_col]], na.rm = TRUE), .groups = "drop")

  # Priority 3: global mean
  global_mean <- mean(observed[[gdd_col]], na.rm = TRUE)

  # For each missing record, find the calendar date when threshold is reached
  missing_idx <- which(is.na(pheno_df[[stage_doy_col]]))
  imputed_doys <- pheno_df[[stage_doy_col]]

  for (i in missing_idx) {
    site <- pheno_df$Site[i]
    year <- pheno_df$Season[i]

    # Determine threshold: priority order
    threshold <- site_means$gdd_threshold[site_means$Site == site]
    if (length(threshold) == 0 || is.na(threshold)) {
      threshold <- year_means$gdd_threshold[year_means$Season == year]
    }
    if (length(threshold) == 0 || is.na(threshold)) {
      threshold <- global_mean
    }

    # Find DOY when GDD first exceeds threshold
    gdd_series <- gdd_df %>%
      filter(Site == site, Year == year) %>%
      arrange(DOY)

    reached <- gdd_series %>% filter(GDD_Mar1 >= threshold)
    if (nrow(reached) > 0) {
      imputed_doys[i] <- reached$DOY[1]
    } else {
      # Fallback if threshold is never reached before end of year 
      # (occurs in exceptionally cool years like 2010/2011 where max GDD < threshold)
      # We assign the date of maximum accumulated GDD, which is typically the end of October.
      if (nrow(gdd_series) > 0) {
        imputed_doys[i] <- max(gdd_series$DOY[month(gdd_series$date) <= 10], na.rm = TRUE)
      } else {
        imputed_doys[i] <- 304 # End of October default
      }
    }
  }

  return(imputed_doys)
}

# Map GDD column names for each stage
gdd_stage_map <- list(
  BB_DOY  = "GDD_Mar1_BB",
  FL_DOY  = "GDD_Mar1_FL",
  VER_DOY = "GDD_Mar1_VER",
  H_DOY   = "GDD_Mar1_H"
)

pheno_imputed <- pheno_gdd
for (stage in names(gdd_stage_map)) {
  n_missing <- sum(is.na(pheno_imputed[[stage]]))
  pheno_imputed[[stage]] <- impute_phenology(
    pheno_imputed, gdd_cumulative, stage, gdd_stage_map[[stage]]
  )
  n_filled <- n_missing - sum(is.na(pheno_imputed[[stage]]))
  cat(sprintf("  %s: %d missing -> %d imputed (%d still missing)\n",
              stage, n_missing, n_filled,
              sum(is.na(pheno_imputed[[stage]]))))
}

# --- 3d. Create site-year phenology summary --------------------------------

# The paper specifies ~213 site-year combinations. DB2 only contains a subset (77).
# We must build a full grid of Site x Season from the weather data (DB1) 
# to calculate features and impute phenology for ALL available weather years.

weather_site_years <- weather %>%
  group_by(Site, Year) %>%
  summarise(n_days = n(), .groups = "drop") %>%
  # Filter to full years (365/366 days)
  filter(n_days >= 365) %>%
  rename(Season = Year)

# Aggregate available phenology to site-year level
obs_site_year_pheno <- pheno_imputed %>%
  group_by(Site, Season) %>%
  summarise(
    BB_DOY  = round(mean(BB_DOY, na.rm = TRUE)),
    FL_DOY  = round(mean(FL_DOY, na.rm = TRUE)),
    VER_DOY = round(mean(VER_DOY, na.rm = TRUE)),
    H_DOY   = round(mean(H_DOY, na.rm = TRUE)),
    .groups = "drop"
  )

# Merge to create the full 213 site-year grid
site_year_pheno <- weather_site_years %>%
  left_join(obs_site_year_pheno, by = c("Site", "Season"))

cat("Before final imputation, full grid has", nrow(site_year_pheno), "site-years.\n")

# Now we must impute the completely missing site-years in the summary table
# using the exact same 3-level priority logic as before.
sy_impute <- site_year_pheno %>%
  left_join(
    gdd_cumulative %>% select(Site, Season = Year, DOY, GDD_Mar1), 
    by = c("Site", "Season")
  ) %>%
  nest_by(Site, Season, BB_DOY, FL_DOY, VER_DOY, H_DOY, .key = "gdd_series")

# Get thresholds from earlier
# Priority 1: site-specific mean
obs_for_thresh <- pheno_gdd %>% filter(!is.na(BB_DOY) & !is.na(GDD_Mar1_BB)) 
site_th_bb <- obs_for_thresh %>% group_by(Site) %>% summarise(th = mean(GDD_Mar1_BB), .groups="drop")
gmean_bb   <- mean(obs_for_thresh$GDD_Mar1_BB)

obs_for_thresh <- pheno_gdd %>% filter(!is.na(FL_DOY) & !is.na(GDD_Mar1_FL)) 
site_th_fl <- obs_for_thresh %>% group_by(Site) %>% summarise(th = mean(GDD_Mar1_FL), .groups="drop")
gmean_fl   <- mean(obs_for_thresh$GDD_Mar1_FL)

obs_for_thresh <- pheno_gdd %>% filter(!is.na(VER_DOY) & !is.na(GDD_Mar1_VER)) 
site_th_ver <- obs_for_thresh %>% group_by(Site) %>% summarise(th = mean(GDD_Mar1_VER), .groups="drop")
gmean_ver   <- mean(obs_for_thresh$GDD_Mar1_VER)

obs_for_thresh <- pheno_gdd %>% filter(!is.na(H_DOY) & !is.na(GDD_Mar1_H)) 
site_th_h <- obs_for_thresh %>% group_by(Site) %>% summarise(th = mean(GDD_Mar1_H), .groups="drop")
gmean_h   <- mean(obs_for_thresh$GDD_Mar1_H)

find_doy <- function(gdd_series, threshold) {
  reached <- gdd_series %>% filter(GDD_Mar1 >= threshold)
  if (nrow(reached) > 0) return(reached$DOY[1])
  if (nrow(gdd_series) > 0) return(max(gdd_series$DOY[month(gdd_series$date) <= 10], na.rm=TRUE)) # fallback
  return(NA)
}

site_year_pheno <- site_year_pheno %>%
  rowwise() %>%
  mutate(
    BB_DOY = ifelse(!is.na(BB_DOY), BB_DOY, {
      th <- site_th_bb$th[site_th_bb$Site == Site]
      if(length(th)==0) th <- gmean_bb
      gdd <- gdd_cumulative %>% filter(Site == .env$Site, Year == .env$Season)
      find_doy(gdd, th)
    }),
    FL_DOY = ifelse(!is.na(FL_DOY), FL_DOY, {
      th <- site_th_fl$th[site_th_fl$Site == Site]
      if(length(th)==0) th <- gmean_fl
      gdd <- gdd_cumulative %>% filter(Site == .env$Site, Year == .env$Season)
      find_doy(gdd, th)
    }),
    VER_DOY = ifelse(!is.na(VER_DOY), VER_DOY, {
      th <- site_th_ver$th[site_th_ver$Site == Site]
      if(length(th)==0) th <- gmean_ver
      gdd <- gdd_cumulative %>% filter(Site == .env$Site, Year == .env$Season)
      find_doy(gdd, th)
    }),
    H_DOY = ifelse(!is.na(H_DOY), H_DOY, {
      th <- site_th_h$th[site_th_h$Site == Site]
      if(length(th)==0) th <- gmean_h
      gdd <- gdd_cumulative %>% filter(Site == .env$Site, Year == .env$Season)
      find_doy(gdd, th)
    })
  ) %>%
  ungroup()

cat("\nSite-year phenology records (after full grid imputation):", nrow(site_year_pheno), "\n")
cat("Expected: ~213 site-year combinations\n")

# --- Save -------------------------------------------------------------------

save(pheno_imputed, site_year_pheno, gdd_cumulative, pheno_gdd,
     file = file.path(output_dir, "02_phenology.RData"))

cat("\n=== Section 3 Complete ===\n")
cat("Saved to:", file.path(output_dir, "02_phenology.RData"), "\n")
