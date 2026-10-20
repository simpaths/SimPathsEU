package simpaths.model.macro;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for DSGEState class.
 *
 * Uses VarIndices.DEFAULT for index constants, matching the current exported schema:
 * - State variables (13): c, R, pi, w, v, n, h, x, L, k, inv, sep_shock, d_shock
 * - Jump variables (9): y, d, gap, w_star, u, u_rate, m, mc, theta
 */
public class DSGEStateTest {

    /** Shorthand for default variable indices */
    private static final DSGEState.VarIndices IDX = DSGEState.VarIndices.DEFAULT;

    @Test
    public void testInflationReadFromStateWhenPiIsState() {
        // Since V15 (iota_p indexation) pi(-1) enters the NKPC, so pi is a STATE
        // variable in the exported model (state_idx_in_s["pi"] = 2 in model_info.json;
        // the jump map has no "pi"). getInflationDeviation() must therefore read the
        // state vector's pi slot — NOT fall back to jump slot 2, which is "gap".
        double[] states = new double[DSGEState.DEFAULT_N_STATE];
        double[] jumps = new double[DSGEState.DEFAULT_N_JUMP];

        states[2] = 0.02;        // pi (STATE, index 2 in the exported schema)
        jumps[IDX.yGap] = 0.13;  // gap (JUMP, index 2) — must NOT be reported as inflation

        DSGEState state = new DSGEState(states, jumps);

        assertEquals(0.02, state.getInflationDeviation(), 1e-10,
            "Inflation must come from the state vector's pi slot, not the gap jump slot");
    }

    @Test
    public void testConstructionNullStateInput() {
        double[] jumps = new double[DSGEState.DEFAULT_N_JUMP];
        assertThrows(IllegalArgumentException.class, () -> new DSGEState(null, jumps),
            "Should throw on null state input");
    }

    @Test
    public void testConstructionNullJumpInput() {
        double[] states = new double[DSGEState.DEFAULT_N_STATE];
        assertThrows(IllegalArgumentException.class, () -> new DSGEState(states, null),
            "Should throw on null jump input");
    }

    @Test
    public void testConstruction() {
        double[] states = new double[DSGEState.DEFAULT_N_STATE];
        double[] jumps = new double[DSGEState.DEFAULT_N_JUMP];

        states[IDX.sW] = 0.05;      // 5% wage deviation (STATE)
        states[IDX.piIdx] = 0.02;   // 2% inflation deviation (STATE since V15)
        jumps[IDX.yY] = 0.03;       // 3% output deviation (JUMP)

        DSGEState state = new DSGEState(states, jumps);

        assertEquals(0.05, state.getWageDeviation(), 1e-10, "Wage deviation");
        assertEquals(0.02, state.getInflationDeviation(), 1e-10, "Inflation deviation");
        assertEquals(0.03, state.getOutputDeviation(), 1e-10, "Output deviation");
    }

    @Test
    public void testConstructionTooSmallState() {
        double[] states = new double[5];  // Smaller than minStateSize
        double[] jumps = new double[DSGEState.DEFAULT_N_JUMP];
        assertThrows(IllegalArgumentException.class, () -> new DSGEState(states, jumps));
    }

    @Test
    public void testConstructionTooSmallJump() {
        double[] states = new double[DSGEState.DEFAULT_N_STATE];
        double[] jumps = new double[5];  // Smaller than minJumpSize
        assertThrows(IllegalArgumentException.class, () -> new DSGEState(states, jumps));
    }

    @Test
    public void testDefaultConstructor() {
        DSGEState state = new DSGEState();

        assertEquals(0.0, state.getWageDeviation(), 1e-10, "Default wage should be 0");
        assertEquals(0.0, state.getInflationDeviation(), 1e-10, "Default inflation should be 0");
        assertEquals(0.0, state.getOutputDeviation(), 1e-10, "Default output should be 0");
    }

    @Test
    public void testStateVectorRetrieval() {
        double[] states = new double[DSGEState.DEFAULT_N_STATE];
        double[] jumps = new double[DSGEState.DEFAULT_N_JUMP];

        states[IDX.sR] = 0.01;
        states[IDX.sW] = 0.02;
        states[IDX.sV] = 0.03;
        states[IDX.sN] = 0.04;
        states[IDX.sH] = 0.05;
        states[IDX.sX] = 0.06;
        states[IDX.sL] = 0.07;
        states[IDX.sSepShock] = 0.08;
        states[IDX.sDShock] = 0.09;

        DSGEState dsgeState = new DSGEState(states, jumps);
        double[] stateVec = dsgeState.getStateVector();

        assertEquals(DSGEState.DEFAULT_N_STATE, stateVec.length, "State vector length");
        assertEquals(0.01, stateVec[IDX.sR], 1e-10, "R in state");
        assertEquals(0.02, stateVec[IDX.sW], 1e-10, "w in state");
        assertEquals(0.03, stateVec[IDX.sV], 1e-10, "v in state");
        assertEquals(0.04, stateVec[IDX.sN], 1e-10, "n in state");
        assertEquals(0.05, stateVec[IDX.sH], 1e-10, "h in state");
        assertEquals(0.06, stateVec[IDX.sX], 1e-10, "x in state");
        assertEquals(0.07, stateVec[IDX.sL], 1e-10, "L in state");
    }

