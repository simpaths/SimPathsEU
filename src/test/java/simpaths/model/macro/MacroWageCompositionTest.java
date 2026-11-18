package simpaths.model.macro;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * How the macro wage SimPaths applies is built from the planner's trend and the DSGE's cycle.
 *
 * <p>The trend wage {@code g} is a percent change of the hourly wage since the handoff quarter;
 * the cycle is a 100&times;log deviation of the hourly wage from that year's trend. The level
 * SimPaths applies is the trend's level times the cycle's factor,
 * {@code (1 + g/100) * exp(cycle/100)}, so a cycle keeps its size however far the trend has
 * moved. The DSGE's {@code w} is a wage per employee; its hourly cycle is {@code w - h}.</p>
 *
 * <p>Expected values come from the bundle's own impulse responses ({@code irfs_eps_*.csv},
 * period 0 is the quarter the shock hits), not from the code under test. Uses the Poland bundle;
 * skipped if absent.</p>
 */
class MacroWageCompositionTest {

    /** The shock hits the first quarter of this year; the DSGE is at its steady state before. */
    private static final int SHOCK_YEAR = MacroTestSupport.START_YEAR + 2;

    @TempDir
    Path tempDir;

    /**
     * With both layers, the wage is the trend's level times the cycle's factor: Ramsey+DSGE equals
     * {@code g + d (1 + g/100)}, where {@code g} is the Ramsey-only wage and {@code d} the
     * DSGE-only wage of the same year. Adding the two percentages breaks this by {@code g d / 100}.
     */
    @Test
    void testRamseyDsgeWageIsTheTrendTimesTheCycle() throws Exception {
        MacroTestSupport.assumePlBundle();
        MacroModelManager ramsey = MacroTestSupport.newManager(false, true);
        MacroModelManager dsge = MacroTestSupport.newManager(true, false);
        MacroModelManager both = MacroTestSupport.newManager(true, true);
        MacroTestSupport.MovableWorker a = new MacroTestSupport.MovableWorker();
        MacroTestSupport.MovableWorker b = new MacroTestSupport.MovableWorker();
        MacroTestSupport.MovableWorker c = new MacroTestSupport.MovableWorker();

        for (int year = MacroTestSupport.START_YEAR; year <= SHOCK_YEAR; year++) {
            MacroTestSupport.runYear(ramsey, year, a.asSet());
            MacroTestSupport.runYear(dsge, year, b.asSet());
            MacroTestSupport.runYear(both, year, c.asSet());
            if (year == MacroTestSupport.START_YEAR) {
                attachScenario(dsge, "eps_a");
                attachScenario(both, "eps_a");
            }
        }

        double g = ramsey.getWageDeviation();
        double d = dsge.getWageDeviation();
        assertTrue(g > 1.0 && Math.abs(d) > 0.1,
                "the test needs a sizeable trend and cycle, got g=" + g + ", d=" + d);
        assertEquals(g + d * (1.0 + g / 100.0), both.getWageDeviation(), 1e-9);
    }

    /**
     * DSGE-only, a technology shock (hours stay at zero): the wage is the percent form of the
     * year's mean 100&times;log cycle, {@code 100 (exp(cycle/100) - 1)}.
     */
    @Test
    void testDsgeOnlyWageIsThePercentFormOfTheCycle() throws Exception {
        assertDsgeOnlyWageMatchesTheHourlyIrf("eps_a");
    }

    /**
     * DSGE-only, an hours shock: SimPaths gets the hourly wage, {@code w - h}. The DSGE's
     * {@code w} is a wage per employee and rises slightly with hours, while the wage per hour
     * falls, so handing SimPaths {@code w} gets the sign wrong.
     */
    @Test
    void testHoursShockReachesSimPathsAsTheHourlyWage() throws Exception {
        assertTrue(annualHourlyWageFromIrf("eps_h") < 0.0, "an hours shock lowers the wage per hour");
        assertDsgeOnlyWageMatchesTheHourlyIrf("eps_h");
    }

    private void assertDsgeOnlyWageMatchesTheHourlyIrf(String shock) throws Exception {
        MacroTestSupport.assumePlBundle();
        MacroModelManager m = MacroTestSupport.newManager(true, false);
        MacroTestSupport.MovableWorker w = new MacroTestSupport.MovableWorker();
        for (int year = MacroTestSupport.START_YEAR; year <= SHOCK_YEAR; year++) {
            MacroTestSupport.runYear(m, year, w.asSet());
            if (year == MacroTestSupport.START_YEAR) {
                attachScenario(m, shock);
            }
        }
        assertEquals(annualHourlyWageFromIrf(shock), m.getWageDeviation(), 1e-8, shock);
    }

    /** A one-sigma {@code shock} in the first quarter of {@link #SHOCK_YEAR}, nothing else. */
    private void attachScenario(MacroModelManager m, String shock) throws Exception {
        Path csv = tempDir.resolve(shock + "_" + System.identityHashCode(m) + ".csv");
        Files.writeString(csv, "year,quarter," + shock + "\n" + SHOCK_YEAR + ",1,1.0\n");
        DSGEModel model = MacroTestSupport.getField(m, "dynamicDsgeModel", DSGEModel.class);
        DSGEShockScenario scenario = new DSGEShockScenario(model.getShockNames(), model.getNumShocks());
        scenario.loadFromFile(csv);
        MacroTestSupport.setField(m, "shockScenario", scenario);
    }

    /**
     * The hourly wage of the shock year in percent: the mean over IRF periods 0 to 3 of
     * {@code w - h} (100&times;log deviations), converted with {@code 100 (exp(x/100) - 1)}.
     */
    private static double annualHourlyWageFromIrf(String shock) throws IOException {
        List<String> lines = Files.readAllLines(Paths.get(MacroTestSupport.PL_MODEL_PATH, "irfs_" + shock + ".csv"));
        List<String> header = Arrays.asList(lines.get(0).trim().split(","));
        int wCol = header.indexOf("w");
        int hCol = header.indexOf("h");
        assertTrue(wCol >= 0 && hCol >= 0, "irfs_" + shock + ".csv needs w and h columns");
        double sum = 0.0;
        for (int period = 0; period < 4; period++) {
            String[] row = lines.get(1 + period).trim().split(",");
            sum += Double.parseDouble(row[wCol]) - Double.parseDouble(row[hCol]);
        }
        return 100.0 * Math.expm1(sum / 4.0 / 100.0);
    }
}
