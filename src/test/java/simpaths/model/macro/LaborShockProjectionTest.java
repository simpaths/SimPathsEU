package simpaths.model.macro;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import simpaths.model.Person;
import simpaths.model.enums.Labour;
import simpaths.model.enums.MacroFeedbackMargins;

/**
 * The DSGE's labour-force shock is measured net of the demographic projection that both
 * macro layers share (simpaths/SimPathsEU#216; JuergenWiemers/SimPathsEU#26).
 *
 * <p>In estimation the observable {@code L} is the labour-force level against its demographic
 * trend ({@code detrended.L = 100 (ln L - ln L_demo)} in {@code ramsey_trend.m}). At runtime the
 * aggregator's year-over-year change of the headcount carried the whole projected decline of
 * the working-age population (about -0.85%/yr for Poland against -0.89%/yr projected, measured
 * 2026-10-20), a standing shock the model was never estimated to see and one the Ramsey layer
 * already prices. The manager therefore hands the aggregator the projection's own annual
 * growth, and the shock becomes the year-over-year change of the employment rate.</p>
 *
 * <p>Uses the Poland bundle in {@code input/PL/MacroModel}; skipped if it is absent.</p>
 */
class LaborShockProjectionTest {

    private static final String PL_MODEL_PATH = "input" + java.io.File.separator + "PL"
            + java.io.File.separator + "MacroModel";
    private static final int START_YEAR = 2023;

    private static void assumeBundleAvailable() {
        Path macroDir = Paths.get(PL_MODEL_PATH);
        Assumptions.assumeTrue(Files.exists(macroDir.resolve("growth_terminal_state.json"))
                        && Files.exists(macroDir.resolve("population_projection_Poland.csv"))
                        && Files.exists(macroDir.resolve("policy_A.csv")),
                "The PL MacroModel bundle is required for LaborShockProjectionTest");
    }

    @SuppressWarnings("unchecked")
    private static <T> T getField(Object target, String fieldName, Class<T> type) throws Exception {
        Field field = target.getClass().getDeclaredField(fieldName);
        field.setAccessible(true);
        if (type == Double.class) {
            return (T) Double.valueOf(field.getDouble(target));
        }
        if (type == Integer.class) {
            return (T) Integer.valueOf(field.getInt(target));
        }
        return type.cast(field.get(target));
    }

    private static void setField(Object target, String fieldName, Object value) throws Exception {
        Field field = target.getClass().getDeclaredField(fieldName);
        field.setAccessible(true);
        field.set(target, value);
    }

    private static void initialize(MacroModelManager m, Set<Person> persons) throws Exception {
        Method initialize = MacroModelManager.class.getDeclaredMethod("initialize", String.class, Set.class);
        initialize.setAccessible(true);
        initialize.invoke(m, "PL", persons);
    }

    /** Ramsey trend only, feedback off: the retained original projection is {@code ramseyProjN}. */
    private static MacroModelManager newRamseyOnlyManager() throws Exception {
        assumeBundleAvailable();
        MacroModelManager m = new MacroModelManager();
        m.setEnabled(true);
        m.setUseDsge(false);
        m.setUseRamseyTrend(true);
        m.setPathRecordingEnabled(false);
        m.setRamseyFeedbackMargins(MacroFeedbackMargins.NONE);
        setField(m, "simulationStartYear", START_YEAR);
        m.initializeRamseyTrend(PL_MODEL_PATH);
        return m;
    }

    /** Mean of the 4 quarters of calendar year {@code year} in the retained original projection. */
    private static double assumedMeanN(MacroModelManager m, int year) throws Exception {
        double[] projN = getField(m, "ramseyProjN", double[].class);
        int q0 = 4 * (year - START_YEAR);
        return (projN[q0] + projN[q0 + 1] + projN[q0 + 2] + projN[q0 + 3]) / 4.0;
    }

    /**
     * One at-risk worker whose weight can be moved between years, so the aggregated labour
     * force can be made to follow (or ignore) the projection exactly.
     */
    private static final class MovableWorker {
        final double[] weight = {1.0};
        final Person person;

        MovableWorker() {
            person = Mockito.mock(Person.class);
            Mockito.when(person.getWeight()).thenAnswer(inv -> weight[0]);
            Mockito.when(person.getDag()).thenReturn(40);
            Mockito.when(person.atRiskOfWork()).thenReturn(true);
            Mockito.when(person.getLabourSupplyWeekly()).thenReturn(Labour.ZERO);
            Mockito.when(person.getLabourSupplyHoursWeekly()).thenReturn(40);
        }

