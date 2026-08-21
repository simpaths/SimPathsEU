package simpaths.model.macro;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Unit tests for RamseyScenario.
 *
 * <p>Tests cover:</p>
 * <ol>
 *   <li>CSV loading and column matching</li>
 *   <li>Parameter deviation retrieval (exact year, floor, before-first, after-last)</li>
 *   <li>Permanent shift assumption (beyond last row)</li>
 *   <li>Partial column specification (missing columns default to 0)</li>
 *   <li>Multiple parameter columns</li>
 *   <li>Validation and error handling</li>
 *   <li>Integration with RamseyTrendModel (scenario solve vs baseline)</li>
 * </ol>
 */
public class RamseyScenarioTest {

    private static final Path MACRO_MODEL_DIR = Path.of("input/PL/MacroModel");

    @TempDir
    Path tempDir;

    private RamseyScenario scenario;

    @BeforeEach
    public void setUp() {
        scenario = new RamseyScenario();
    }

    // ========== State Before Loading ==========

    @Test
    public void testEmptyBeforeLoading() {
        assertFalse(scenario.isLoaded());
        assertFalse(scenario.hasAnyDeviations());
        assertNull(scenario.getScenarioName());
        assertEquals(0.0, scenario.getDeviation(2025, "g_A"));
    }

    // ========== Loading Tests ==========

    @Test
    public void testLoadSingleColumn() throws IOException {
        Path csv = tempDir.resolve("test_gA.csv");
        Files.writeString(csv,
            "year, g_A\n" +
            "2025, 0.0025\n" +
            "2026, 0.0025\n");

        scenario.loadFromFile(csv);

        assertTrue(scenario.isLoaded());
        assertTrue(scenario.hasAnyDeviations());
        assertEquals("test_gA.csv", scenario.getScenarioName());
    }

    @Test
    public void testLoadAllColumns() throws IOException {
        Path csv = tempDir.resolve("test_all.csv");
        Files.writeString(csv,
            "year, g_A, delta, alpha_K, beta, sigma, g_Y, nx_Y\n" +
            "2025, 0.0025, 0.01, 0.02, -0.01, 0.5, 0.03, -0.02\n" +
            "2030, 0.005, 0.02, 0.03, -0.02, 1.0, 0.04, -0.03\n");

        scenario.loadFromFile(csv);

        assertTrue(scenario.isLoaded());
        assertEquals(0.0025, scenario.getDeviation(2025, "g_A"), 1e-10);
        assertEquals(0.01, scenario.getDeviation(2025, "delta"), 1e-10);
        assertEquals(0.02, scenario.getDeviation(2025, "alpha_K"), 1e-10);
        assertEquals(-0.01, scenario.getDeviation(2025, "beta"), 1e-10);
        assertEquals(0.5, scenario.getDeviation(2025, "sigma"), 1e-10);
        assertEquals(0.03, scenario.getDeviation(2025, "g_Y"), 1e-10);
        assertEquals(-0.02, scenario.getDeviation(2025, "nx_Y"), 1e-10);

        assertEquals(0.005, scenario.getDeviation(2030, "g_A"), 1e-10);
        assertEquals(1.0, scenario.getDeviation(2030, "sigma"), 1e-10);
        assertEquals(0.04, scenario.getDeviation(2030, "g_Y"), 1e-10);
        assertEquals(-0.03, scenario.getDeviation(2030, "nx_Y"), 1e-10);
    }

    @Test
    public void testLoadWithComments() throws IOException {
        Path csv = tempDir.resolve("test_comments.csv");
        Files.writeString(csv,
            "# This is a comment line\n" +
            "// Another comment\n" +
            "\n" +
            "year, g_A\n" +
            "2025, 0.001\n" +
            "# Inline comment between data rows\n" +
            "2026, 0.002\n");

        scenario.loadFromFile(csv);

        assertTrue(scenario.isLoaded());
        assertEquals(0.001, scenario.getDeviation(2025, "g_A"), 1e-10);
        assertEquals(0.002, scenario.getDeviation(2026, "g_A"), 1e-10);
    }

