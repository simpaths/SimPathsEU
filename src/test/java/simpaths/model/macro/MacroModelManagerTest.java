package simpaths.model.macro;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
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
     * CONTRACT: a scenario shock lands in the year it declares, the start year included.
     *
     * <p>The DSGE runs the same annual step in every year, driven through
     * {@code updateEquilibrium} as the schedule drives it, so a scenario declared from
     * startYear moves the wage in startYear, not later and not at a decayed magnitude.</p>
     */
    @Test
    void testScenarioShocksApplyFromTheStartYear() throws Exception {
        assumeRamseyInputsAvailable();

        // Written here rather than reusing a shipped scenario: those declare their
        // shocks in whichever year they were authored for (the 1sd/20q energy file
        // starts in 2030), and this test is specifically about the START year.
        // A mild 0.5-sigma cost-push shock keeps the DSGE inside its stability
        // bounds — the shipped 1.5sd/60-quarter energy shock, applied from the
        // start year, drives the state past the default +/-10 bound.
        Path scenarioFile = Files.createTempDirectory("macro-scenario-startyear")
                .resolve("_macroScenario_startyear_costpush.csv");
        scenarioFile.toFile().deleteOnExit();
        Files.writeString(scenarioFile, "year,quarter,eps_p\n2023,1,0.5\n2023,2,0.4\n");

        MacroModelManager manager = new MacroModelManager();
        setIntField(manager, "simulationStartYear", 2023);
        manager.setEnabled(true);
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

        manager.updateEquilibrium(2023, 2023, "PL", Collections.emptySet(), Collections.emptySet(), false);

        // The cost-push shock moves inflation on impact. Inflation stays exactly zero
        // if the scenario is not consulted in the start year.
        double inflation = getDoubleField(manager, "inflationDeviation");
        assertTrue(Math.abs(inflation) > 1e-6,
                "Scenario shock declared for the start year must reach the DSGE, "
                + "got inflationDeviation=" + inflation);
    }

    /**
     * CONTRACT: macro artifacts are merged by DATE, not by row position.
     *
     * <p>The population projection and the reference CSV both carry a time column. Fails
     * if they are consumed positionally, with the splice assuming row 0 of the projection
     * is the handoff quarter: changing the simulation start year without regenerating
     * every upstream artifact would then shift the entire demographic path while
     * validateRamseyHandoffTime — which only checks a scalar in the terminal JSON —
     * still passes. This is the "silently wrong downstream simulation" footgun.</p>
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
        String value = firstData.split(",", 2)[1];       // the rest of the row: N and P
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
            assertEquals(expected.population(), actual.population(),
                    Math.abs(expected.population()) * 1e-12,
                    "Quarters before the handoff must not shift the population path "
                    + "(quarter " + q + ")");
            assertEquals(expected.output(), actual.output(), Math.abs(expected.output()) * 1e-12,
                    "Quarters before the handoff must not shift output (quarter " + q + ")");
        }
    }

    @Test
    void testProjectionWithoutPopulationColumnIsRefused() throws Exception {
        assumeRamseyInputsAvailable();
        Path scratch = copyMacroBundle();
        Path proj = scratch.resolve("population_projection_Poland.csv");
        List<String> lines = Files.readAllLines(proj);        // time,N,P -> time,N
        StringBuilder sb = new StringBuilder("time,N\n");
        for (int i = 1; i < lines.size(); i++) {
            if (lines.get(i).isBlank()) continue;
            String[] p = lines.get(i).split(",");
            sb.append(p[0]).append(',').append(p[1]).append('\n');
        }
        Files.writeString(proj, sb.toString());
        MacroModelManager manager = new MacroModelManager();
        setIntField(manager, "simulationStartYear", 2023);
        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> manager.initializeRamseyTrend(scratch.toString()));
        assertTrue(ex.getMessage().contains("P column") && ex.getMessage().contains("re-export"),
                ex.getMessage());
    }

    @Test
    void testPopulationBeyondTheProjectionFollowsEmploymentAtTheLastRatio() throws Exception {
        assumeRamseyInputsAvailable();
        MacroModelManager m = new MacroModelManager();
        setIntField(m, "simulationStartYear", 2023);
        m.initializeRamseyTrend(MACRO_MODEL_PATH);
        double[] n = getField(m, "ramseyProjN", double[].class);
        double[] p = getField(m, "ramseyProjP", double[].class);
        int lastRow = 151;                                      // 2023q1..2060q4 in population_projection_Poland.csv
        double ratio = p[lastRow] / n[lastRow];
        assertTrue(p[0] / n[0] < ratio, "the workbook's dependency ratio rises to 2060");
        for (int t = lastRow + 1; t < p.length; t++) {
            assertEquals(ratio, p[t] / n[t], 1e-12 * ratio, "ratio frozen at quarter " + t);
        }
    }

    @Test
    void testFrozenDependencyRatioAfterTheLastProjectionIndex() {
        double[] n = {10, 11, 12, 13, 14, 15};
        double[] p = {20, 24, 30, 0, 0, 0};
        MacroModelManager.applyFrozenDependencyRatio(p, n, 2, 6);
        double ratio = 30.0 / 12.0;
        assertArrayEquals(new double[] {20, 24, 30}, java.util.Arrays.copyOf(p, 3), 0.0);
        for (int t = 3; t < 6; t++) {
            assertEquals(n[t] * ratio, p[t], 1e-12, "quarter " + t);
        }
    }

    @Test
    void testFrozenDependencyRatioLeavesAFullyCoveredHorizonUnchanged() {
        double[] n = {10, 11, 12};
        double[] p = {20, 24, 30};
        MacroModelManager.applyFrozenDependencyRatio(p, n, 2, 3);
        assertArrayEquals(new double[] {20, 24, 30}, p, 0.0);
    }

    // ========== Ramsey scenario: the planner's workers N and population P ==========

    /** A Poland manager initialised on {@code bundle}, optionally with a Ramsey scenario and an input scenario folder. */
    private static MacroModelManager newRamseyManager(String bundle, String ramseyScenario, Path inputScenarioDir)
            throws Exception {
        MacroModelManager m = new MacroModelManager();
        setIntField(m, "simulationStartYear", 2023);
        if (ramseyScenario != null) m.setRamseyScenario(ramseyScenario);
        if (inputScenarioDir != null) m.setInputScenarioDir(inputScenarioDir.toString());
        m.initializeRamseyTrend(bundle);
        return m;
    }

    @Test
    void testZeroPathDeviationsLeaveThePlannerBitIdentical(@TempDir Path tempDir) throws Exception {
        assumeRamseyInputsAvailable();
        Files.writeString(tempDir.resolve("zero.csv"), "year, N, P\n2011, 0, 0\n2060, 0, 0\n");
        MacroModelManager base = newRamseyManager(MACRO_MODEL_PATH, null, null);
        MacroModelManager scen = newRamseyManager(MACRO_MODEL_PATH, "zero.csv", tempDir);

        assertArrayEquals(getField(base, "ramseyProjN", double[].class),
                getField(scen, "ramseyProjN", double[].class), 0.0);
        assertArrayEquals(getField(base, "ramseyProjP", double[].class),
                getField(scen, "ramseyProjP", double[].class), 0.0);
        RamseyTrendModel baseTrend = getField(base, "ramseyTrend", RamseyTrendModel.class);
        RamseyTrendModel scenTrend = getField(scen, "ramseyTrend", RamseyTrendModel.class);
        assertEquals(baseTrend.getSimQuarters(), scenTrend.getSimQuarters());
        for (int q = 0; q < baseTrend.getSimQuarters(); q++) {
            var b = baseTrend.getTrendAtQuarter(q);
            var s = scenTrend.getTrendAtQuarter(q);
            assertEquals(b.wage(), s.wage(), 0.0, "wage, quarter " + q);
            assertEquals(b.output(), s.output(), 0.0, "output, quarter " + q);
            assertEquals(b.consumption(), s.consumption(), 0.0, "consumption, quarter " + q);
            // A record compares double components with Double.compare: every field, bit for bit.
            assertEquals(b, s, "trend state, quarter " + q);
        }
    }

    @Test
    void testPathDeviationsScaleNandPWithGeometricInterpolation(@TempDir Path tempDir) throws Exception {
        assumeRamseyInputsAvailable();
        Files.writeString(tempDir.resolve("step.csv"), "year, N, P\n2029, 0, 0\n2030, 0.10, 0.04\n");
        MacroModelManager base = newRamseyManager(MACRO_MODEL_PATH, null, null);
        MacroModelManager scen = newRamseyManager(MACRO_MODEL_PATH, "step.csv", tempDir);
        double[] baseN = getField(base, "ramseyProjN", double[].class);
        double[] baseP = getField(base, "ramseyProjP", double[].class);
        double[] scenN = getField(scen, "ramseyProjN", double[].class);
        double[] scenP = getField(scen, "ramseyProjP", double[].class);
        int last = scenN.length - 1;

        // Quarter j is calendar year 2023 + j/4: 2029q1 is j = 24.
        for (int j = 0; j < 24; j++) {
            assertEquals(baseN[j], scenN[j], 0.0, "N before the deviation, quarter " + j);
            assertEquals(baseP[j], scenP[j], 0.0, "P before the deviation, quarter " + j);
        }
        assertEquals(1.0, scenN[24] / baseN[24], 1e-15);                          // 2029q1
        assertEquals(Math.pow(1.10, 0.25), scenN[25] / baseN[25], 1e-14);          // 2029q2
        assertEquals(Math.pow(1.10, 0.50), scenN[26] / baseN[26], 1e-14);          // 2029q3
        assertEquals(Math.pow(1.04, 0.75), scenP[27] / baseP[27], 1e-14);          // 2029q4
        assertEquals(1.10, scenN[28] / baseN[28], 1e-14);                          // 2030q1
        assertEquals(1.04, scenP[28] / baseP[28], 1e-14);
        assertEquals(1.10, scenN[last] / baseN[last], 1e-14);                      // beyond the file: persists
        assertEquals(1.04, scenP[last] / baseP[last], 1e-14);

        // The initial solve runs on the scaled paths, not only the stored copies.
        RamseyTrendModel trend = getField(scen, "ramseyTrend", RamseyTrendModel.class);
        assertEquals(scenN[28], trend.getTrendAtQuarter(28).labor(), 0.0);
        assertEquals(scenP[28], trend.getTrendAtQuarter(28).population(), 0.0);
    }

    @Test
    void testConstantFactorsKeepTheFrozenDependencyRatioFrozen(@TempDir Path tempDir) throws Exception {
        assumeRamseyInputsAvailable();
        Files.writeString(tempDir.resolve("step.csv"), "year, N, P\n2029, 0, 0\n2030, 0.10, 0.04\n");
        MacroModelManager base = newRamseyManager(MACRO_MODEL_PATH, null, null);
        MacroModelManager scen = newRamseyManager(MACRO_MODEL_PATH, "step.csv", tempDir);
        double[] baseN = getField(base, "ramseyProjN", double[].class);
        double[] baseP = getField(base, "ramseyProjP", double[].class);
        double[] scenN = getField(scen, "ramseyProjN", double[].class);
        double[] scenP = getField(scen, "ramseyProjP", double[].class);

        // Index 0 is the projection's first row (the handoff quarter), so its last row is rows - 1.
        List<String> rows = Files.readAllLines(Paths.get(MACRO_MODEL_PATH, "population_projection_Poland.csv"))
                .stream().skip(1).filter(line -> !line.isBlank()).toList();
        assertTrue(rows.get(0).startsWith("2023q1"), "the projection starts at the handoff quarter");
        int lastProjected = rows.size() - 1;
        assertTrue(lastProjected + 2 < scenN.length, "the horizon must extend beyond the projection");

        for (int j = lastProjected + 1; j < scenN.length; j++) {
            assertEquals(1.04 / 1.10, (scenP[j] / scenN[j]) / (baseP[j] / baseN[j]), 1e-14,
                    "dependency ratio, quarter " + j);
            if (j + 1 < scenN.length) {
                assertEquals(baseN[j + 1] / baseN[j], scenN[j + 1] / scenN[j], 1e-14,
                        "growth of N, quarter " + j);
            }
        }
    }

    @Test
    void testRamseyScenarioIsFoundInTheInputScenarioFolderFirst(@TempDir Path tempDir) throws Exception {
        assumeRamseyInputsAvailable();
        Path bundle = Files.createDirectory(tempDir.resolve("bundle"));
        try (var files = Files.list(Paths.get(MACRO_MODEL_PATH))) {
            for (Path f : (Iterable<Path>) files::iterator) {
                if (Files.isRegularFile(f)) Files.copy(f, bundle.resolve(f.getFileName()));
            }
        }
        Files.writeString(bundle.resolve("x.csv"), "year, N\n2030, 0.0\n");
        Path scenarioDir = Files.createDirectory(tempDir.resolve("scenario"));
        Files.writeString(scenarioDir.resolve("x.csv"), "year, N\n2030, 0.05\n");

        double[] baseN = getField(newRamseyManager(bundle.toString(), null, null), "ramseyProjN", double[].class);
        double[] scenN = getField(newRamseyManager(bundle.toString(), "x.csv", scenarioDir), "ramseyProjN", double[].class);
        assertEquals(1.05, scenN[28] / baseN[28], 1e-14);

        // Without an input scenario folder the bundle's file applies.
        double[] bundleN = getField(newRamseyManager(bundle.toString(), "x.csv", null), "ramseyProjN", double[].class);
        assertArrayEquals(baseN, bundleN, 0.0);
    }

    @Test
    void testRamseyScenarioFoundInNeitherFolderNamesBoth(@TempDir Path tempDir) throws Exception {
        assumeRamseyInputsAvailable();
        Path scenarioDir = Files.createDirectory(tempDir.resolve("scenario"));
        var e = assertThrows(java.io.FileNotFoundException.class,
                () -> newRamseyManager(MACRO_MODEL_PATH, "absent.csv", scenarioDir));
        assertTrue(e.getMessage().contains(scenarioDir.toString())
                && e.getMessage().contains(Paths.get(MACRO_MODEL_PATH).toString()), e.getMessage());
    }

    @Test
    void testNonZeroPathDeviationInTheStartYearIsRefused(@TempDir Path tempDir) throws Exception {
        assumeRamseyInputsAvailable();
        // The floor rule carries the 2020 row into the start year 2023.
        Files.writeString(tempDir.resolve("early.csv"), "year, N\n2020, 0.01\n");
        MacroModelManager m = new MacroModelManager();
        setIntField(m, "simulationStartYear", 2023);
        m.setRamseyScenario("early.csv");
        m.setInputScenarioDir(tempDir.toString());
        var e = assertThrows(IllegalStateException.class, () -> m.initializeRamseyTrend(MACRO_MODEL_PATH));
        assertTrue(e.getMessage().contains("start year"), e.getMessage());

        Files.writeString(tempDir.resolve("early_p.csv"), "year, P\n2023, -0.02\n2030, 0.01\n");
        MacroModelManager mp = new MacroModelManager();
        setIntField(mp, "simulationStartYear", 2023);
        mp.setRamseyScenario("early_p.csv");
        mp.setInputScenarioDir(tempDir.toString());
        var ep = assertThrows(IllegalStateException.class, () -> mp.initializeRamseyTrend(MACRO_MODEL_PATH));
        assertTrue(ep.getMessage().contains("start year"), ep.getMessage());
    }

    /**
     * The latch year 2024 takes in 2025's factor through the within-year interpolation, so a
     * deviation in 2025 is refused; 2026 is the first year a deviation may be non-zero.
     */
    @Test
    void testFirstAllowedPathDeviationYearIsThreeYearsAfterTheStart(@TempDir Path tempDir) throws Exception {
        assumeRamseyInputsAvailable();
        Path refused = tempDir.resolve("from2025.csv");
        Files.writeString(refused, "year, N, P\n2025, 0, 0.03\n2030, 0.05, 0.03\n");
        MacroModelManager m = new MacroModelManager();
        setIntField(m, "simulationStartYear", 2023);
        m.setRamseyScenario("from2025.csv");
        m.setInputScenarioDir(tempDir.toString());
        var e = assertThrows(IllegalStateException.class, () -> m.initializeRamseyTrend(MACRO_MODEL_PATH));
        String msg = e.getMessage();
        assertTrue(msg.contains("start year"), msg);
        assertTrue(msg.contains(refused.toString()), "names the resolved file: " + msg);
        assertTrue(msg.contains("column P is 0.03 in 2025"), "names column, value and year: " + msg);
        assertTrue(msg.contains("first year a deviation may be non-zero is 2026"), msg);

        Files.writeString(tempDir.resolve("from2026.csv"), "year, N, P\n2026, 0.05, 0.03\n");
        MacroModelManager base = newRamseyManager(MACRO_MODEL_PATH, null, null);
        MacroModelManager ok = newRamseyManager(MACRO_MODEL_PATH, "from2026.csv", tempDir);
        double[] baseN = getField(base, "ramseyProjN", double[].class);
        double[] okN = getField(ok, "ramseyProjN", double[].class);
        for (int j = 0; j <= 8; j++) {                  // 2023q1 .. 2025q1, latch year 2024 included
            assertEquals(baseN[j], okN[j], 0.0, "quarter " + j);
        }
        assertEquals(1.05, okN[12] / baseN[12], 1e-14); // 2026q1
    }

    /**
     * With a later reference year the zero rule moves with it: a deviation is refused through
     * the year after the reference year, whose factor enters the reference year's quarters.
     */
    @Test
    void testFirstAllowedPathDeviationYearFollowsTheReferenceYear(@TempDir Path tempDir) throws Exception {
        assumeRamseyInputsAvailable();
        Path refused = tempDir.resolve("from2029.csv");
        Files.writeString(refused, "year, N, P\n2029, 0.05, 0.03\n");
        MacroModelManager m = new MacroModelManager();
        setIntField(m, "simulationStartYear", 2023);
        m.setRamseyFeedbackReferenceYear(2028);
        m.setRamseyScenario("from2029.csv");
        m.setInputScenarioDir(tempDir.toString());
        var e = assertThrows(IllegalStateException.class, () -> m.initializeRamseyTrend(MACRO_MODEL_PATH));
        String msg = e.getMessage();
        assertTrue(msg.contains("column N is 0.05 in 2029"), "names column, value and year: " + msg);
        assertTrue(msg.contains("through 2029"), msg);
        assertTrue(msg.contains("first year a deviation may be non-zero is 2030"), msg);
        assertTrue(msg.contains("reference year 2028"), msg);

        Files.writeString(tempDir.resolve("from2030.csv"), "year, N, P\n2030, 0.05, 0.03\n");
        MacroModelManager ok = new MacroModelManager();
        setIntField(ok, "simulationStartYear", 2023);
        ok.setRamseyFeedbackReferenceYear(2028);
        ok.setRamseyScenario("from2030.csv");
        ok.setInputScenarioDir(tempDir.toString());
        assertDoesNotThrow(() -> ok.initializeRamseyTrend(MACRO_MODEL_PATH));
    }

    /** The reference year is 0 (the year after the start year) or a year after the start year, before the end year. */
    @Test
    void testFeedbackReferenceYearMustLieInsideTheRun() throws Exception {
        MacroModelManager m = new MacroModelManager();
        m.setEnabled(true);
        m.setUseDsge(false);
        m.setUseRamseyTrend(true);
        setIntField(m, "simulationStartYear", 2023);

        m.setRamseyFeedbackReferenceYear(2023);
        var e = assertThrows(IllegalStateException.class, m::validateRamseyFeedbackConfig);
        assertTrue(e.getMessage().contains("mm_ramseyFeedbackReferenceYear"), e.getMessage());
        assertTrue(e.getMessage().contains("2023"), e.getMessage());

        m.setRamseyFeedbackReferenceYear(2024);
        assertDoesNotThrow(m::validateRamseyFeedbackConfig);
        m.setRamseyFeedbackReferenceYear(0);
        assertDoesNotThrow(m::validateRamseyFeedbackConfig);

        // With the end year known, the reference year must leave at least one year to measure a gap in.
        assertDoesNotThrow(() -> MacroModelManager.requireFeedbackReferenceYearInsideRun(0, 2023, 2060));
        assertDoesNotThrow(() -> MacroModelManager.requireFeedbackReferenceYearInsideRun(2059, 2023, 2060));
        var late = assertThrows(IllegalStateException.class,
                () -> MacroModelManager.requireFeedbackReferenceYearInsideRun(2060, 2023, 2060));
        assertTrue(late.getMessage().contains("2060"), late.getMessage());
    }

    /** Without the Ramsey layer the reference year is never read, so no value of it is fatal. */
    @Test
    void testFeedbackReferenceYearIsInertWithoutRamseyTrend() throws Exception {
        MacroModelManager m = new MacroModelManager();
        m.setEnabled(true);
        m.setUseDsge(true);
        m.setUseRamseyTrend(false);
        setIntField(m, "simulationStartYear", 2023);
        m.setRamseyFeedbackReferenceYear(2000);
        assertDoesNotThrow(m::validateRamseyFeedbackConfig);
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
        assertEquals(yearOne.output(), currentTrends.get("y_ramsey_level"), 0.0);
        assertEquals(yearOne.consumption(), currentTrends.get("c_ramsey_level"), 0.0);
        assertEquals(yearOne.investment(), currentTrends.get("inv_ramsey_level"), 0.0);
        assertEquals(yearOne.capitalStock(), currentTrends.get("k_ramsey_level"), 0.0);
        assertEquals(yearOne.labor(), currentTrends.get("n_ramsey_level"), 0.0);
        assertEquals(yearOne.population(), currentTrends.get("p_ramsey_level"), 0.0);

        double expectedGovernmentTrend = baselineGovernment != 0.0
                ? (yearOne.government() / baselineGovernment - 1.0) * 100.0 : 0.0;
        double expectedNetExportsTrend = baselineNetExports != 0.0
                ? (yearOne.netExports() / baselineNetExports - 1.0) * 100.0 : 0.0;
        assertEquals(expectedGovernmentTrend, currentTrends.get("g"), 1e-12,
                "Government trend should use the same baseline-relative rule as the manager");
        assertEquals(expectedNetExportsTrend, currentTrends.get("nx"), 1e-12,
                "Net exports trend should use the same baseline-relative rule as the manager");
        assertEquals(java.util.Set.of("w", "y", "c", "inv", "k", "g", "nx", "n_ramsey", "p_ramsey",
                "y_ramsey_level", "c_ramsey_level", "inv_ramsey_level", "k_ramsey_level",
                "n_ramsey_level", "p_ramsey_level"), currentTrends.keySet(),
                "The trend map carries exactly these keys, with no participation entry: the planner "
                + "takes labour input as exogenous");
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
     * the reference CSV locally: a local extrapolation would be a second derivation of the
     * hours path, with its own trailing-growth window, and nothing would detect a divergence
     * between the two. A missing file must therefore fail the run.
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

    /**
     * Contract #36: a bundle the MATLAB exporter refused carries BUNDLE_NOT_VERIFIED.txt and
     * sits in the folder SimPaths reads. Every other file in it may look valid, so the marker
     * is the only signal, and the loader must stop on it.
     */
    @Test
    void testBundleWithNotVerifiedMarkerIsRefused(@TempDir Path tempDir) throws Exception {
        Path macroDir = tempDir.resolve("MacroModel");
        Files.createDirectories(macroDir);
        Files.writeString(macroDir.resolve("policy_A.csv"), "x\n");
        Files.writeString(macroDir.resolve("BUNDLE_NOT_VERIFIED.txt"),
                "THIS BUNDLE IS NOT VERIFIED - DO NOT COMMIT IT, SimPaths MUST NOT RUN ON IT\n");

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> MacroModelManager.requireVerifiedBundle(macroDir),
                "A bundle carrying the exporter's refusal marker must not load");
        assertTrue(ex.getMessage().contains("BUNDLE_NOT_VERIFIED.txt"),
                "Error should name the marker file, got: " + ex.getMessage());
        assertTrue(ex.getMessage().contains(macroDir.toString()),
                "Error should name the bundle folder, got: " + ex.getMessage());
        assertTrue(ex.getMessage().contains("regenerated"),
                "Error should say the bundle must be regenerated, got: " + ex.getMessage());

        Files.delete(macroDir.resolve("BUNDLE_NOT_VERIFIED.txt"));
        assertDoesNotThrow(() -> MacroModelManager.requireVerifiedBundle(macroDir),
                "Without the marker the same folder must pass the check");
    }

    // ---- mm_macroBundleDir: the bundle folder is configurable per run ----

    @Test
    void testBlankBundleDirFallsBackToCountryFolder() {
        MacroModelManager manager = new MacroModelManager();
        for (String blank : new String[] {null, "", "   "}) {
            manager.setMacroBundleDir(blank);
            assertEquals(Paths.get("input", "PL", "MacroModel").toString(), manager.resolveBundleDir("PL"),
                    "a blank bundle folder must mean the country default, got blank='" + blank + "'");
        }
    }

    @Test
    void testConfiguredBundleDirReplacesCountryFolder(@TempDir Path tempDir) throws Exception {
        assumeRamseyInputsAvailable();
        Path bundle = tempDir.resolve("MacroModel_backtest");
        Files.createDirectories(bundle);
        try (var files = Files.list(Paths.get(MACRO_MODEL_PATH))) {
            for (Path f : (Iterable<Path>) files.filter(Files::isRegularFile)::iterator) {
                Files.copy(f, bundle.resolve(f.getFileName()));
            }
        }

        MacroModelManager manager = new MacroModelManager();
        manager.setUseDsge(false);
        manager.setMacroBundleDir(bundle.toString());
        // input/XX/MacroModel does not exist: only the configured folder can satisfy this.
        invokeInitialize(manager, "XX");

        assertNotNull(getField(manager, "ramseyTrend", RamseyTrendModel.class),
                "The Ramsey trend should load from the configured folder");
        MacroPathRecorder recorder = getField(manager, "trendOnlyPathRecorder", MacroPathRecorder.class);
        assertEquals(13, getField(recorder, "stateNames", String[].class).length,
                "The recorder schema should come from the configured folder's model_info.json");
    }

    @Test
    void testConfiguredBundleDirThatDoesNotExistFailsNamingIt(@TempDir Path tempDir) {
        Path missing = tempDir.resolve("no_such_bundle");
        MacroModelManager manager = new MacroModelManager();
        manager.setUseDsge(false);
        manager.setMacroBundleDir(missing.toString());

        RuntimeException ex = initializeFailure(manager, "PL");
        assertTrue(ex.getMessage().contains(missing.toString()),
                "A missing configured folder must fail naming it, not fall back to the country default; got: "
                        + ex.getMessage());
    }

    /** The marker check's call site in initialize; until now only the static method had a test. */
    @Test
    void testInitializeRefusesBundleCarryingNotVerifiedMarker(@TempDir Path tempDir) throws Exception {
        Path bundle = tempDir.resolve("MacroModel");
        Files.createDirectories(bundle);
        Files.writeString(bundle.resolve(MacroModelManager.BUNDLE_NOT_VERIFIED_MARKER), "refused\n");
        MacroModelManager manager = new MacroModelManager();
        manager.setUseDsge(false);
        manager.setMacroBundleDir(bundle.toString());

        RuntimeException ex = initializeFailure(manager, "PL");
        assertTrue(ex instanceof IllegalStateException, ex.toString());
        // Without the call, initialize fails on the missing growth_params instead: the marker name tells them apart.
        assertTrue(ex.getMessage().contains(MacroModelManager.BUNDLE_NOT_VERIFIED_MARKER),
                "initialize must refuse a marked bundle, got: " + ex.getMessage());
    }

    /** Decision: recorder-only reads only model_info.json's variable names, so a refused bundle does not stop it. */
    @Test
    void testRecorderOnlyRunsOnBundleCarryingNotVerifiedMarker(@TempDir Path tempDir) throws Exception {
        assumeRamseyInputsAvailable();
        Path bundle = tempDir.resolve("MacroModel");
        Files.createDirectories(bundle);
        Files.copy(Paths.get(MACRO_MODEL_PATH, "model_info.json"), bundle.resolve("model_info.json"));
        Files.writeString(bundle.resolve(MacroModelManager.BUNDLE_NOT_VERIFIED_MARKER), "refused\n");
        MacroModelManager manager = new MacroModelManager();
        manager.setMacroBundleDir(bundle.toString());

        Method initializeRecorderOnly = MacroModelManager.class
                .getDeclaredMethod("initializeRecorderOnly", String.class);
        initializeRecorderOnly.setAccessible(true);
        assertDoesNotThrow(() -> initializeRecorderOnly.invoke(manager, "PL"));

        MacroPathRecorder recorder = getField(manager, "trendOnlyPathRecorder", MacroPathRecorder.class);
        assertEquals(13, getField(recorder, "stateNames", String[].class).length,
                "Recorder-only should still label its columns from the configured folder");
    }

    private static void invokeInitialize(MacroModelManager manager, String countryCode) throws Exception {
        Method initialize = MacroModelManager.class
                .getDeclaredMethod("initialize", String.class, java.util.Set.class);
        initialize.setAccessible(true);
        initialize.invoke(manager, countryCode, Collections.emptySet());
    }

    /** What initialize itself throws, unwrapped from the reflective call. */
    private static RuntimeException initializeFailure(MacroModelManager manager, String countryCode) {
        InvocationTargetException ite = assertThrows(InvocationTargetException.class,
                () -> invokeInitialize(manager, countryCode));
        return (RuntimeException) ite.getCause();
    }

    @Test
    void testSmoothTerminalDemographicClosureTapersGrowthToZero() throws Exception {
        double[] path = new double[12];
        path[0] = 100.0;
        for (int i = 1; i <= 5; i++) {
            path[i] = path[i - 1] * 0.99;
        }

        // window=20 clamps to lastProjectionIdx=5 internally, so the seed window is
        // Math.min(20, lastProjectionIdx), the case this test asserts on.
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
     * Tripwire for the MATLAB/Java conventions that no artefact carries.
     * {@code input_processing/macromodel/ramsey_trend.m} extends the demographic path with
     * window 20 and the hours tail with window 1; Java must match, or the two sides build
     * different paths from the same bundle. A wrong hours window stays invisible while the
     * exported {@code h} column is a pure exponential under
     * {@code hours_trend_method: log_linear}, so only this test catches it.
     *
     * <p>The forward hours projection is not pinned here: it is carried by
     * {@code hours_projection_*.csv} and read rather than recomputed, which is a real contract
     * rather than a tripwire. The terminal tail is built on both sides for both series, so
     * those two windows stay pinned. Change them only together with ramsey_trend.m.</p>
     */
    @Test
    public void testHandoffExtensionWindowsMatchUpstreamMatlab() {
        assertEquals(20, MacroModelManager.DEMOGRAPHIC_EXTENSION_WINDOW,
                "must match extend_level_path(N_trend(1:handoff_idx), ..., 20) in ramsey_trend.m");
        assertEquals(20, RamseyTrendModel.TAIL_DEMOGRAPHIC_WINDOW,
                "must match extend_level_path(handoff_labor_proj, ..., 20) in ramsey_trend.m");
        assertEquals(1, RamseyTrendModel.TAIL_HOURS_WINDOW,
                "must match apply_smooth_terminal_demographic_closure(handoff_h_ext, ..., 1) in ramsey_trend.m");
    }

    /**
     * MATLAB bounds the taper's seed window by the override length:
     * {@code tail_window = min(20, n_avail - 1)} in ramsey_trend.m, and Java must too. A
     * bound by array position alone coincides while the population projection covers
     * more than 21 quarters past the handoff and silently diverges when it does not
     * (the seed rate would then be measured across the splice, on pre-override
     * extrapolated data).
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

    /**
     * Without the Ramsey layer the feedback is inert, not fatal, whatever the persistence: a
     * dsge-only run never reads it, and the re-solve itself is guarded by the null ramseyTrend
     * check in applyRamseyFeedbackWithRealized.
     */
    @Test
    public void testRecursiveFeedbackIsInertWithoutRamseyTrend() {
        MacroModelManager m = new MacroModelManager();
        m.setEnabled(true);
        m.setUseDsge(true);
        m.setUseRamseyTrend(false);
        m.setRamseyFeedbackPersistence(1.5);
        assertDoesNotThrow(m::validateRamseyFeedbackConfig);
        assertDoesNotThrow(() -> m.applyRamseyFeedbackWithRealized(2030, 1000.0, 40.0));
    }

    @Test
    public void testRecursiveFeedbackRejectsBadPersistence() {
        MacroModelManager m = new MacroModelManager();
        m.setEnabled(true);
        m.setUseDsge(false);
        m.setUseRamseyTrend(true);
        m.setRamseyFeedbackPersistence(1.5);
        assertThrows(IllegalStateException.class, m::validateRamseyFeedbackConfig);
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
        double[] projP = getField(m, "ramseyProjP", double[].class);
        assertNotNull(projP);
        assertEquals(projN.length, projP.length);
        for (double v : projP) assertTrue(v > 0.0, "population path must be positive");
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