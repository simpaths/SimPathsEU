package simpaths.model.macro;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Collections;
import java.util.Set;
import java.util.function.UnaryOperator;

import simpaths.model.Person;
import simpaths.model.enums.Les_c4;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Integration tests using actual DSGE export files.
 * 
 * These tests use the real model files in input/PL/MacroModel/
 * and verify the model produces economically sensible results.
 * 
 * Tests are skipped if the input files don't exist.
 */
class DSGEIntegrationTest {
    
    private static final String PL_MODEL_PATH = "input/PL/MacroModel";
    
    static boolean modelFilesExist() {
        File dir = new File(PL_MODEL_PATH);
        return dir.exists()
                && new File(dir, "policy_A.csv").exists()
                && new File(dir, "policy_Bs.csv").exists()
                && new File(dir, "policy_C.csv").exists()
                && new File(dir, "policy_D.csv").exists()
                && new File(dir, "model_info.json").exists();
    }
    
    @Test
    @EnabledIf("modelFilesExist")
    void testLoadActualPolishDynamicModel() throws IOException {
        DSGEModel model = new DSGEModel();
        model.loadFromDirectory(PL_MODEL_PATH);
        
        assertTrue(model.isLoaded(), "Model should load successfully");
        assertTrue(model.getNumStates() > 0, "State dimension must be positive");
        assertTrue(model.getNumShocks() > 0, "Shock dimension must be positive");
    }
    
    @Test
    @EnabledIf("modelFilesExist")
    void testDynamicModelWageResponseToLaborShock() throws IOException {
        DSGEModel model = new DSGEModel();
        model.loadFromDirectory(PL_MODEL_PATH);
        DSGEState response = model.stepAnnual(0.01);

        assertFalse(Double.isNaN(response.getWageDeviation()), "Wage response must be numeric");
        assertFalse(Double.isNaN(response.getInflationDeviation()), "Inflation response must be numeric");
        assertFalse(Double.isNaN(response.getOutputDeviation()), "Output response must be numeric");
        assertTrue(response.getLaborForceDeviation() > 0.0,
                "Positive eps_L should raise labor-force deviation");
    }

    @Test
    @EnabledIf("modelFilesExist")
    void testDynamicModelStatePersistenceAcrossQuarters() throws IOException {
        DSGEModel model = new DSGEModel();
        model.loadFromDirectory(PL_MODEL_PATH);

        double[] shocks = new double[model.getNumShocks()];
        shocks[model.getIdxEpsL()] = 0.01;
        model.stepQuarterly(shocks);

        DSGEState stateAfterShock = model.stepQuarterly(new double[model.getNumShocks()]);
        assertNotEquals(0.0, stateAfterShock.getLaborForceDeviation(),
                "Dynamic state should persist after a one-quarter shock");
    }

    // ========== Ramsey Trend Manager Integration ==========

    static boolean ramseyFilesExist() {
        File dir = new File(PL_MODEL_PATH);
        return dir.exists()
                && dir.listFiles((d, n) -> n.startsWith("growth_params_") && n.endsWith(".json")) != null
                && dir.listFiles((d, n) -> n.startsWith("growth_params_") && n.endsWith(".json")).length > 0
                && new File(dir, "growth_terminal_state.json").exists();
    }

    /**
     * Test that MacroModelManager.initializeRamseyTrend() loads the model,
     * solves the forward projection, and produces a valid trend object.
     */
    @Test
    @EnabledIf("ramseyFilesExist")
    void testManagerInitializesRamseyTrend() throws IOException {
        MacroModelManager manager = new MacroModelManager();
        manager.setUseRamseyTrend(true);
        manager.setLogMacroState(true);

        // Direct call to initializeRamseyTrend (package-private)
        manager.initializeRamseyTrend(PL_MODEL_PATH);

        // Model should be initialized and solved
        assertTrue(manager.isUseRamseyTrend(), "Ramsey trend should be enabled");
        assertNotNull(manager.getRamseyTrend(), "Ramsey model should exist");
        assertTrue(manager.getRamseyTrend().isSolved(), "Ramsey model should be solved");
    }

