#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

JAR_PATH="${JAR_PATH:-multirun.jar}"
START_YEAR="${START_YEAR:-2011}"
END_YEAR="${END_YEAR:-2023}"
POP_SIZE="${POP_SIZE:-50000}"
RUNS_PER_SCENARIO="${RUNS_PER_SCENARIO:-5}"
SHOW_GUI="${SHOW_GUI:-false}"
RANDOM_SEED="${RANDOM_SEED:-1821}"

# JVM heap: give the simulation generous room.
# Rule of thumb: (population × runs) drives peak usage. At 50k × 5 runs,
# 8g is comfortable on this machine (18 GB RAM). Lower to 6g if other
# processes are competing; raise to 12g if you see GC pauses or OOM.
JVM_HEAP="${JVM_HEAP:-12g}"

CONFIGS=(
  "alignment_00_populationOFF.yml"
  "alignment_01_population.yml"
  "alignment_02a_population_fertility.yml"
  "alignment_02b_population_cohabitation.yml"
  "alignment_02c_population_disability.yml"
  "alignment_02d_population_inschool.yml"
  "alignment_02e_population_retirement.yml"
  "alignment_02f_population_retirement.yml"
  "alignment_03_population_cohabitation_employment.yml"
  # "alignment_04_population_fertility_cohabitation_employment.yml"
)

if [[ ! -f "$JAR_PATH" ]]; then
  echo "Jar not found: $JAR_PATH" >&2
  exit 1
fi

for cfg in "${CONFIGS[@]}"; do
  scenario="${cfg%.yml}"   # strip .yml → e.g. alignment_01_population
  dest="output/${scenario}"

  echo "============================================"
  echo "Running scenario: ${scenario}"
  echo "============================================"

  # Marker file: anything created after this point is from the upcoming run.
  marker=$(mktemp)

  java -Xms"${JVM_HEAP}" -Xmx"${JVM_HEAP}" -jar "$JAR_PATH" \
    -g "$SHOW_GUI" \
    -s "$START_YEAR" \
    -e "$END_YEAR" \
    -p "$POP_SIZE" \
    -n "$RUNS_PER_SCENARIO" \
    -r "$RANDOM_SEED" \
    -config "$cfg"

  # The CSV output folder is the timestamped directory WITHOUT a seed/counter
  # suffix (e.g. output/20260323204849/csv). Find it by comparing to the marker.
  new_csv_folder=$(find output -maxdepth 1 -type d -newer "$marker" -name '[0-9]*' \
    | grep -v '_' | sort -r | head -1)
  rm -f "$marker"

  if [[ -n "$new_csv_folder" ]]; then
    if [[ -d "$dest" ]]; then
      echo "Warning: ${dest} already exists — removing before overwrite." >&2
      rm -rf "$dest"
    fi
    mv "$new_csv_folder" "$dest"
    echo "Output saved → ${dest}"
  else
    echo "Warning: could not find new output folder for scenario ${scenario}." >&2
  fi
done

echo ""
echo "All scenarios complete. Results are in:"
for cfg in "${CONFIGS[@]}"; do
  echo "  output/${cfg%.yml}/"
done
