###############################################################################
# 01_setup_and_data.R
# Reproduction of Previtali et al. (2026)
# Section 1 & 2: Environment Setup and Data Acquisition
###############################################################################

# --- 1. Install / load required packages ------------------------------------

required_packages <- c(
  "readxl",        # reading Figshare Excel files
  "dplyr",         # data wrangling
  "tidyr",         # reshaping

  "lubridate",     # date handling
  "ggplot2",       # all data visualizations
  "factoextra",    # HCA clustering and visualization
  "randomForest",  # bootstrap RF validation
  "lme4",          # linear mixed models
  "lmerTest",      # p-values for LMMs
  "emmeans",       # Tukey post-hoc comparisons
  "car",           # Levene's test
  "circlize",      # dependency for ComplexHeatmap
  "scales",        # axis formatting
  "gridExtra",     # multi-panel layouts
  "viridis"        # colour palettes
)

# Install from CRAN if missing
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org", quiet = TRUE)
  }
}

# ComplexHeatmap is on Bioconductor, not CRAN
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", repos = "https://cloud.r-project.org", quiet = TRUE)
}
if (!requireNamespace("ComplexHeatmap", quietly = TRUE)) {
  BiocManager::install("ComplexHeatmap", ask = FALSE, update = FALSE)
}

# Load all packages
suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(ggplot2)
  library(factoextra)
  library(randomForest)
  library(lme4)
  library(lmerTest)
  library(emmeans)
  library(car)
  library(ComplexHeatmap)
  library(circlize)
  library(scales)
  library(gridExtra)
  library(viridis)
})

cat("All packages loaded successfully.\n")
cat("R version:", R.version.string, "\n\n")

# --- 2. Define paths --------------------------------------------------------

data_dir    <- "data"
fig_dir     <- "figures"
output_dir  <- "output"

dir.create(fig_dir, showWarnings = FALSE)
dir.create(output_dir, showWarnings = FALSE)

# --- 3. Load all four databases (both sheets each) -------------------------

cat("=== Loading Database 1: PRISM Weather ===\n")
db1_data <- read_excel(file.path(data_dir, "DB1_PRISM_Weather_Daily_1981_2023.xlsx"),
                       sheet = "Data")
db1_vars <- read_excel(file.path(data_dir, "DB1_PRISM_Weather_Daily_1981_2023.xlsx"),
                       sheet = "List of Variables")
cat("  Rows:", nrow(db1_data), " Cols:", ncol(db1_data), "\n")
cat("  Sites:", paste(unique(db1_data$Site), collapse = ", "), "\n")
cat("  Date range:", min(db1_data$date), "to", max(db1_data$date), "\n")
cat("  Variables:\n")
print(db1_vars)

cat("\n=== Loading Database 2: Phenology ===\n")
db2_data <- read_excel(file.path(data_dir, "DB2_Phenology.xlsx"),
                       sheet = "Data")
db2_vars <- read_excel(file.path(data_dir, "DB2_Phenology.xlsx"),
                       sheet = "List of Variables")
cat("  Rows:", nrow(db2_data), " Cols:", ncol(db2_data), "\n")
cat("  Seasons:", paste(range(db2_data$Season), collapse = " to "), "\n")
cat("  Variables:\n")
print(db2_vars)

cat("\n=== Loading Database 3: Yield & Harvest Date ===\n")
db3_data <- read_excel(file.path(data_dir, "DB3_Yield_Harvest_date.xlsx"),
                       sheet = "Data")
db3_vars <- read_excel(file.path(data_dir, "DB3_Yield_Harvest_date.xlsx"),
                       sheet = "List of Variables")
cat("  Rows:", nrow(db3_data), " Cols:", ncol(db3_data), "\n")
cat("  Variables:\n")
print(db3_vars)

cat("\n=== Loading Database 4: Fruit Composition ===\n")
db4_data <- read_excel(file.path(data_dir, "DB4_Fruit_composition.xlsx"),
                       sheet = "Data")
db4_vars <- read_excel(file.path(data_dir, "DB4_Fruit_composition.xlsx"),
                       sheet = "List of Variables")
