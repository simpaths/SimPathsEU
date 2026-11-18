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
 * Unit tests for LaborSupplyAggregator: the start-year anchors latch once, and the
 * aggregate records carry what the level diagnostics and the planner's feedback read.
 */
class LaborSupplyAggregatorTest {
    
    private LaborSupplyAggregator aggregator;
    
    @BeforeEach
    void setUp() {
        aggregator = new LaborSupplyAggregator();
    }

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
     * The post-labour-market latch fixes the start-year L/h anchors of the level diagnostics
     * once; a later call with another population does not move them.
     */
    @Test
    void testStartYearAnchorsLatchOnce() {
        Set<Person> firstPopulation = persons(worker(1.0, 40), worker(1.0, 40));
        Set<Person> differentPopulation = persons(worker(2.0, 30), worker(1.0, 20));

        assertFalse(aggregator.isStartYearLatched());
        aggregator.latchStartYearAnchors(firstPopulation);
        assertTrue(aggregator.isStartYearLatched());
        double l0 = aggregator.getStartYearL();
        double h0 = aggregator.getStartYearH();
        aggregator.latchStartYearAnchors(differentPopulation);
        assertEquals(l0, aggregator.getStartYearL(), 0.0);
        assertEquals(h0, aggregator.getStartYearH(), 0.0);
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
}
