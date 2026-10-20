package simpaths.model.macro;

import java.util.HashSet;
import java.util.Set;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import simpaths.model.Person;
import simpaths.model.enums.Labour;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for LaborSupplyAggregator.
 * 
 * Tests cover:
 * - Baseline computation
 * - Shock calculation (eps_L, eps_h)
 * - Mathematical properties of log-deviation shocks
 * 
 * Note: Tests for aggregate() with Person objects require integration tests
 * due to the complexity of mocking Person with all its dependencies.
 */
class LaborSupplyAggregatorTest {
    
    private LaborSupplyAggregator aggregator;
    
    @BeforeEach
    void setUp() {
        aggregator = new LaborSupplyAggregator();
    }
    
    @Test
    void testInitialStateNotBaselineSet() {
        assertFalse(aggregator.isBaselineSet(), "Baseline should not be set initially");
    }

    // ========== Snapshot timing and the assumed labour growth ==========

    /**
     * A working-age person at risk of work. {@code computeRawAggregates} only calls
     * getWeight, getDag, atRiskOfWork, getLabourSupplyWeekly and getLabourSupplyHoursWeekly,
     * so a mock is enough (see RamseyRecursiveFeedbackTest.buildSyntheticPersons).
     */
    private static Person worker(double weight, int hoursWeekly) {
        Person p = Mockito.mock(Person.class);
        Mockito.when(p.getWeight()).thenReturn(weight);
        Mockito.when(p.getDag()).thenReturn(40);
        Mockito.when(p.atRiskOfWork()).thenReturn(true);
        Mockito.when(p.getLabourSupplyWeekly()).thenReturn(Labour.ZERO);
        Mockito.when(p.getLabourSupplyHoursWeekly()).thenReturn(hoursWeekly);
        return p;
    }

    private static Set<Person> persons(Person... ps) {
        return new HashSet<>(java.util.List.of(ps));
    }

    /**
     * CONTRACT: the baseline latched after the first labour market (startYear+1) is a
     * post-labour-market snapshot, but every later aggregate() is taken before the year's
     * labour market. The first aggregate() after that latch therefore compares two different
     * snapshots of the same year's turnover (retirements, deaths, entrants without hours) and
     * must not be reported as a labour-supply shock: it returns zero shocks and becomes the
     * new, pre-labour-market baseline. From the next year on both snapshots are of the same
     * kind and the shock is live.
     */
    @Test
    void testFirstAggregateAfterPostLabourMarketLatchReportsNoShockAndRollsBaseline() {
        Set<Person> postLabourMarket = persons(worker(1.0, 40), worker(1.0, 40), worker(1.0, 40));
        Set<Person> preLabourMarketNextYear = persons(worker(1.0, 40), worker(1.0, 40), worker(1.0, 0));
        Set<Person> preLabourMarketYearAfter = persons(worker(1.0, 40), worker(1.0, 40), worker(1.0, 40), worker(1.0, 40));

        aggregator.computeAndSetBaseline(postLabourMarket);                  // startYear+1, after the labour market
        LaborSupplyAggregator.LaborSupplyShocks first = aggregator.aggregate(preLabourMarketNextYear);  // startYear+2, before it

        assertEquals(0.0, first.epsL(), 1e-12, "mixed snapshots: no labour-force shock");
        assertEquals(0.0, first.epsH(), 1e-12, "mixed snapshots: no hours shock");
        assertEquals(2.0, first.aggregates().laborForce(), 1e-12, "the aggregates themselves are still reported");

        aggregator.advanceBaseline();
        assertEquals(2.0, aggregator.getBaselineL(), 1e-12, "the pre-labour-market snapshot is the new baseline");

        LaborSupplyAggregator.LaborSupplyShocks second = aggregator.aggregate(preLabourMarketYearAfter);
        assertEquals(100.0 * Math.log(4.0 / 2.0), second.epsL(), 1e-9,
                "from the second pre-labour-market snapshot on, the shock is the year-over-year change");
    }

    /**
     * CONTRACT: the DSGE was estimated on the labour force net of its demographic trend, so
     * the shock handed to it is the year-over-year change net of the assumed labour growth of
     * the projection both macro layers share: eps_L = 100 ln(L_t/L_{t-1}) - g_assumed. A
     * workforce that shrinks exactly as projected is no shock.
     */
    @Test
    void testShockIsMeasuredNetOfTheAssumedLabourGrowth() {
        aggregator.setBaseline(1.0, 40.0);
        Set<Person> shrunkAsProjected = persons(worker(0.99, 40));
        double assumedGrowthPct = 100.0 * Math.log(0.99);

        LaborSupplyAggregator.LaborSupplyShocks net = aggregator.aggregate(shrunkAsProjected, assumedGrowthPct);
        assertEquals(0.0, net.epsL(), 1e-9, "shrinking as projected is no shock");

        LaborSupplyAggregator.LaborSupplyShocks raw = aggregator.aggregate(shrunkAsProjected);
        assertEquals(100.0 * Math.log(0.99), raw.epsL(), 1e-9, "without an assumed growth the raw change is reported");
        assertEquals(net.epsH(), raw.epsH(), 1e-12, "hours are not detrended");
    }
    
    @Test
    void testSetBaseline() {
        aggregator.setBaseline(1000.0, 40.0);
        
        assertTrue(aggregator.isBaselineSet(), "Baseline should be set after setBaseline");
        assertEquals(1000.0, aggregator.getBaselineL(), 1e-10);
        assertEquals(40.0, aggregator.getBaselineH(), 1e-10);
    }
    
