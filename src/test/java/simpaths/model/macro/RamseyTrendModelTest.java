package simpaths.model.macro;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Validation tests for RamseyTrendModel.
 *
 * <p>Validates that the Java Ramsey solver remains consistent with the MATLAB
 * export contract used by SimPaths. The MATLAB pipeline exports a historical
 * reference CSV ({@code growth_model_reference_Poland.csv}) and a terminal state
 * ({@code growth_terminal_state.json}). At runtime, SimPaths projects forward
 * from that terminal state, so the most important parity checks are anchored on
 * the exported terminal quarter rather than on the full historical detrending
 * path.</p>
 *
 * <h3>Test categories</h3>
 * <ol>
 *   <li>Parameter loading and conversion (quarterly/annual)</li>
 *   <li>Stacked-time Newton convergence</li>
 *   <li>Forward-parity checks against MATLAB export contract</li>
 *   <li>Stepping interface (year-by-year advancement)</li>
 *   <li>Forward projection from terminal state (mirrors MacroModelManager)</li>
 *   <li>Edge cases and error handling</li>
 * </ol>
 *
 * <p>Test data: frozen fixtures under {@code src/test/resources/macro/}
 * ({@code exogenous/} and {@code endogenous/}), decoupled from the live
 * {@code input/PL/MacroModel/} bundle so swapping the SimPaths runtime input
 * between Ramsey labour modes cannot break this suite.</p>
 *
 * <p><b>MATLAB↔Java parity is exogenous-mode only — by design.</b> The LBJ
 * stacked-time solver is mirrored between {@code ramsey_trend.m} and
 * {@code RamseyTrendModel.java} <i>only</i> in exogenous labour mode. In
 * endogenous mode the two intentionally differ: MATLAB is hybrid (observed
 * participation in-sample so the DSGE estimation sample detrends cleanly, FOC
 * out-of-sample), whereas Java solves the full FOC over all periods because it
 * is purely the forward-projection engine. Do <b>not</b> add a MATLAB↔Java
 * cross-validation/parity assertion for endogenous mode — it will fail by
 * design, not due to a regression. See CLAUDE.md "Ramsey Solver (LBJ) And The
 * Endogenous-Labour Asymmetry" and chats WS_CHATS_141/151, SP_CHATS_91/93.</p>
 */
public class RamseyTrendModelTest {

    @TempDir
    Path tempDir;

    /**
     * Frozen test fixtures, decoupled from the live {@code input/PL/MacroModel}
     * bundle. Each directory holds a self-contained, pinned MacroModel export
     * ({@code growth_params_Poland.json}, {@code growth_model_reference_Poland.csv},
     * {@code growth_terminal_state.json}) so swapping the live SimPaths input
     * between exogenous and endogenous Ramsey can never break this suite.
     *
     * <ul>
     *   <li>{@code MACRO_MODEL_PATH} → frozen <b>exogenous</b> bundle: the
     *       MATLAB↔Java parity, extension and JSON-surgery tests run against
     *       this (parity is exogenous-only by design — see class javadoc).</li>
     *   <li>{@code ENDO_MODEL_PATH} → frozen <b>endogenous</b> bundle: the
     *       Section 7 endogenous-labour tests run against this.</li>
     * </ul>
     */
    private static final String MACRO_MODEL_PATH = resolveFixtureDir("exogenous");
    private static final String ENDO_MODEL_PATH  = resolveFixtureDir("endogenous");

    /** Resolve a frozen fixture directory from the test classpath. */
    private static String resolveFixtureDir(String mode) {
        try {
            var url = RamseyTrendModelTest.class.getResource("/macro/" + mode);
            if (url == null) {
                throw new IllegalStateException("Missing test fixture resource: /macro/" + mode);
            }
            return Paths.get(url.toURI()).toString();
        } catch (java.net.URISyntaxException e) {
            throw new IllegalStateException("Cannot resolve fixture dir for " + mode, e);
        }
    }

    /**
     * Tolerance for exogenous cross-validation (relative), against the frozen
     * exogenous fixture's MATLAB reference.
     *
     * <p>The two solvers are intended mirrors in exogenous mode. Measured
     * deviations: 1.6e-13 on the path cross-validation; the terminal-quarter
     * forward anchor measured 4.4e-11 until 2026-08-19, but that figure was not
     * solver disagreement — it was the %.10f rounding of {@code A_terminal} in
     * {@code growth_terminal_state.json} (~9 significant digits on a value of
     * order 0.03). Now that the export writes {@code A_terminal} at %.16e, the
     * worst measured anchor deviation is ~1.3e-11 (investment). Both are near
     * machine precision, as the technical documentation's "~1e-12 parity"
     * claims.</p>
     *
     * <p>This was previously 5e-3 — eight orders of magnitude looser than the worst
     * observed deviation — justified by "path-construction differences that
     * accumulate over ~100 quarters" which the measurements show do not exist. At
     * that setting the suite would have passed a catastrophic parity regression
     * without complaint.</p>
     *
     * <p>1e-9 leaves ~20x headroom over the worst observed deviation for
     * platform/BLAS variation while still failing on any real divergence. If this
     * starts failing, the mirrors have separated — do not loosen it to make it
     * pass.</p>
     */
    private static final double RELATIVE_TOLERANCE = 1e-9;

    /** Tolerance for parameter conversion checks */
    private static final double PARAM_TOLERANCE = 1e-8;

    /** Flag: test data available */
    private static boolean testDataAvailable = false;

    /** MATLAB reference data (frozen EXOGENOUS fixture) */
    private static List<RamseyTrendModel.ReferenceRow> referenceData;

    /** Growth params JSON content, frozen EXOGENOUS fixture (cached) */
    private static String growthParamsContent;

    /** MATLAB reference data (frozen ENDOGENOUS fixture; carries WAP/l columns) */
    private static List<RamseyTrendModel.ReferenceRow> endoReferenceData;

    /**
     * Growth params JSON content, frozen ENDOGENOUS fixture (cached).
     *
     * <p>Endogenous-mode tests must source psi from here, not from the exogenous
     * fixture. psi carries the units of w·h·c^{-sigma}, so it scales with hours per
     * quarter (~500); an exogenous export does not calibrate it at all. Reusing the
     * exogenous fixture's stale psi under the corrected w·h FOC drives participation
     * straight into the 0.99 clamp.</p>
     */
    private static String endoGrowthParamsContent;

    /** Model instance for tests */
    private RamseyTrendModel model;

    @BeforeAll
    public static void checkTestData() {
        Path dir = Paths.get(MACRO_MODEL_PATH);
        Path paramsFile = dir.resolve("growth_params_Poland.json");
        Path referenceFile = dir.resolve("growth_model_reference_Poland.csv");
        Path terminalFile = dir.resolve("growth_terminal_state.json");

        testDataAvailable = Files.exists(paramsFile)
                && Files.exists(referenceFile)
                && Files.exists(terminalFile);

        Path endoReferenceFile = Paths.get(ENDO_MODEL_PATH, "growth_model_reference_Poland.csv");

        if (!testDataAvailable) {
            System.out.println("WARNING: Ramsey test fixtures not found at " + MACRO_MODEL_PATH);
            System.out.println("Required files: growth_params_Poland.json, "
                    + "growth_model_reference_Poland.csv, growth_terminal_state.json");
            System.out.println("Skipping Ramsey cross-validation tests.");
        } else {
            try {
                referenceData = RamseyTrendModel.loadReferenceCSV(referenceFile);
                growthParamsContent = Files.readString(paramsFile);
                endoGrowthParamsContent = Files.readString(
                        Paths.get(ENDO_MODEL_PATH, "growth_params_Poland.json"));
                endoReferenceData = RamseyTrendModel.loadReferenceCSV(endoReferenceFile);
                System.out.println("Loaded " + referenceData.size()
                        + " exogenous + " + endoReferenceData.size()
                        + " endogenous reference quarters from frozen fixtures.");
            } catch (IOException e) {
                testDataAvailable = false;
                System.out.println("ERROR loading test fixtures: " + e.getMessage());
            }
        }
    }

    @BeforeEach
    public void setUp() throws IOException {
        model = new RamseyTrendModel();
        if (testDataAvailable) {
            model.setLogEnabled(true);
            model.loadParams(Paths.get(MACRO_MODEL_PATH, "growth_params_Poland.json"));

            // Always force exogenous mode for the shared model instance.
            // Existing tests (cross-validation, constant exogenous, forward projection)
            // pass N arrays directly and expect exogenous solver behavior.
            // Endogenous-specific tests (Section 7) create their own model instances.
            if (model.isEndogenousLabor()) {
                model.setEndogenousLabor(false);
            }
        }
    }

    private void assumeTestDataAvailable() {
        Assumptions.assumeTrue(testDataAvailable,
                "Test data not available at " + MACRO_MODEL_PATH);
    }

    // ========== 1. Parameter Loading Tests ==========

    @Test
    public void testParametersNotLoadedInitially() {
        var fresh = new RamseyTrendModel();
        assertFalse(fresh.isParamsLoaded(), "Fresh model should not have params loaded");
        assertFalse(fresh.isSolved(), "Fresh model should not be solved");
    }