    @Test
    public void testLoadPartialColumns() throws IOException {
        Path csv = tempDir.resolve("test_partial.csv");
        Files.writeString(csv,
            "year, delta, sigma\n" +
            "2025, 0.01, 0.5\n");

        scenario.loadFromFile(csv);

        // Specified columns have values
        assertEquals(0.01, scenario.getDeviation(2025, "delta"), 1e-10);
        assertEquals(0.5, scenario.getDeviation(2025, "sigma"), 1e-10);

        // Unspecified columns default to 0
        assertEquals(0.0, scenario.getDeviation(2025, "g_A"));
        assertEquals(0.0, scenario.getDeviation(2025, "alpha_K"));
        assertEquals(0.0, scenario.getDeviation(2025, "beta"));
        assertEquals(0.0, scenario.getDeviation(2025, "g_Y"));
        assertEquals(0.0, scenario.getDeviation(2025, "nx_Y"));
    }

    @Test
    public void testLoadCaseInsensitive() throws IOException {
        Path csv = tempDir.resolve("test_case.csv");
        Files.writeString(csv,
            "YEAR, G_A, DELTA, Alpha_K, Beta, SIGMA, G_Y, NX_Y\n" +
            "2025, 0.001, 0.002, 0.003, 0.004, 0.005, 0.006, 0.007\n");

        scenario.loadFromFile(csv);

        assertEquals(0.001, scenario.getDeviation(2025, "g_A"), 1e-10);
        assertEquals(0.002, scenario.getDeviation(2025, "delta"), 1e-10);
        assertEquals(0.003, scenario.getDeviation(2025, "alpha_K"), 1e-10);
        assertEquals(0.004, scenario.getDeviation(2025, "beta"), 1e-10);
        assertEquals(0.005, scenario.getDeviation(2025, "sigma"), 1e-10);
        assertEquals(0.006, scenario.getDeviation(2025, "g_Y"), 1e-10);
        assertEquals(0.007, scenario.getDeviation(2025, "nx_Y"), 1e-10);
    }

    // ========== Deviation Retrieval Tests ==========

    @Test
    public void testExactYearMatch() throws IOException {
        Path csv = tempDir.resolve("test_exact.csv");
        Files.writeString(csv,
            "year, g_A\n" +
            "2025, 0.001\n" +
            "2030, 0.002\n" +
            "2040, 0.003\n");

        scenario.loadFromFile(csv);

        assertEquals(0.001, scenario.getDeviation(2025, "g_A"), 1e-10);
        assertEquals(0.002, scenario.getDeviation(2030, "g_A"), 1e-10);
        assertEquals(0.003, scenario.getDeviation(2040, "g_A"), 1e-10);
    }

    @Test
    public void testFloorEntryLookup() throws IOException {
        Path csv = tempDir.resolve("test_floor.csv");
        Files.writeString(csv,
            "year, g_A\n" +
            "2025, 0.001\n" +
            "2030, 0.002\n");

        scenario.loadFromFile(csv);

        // Between 2025 and 2030: should use 2025 value (floor entry)
        assertEquals(0.001, scenario.getDeviation(2027, "g_A"), 1e-10);
        assertEquals(0.001, scenario.getDeviation(2029, "g_A"), 1e-10);
    }

    @Test
    public void testBeforeFirstYear() throws IOException {
        Path csv = tempDir.resolve("test_before.csv");
        Files.writeString(csv,
            "year, g_A\n" +
            "2025, 0.001\n");

        scenario.loadFromFile(csv);

        // Before first row → baseline (0)
        assertEquals(0.0, scenario.getDeviation(2020, "g_A"));
        assertEquals(0.0, scenario.getDeviation(2024, "g_A"));
    }

    @Test
    public void testPermanentShiftBeyondLastRow() throws IOException {
        Path csv = tempDir.resolve("test_persist.csv");
        Files.writeString(csv,
            "year, g_A, delta\n" +
            "2025, 0.001, 0.01\n" +
            "2030, 0.002, 0.02\n");

        scenario.loadFromFile(csv);

        // Beyond last row → persist last row's values (permanent shift)
        assertEquals(0.002, scenario.getDeviation(2031, "g_A"), 1e-10);
        assertEquals(0.002, scenario.getDeviation(2050, "g_A"), 1e-10);
        assertEquals(0.002, scenario.getDeviation(2100, "g_A"), 1e-10);
        assertEquals(0.02, scenario.getDeviation(2050, "delta"), 1e-10);
    }

