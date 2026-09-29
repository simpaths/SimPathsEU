package simpaths.integrationtest;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.*;
import org.yaml.snakeyaml.Yaml;
import simpaths.model.enums.Country;

/**
 * Country-agnostic end-to-end regression test for SimPathsEU.
 *
 * <p>Subclass this once per country, supplying only the two YAML configs — everything
 * else (flow, tolerances, diff messages, and all the paths below) is shared, so the
 * country baselines stay directly comparable. Concrete subclasses:
 * {@link RunSimPathsPLIntegrationTest} (Poland) and {@link RunSimPathsESIntegrationTest}
 * (Spain).
 *
 * <p><b>Everything is keyed on country code and data mode.</b> Both are read from the
 * run config ({@code countryString} and {@code parameter_args.trainingFlag}), and both
 * paths follow the same convention, so adding a country — or switching one from real
 * data to training data — needs no code change here:
 *
 * <pre>
 *   output folder : output/INTEGRATION_TESTS[_TRAINING]_&lt;CC&gt;/csv/
 *   golden files  : src/test/java/simpaths/integrationtest/expected[_training]_&lt;CC&gt;/
 * </pre>
 *
 * <p>Training-data baselines are committed (shareable data, CI-ready); real-data
 * baselines are gitignored and captured locally per developer. See each
 * {@code expected*} folder's README.
 *
 * Flow (ordered):
 *   1. Build a fresh input database from the EU inputs via {@code multirun.jar -DBSetup}
 *      using {@link #createDatabaseConfig()}.
 *   2. Verify that the expected input artefacts were produced.
 *   3. Run a short deterministic simulation via {@code multirun.jar} using
 *      {@link #runConfig()}.
 *   4. Diff each produced CSV against a committed golden file with a hybrid
 *      absolute/relative numeric tolerance (see {@link #tokensMatchWithTolerance}).
 *
 * <p><b>Shared global state.</b> All countries share one {@code input/input.mv.db}
 * and one {@code input/DatabaseCountryYear.xlsx}, both rewritten by the {@code -DBSetup}
 * step. The country tests are therefore safe to run one after another (each rebuilds
 * the database it needs) but must never be run <i>concurrently</i>.
 */
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
public abstract class SimPathsIntegrationTestBase {

    /** Absolute epsilon for numeric comparison. */
    private static final double ABS_EPSILON = 1e-9;
    /** Relative epsilon for numeric comparison. */
    private static final double REL_EPSILON = 1e-6;

    // ------------------------------------------------------------------
    // Per-country hooks
    // ------------------------------------------------------------------

    /** File name (inside {@code config/}) of the {@code -DBSetup} config. */
    protected abstract String createDatabaseConfig();

    /** File name (inside {@code config/}) of the simulation-run config. */
    protected abstract String runConfig();

    // ------------------------------------------------------------------
    // Resolved from the run config
    // ------------------------------------------------------------------

    /** Root of the golden-file directories, one {@code expected[_training]_<CC>} per country. */
    private static final Path INTEGRATION_TEST_DIR =
            Paths.get("src", "test", "java", "simpaths", "integrationtest");

    private Path runConfigPath;
    private Map<String, Object> runConfigMap;
    private String countryCode;
    private boolean trainingFlag;
    private Path countryPolicySchedule;
    private Path outputDir;
    private Path expectedDir;

    protected final boolean isTrainingRun() {
        return trainingFlag;
    }

    @BeforeAll
    void resolveConfiguration() {
        runConfigPath = Paths.get("config", runConfig());
        runConfigMap = loadYaml(runConfigPath);
        countryCode = resolveCountryCode();
        trainingFlag = resolveTrainingFlag();
        countryPolicySchedule = Paths.get("input", countryCode, "EUROMODpolicySchedule.xlsx");
        outputDir = Paths.get("output", resolveOutputSubFolder());
        expectedDir = INTEGRATION_TEST_DIR.resolve(
                "expected" + (trainingFlag ? "_training" : "") + "_" + countryCode);

    }

    // ------------------------------------------------------------------
    // The test flow
    // ------------------------------------------------------------------

    @Test
    @DisplayName("Initial database setup runs successfully")
    @Order(1)
    void testRunSetup() {
        runCommand(
                "java", "-jar", "multirun.jar", "-DBSetup", "-config", createDatabaseConfig(),
                "-t", String.valueOf(trainingFlag)
        );
    }

    @Test
    @DisplayName("Database and configuration files are created")
    @Order(2)
    void testVerifySetupOutput() {
        assertFileExists("input/input.mv.db");
        assertFileExists(countryPolicySchedule.toString());
        assertFileExists("input/DatabaseCountryYear.xlsx");
    }

    @Test
    @DisplayName("Simulation runs successfully")
    @Order(3)
    void testRunSimulation() {
        runCommand(
                "java", "-jar", "multirun.jar", "-config", runConfig(),
                "-t", String.valueOf(trainingFlag)
        );
    }