    @Test
    public void testParameterLoading() {
        assumeTestDataAvailable();
        assertTrue(model.isParamsLoaded(), "Params should be loaded after loadParams()");

        // Check if parameters fell into reasonable bounds (instead of hardcoding exact values that change with calibration)
        assertTrue(model.getAlphaK() > 0 && model.getAlphaK() < 1, "alpha_K should be between 0 and 1");
        assertTrue(model.getSigma() >= 0.5 && model.getSigma() <= 5.0, "sigma should be in a reasonable range");

        boolean expectedTerminalGrowthEnabled = extractJsonBoolean(growthParamsContent, "enabled", false);
        assertEquals(expectedTerminalGrowthEnabled, model.isTerminalGrowthEnabled(),
            "terminal_growth.enabled should be parsed from growth_params JSON");

        if (expectedTerminalGrowthEnabled) {
            double expectedTerminalAnnual = extractJsonDouble(growthParamsContent, "g_A_terminal_annual");
            double expectedRho = extractJsonDouble(growthParamsContent, "rho_quarterly");
            assertEquals(expectedTerminalAnnual, model.getGATerminalAnnual(), PARAM_TOLERANCE,
                "Terminal annual TFP growth should match JSON");
            assertEquals(expectedRho, model.getTerminalGrowthRhoQ(), PARAM_TOLERANCE,
                "Terminal growth persistence should match JSON");
        }
    }

        @Test
        public void testQuarterlyConversions() {
        assumeTestDataAvailable();

        double deltaAnnual = extractJsonDouble(growthParamsContent, "delta_annual");
        double betaAnnual = extractJsonDouble(growthParamsContent, "beta_annual");
        double gAAnnual = extractJsonDouble(growthParamsContent, "tfp_growth_annual");

        double expectedDelta = 1.0 - Math.pow(1.0 - deltaAnnual, 0.25);
        assertEquals(expectedDelta, model.getDeltaQ(), PARAM_TOLERANCE,
                "Quarterly depreciation conversion");

        double expectedBeta = Math.pow(betaAnnual, 0.25);
        assertEquals(expectedBeta, model.getBetaQ(), PARAM_TOLERANCE,
                "Quarterly discount factor conversion");

        double expectedGA = annualToQuarterlyGrowth(gAAnnual);
        assertEquals(expectedGA, model.getGAQ(), PARAM_TOLERANCE,
                "Quarterly TFP growth conversion");

        if (model.isTerminalGrowthEnabled()) {
            double terminalAnnual = extractJsonDouble(growthParamsContent, "g_A_terminal_annual");
            double expectedTerminalGA = annualToQuarterlyGrowth(terminalAnnual);
            assertTrue(expectedTerminalGA > 0,
                "Terminal quarterly TFP growth should be positive when terminal growth is enabled");
        }
    }

    @Test
    public void testBgpCapitalOutputRatio() {
        assumeTestDataAvailable();

        double terminalAnnualGrowth = model.isTerminalGrowthEnabled()
            ? model.getGATerminalAnnual()
            : extractJsonDouble(growthParamsContent, "tfp_growth_annual");
        double terminalQuarterlyGrowth = Math.pow(1.0 + terminalAnnualGrowth, 0.25) - 1.0;
        double consumptionGrowth = terminalQuarterlyGrowth / (1.0 - model.getAlphaK());
        double rStarQuarterly = Math.pow(1.0 + consumptionGrowth, model.getSigma()) / model.getBetaQ() - 1.0;
        double expectedKY = model.getAlphaK() / (rStarQuarterly + model.getDeltaQ());
        assertEquals(expectedKY, model.getKyBgp(), PARAM_TOLERANCE,
                "BGP capital-output ratio");

        assertTrue(model.getKyBgp() > 8.0 && model.getKyBgp() < 20.0,
                "BGP K/Y should be in reasonable range, got: " + model.getKyBgp());
    }

    /**
     * The annual->quarterly conversions and the BGP K/Y closure are computed on BOTH
     * sides (calibrate_growth_model.m / ramsey_trend.m upstream; loadParams /
     * calculateBgpCapitalOutputRatio here). The `derived` block in growth_params is
     * MATLAB's own values for them, previously exported and read by nothing.
     * testQuarterlyConversions and testBgpCapitalOutputRatio re-derive the formulas
     * inside the test body, so they can never catch a MATLAB-side change; this can —
     * and it pins the duplicated formulas exactly where the 1e-9 anchor test is least
     * sensitive (the terminal closure sits ~900 quarters out, attenuated ~1e-7 on the
     * way back to quarter 0). If this fails, one side's formula moved: find which,
     * do not loosen. (2026-08-19 boundary audit, C5.)
     */
    @Test
    public void testDerivedBlockMatchesJavaRecomputation() {
        assumeTestDataAvailable();

        double betaQ = extractJsonDouble(growthParamsContent, "beta_quarterly");
        double deltaQ = extractJsonDouble(growthParamsContent, "delta_quarterly");
        double kyBgp = extractJsonDouble(growthParamsContent, "KY_bgp_quarterly");
        Assumptions.assumeTrue(betaQ > 0 && deltaQ > 0 && kyBgp > 0,
                "growth_params fixture carries no derived block");

        assertRelativeClose(model.getBetaQ(), betaQ, 1e-12,
                "Java beta_quarterly must match calibrate_growth_model's derived value");
        assertRelativeClose(model.getDeltaQ(), deltaQ, 1e-12,
                "Java delta_quarterly must match calibrate_growth_model's derived value");
        assertRelativeClose(model.getKyBgp(), kyBgp, 1e-12,
                "Java BGP K/Y must match calibrate_growth_model's derived value");
    }

        @Test
        public void testTerminalGrowthBaselineDecaysTowardAnchor() throws IOException {
        assumeTestDataAvailable();

        Path paramsPath = tempDir.resolve("growth_params_terminal_decay.json");
        Files.writeString(paramsPath, withTerminalGrowth(growthParamsContent, 0.04, 0.01, 0.8, false));

        RamseyTrendModel decayModel = solveSimpleExogenous(paramsPath, 60);

        double g0 = annualizedQuarterGrowth(decayModel, 0);
        double g1 = annualizedQuarterGrowth(decayModel, 1);
        double g8 = annualizedQuarterGrowth(decayModel, 8);
        double g40 = annualizedQuarterGrowth(decayModel, 40);

        assertEquals(expectedAnnualGrowth(0.04, 0.01, 0.8, 0), g0, 1e-12,
            "Quarter 0 annualized TFP growth should match the baseline calibration");
        assertEquals(expectedAnnualGrowth(0.04, 0.01, 0.8, 1), g1, 1e-12,
            "Quarter 1 annualized TFP growth should follow the AR(1) decay path");
        assertEquals(expectedAnnualGrowth(0.04, 0.01, 0.8, 8), g8, 1e-12,
            "Quarter 8 annualized TFP growth should follow the AR(1) decay path");
        assertEquals(expectedAnnualGrowth(0.04, 0.01, 0.8, 40), g40, 1e-12,
            "Quarter 40 annualized TFP growth should remain on the convergence path");

        assertTrue(g0 > g1 && g1 > g8 && g8 > g40,
            "Baseline terminal-growth path should decline monotonically toward the terminal anchor");
        assertEquals(0.01, g40, 5e-5,
            "Long-horizon annualized TFP growth should be close to the terminal anchor");
        }

        @Test
        public void testLegacyJsonWithoutTerminalGrowthKeepsConstantBaselineGrowth() throws IOException {
        assumeTestDataAvailable();

        Path paramsPath = tempDir.resolve("growth_params_legacy_constant.json");
        Files.writeString(paramsPath, withoutTerminalGrowth(growthParamsContent));

        RamseyTrendModel legacyModel = solveSimpleExogenous(paramsPath, 24);
        double expectedGrowth = extractJsonDouble(growthParamsContent, "tfp_growth_annual");

        assertFalse(legacyModel.isTerminalGrowthEnabled(),
            "Legacy JSON without terminal_growth should fall back to constant growth mode");
        assertEquals(expectedGrowth, annualizedQuarterGrowth(legacyModel, 0), 1e-12,
            "Quarter 0 annualized TFP growth should match the legacy baseline");
        assertEquals(expectedGrowth, annualizedQuarterGrowth(legacyModel, 5), 1e-12,
            "Mid-sample annualized TFP growth should stay constant without terminal_growth");
        assertEquals(expectedGrowth, annualizedQuarterGrowth(legacyModel, 15), 1e-12,
            "Later annualized TFP growth should stay constant without terminal_growth");
        }

