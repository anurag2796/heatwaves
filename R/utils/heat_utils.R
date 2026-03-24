###############################################################################
# R/utils/heat_utils.R
# Heat feature computation helpers
# Extracted from 03_feature_engineering.R for reusability and testability
###############################################################################

#' Heat threshold for defining heat days and heatwaves (paper: >= 38 degC)
HEAT_THRESHOLD_C <- 38.0

#' Compute generic weather metrics for a daily weather subset
#'
#' @param w Data frame with columns: tmax, tmin, tmean, rain, vpdmin, vpdmax
#' @return Named numeric vector of 11 metrics
compute_generic <- function(w) {
  if (nrow(w) == 0) {
    return(c(gdd = 0, tmax = NA, hwu = 0, ppt = 0, tmean = NA, tmin = NA,
             fdays = 0, frost = 0, vpdmin = NA, vpdmax = NA, vpdavg = NA))
  }

  safe_max <- function(x) if (all(is.na(x))) NA else max(x, na.rm = TRUE)
  safe_min <- function(x) if (all(is.na(x))) NA else min(x, na.rm = TRUE)

  c(
    gdd    = sum(pmax(0, (w$tmax + w$tmin) / 2 - 10), na.rm = TRUE),
    tmax   = safe_max(w$tmax),
    hwu    = sum(pmax(0, w$tmax - HEAT_THRESHOLD_C), na.rm = TRUE),
    ppt    = sum(w$rain, na.rm = TRUE),
    tmean  = mean(w$tmean, na.rm = TRUE),
    tmin   = safe_min(w$tmin),
    fdays  = sum(w$tmin <= 0, na.rm = TRUE),
    frost  = sum(pmax(0, -w$tmin), na.rm = TRUE),
    vpdmin = safe_min(w$vpdmin),
    vpdmax = safe_max(w$vpdmax),
    vpdavg = mean((w$vpdmax + w$vpdmin) / 2, na.rm = TRUE)
  )
}

#' Compute heatwave-specific metrics for a daily weather subset
#'
#' A heatwave is >= 2 consecutive days with Tmax >= 38 degC.
#' HWU (Heat Wave Units) = sum of (Tmax - 38) over heatwave days.
#'
#' @param w Data frame with columns: tmax, vpdmax
#' @return Named list of 8 heatwave metrics
compute_heatwave <- function(w) {
  out <- list(
    heat_days   = 0, n_heatwaves  = 0,
    avg_duration = 0, max_duration = 0,
    total_hwu   = 0, avg_hwu      = 0,
    avg_vpd     = 0, max_vpd      = 0
  )

  if (nrow(w) == 0) return(out)

  heat_flags <- w$tmax >= HEAT_THRESHOLD_C
  out$heat_days <- sum(heat_flags, na.rm = TRUE)

  if (out$heat_days >= 2) {
    rle_heat <- rle(heat_flags)
    hw_mask  <- rle_heat$values == TRUE & rle_heat$lengths >= 2
    out$n_heatwaves <- sum(hw_mask)

    if (out$n_heatwaves > 0) {
      end_pos   <- cumsum(rle_heat$lengths)
      start_pos <- end_pos - rle_heat$lengths + 1

      hw_durations <- numeric(0)
      hw_units     <- numeric(0)
      hw_vpd_maxes <- numeric(0)

      for (j in which(hw_mask)) {
        hw_rows <- w[start_pos[j]:end_pos[j], ]
        hw_durations <- c(hw_durations, nrow(hw_rows))
        hw_units     <- c(hw_units, sum(pmax(0, hw_rows$tmax - HEAT_THRESHOLD_C), na.rm = TRUE))
        hw_vpd_maxes <- c(hw_vpd_maxes, max(hw_rows$vpdmax, na.rm = TRUE))
      }

      out$avg_duration <- mean(hw_durations)
      out$max_duration <- max(hw_durations)
      out$total_hwu    <- sum(hw_units)
      out$avg_hwu      <- mean(hw_units)
      out$avg_vpd      <- mean(hw_vpd_maxes, na.rm = TRUE)
      out$max_vpd      <- max(hw_vpd_maxes, na.rm = TRUE)
    }
  }
  out
}
