###############################################################################
# 03_feature_engineering.R
# Fixed: Tmax/Tmin/VPDmax correctly calculated as absolute interval EXTREMES
###############################################################################

load("output/01_data_loaded.RData")
load("output/02_phenology.RData")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(lubridate)
})

cat("=== Section 4: Feature Engineering ===\n\n")

HEAT_THRESHOLD <- 38.0  # Paper: "days with Tmax >= 38 degC"

# --- Helper 1: Compute generic metrics for a given subset ---
compute_generic <- function(w) {
  if (nrow(w) == 0) return(c(gdd=0, tmax=NA, hwu=0, ppt=0, tmean=NA, tmin=NA, 
                             fdays=0, frost=0, vpdmin=NA, vpdmax=NA, vpdavg=NA))
  
  safe_max <- function(x) if(all(is.na(x))) NA else max(x, na.rm = TRUE)
  safe_min <- function(x) if(all(is.na(x))) NA else min(x, na.rm = TRUE)
  
  c(
    gdd    = sum(pmax(0, (w$tmax + w$tmin)/2 - 10), na.rm = TRUE),
    tmax   = safe_max(w$tmax),               # Absolute interval maximum
    hwu    = sum(pmax(0, w$tmax - 38), na.rm = TRUE), 
    ppt    = sum(w$rain, na.rm = TRUE),
    tmean  = mean(w$tmean, na.rm = TRUE),    # Tmean is still an average
    tmin   = safe_min(w$tmin),               # Absolute interval minimum
    fdays  = sum(w$tmin <= 0, na.rm = TRUE),
    frost  = sum(pmax(0, -w$tmin), na.rm = TRUE),
    vpdmin = safe_min(w$vpdmin),
    vpdmax = safe_max(w$vpdmax),
    vpdavg = mean((w$vpdmax + w$vpdmin)/2, na.rm = TRUE)
  )
}

# --- Helper 2: Compute heatwave-specific metrics ---
compute_hw <- function(w) {
  out <- list(heat_days=0, no_hw=0, avg_dur=0, max_dur=0, 
              tot_hw_hwu=0, avg_hw_hwu=0, avg_vpd=0, max_vpd=0)
  if (nrow(w) == 0) return(out)
  
  heat_flags <- w$tmax >= HEAT_THRESHOLD
  out$heat_days <- sum(heat_flags, na.rm = TRUE)
  
  if (out$heat_days >= 2) {
    rle_heat <- rle(heat_flags)
    hw_mask  <- rle_heat$values == TRUE & rle_heat$lengths >= 2
    out$no_hw <- sum(hw_mask)
    
    if (out$no_hw > 0) {
      end_pos   <- cumsum(rle_heat$lengths)
      start_pos <- end_pos - rle_heat$lengths + 1
      
      durs <- c(); hwus <- c(); vpds <- c()
      
      for (j in which(hw_mask)) {
        hw_rows <- w[start_pos[j]:end_pos[j], ]
        durs <- c(durs, nrow(hw_rows))
        hwus <- c(hwus, sum(pmax(0, hw_rows$tmax - 38), na.rm = TRUE))
        vpds <- c(vpds, max(hw_rows$vpdmax, na.rm = TRUE))
      }
      
      out$avg_dur    <- mean(durs)
      out$max_dur    <- max(durs)
      out$tot_hw_hwu <- sum(hwus)
      out$avg_hw_hwu <- mean(hwus)
      out$avg_vpd    <- mean(vpds, na.rm = TRUE)
      out$max_vpd    <- max(vpds, na.rm = TRUE)
    }
  }
  out
}

# --- Main loop ---
weather <- db1_data %>% mutate(Year = year(date), Month = month(date), DOY = yday(date))
cat("Building feature matrix for", nrow(site_year_pheno), "site-years...\n")

all_features <- list()