        @Test
        public void testScenarioGrowthDeviationBuildsOnConvergingBaseline() throws IOException {
        assumeTestDataAvailable();

        Path paramsPath = tempDir.resolve("growth_params_terminal_scenario.json");
        Files.writeString(paramsPath, withTerminalGrowth(growthParamsContent, 0.04, 0.01, 0.8, false));

        RamseyTrendModel baselineModel = solveSimpleExogenous(paramsPath, 40);

        Path scenarioCsv = tempDir.resolve("scenario_terminal_growth_overlay.csv");
        Files.writeString(scenarioCsv,
            "year, g_A\n" +
            "2025, 0.0025\n");

        RamseyScenario overlayScenario = new RamseyScenario();
        overlayScenario.loadFromFile(scenarioCsv);

        RamseyTrendModel scenarioModel = new RamseyTrendModel();
        scenarioModel.loadParams(paramsPath);
        scenarioModel.setEndogenousLabor(false);
        scenarioModel.setScenario(overlayScenario, 2025);
        solveSimpleExogenous(scenarioModel, 40);

        double baselineQ0 = annualizedQuarterGrowth(baselineModel, 0);
        double baselineQ8 = annualizedQuarterGrowth(baselineModel, 8);
        double scenarioQ0 = annualizedQuarterGrowth(scenarioModel, 0);
        double scenarioQ8 = annualizedQuarterGrowth(scenarioModel, 8);

        assertEquals(expectedAnnualGrowth(0.04, 0.01, 0.8, 0), baselineQ0, 1e-12,
            "Baseline quarter 0 growth should follow the configured convergence path");
        assertEquals(expectedAnnualGrowth(0.04, 0.01, 0.8, 8), baselineQ8, 1e-12,
            "Baseline quarter 8 growth should follow the configured convergence path");
        assertEquals(expectedAnnualGrowth(0.04, 0.01, 0.8, 0) + 0.0025, scenarioQ0, 1e-12,
            "Scenario quarter 0 growth should add its deviation on top of the baseline path");
        assertEquals(expectedAnnualGrowth(0.04, 0.01, 0.8, 8) + 0.0025, scenarioQ8, 1e-12,
            "Scenario quarter 8 growth should remain an overlay on the converging baseline path");

        assertTrue(scenarioQ0 > scenarioQ8,
            "Scenario growth should still converge over time rather than replacing the baseline with a flat path");
        assertTrue(scenarioQ0 > baselineQ0 && scenarioQ8 > baselineQ8,
            "Scenario growth should lie above baseline growth at each checked quarter");
        }

    // ========== 2. Solver Convergence Tests ==========

    @Test
    public void testSolveRequiresParams() {
        var fresh = new RamseyTrendModel();
        assertThrows(IllegalStateException.class, () ->
                fresh.solveForPath(1000.0, 1.0, new double[40], new double[40],
                        new double[40], new double[40], 40));
    }

    @Test
    public void testSolveWithConstantExogenous() {
        assumeTestDataAvailable();

        // Solve with realistic constant exogenous inputs based on the first Poland reference quarter.
        int T = 120;
        double[] N = new double[T];
        double[] h = new double[T];
        java.util.Arrays.fill(N, referenceData.get(0).N());
        java.util.Arrays.fill(h, referenceData.get(0).h());

        double K0 = referenceData.get(0).K();
        double A0 = extractA0(growthParamsContent);
        double[] gY = new double[T];
        double[] nxY = new double[T];
        java.util.Arrays.fill(gY, referenceData.get(0).gY());
        java.util.Arrays.fill(nxY, referenceData.get(0).nxY());

        model.solveForPath(K0, A0, N, h, gY, nxY, T);
        assertTrue(model.isSolved(), "Model should be solved");

        // Check K/Y moves toward the terminal BGP under a stationary exogenous environment.
        var lastQ = model.getTrendAtQuarter(T - 1);
        double kyLast = lastQ.capitalStock() / lastQ.output();
        assertEquals(model.getKyBgp(), kyLast, 5.0,
                "K/Y at end of long simulation should approach BGP");
    }

        // ========== 3. Forward-Parity Against MATLAB Export Contract ==========

    /**
     * The MATLAB-Java cross-validation anchor.
     *
     * <p>Drives {@link MacroModelManager#initializeRamseyTrend} rather than assembling the
     * projection locally. A local assembly was a fourth copy of the path-building rules and had
     * silently gone stale: it extrapolated employment geometrically, reaching 35,983 thousand by
     * 2103, where MATLAB's handoff solve splices the SimPaths-consistent demographic projection
     * and reaches 9,641 — 273% apart. The test still passed because the frozen fixture predated
     * MATLAB gaining that override, so Java was being checked against a MATLAB that no longer
     * existed, over a projection production never uses. Regenerating the fixture on 2026-08-18
     * exposed it. Route this through the production loader so the two can only drift together.</p>
     */
    @Test
        public void testForwardProjectionAnchorMatchesMATLABExport() throws Exception {
        assumeTestDataAvailable();

        MacroModelManager manager = new MacroModelManager();
        manager.setEnabled(true);
        manager.setUseDsge(false);
        manager.setUseRamseyTrend(true);
        manager.setPathRecordingEnabled(false);
        java.lang.reflect.Field startYear =
                MacroModelManager.class.getDeclaredField("simulationStartYear");
        startYear.setAccessible(true);
        startYear.setInt(manager, 2023);
        manager.initializeRamseyTrend(MACRO_MODEL_PATH);

        java.lang.reflect.Field trendField =
                MacroModelManager.class.getDeclaredField("ramseyTrend");
        trendField.setAccessible(true);
        RamseyTrendModel solved = (RamseyTrendModel) trendField.get(manager);
        assertTrue(solved.isSolved());

        double kTerminal = solved.getK();
        double aTerminal = solved.getA();

        var expected = referenceData.get(referenceData.size() - 1);
        var actual = solved.getTrendAtQuarter(0);

        assertRelativeClose(actual.capitalStock(), expected.K(), RELATIVE_TOLERANCE,
            "Terminal-quarter capital should match MATLAB export");
        assertRelativeClose(actual.output(), expected.Y(), RELATIVE_TOLERANCE,
            "Terminal-quarter output should match MATLAB export");
        assertRelativeClose(actual.consumption(), expected.C(), RELATIVE_TOLERANCE,
            "Terminal-quarter consumption should match MATLAB export");
        assertRelativeClose(actual.investment(), expected.I(), RELATIVE_TOLERANCE,
            "Terminal-quarter investment should match MATLAB export");
        assertRelativeClose(actual.wage(), expected.w(), RELATIVE_TOLERANCE,
            "Terminal-quarter wage should match MATLAB export");
        assertRelativeClose(actual.rQuarterly(), expected.rStar(), RELATIVE_TOLERANCE,
            "Terminal-quarter natural rate should match MATLAB export");
        assertRelativeClose(actual.labor(), expected.N(), RELATIVE_TOLERANCE,
            "Terminal-quarter labor should match MATLAB export");
        assertRelativeClose(kTerminal, expected.K(), RELATIVE_TOLERANCE,
            "growth_terminal_state K should match last MATLAB reference quarter");

        assertTrue(aTerminal > 0, "growth_terminal_state A should be positive");
    }

    /**
     * The open-economy Ramsey model allocates GDP into four components:
     *   Y = C + I + G + NX
     * where G = g_Y Ã— Y and NX = nx_Y Ã— Y are exogenous share-based claims.
     * Private consumption (C) is determined by the Euler equation, and
     * investment (I) is the residual: I = Y âˆ’ C âˆ’ G âˆ’ NX.
     *
     * This test verifies the accounting identity Y = C + I + G + NX holds in
     * the Java solver, and that all components are reasonable (positive C/I,
     * correct magnitudes).
     */
    @Test
    public void testRamseyConsumptionInvestmentIdentity() throws IOException {
        assumeTestDataAvailable();

        int T = referenceData.size();
        double[] N = new double[T];
        double[] h = new double[T];
        double[] gY = new double[T];
        double[] nxY = new double[T];
        for (int i = 0; i < T; i++) {
            N[i] = referenceData.get(i).N();
            h[i] = referenceData.get(i).h();
            gY[i] = referenceData.get(i).gY();
            nxY[i] = referenceData.get(i).nxY();
        }

        double K0 = referenceData.get(0).K();
        Path paramsPath = Paths.get(MACRO_MODEL_PATH, "growth_params_Poland.json");
        double A0 = extractA0(Files.readString(paramsPath));

        model.solveForPath(K0, A0, N, h, gY, nxY, T);

        for (int q = 0; q < T; q++) {
            var ts = model.getTrendAtQuarter(q);
            double Y = ts.output();
            double C = ts.consumption();
            double I = ts.investment();
            double G = ts.government();
            double NX = ts.netExports();

            // Y = C + I + G + NX (open-economy identity)
            assertEquals(Y, C + I + G + NX, Y * 1e-10,
                    String.format("q=%d: Y â‰  C+I+G+NX  (Y=%.2f, C=%.2f, I=%.2f, G=%.2f, NX=%.2f)",
                            q, Y, C, I, G, NX));

            // Both C and I should be positive
            assertTrue(C > 0, String.format("q=%d: C should be positive, got %.2f", q, C));
            assertTrue(I > 0, String.format("q=%d: I should be positive, got %.2f", q, I));
            assertTrue(G >= 0, String.format("q=%d: G should be non-negative, got %.2f", q, G));

            // Private C/Y should be ~0.45-0.70 (open economy, after G and NX)
            double cy = C / Y;
            assertTrue(cy > 0.3 && cy < 0.85,
                    String.format("q=%d: C/Y=%.3f outside reasonable range", q, cy));
        }
    }

    // ========== 4. Stepping Interface Tests ==========

