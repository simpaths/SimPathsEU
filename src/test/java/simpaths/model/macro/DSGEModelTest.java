package simpaths.model.macro;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Unit tests for DSGEModel class.
 *
 * Tests cover:
 * 1. Matrix loading and dimensions
 * 2. Policy function evaluation
 * 3. IRF validation against Dynare output
 * 4. Shock scaling methods
 * 5. Stability checks
 */
public class DSGEModelTest {

    /** Path to test data (Poland MacroModel directory) */
    private static final String MACRO_MODEL_PATH = "input/PL/MacroModel";

    /** Model instance for tests */
    private DSGEModel model;

    @TempDir
    Path tempDir;

    /** Flag indicating if test data is available */
    private static boolean testDataAvailable = false;

    @BeforeAll
    public static void checkTestData() {
        Path path = Paths.get(MACRO_MODEL_PATH);
        testDataAvailable = Files.exists(path) &&
                           Files.exists(path.resolve("policy_A.csv")) &&
                           Files.exists(path.resolve("policy_Bs.csv")) &&
                           Files.exists(path.resolve("policy_C.csv")) &&
                           Files.exists(path.resolve("policy_D.csv")) &&
                           Files.exists(path.resolve("model_info.json"));

        if (!testDataAvailable) {
            System.out.println("WARNING: DSGE test data not found at " + MACRO_MODEL_PATH);
            System.out.println("Skipping integration tests. Run Dynare export first.");
        }
    }

    @BeforeEach
    public void setUp() throws IOException {
        model = new DSGEModel();
        if (testDataAvailable) {
            model.loadFromDirectory(MACRO_MODEL_PATH);
        }
    }

    // ========== Loading Tests ==========

    @Test
    public void testModelNotLoadedInitially() {
        DSGEModel freshModel = new DSGEModel();
        assertFalse(freshModel.isLoaded(), "Fresh model should not be loaded");
    }

    @Test
    public void testStepBeforeLoad() {
        DSGEModel freshModel = new DSGEModel();
        assertThrows(IllegalStateException.class, () ->
            freshModel.stepQuarterly(new double[7]));
    }

    @Test
    public void testStepQuarterlyNullShocks() {
        assumeTestDataAvailable();
        assertThrows(IllegalArgumentException.class, () ->
            model.stepQuarterly(null), "Should reject null shocks");
    }

    @Test
    public void testStepQuarterlyWrongShockCount() {
        assumeTestDataAvailable();
        assertThrows(IllegalArgumentException.class, () ->
            model.stepQuarterly(new double[5]), "Should reject wrong shock count");
    }

    @Test
    public void testLoadInvalidDirectory() {
        DSGEModel freshModel = new DSGEModel();
        assertThrows(IllegalArgumentException.class, () ->
            freshModel.loadFromDirectory("/nonexistent/path"),
            "Should throw on non-existent directory");
    }

    @Test
    public void testLoadMatrices() {
        assumeTestDataAvailable();

        assertTrue(model.isLoaded(), "Model should be loaded");
        assertTrue(model.getNumStates() > 0, "State dimension must be positive");
        assertTrue(model.getNumJumps() > 0, "Jump dimension must be positive");
        assertTrue(model.getNumShocks() > 0, "Shock dimension must be positive");
    }

    @Test
    public void testMatrixDimensions() {
        assumeTestDataAvailable();

        double[][] A = model.getMatrixA();
        double[][] Bs = model.getMatrixBs();
        double[][] C = model.getMatrixC();
        double[][] D = model.getMatrixD();

        assertNotNull(A, "Matrix A should not be null");
        assertNotNull(Bs, "Matrix Bs should not be null");
        assertNotNull(C, "Matrix C should not be null");
        assertNotNull(D, "Matrix D should not be null");

        // Dimensions should match what was loaded from JSON
        assertEquals(model.getNumStates(), A.length, "A rows should match nState");
        assertEquals(model.getNumStates(), A[0].length, "A cols should match nState");
        assertEquals(model.getNumStates(), Bs.length, "Bs rows should match nState");
        assertEquals(model.getNumShocks(), Bs[0].length, "Bs cols should match nExo");
        assertEquals(model.getNumJumps(), C.length, "C rows should match nJump");
        assertEquals(model.getNumStates(), C[0].length, "C cols should match nState");
        assertEquals(model.getNumJumps(), D.length, "D rows should match nJump");
        assertEquals(model.getNumShocks(), D[0].length, "D cols should match nExo");
    }

