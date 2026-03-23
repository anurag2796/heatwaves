#!/bin/bash
mkdir -p output
LOGFILE="output/complete_run.log"
echo "Starting complete run at $(date)" > "$LOGFILE"

SCRIPTS=(
  "01_setup_and_data.R"
  "02_gdd_phenology.R"
  "03_feature_engineering.R"
  "04_hca_clustering.R"
  "05_random_forest_validation.R"
  "06_linear_mixed_models.R"
  "07_figures.R"
  "08_verification_report.R"
)

for f in "${SCRIPTS[@]}"; do
  echo "========== RUNNING $f ==========" | tee -a "$LOGFILE"
  Rscript "$f" >> "$LOGFILE" 2>&1
  if [ $? -ne 0 ]; then
    echo "Error running $f. Stopping pipeline." | tee -a "$LOGFILE"
    exit 1
  fi
done

echo "Complete run finished successfully at $(date)" | tee -a "$LOGFILE"