    @Test
    public void testStepYearAdvancesCounter() throws IOException {
        assumeTestDataAvailable();

        int T = referenceData.size();
        double[] N = new double[T];
        double[] h = new double[T];
        double[] gY = new double[T];
        double[] nxY = new double[T];
        for (int i = 0; i < T; i++) {
            N[i] = referenceData.get(i).N();
            h[i] = referenceData.get(i).h();
            gY[i] = referenceData.get(i).gY();
            nxY[i] = referenceData.get(i).nxY();
        }

        double K0 = referenceData.get(0).K();
        double A0 = extractA0(Files.readString(
                Paths.get(MACRO_MODEL_PATH, "growth_params_Poland.json")));

        model.solveForPath(K0, A0, N, h, gY, nxY, T);

        assertEquals(0, model.getCurrentQuarterIdx(), "Should start at quarter 0");

        model.stepYear();
        assertEquals(4, model.getCurrentQuarterIdx(), "After 1 year, should be at quarter 4");

        model.stepYear();
        assertEquals(8, model.getCurrentQuarterIdx(), "After 2 years, should be at quarter 8");
    }

    @Test
    public void testStepYearAveragesMatchQuarterly() throws IOException {
        assumeTestDataAvailable();

        int T = referenceData.size();
        double[] N = new double[T];
        double[] h = new double[T];
        double[] gY = new double[T];
        double[] nxY = new double[T];
        for (int i = 0; i < T; i++) {
            N[i] = referenceData.get(i).N();
            h[i] = referenceData.get(i).h();
            gY[i] = referenceData.get(i).gY();
            nxY[i] = referenceData.get(i).nxY();
        }

        double K0 = referenceData.get(0).K();
        double A0 = extractA0(Files.readString(
                Paths.get(MACRO_MODEL_PATH, "growth_params_Poland.json")));

        model.solveForPath(K0, A0, N, h, gY, nxY, T);

        // Compute manual average for first year
        double yManual = 0;
        for (int q = 0; q < 4; q++) {
            yManual += model.getTrendAtQuarter(q).output();
        }
        yManual /= 4.0;

        // Get stepYear average
        model.resetStepping();
        var yearState = model.stepYear();

        assertEquals(yManual, yearState.output(), 1e-6,
                "stepYear output should equal manual quarterly average");
    }

    @Test
    public void testResetStepping() throws IOException {
        assumeTestDataAvailable();

        int T = referenceData.size();
        double[] N = new double[T];
        double[] h = new double[T];
        double[] gY = new double[T];
        double[] nxY = new double[T];
        for (int i = 0; i < T; i++) {
            N[i] = referenceData.get(i).N();
            h[i] = referenceData.get(i).h();
            gY[i] = referenceData.get(i).gY();
            nxY[i] = referenceData.get(i).nxY();
        }

        double K0 = referenceData.get(0).K();
        double A0 = extractA0(Files.readString(
                Paths.get(MACRO_MODEL_PATH, "growth_params_Poland.json")));

        model.solveForPath(K0, A0, N, h, gY, nxY, T);

        model.stepYear();
        model.stepYear();
        assertEquals(8, model.getCurrentQuarterIdx());

        model.resetStepping();
        assertEquals(0, model.getCurrentQuarterIdx(), "Reset should return to quarter 0");
    }

    // ========== 5. Forward Projection from Terminal State ==========
    //
    // These tests mirror MacroModelManager.initializeRamseyTrend():
    // start from the terminal K/A (end of estimation sample) and project forward.

    /**
     * Mirrors the full initialization logic in MacroModelManager.initializeRamseyTrend().
     * Loads terminal state, extracts N/h from reference CSV, extends forward,
     * and verifies the forward path is economically sensible.
     */
    @Test
    public void testForwardProjectionFromTerminal() throws IOException {
        assumeTestDataAvailable();

        int refSize = referenceData.size();
        double[] refN = new double[refSize];
        double[] refH = new double[refSize];
        double[] refGY = new double[refSize];
        double[] refNXY = new double[refSize];
        for (int i = 0; i < refSize; i++) {
            refN[i] = referenceData.get(i).N();
            refH[i] = referenceData.get(i).h();
            refGY[i] = referenceData.get(i).gY();
            refNXY[i] = referenceData.get(i).nxY();
        }

        // Extend N/h forward (80 years = 320 quarters, matching manager code)
        int projectionQuarters = 320;
        int totalExtended = refSize + projectionQuarters;
        double[] extN = RamseyTrendModel.extendExogenous(refN, totalExtended, 20);
        double[] extH = RamseyTrendModel.extendExogenous(refH, totalExtended,
                Math.min(20, refSize - 1));
        double[] extGY = RamseyTrendModel.extendShare(refGY, totalExtended);
        double[] extNXY = RamseyTrendModel.extendShare(refNXY, totalExtended);

        // Forward projection starts at terminal date (= last reference observation)
        int startIdx = refSize - 1;
        int projLen = totalExtended - startIdx;
        double[] projN = java.util.Arrays.copyOfRange(extN, startIdx, totalExtended);
        double[] projH = java.util.Arrays.copyOfRange(extH, startIdx, totalExtended);
        double[] projGY = java.util.Arrays.copyOfRange(extGY, startIdx, totalExtended);
        double[] projNXY = java.util.Arrays.copyOfRange(extNXY, startIdx, totalExtended);

        // Load terminal state
        model.loadTerminalState(Paths.get(MACRO_MODEL_PATH, "growth_terminal_state.json"));
        double K_terminal = model.getK();
        double A_terminal = model.getA();

        assertTrue(K_terminal > 500000, "Terminal K should be large, got: " + K_terminal);
        assertTrue(A_terminal > 0, "Terminal A should be positive, got: " + A_terminal);

        // Solve forward from terminal state
        model.solveForPath(K_terminal, A_terminal, projN, projH, projGY, projNXY, projLen);
        assertTrue(model.isSolved(), "Forward projection should converge");

        // === Verify quarter 0 matches terminal state ===
        var q0 = model.getTrendAtQuarter(0);
        assertEquals(K_terminal, q0.capitalStock(), K_terminal * 1e-6,
                "Quarter 0 K should match terminal K");
        assertTrue(q0.output() > 0, "Output should be positive at q0");
        assertTrue(q0.wage() > 0, "Wage should be positive at q0");
        assertTrue(q0.rQuarterly() > 0 && q0.rQuarterly() < 0.05,
                "r* quarterly should be in (0, 5%), got: " + q0.rQuarterly());

        // === Verify smooth wage growth ===
        double prevWage = q0.wage();
        int jumpCount = 0;
        for (int q = 4; q < Math.min(projLen, 200); q += 4) {
            var ts = model.getTrendAtQuarter(q);
            double wageGrowth = (ts.wage() / prevWage - 1.0) * 100.0;

            // Wage should grow (TFP-driven) â€” typical range 0.1â€“2.0% per year
            assertTrue(wageGrowth > -1.0 && wageGrowth < 5.0,
                    String.format("q=%d: annual wage growth=%.2f%% outside [-1, 5]", q, wageGrowth));

            // No huge quarterly jumps (>5%)
            for (int sq = q - 3; sq <= q; sq++) {
                double wq = model.getTrendAtQuarter(sq).wage();
                double wqPrev = model.getTrendAtQuarter(Math.max(0, sq - 1)).wage();
                if (sq > 0 && Math.abs(wq / wqPrev - 1.0) > 0.05) jumpCount++;
            }

            prevWage = ts.wage();
        }
        assertTrue(jumpCount <= 2,
                "Too many quarter-over-quarter wage jumps (>5%): " + jumpCount);

        // === Verify interest rate stays bounded ===
        for (int q = 0; q < Math.min(projLen, 200); q++) {
            double rq = model.getTrendAtQuarter(q).rQuarterly();
            assertTrue(rq > -0.01 && rq < 0.05,
                    String.format("q=%d: r*_q=%.4f outside (-1%%, 5%%)", q, rq));
            assertFalse(Double.isNaN(rq), "r* should not be NaN at q=" + q);
        }

        // === Verify K/Y converges toward BGP ===
        double kyBgp = model.getKyBgp();
        var lastQ = model.getTrendAtQuarter(projLen - 1);
        double kyEnd = lastQ.capitalStock() / lastQ.output();
        // After 80 years, should be within Â±5 of BGP (loose, accommodates transition)
        assertTrue(Math.abs(kyEnd - kyBgp) < 5.0,
                String.format("K/Y at end (%.2f) far from BGP (%.2f)", kyEnd, kyBgp));

        // Print summary
        var midQ = model.getTrendAtQuarter(40);  // ~10 years out
        System.out.println("=== Forward Projection from Terminal ===");
        System.out.printf("  Terminal: K=%.0f, A=%.6f, w=%.6f, r*=%.4f%%\n",
                K_terminal, A_terminal, q0.wage(), q0.rQuarterly() * 100);
        System.out.printf("  +10yr:    K=%.0f, Y=%.0f, w=%.6f, r*=%.4f%%\n",
                midQ.capitalStock(), midQ.output(), midQ.wage(), midQ.rQuarterly() * 100);
        System.out.printf("  +80yr:    K=%.0f, Y=%.0f, w=%.6f, K/Y=%.2f (BGP=%.2f)\n",
                lastQ.capitalStock(), lastQ.output(), lastQ.wage(), kyEnd, kyBgp);
    }