    @Test
    public void testJumpVectorRetrieval() {
        double[] states = new double[DSGEState.DEFAULT_N_STATE];
        double[] jumps = new double[DSGEState.DEFAULT_N_JUMP];

        jumps[IDX.yY] = 0.11;
        jumps[IDX.yD] = 0.12;
        jumps[IDX.yGap] = 0.13;
        jumps[IDX.yWStar] = 0.15;
        jumps[IDX.yU] = 0.16;
        jumps[IDX.yURate] = 0.17;
        jumps[IDX.yM] = 0.18;
        jumps[IDX.yMC] = 0.19;
        jumps[IDX.yTheta] = 0.20;

        DSGEState dsgeState = new DSGEState(states, jumps);
        double[] jumpVec = dsgeState.getJumpVector();

        assertEquals(DSGEState.DEFAULT_N_JUMP, jumpVec.length, "Jump vector length");
        assertEquals(0.11, jumpVec[IDX.yY], 1e-10, "y in jump");
        assertEquals(0.13, jumpVec[IDX.yGap], 1e-10, "gap in jump");
        assertEquals(0.17, jumpVec[IDX.yURate], 1e-10, "u_rate in jump");
    }

    @Test
    public void testConvenienceGetters() {
        double[] states = new double[DSGEState.DEFAULT_N_STATE];
        double[] jumps = new double[DSGEState.DEFAULT_N_JUMP];

        states[IDX.sR] = 0.01;
        states[IDX.sW] = 0.02;
        states[IDX.sV] = 0.03;
        states[IDX.sN] = 0.04;
        states[IDX.sH] = 0.05;
        states[IDX.sL] = 0.06;

        states[IDX.piIdx] = 0.12;   // pi is a state in the default schema

        jumps[IDX.yY] = 0.11;
        jumps[IDX.yURate] = 0.13;
        jumps[IDX.yTheta] = 0.14;
        jumps[IDX.yMC] = 0.15;

        DSGEState dsgeState = new DSGEState(states, jumps);

        assertEquals(0.01, dsgeState.getInterestRateDeviation(), 1e-10, "R getter");
        assertEquals(0.02, dsgeState.getWageDeviation(), 1e-10, "w getter");
        assertEquals(0.03, dsgeState.getVacanciesDeviation(), 1e-10, "v getter");
        assertEquals(0.04, dsgeState.getEmploymentDeviation(), 1e-10, "n getter");
        assertEquals(0.05, dsgeState.getHoursDeviation(), 1e-10, "h getter");
        assertEquals(0.06, dsgeState.getLaborForceDeviation(), 1e-10, "L getter");

        assertEquals(0.11, dsgeState.getOutputDeviation(), 1e-10, "y getter");
        assertEquals(0.12, dsgeState.getInflationDeviation(), 1e-10, "pi getter");
        assertEquals(0.13, dsgeState.getUnemploymentRateDeviation(), 1e-10, "u_rate getter");
        assertEquals(0.14, dsgeState.getThetaDeviation(), 1e-10, "theta getter");
        assertEquals(0.15, dsgeState.getMarginalCostDeviation(), 1e-10, "mc getter");
    }

    @Test
    public void testStateVectorCopy() {
        double[] states = new double[DSGEState.DEFAULT_N_STATE];
        double[] jumps = new double[DSGEState.DEFAULT_N_JUMP];
        states[IDX.sW] = 0.05;

        DSGEState dsgeState = new DSGEState(states, jumps);
        double[] retrieved = dsgeState.getStateVector();

        retrieved[IDX.sW] = 0.99;
        assertEquals(0.05, dsgeState.getWageDeviation(), 1e-10, "Original should be unchanged");
    }

    @Test
    public void testJumpVectorCopy() {
        double[] states = new double[DSGEState.DEFAULT_N_STATE];
        double[] jumps = new double[DSGEState.DEFAULT_N_JUMP];
        jumps[IDX.yY] = 0.05;

        DSGEState dsgeState = new DSGEState(states, jumps);
        double[] retrieved = dsgeState.getJumpVector();

        retrieved[IDX.yY] = 0.99;
        assertEquals(0.05, dsgeState.getOutputDeviation(), 1e-10, "Original should be unchanged");
    }

