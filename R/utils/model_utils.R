###############################################################################
# R/utils/model_utils.R
# LMM modeling helpers and verification utilities
# Extracted from 06_linear_mixed_models.R and 08_verification_report.R
###############################################################################

#' Safely rename fruit composition columns (handles Unicode issues)
#'
#' @param df Data frame with raw DB4 column names
#' @return Data frame with clean, ASCII column names
sanitize_fruit_columns <- function(df) {
  rename_map <- list(
    "Damascenone"  = "B_Damascenone",
    "Octen"        = "Octen_3_ol",
    "C6"           = "C6_compounds",
    "anthocyanins"  = "Total_anthocyanins",
    "tannins"      = "Polymeric_tannins",
    "Quercetin"    = "Quercetin_glycosides",
    "moisture"     = "Berry_moisture",
    "Malic"        = "Malic_acid"
  )

  for (pattern in names(rename_map)) {
    names(df)[grepl(pattern, names(df), ignore.case = TRUE)] <- rename_map[[pattern]]
  }

  if ("Block_ID" %in% names(df)) {
    names(df)[names(df) == "Block_ID"] <- "block_ID"
  }

  return(df)
}

#' Get median of a variable for a specific cluster
#'
#' @param df Data frame with 'cluster' column
#' @param var_name Variable to compute median of
#' @param clust Cluster level (e.g., "C1")
#' @return Numeric median
get_cluster_median <- function(df, var_name, clust) {
  df %>%
    dplyr::filter(cluster == clust) %>%
    dplyr::pull(!!rlang::sym(var_name)) %>%
    median(na.rm = TRUE)
}

#' List of the 12 fruit composition analytes from the paper
ANALYTE_NAMES <- c(
  "B_Damascenone", "Octen_3_ol", "C6_compounds", "IBMP",
  "Total_anthocyanins", "Polymeric_tannins", "Quercetin_glycosides",
  "TSS", "Berry_moisture", "pH", "Malic_acid", "YAN"
)
