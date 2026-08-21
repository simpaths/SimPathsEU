package simpaths.model.macro;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;

import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Cross-validates the Java DSGE import against MATLAB's own impulse responses.
 *
 * <p>The export bundle has always shipped {@code irfs_eps_*.csv} — Dynare's one-standard-deviation
 * IRFs computed from the same policy matrices Java loads — but until 2026-08-18 nothing read them,
 * in production or in tests. They are the DSGE half's equivalent of the Ramsey parity fixture, and
 * they were free.</p>
 *
 * <p>Reproducing them end to end pins, in one assertion, every convention on the import path:
 * matrix loading (A, B_s, C, D), the state/jump split, row and column alignment against
 * {@code model_info.json}, the AR(1) shock processes carried inside the state transition, and above
 * all the σ-scaling asymmetry that {@code CLAUDE.md} names as the top pitfall — {@code eps_L} and
 * {@code eps_h} arrive already in percent and must NOT be scaled, while every other shock is in
 * σ-units and must be multiplied by its standard deviation. Both conventions are exercised here,
 * because the bundle ships IRFs for shocks on each side of the split. Dividing by σ instead of
 * multiplying, or treating {@code eps_L} like the others, fails this test immediately.</p>
 */
public class DSGEIrfParityTest {

    private static final String MODEL_PATH = "input" + java.io.File.separator + "PL"
            + java.io.File.separator + "MacroModel";

    /** Dynare writes ~15 significant digits; the recursion is short, so this is generous. */
    private static final double TOL = 1e-8;

    private static void assumeBundleAvailable() {
        Assumptions.assumeTrue(Files.exists(Paths.get(MODEL_PATH, "policy_A.csv"))
                && Files.exists(Paths.get(MODEL_PATH, "irfs_eps_L.csv")),
                "PL MacroModel bundle with exported IRFs required");
    }

    private record Irf(List<String> variables, List<double[]> rows) {}

    private static Irf loadIrf(Path csv) throws IOException {
        List<String> lines = Files.readAllLines(csv);
        String[] header = lines.get(0).split(",");
        List<String> vars = new ArrayList<>();
        for (int i = 1; i < header.length; i++) {
            vars.add(header[i].trim());
        }
        List<double[]> rows = new ArrayList<>();
        for (int i = 1; i < lines.size(); i++) {
            String line = lines.get(i).trim();
            if (line.isEmpty()) continue;
            String[] parts = line.split(",");
            double[] vals = new double[vars.size()];
            for (int j = 0; j < vars.size(); j++) {
                vals[j] = Double.parseDouble(parts[j + 1].trim());
            }
            rows.add(vals);
        }
        return new Irf(vars, rows);
    }

    /** Only the IRF columns DSGEState exposes by name; others are skipped, not silently passed. */
    private static Map<String, Function<DSGEState, Double>> accessors() {
        Map<String, Function<DSGEState, Double>> m = new LinkedHashMap<>();
        m.put("w", DSGEState::getWageDeviation);
        m.put("pi", DSGEState::getInflationDeviation);
        m.put("y", DSGEState::getOutputDeviation);
        m.put("n", DSGEState::getEmploymentDeviation);
        m.put("u_rate", DSGEState::getUnemploymentRateDeviation);
        m.put("h", DSGEState::getHoursDeviation);
        m.put("L", DSGEState::getLaborForceDeviation);
        m.put("R", DSGEState::getInterestRateDeviation);
        return m;
    }