    @Test
    public void testGetDeviationsArray() throws IOException {
        Path csv = tempDir.resolve("test_array.csv");
        Files.writeString(csv,
            "year, g_A, delta, alpha_K, beta, sigma, g_Y, nx_Y, psi, phi\n" +
            "2025, 0.001, 0.002, 0.003, 0.004, 0.005, 0.006, 0.007, 0.008, 0.009\n");

        scenario.loadFromFile(csv);

        double[] devs = scenario.getDeviations(2025);
        assertEquals(9, devs.length);
        assertEquals(0.001, devs[RamseyScenario.IDX_G_A], 1e-10);
        assertEquals(0.002, devs[RamseyScenario.IDX_DELTA], 1e-10);
        assertEquals(0.003, devs[RamseyScenario.IDX_ALPHA_K], 1e-10);
        assertEquals(0.004, devs[RamseyScenario.IDX_BETA], 1e-10);
        assertEquals(0.005, devs[RamseyScenario.IDX_SIGMA], 1e-10);
        assertEquals(0.006, devs[RamseyScenario.IDX_G_Y], 1e-10);
        assertEquals(0.007, devs[RamseyScenario.IDX_NX_Y], 1e-10);
        assertEquals(0.008, devs[RamseyScenario.IDX_PSI], 1e-10);
        assertEquals(0.009, devs[RamseyScenario.IDX_PHI], 1e-10);
    }

    @Test
    public void testGetDeviationByIndex() throws IOException {
        Path csv = tempDir.resolve("test_idx.csv");
        Files.writeString(csv,
            "year, g_A\n" +
            "2025, 0.0025\n");

        scenario.loadFromFile(csv);

        assertEquals(0.0025, scenario.getDeviation(2025, RamseyScenario.IDX_G_A), 1e-10);
        assertEquals(0.0, scenario.getDeviation(2025, RamseyScenario.IDX_DELTA));
        assertEquals(0.0, scenario.getDeviation(2025, RamseyScenario.IDX_SIGMA));
    }

    @Test
    public void testUnknownParamNameReturnsZero() throws IOException {
        Path csv = tempDir.resolve("test_unknown.csv");
        Files.writeString(csv,
            "year, g_A\n" +
            "2025, 0.001\n");

        scenario.loadFromFile(csv);

        assertEquals(0.0, scenario.getDeviation(2025, "nonexistent_param"));
    }

    // ========== hasAnyDeviations Tests ==========

    @Test
    public void testAllZeroDeviations() throws IOException {
        Path csv = tempDir.resolve("test_zeros.csv");
        Files.writeString(csv,
            "year, g_A, delta\n" +
            "2025, 0, 0\n" +
            "2026, 0, 0\n");

        scenario.loadFromFile(csv);

        assertTrue(scenario.isLoaded());
        assertFalse(scenario.hasAnyDeviations());
    }

    @Test
    public void testSomeNonZeroDeviations() throws IOException {
        Path csv = tempDir.resolve("test_nonzero.csv");
        Files.writeString(csv,
            "year, g_A, delta\n" +
            "2025, 0, 0\n" +
            "2026, 0.001, 0\n");

        scenario.loadFromFile(csv);

        assertTrue(scenario.hasAnyDeviations());
    }

    // ========== Error Handling ==========

    @Test
    public void testMissingFile() {
        assertThrows(Exception.class,
            () -> scenario.loadFromFile(tempDir.resolve("nonexistent.csv")));
    }

    @Test
    public void testMissingYearColumn() {
        Path csv = tempDir.resolve("test_noyear.csv");
        assertThrows(Exception.class, () -> {
            Files.writeString(csv, "g_A, delta\n0.001, 0.002\n");
            scenario.loadFromFile(csv);
        });
    }

    @Test
    public void testNoParameterColumns() {
        Path csv = tempDir.resolve("test_noparams.csv");
        assertThrows(Exception.class, () -> {
            Files.writeString(csv, "year, random_column\n2025, 1.0\n");
            scenario.loadFromFile(csv);
        });
    }

    @Test
    public void testDuplicateYear() {
        Path csv = tempDir.resolve("test_dup.csv");
        assertThrows(Exception.class, () -> {
            Files.writeString(csv,
                "year, g_A\n" +
                "2025, 0.001\n" +
                "2025, 0.002\n");
            scenario.loadFromFile(csv);
        });
    }

    @Test
    public void testInvalidNumberFormat() {
        Path csv = tempDir.resolve("test_badnum.csv");
        assertThrows(Exception.class, () -> {
            Files.writeString(csv,
                "year, g_A\n" +
                "2025, abc\n");
            scenario.loadFromFile(csv);
        });
    }

    @Test
    public void testInvalidNonFiniteNumber() {
        Path csv = tempDir.resolve("test_nonfinite.csv");
        assertThrows(IllegalArgumentException.class, () -> {
            Files.writeString(csv,
                    "year, g_A\n" +
                    "2025, Infinity\n");
            scenario.loadFromFile(csv);
        });
    }