        Set<Person> asSet() {
            return new HashSet<>(Collections.singleton(person));
        }
    }

    @Test
    void testProjectedLabourGrowthIsTheLogChangeOfTheRetainedProjectionsAnnualMeans() throws Exception {
        MacroModelManager m = newRamseyOnlyManager();
        double expected = 100.0 * Math.log(assumedMeanN(m, 2026) / assumedMeanN(m, 2025));
        assertEquals(expected, m.projectedLaborGrowthPct(2026), 1e-12);
        assertTrue(Math.abs(expected) > 0.05, "the Poland projection moves by more than 0.05% a year, so the test is not vacuous");
    }

    /**
     * {@code mm_macroModel: dsge} runs no Ramsey trend, but the shock still needs the
     * projection (never re-derive what the bundle carries; fail if it is missing).
     */
    @Test
    void testDsgeOnlyModeLoadsTheProjectionForTheLabourShock() throws Exception {
        MacroModelManager ramsey = newRamseyOnlyManager();

        MacroModelManager dsgeOnly = new MacroModelManager();
        dsgeOnly.setEnabled(true);
        dsgeOnly.setUseDsge(true);
        dsgeOnly.setUseRamseyTrend(false);
        dsgeOnly.setPathRecordingEnabled(false);
        dsgeOnly.setRamseyFeedbackMargins(MacroFeedbackMargins.NONE);
        setField(dsgeOnly, "simulationStartYear", START_YEAR);
        initialize(dsgeOnly, new MovableWorker().asSet());

        assertEquals(ramsey.projectedLaborGrowthPct(2026), dsgeOnly.projectedLaborGrowthPct(2026), 1e-12);
    }

    /**
     * End to end through {@code updateEquilibrium}: a workforce that follows the projection
     * exactly hands the DSGE a zero shock, both in the first feedback year (the snapshot roll)
     * and in the first live year; a flat workforce hands it minus the projection's growth.
     */
    @Test
    void testWorkersFollowingTheProjectionGiveTheDsgeNoShock() throws Exception {
        assumeBundleAvailable();
        double followSum = runThreeYears(true);
        assertEquals(0.0, followSum, 1e-9, "following the projection exactly is no shock");

        MacroModelManager reference = newRamseyOnlyManager();
        double flatSum = runThreeYears(false);
        assertEquals(-reference.projectedLaborGrowthPct(START_YEAR + 3), flatSum, 1e-9,
                "a flat workforce against a moving projection is minus the projection's growth");
    }

    /**
     * Runs startYear..startYear+3 with the DSGE and the Ramsey trend on, the feedback off, and
     * returns the sum of the labour-force shocks handed to the DSGE (the diagnostics sum over
     * the two years in which a shock is formed: the roll year and the first live year).
     *
     * <p>Replays the schedule's calls in order: the macro update before the labour market,
     * then after it the one-time baseline latch and, every year, the post-labour-market
     * diagnostics ({@code logLaborSupplyDiagnostics}, which the schedule calls whenever
     * {@code mm_macroLogging} is on). Those diagnostics must not consume the snapshot roll:
     * in the first paired run after the fix they did, and the 2025 shock came out at -1.7
     * instead of 0.</p>
     */
    private static double runThreeYears(boolean followProjection) throws Exception {
        MacroModelManager m = new MacroModelManager();
        m.setEnabled(true);
        m.setUseDsge(true);
        m.setUseRamseyTrend(true);
        m.setPathRecordingEnabled(false);
        m.setRamseyFeedbackMargins(MacroFeedbackMargins.NONE);
        m.setLogMacroState(true);                 // the shock diagnostics are only kept when logging is on
        setField(m, "simulationStartYear", START_YEAR);

        MovableWorker w = new MovableWorker();
        for (int year = START_YEAR; year <= START_YEAR + 3; year++) {
            if (year > START_YEAR) {
                double meanN = assumedMeanN(m, year);
                w.weight[0] = followProjection ? meanN / 1000.0 : 1.0;
            }
            m.updateEquilibrium(year, START_YEAR, "PL", w.asSet(), Collections.emptySet(), false);
            if (year > START_YEAR) {                                    // the labour market runs from startYear+1
                m.latchBaselineFromPostLaborMarket(year, w.asSet());   // latches once, no-op afterwards
                m.logLaborSupplyDiagnostics(year, w.asSet(), "post-labour-market");
            }
        }
        assertEquals(2, (int) getField(m, "diagnosticsCount", Integer.class),
                "shocks are formed in startYear+2 (roll) and startYear+3 (live)");
        return getField(m, "epsLSum", Double.class);
    }
}