    /**
     * Replays one shock through the loaded model and compares against MATLAB's IRF.
     *
     * @param sigmaUnits true for shocks the model scales by σ internally (pass 1.0 for a 1-σ IRF);
     *                   false for eps_L/eps_h, which arrive in percent (pass σ explicitly).
     */
    private void assertIrfMatches(String shockName, boolean sigmaUnits) throws IOException {
        assumeBundleAvailable();
        Path irfFile = Paths.get(MODEL_PATH, "irfs_" + shockName + ".csv");
        Assumptions.assumeTrue(Files.exists(irfFile), "no exported IRF for " + shockName);

        DSGEModel model = new DSGEModel();
        model.loadFromDirectory(MODEL_PATH);
        model.setLogEnabled(false);
        model.resetToSteadyState();

        int idx = -1;
        String[] names = model.getShockNames();
        for (int j = 0; j < names.length; j++) {
            if (names[j].equals(shockName)) { idx = j; break; }
        }
        assertTrue(idx >= 0, "shock " + shockName + " not found in the bundle");

        double sigma = model.getShockStdDev()[idx];
        assertTrue(sigma > 0, "shock " + shockName + " has a non-positive std dev");

        Irf expected = loadIrf(irfFile);
        Map<String, Function<DSGEState, Double>> acc = accessors();

        List<String> compared = new ArrayList<>();
        for (int period = 0; period < expected.rows().size(); period++) {
            double[] shocks = new double[model.getNumShocks()];
            if (period == 0) {
                // A 1-sigma impulse, expressed in whatever units this shock's channel expects.
                shocks[idx] = sigmaUnits ? 1.0 : sigma;
            }
            DSGEState state = model.stepQuarterly(shocks);

            for (int v = 0; v < expected.variables().size(); v++) {
                String var = expected.variables().get(v);
                Function<DSGEState, Double> get = acc.get(var);
                if (get == null) continue;
                if (period == 0) compared.add(var);

                double actual = get.apply(state);
                double want = expected.rows().get(period)[v];
                double scale = Math.max(1.0, Math.abs(want));
                assertEquals(want, actual, TOL * scale, String.format(
                        "%s IRF, variable %s, period %d: MATLAB=%.12g Java=%.12g",
                        shockName, var, period, want, actual));
            }
        }
        assertFalse(compared.isEmpty(),
                "no IRF column matched a DSGEState accessor; the test would be vacuous");
    }

    /**
     * eps_L is the SimPaths input channel: it arrives already in percent log-deviations and must
     * NOT be scaled by sigma inside the model. Passing sigma explicitly here must therefore
     * reproduce Dynare's 1-sigma IRF. If someone ever "fixes" eps_L to be sigma-scaled like the
     * others, this fails.
     */
    @Test
    public void testLaborForceShockIrfMatchesMatlab() throws IOException {
        assertIrfMatches("eps_L", false);
    }

    /** eps_h shares the SimPaths percent convention with eps_L. */
    @Test
    public void testHoursShockIrfMatchesMatlab() throws IOException {
        assertIrfMatches("eps_h", false);
    }

    /**
     * The other side of the split: eps_a is in sigma-units, so 1.0 means one standard deviation
     * and the model multiplies by sigma internally. It also has rho = 0.95, so this additionally
     * checks that the AR(1) process is carried inside the state transition rather than applied to
     * the shock input.
     */
    @Test
    public void testTechnologyShockIrfMatchesMatlab() throws IOException {
        assertIrfMatches("eps_a", true);
    }

    @Test
    public void testDemandShockIrfMatchesMatlab() throws IOException {
        assertIrfMatches("eps_d", true);
    }

    @Test
    public void testMonetaryShockIrfMatchesMatlab() throws IOException {
        assertIrfMatches("eps_r", true);
    }

    @Test
    public void testInvestmentShockIrfMatchesMatlab() throws IOException {
        assertIrfMatches("eps_inv", true);
    }

    /**
     * Guards the guard: the exported IRFs must actually be 1-sigma, not unit-innovation. Dynare's
     * impact response of L to eps_L is exactly sigma_L, so if a future export switched to raw
     * innovations every test above would still pass against the new file while the production
     * scaling silently changed meaning. This pins the file's own convention.
     */
    @Test
    public void testExportedIrfsAreOneStandardDeviation() throws IOException {
        assumeBundleAvailable();
        DSGEModel model = new DSGEModel();
        model.loadFromDirectory(MODEL_PATH);

        int idx = -1;
        String[] names = model.getShockNames();
        for (int j = 0; j < names.length; j++) {
            if (names[j].equals("eps_L")) { idx = j; break; }
        }
        double sigmaL = model.getShockStdDev()[idx];

        Irf irf = loadIrf(Paths.get(MODEL_PATH, "irfs_eps_L.csv"));
        int lCol = irf.variables().indexOf("L");
        assertTrue(lCol >= 0, "irfs_eps_L.csv should contain an L column");

        assertEquals(sigmaL, irf.rows().get(0)[lCol], 1e-9,
                "Impact response of L to eps_L must equal sigma_L, i.e. the exported IRFs are "
                + "1-sigma. If this fails the export switched to raw innovations and every "
                + "sigma-scaling assumption downstream needs re-checking.");
    }
}
