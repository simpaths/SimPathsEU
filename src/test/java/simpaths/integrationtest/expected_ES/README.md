# Integration-test golden files — Spain (ES), real-data baseline

This directory holds the golden CSV outputs that `RunSimPathsESIntegrationTest`
diffs against **when `parameter_args.trainingFlag: false` in
`config/test_run_ES.yml`** (the real-EUROMOD-data baseline).

The CSVs here are **not committed** (see the matching entry in `.gitignore`) because
real EU-SILC / EUROMOD inputs are not shareable — each developer captures a local
baseline against their own input data before making behavioural changes.

> For the **training-data baseline** (committed, CI-ready, and the default), see
> [`../expected_training_ES/README.md`](../expected_training_ES/README.md). Poland
> follows the identical convention under [`../expected_PL/`](../expected_PL/README.md)
> and [`../expected_training_PL/`](../expected_training_PL/README.md).

## Capturing the baseline locally

1. Set `parameter_args.trainingFlag: false` in `config/test_run_ES.yml`.

2. Build, then run the test once — it fails on the comparison step because the
   expected CSVs do not yet exist:

    ```sh
    mvn clean package -DskipTests
    mvn verify -Dit.test=RunSimPathsESIntegrationTest
    ```

3. Copy the actual outputs into this directory as the baseline:

    ```sh
    SRC=output/INTEGRATION_TESTS_ES/csv
    DST=src/test/java/simpaths/integrationtest/expected_ES
    cp "$SRC/WealthIncomeStatistics.csv" "$SRC/DemographicStatistics.csv" \
       "$SRC/HealthStatistics.csv" "$SRC/HealthByGender.csv" \
       "$SRC/LabourStatistics.csv" "$DST/"
    # AlignmentStatistics.csv is only checked for existence, no diff.
    ```

4. Rerun — it should now pass.

## Caveat on the numbers

See [`../expected_training_ES/README.md`](../expected_training_ES/README.md#caveat-on-the-numbers):
several ES inputs are still Polish clones, so ES levels are not yet meaningful. The
test pins reproducibility, not correctness.

## Comparison rules

Same hybrid tolerance as every other baseline — see
[`../expected_PL/README.md`](../expected_PL/README.md#comparison-rules).