for (i in 1:nrow(site_year_pheno)) {
  sy   <- site_year_pheno[i, ]
  w <- weather %>% filter(Site == sy$Site, Year == sy$Season)
  if (nrow(w) == 0) next
  
  # Month subsets
  w_m <- lapply(1:12, function(m) w %>% filter(Month == m))
  names(w_m) <- month.abb
  
  # Calendar subsets
  w_preS <- w %>% filter(Month %in% 1:3)
  w_preV_m <- w %>% filter(Month %in% 5:7)
  w_postV_m <- w %>% filter(Month %in% 8:10)
  w_apr_oct <- w %>% filter(Month %in% 4:10)
  w_apr_jul <- w %>% filter(Month %in% 4:7)
  
  # Phenology subsets
  w_bb_bl  <- w %>% filter(DOY >= sy$BB_DOY, DOY <= sy$FL_DOY)
  w_bl_ver <- w %>% filter(DOY >= sy$FL_DOY, DOY <= sy$VER_DOY)
  w_ver_h  <- w %>% filter(DOY >= sy$VER_DOY, DOY <= sy$H_DOY)
  w_bb_h   <- w %>% filter(DOY >= sy$BB_DOY, DOY <= sy$H_DOY)
  
  # Precompute block metrics
  gen_m <- lapply(w_m, compute_generic)
  hw_m  <- lapply(w_m, compute_hw)
  
  # ---------------------------------------------------------------------
  # ASSEMBLE 220 FEATURES 
  # ---------------------------------------------------------------------
  f <- numeric(220)
  
  f[1:8] <- sapply(3:10, function(x) gen_m[[x]]["gdd"])
  f[9] <- compute_generic(w_preV_m)["gdd"]; f[10] <- compute_generic(w_postV_m)["gdd"]; f[11] <- compute_generic(w_apr_oct)["gdd"]
  
  f[12:23] <- sapply(1:12, function(x) gen_m[[x]]["tmax"])
  f[24] <- compute_generic(w_preV_m)["tmax"]; f[25] <- compute_generic(w_postV_m)["tmax"]; f[26] <- compute_generic(w_apr_oct)["tmax"]
  f[27] <- ifelse(nrow(w)>0, w$DOY[which.max(w$tmax)], NA)
  
  f[28:32] <- sapply(5:9, function(x) gen_m[[x]]["hwu"])
  f[33] <- compute_generic(w_preV_m)["hwu"]; f[34] <- compute_generic(w_postV_m)["hwu"]; f[35] <- compute_generic(w_apr_oct)["hwu"]
  
  f[36:47] <- sapply(1:12, function(x) gen_m[[x]]["ppt"])
  f[48] <- compute_generic(w_preS)["ppt"]; f[49] <- compute_generic(w_preV_m)["ppt"]; f[50] <- compute_generic(w_postV_m)["ppt"]; f[51] <- compute_generic(w_apr_oct)["ppt"]
  f[52] <- ifelse(nrow(w)>0, w$DOY[which.max(w$rain)], NA)
  
  f[53:64] <- sapply(1:12, function(x) gen_m[[x]]["tmean"])
  f[65] <- compute_generic(w_preV_m)["tmean"]; f[66] <- compute_generic(w_postV_m)["tmean"]; f[67] <- compute_generic(w_apr_oct)["tmean"]
  f[68] <- ifelse(nrow(w)>0, w$DOY[which.max(w$tmean)], NA)
  
  f[69:80] <- sapply(1:12, function(x) gen_m[[x]]["tmin"])
  f[81] <- compute_generic(w_preS)["tmin"]; f[82] <- compute_generic(w_preV_m)["tmin"]; f[83] <- compute_generic(w_postV_m)["tmin"]; f[84] <- compute_generic(w_apr_oct)["tmin"]
  
  f[85:89] <- sapply(1:5, function(x) gen_m[[x]]["fdays"]); f[90:92] <- sapply(10:12, function(x) gen_m[[x]]["fdays"])
  f[93] <- compute_generic(w_apr_oct)["fdays"]
  
  f[94:98] <- sapply(1:5, function(x) gen_m[[x]]["frost"]); f[99:100] <- sapply(11:12, function(x) gen_m[[x]]["frost"])
  
  f[101:112] <- sapply(1:12, function(x) gen_m[[x]]["vpdmin"])
  f[113] <- compute_generic(w_apr_jul)["vpdmin"]; f[114] <- compute_generic(w_postV_m)["vpdmin"]; f[115] <- compute_generic(w_apr_oct)["vpdmin"]
  
  f[116:127] <- sapply(1:12, function(x) gen_m[[x]]["vpdmax"])
  f[128] <- compute_generic(w_apr_jul)["vpdmax"]; f[129] <- compute_generic(w_postV_m)["vpdmax"]; f[130] <- compute_generic(w_apr_oct)["vpdmax"]
  
  f[131] <- compute_hw(w)$heat_days
  f[132:135] <- sapply(6:9, function(x) hw_m[[x]]$heat_days)
  f[136] <- compute_hw(w_preV_m)$heat_days; f[137] <- compute_hw(w_postV_m)$heat_days
  
  f[138:141] <- sapply(6:9, function(x) hw_m[[x]]$no_hw)
  f[142] <- compute_hw(w_preV_m)$no_hw; f[143] <- compute_hw(w_postV_m)$no_hw; f[144] <- compute_hw(w_apr_oct)$no_hw
  
  hw_seas <- compute_hw(w_apr_oct)
  f[145] <- hw_seas$avg_dur; f[146] <- hw_seas$max_dur; f[147] <- hw_seas$tot_hw_hwu
  f[148] <- hw_seas$avg_hw_hwu; f[149] <- hw_seas$avg_vpd; f[150] <- hw_seas$max_vpd
  
  f[151:154] <- sapply(6:9, function(x) hw_m[[x]]$tot_hw_hwu)
  f[155] <- compute_hw(w_preV_m)$tot_hw_hwu; f[156] <- compute_hw(w_postV_m)$tot_hw_hwu
  
  w_p <- list(w_bb_bl, w_bl_ver, w_ver_h, w_bb_h)
  f[157:160] <- sapply(w_p, function(x) compute_generic(x)["tmax"])
  f[161:164] <- sapply(w_p, function(x) compute_generic(x)["tmean"])
  f[165:168] <- sapply(w_p, function(x) compute_generic(x)["tmin"])
  f[169:172] <- sapply(w_p, function(x) compute_generic(x)["ppt"])
  f[173:176] <- sapply(w_p, function(x) compute_generic(x)["fdays"])
  f[177:180] <- sapply(w_p, function(x) compute_generic(x)["frost"])
  f[181:184] <- sapply(w_p, function(x) compute_generic(x)["hwu"])
  f[185:188] <- sapply(w_p, function(x) compute_generic(x)["vpdmax"])
  f[189:192] <- sapply(w_p, function(x) compute_generic(x)["vpdavg"])
  f[193:196] <- sapply(w_p, function(x) compute_generic(x)["vpdmin"])
  
  hw_p <- lapply(w_p[2:4], compute_hw)
  f[197:199] <- sapply(hw_p, function(x) x$no_hw)
  f[200:202] <- sapply(hw_p, function(x) x$avg_dur)
  f[203:205] <- sapply(hw_p, function(x) x$max_dur)
  f[206:208] <- sapply(hw_p, function(x) x$tot_hw_hwu)
  f[209:211] <- sapply(hw_p, function(x) x$avg_hw_hwu)
  f[212:214] <- sapply(hw_p, function(x) x$avg_vpd)
  f[215:217] <- sapply(hw_p, function(x) x$max_vpd)
  f[218:220] <- sapply(hw_p, function(x) x$heat_days)

  all_features[[i]] <- as.numeric(f)
}