    @Test
    public void testToCSV() {
        double[] states = new double[DSGEState.DEFAULT_N_STATE];
        double[] jumps = new double[DSGEState.DEFAULT_N_JUMP];

        states[IDX.sW] = 0.05;
        states[IDX.piIdx] = 0.02;
        jumps[IDX.yY] = 0.03;

        DSGEState dsgeState = new DSGEState(states, jumps);
        String csv = dsgeState.toCSV();

        assertTrue(csv.contains(","), "CSV should contain comma-separated values");
        assertFalse(csv.endsWith(","), "CSV should not end with comma");
    }

    @Test
    public void testToString() {
        double[] states = new double[DSGEState.DEFAULT_N_STATE];
        double[] jumps = new double[DSGEState.DEFAULT_N_JUMP];

        states[IDX.sW] = 0.05;
        states[IDX.piIdx] = 0.02;
        jumps[IDX.yY] = 0.03;

        DSGEState dsgeState = new DSGEState(states, jumps);
        String str = dsgeState.toString();

        assertTrue(str.contains("DSGEState"), "toString should mention DSGEState");
        assertTrue(str.contains("y="), "toString should contain y");
        assertTrue(str.contains("w="), "toString should contain w");
        assertTrue(str.contains("pi="), "toString should contain pi");
    }

    @Test
    public void testGetStateVar() {
        double[] states = new double[DSGEState.DEFAULT_N_STATE];
        double[] jumps = new double[DSGEState.DEFAULT_N_JUMP];
        states[IDX.sW] = 0.05;

        DSGEState dsgeState = new DSGEState(states, jumps);
        assertEquals(0.05, dsgeState.getStateVar(IDX.sW), 1e-10, "getStateVar should work");
    }

    @Test
    public void testGetJumpVar() {
        double[] states = new double[DSGEState.DEFAULT_N_STATE];
        double[] jumps = new double[DSGEState.DEFAULT_N_JUMP];
        jumps[IDX.yGap] = 0.03;

        DSGEState dsgeState = new DSGEState(states, jumps);
        assertEquals(0.03, dsgeState.getJumpVar(IDX.yGap), 1e-10, "getJumpVar should work");
    }

    @Test
    public void testGetStateVarBoundsCheck() {
        DSGEState dsgeState = new DSGEState();
        assertThrows(IndexOutOfBoundsException.class, () -> dsgeState.getStateVar(-1));
        assertThrows(IndexOutOfBoundsException.class, () -> dsgeState.getStateVar(DSGEState.DEFAULT_N_STATE));
    }

    @Test
    public void testGetJumpVarBoundsCheck() {
        DSGEState dsgeState = new DSGEState();
        assertThrows(IndexOutOfBoundsException.class, () -> dsgeState.getJumpVar(-1));
        assertThrows(IndexOutOfBoundsException.class, () -> dsgeState.getJumpVar(DSGEState.DEFAULT_N_JUMP));
    }

    @Test
    public void testDefaultDimensions() {
        assertEquals(13, DSGEState.DEFAULT_N_STATE, "DEFAULT_N_STATE should be 13");
        assertEquals(9, DSGEState.DEFAULT_N_JUMP, "DEFAULT_N_JUMP should be 9");
    }

    @Test
    public void testVarIndicesDefault() {
        // Verify default indices match the current exported SimPaths DSGE structure
        assertEquals(1, IDX.sR, "R should be at index 1");
        assertEquals(3, IDX.sW, "w should be at index 3");
        assertEquals(5, IDX.sN, "n should be at index 5");
        assertEquals(8, IDX.sL, "L should be at index 8");
        assertEquals(0, IDX.yY, "y should be at index 0");
        assertTrue(IDX.piIsState, "pi is a state in the default (V15+) schema");
        assertEquals(2, IDX.piIdx, "pi should be at state index 2");
        assertEquals(5, IDX.yURate, "u_rate should be at index 5");
        assertEquals(8, IDX.yTheta, "theta should be at index 8");

        assertEquals(13, IDX.minStateSize, "minStateSize should be 13");
        assertEquals(9, IDX.minJumpSize, "minJumpSize should be 9");
    }

    @Test
    public void testLargerThanMinimumArrays() {
        // DSGEState should accept arrays larger than the minimum required size
        double[] states = new double[15];  // Larger than default 9
        double[] jumps = new double[15];   // Larger than default 10

        states[IDX.sW] = 0.05;
        states[IDX.piIdx] = 0.02;

        DSGEState dsgeState = new DSGEState(states, jumps);
        assertEquals(0.05, dsgeState.getWageDeviation(), 1e-10, "Should work with larger arrays");
        assertEquals(0.02, dsgeState.getInflationDeviation(), 1e-10, "Should work with larger arrays");
        assertEquals(15, dsgeState.getStateVector().length, "Should preserve actual array length");
    }
}