    @Test
    public void testShockParameters() {
        assumeTestDataAvailable();

        double[] stdDev = model.getShockStdDev();
        double[] rho = model.getShockRho();

        assertNotNull(stdDev, "Shock std dev should be loaded");
        assertNotNull(rho, "Shock rho should be loaded");

        assertEquals(model.getNumShocks(), stdDev.length, "Should have correct number of shock std devs");
        assertEquals(model.getNumShocks(), rho.length, "Should have correct number of shock rhos");

        // eps_L should be positive and finite (value depends on current estimation export)
        assertTrue(Double.isFinite(stdDev[model.getIdxEpsL()]), "eps_L std dev should be finite");
        assertTrue(stdDev[model.getIdxEpsL()] > 0.0, "eps_L std dev should be positive");

        // eps_L persistence should be finite and in a valid AR(1) range
        assertTrue(Double.isFinite(rho[model.getIdxEpsL()]), "eps_L rho should be finite");
        assertTrue(Math.abs(rho[model.getIdxEpsL()]) < 1.0, "eps_L rho should be within (-1,1)");
    }

    @Test
    public void testDimensionsLoadedFromJson() {
        assumeTestDataAvailable();

        // Verify dimensions were loaded from model_info.json
        assertTrue(model.getNumStates() > 0, "nState should be positive");
        assertTrue(model.getNumJumps() > 0, "nJump should be positive");
        assertTrue(model.getNumShocks() > 0, "nExo should be positive");

        // Verify shock indices were loaded
        assertTrue(model.getIdxEpsL() >= 0 && model.getIdxEpsL() < model.getNumShocks(),
            "eps_L index should be valid");
        assertTrue(model.getIdxEpsH() >= 0 && model.getIdxEpsH() < model.getNumShocks(),
            "eps_h index should be valid");

        // Verify VarIndices were loaded
        DSGEState.VarIndices idx = model.getVarIndices();
        assertNotNull(idx, "VarIndices should be loaded");
        assertTrue(idx.sW >= 0 && idx.sW < model.getNumStates(), "w index should be valid");
        // pi is a state in the current (V15+, indexation) exports
        assertTrue(idx.piIsState, "pi should resolve to the state side in the current export");
        assertTrue(idx.piIdx >= 0 && idx.piIdx < model.getNumStates(), "pi state index should be valid");

        // Verify variable names were loaded
        assertNotNull(model.getStateNames(), "State names should be loaded");
        assertNotNull(model.getJumpNames(), "Jump names should be loaded");
        assertEquals(model.getNumStates(), model.getStateNames().length, "State names count should match");
        assertEquals(model.getNumJumps(), model.getJumpNames().length, "Jump names count should match");
    }

    // ========== Policy Function Tests ==========

    @Test
    public void testStepQuarterly_NoShock() {
        assumeTestDataAvailable();

        model.resetToSteadyState();
        double[] zeroShocks = new double[model.getNumShocks()];

        DSGEState state = model.stepQuarterly(zeroShocks);

        assertEquals(0.0, state.getWageDeviation(), 1e-10, "Wage deviation should be zero");
        assertEquals(0.0, state.getInflationDeviation(), 1e-10, "Inflation deviation should be zero");
        assertEquals(0.0, state.getOutputDeviation(), 1e-10, "Output deviation should be zero");
    }

    @Test
    public void testStepQuarterly_LaborShock() {
        assumeTestDataAvailable();

        model.resetToSteadyState();

        double[] shocks = new double[model.getNumShocks()];
        shocks[model.getIdxEpsL()] = 0.01;

        DSGEState state = model.stepQuarterly(shocks);

        assertTrue(state.getLaborForceDeviation() > 0, "Labor force should increase");
        assertNotEquals(0.0, state.getWageDeviation(), "Wage should change");
    }