    /**
     * Test the full advanceRamseyTrend cycle: baseline set at initialization from
     * quarter 0, so the first stepYear (quarters 0-3 average) already produces a
     * small positive trend. Subsequent years produce growing trends.
     */
    @Test
    @EnabledIf("ramseyFilesExist")
    void testManagerRamseyWageTrendCycle() throws IOException {
        MacroModelManager manager = new MacroModelManager();
        manager.setUseRamseyTrend(true);
        manager.setLogMacroState(true);

        manager.initializeRamseyTrend(PL_MODEL_PATH);

        // Year 1: baseline set during initializeRamseyTrend from quarter 0.
        // First stepYear() averages quarters 0-3, so trend should be small but
        // potentially non-zero (could be positive or slightly negative depending
        // on the path shape in the first year).
        manager.advanceRamseyTrend();
        double trend1 = manager.getCapitalDeepeningWageAdjustment();
        assertTrue(Math.abs(trend1) < 2.0,
                "First year trend should be small (baseline is quarter 0), got: " + trend1);

        // Year 2: trend should grow
        manager.advanceRamseyTrend();
        double trend2 = manager.getCapitalDeepeningWageAdjustment();
        assertTrue(trend2 > trend1, "Second year trend should exceed first year, got: " + trend2);
        assertTrue(trend2 < 4.0, "Second year trend should be modest, got: " + trend2);

        // Year 5: larger trend
        manager.advanceRamseyTrend();
        manager.advanceRamseyTrend();
        manager.advanceRamseyTrend();
        double trend5 = manager.getCapitalDeepeningWageAdjustment();
        assertTrue(trend5 > trend2, "Trend should grow over time");

        System.out.println("=== Manager Ramsey Trend ===");
        System.out.printf("  Year 1: %+.4f%%\n", trend1);
        System.out.printf("  Year 2: %+.4f%%\n", trend2);
        System.out.printf("  Year 5: %+.4f%%\n", trend5);
    }

    /**
     * A missing Ramsey bundle is fatal, not a soft fallback.
     *
     * <p>This test previously asserted the opposite: that the manager quietly cleared
     * {@code useRamseyTrend} and carried on. That behaviour was removed deliberately,
     * because a silent fallback means a run configured for the Ramsey layer produces
     * non-Ramsey numbers that look exactly like Ramsey numbers. The same reasoning
     * removed the legacy population-projection fallback. The test kept asserting the
     * old contract only because it never ran &mdash; surefire excludes
     * {@code *IntegrationTest} and CI failed earlier in the build.</p>
     */
    @Test
    void testManagerRefusesToRunWithoutRamseyFiles() {
        MacroModelManager manager = new MacroModelManager();
        manager.setUseRamseyTrend(true);

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> manager.initializeRamseyTrend("input/nonexistent_country/MacroModel"),
                "A missing bundle must fail the run, not silently disable the trend layer");