    @Test
    void testSetBaselineWithDifferentValues() {
        aggregator.setBaseline(5000.0, 35.5);
        
        assertEquals(5000.0, aggregator.getBaselineL(), 1e-10);
        assertEquals(35.5, aggregator.getBaselineH(), 1e-10);
    }
    
    @Test
    void testBaselineCanBeUpdated() {
        aggregator.setBaseline(1000.0, 40.0);
        aggregator.setBaseline(2000.0, 38.0);
        
        assertEquals(2000.0, aggregator.getBaselineL(), 1e-10);
        assertEquals(38.0, aggregator.getBaselineH(), 1e-10);
    }
    
    @Test
    void testShockCalculationLogDeviation() {
        // Test the mathematical formula: eps = ln(current / baseline)
        // For 10% increase: eps = ln(1.1) ≈ 0.0953
        double baseline = 1000.0;
        double current = 1100.0;  // 10% increase
        
        double expectedShock = Math.log(current / baseline);
        
        assertEquals(0.0953, expectedShock, 0.0001, 
            "Log deviation for 10% increase should be ~0.0953");
    }
    
    @Test
    void testShockCalculationSymmetry() {
        // Log deviations are approximately symmetric for small changes
        // but not perfectly symmetric for large changes
        double baseline = 1000.0;
        double increase = Math.log(1100.0 / baseline);  // +10%
        double decrease = Math.log(900.0 / baseline);   // -10%
        
        // For 10% changes, asymmetry is small but present
        assertTrue(Math.abs(increase + decrease) < 0.02, 
            "Log deviations should be approximately symmetric");
    }
    
    @Test
    void testShockCalculationZeroAtBaseline() {
        // At baseline, shock should be exactly zero
        double baseline = 1000.0;
        double shock = Math.log(baseline / baseline);
        
        assertEquals(0.0, shock, 1e-10, "Shock at baseline should be zero");
    }
    
    @Test
    void testShockCalculationPositiveForIncrease() {
        LaborSupplyAggregator agg = new LaborSupplyAggregator();
        double shock = agg.computeLogDeviation(1050.0, 1000.0);  // 5% increase

        assertTrue(shock > 0, "Shock should be positive for increase");
    }

    @Test
    void testShockCalculationNegativeForDecrease() {
        LaborSupplyAggregator agg = new LaborSupplyAggregator();
        double shock = agg.computeLogDeviation(950.0, 1000.0);  // 5% decrease

        assertTrue(shock < 0, "Shock should be negative for decrease");
    }

    @Test
    void testShocksAreInPercentLogDeviationUnits() {
        // The exported policy matrices are estimated on PERCENT-unit data
        // (ramsey_trend.m writes observables as 100*log-deviations; sigma_L = 0.783
        // means 0.78%). eps_L/eps_h must therefore be handed to the DSGE as
        // 100*ln(current/baseline) — a raw ln fraction (0.05 for a 5% change)
        // would enter the model as a 0.05% shock, attenuating the entire
        // SimPaths->DSGE cyclical channel by a factor of ~100.
        LaborSupplyAggregator agg = new LaborSupplyAggregator();

        double eps = agg.computeLogDeviation(1050.0, 1000.0);
        assertEquals(100.0 * Math.log(1.05), eps, 1e-10,
            "A 5% labor-force increase must arrive as ~+4.879 (percent log-dev), not 0.04879");

        double epsDown = agg.computeLogDeviation(992.0, 1000.0);
        assertEquals(100.0 * Math.log(0.992), epsDown, 1e-10,
            "A -0.8% change must arrive as ~-0.803 (percent log-dev)");
    }

    @Test
    void testShockCapIsInPercentUnits() {
        // The collapse cap (current <= 0) must scale with the unit convention:
        // -5.0 in ln units corresponds to -500 in percent log-dev units.
        LaborSupplyAggregator agg = new LaborSupplyAggregator();
        double eps = agg.computeLogDeviation(0.0, 1000.0);
        assertEquals(-500.0, eps, 1e-10, "Collapse cap should be -500 percent log-dev");
    }
    
    @Test
    void testLaborSupplyAggregatesRecord() {
        // Test the LaborSupplyAggregates record
        // Record has: laborForce, avgHoursPerWorker, totalHours, workingAgePopulation, participationRate, atRiskPool, totalPopulation
        // laborForce = extensive margin (persons with positive hours)
        // atRiskPool = non-student, non-retired 15-64 (enters labor supply model)
        LaborSupplyAggregator.LaborSupplyAggregates agg = 
            new LaborSupplyAggregator.LaborSupplyAggregates(1000.0, 40.0, 40000.0, 1500, 0.67, 1200, 5000);
        
        assertEquals(1000.0, agg.laborForce());
        assertEquals(40.0, agg.avgHoursPerWorker());
        assertEquals(40000.0, agg.totalHours());
        assertEquals(1500, agg.workingAgePopulation());
        assertEquals(0.67, agg.participationRate());
        assertEquals(1200, agg.atRiskPool());
        assertEquals(5000, agg.totalPopulation());
    }
    
    @Test
    void testLaborSupplyShocksRecord() {
        // Test the LaborSupplyShocks record
        LaborSupplyAggregator.LaborSupplyAggregates agg = 
            new LaborSupplyAggregator.LaborSupplyAggregates(1000.0, 40.0, 40000.0, 1500, 0.67, 1200, 5000);
        
        LaborSupplyAggregator.LaborSupplyShocks shocks = 
            new LaborSupplyAggregator.LaborSupplyShocks(0.05, 0.02, agg);
        
        assertEquals(0.05, shocks.epsL());
        assertEquals(0.02, shocks.epsH());
        assertNotNull(shocks.aggregates());
        assertEquals(1000.0, shocks.aggregates().laborForce());
    }
}