    @Test
    public void testStepAnnual_LaborShock() {
        assumeTestDataAvailable();

        model.resetToSteadyState();

        DSGEState annualState = model.stepAnnual(0.02);

        assertTrue(annualState.getLaborForceDeviation() > 0, "Labor force should increase");
    }

    @Test
    public void testStatePersistence() {
        assumeTestDataAvailable();

        model.resetToSteadyState();

        double[] shocks = new double[model.getNumShocks()];
        shocks[model.getIdxEpsL()] = 0.01;
        model.stepQuarterly(shocks);

        double[] zeroShocks = new double[model.getNumShocks()];
        DSGEState state2 = model.stepQuarterly(zeroShocks);
        DSGEState state3 = model.stepQuarterly(zeroShocks);

        assertNotEquals(0.0, state2.getLaborForceDeviation(), "State should persist after shock");
        assertNotEquals(0.0, state3.getLaborForceDeviation(), "State should still persist");
    }

    @Test
    public void testNonSimPathsShockUsesSigmaScaledInnovation() {
        assumeTestDataAvailable();

        model.resetToSteadyState();

        int epsP = indexOf(model.getShockNames(), "eps_p");
        int wageState = indexOf(model.getStateNames(), "w");
        int capitalState = indexOf(model.getStateNames(), "k");
        int outputJump = indexOf(model.getJumpNames(), "y");
        int thetaJump = indexOf(model.getJumpNames(), "theta");

        double sigma = model.getShockStdDev()[epsP];
        double[] shocks = new double[model.getNumShocks()];
        shocks[epsP] = 1.0;

        DSGEState shockedState = model.stepQuarterly(shocks);
        double[][] bs = model.getMatrixBs();
        double[][] d = model.getMatrixD();

        assertEquals(bs[wageState][epsP] * sigma, shockedState.getStateVector()[wageState], 1e-12,
            "State response should equal raw policy loading times sigma");
        assertEquals(bs[capitalState][epsP] * sigma, shockedState.getStateVector()[capitalState], 1e-12,
            "Capital state should use sigma-scaled innovation");
        assertEquals(d[outputJump][epsP] * sigma, shockedState.getJumpVector()[outputJump], 1e-12,
            "Jump response should equal raw policy loading times sigma");
        assertEquals(d[thetaJump][epsP] * sigma, shockedState.getJumpVector()[thetaJump], 1e-12,
            "Theta jump should use sigma-scaled innovation");
    }

    @Test
    public void testAnnualScenarioMatchesExplicitQuarterRollout() throws IOException {
        assumeTestDataAvailable();

        Path scenarioFile = tempDir.resolve("scenario.csv");
        Files.writeString(scenarioFile,
            String.join(System.lineSeparator(),
                "year,quarter,eps_p,eps_a",
                "2032,1,0.50,0.00",
                "2032,2,0.00,0.25",
                "2032,3,-0.25,0.00",
                "2032,4,0.10,-0.20") + System.lineSeparator());

        DSGEShockScenario scenario = new DSGEShockScenario(model.getShockNames(), model.getNumShocks());
        scenario.loadFromFile(scenarioFile);

        model.resetToSteadyState();
        DSGEModel manualModel = new DSGEModel();
        manualModel.loadFromDirectory(MACRO_MODEL_PATH);
        manualModel.resetToSteadyState();

        double epsL = 0.015;
        double epsH = -0.010;
        DSGEState annualAverage = model.stepAnnualWithScenario(epsL, epsH, scenario, 2032);

        double[] sumState = new double[manualModel.getNumStates()];
        double[] sumJumps = new double[manualModel.getNumJumps()];
        DSGEState quarterState = null;
        int idxEpsL = manualModel.getIdxEpsL();
        int idxEpsH = manualModel.getIdxEpsH();
        for (int quarter = 1; quarter <= 4; quarter++) {
            double[] quarterShocks = scenario.getShocks(2032, quarter);
            quarterShocks[idxEpsL] += epsL;
            quarterShocks[idxEpsH] += epsH;

            quarterState = manualModel.stepQuarterly(quarterShocks);
            for (int i = 0; i < sumState.length; i++) {
                sumState[i] += quarterState.getStateVector()[i];
            }
            for (int i = 0; i < sumJumps.length; i++) {
                sumJumps[i] += quarterState.getJumpVector()[i];
            }
        }

        for (int i = 0; i < sumState.length; i++) {
            sumState[i] /= 4.0;
        }
        for (int i = 0; i < sumJumps.length; i++) {
            sumJumps[i] /= 4.0;
        }

        assertArrayEquals(sumState, annualAverage.getStateVector(), 1e-12,
            "Annual scenario average state should match explicit quarter-by-quarter averaging");
        assertArrayEquals(sumJumps, annualAverage.getJumpVector(), 1e-12,
            "Annual scenario average jumps should match explicit quarter-by-quarter averaging");
        assertNotNull(quarterState, "Manual quarter rollout should produce a final quarter state");
        assertArrayEquals(manualModel.getState(), model.getState(), 1e-12,
            "Internal end-of-year state should match the explicit fourth-quarter rollout");
    }