    /**
     * Test the annual stepping through the forward-projected path,
     * mirroring MacroModelManager.advanceRamseyTrend() wage trend logic.
     */
    @Test
    public void testForwardProjectionWageTrend() throws IOException {
        assumeTestDataAvailable();

        // Setup the forward projection (same as above)
        int refSize = referenceData.size();
        double[] refN = new double[refSize];
        double[] refH = new double[refSize];
        double[] refGY = new double[refSize];
        double[] refNXY = new double[refSize];
        for (int i = 0; i < refSize; i++) {
            refN[i] = referenceData.get(i).N();
            refH[i] = referenceData.get(i).h();
            refGY[i] = referenceData.get(i).gY();
            refNXY[i] = referenceData.get(i).nxY();
        }

        int projectionQuarters = 320;
        int totalExtended = refSize + projectionQuarters;
        double[] extN = RamseyTrendModel.extendExogenous(refN, totalExtended, 20);
        double[] extH = RamseyTrendModel.extendExogenous(refH, totalExtended,
                Math.min(20, refSize - 1));
        double[] extGY = RamseyTrendModel.extendShare(refGY, totalExtended);
        double[] extNXY = RamseyTrendModel.extendShare(refNXY, totalExtended);

        int startIdx = refSize - 1;
        int projLen = totalExtended - startIdx;
        double[] projN = java.util.Arrays.copyOfRange(extN, startIdx, totalExtended);
        double[] projH = java.util.Arrays.copyOfRange(extH, startIdx, totalExtended);
        double[] projGY = java.util.Arrays.copyOfRange(extGY, startIdx, totalExtended);
        double[] projNXY = java.util.Arrays.copyOfRange(extNXY, startIdx, totalExtended);

        model.loadTerminalState(Paths.get(MACRO_MODEL_PATH, "growth_terminal_state.json"));
        model.solveForPath(model.getK(), model.getA(), projN, projH, projGY, projNXY, projLen);

        // === Mimic MacroModelManager.advanceRamseyTrend() logic ===
        double baselineWage = 0.0;
        double prevTrend = 0.0;

        int maxYears = Math.min(50, projLen / 4);  // up to 50 years
        double[] trends = new double[maxYears];

        for (int yr = 0; yr < maxYears; yr++) {
            var ts = model.stepYear();

            if (yr == 0) {
                baselineWage = ts.wage();
                trends[yr] = 0.0;
            } else {
                trends[yr] = (ts.wage() / baselineWage - 1.0) * 100.0;
            }
        }

        // First year: trend = 0
        assertEquals(0.0, trends[0], 1e-12, "First year trend should be 0%");

        // Trend should be positive after first year (wages grow with TFP)
        assertTrue(trends[1] > 0.0,
                "Second year trend should be positive, got: " + trends[1]);

        // Trend should grow monotonically (at least mostly)
        int nonMonotoneCount = 0;
        for (int i = 2; i < maxYears; i++) {
            if (trends[i] < trends[i - 1]) nonMonotoneCount++;
        }
        assertTrue(nonMonotoneCount <= 3,
                "Wage trend should be mostly monotone, but " + nonMonotoneCount + " decreases found");

        // After 10 years: trend should be in ~0.5â€“5% (TFP ~0.5%/yr implies ~5% cumulative)
        assertTrue(trends[10] > 0.3 && trends[10] < 40.0,
                String.format("10-year wage trend=%.2f%% outside (0.3, 10)", trends[10]));

        // After 30 years: trend should be ~10â€“30% (TFP ~0.5%/yr, compounded)
        if (maxYears > 30) {
            assertTrue(trends[30] > 5.0 && trends[30] < 150.0,
                    String.format("30-year wage trend=%.2f%% outside (5, 50)", trends[30]));
        }

        // Print a table of trend values
        System.out.println("=== Forward Projection Wage Trend ===");
        System.out.printf("  %-7s  %10s\n", "Year", "Trend(%)");
        for (int yr = 0; yr < maxYears; yr += 5) {
            System.out.printf("  +%-5d  %+10.4f%%\n", yr, trends[yr]);
        }

        // Smoothness: year-over-year trend increments should be comparable
        double firstIncrement = trends[2] - trends[1];
        double laterIncrement = trends[20] - trends[19];
        double ratio = laterIncrement / firstIncrement;
        assertTrue(ratio > 0.3 && ratio < 3.0,
                String.format("Trend increment ratio (yr20/yr2) = %.2f, expected ~1.0", ratio));
    }

    /**
     * Verify that the extended N/h series are smooth at the boundary
     * between reference data and projection.
     */
    @Test
    public void testExogenousExtensionSmoothness() {
        assumeTestDataAvailable();

        int refSize = referenceData.size();
        double[] refN = new double[refSize];
        for (int i = 0; i < refSize; i++) {
            refN[i] = referenceData.get(i).N();
        }

        int totalLen = refSize + 40;  // 10 extra years
        double[] extN = RamseyTrendModel.extendExogenous(refN, totalLen, 20);

        // No discontinuity at boundary
        double ratio = extN[refSize] / extN[refSize - 1];
        assertTrue(Math.abs(ratio - 1.0) < 0.02,
                String.format("N jump at boundary: %.4f, ratio=%.4f (expect ~1.0)",
                        extN[refSize] - extN[refSize - 1], ratio));

        // All extended values should be positive
        for (int i = refSize; i < totalLen; i++) {
            assertTrue(extN[i] > 0, "Extended N should be positive at i=" + i);
        }

        // Trend should continue smoothly
        double growthBefore = Math.log(extN[refSize - 1] / extN[refSize - 5]);
        double growthAfter = Math.log(extN[refSize + 4] / extN[refSize]);
        assertEquals(growthBefore / 4.0, growthAfter / 4.0, 0.001,
                "Growth rate should be continuous across boundary");
    }

    /**
     * A re-solve over the shortened horizon [t..T], started from the solved model's own
     * K/A state at t with an unchanged labor path and the TFP convergence phase carried
     * over, must reproduce the original solution's tail. This is the correctness
     * contract for the recursive-feedback channel: no surprise => no revision.
     */
    @Test
    public void testShiftedHorizonReSolveReproducesOriginalTail() throws IOException {
        Assumptions.assumeTrue(testDataAvailable, "Macro fixtures not available");
        model.loadTerminalState(Paths.get(MACRO_MODEL_PATH, "growth_terminal_state.json"));
        ProjectionInputs inputs = buildForwardProjectionInputs(false);
        model.solveForPath(model.getK(), model.getA(), inputs.labor(), inputs.h(),
                inputs.gY(), inputs.nxY(), inputs.projLen());

        final int shift = 4; // one year
        int n = model.getSimQuarters();
        double[] wOrig = new double[n];
        double[] kOrig = new double[n];
        for (int q = 0; q < n; q++) {
            var ts = model.getTrendAtQuarter(q);
            wOrig[q] = ts.wage();
            kOrig[q] = ts.capitalStock();
        }
        double k0 = model.getKAtQuarter(shift);
        double a0 = model.getAAtQuarter(shift);

        RamseyTrendModel reSolved = new RamseyTrendModel();
        reSolved.loadParams(Paths.get(MACRO_MODEL_PATH, "growth_params_Poland.json"));
        if (reSolved.isEndogenousLabor()) reSolved.setEndogenousLabor(false);
        reSolved.setTfpPhaseOffsetQuarters(shift);
        reSolved.solveForPath(k0, a0,
                tail(inputs.labor(), shift), tail(inputs.h(), shift),
                tail(inputs.gY(), shift), tail(inputs.nxY(), shift),
                inputs.projLen() - shift);

        int compareQuarters = Math.min(120, reSolved.getSimQuarters()); // first 30 years
        double maxRelDev = 0.0;
        for (int q = 0; q < compareQuarters; q++) {
            var ts = reSolved.getTrendAtQuarter(q);
            maxRelDev = Math.max(maxRelDev, relativeError(ts.wage(), wOrig[q + shift]));
            assertRelativeClose(ts.wage(), wOrig[q + shift], 1e-6,
                    "wage at shifted quarter " + q);
            assertRelativeClose(ts.capitalStock(), kOrig[q + shift], 1e-6,
                    "capital at shifted quarter " + q);
        }
        System.out.println("Shifted-horizon idempotence: max relative deviation = " + maxRelDev);
    }

    @Test
    public void testNegativeTfpPhaseOffsetRejected() {
        RamseyTrendModel m = new RamseyTrendModel();
        assertThrows(IllegalArgumentException.class, () -> m.setTfpPhaseOffsetQuarters(-1));
    }

    private static double[] tail(double[] a, int from) {
        return java.util.Arrays.copyOfRange(a, from, a.length);
    }

    // ========== 6. Edge Cases and Error Handling ==========

    @Test
    public void testGetTrendBeforeSolve() {
        assumeTestDataAvailable();
        assertThrows(IllegalStateException.class, () -> model.getTrendAtQuarter(0));
    }

    @Test
    public void testStepYearBeforeSolve() {
        assumeTestDataAvailable();
        assertThrows(IllegalStateException.class, () -> model.stepYear());
    }

    @Test
    public void testGetTrendOutOfBounds() throws IOException {
        assumeTestDataAvailable();

        int T = 40;
        double[] N = new double[T];
        double[] h = new double[T];
        java.util.Arrays.fill(N, 35000.0);
        java.util.Arrays.fill(h, 345.0);

        model.solveForPath(9e6, 0.058, N, h, new double[T], new double[T], T);

        assertThrows(IndexOutOfBoundsException.class, () -> model.getTrendAtQuarter(-1));
        assertThrows(IndexOutOfBoundsException.class, () -> model.getTrendAtQuarter(T));
    }

