package simpaths.integrationtest;

import org.junit.jupiter.api.DisplayName;

/**
 * End-to-end regression test for SimPathsEU — <b>Spain (ES)</b>.
 *
 * <p>Identical in every respect to {@link RunSimPathsPLIntegrationTest} apart from the
 * country: same seeds, same population sizes, same 2019-2022 horizon, same numeric
 * tolerances, same set of diffed CSVs. All the machinery lives in
 * {@link SimPathsIntegrationTestBase}. It builds the database with
 * {@code config/test_create_database_ES.yml} and runs {@code config/test_run_ES.yml}.
 *
 * <p>Output folder and golden-file directory are derived from the country code and
 * {@code parameter_args.trainingFlag} in the run config:
 *
 * <ul>
 *   <li>{@code trainingFlag: true} (shared training data, the default) —
 *       {@code output/INTEGRATION_TESTS_TRAINING_ES/} diffed against
 *       {@code expected_training_ES/}. Those CSVs <b>are</b> committed and act as
 *       the CI-ready regression baseline.</li>
 *   <li>{@code trainingFlag: false} (real EUROMOD data) —
 *       {@code output/INTEGRATION_TESTS_ES/} diffed against {@code expected_ES/}.
 *       Those CSVs are NOT committed ({@code .gitignore}) because real data is not
 *       shareable.</li>
 * </ul>
 *
 * <p>Run on its own with:
 * <pre>mvn verify -Dit.test=RunSimPathsESIntegrationTest</pre>
 */
@DisplayName("Integration test — Spain (ES)")
public class RunSimPathsESIntegrationTest extends SimPathsIntegrationTestBase {

    @Override
    protected String createDatabaseConfig() {
        return "test_create_database_ES.yml";
    }

    @Override
    protected String runConfig() {
        return "test_run_ES.yml";
    }
}