    @Test
    public void testTrailingEmptyColumnsAreAccepted() throws IOException {
        Path csv = tempDir.resolve("test_trailing_empty.csv");
        Files.writeString(csv,
                "year, g_A, delta\n" +
                "2025, 0.001, ,\n");

        scenario.loadFromFile(csv);
        assertEquals(0.001, scenario.getDeviation(2025, "g_A"), 1e-10);
        assertEquals(0.0, scenario.getDeviation(2025, "delta"), 1e-10);
    }

    // ========== Summary ==========

    @Test
    public void testSummaryWithData() throws IOException {
        Path csv = tempDir.resolve("test_summary.csv");
        Files.writeString(csv,
            "year, g_A, delta\n" +
            "2025, 0.0025, 0\n" +
            "2060, 0.005, 0.01\n");

        scenario.loadFromFile(csv);

        String summary = scenario.getSummary();
        assertNotNull(summary);
        assertTrue(summary.contains("2025"));
        assertTrue(summary.contains("2060"));
        assertTrue(summary.contains("g_A"));
    }

    @Test
    public void testSummaryEmpty() {
        String summary = scenario.getSummary();
        assertNotNull(summary);
        assertTrue(summary.contains("No Ramsey scenario"));
    }

    // ========== Integration: Scenario Effect on RamseyTrendModel ==========

    @Test
    public void testScenarioChangesRamseySolution() throws IOException {
        // This test verifies that a g_A scenario produces DIFFERENT results
        // than the baseline (same model, no scenario). It requires test data.
        Path paramsFile = requireGrowthParamsFixture();
        Path terminalFile = requireTerminalStateFixture();

        if (!Files.exists(paramsFile) || !Files.exists(terminalFile)) {
            System.out.println("Skipping Ramsey scenario integration test: test data not available");
            return;
        }

        // Baseline solve (no scenario)
        RamseyTrendModel baseline = new RamseyTrendModel();
        baseline.loadParams(paramsFile);
        baseline.loadTerminalState(terminalFile);

        int quarters = 40; // 10 years
        double K0 = baseline.getK();
        double A0 = baseline.getA();
        double[] N = new double[quarters];
        double[] h = new double[quarters];
        java.util.Arrays.fill(N, 10000.0);
        java.util.Arrays.fill(h, 36.0);

        double[] gY = new double[quarters];
        double[] nxY = new double[quarters];

        baseline.solveForPath(K0, A0, N, h, gY, nxY, quarters);
        RamseyTrendModel.TrendState baselineYear1 = baseline.stepYear();
        baseline.resetStepping();
        // Step to year 10 for robust comparison
        for (int y = 0; y < 9; y++) baseline.stepYear();
        RamseyTrendModel.TrendState baselineYear10 = baseline.stepYear();

        // Scenario solve (+0.25pp g_A permanently)
        Path scenarioCsv = tempDir.resolve("scenario_gA.csv");
        Files.writeString(scenarioCsv,
            "year, g_A\n2025, 0.0025\n");

        RamseyScenario sc = new RamseyScenario();
        sc.loadFromFile(scenarioCsv);

        RamseyTrendModel scenarioModel = new RamseyTrendModel();
        scenarioModel.loadParams(paramsFile);
        scenarioModel.loadTerminalState(terminalFile);
        scenarioModel.setScenario(sc, 2025);
        scenarioModel.solveForPath(K0, A0, N, h, gY, nxY, quarters);

        RamseyTrendModel.TrendState scenarioYear1 = scenarioModel.stepYear();
        scenarioModel.resetStepping();
        for (int y = 0; y < 9; y++) scenarioModel.stepYear();
        RamseyTrendModel.TrendState scenarioYear10 = scenarioModel.stepYear();

        // Higher TFP growth should lead to higher output and wages at year 10
        assertTrue(scenarioYear10.output() > baselineYear10.output(),
                "Scenario output at year 10 should exceed baseline");
        assertTrue(scenarioYear10.wage() > baselineYear10.wage(),
                "Scenario wage at year 10 should exceed baseline");

        // The difference should grow over time (compounding effect)
        double outputDiffYear1 = scenarioYear1.output() / baselineYear1.output() - 1.0;
        double outputDiffYear10 = scenarioYear10.output() / baselineYear10.output() - 1.0;
        assertTrue(outputDiffYear10 > outputDiffYear1,
                "Output gap should widen over time with higher TFP growth");

        System.out.println(String.format(
                "Ramsey scenario test: Year 1 output gap=%.4f%%, Year 10 output gap=%.4f%%",
                outputDiffYear1 * 100, outputDiffYear10 * 100));
    }