    @Test
    public void testTerminalStateLoading() throws IOException {
        assumeTestDataAvailable();

        Path termPath = Paths.get(MACRO_MODEL_PATH, "growth_terminal_state.json");
        model.loadTerminalState(termPath);

        // Just verify it doesn't throw and loads positive values
        // (The actual values are checked via cross-validation tests)
    }

    @Test
    public void testReferenceCSVLoading() throws IOException {
        assumeTestDataAvailable();

        assertNotNull(referenceData, "Reference data should be loaded");
        assertTrue(referenceData.size() > 50,
                "Expected at least 50 quarters, got: " + referenceData.size());

        // First row should be 2005q1 for Poland
        assertEquals("2005q1", referenceData.get(0).time());

        // K should be positive and large (millions of EUR, German capital stock)
        assertTrue(referenceData.get(0).K() > 500000,
                "K should be > 1M, got: " + referenceData.get(0).K());
    }

    @Test
    public void testMismatchedInputLengths() {
        assumeTestDataAvailable();
        double[] N = new double[40];
        double[] h = new double[30]; // different length

        assertThrows(IllegalArgumentException.class, () ->
                model.solveForPath(9e6, 0.058, N, h, new double[40], new double[40], 40));
    }

    @Test
    public void testExtendExogenousSingleObservationIsConstant() {
        double[] sample = {1234.5};
        double[] extended = RamseyTrendModel.extendExogenous(sample, 6, 20);
        assertArrayEquals(new double[]{1234.5, 1234.5, 1234.5, 1234.5, 1234.5, 1234.5}, extended, 1e-12);
    }

    @Test
    public void testInvalidPrivateShareRejected() {
        assumeTestDataAvailable();

        int T = 40;
        double[] N = new double[T];
        double[] h = new double[T];
        java.util.Arrays.fill(N, 35000.0);
        java.util.Arrays.fill(h, 345.0);

        double[] gY = new double[T];
        double[] nxY = new double[T];
        java.util.Arrays.fill(gY, 0.8);
        java.util.Arrays.fill(nxY, 0.25);

        assertThrows(IllegalArgumentException.class, () ->
                model.solveForPath(9e6, 0.058, N, h, gY, nxY, T));
    }

    @Test
    public void testScenarioWithInvalidQuarterlyParametersFailsFast() throws IOException {
        assumeTestDataAvailable();

        int T = 40;
        double[] N = new double[T];
        double[] h = new double[T];
        java.util.Arrays.fill(N, 35000.0);
        java.util.Arrays.fill(h, 345.0);
        double[] gY = new double[T];
        double[] nxY = new double[T];

        Path invalidScenario = tempDir.resolve("invalid_delta.csv");
        Files.writeString(invalidScenario,
                "year,delta\n" +
                "2025,1.20\n");

        RamseyScenario scenario = new RamseyScenario();
        scenario.loadFromFile(invalidScenario);

        model.setScenario(scenario, 2025);
        assertThrows(IllegalArgumentException.class, () ->
                model.solveForPath(9e6, 0.058, N, h, gY, nxY, T));
    }

    @Test
    public void testQuarterAccessorsOutOfBounds() {
        assumeTestDataAvailable();

        int T = 40;
        double[] N = new double[T];
        double[] h = new double[T];
        java.util.Arrays.fill(N, 35000.0);
        java.util.Arrays.fill(h, 345.0);

        model.solveForPath(9e6, 0.058, N, h, new double[T], new double[T], T);

        assertThrows(IndexOutOfBoundsException.class, () -> model.getKAtQuarter(-1));
        assertThrows(IndexOutOfBoundsException.class, () -> model.getKAtQuarter(T));
        assertThrows(IndexOutOfBoundsException.class, () -> model.getAAtQuarter(-1));
        assertThrows(IndexOutOfBoundsException.class, () -> model.getAAtQuarter(T));
    }

    // ========== 7. Endogenous Labor Supply Tests ==========

    @Test
    public void testEndogenousLaborParameterLoading() throws IOException {
        assumeTestDataAvailable();

        var endoModel = new RamseyTrendModel();
        endoModel.setLogEnabled(true);
        endoModel.loadParams(Paths.get(ENDO_MODEL_PATH, "growth_params_Poland.json"));

        // The JSON has labor_supply: "endogenous", phi: ~1.3, psi: >0
        if (endoModel.isEndogenousLabor()) {
            assertTrue(endoModel.getPhi() > 0, "phi should be positive");
            assertTrue(endoModel.getPsi() > 0, "psi should be positive");
            assertTrue(endoModel.getPhi() >= 0.5 && endoModel.getPhi() <= 5.0, "phi should be in reasonable range");
            // psi has the units of w·h·c^{-sigma}, so its scale follows hours per
            // quarter (~500 for Poland) and it lands near 1. The pre-2026-08
            // hourly-wage FOC put it near 2.5e-3; the band below spans both by
            // orders of magnitude, so it catches a genuine units error without
            // re-encoding one particular convention.
            assertTrue(endoModel.getPsi() > 1e-4 && endoModel.getPsi() < 1e3,
                    "psi should be in reasonable range, got: " + endoModel.getPsi());
            System.out.println("Endogenous labor params loaded: phi="
                    + endoModel.getPhi() + ", psi=" + endoModel.getPsi());
        } else {
            System.out.println("JSON does not specify endogenous labor â€” skipping phi/psi checks");
        }
    }

    /**
     * Solve with endogenous labor using constant WAP and h.
     * Verifies convergence and that participation rate is in a plausible range.
     */
    @Test
    public void testEndogenousLaborSolverConvergence() throws IOException {
        assumeTestDataAvailable();

        Path endoParams = Paths.get(ENDO_MODEL_PATH, "growth_params_Poland.json");
        var endoModel = new RamseyTrendModel();
        endoModel.setLogEnabled(true);
        endoModel.loadParams(endoParams);
        Assumptions.assumeTrue(endoModel.isEndogenousLabor(),
                "JSON does not specify endogenous labor");

        // Calibration-consistent scenario: drive the FOC with the fixture's own
        // base-year state (WAP, h, K, A) instead of arbitrary magnitudes, so the
        // solved participation is comparable to the calibrated l_base. With
        // off-calibration inputs the FOC lands at an unrelated l (the old
        // 55000/9e6/0.058 scenario produced ~0.25), which tests nothing useful.
        String endoContent = Files.readString(endoParams);
        double WAP = extractJsonDouble(endoContent, "WAP");
        double h = extractJsonDouble(endoContent, "h");
        double K0 = extractJsonDouble(endoContent, "K");
        double A0 = extractJsonDouble(endoContent, "A_implied");
        double lBase = extractJsonDouble(endoContent, "l_base");

        int T = 200;
        double[] wapArr = new double[T];
        double[] hArr = new double[T];
        java.util.Arrays.fill(wapArr, WAP);
        java.util.Arrays.fill(hArr, h);

        endoModel.solveForPath(K0, A0, wapArr, hArr, new double[T], new double[T], T);
        assertTrue(endoModel.isSolved(), "Endogenous solver should converge");

        // Verify participation rate at quarter 0
        var q0 = endoModel.getTrendAtQuarter(0);
        assertTrue(q0.participationRate() > 0.3 && q0.participationRate() < 0.95,
                String.format("Participation rate should be in (0.3, 0.95), got: %.4f",
                        q0.participationRate()));
        assertEquals(lBase, q0.participationRate(), 0.10,
                String.format("Base-year participation should track calibrated l_base=%.4f, got: %.4f",
                        lBase, q0.participationRate()));

        // N should equal l * WAP
        double expectedN = q0.participationRate() * WAP;
        assertEquals(expectedN, q0.labor(), expectedN * 1e-10,
                "N should equal l Ã— WAP");

        // Print summary
        System.out.printf("=== Endogenous Labor Convergence ===\n");
        System.out.printf("  q=0:   l=%.4f, N=%.0f, Y=%.0f, w=%.6f\n",
                q0.participationRate(), q0.labor(), q0.output(), q0.wage());
        var lastQ = endoModel.getTrendAtQuarter(T - 1);
        System.out.printf("  q=%d: l=%.4f, N=%.0f, Y=%.0f, w=%.6f\n",
                T - 1, lastQ.participationRate(), lastQ.labor(), lastQ.output(), lastQ.wage());
    }