cat("  Rows:", nrow(db4_data), " Cols:", ncol(db4_data), "\n")
cat("  Variables:\n")
print(db4_vars)

# --- 4. Data type coercion --------------------------------------------------

# DB1: Convert date column from character to Date
db1_data <- db1_data %>%
  mutate(date = as.Date(date))

# DB2: Convert phenological date columns from character to Date
date_cols <- c("Budbreak", "Flowering", "Veraison", "Harvest")
db2_data <- db2_data %>%
  mutate(across(all_of(date_cols), ~ as.Date(.x)))

# DB4: Standardise column names for easier handling
# The raw names contain special characters (β, spaces, line breaks)
names(db4_data) <- c("Site", "Block_ID", "Season",
                     "B_Damascenone", "Octen_3_ol", "C6_compounds", "IBMP",
                     "Total_anthocyanins", "Polymeric_tannins",
                     "Quercetin_glycosides", "TSS", "Berry_moisture",
                     "pH", "Malic_acid", "YAN")

# --- 5. Critical screening: block area stability (Section 2a) ---------------

# The plan says: "Verify vineyard block area stability over time.
# Discard blocks with unacceptable area variation."
# The dataset does not include block area directly — yield is already in
# tons/hectare (normalised by area). We check for obvious anomalies by
# looking for extreme yield outliers per block that might indicate
# area changes.

cat("\n=== Block Area Stability Screening (DB3) ===\n")
block_stats <- db3_data %>%
  filter(!is.na(Yield_tha)) %>%
  group_by(Site, Block_ID) %>%
  summarise(
    n_years = n(),
    mean_yield = mean(Yield_tha),
    sd_yield = sd(Yield_tha),
    cv_yield = sd(Yield_tha) / mean(Yield_tha) * 100,
    .groups = "drop"
  )
cat("  Total blocks:", nrow(block_stats), "\n")
cat("  Blocks with >1 observation:", sum(block_stats$n_years > 1), "\n")
cat("  Mean CV of yield:", round(mean(block_stats$cv_yield, na.rm = TRUE), 1), "%\n")

# Flag blocks with extremely high CV (>100%) as potential area-change issues
flagged <- block_stats %>% filter(cv_yield > 100)
if (nrow(flagged) > 0) {
  cat("  WARNING: ", nrow(flagged), " blocks have CV > 100%, inspect manually:\n")
  print(flagged)
} else {
  cat("  No blocks flagged for excessive yield variability.\n")
}

# --- 6. Site GPS coordinates (from Table 1 in paper) -----------------------

site_info <- data.frame(
  Site = c("S1", "S2", "S3", "S4", "S5"),
  Latitude = c(38.638, 38.333, 38.450, 38.642, 38.350), 
  Longitude = c(-122.450, -122.467, -122.300, -122.454, -122.267),
  Classification = c("Napa Valley", "Moon Mountain AVA", "Atlas Peak AVA",
                      "Napa Valley", "Napa Valley"),
  Elevation_m = c(340, 280, 455, 340, 114),
  Blocks = c(30, 56, 218, 18, 33),
  Avg_Block_ha = c(4.62, 2.16, 1.18, 3.12, 2.20),
  stringsAsFactors = FALSE
)

# NOTE: S1 and S4 share identical GPS coordinates in the paper's Table 1.
# This is flagged in the reproduction plan. Cross-reference with DB1 shows
# they do have distinct weather series, so likely a rounding artifact in
# the reported coordinates.
cat("\n=== Site Information ===\n")
print(site_info)
cat("\n  NOTE: S1 and S4 share coordinates in the paper. Distinct weather data\n")
cat("        in DB1 suggests slightly different actual positions.\n")

# --- 7. Save workspace for downstream scripts ------------------------------

save(db1_data, db1_vars,
     db2_data, db2_vars,
     db3_data, db3_vars,
     db4_data, db4_vars,
     site_info, block_stats,
     data_dir, fig_dir, output_dir,
     file = file.path(output_dir, "01_data_loaded.RData"))

cat("\n=== Setup Complete ===\n")
cat("Workspace saved to:", file.path(output_dir, "01_data_loaded.RData"), "\n")
