package simpaths.integrationtest;

import org.junit.jupiter.api.DisplayName;

/**
 * End-to-end regression test for SimPathsEU — <b>Poland (PL)</b>.
 *
 * <p>All the machinery lives in {@link SimPathsIntegrationTestBase}; this class only
 * says which configs to use. It builds the database with
 * {@code config/test_create_database_PL.yml} (seed 606, pop 30000) and runs
 * {@code config/test_run_PL.yml} (seed 100, 2019-2022, pop 20000).
 *
 * <p>Output folder and golden-file directory are derived from the country code and
 * {@code parameter_args.trainingFlag} in the run config:
 *
 * <ul>
 *   <li>{@code trainingFlag: true} (shared training data, the default) —
 *       {@code output/INTEGRATION_TESTS_TRAINING_PL/} diffed against
 *       {@code expected_training_PL/}. Those CSVs <b>are</b> committed and act as
 *       the CI-ready regression baseline.</li>
 *   <li>{@code trainingFlag: false} (real EUROMOD data) —
 *       {@code output/INTEGRATION_TESTS_PL/} diffed against {@code expected_PL/}.
 *       Those CSVs are NOT committed ({@code .gitignore}) because real data is not
 *       shareable.</li>
 * </ul>
 *
 * <p>Run on its own with:
 * <pre>mvn verify -Dit.test=RunSimPathsPLIntegrationTest</pre>
 *
 * @see RunSimPathsESIntegrationTest for the Spanish equivalent
 */
@DisplayName("Integration test — Poland (PL)")
public class RunSimPathsPLIntegrationTest extends SimPathsIntegrationTestBase {

    @Override
    protected String createDatabaseConfig() {
        return "test_create_database_PL.yml";
    }

    @Override
    protected String runConfig() {
        return "test_run_PL.yml";
    }
}
