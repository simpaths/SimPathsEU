package simpaths.model.macro;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Collections;
import java.util.Set;

import org.junit.jupiter.api.Test;

import simpaths.model.Person;

/**
 * The DSGE takes no input from SimPaths (contract 38): its annual step sees the scenario's
 * shocks only, so without a scenario its cycle wage is zero whatever SimPaths' workers do, and
 * a Ramsey+DSGE run has the Ramsey-only wage index year by year.
 *
 * <p>Each test drives the manager through the schedule ({@link MacroTestSupport#runYear}) on
 * one worker whose weight moves between years. Uses the Poland bundle; skipped if absent.</p>
 */
class DsgeOneWayTest {

    private static final double[] WEIGHTS = {1.00, 1.00, 1.03, 0.97, 1.05};

    @Test
    void testRamseyDsgeWageEqualsRamseyOnlyWithoutScenario() throws Exception {
        MacroTestSupport.assumePlBundle();
        MacroModelManager ramsey = MacroTestSupport.newManager(false, true);
        MacroModelManager both = MacroTestSupport.newManager(true, true);
        MacroTestSupport.MovableWorker a = new MacroTestSupport.MovableWorker();
        MacroTestSupport.MovableWorker b = new MacroTestSupport.MovableWorker();
        for (int i = 0; i < WEIGHTS.length; i++) {
            int year = MacroTestSupport.START_YEAR + i;
            a.weight[0] = WEIGHTS[i];
            b.weight[0] = WEIGHTS[i];
            MacroTestSupport.runYear(ramsey, year, a.asSet());
            MacroTestSupport.runYear(both, year, b.asSet());
            assertEquals(ramsey.getWageDeviation(), both.getWageDeviation(), 0.0, "wage index, year " + year);
            assertEquals(both.getCapitalDeepeningWageAdjustment(), both.getWageDeviation(), 0.0, "cycle wage, year " + year);
            DSGEModel dsge = MacroTestSupport.getField(both, "dynamicDsgeModel", DSGEModel.class);
            for (double s : dsge.getState()) assertEquals(0.0, s, 0.0, "DSGE state, year " + year);
        }
    }

    @Test
    void testDsgeOnlyCycleIsZeroWhateverTheWorkersDo() throws Exception {
        MacroTestSupport.assumePlBundle();
        MacroModelManager m = MacroTestSupport.newManager(true, false);
        MacroTestSupport.MovableWorker w = new MacroTestSupport.MovableWorker();
        for (int i = 0; i < WEIGHTS.length; i++) {
            w.weight[0] = WEIGHTS[i];
            MacroTestSupport.runYear(m, MacroTestSupport.START_YEAR + i, w.asSet());
            assertEquals(0.0, m.getWageDeviation(), 0.0);
        }
        assertNull(MacroTestSupport.getField(m, "ramseyProjN", double[].class),
                "DSGE-only mode does not load the population projection");
    }

    /**
     * A planner year whose previous end-of-year feedback did not run stops the run: advancing
     * the trend on a path that ignores a year of SimPaths' labour supply would be a silent
     * fallback.
     */
    @Test
    void testPlannerYearWithoutThePreviousYearsFeedbackFails() throws Exception {
        MacroTestSupport.assumePlBundle();
        MacroModelManager m = MacroTestSupport.newManager(false, true);
        MacroTestSupport.MovableWorker w = new MacroTestSupport.MovableWorker();
        int y0 = MacroTestSupport.START_YEAR;
        MacroTestSupport.runYear(m, y0, w.asSet());
        MacroTestSupport.runYear(m, y0 + 1, w.asSet());
        m.updateEquilibrium(y0 + 2, y0, "PL", w.asSet(), Collections.emptySet(), false);   // feedback of y0+1 ran
        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> m.updateEquilibrium(y0 + 3, y0, "PL", w.asSet(), Collections.emptySet(), false));
        assertTrue(ex.getMessage().contains("MacroEndYearCapture") && ex.getMessage().contains(String.valueOf(y0 + 2)),
                ex.getMessage());
    }

    @Test
    void testDsgeOnlyRefusesAStartYearOffTheBundlesHandoff() {
        MacroTestSupport.assumePlBundle();
        MacroModelManager m = new MacroModelManager();
        m.setEnabled(true); m.setUseDsge(true); m.setUseRamseyTrend(false); m.setPathRecordingEnabled(false);
        Set<Person> persons = new MacroTestSupport.MovableWorker().asSet();
        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> m.updateEquilibrium(2024, 2024, "PL", persons, Collections.emptySet(), false));
        assertTrue((ex + " " + ex.getCause()).contains("handoff"), ex.toString());
    }
}
