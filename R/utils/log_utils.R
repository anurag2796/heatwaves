###############################################################################
# R/utils/log_utils.R
# Structured logging utility for the reproduction pipeline
###############################################################################

#' Log a pipeline step with timestamp and level
#'
#' @param section Section name (e.g., "Feature Engineering")
#' @param msg Message string (supports sprintf formatting)
#' @param ... Additional arguments passed to sprintf
#' @param level Log level: "INFO", "WARN", "ERROR", "DEBUG"
log_step <- function(section, msg, ..., level = "INFO") {
  ts <- format(Sys.time(), "%H:%M:%S")
  formatted_msg <- if (length(list(...)) > 0) sprintf(msg, ...) else msg
  cat(sprintf("[%s] [%-5s] %s: %s\n", ts, level, section, formatted_msg))
}

#' Log a gate check (pass/fail with target vs actual)
log_check <- function(label, target, actual, tolerance_pct = 5, unit = "") {
  if (is.na(actual) || length(actual) == 0) {
    log_step("CHECK", "%-35s  Target: %8s  Actual: %8s  [ MISSING ]",
             label, paste0(target, unit), "NA", level = "WARN")
    return(FALSE)
  }
  pct_dev <- abs(actual - target) / abs(target) * 100
  status <- ifelse(pct_dev <= tolerance_pct, "OK", "WARNING")
  lvl <- ifelse(pct_dev <= tolerance_pct, "INFO", "WARN")
  log_step("CHECK", "%-35s  Target: %8s  Actual: %8.2f  Dev: %5.1f%%  [%s]",
           label, paste0(target, unit), actual, pct_dev, status, level = lvl)
  return(pct_dev <= tolerance_pct)
}