# Combine into matrix
feature_matrix <- do.call(rbind, all_features)
rownames(feature_matrix) <- paste(site_year_pheno$Site, site_year_pheno$Season, sep = "_")

feature_names <- c(
  "GDD_march", "GDD_april", "GDD_may", "GDD_june", "GDD_july", "GDD_aug", "GDD_sep", "GDD_oct", "GDD_preV", "GDD_postV", "GDD_Apr_Oct",
  "Tmax_jan", "Tmax_feb", "Tmax_march", "Tmax_april", "Tmax_may", "Tmax_june", "Tmax_july", "Tmax_aug", "Tmax_sep", "Tmax_oct", "Tmax_nov", "Tmax_dec", "Tmax_preV", "Tmax_postV", "Tmax_Apr_Oct", "Tmax_doy",
  "HWU_may", "HWU_june", "HWU_july", "HWU_aug", "HWU_sep", "HWU_preV", "HWU_postV", "HWU_Apr_Oct",
  "ppt_jan", "ppt_feb", "ppt_march", "ppt_april", "ppt_may", "ppt_june", "ppt_july", "ppt_aug", "ppt_sep", "ppt_oct", "ppt_nov", "ppt_dec", "ppt_preS", "ppt_preV", "ppt_postV", "ppt_Apr_Oct", "ppt_max_doy",
  "tmean_jan", "tmean_feb", "tmean_march", "tmean_apr", "tmean_may", "tmean_june", "tmean_july", "tmean_aug", "tmean_sep", "tmean_oct", "tmean_nov", "tmean_dec", "tmean_preS", "tmean_preV", "tmean_postV", "tmean_Apr_Oct",
  "tmin_jan", "tmin_feb", "tmin_march", "tmin_apr", "tmin_may", "tmin_june", "tmin_july", "tmin_aug", "tmin_sep", "tmin_oct", "tmin_nov", "tmin_dec", "tmin_preS", "tmin_preV", "tmin_postV", "tmin_Apr_Oct",
  "fdays_jan", "fdays_feb", "fdays_mar", "fdays_apr", "fdays_may", "fdays_oct", "fdays_nov", "fdays_dec", "fdays_Apr_Oct",
  "frost_jan", "frost_feb", "frost_march", "frost_apr", "frost_may", "frost_nov", "frost_dec",
  "vpdmin_jan", "vpdmin_feb", "vpdmin_march", "vpdmin_apr", "vpdmin_may", "vpdmin_june", "vpdmin_july", "vpdmin_aug", "vpdmin_sep", "vpdmin_oct", "vpdmin_nov", "vpdmin_dec", "vpdmin_preV", "vpdmin_postV", "vpdmin_Apr_Oct",
  "vpdmax_jan", "vpdmax_feb", "vpdmax_march", "vpdmax_apr", "vpdmax_may", "vpdmax_june", "vpdmax_july", "vpdmax_aug", "vpdmax_sep", "vpdmax_oct", "vpdmax_nov", "vpdmax_dec", "vpdmax_preV", "vpdmax_postV", "vpdmax_Apr_Oct",
  "heat_days_100", "heat_days_june", "heat_days_july", "heat_days_aug", "heat_days_sep", "heat_days_preV", "heat_days_postV",
  "no_hw_june", "no_hw_july", "no_hw_aug", "no_hw_sep", "no_hw_preV", "no_hw_postV", "no_hw",
  "avg_hw_duration", "max_hw_duration", "tot_hw_hwu", "avg_hw_hwu", "avg_hw_vpd", "max_hw_vpd",
  "hw_hwu_june", "hw_hwu_july", "hw_hwu_aug", "hw_hwu_sep", "hw_hwu_preV", "hw_hwu_postV",
  "Tmax_BBtoFL", "Tmax_FLtoVER", "Tmax_VERtoH", "Tmax_BBtoH",
  "Tmean_BBtoFL", "Tmean_FLtoVER", "Tmean_VERtoH", "Tmean_BBtoH",
  "Tmin_BBtoFL", "Tmin_FLtoVER", "Tmin_VERtoH", "Tmin_BBtoH",
  "rain_BBtoFL", "rain_FLtoVER", "rain_VERtoH", "rain_BBtoH",
  "fdays_BBtoFL", "fdays_FLtoVER", "fdays_VERtoH", "fdays_BBtoH",
  "frost_BBtoFL", "frost_FLtoVER", "frost_VERtoH", "frost_BBtoH",
  "hwu_BBtoFL", "hwu_FLtoVER", "hwu_VERtoH", "hwu_BBtoH",
  "vpdmax_BBtoFL", "vpdmax_FLtoVER", "vpdmax_VERtoH", "vpdmax_BBtoH",
  "vpdavg_BBtoFL", "vpdavg_FLtoVER", "vpdavg_VERtoH", "vpdavg_BBtoH",
  "vpdmin_BBtoFL", "vpdmin_FLtoVER", "vpdmin_VERtoH", "vpdmin_BBtoH",
  "no_hw_FLtoVER", "no_hw_VERtoH", "no_hw_BBtoH",
  "avg_hw_duration_FLtoVER", "avg_hw_duration_VERtoH", "avg_hw_duration_BBtoH",
  "max_hw_duration_FLtoVER", "max_hw_duration_VERtoH", "max_hw_duration_BBtoH",
  "tot_hw_hwu_FLtoVER", "tot_hw_hwu_VERtoH", "tot_hw_hwu_BBtoH",
  "avg_hw_hwu_FLtoVER", "avg_hw_hwu_VERtoH", "avg_hw_hwu_BBtoH",
  "avg_hw_vpd_FLtoVER", "avg_hw_vpd_VERtoH", "avg_hw_vpd_BBtoH",
  "max_hw_vpd_FLtoVER", "max_hw_vpd_VERtoH", "max_hw_vpd_BBtoH",
  "heat_days_FLtoVER", "heat_days_VERtoH", "heat_days_BBtoH"
)

colnames(feature_matrix) <- feature_names

for (j in seq_len(ncol(feature_matrix))) {
  na_mask <- is.na(feature_matrix[, j])
  if (any(na_mask)) feature_matrix[na_mask, j] <- median(feature_matrix[, j], na.rm = TRUE)
}

variances <- apply(feature_matrix, 2, var)
zero_var  <- variances == 0 | is.na(variances)
feature_matrix <- feature_matrix[, !zero_var]
scaled_features <- scale(feature_matrix)

cat("  Final scaled feature matrix:", nrow(scaled_features), "x", ncol(scaled_features), "\n")

save(feature_matrix, scaled_features, site_year_pheno,
     file = file.path("output", "03_features.RData"))

cat("=== Section 4 Complete ===\n")