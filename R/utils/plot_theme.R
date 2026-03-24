###############################################################################
# R/utils/plot_theme.R
# Shared plotting theme, colour palette, and label definitions
# Extracted from 07_figures.R for consistency across all figure scripts
###############################################################################

suppressPackageStartupMessages(library(ggplot2))

#' Publication-ready ggplot2 theme for Previtali reproduction
theme_paper <- theme_classic(base_size = 14) +
  theme(
    plot.title    = element_text(face = "bold", size = 16),
    legend.position = "bottom",
    legend.title  = element_text(face = "bold"),
    legend.text   = element_text(size = 12),
    axis.text     = element_text(color = "black", size = 12),
    axis.title    = element_text(face = "bold", size = 13),
    plot.caption  = element_text(
      hjust = 0, face = "italic", color = "gray30",
      size = 11, margin = margin(t = 15)
    )
  )

#' Cluster colour palette (colourblind-friendly)
cluster_colours <- c(
  "C1" = "#D55E00",   # orange-red for POST-V heat
  "C2" = "#E69F00",   # amber for PRE-V heat
  "C3" = "#0072B2"    # blue for Cool baseline
)

#' Full biological labels for cluster legends
cluster_labels <- c(
  "C3" = "C3 (Cool Baseline)",
  "C2" = "C2 (Pre-Veraison Heat)",
  "C1" = "C1 (Post-Veraison Heat)"
)

#' Short labels for axis tick marks
cluster_labels_short <- c(
  "C3" = "C3 (Cool)",
  "C2" = "C2 (Pre-V)",
  "C1" = "C1 (Post-V)"
)