    @Test
    @DisplayName("Simulation output directory exists")
    @Order(4)
    void testOutputDirectoryExists() {
        assertTrue(
                Files.isDirectory(outputDir),
                "Integration-test output directory is missing: " + outputDir
                        + " (resolved from " + runConfigPath + ", country=" + countryCode
                        + ", trainingFlag=" + trainingFlag + ")"
        );
    }

    @Test
    @DisplayName("WealthIncomeStatistics.csv matches the golden file")
    @Order(5)
    void compareWealthIncomeStatistics() throws IOException {
        compareFiles(outputDir.resolve("csv/WealthIncomeStatistics.csv"), expectedDir.resolve("WealthIncomeStatistics.csv"));
    }

    @Test
    @DisplayName("DemographicStatistics.csv matches the golden file")
    @Order(6)
    void compareDemographicStatistics() throws IOException {
        compareFiles(outputDir.resolve("csv/DemographicStatistics.csv"), expectedDir.resolve("DemographicStatistics.csv"));
    }

    @Test
    @DisplayName("AlignmentStatistics.csv was exported")
    @Order(7)
    void verifyAlignmentStatisticsExported() {
        Path file = outputDir.resolve("csv/AlignmentStatistics.csv");
        assertTrue(Files.exists(file), "Expected output file is missing: " + file);
    }

    @Test
    @DisplayName("HealthStatistics.csv matches the golden file")
    @Order(8)
    void compareHealthStatistics() throws IOException {
        compareFiles(outputDir.resolve("csv/HealthStatistics.csv"), expectedDir.resolve("HealthStatistics.csv"));
    }

    @Test
    @DisplayName("HealthByGender.csv matches the golden file")
    @Order(9)
    void compareHealthByGender() throws IOException {
        compareFiles(outputDir.resolve("csv/HealthByGender.csv"), expectedDir.resolve("HealthByGender.csv"));
    }

    @Test
    @DisplayName("LabourStatistics.csv matches the golden file")
    @Order(10)
    void compareLabourStatistics() throws IOException {
        compareFiles(outputDir.resolve("csv/LabourStatistics.csv"), expectedDir.resolve("LabourStatistics.csv"));
    }

    // ------------------------------------------------------------------
    // File-comparison helpers
    // ------------------------------------------------------------------

    void compareFiles(Path actualFile, Path expectedFile) throws IOException {
        assertTrue(Files.exists(actualFile), "Expected output file is missing: " + actualFile);
        assertTrue(Files.exists(expectedFile),
                "Golden file is missing: " + expectedFile + System.lineSeparator()
                        + "If this is the first run on this machine, capture a baseline by copying:" + System.lineSeparator()
                        + "    cp " + actualFile + " " + expectedFile);
        assertTrue(filesMatchWithTolerance(actualFile, expectedFile), fileMismatchMessage(actualFile, expectedFile));
    }

    String fileMismatchMessage(Path actualFile, Path expectedFile) throws IOException {
        List<String> actualLines = Files.readAllLines(actualFile);
        List<String> expectedLines = Files.readAllLines(expectedFile);
        int maxLines = Math.max(expectedLines.size(), actualLines.size());

        StringBuilder differences = new StringBuilder();
        for (int i = 0; i < maxLines; i++) {
            String expectedLine = (i < expectedLines.size()) ? expectedLines.get(i) : "<MISSING>";
            String actualLine = (i < actualLines.size()) ? actualLines.get(i) : "<EXTRA>";

            if (!linesMatchWithTolerance(expectedLine, actualLine)) {
                differences.append(String.format("""
                    Line %d:
                    Expected: %s
                    Actual  : %s
                    """,
                        i + 1, expectedLine, actualLine));
            }
        }

        return String.format("""

            The actual output from the integration test does not match the expected output.

            Actual output file  : %s
            Expected output file: %s

            Differences:

            %s
            IF THIS IS EXPECTED - for example, if you have changed substantive processes within the model
            or the structure of the output, please:

            1. Verify that the output is correct and as expected.
            2. Replace the expected output file with the new output file:
                cp %s %s
            3. Commit this change (or keep it local, per your project's policy) so future runs pass.

            """, actualFile, expectedFile, differences, actualFile, expectedFile);
    }

    private boolean filesMatchWithTolerance(Path actualFile, Path expectedFile) throws IOException {
        List<String> actualLines = Files.readAllLines(actualFile);
        List<String> expectedLines = Files.readAllLines(expectedFile);

        if (actualLines.size() != expectedLines.size()) {
            return false;
        }
        for (int i = 0; i < expectedLines.size(); i++) {
            if (!linesMatchWithTolerance(expectedLines.get(i), actualLines.get(i))) {
                return false;
            }
        }
        return true;
    }