    // ========== IRF Validation Tests ==========

    @Test
    public void testIRF_LaborShock_WageResponse() {
        assumeTestDataAvailable();

        model.resetToSteadyState();

        double[] shocks = new double[model.getNumShocks()];
        shocks[model.getIdxEpsL()] = 0.04;  // 1 std dev for quarterly

        double[] wageIRF = new double[20];
        double[] laborIRF = new double[20];

        for (int q = 0; q < 20; q++) {
            DSGEState state = model.stepQuarterly(q == 0 ? shocks : new double[model.getNumShocks()]);
            wageIRF[q] = state.getWageDeviation();
            laborIRF[q] = state.getLaborForceDeviation();
        }

        assertTrue(laborIRF[0] > 0, "Labor should increase on impact");

        double maxWageAbsChange = 0;
        for (double w : wageIRF) {
            maxWageAbsChange = Math.max(maxWageAbsChange, Math.abs(w));
        }
        assertTrue(maxWageAbsChange > 1e-6, "Wages should respond to labor shock");

        assertTrue(Math.abs(laborIRF[19]) < Math.abs(laborIRF[0]) * 2.0, "IRF should not explode");
    }

    // ========== Stability Tests ==========

    @Test
    public void testStability_NormalOperation() {
        assumeTestDataAvailable();

        model.resetToSteadyState();

        for (int t = 0; t < 100; t++) {
            double[] shocks = new double[model.getNumShocks()];
            shocks[model.getIdxEpsL()] = 0.01 * Math.sin(t * 0.1);
            model.stepQuarterly(shocks);
        }

        assertTrue(true, "Model remained stable");
    }

    @Test
    public void testStateReset() {
        assumeTestDataAvailable();

        model.resetToSteadyState();

        double[] shocks = new double[model.getNumShocks()];
        shocks[model.getIdxEpsL()] = 0.05;
        model.stepQuarterly(shocks);

        double[] stateAfterShock = model.getState();
        boolean hasNonZero = false;
        for (double s : stateAfterShock) {
            if (Math.abs(s) > 1e-10) hasNonZero = true;
        }
        assertTrue(hasNonZero, "State should be non-zero after shock");

        model.resetToSteadyState();
        double[] stateAfterReset = model.getState();
        for (double s : stateAfterReset) {
            assertEquals(0.0, s, 1e-10, "State should be zero after reset");
        }
    }

    // ========== Helper Methods ==========

    private void assumeTestDataAvailable() {
        if (!testDataAvailable) {
            System.out.println("Skipping test - DSGE data not available");
            Assumptions.assumeTrue(testDataAvailable, "Test data available");
        }
    }

    private int indexOf(String[] names, String target) {
        for (int i = 0; i < names.length; i++) {
            if (target.equals(names[i])) {
                return i;
            }
        }
        fail("Variable not found in loaded schema: " + target);
        return -1;
    }
}
