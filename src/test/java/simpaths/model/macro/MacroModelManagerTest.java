package simpaths.model.macro;

import simpaths.model.enums.MacroFeedbackMargins;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class MacroModelManagerTest {

    private static final String MACRO_MODEL_PATH = "input/PL/MacroModel";

        @Test
        void testRecorderOnlyInitializationUsesModelInfoSchema() throws Exception {
                assumeRamseyInputsAvailable();

                MacroModelManager manager = new MacroModelManager();
                Method initializeRecorderOnly = MacroModelManager.class
                                .getDeclaredMethod("initializeRecorderOnly", String.class);
                initializeRecorderOnly.setAccessible(true);
                initializeRecorderOnly.invoke(manager, "PL");

                MacroPathRecorder recorder = getField(manager, "trendOnlyPathRecorder", MacroPathRecorder.class);
                assertNotNull(recorder, "Recorder-only initialization should create a recorder when path recording is enabled");

                String[] stateNames = getField(recorder, "stateNames", String[].class);
                String[] jumpNames = getField(recorder, "jumpNames", String[].class);
                String[] shockNames = getField(recorder, "shockNames", String[].class);

                assertEquals(13, stateNames.length, "Recorder-only schema should use model_info state dimensions");
                assertEquals(9, jumpNames.length, "Recorder-only schema should use model_info jump dimensions");
                assertEquals(8, shockNames.length, "Recorder-only schema should use model_info shock dimensions");
                assertEquals("c", stateNames[0], "Recorder-only schema should use live state ordering from model_info");
                assertEquals("y", jumpNames[0], "Recorder-only schema should use live jump ordering from model_info");
                assertEquals("eps_inv", shockNames[7], "Recorder-only schema should use live shock ordering from model_info");
        }

        @Test
        void testRamseyOnlyInitializationUsesModelInfoSchema() throws Exception {
                assumeRamseyInputsAvailable();

                MacroModelManager manager = new MacroModelManager();
                manager.setUseDsge(false);

                Method initialize = MacroModelManager.class
                                .getDeclaredMethod("initialize", String.class, java.util.Set.class);
                initialize.setAccessible(true);
                initialize.invoke(manager, "PL", Collections.emptySet());

                MacroPathRecorder recorder = getField(manager, "trendOnlyPathRecorder", MacroPathRecorder.class);
                assertNotNull(recorder, "Ramsey-only initialization should create a trend recorder");

                String[] stateNames = getField(recorder, "stateNames", String[].class);
                String[] jumpNames = getField(recorder, "jumpNames", String[].class);
                String[] shockNames = getField(recorder, "shockNames", String[].class);

                assertEquals(13, stateNames.length, "Ramsey-only schema should use model_info state dimensions");
                assertEquals(9, jumpNames.length, "Ramsey-only schema should use model_info jump dimensions");
                assertEquals(8, shockNames.length, "Ramsey-only schema should use model_info shock dimensions");
                assertEquals("d_shock", stateNames[12], "Ramsey-only recorder should expose the current d_shock state column");
                assertEquals("theta", jumpNames[8], "Ramsey-only recorder should expose the current theta jump column");
                assertEquals("eps_h", shockNames[6], "Ramsey-only recorder should expose the current eps_h shock column");
        }

    /**
     * CONTRACT: a scenario shock lands in the year it declares, including the first
     * two simulation years.
     *
     * <p>The DSGE cycle is skipped until the labour-supply baseline is latched
     * post-labour-market, but that only prevents measuring eps_L/eps_h. Scenario
     * shocks are exogenous. Until 2026-08 both skip branches returned before the
     * scenario was consulted, so a scenario declared from startYear silently lost
     * its first eight quarters and began two years late at decayed magnitude.</p>
     */
    @Test
    void testScenarioShocksApplyInBaselinePendingYears() throws Exception {
        assumeRamseyInputsAvailable();

        // Written here rather than reusing a shipped scenario: those declare their
        // shocks in whichever year they were authored for (the 1sd/20q energy file
        // starts in 2030), and this test is specifically about the START year.
        // A mild 0.5-sigma cost-push shock keeps the DSGE inside its stability
        // bounds — the shipped 1.5sd/60-quarter energy shock, once it actually
        // reaches the model in the start year, drives the state past the default
        // +/-10 bound, which is itself a consequence of this fix worth knowing.
        Path scenarioFile = Files.createTempDirectory("macro-scenario-startyear")
                .resolve("_macroScenario_startyear_costpush.csv");
        scenarioFile.toFile().deleteOnExit();
        Files.writeString(scenarioFile, "year,quarter,eps_p\n2023,1,0.5\n2023,2,0.4\n");

        MacroModelManager manager = new MacroModelManager();
        setIntField(manager, "simulationStartYear", 2023);
        manager.setUseDsge(true);

        Method initialize = MacroModelManager.class
                .getDeclaredMethod("initialize", String.class, java.util.Set.class);
        initialize.setAccessible(true);
        initialize.invoke(manager, "PL", Collections.emptySet());

        DSGEModel dsge = getField(manager, "dynamicDsgeModel", DSGEModel.class);
        org.junit.jupiter.api.Assumptions.assumeTrue(dsge != null,
                "DSGE model not initialised from PL fixtures");
        String[] shockNames = getField(dsge, "shockNames", String[].class);
        DSGEShockScenario scenario = new DSGEShockScenario(shockNames, dsge.getNumShocks());
        scenario.loadFromFile(scenarioFile);
        org.junit.jupiter.api.Assumptions.assumeTrue(scenario.hasShocksForYear(2023),
                "Fixture scenario should declare shocks in the start year");
        setField(manager, "shockScenario", scenario);

        Method pass = MacroModelManager.class.getDeclaredMethod(
                "runBaselinePendingPass", int.class, java.util.Set.class, String.class);
        pass.setAccessible(true);
        pass.invoke(manager, 2023, Collections.emptySet(), "test");

        // The cost-push shock moves inflation on impact. Before the fix this was
        // exactly zero, because the scenario was never consulted in this year.
        double inflation = getDoubleField(manager, "inflationDeviation");
        assertTrue(Math.abs(inflation) > 1e-6,
                "Scenario shock declared for the start year must reach the DSGE, "
                + "got inflationDeviation=" + inflation);
    }

    /**
     * CONTRACT: macro artifacts are merged by DATE, not by row position.
     *
     * <p>The population projection and the reference CSV both carry a time column and
     * were both consumed positionally: the splice assumed row 0 of the projection was
     * the handoff quarter. Changing the simulation start year without regenerating
     * every upstream artifact then shifted the entire demographic path while
     * validateRamseyHandoffTime — which only checks a scalar in the terminal JSON —
     * still passed. This is the "silently wrong downstream simulation" footgun.</p>
     */
    @Test
    void testMisalignedPopulationProjectionFailsLoudly() throws Exception {
        assumeRamseyInputsAvailable();

        Path scratch = copyMacroBundle();
        Path proj = scratch.resolve("population_projection_Poland.csv");
        Assumptions.assumeTrue(Files.exists(proj), "population projection fixture missing");

        // Shift every quarter label forward by one year, as if the projection had been
        // regenerated for a later start year while the rest of the bundle was not.
        List<String> lines = Files.readAllLines(proj);
        StringBuilder shifted = new StringBuilder(lines.get(0)).append('\n');
        for (int i = 1; i < lines.size(); i++) {
            String line = lines.get(i);
            if (line.isBlank()) continue;
            String[] parts = line.split(",", 2);
            java.util.regex.Matcher m =
                    java.util.regex.Pattern.compile("(\\d{4})(q[1-4])").matcher(parts[0].trim());
            if (m.matches()) {
                shifted.append(Integer.parseInt(m.group(1)) + 1).append(m.group(2));
            } else {
                shifted.append(parts[0]);
            }
            shifted.append(',').append(parts[1]).append('\n');
        }
        Files.writeString(proj, shifted.toString());

        MacroModelManager manager = new MacroModelManager();
        setIntField(manager, "simulationStartYear", 2023);

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> manager.initializeRamseyTrend(scratch.toString()),
                "A population projection that does not contain the handoff quarter must not load");
        assertTrue(ex.getMessage().contains("not aligned"),
                "Error should name the misalignment, got: " + ex.getMessage());
    }

    /**
     * A projection that legitimately STARTS before the handoff must align on the
     * handoff row rather than shifting the path by the offset. This is the half that
     * "just works" instead of merely failing.
     */
    @Test
    void testProjectionStartingBeforeHandoffAlignsOnDate() throws Exception {
        assumeRamseyInputsAvailable();

        Path scratch = copyMacroBundle();
        Path proj = scratch.resolve("population_projection_Poland.csv");
        Assumptions.assumeTrue(Files.exists(proj), "population projection fixture missing");

        // Prepend four quarters before the handoff. Row 0 is no longer the handoff, so
        // a positional splice would shift the whole demographic path by a year.
        List<String> lines = Files.readAllLines(proj);
        String firstData = lines.get(1);
        String value = firstData.split(",", 2)[1];
        StringBuilder prefixed = new StringBuilder(lines.get(0)).append('\n');
        for (int q = 1; q <= 4; q++) {
            prefixed.append("2022q").append(q).append(',').append(value).append('\n');
        }
        for (int i = 1; i < lines.size(); i++) {
            if (!lines.get(i).isBlank()) {
                prefixed.append(lines.get(i)).append('\n');
            }
        }
        Files.writeString(proj, prefixed.toString());

        MacroModelManager offsetManager = new MacroModelManager();
        setIntField(offsetManager, "simulationStartYear", 2023);
        offsetManager.initializeRamseyTrend(scratch.toString());
        RamseyTrendModel offsetTrend = getField(offsetManager, "ramseyTrend", RamseyTrendModel.class);
        assertNotNull(offsetTrend, "Ramsey trend should initialise with an offset projection");
        assertTrue(offsetTrend.isSolved(),
                "Trend should solve when the projection starts before the handoff");

        // The prefixed quarters all precede the handoff, so aligning by date must
        // ignore them entirely: the trend has to be identical to the unmodified
        // bundle's. A positional splice would instead start the demographic override
        // four quarters early and shift the whole path — it would still "solve", which
        // is why asserting isSolved() alone would not catch this.
        MacroModelManager baseManager = new MacroModelManager();
        setIntField(baseManager, "simulationStartYear", 2023);
        baseManager.initializeRamseyTrend(MACRO_MODEL_PATH);
        RamseyTrendModel baseTrend = getField(baseManager, "ramseyTrend", RamseyTrendModel.class);

        for (int q : new int[] {0, 20, 80}) {
            var expected = baseTrend.getTrendAtQuarter(q);
            var actual = offsetTrend.getTrendAtQuarter(q);
            assertEquals(expected.labor(), actual.labor(), Math.abs(expected.labor()) * 1e-12,
                    "Quarters before the handoff must not shift the demographic path "
                    + "(quarter " + q + ")");
            assertEquals(expected.output(), actual.output(), Math.abs(expected.output()) * 1e-12,
                    "Quarters before the handoff must not shift output (quarter " + q + ")");
        }
    }

    /** Copy the deployed PL macro bundle into a scratch directory. */
    private static Path copyMacroBundle() throws Exception {
        Path scratch = Files.createTempDirectory("macro-align-test");
        scratch.toFile().deleteOnExit();
        java.io.File[] files = new java.io.File(MACRO_MODEL_PATH).listFiles();
        assertNotNull(files, "Deployed macro bundle should be listable");
        for (java.io.File f : files) {
            if (!f.isFile()) continue;
            Path dest = scratch.resolve(f.getName());
            Files.copy(f.toPath(), dest);
            dest.toFile().deleteOnExit();
        }
        return scratch;
    }

    @Test
    void testInitializeRamseyTrendSetsQuarterZeroBaselines() throws Exception {
        assumeRamseyInputsAvailable();

        MacroModelManager manager = new MacroModelManager();
                setIntField(manager, "simulationStartYear", 2023);
        manager.initializeRamseyTrend(MACRO_MODEL_PATH);

        RamseyTrendModel ramseyTrend = getField(manager, "ramseyTrend", RamseyTrendModel.class);
        assertNotNull(ramseyTrend, "Ramsey trend should be initialized when MacroModel fixtures are present");
        assertTrue(ramseyTrend.isSolved(), "Ramsey trend should be solved during manager initialization");

        RamseyTrendModel.TrendState q0 = ramseyTrend.getTrendAtQuarter(0);
        RamseyTrendModel.TrendState baseline =
                getField(manager, "ramseyBaseline", RamseyTrendModel.TrendState.class);
        assertNotNull(baseline, "Manager should latch a Ramsey baseline during initialization");
        assertEquals(q0.wage(), baseline.wage(), 1e-12,
                "Manager should baseline wages from Ramsey quarter 0 during initialization");
        assertEquals(q0.output(), baseline.output(), 1e-9,
                "Manager should baseline output from Ramsey quarter 0 during initialization");
        assertEquals(q0.consumption(), baseline.consumption(), 1e-9,
                "Manager should baseline consumption from Ramsey quarter 0 during initialization");
        assertEquals(q0.investment(), baseline.investment(), 1e-9,
                "Manager should baseline investment from Ramsey quarter 0 during initialization");
        assertEquals(q0.capitalStock(), baseline.capitalStock(), 1e-6,
                "Manager should baseline capital from Ramsey quarter 0 during initialization");
        assertEquals(q0.government(), baseline.government(), 1e-9,
                "Manager should baseline government spending from Ramsey quarter 0 during initialization");
        assertEquals(q0.netExports(), baseline.netExports(), 1e-9,
                "Manager should baseline net exports from Ramsey quarter 0 during initialization");
        assertEquals(q0.labor(), baseline.labor(), 1e-9,
                "Manager should baseline labour from Ramsey quarter 0 during initialization");
        // The whole quarter-0 state is held, so a new trend variable cannot be
        // added to the trend layer while silently keeping a 0.0 baseline.
        assertEquals(q0, baseline,
                "Manager should hold the entire quarter-0 TrendState as its baseline");
        assertEquals(0, ramseyTrend.getCurrentQuarterIdx(),
                "Initialization should not consume any Ramsey quarters before the first simulation year");
    }

    @Test
    void testAdvanceRamseyTrendUsesQuarterZeroBaselineForFirstYearTrend() throws Exception {
        assumeRamseyInputsAvailable();

        MacroModelManager manager = new MacroModelManager();
                setIntField(manager, "simulationStartYear", 2023);
        manager.initializeRamseyTrend(MACRO_MODEL_PATH);

        RamseyTrendModel ramseyTrend = getField(manager, "ramseyTrend", RamseyTrendModel.class);
        RamseyTrendModel.TrendState baseline =
                getField(manager, "ramseyBaseline", RamseyTrendModel.TrendState.class);
        double baselineWage = baseline.wage();
        double baselineOutput = baseline.output();
        double baselineConsumption = baseline.consumption();
        double baselineInvestment = baseline.investment();
        double baselineCapital = baseline.capitalStock();
        double baselineGovernment = baseline.government();
        double baselineNetExports = baseline.netExports();
        double baselineLabor = baseline.labor();

        manager.advanceRamseyTrend();

        RamseyTrendModel.TrendState yearOne = getField(manager, "ramseyCurrentYearState", RamseyTrendModel.TrendState.class);
        double wageTrend = getDoubleField(manager, "capitalDeepeningWageAdjustment");
        @SuppressWarnings("unchecked")
        Map<String, Double> currentTrends = getField(manager, "currentRamseyTrends", Map.class);

        assertNotNull(yearOne, "Manager should store the current Ramsey yearly state after stepping");
        assertEquals(4, ramseyTrend.getCurrentQuarterIdx(),
                "A yearly Ramsey step should advance the internal quarter counter by four");

        assertEquals((yearOne.wage() / baselineWage - 1.0) * 100.0, wageTrend, 1e-12,
                "Wage trend should be computed relative to the quarter-0 baseline");
        assertEquals(wageTrend, currentTrends.get("w"), 1e-12,
                "Trend map should expose the same wage trend used in wage decomposition");
        assertEquals((yearOne.output() / baselineOutput - 1.0) * 100.0, currentTrends.get("y"), 1e-12,
                "Output trend should be computed relative to the quarter-0 baseline");
        assertEquals((yearOne.consumption() / baselineConsumption - 1.0) * 100.0, currentTrends.get("c"), 1e-12,
                "Consumption trend should be computed relative to the quarter-0 baseline");
        assertEquals((yearOne.investment() / baselineInvestment - 1.0) * 100.0, currentTrends.get("inv"), 1e-12,
                "Investment trend should be computed relative to the quarter-0 baseline");
        assertEquals((yearOne.capitalStock() / baselineCapital - 1.0) * 100.0, currentTrends.get("k"), 1e-12,
                "Capital trend should be computed relative to the quarter-0 baseline");
        assertEquals((yearOne.labor() / baselineLabor - 1.0) * 100.0, currentTrends.get("n_ramsey"), 1e-12,
                "Ramsey labour trend should be computed relative to the quarter-0 baseline");

        double expectedGovernmentTrend = baselineGovernment != 0.0
                ? (yearOne.government() / baselineGovernment - 1.0) * 100.0 : 0.0;
        double expectedNetExportsTrend = baselineNetExports != 0.0
                ? (yearOne.netExports() / baselineNetExports - 1.0) * 100.0 : 0.0;
        assertEquals(expectedGovernmentTrend, currentTrends.get("g"), 1e-12,
                "Government trend should use the same baseline-relative rule as the manager");
        assertEquals(expectedNetExportsTrend, currentTrends.get("nx"), 1e-12,
                "Net exports trend should use the same baseline-relative rule as the manager");
        assertEquals(yearOne.participationRate() * 100.0, currentTrends.get("l_ramsey"), 1e-12,
                "Participation should be stored in percentage points for downstream logging/recording");
        assertFalse(Math.abs(wageTrend) < 1e-12,
                "The first stepped year should already produce a non-zero wage trend because the baseline is quarter 0");
    }

    @Test
    void testInitializeRamseyTrendFailsWhenHandoffTimeMismatchesSimulationStartYear(@TempDir Path tempDir) throws Exception {
        assumeRamseyInputsAvailable();

        Path macroDir = tempDir.resolve("MacroModel");
        Files.createDirectories(macroDir);
        Files.copy(Paths.get(MACRO_MODEL_PATH, "growth_params_Poland.json"),
                macroDir.resolve("growth_params_Poland.json"));
        Files.copy(Paths.get(MACRO_MODEL_PATH, "growth_model_reference_poland.csv"),
                macroDir.resolve("growth_model_reference_poland.csv"));

        String terminalJson = Files.readString(Paths.get(MACRO_MODEL_PATH, "growth_terminal_state.json"))
                .replace("\"handoff_time\": \"2023q1\"", "\"handoff_time\": \"2025q1\"");
        Files.writeString(macroDir.resolve("growth_terminal_state.json"), terminalJson);

        MacroModelManager manager = new MacroModelManager();
        setIntField(manager, "simulationStartYear", 2023);

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> manager.initializeRamseyTrend(macroDir.toString()),
                "A mismatched macro handoff_time should fail loudly during initialization");
        assertTrue(ex.getMessage().contains("handoff mismatch"),
                "Mismatch error should clearly mention the handoff mismatch");
    }

    /**
     * The hours projection is a required bundle artefact, with no fallback to extrapolating
     * the reference CSV locally. That fallback is precisely what the file replaces: while both
     * sides derived the hours path independently they used different trailing-growth windows,
     * and nothing detected it. A silent fallback would reopen the gap on any bundle exported
     * before 2026-08-18, so a missing file must fail the run.
     */
    @Test
    void testInitializeRamseyTrendFailsWhenHoursProjectionIsMissing(@TempDir Path tempDir) throws Exception {
        assumeRamseyInputsAvailable();

        Path macroDir = tempDir.resolve("MacroModel");
        Files.createDirectories(macroDir);
        for (String name : new String[] {
                "growth_params_Poland.json",
                "growth_model_reference_poland.csv",
                "growth_terminal_state.json",
                "population_projection_Poland.csv"}) {
            Files.copy(Paths.get(MACRO_MODEL_PATH, name), macroDir.resolve(name));
        }
        // hours_projection_Poland.csv deliberately not copied.

        MacroModelManager manager = new MacroModelManager();
        setIntField(manager, "simulationStartYear", 2023);

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> manager.initializeRamseyTrend(macroDir.toString()),
                "A bundle without the hours projection must fail rather than extrapolate locally");
        assertTrue(ex.getMessage().contains("hours_projection_Poland.csv"),
                "Error should name the missing file, got: " + ex.getMessage());
    }

    /** The same bundle, complete, must initialise: proves the test above isolates the hours file. */
    @Test
    void testInitializeRamseyTrendSucceedsWhenHoursProjectionIsPresent(@TempDir Path tempDir) throws Exception {
        assumeRamseyInputsAvailable();

        Path macroDir = tempDir.resolve("MacroModel");
        Files.createDirectories(macroDir);
        for (String name : new String[] {
                "growth_params_Poland.json",
                "growth_model_reference_poland.csv",
                "growth_terminal_state.json",
                "population_projection_Poland.csv",
                "hours_projection_Poland.csv"}) {
            Files.copy(Paths.get(MACRO_MODEL_PATH, name), macroDir.resolve(name));
        }

        MacroModelManager manager = new MacroModelManager();
        setIntField(manager, "simulationStartYear", 2023);

        assertDoesNotThrow(() -> manager.initializeRamseyTrend(macroDir.toString()));
    }

    @Test
    void testSmoothTerminalDemographicClosureTapersGrowthToZero() throws Exception {
        double[] path = new double[12];
        path[0] = 100.0;
        for (int i = 1; i <= 5; i++) {
            path[i] = path[i - 1] * 0.99;
        }

        // window=20 clamps to lastProjectionIdx=5 internally, reproducing the old
        // hard-coded Math.min(20, lastProjectionIdx) behaviour this test asserts on.
        MacroModelManager.applySmoothTerminalDemographicClosure(path, 5, path.length, 20);

        double firstTailGrowth = Math.log(path[6] / path[5]);
        double secondTailGrowth = Math.log(path[7] / path[6]);

        assertTrue(path[6] < path[5],
                "A negative terminal growth rate should continue declining after the projection horizon");
        assertTrue(path[6] / path[5] > 0.99,
                "The first tail step should already be less negative than indefinite extrapolation");
        assertTrue(Math.abs(secondTailGrowth) < Math.abs(firstTailGrowth),
                "Terminal demographic growth should decay toward zero quarter by quarter");
        assertTrue(path[path.length - 1] > path[5] * Math.pow(0.99, path.length - 6),
                "Smooth closure should not extrapolate the last decline indefinitely");
    }

    /**
     * The DSGE combination is allowed. The eps_L channel responds to the year-over-year change
     * in labour supply while the Ramsey re-solve responds to the cumulative level gap against
     * the projection, so the two overlap only while the cycle decays back to the trend. The
     * config emits a warning instead of failing.
     */
    @Test
    public void testRecursiveFeedbackAllowsDsge() {
        MacroModelManager m = new MacroModelManager();
        m.setEnabled(true);
        m.setUseDsge(true);
        m.setUseRamseyTrend(true);
        m.setRamseyFeedbackMargins(MacroFeedbackMargins.EMPLOYMENT_AND_HOURS);
        assertDoesNotThrow(m::validateRamseyFeedbackConfig);
    }

    /**
     * Tripwire for the cross-repository conventions that no artefact carries. The upstream
     * MATLAB {@code macromodel/ramsey_trend.m} extends the demographic path with window 20 and
     * the hours path with window 1; Java must match, or the two sides build different paths
     * from the same bundle. Java used 20 for hours until 2026-08-18, which was invisible only
     * because the exported {@code h} column is a pure exponential under
     * {@code hours_trend_method: log_linear}.
     *
     * <p>The forward hours projection no longer appears here: it is carried by
     * {@code hours_projection_*.csv} and read rather than recomputed, which is a real contract
     * rather than a tripwire. The terminal tail is still built on both sides for both series,
     * so those two windows stay pinned. Change them only together with ramsey_trend.m.</p>
     */
    @Test
    public void testHandoffExtensionWindowsMatchUpstreamMatlab() {
        assertEquals(20, MacroModelManager.DEMOGRAPHIC_EXTENSION_WINDOW,
                "must match extend_level_path(N_trend(, ..., 20) in ramsey_trend.m");
        assertEquals(20, RamseyTrendModel.TAIL_DEMOGRAPHIC_WINDOW,
                "must match extend_level_path(handoff_labor_proj, ..., 20) in ramsey_trend.m");
        assertEquals(1, RamseyTrendModel.TAIL_HOURS_WINDOW,
                "must match extend_level_path(handoff_h_proj, ..., 1) in ramsey_trend.m");
    }

    /**
     * MATLAB bounds the taper's seed window by the override length:
     * {@code tail_window = min(20, n_avail - 1)} in ramsey_trend.m. Java bounded it
     * by array position only, which coincides while the population projection covers
     * more than 21 quarters past the handoff and silently diverges when it does not
     * (the seed rate would then be measured across the splice, on pre-override
     * extrapolated data). (2026-08-19 boundary audit, C3.)
     */
    @Test
    void taperWindowIsBoundedByTheOverrideLength() {
        assertEquals(20, MacroModelManager.demographicTaperWindow(150),
                "long projection: window 20, matching min(20, n_avail-1)");
        assertEquals(5, MacroModelManager.demographicTaperWindow(6),
                "short projection: window n_avail-1, matching MATLAB");
        assertEquals(0, MacroModelManager.demographicTaperWindow(1),
                "single forward quarter: window 0 -> flat fill, matching MATLAB");
    }

    /** The bound is load-bearing: on a sample with a growth break inside the last 20
     *  quarters, window 5 and window 20 produce different tails. */
    @Test
    void taperSeedRateStaysInsideTheOverride() {
        double[] path = new double[40];
        path[0] = 100.0;
        for (int t = 1; t <= 15; t++) path[t] = path[t - 1] * 1.10;  // pre-override regime
        for (int t = 16; t <= 20; t++) path[t] = path[t - 1] * 1.01; // 5 override growth steps
        double[] wide = path.clone();

        // Override covers 6 quarters after the handoff (indices 15..20 overwritten),
        // so MATLAB's window is min(20, 6-1) = 5 and the seed rate is exactly ln(1.01).
        MacroModelManager.applySmoothTerminalDemographicClosure(
                path, 20, 40, MacroModelManager.demographicTaperWindow(6));

        double rho = Math.pow(0.5, 1.0 / 20.0);
        double expectedFirst = path[20] * Math.exp(rho * Math.log(1.01));
        assertEquals(expectedFirst, path[21], 1e-12,
                "first tapered value must be seeded from the override-only growth rate");

        MacroModelManager.applySmoothTerminalDemographicClosure(wide, 20, 40, 20);
        assertNotEquals(wide[39], path[39],
                "window 20 must differ here, else the bound is vacuous on this sample");
    }

    /**
     * The window is load-bearing whenever the extended series is not a pure exponential, which
     * is what makes the tripwire above worth having rather than a formality.
     */
    @Test
    public void testExtensionWindowChangesTheProjectedPathForANonExponentialSeries() {
        double[] wiggly = new double[40];
        for (int i = 0; i < wiggly.length; i++) {
            wiggly[i] = 100.0 + 5.0 * Math.sin(i / 2.0) - 0.1 * i;
        }
        double[] w1 = RamseyTrendModel.extendExogenous(wiggly, wiggly.length + 40, 1);
        double[] w20 = RamseyTrendModel.extendExogenous(wiggly, wiggly.length + 40, 20);
        assertTrue(Math.abs(w1[wiggly.length + 39] / w20[wiggly.length + 39] - 1.0) > 1e-6,
                "windows 1 and 20 must diverge on a non-exponential sample, else the tripwire is vacuous");
    }

    @Test
    public void testRecursiveFeedbackRejectsBadHoursPersistence() {
        MacroModelManager m = new MacroModelManager();
        m.setEnabled(true);
        m.setUseDsge(false);
        m.setUseRamseyTrend(true);
        m.setRamseyFeedbackMargins(MacroFeedbackMargins.EMPLOYMENT_AND_HOURS);
        m.setRamseyFeedbackHoursPersistence(-0.1);
        assertThrows(IllegalStateException.class, m::validateRamseyFeedbackConfig);
    }

    /**
     * Without the Ramsey layer the feedback is inert, not fatal. The margins default to on, so
     * a deliberate dsge-only run must not be forced to switch them off by hand; the re-solve
     * itself is already guarded by the null ramseyTrend check in applyRamseyFeedbackWithRealized.
     */
    @Test
    public void testRecursiveFeedbackIsInertWithoutRamseyTrend() {
        MacroModelManager m = new MacroModelManager();
        m.setEnabled(true);
        m.setUseDsge(true);
        m.setUseRamseyTrend(false);
        m.setRamseyFeedbackMargins(MacroFeedbackMargins.EMPLOYMENT_AND_HOURS);
        assertDoesNotThrow(m::validateRamseyFeedbackConfig);
        assertDoesNotThrow(() -> m.applyRamseyFeedbackWithRealized(2030, 1000.0, 40.0));
    }

    @Test
    public void testRecursiveFeedbackRejectsBadPersistence() {
        MacroModelManager m = new MacroModelManager();
        m.setEnabled(true);
        m.setUseDsge(false);
        m.setUseRamseyTrend(true);
        m.setRamseyFeedbackMargins(MacroFeedbackMargins.EMPLOYMENT_AND_HOURS);
        m.setRamseyFeedbackPersistence(1.5);
        assertThrows(IllegalStateException.class, m::validateRamseyFeedbackConfig);
    }

    @Test
    public void testRecursiveFeedbackRejectsEndogenousLabor() throws Exception {
        MacroModelManager m = new MacroModelManager();
        m.setEnabled(true);
        m.setUseDsge(false);
        m.setUseRamseyTrend(true);
        m.setRamseyFeedbackMargins(MacroFeedbackMargins.EMPLOYMENT_AND_HOURS);
        RamseyTrendModel endo = org.mockito.Mockito.mock(RamseyTrendModel.class);
        org.mockito.Mockito.when(endo.isEndogenousLabor()).thenReturn(true);
        setField(m, "ramseyTrend", endo);
        IllegalStateException ex = assertThrows(IllegalStateException.class,
                m::validateRamseyFeedbackConfig);
        assertTrue(ex.getMessage().contains("exogenous"));
    }

    @Test
    public void testProjectionArraysRetainedAfterInit() throws Exception {
        // Mirror this class's existing initialization pattern against input/PL/MacroModel,
        // including its file-availability Assumptions guard and start-year setup.
        MacroModelManager m = newInitializedPolandManager();
        double[] projN = getField(m, "ramseyProjN", double[].class);
        assertNotNull(projN);
        RamseyTrendModel trend = getField(m, "ramseyTrend", RamseyTrendModel.class);
        assertEquals(trend.getSimQuarters(), projN.length);
        assertEquals((Integer) getField(m, "ramseyProjLen", Integer.class).intValue(), projN.length);
    }

    /**
     * Drives the manager's real initialization path against the live PL bundle, mirroring
     * {@link #testRamseyOnlyInitializationUsesModelInfoSchema()}. simulationStartYear is
     * pinned to 2023 because validateRamseyHandoffTime requires it to match the deployed
     * reference CSV's handoff quarter (2023q1) exactly.
     */
    private static MacroModelManager newInitializedPolandManager() throws Exception {
        assumeRamseyInputsAvailable();

        MacroModelManager manager = new MacroModelManager();
        setIntField(manager, "simulationStartYear", 2023);
        manager.setUseDsge(false);

        Method initialize = MacroModelManager.class
                        .getDeclaredMethod("initialize", String.class, java.util.Set.class);
        initialize.setAccessible(true);
        initialize.invoke(manager, "PL", Collections.emptySet());

        return manager;
    }

    private static void assumeRamseyInputsAvailable() {
        Path macroDir = Paths.get(MACRO_MODEL_PATH);
        Assumptions.assumeTrue(Files.exists(macroDir.resolve("growth_params_Poland.json"))
                        && Files.exists(macroDir.resolve("growth_terminal_state.json"))
                        && Files.exists(macroDir.resolve("growth_model_reference_poland.csv")),
                "Ramsey MacroModel fixtures are required for MacroModelManager regression tests");
    }

    private static double getDoubleField(Object target, String fieldName) throws Exception {
        return getField(target, fieldName, Double.class);
    }

        private static void setField(Object target, String fieldName, Object value) throws Exception {
                Field field = target.getClass().getDeclaredField(fieldName);
                field.setAccessible(true);
                field.set(target, value);
        }

        private static void setIntField(Object target, String fieldName, int value) throws Exception {
                Field field = target.getClass().getDeclaredField(fieldName);
                field.setAccessible(true);
                field.setInt(target, value);
        }

    @SuppressWarnings("unchecked")
    private static <T> T getField(Object target, String fieldName, Class<T> type) throws Exception {
        Field field = target.getClass().getDeclaredField(fieldName);
        field.setAccessible(true);
        Object value = field.get(target);
        if (type == Double.class) {
            return (T) Double.valueOf(field.getDouble(target));
        }
        return type.cast(value);
    }
}