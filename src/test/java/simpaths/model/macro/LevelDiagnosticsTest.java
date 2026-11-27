package simpaths.model.macro;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Collections;
import java.util.Map;
import java.util.Set;

import org.junit.jupiter.api.Test;

import simpaths.model.Person;

/**
 * When the level columns of MacroPaths.csv appear. {@code participation_rate},
 * {@code workers_over_atRiskPool} and {@code l_level} are emitted only once the labour
 * market has run and the post-market latch has fired (from {@code startYear + 1}'s latch on);
 * {@code compare_scenarios.do} anchors on their first non-zero value, so the timing must not
 * move. Every pass shares {@code demographicIndexUpdates}; this drives the Ramsey-only pass.
 * Uses the Poland bundle; skipped if absent.
 */
class LevelDiagnosticsTest {

    @SuppressWarnings("unchecked")
    private static Map<String, Double> trends(MacroModelManager m) throws Exception {
        return MacroTestSupport.getField(m, "currentRamseyTrends", Map.class);
    }

    private static void endOfYear(MacroModelManager m, int year, Set<Person> persons, boolean latch) {
        if (latch) {
            m.latchStartYearAnchorsPostLabourMarket(year, persons);
        }
        m.updateLevelAggregatesPostAlignment(year, persons);
        m.applyRamseyRecursiveFeedback(year, persons);
    }

    @Test
    void testLevelDiagnosticsAppearOnlyAfterThePostMarketLatch() throws Exception {
        MacroTestSupport.assumePlBundle();
        MacroModelManager m = MacroTestSupport.newManager(false, true);
        MacroTestSupport.MovableWorker w = new MacroTestSupport.MovableWorker();
        int y0 = MacroTestSupport.START_YEAR;

        m.updateEquilibrium(y0, y0, "PL", w.asSet(), Collections.emptySet(), false);
        assertFalse(trends(m).containsKey("participation_rate"), "start year: no labour market yet");
        assertFalse(trends(m).containsKey("l_level"));
        endOfYear(m, y0, w.asSet(), false);

        m.updateEquilibrium(y0 + 1, y0, "PL", w.asSet(), Collections.emptySet(), false);
        assertFalse(trends(m).containsKey("participation_rate"), "y1 before the labour market");
        endOfYear(m, y0 + 1, w.asSet(), true);                // the labour market of y1 has run: latch

        w.weight[0] = 1.10;
        m.updateEquilibrium(y0 + 2, y0, "PL", w.asSet(), Collections.emptySet(), false);
        assertEquals(10.0, trends(m).get("l_level"), 1e-9);
        assertTrue(trends(m).containsKey("participation_rate"));
    }
}
