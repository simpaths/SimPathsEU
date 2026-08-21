package simpaths.model.macro;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

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
