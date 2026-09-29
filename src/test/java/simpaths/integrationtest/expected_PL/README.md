# Integration-test golden files — Poland (PL), real-data baseline

This directory holds the golden CSV outputs that `RunSimPathsPLIntegrationTest`
diffs the simulation output against **when `parameter_args.trainingFlag: false`
in `config/test_run_PL.yml`** (the real-EUROMOD-data baseline).

The CSV files in this directory are **not committed** (see the matching entry
in `.gitignore`) because real EU-SILC / EUROMOD inputs are not shareable —
each developer must capture a local baseline against their own input data
before making behavioural changes.

> For the **training-data baseline** (committed, CI-ready, and the default), see
> [`../expected_training_PL/README.md`](../expected_training_PL/README.md).
> Spain follows the identical convention under [`../expected_ES/`](../expected_ES/README.md)
> and [`../expected_training_ES/`](../expected_training_ES/README.md).

## When to use this test

Before refactoring anything that could shift simulated output (model code,
alignment, tax/benefit, health transitions, …) run the test once to capture
the current output as the baseline, then run it again after your change to
verify that nothing moved.

## Regenerating the golden files locally

1. Confirm `config/test_run_PL.yml` has `parameter_args.trainingFlag: false`.

2. Build the project:

    ```sh
    mvn clean package -DskipTests
    ```

3. Run the integration test once. It will fail on the comparison step because
   the expected CSVs do not yet exist:

    ```sh
    mvn verify -Dit.test=RunSimPathsPLIntegrationTest
    ```

4. Copy the actual outputs into this directory as the baseline:

    ```sh
    SRC=output/INTEGRATION_TESTS_PL/csv
    DST=src/test/java/simpaths/integrationtest/expected_PL
    cp "$SRC/WealthIncomeStatistics.csv" "$SRC/DemographicStatistics.csv" \
       "$SRC/HealthStatistics.csv" "$SRC/HealthByGender.csv" \
       "$SRC/LabourStatistics.csv" "$DST/"
    # AlignmentStatistics.csv is only checked for existence, no diff.
    ```

5. Rerun `mvn verify` — it should now pass.

## When the diff fires after a refactor

If you made an *intentional* behavioural change, regenerate the baseline as
above and keep the new files locally. If the diff was unexpected, that is
exactly the signal this test exists to provide — investigate before moving on.

## Comparison rules

The test uses a **hybrid numeric tolerance** (see
`SimPathsIntegrationTestBase.tokensMatchWithTolerance`), shared by every country
baseline:

- numeric tokens match when `|a - b| <= max(1e-9, 1e-6 * max(|a|, |b|))`
- `NaN` is treated as equal to `NaN`
- non-numeric tokens must match exactly as strings
- line counts and column counts must match exactly
