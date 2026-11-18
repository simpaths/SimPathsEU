package simpaths.model.macro;

import java.io.File;
import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

import org.junit.jupiter.api.Assumptions;
import org.mockito.Mockito;

import simpaths.model.Person;
import simpaths.model.enums.Labour;

/**
 * Shared helpers for the macro tests that drive a {@link MacroModelManager} through the
 * schedule on the Poland bundle in {@code input/PL/MacroModel}.
 */
final class MacroTestSupport {

    static final String PL_MODEL_PATH = "input" + File.separator + "PL" + File.separator + "MacroModel";
    static final int START_YEAR = 2023;

    private MacroTestSupport() {
    }

    /** Skips the calling test when the Poland bundle is absent. */
    static void assumePlBundle() {
        Path macroDir = Paths.get(PL_MODEL_PATH);
        Assumptions.assumeTrue(Files.exists(macroDir.resolve("growth_terminal_state.json"))
                        && Files.exists(macroDir.resolve("population_projection_Poland.csv"))
                        && Files.exists(macroDir.resolve("policy_A.csv")),
                "The PL MacroModel bundle is required");
    }

    @SuppressWarnings("unchecked")
    static <T> T getField(Object target, String fieldName, Class<T> type) throws Exception {
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

    static void setField(Object target, String fieldName, Object value) throws Exception {
        Field field = target.getClass().getDeclaredField(fieldName);
        field.setAccessible(true);
        field.set(target, value);
    }

    /** An enabled manager in the given mode, path recording off, not yet initialised. */
    static MacroModelManager newManager(boolean useDsge, boolean useRamseyTrend) {
        MacroModelManager m = new MacroModelManager();
        m.setEnabled(true);
        m.setUseDsge(useDsge);
        m.setUseRamseyTrend(useRamseyTrend);
        m.setPathRecordingEnabled(false);
        return m;
    }

    /**
     * Replays the schedule of one year: the macro update before the labour market
     * ({@code DSGEMacroUpdate}); from {@code START_YEAR + 1} on, the post-labour-market latch
     * (a no-op after the first); then the end-of-year capture ({@code MacroEndYearCapture}).
     */
    static void runYear(MacroModelManager m, int year, Set<Person> persons) {
        m.updateEquilibrium(year, START_YEAR, "PL", persons, Collections.emptySet(), false);
        if (year > START_YEAR) {
            m.latchStartYearAnchorsPostLabourMarket(year, persons);
        }
        m.updateLevelAggregatesPostAlignment(year, persons);
        m.applyRamseyRecursiveFeedback(year, persons);
    }

    /**
     * One at-risk worker whose weight can be moved between years, so the aggregated labour
     * force can be made to follow (or ignore) the projection exactly.
     */
    static final class MovableWorker {
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
}