    @Test
    public void testZeroScenarioMatchesBaseline() throws IOException {
        // A scenario with all-zero deviations should produce identical results to baseline
        Path paramsFile = requireGrowthParamsFixture();
        Path terminalFile = requireTerminalStateFixture();

        if (!Files.exists(paramsFile) || !Files.exists(terminalFile)) {
            System.out.println("Skipping zero-scenario test: test data not available");
            return;
        }

        int quarters = 40;
        double[] N = new double[quarters];
        double[] h = new double[quarters];
        java.util.Arrays.fill(N, 10000.0);
        java.util.Arrays.fill(h, 36.0);

        // Baseline
        RamseyTrendModel baseline = new RamseyTrendModel();
        baseline.loadParams(paramsFile);
        baseline.loadTerminalState(terminalFile);
        double K0 = baseline.getK();
        double A0 = baseline.getA();
        double[] gY = new double[quarters];
        double[] nxY = new double[quarters];
        baseline.solveForPath(K0, A0, N, h, gY, nxY, quarters);

        // Zero scenario
        Path zeroCsv = tempDir.resolve("zero_scenario.csv");
        Files.writeString(zeroCsv,
            "year, g_A, delta, alpha_K, beta, sigma, g_Y, nx_Y\n" +
            "2025, 0, 0, 0, 0, 0, 0, 0\n");

        RamseyScenario zeroSc = new RamseyScenario();
        zeroSc.loadFromFile(zeroCsv);
        assertFalse(zeroSc.hasAnyDeviations(), "All-zero scenario should report no deviations");

        RamseyTrendModel withZero = new RamseyTrendModel();
        withZero.loadParams(paramsFile);
        withZero.loadTerminalState(terminalFile);
        withZero.setScenario(zeroSc, 2025);
        // hasScenario() should be false for all-zero scenario
        assertFalse(withZero.hasScenario(),
                "All-zero scenario should not count as active");
        withZero.solveForPath(K0, A0, N, h, gY, nxY, quarters);

        // Compare quarter by quarter
        for (int q = 0; q < quarters; q++) {
            var bState = baseline.getTrendAtQuarter(q);
            var sState = withZero.getTrendAtQuarter(q);

            assertEquals(bState.output(), sState.output(), 1e-6,
                    "Output should match at quarter " + q);
            assertEquals(bState.wage(), sState.wage(), 1e-8,
                    "Wage should match at quarter " + q);
            assertEquals(bState.capitalStock(), sState.capitalStock(), 1e-4,
                    "Capital should match at quarter " + q);
        }

        System.out.println("Zero-scenario produces identical results to baseline ✓");
    }

    private static Path requireGrowthParamsFixture() throws IOException {
        try (var stream = Files.list(MACRO_MODEL_DIR)) {
            return stream
                .filter(path -> {
                    String name = path.getFileName().toString();
                    return name.startsWith("growth_params_") && name.endsWith(".json");
                })
                .sorted()
                .findFirst()
                .orElseThrow(() -> new IOException("No growth_params_*.json fixture found in " + MACRO_MODEL_DIR));
        }
    }

    private static Path requireTerminalStateFixture() {
        return MACRO_MODEL_DIR.resolve("growth_terminal_state.json");
    }

    // ========== Index Constants ==========

    @Test
    public void testIndexConstants() {
        assertEquals(0, RamseyScenario.IDX_G_A);
        assertEquals(1, RamseyScenario.IDX_DELTA);
        assertEquals(2, RamseyScenario.IDX_ALPHA_K);
        assertEquals(3, RamseyScenario.IDX_BETA);
        assertEquals(4, RamseyScenario.IDX_SIGMA);
        assertEquals(5, RamseyScenario.IDX_G_Y);
        assertEquals(6, RamseyScenario.IDX_NX_Y);
    }

    @Test
    public void testParamNames() {
        assertEquals("g_A", RamseyScenario.PARAM_NAMES[0]);
        assertEquals("delta", RamseyScenario.PARAM_NAMES[1]);
        assertEquals("alpha_K", RamseyScenario.PARAM_NAMES[2]);
        assertEquals("beta", RamseyScenario.PARAM_NAMES[3]);
        assertEquals("sigma", RamseyScenario.PARAM_NAMES[4]);
        assertEquals("g_Y", RamseyScenario.PARAM_NAMES[5]);
        assertEquals("nx_Y", RamseyScenario.PARAM_NAMES[6]);
    }
}

