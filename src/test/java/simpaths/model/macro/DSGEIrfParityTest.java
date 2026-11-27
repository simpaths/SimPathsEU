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
 * <p>The export bundle ships {@code irfs_eps_*.csv} — Dynare's one-standard-deviation IRFs
 * computed from the same policy matrices Java loads. Production does not read them; this test
 * does. They are the DSGE half's equivalent of the Ramsey parity fixture, at no extra export
 * cost.</p>
 *
 * <p>Reproducing them end to end pins, in one assertion, every convention on the import path:
 * matrix loading (A, B_s, C, D), the state/jump split, row and column alignment against
 * {@code model_info.json}, the AR(1) shock processes carried inside the state transition, and the
 * σ-scaling: every shock is scaled by its standard deviation, so an input of 1.0 is a one-σ
 * innovation. Dividing by σ instead of multiplying fails this test immediately.</p>
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

    /** Replays one 1-σ shock through the loaded model and compares against MATLAB's IRF. */
    private void assertIrfMatches(String shockName) throws IOException {
        assumeBundleAvailable();
        Assumptions.assumeTrue(Files.exists(Paths.get(MODEL_PATH, "irfs_" + shockName + ".csv")),
                "no exported IRF for " + shockName);
        assertIrfMatches(MODEL_PATH, shockName);
    }

    /** The replay itself, for any bundle folder; CommittedBundlesTest runs it on every committed bundle. */
    static void assertIrfMatches(String modelPath, String shockName) throws IOException {
        Path irfFile = Paths.get(modelPath, "irfs_" + shockName + ".csv");
        assertTrue(Files.exists(irfFile), "no exported IRF for " + shockName + " in " + modelPath);

        DSGEModel model = new DSGEModel();
        model.loadFromDirectory(modelPath);
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
                shocks[idx] = 1.0;   // a 1-sigma impulse: every shock is in standard-deviation units
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
                        "%s: %s IRF, variable %s, period %d: MATLAB=%.12g Java=%.12g",
                        modelPath, shockName, var, period, want, actual));
            }
        }
        assertFalse(compared.isEmpty(),
                "no IRF column matched a DSGEState accessor; the test would be vacuous");
    }

    /**
     * eps_L is an ordinary shock: 1.0 is one standard deviation, and the labour force follows
     * its AR(1) at the calibrated rho_L, carried inside the state transition.
     */
    @Test
    public void testLaborForceShockIrfMatchesMatlab() throws IOException {
        assertIrfMatches("eps_L");
    }

    /** eps_h likewise, at the calibrated rho_h. */
    @Test
    public void testHoursShockIrfMatchesMatlab() throws IOException {
        assertIrfMatches("eps_h");
    }

    /**
     * eps_a is in sigma-units, so 1.0 means one standard deviation and the model multiplies by
     * sigma internally. It also has rho = 0.95, so this additionally checks that the AR(1)
     * process is carried inside the state transition rather than applied to the shock input.
     */
    @Test
    public void testTechnologyShockIrfMatchesMatlab() throws IOException {
        assertIrfMatches("eps_a");
    }

    @Test
    public void testDemandShockIrfMatchesMatlab() throws IOException {
        assertIrfMatches("eps_d");
    }

    @Test
    public void testMonetaryShockIrfMatchesMatlab() throws IOException {
        assertIrfMatches("eps_r");
    }

    @Test
    public void testInvestmentShockIrfMatchesMatlab() throws IOException {
        assertIrfMatches("eps_inv");
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