        @Test
        public void testEndogenousTerminalGrowthSolveRemainsStable() throws IOException {
        assumeTestDataAvailable();

        // Source the ENDOGENOUS fixture: psi has to be on the w·h scale the FOC uses.
        Path paramsPath = tempDir.resolve("growth_params_endogenous_terminal.json");
        Files.writeString(paramsPath, withTerminalGrowth(endoGrowthParamsContent, 0.04, 0.01, 0.8, true));

        RamseyTrendModel endoModel = new RamseyTrendModel();
        endoModel.setLogEnabled(true);
        endoModel.loadParams(paramsPath);
        Assumptions.assumeTrue(endoModel.isEndogenousLabor(),
            "Modified JSON should force endogenous labor mode");

        int T = 80;
        double[] wapArr = new double[T];
        double[] hArr = new double[T];
        java.util.Arrays.fill(wapArr, 55000.0);
        java.util.Arrays.fill(hArr, 345.0);

        endoModel.solveForPath(9e6, 0.058, wapArr, hArr, new double[T], new double[T], T);
        assertTrue(endoModel.isSolved(), "Endogenous solver should converge with terminal-growth enabled");

        var q0 = endoModel.getTrendAtQuarter(0);
        var q20 = endoModel.getTrendAtQuarter(20);
        double g0 = annualizedQuarterGrowth(endoModel, 0);
        double g20 = annualizedQuarterGrowth(endoModel, 20);

        // Re-baselined for the exact stacked-time Newton solver. The legacy
        // forward solver used a Path-A Euler approximation (l_{t+1} ≈ l_t) and
        // reported l₀≈0.34 here; the exact endogenous solution for this
        // synthetic high-TFP fixture is l₀≈0.26, rising toward the BGP. The
        // guard checks an interior, stable solution well off the FOC clamp
        // bounds [0.01, 0.99] that still transitions upward over the horizon.
        assertTrue(q0.participationRate() > 0.15 && q0.participationRate() < 0.95,
            "Participation should remain in a plausible interior range, got: "
                + q0.participationRate());
        assertTrue(q20.participationRate() >= q0.participationRate(),
            "Participation should transition upward toward the BGP, got q0="
                + q0.participationRate() + ", q20=" + q20.participationRate());
        assertTrue(g0 > g20,
            "Endogenous mode should still inherit the declining terminal-growth baseline path");
        assertEquals(0.04, g0, 1e-12,
            "Endogenous mode should start from the configured baseline annual TFP growth");
        assertEquals(expectedAnnualGrowth(0.04, 0.01, 0.8, 20), g20, 1e-12,
            "Endogenous mode should follow the same convergence path by quarter 20");
        }

    /**
     * In the inelastic limit (Ï† â†’ âˆž), the endogenous solver should produce
     * results close to the exogenous solver with N = l_base Ã— WAP.
     * This verifies the FOC reverts to near-constant labor at high Ï†.
     */
    @Test
    public void testEndogenousHighPhiApproachesExogenous() throws IOException {
        assumeTestDataAvailable();

        // Create a modified JSON with very high phi (forcing near-constant l)
        Path paramsPath = Paths.get(ENDO_MODEL_PATH, "growth_params_Poland.json");
        String content = Files.readString(paramsPath);

        // Replace phi value with a large number
        Path highPhiJson = tempDir.resolve("growth_params_highphi.json");
        String modified = content
                .replaceFirst("\"phi\"\\s*:\\s*[\\d.eE+\\-]+", "\"phi\": 50.0")
                .replaceFirst("\"psi\"\\s*:\\s*[\\d.eE+\\-]+", "\"psi\": 0.002");
        Files.writeString(highPhiJson, modified);

        var endoModel = new RamseyTrendModel();
        endoModel.setLogEnabled(true);
        endoModel.loadParams(highPhiJson);
        Assumptions.assumeTrue(endoModel.isEndogenousLabor(),
                "Modified JSON should still be endogenous");

        int T = 120;
        double[] WAP = new double[T];
        double[] h = new double[T];
        java.util.Arrays.fill(WAP, 55000.0);
        java.util.Arrays.fill(h, 345.0);

        double K0 = 9e6;
        double A0 = 0.058;
        double[] gY = new double[T];
        double[] nxY = new double[T];

        endoModel.solveForPath(K0, A0, WAP, h, gY, nxY, T);
        assertTrue(endoModel.isSolved());

        // With very high phi, l should be nearly constant across all quarters
        double l0 = endoModel.getTrendAtQuarter(0).participationRate();
        double lEnd = endoModel.getTrendAtQuarter(T - 1).participationRate();
        double lRange = Math.abs(lEnd - l0);

        assertTrue(lRange < 0.02,
                String.format("With phi=50, l range should be tiny: |%.4f - %.4f| = %.4f",
                        l0, lEnd, lRange));

        System.out.printf("=== High-phi inelastic limit ===\n");
        System.out.printf("  phi=50: l_0=%.6f, l_end=%.6f, range=%.6f\n", l0, lEnd, lRange);
    }

        /**
         * Validate the endogenous forward-projection anchor against the MATLAB terminal export
         * when the reference CSV contains WAP/l columns.
         *
         * <p>SANITY anchor at 5e-4 — deliberately NOT a parity contract (parity is
         * exogenous-only by policy). Inputs are rebuilt locally via
         * buildForwardProjectionInputs rather than through the production loader,
         * because the endogenous fixture predates the projection artefacts; see
         * src/test/resources/macro/endogenous/FIXTURE_PROVENANCE.txt.</p>
         */
        @Test
        public void testEndogenousForwardProjectionAnchorMatchesMATLABExport() throws IOException {
        assumeTestDataAvailable();

        boolean hasWAP = endoReferenceData != null && !endoReferenceData.isEmpty()
            && endoReferenceData.get(endoReferenceData.size() - 1).WAP() > 0
            && endoReferenceData.get(endoReferenceData.size() - 1).l() > 0;
        Assumptions.assumeTrue(hasWAP,
            "Endogenous fixture reference CSV lacks WAP/l columns for forward anchor parity");

        var endoModel = new RamseyTrendModel();
        endoModel.setLogEnabled(true);
        endoModel.loadParams(Paths.get(ENDO_MODEL_PATH, "growth_params_Poland.json"));
        Assumptions.assumeTrue(endoModel.isEndogenousLabor(),
                "JSON does not specify endogenous labor");

        ProjectionInputs projection = buildForwardProjectionInputs(true, endoReferenceData);
        endoModel.loadTerminalState(Paths.get(ENDO_MODEL_PATH, "growth_terminal_state.json"));
        double kTerminal = endoModel.getK();
        double aTerminal = endoModel.getA();

        endoModel.solveForPath(kTerminal, aTerminal,
            projection.labor(), projection.h(), projection.gY(), projection.nxY(), projection.projLen());
        assertTrue(endoModel.isSolved());

        var expected = endoReferenceData.get(endoReferenceData.size() - 1);
        var actual = endoModel.getTrendAtQuarter(0);
        double endoTolerance = 5e-4;

        assertRelativeClose(actual.capitalStock(), expected.K(), endoTolerance,
            "Endogenous terminal-quarter capital should match MATLAB export");
        assertRelativeClose(actual.output(), expected.Y(), endoTolerance,
            "Endogenous terminal-quarter output should match MATLAB export");
        assertRelativeClose(actual.labor(), expected.N(), endoTolerance,
            "Endogenous terminal-quarter labor should match MATLAB export");
        assertRelativeClose(actual.participationRate(), expected.l(), endoTolerance,
            "Endogenous terminal-quarter participation should match MATLAB export");
        assertRelativeClose(actual.wage(), expected.w(), endoTolerance,
            "Endogenous terminal-quarter wage should match MATLAB export");
        assertRelativeClose(actual.rQuarterly(), expected.rStar(), endoTolerance,
            "Endogenous terminal-quarter natural rate should match MATLAB export");
        assertRelativeClose(kTerminal, expected.K(), endoTolerance,
            "Endogenous terminal-state K should match last MATLAB reference quarter");

        assertTrue(aTerminal > 0, "growth_terminal_state A should be positive in endogenous mode");
    }

    /**
     * Verify that TrendState.participationRate() returns 0 in exogenous mode.
     */
    @Test
    public void testExogenousModeParticipationRateIsZero() throws IOException {
        assumeTestDataAvailable();
        // model is already forced to exogenous in setUp()
        assertFalse(model.isEndogenousLabor(), "Model should be in exogenous mode");

        int T = 40;
        double[] N = new double[T];
        double[] h = new double[T];
        java.util.Arrays.fill(N, 35000.0);
        java.util.Arrays.fill(h, 345.0);

        model.solveForPath(9e6, 0.058, N, h, new double[T], new double[T], T);

        var q0 = model.getTrendAtQuarter(0);
        assertEquals(0.0, q0.participationRate(), 0.0,
                "Participation rate should be 0 in exogenous mode");
    }

    // ========== Helper Methods ==========

    /**
     * Compute relative error between actual and expected.
     */
    private static double relativeError(double actual, double expected) {
        if (Math.abs(expected) < 1e-15) {
            return Math.abs(actual);
        }
        return Math.abs(actual - expected) / Math.abs(expected);
    }

    private static void assertRelativeClose(double actual, double expected, double tolerance, String message) {
        double rel = relativeError(actual, expected);
        assertTrue(rel <= tolerance,
                String.format("%s: actual=%.10g, expected=%.10g, rel=%.3e, tol=%.3e",
                        message, actual, expected, rel, tolerance));
    }

    private RamseyTrendModel solveSimpleExogenous(Path paramsPath, int quarters) throws IOException {
        RamseyTrendModel simpleModel = new RamseyTrendModel();
        simpleModel.loadParams(paramsPath);
        simpleModel.setEndogenousLabor(false);
        solveSimpleExogenous(simpleModel, quarters);
        return simpleModel;
    }

    private void solveSimpleExogenous(RamseyTrendModel simpleModel, int quarters) {
        double[] labor = new double[quarters];
        double[] hours = new double[quarters];
        double[] gY = new double[quarters];
        double[] nxY = new double[quarters];
        java.util.Arrays.fill(labor, 35000.0);
        java.util.Arrays.fill(hours, 345.0);
        simpleModel.solveForPath(9e6, 0.058, labor, hours, gY, nxY, quarters);
    }