    private boolean linesMatchWithTolerance(String expectedLine, String actualLine) {
        String[] expectedTokens = expectedLine.split(",", -1);
        String[] actualTokens = actualLine.split(",", -1);

        if (expectedTokens.length != actualTokens.length) {
            return false;
        }
        for (int i = 0; i < expectedTokens.length; i++) {
            if (!tokensMatchWithTolerance(expectedTokens[i], actualTokens[i])) {
                return false;
            }
        }
        return true;
    }

    /**
     * Hybrid numeric tolerance:
     *   - If both tokens parse as doubles, they match when
     *     |a - b| <= max(ABS_EPSILON, REL_EPSILON * max(|a|,|b|)).
     *   - NaN values are treated as equal to each other (Java's == says no, but for
     *     regression-comparison purposes "still NaN" is the intended behaviour).
     *   - +/- infinities must match sign.
     *   - If either token is not numeric, tokens must match exactly as strings.
     *
     * This fixes the UK reference implementation's bug in which any two parseable
     * doubles were considered equal regardless of value.
     */
    private boolean tokensMatchWithTolerance(String expectedToken, String actualToken) {
        String expectedTrimmed = expectedToken.trim();
        String actualTrimmed = actualToken.trim();

        Double expectedNumber = tryParseDouble(expectedTrimmed);
        Double actualNumber = tryParseDouble(actualTrimmed);

        if (expectedNumber != null && actualNumber != null) {
            double e = expectedNumber;
            double a = actualNumber;
            if (Double.isNaN(e) && Double.isNaN(a)) {
                return true;
            }
            if (Double.isNaN(e) || Double.isNaN(a)) {
                return false;
            }
            if (Double.isInfinite(e) || Double.isInfinite(a)) {
                return Double.compare(e, a) == 0;
            }
            double diff = Math.abs(e - a);
            double tolerance = Math.max(ABS_EPSILON, REL_EPSILON * Math.max(Math.abs(e), Math.abs(a)));
            return diff <= tolerance;
        }

        return expectedToken.equals(actualToken);
    }

    private Double tryParseDouble(String value) {
        try {
            return Double.parseDouble(value);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    // ------------------------------------------------------------------
    // Config resolution
    // ------------------------------------------------------------------

    private static Map<String, Object> loadYaml(Path path) {
        try (FileInputStream inputStream = new FileInputStream(path.toFile())) {
            Map<String, Object> config = new Yaml().load(inputStream);
            if (config == null) {
                throw new IllegalStateException("Integration test config is empty: " + path);
            }
            return config;
        } catch (IOException e) {
            throw new IllegalStateException("Failed to read integration test config: " + path, e);
        }
    }

    /**
     * Read {@code parameter_args.trainingFlag} from the run config. Defaults to
     * {@code false} (real-data baseline) when the key is absent.
     */
    @SuppressWarnings("unchecked")
    private boolean resolveTrainingFlag() {
        Object parameterArgs = runConfigMap.get("parameter_args");
        if (!(parameterArgs instanceof Map)) {
            return false;
        }
        Object flag = ((Map<String, Object>) parameterArgs).get("trainingFlag");
        if (flag instanceof Boolean) {
            return (Boolean) flag;
        }
        if (flag instanceof String) {
            return Boolean.parseBoolean((String) flag);
        }
        return false;
    }

    /**
     * Name of the sub-folder under {@code output/} that the run writes into. Must stay in
     * lockstep with the same expression in {@code SimPathsMultiRun}.
     */
    private String resolveOutputSubFolder() {
        return "INTEGRATION_TESTS" + (trainingFlag ? "_TRAINING" : "") + "_" + countryCode;
    }

    /** Two-letter country code (e.g. {@code PL}, {@code ES}) from the config's {@code countryString}. */
    private String resolveCountryCode() {
        Object countryName = runConfigMap.get("countryString");
        if (!(countryName instanceof String countryString)) {
            throw new IllegalStateException("Integration test config is missing a valid countryString: " + runConfigPath);
        }
        return Country.getCountryFromNameString(countryString).toString();
    }

    // ------------------------------------------------------------------
    // Process / assertion helpers
    // ------------------------------------------------------------------

    private void runCommand(String... args) {
        try {
            ProcessBuilder processBuilder = new ProcessBuilder();
            processBuilder.command(args);
            processBuilder.redirectErrorStream(true);

            Process process = processBuilder.start();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    System.out.println(line); // Log output to console when running in Maven
                }
            }
            int exitCode = process.waitFor();
            assertEquals(0, exitCode, "Process exited with error code: " + exitCode);
        } catch (Exception e) {
            throw new RuntimeException("Failed to run: " + e.getMessage(), e);
        }
    }

    private void assertFileExists(String path) {
        assertTrue(new File(path).exists(), "Missing file " + path);
    }
}