        assertTrue(ex.getMessage().contains("growth_params_"),
                "Message should name the artefact that is missing, got: " + ex.getMessage());
        assertTrue(ex.getMessage().contains("fatal"),
                "Message should say the run cannot continue, got: " + ex.getMessage());
    }
    
    // ========== Export-bundle contract validation ==========

    /**
     * shock_indices_java pins which column of the shock vector carries eps_L. The old
     * default of 3 dates from an earlier schema; in the current export eps_L is 4 and 3
     * is eps_p, so defaulting would route SimPaths' labour-supply signal into the
     * cost-push slot and scale it by sigma_p. A bundle that cannot state its own shock
     * layout must not load.
     */
    @Test
    @EnabledIf("modelFilesExist")
    void testMissingShockIndicesIsRejected() throws IOException {
        Path scratch = copyBundleAndEdit("model_info.json",
                s -> s.replace("shock_indices_java", "shock_indices_java_DISABLED"));

        DSGEModel model = new DSGEModel();
        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> model.loadFromDirectory(scratch.toString()),
                "Bundle without shock_indices_java must not load with guessed indices");
        assertTrue(ex.getMessage().contains("shock_indices_java"),
                "Error should name the missing key, got: " + ex.getMessage());
    }

    /**
     * A short shock_params.csv previously left trailing shocks at sigma=0, which silently
     * disables their scaling in stepQuarterly rather than failing.
     */
    @Test
    @EnabledIf("modelFilesExist")
    void testShortShockParamsFileIsRejected() throws IOException {
        Path scratch = copyBundleAndEdit("shock_params.csv", s -> {
            String[] lines = s.split("\\R");
            StringBuilder sb = new StringBuilder();
            // header + all but the last two shock rows
            for (int i = 0; i < lines.length - 2; i++) {
                sb.append(lines[i]).append('\n');
            }
            return sb.toString();
        });

        DSGEModel model = new DSGEModel();
        assertThrows(IllegalArgumentException.class,
                () -> model.loadFromDirectory(scratch.toString()),
                "Truncated shock_params.csv must not load with zero-sigma trailing shocks");
    }

    /**
     * Matrix rows are consumed positionally; the row-name column was read and discarded.
     * A CSV refreshed from a different export run would misalign silently.
     */
    @Test
    @EnabledIf("modelFilesExist")
    void testMisalignedMatrixRowNamesAreRejected() throws IOException {
        Path scratch = copyBundleAndEdit("policy_A.csv",
                s -> s.replaceFirst("(?m)^c,", "NOT_A_STATE,"));

        DSGEModel model = new DSGEModel();
        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> model.loadFromDirectory(scratch.toString()),
                "policy_A row names must be validated against state_names");
        assertTrue(ex.getMessage().contains("NOT_A_STATE"),
                "Error should name the offending row, got: " + ex.getMessage());
    }

    /**
     * Bs/D columns are the shock vector in export order. A reordered or renamed shock
     * column would silently permute every shock's effect.
     */
    @Test
    @EnabledIf("modelFilesExist")
    void testMisalignedShockColumnsAreRejected() throws IOException {
        Path scratch = copyBundleAndEdit("policy_Bs.csv",
                s -> s.replaceFirst("eps_L", "eps_WRONG"));

        DSGEModel model = new DSGEModel();
        assertThrows(IllegalArgumentException.class,
                () -> model.loadFromDirectory(scratch.toString()),
                "policy_Bs shock column names must be validated against the export order");
    }

    /**
     * The forward horizon must come from the bundle, not from a constant duplicated on
     * each side. MATLAB solves the handoff contract over projection_quarters; if Java
     * silently used a different number the terminal closure would differ on one side.
     */
    @Test
    @EnabledIf("ramseyFilesExist")
    void testProjectionHorizonComesFromBundle() throws IOException {
        Path scratch = copyBundleAndEdit("growth_terminal_state.json", s -> {
            String stripped = s.replaceAll("\\s*\"projection_quarters\"\\s*:\\s*\\d+,", "");
            // Declare a horizon that differs from the legacy 320 default.
            return stripped.replaceFirst("\\{", "{\n  \"projection_quarters\": 240,");
        });

        MacroModelManager manager = new MacroModelManager();
        manager.setUseRamseyTrend(true);
        manager.initializeRamseyTrend(scratch.toString());

        assertEquals(240, manager.getRamseyProjectionQuarters(),
                "Projection horizon must be taken from growth_terminal_state.json");
    }

    // ========== Population Projection Integration ==========
    
    static boolean populationProjectionFileExists() {
        return ramseyFilesExist()
                && new File(PL_MODEL_PATH, "population_projection_Poland.csv").exists();
    }

    /**
     * Copy the deployed Poland bundle into a scratch directory, optionally renaming one
     * file on the way. Returns the scratch directory.
     */
    private static Path copyBundle(String renameFrom, String renameTo) throws IOException {
        Path scratch = Files.createTempDirectory("macro-bundle-test");
        scratch.toFile().deleteOnExit();
        File[] files = new File(PL_MODEL_PATH).listFiles();
        assertNotNull(files, "Deployed PL bundle should be listable");
        for (File f : files) {
            if (!f.isFile() || f.getName().startsWith("_macroScenario_")) {
                continue;
            }
            String target = f.getName().equals(renameFrom) ? renameTo : f.getName();
            Path dest = scratch.resolve(target);
            Files.copy(f.toPath(), dest);
            dest.toFile().deleteOnExit();
        }
        return scratch;
    }

    private static Path copyBundleWithProjectionNamed(String projectionName) throws IOException {
        return copyBundle("population_projection_Poland.csv", projectionName);
    }

    /** Copy the bundle, then rewrite one file's contents. */
    private static Path copyBundleAndEdit(String fileName, UnaryOperator<String> edit)
            throws IOException {
        Path scratch = copyBundle(null, null);
        Path target = scratch.resolve(fileName);
        Files.writeString(target, edit.apply(Files.readString(target)));
        return scratch;
    }

    /**
     * A population projection carrying the legacy country-agnostic name must not be
     * silently consumed. Historically MacroModelManager fell back to
     * population_projection.csv, which dated from the period when the German macro
     * model was run inside Polish SimPaths. In a per-country layout that fallback can
     * only ever feed one country's demographics into another country's trend.
     */
    @Test
    @EnabledIf("populationProjectionFileExists")
    void testUnsuffixedPopulationProjectionIsNotSilentlyConsumed() throws IOException {
        Path scratch = copyBundleWithProjectionNamed("population_projection.csv");

        MacroModelManager manager = new MacroModelManager();
        manager.setUseRamseyTrend(true);

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> manager.initializeRamseyTrend(scratch.toString()),
                "Legacy unsuffixed projection must not be accepted silently");
        assertTrue(ex.getMessage().contains("population_projection_Poland.csv"),
                "Error should name the expected file, got: " + ex.getMessage());
    }

    /**
     * The dangerous historical case: another country's projection sitting in this
     * bundle's directory must fail loudly rather than drive the Ramsey trend.
     */
    @Test
    @EnabledIf("populationProjectionFileExists")
    void testForeignCountryPopulationProjectionIsNotSilentlyConsumed() throws IOException {
        Path scratch = copyBundleWithProjectionNamed("population_projection_Germany.csv");

        MacroModelManager manager = new MacroModelManager();
        manager.setUseRamseyTrend(true);

        assertThrows(IllegalStateException.class,
                () -> manager.initializeRamseyTrend(scratch.toString()),
                "A foreign-country projection must not be consumed for this bundle");
    }
    
    /**
     * Test that population_projection_[COUNTRY].csv is loaded and causes the Ramsey trend
     * to use declining N (Polish demographics) instead of growing N (German
     * extrapolation). The key indicator: n_ramsey trend should turn negative
     * over time, reflecting Polish working-age population decline.
     */
    @Test
    @EnabledIf("populationProjectionFileExists")
    void testPopulationProjectionProducesNegativeNTrend() throws IOException {
        MacroModelManager manager = new MacroModelManager();
        manager.setUseRamseyTrend(true);
        manager.setLogMacroState(true);
        
        manager.initializeRamseyTrend(PL_MODEL_PATH);
        assertTrue(manager.getRamseyTrend().isSolved(), "Ramsey model should be solved");
        
        // Year 1: baseline already set during initializeRamseyTrend
        manager.advanceRamseyTrend();
        
        // Advance several years to see the declining N trend
        double nTrend = 0.0;
        for (int y = 0; y < 10; y++) {
            manager.advanceRamseyTrend();
            nTrend = manager.getCurrentRamseyTrends().getOrDefault("n_ramsey", 0.0);
        }
        
        // After 10 years, the N trend should be negative (Polish WAP is declining)
        assertTrue(nTrend < 0.0,
                "n_ramsey trend should be negative after 10 years with Polish demographics, "
                + "got: " + nTrend + "%");
        
        // The wage trend should still be positive (capital deepening: K grows
        // relative to shrinking L, so MPL and wages rise)
        double wageTrend = manager.getCapitalDeepeningWageAdjustment();
        assertTrue(wageTrend > 0.0,
                "Wage trend should be positive due to capital deepening, got: " + wageTrend + "%");
        
        System.out.println("=== Population Projection Test ===");
        System.out.printf("  After 10 years: n_ramsey=%+.4f%%, wage=%+.4f%%\n", nTrend, wageTrend);
    }

        @Test
        @EnabledIf("modelFilesExist")
        void testBaselineMustBeLatchedPostLaborMarket() {
        MacroModelManager manager = new MacroModelManager();
        manager.setEnabled(true);
        manager.setUseDsge(true);
        manager.setUseRamseyTrend(false);

        Person worker = mock(Person.class);
        when(worker.getDag()).thenReturn(35);
        when(worker.getLes_c4()).thenReturn(Les_c4.EmployedOrSelfEmployed);
        when(worker.atRiskOfWork()).thenReturn(true);
        when(worker.getWeight()).thenReturn(1.0);
        when(worker.getLabourSupplyHoursWeekly()).thenReturn(40);
        Set<Person> persons = Set.of(worker);

        // Year 1: initialize DSGE, but baseline must remain unset until post-labor-market latch.
        manager.updateEquilibrium(2027, 2027, "PL", persons, Collections.emptySet(), false);
        assertFalse(manager.isLaborSupplyBaselineSet(),
            "Baseline should not be auto-set during first-year DSGE macro update");

        // Strict fix: latch baseline from post-labor-market state.
        assertTrue(manager.latchBaselineFromPostLaborMarket(2027, persons),
            "Baseline should be latched exactly once from post-labor-market state");
        assertTrue(manager.isLaborSupplyBaselineSet(),
            "Baseline should be set after explicit post-labor-market latch");
        assertFalse(manager.latchBaselineFromPostLaborMarket(2027, persons),
            "Second latch call should be a no-op");

        // Year 2 should run normally now that baseline exists.
        manager.updateEquilibrium(2028, 2027, "PL", persons, Collections.emptySet(), false);
        assertTrue(Double.isFinite(manager.getWageDeviation()),
            "Wage deviation should be finite after year-2 DSGE update");

        // Control check: without explicit latch, baseline remains unset in year 2 and DSGE keeps skipping.
        MacroModelManager noLatchManager = new MacroModelManager();
        noLatchManager.setEnabled(true);
        noLatchManager.setUseDsge(true);
        noLatchManager.setUseRamseyTrend(false);
        noLatchManager.updateEquilibrium(2027, 2027, "PL", persons, Collections.emptySet(), false);
        noLatchManager.updateEquilibrium(2028, 2027, "PL", persons, Collections.emptySet(), false);
        assertFalse(noLatchManager.isLaborSupplyBaselineSet(),
            "Without post-labor-market latch, baseline should remain unset");
        }
}