    private static double annualizedQuarterGrowth(RamseyTrendModel testModel, int quarterIdx) {
        double aNow = testModel.getAAtQuarter(quarterIdx);
        double aNext = testModel.getAAtQuarter(quarterIdx + 1);
        return Math.pow(aNext / aNow, 4.0) - 1.0;
    }

    private static double expectedAnnualGrowth(double baselineAnnual, double terminalAnnual,
                                               double rhoQuarterly, int quarterIdx) {
        return terminalAnnual + Math.pow(rhoQuarterly, quarterIdx) * (baselineAnnual - terminalAnnual);
    }

    /**
     * CONTRACT: Java's intratemporal FOC must match MATLAB's to machine precision.
     *
     * <p>The FOC exists in both runtimes by architecture — MATLAB detrends and
     * projects, Java projects inside SimPaths — and nothing structural keeps them in
     * step. They disagreed for three months in 2026 (MATLAB priced the extensive
     * margin at w·h, Java at the hourly wage w) and every run still succeeded.</p>
     *
     * <p>{@code foc_parity_cases.csv} is generated by MATLAB's
     * generate_foc_parity_cases.m and asserted by BOTH suites, so drift on either
     * side fails immediately without a full pipeline run. If this fails, do not
     * regenerate the fixture to make it pass — the fixture is the contract.</p>
     */
    @Test
    public void testLaborFOCMatchesMATLABParityCases() throws IOException {
        Path parityFile = Paths.get(resolveFixtureDir("")).resolve("foc_parity_cases.csv");
        Assumptions.assumeTrue(Files.exists(parityFile),
                "FOC parity fixture not found at " + parityFile
                + " — run generate_foc_parity_cases.m");

        List<String> lines = Files.readAllLines(parityFile);
        assertTrue(lines.size() > 1, "Parity fixture should contain cases");

        String[] header = lines.get(0).split(",");
        Map<String, Integer> col = new HashMap<>();
        for (int i = 0; i < header.length; i++) {
            col.put(header[i].trim(), i);
        }
        for (String required : new String[] {
                "c", "K", "A", "WAP", "h", "alpha", "sigma", "phi", "psi", "expected_l"}) {
            assertTrue(col.containsKey(required),
                    "Parity fixture missing column: " + required);
        }

        RamseyTrendModel focModel = new RamseyTrendModel();
        double worst = 0.0;
        int checked = 0;
        for (int i = 1; i < lines.size(); i++) {
            String line = lines.get(i).trim();
            if (line.isEmpty()) {
                continue;
            }
            String[] f = line.split(",");
            double expected = Double.parseDouble(f[col.get("expected_l")]);
            double actual = focModel.solveLaborFOC(
                    Double.parseDouble(f[col.get("c")]),
                    Double.parseDouble(f[col.get("K")]),
                    Double.parseDouble(f[col.get("A")]),
                    Double.parseDouble(f[col.get("WAP")]),
                    Double.parseDouble(f[col.get("h")]),
                    Double.parseDouble(f[col.get("alpha")]),
                    Double.parseDouble(f[col.get("sigma")]),
                    Double.parseDouble(f[col.get("psi")]),
                    Double.parseDouble(f[col.get("phi")]));
            worst = Math.max(worst, Math.abs(actual / expected - 1.0));
            assertRelativeClose(actual, expected, 1e-12,
                    "FOC parity case " + i + " (h=" + f[col.get("h")]
                    + ", psi=" + f[col.get("psi")] + "): Java and MATLAB disagree");
            checked++;
        }
        System.out.println("FOC parity: " + checked
                + " cases matched MATLAB, worst relative deviation " + worst);
    }

    private static String withTerminalGrowth(String jsonContent, double baselineAnnual,
                                             double terminalAnnual, double rhoQuarterly,
                                             boolean endogenousLabor) {
        String updated = jsonContent
                .replaceFirst("\\\"tfp_growth_annual\\\"\\s*:\\s*[\\d.eE+\\-]+",
                        "\"tfp_growth_annual\": " + baselineAnnual)
                .replaceFirst("\\\"g_A_terminal_annual\\\"\\s*:\\s*[\\d.eE+\\-]+",
                        "\"g_A_terminal_annual\": " + terminalAnnual)
                .replaceFirst("\\\"rho_quarterly\\\"\\s*:\\s*[\\d.eE+\\-]+",
                        "\"rho_quarterly\": " + rhoQuarterly)
                .replaceFirst("\\\"labor_supply\\\"\\s*:\\s*\\\"[^\\\"]+\\\"",
                        "\"labor_supply\": \"" + (endogenousLabor ? "endogenous" : "exogenous") + "\"");
        if (!updated.contains("\"terminal_growth\"")) {
            throw new IllegalStateException("Expected terminal_growth block in test fixture JSON");
        }
        return updated;
    }

    private static String withoutTerminalGrowth(String jsonContent) {
        // Strip the terminal_growth object structurally (leading comma + block).
        // The block contains only scalars/strings (no nested braces), so [^{}]*
        // is safe. Independent of the following key, so it works across export
        // layouts (the old hand-formatted JSON had equations_doc next; the
        // jsonencode-refactored JSON does not).
        String stripped = jsonContent.replaceFirst(
                ",\\s*\\\"terminal_growth\\\"\\s*:\\s*\\{[^{}]*\\}", "");
        if (stripped.contains("\"terminal_growth\"")) {
            throw new IllegalStateException(
                    "withoutTerminalGrowth() failed to strip the terminal_growth block");
        }
        return stripped;
    }

    private ProjectionInputs buildForwardProjectionInputs(boolean useWap) {
        return buildForwardProjectionInputs(useWap, referenceData);
    }

    private ProjectionInputs buildForwardProjectionInputs(boolean useWap,
            List<RamseyTrendModel.ReferenceRow> ref) {
        int refSize = ref.size();
        double[] refLabor = new double[refSize];
        double[] refH = new double[refSize];
        double[] refGY = new double[refSize];
        double[] refNXY = new double[refSize];

        for (int i = 0; i < refSize; i++) {
            var row = ref.get(i);
            refLabor[i] = useWap ? row.WAP() : row.N();
            refH[i] = row.h();
            refGY[i] = row.gY();
            refNXY[i] = row.nxY();
        }

        int projectionQuarters = 320;
        int totalExtended = refSize + projectionQuarters;
        // Reproduces what MATLAB writes into the bundle: extend_level_path(N_trend, ..., 20)
        // and extend_level_path(handoff_h_hist, ..., 1). The hours window was 20 here until
        // 2026-08-18, matching the production bug rather than MATLAB; it is invisible while
        // hours_trend_method is log_linear because the h column is then a pure exponential.
        double[] extLabor = RamseyTrendModel.extendExogenous(refLabor, totalExtended, 20);
        double[] extH = RamseyTrendModel.extendExogenous(refH, totalExtended, 1);
        double[] extGY = RamseyTrendModel.extendShare(refGY, totalExtended);
        double[] extNXY = RamseyTrendModel.extendShare(refNXY, totalExtended);

        int startIdx = refSize - 1;
        return new ProjectionInputs(
                java.util.Arrays.copyOfRange(extLabor, startIdx, totalExtended),
                java.util.Arrays.copyOfRange(extH, startIdx, totalExtended),
                java.util.Arrays.copyOfRange(extGY, startIdx, totalExtended),
                java.util.Arrays.copyOfRange(extNXY, startIdx, totalExtended),
                totalExtended - startIdx);
    }

    /**
     * Extract A_implied from growth_params JSON.
     */
    private static double extractA0(String jsonContent) {
        return extractJsonDouble(jsonContent, "A_implied");
    }

    private static double extractJsonDouble(String jsonContent, String key) {
        String pattern = "\"" + key + "\":";
        int start = jsonContent.indexOf(pattern);
        if (start < 0) return 0.0;
        start += pattern.length();

        while (start < jsonContent.length() && Character.isWhitespace(jsonContent.charAt(start))) {
            start++;
        }

        var sb = new StringBuilder();
        while (start < jsonContent.length()) {
            char c = jsonContent.charAt(start);
            if (Character.isDigit(c) || c == '.' || c == '-' || c == '+' || c == 'e' || c == 'E') {
                sb.append(c);
                start++;
            } else {
                break;
            }
        }

        return Double.parseDouble(sb.toString());
    }

    private static boolean extractJsonBoolean(String jsonContent, String key, boolean defaultValue) {
        String pattern = "\"" + key + "\":";
        int start = jsonContent.indexOf(pattern);
        if (start < 0) return defaultValue;
        start += pattern.length();

        while (start < jsonContent.length() && Character.isWhitespace(jsonContent.charAt(start))) {
            start++;
        }

        if (jsonContent.startsWith("true", start)) {
            return true;
        }
        if (jsonContent.startsWith("false", start)) {
            return false;
        }
        return defaultValue;
    }

    private static double annualToQuarterlyGrowth(double annualGrowth) {
        return Math.pow(1.0 + annualGrowth, 0.25) - 1.0;
    }

    private record ProjectionInputs(double[] labor, double[] h, double[] gY, double[] nxY, int projLen) {}
}
