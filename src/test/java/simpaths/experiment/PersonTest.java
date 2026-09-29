package simpaths.experiment;

import simpaths.data.ManagerRegressions;
import simpaths.data.Parameters;
import simpaths.data.RegressionName;
import simpaths.model.BenefitUnit;
import simpaths.model.Person;
import simpaths.model.SimPathsModel;
import simpaths.model.enums.Dcpst;
import simpaths.model.enums.Education;
import simpaths.model.enums.EducationLevel;
import simpaths.model.enums.Indicator;
import simpaths.model.enums.Gender;
import simpaths.model.enums.Les_c4;
import simpaths.model.enums.TimeSeriesVariable;
import simpaths.model.Innovations;

import microsim.statistics.regression.BinomialRegression;
import microsim.statistics.regression.GeneralisedOrderedRegression;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Nested; // Added: For nested test structure
import org.junit.jupiter.api.DisplayName; // Added: For descriptive names
import org.mockito.MockedStatic;
import org.mockito.Mockito;

import java.lang.reflect.Field;
import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Disabled;



/**
 * Unit tests for the Person class, focusing on education transitions.
 * This test uses Mockito to isolate Person from its complex dependencies
 * (SimPathsModel, Parameters, Innovations).
 */
// /*: PersonTest may be disabled to build Maven education module development*/
//@Disabled("Temporarily disabled due to Jasmine core update")
public class PersonTest {

    // Static mock reference for Parameters
    private MockedStatic<Parameters> parametersMock;
    private MockedStatic<ManagerRegressions> managerRegressionsMock;


    private Person testPerson;

    // --- Mocks for Dependencies ---
    private SimPathsModel mockModel;
    private Innovations mockInnovations;
    private BenefitUnit mockBenefitUnit;

    // Using the actual regression types for strong type checking and accuracy
    private BinomialRegression mockBinomialRegression;
    private GeneralisedOrderedRegression<EducationLevel> mockGeneralisedOrderedRegression;

    // --- Critical Constructor Mocking Helper ---

    /**
     * Helper to mock static dependencies that are called inside the Person constructor,
     * specifically to prevent the NullPointerException related to Parameter initialization.
     */
    private void mockStaticDependenciesForConstructor(Runnable action) {
        // Mock the multivariate distribution needed by Person constructor's setMarriageTargets()
        double[] mockWageAgeValues = new double[]{0.0, 0.0};

        // Using explicit lambda call for robust static stubbing
        parametersMock.when(() -> Parameters.getWageAndAgeDifferentialMultivariateNormalDistribution(Mockito.anyLong()))
                .thenReturn(mockWageAgeValues);

        // Execute the rest of the setup (including new Person() and field injection)
            action.run();
    }


    // Reflection utility to set final/private fields for test isolation
    private void setPrivateField(Object target, String fieldName, Object value) throws Exception {
        Field field = target.getClass().getDeclaredField(fieldName);
        field.setAccessible(true);
        field.set(target, value);
    }

    /**
     * Helper method to configure the regression mock for setEducationLevel().
     */
    private void setupEducationLevelRegressionMock(EducationLevel expectedEducationLevel, double draw) throws Exception {
        // Mock random draw for setEducationLevel to ensure assignment happens
        Mockito.when(mockInnovations.getDoubleDraw(30)).thenReturn(draw);

        // Mock the static dependency on Parameters and ManagerRegressions

        // Set up probabilities map (simplified logic to ensure 'draw' selects 'expectedEducationLevel')
            Map<EducationLevel, Double> mockProbs = new HashMap<>();
            mockProbs.put(EducationLevel.Low, 0.3);
            mockProbs.put(EducationLevel.Medium, 0.3);
            mockProbs.put(EducationLevel.High, 0.4);

        // Mock regression to return the probabilities map
        Mockito.when(mockGeneralisedOrderedRegression.getProbabilities(Mockito.any(), Mockito.any()))
                .thenReturn((Map) mockProbs);

        // Stub the static call to return our deterministic probabilities map
        managerRegressionsMock.when(() -> ManagerRegressions.getProbabilities(Mockito.any(Person.class), Mockito.eq(RegressionName.EducationE2a)))
                .thenReturn(mockProbs);

        // Mock Parameters static method to return regression
        parametersMock.when(Parameters::getRegEducationE2a)
                .thenReturn(mockGeneralisedOrderedRegression);

    }


    /**
     * Setup method to be executed before each test method.
     */
    @BeforeEach
    public void setUp() throws Exception {

        // Static mock setup first
        parametersMock = Mockito.mockStatic(Parameters.class);
        parametersMock.when(Parameters::getRegEducationE2a)
                .thenReturn(mockGeneralisedOrderedRegression);

        // Static mock setup for ManagerRegressions
        managerRegressionsMock = Mockito.mockStatic(ManagerRegressions.class);

        // We wrap the entire setup in a mock block to handle the static dependency called by the Person constructor.
        mockStaticDependenciesForConstructor(() -> {
            try {
                // 1. Initialize Mocks
                mockModel = Mockito.mock(SimPathsModel.class);
                mockInnovations = Mockito.mock(Innovations.class);
                mockBenefitUnit = Mockito.mock(BenefitUnit.class);

                // Initialize regression mocks with specific types
                mockBinomialRegression = Mockito.mock(BinomialRegression.class);
            mockGeneralisedOrderedRegression = Mockito.mock(GeneralisedOrderedRegression.class);

                // 2. Set up basic predictable environment
                Mockito.when(mockModel.getYear()).thenReturn(2025);
                Mockito.when(mockModel.isAlignInSchool()).thenReturn(false);

                // 3. Initialize Person and inject Mocks using Reflection
                testPerson = new Person(1L, 123L);

                setPrivateField(testPerson, "model", mockModel);
                setPrivateField(testPerson, "innovations", mockInnovations);
                setPrivateField(testPerson, "benefitUnit", mockBenefitUnit);
                setPrivateField(testPerson, "eduLeftEduFlag", Boolean.FALSE);
                setPrivateField(testPerson, "eduLeaveSchoolFlag", Boolean.FALSE);

                // Mock the critical dependency from BenefitUnit (Set<Person> is empty for simplicity)
                Mockito.when(mockBenefitUnit.getChildren()).thenReturn(java.util.Collections.emptySet());
            } catch (Exception e) {
                throw new RuntimeException("Setup failed during initialization or field injection.", e);
            }
        });
    }

    @AfterEach
    public void tearDown() throws Exception {
        if (parametersMock != null) {
            parametersMock.close();
        }
        if (managerRegressionsMock != null) {
            managerRegressionsMock.close();
        }
    }

    @Nested
    @DisplayName("RegressorTests: Child Dummies")
    class RegressorTests {

        @Test
        @DisplayName("D_Children_L1 matches D_Children when both periods have children")
        public void dChildrenLagMatchesCurrentWhenChildrenPresent() {
            Mockito.when(mockBenefitUnit.getNumberChildrenAll()).thenReturn(2);
            Mockito.when(mockBenefitUnit.getNumberChildrenAll_lag1()).thenReturn(2);

            assertEquals(1.0, testPerson.getDoubleValue(Person.DoublesVariables.D_Children));
            assertEquals(1.0, testPerson.getDoubleValue(Person.DoublesVariables.D_Children_L1));
        }

        @Test
        @DisplayName("D_Children_L1 matches D_Children when both periods have no children")
        public void dChildrenLagMatchesCurrentWhenNoChildrenPresent() {
            Mockito.when(mockBenefitUnit.getNumberChildrenAll()).thenReturn(0);
            Mockito.when(mockBenefitUnit.getNumberChildrenAll_lag1()).thenReturn(0);

            assertEquals(0.0, testPerson.getDoubleValue(Person.DoublesVariables.D_Children));
            assertEquals(0.0, testPerson.getDoubleValue(Person.DoublesVariables.D_Children_L1));
        }

        @Test
        @DisplayName("Les_c2_NotEmployed_L1 flags lagged student or not employed, as Stata lesnr_c2")
        public void lesC2NotEmployedLagMatchesLesnrC2() {
            testPerson.setLes_c4_lag1(Les_c4.NotEmployed);
            assertEquals(1.0, testPerson.getDoubleValue(Person.DoublesVariables.Les_c2_NotEmployed_L1));
            testPerson.setLes_c4_lag1(Les_c4.Student);
            assertEquals(1.0, testPerson.getDoubleValue(Person.DoublesVariables.Les_c2_NotEmployed_L1));
            testPerson.setLes_c4_lag1(Les_c4.EmployedOrSelfEmployed);
            assertEquals(0.0, testPerson.getDoubleValue(Person.DoublesVariables.Les_c2_NotEmployed_L1));
            testPerson.setLes_c4_lag1(Les_c4.Retired);
            assertEquals(0.0, testPerson.getDoubleValue(Person.DoublesVariables.Les_c2_NotEmployed_L1));
        }

        @Test
        @DisplayName("Reached_Retirement_Age_Les_c2_NotEmployed_L1 needs pension age this year and lagged non-employment")
        public void reachedRetirementAgeLesC2Interaction() {
            parametersMock.when(() -> Parameters.getTimeSeriesValue(Mockito.anyInt(), Mockito.anyString(),
                    Mockito.eq(TimeSeriesVariable.FixedRetirementAge))).thenReturn(65.0);
            testPerson.setDgn(Gender.Male);

            testPerson.setDag(65);
            testPerson.setLes_c4_lag1(Les_c4.NotEmployed);
            assertEquals(1.0, testPerson.getDoubleValue(Person.DoublesVariables.Reached_Retirement_Age_Les_c2_NotEmployed_L1));
            testPerson.setLes_c4_lag1(Les_c4.EmployedOrSelfEmployed);
            assertEquals(0.0, testPerson.getDoubleValue(Person.DoublesVariables.Reached_Retirement_Age_Les_c2_NotEmployed_L1));

            testPerson.setDag(64);
            testPerson.setLes_c4_lag1(Les_c4.NotEmployed);
            assertEquals(0.0, testPerson.getDoubleValue(Person.DoublesVariables.Reached_Retirement_Age_Les_c2_NotEmployed_L1));
        }

        @Test
        @DisplayName("Dnc parity dummies split the lagged child count at zero, one and two")
        public void dncParityDummiesSplitLaggedChildCount() {
            Mockito.when(mockBenefitUnit.getNumberChildrenAll_lag1()).thenReturn(0);
            assertEquals(0.0, testPerson.getDoubleValue(Person.DoublesVariables.Dnc1_plus_L1));
            assertEquals(0.0, testPerson.getDoubleValue(Person.DoublesVariables.Dnc1_L1));
            assertEquals(0.0, testPerson.getDoubleValue(Person.DoublesVariables.Dnc2_plus_L1));

            Mockito.when(mockBenefitUnit.getNumberChildrenAll_lag1()).thenReturn(1);
            assertEquals(1.0, testPerson.getDoubleValue(Person.DoublesVariables.Dnc1_plus_L1));
            assertEquals(1.0, testPerson.getDoubleValue(Person.DoublesVariables.Dnc1_L1));
            assertEquals(0.0, testPerson.getDoubleValue(Person.DoublesVariables.Dnc2_plus_L1));

            Mockito.when(mockBenefitUnit.getNumberChildrenAll_lag1()).thenReturn(3);
            assertEquals(1.0, testPerson.getDoubleValue(Person.DoublesVariables.Dnc1_plus_L1));
            assertEquals(0.0, testPerson.getDoubleValue(Person.DoublesVariables.Dnc1_L1));
            assertEquals(1.0, testPerson.getDoubleValue(Person.DoublesVariables.Dnc2_plus_L1));
        }

        @Test
        @DisplayName("Dnc1_plus_L1 matches D_Children_L1; Dnc02_yes_L1 flags any child aged 0-2")
        public void dncPresenceDummiesBehaveAsExpected() {
            Mockito.when(mockBenefitUnit.getNumberChildrenAll_lag1()).thenReturn(2);
            Mockito.when(mockBenefitUnit.getNumberChildren02_lag1()).thenReturn(0);

            assertEquals(testPerson.getDoubleValue(Person.DoublesVariables.D_Children_L1),
                    testPerson.getDoubleValue(Person.DoublesVariables.Dnc1_plus_L1));
            assertEquals(0.0, testPerson.getDoubleValue(Person.DoublesVariables.Dnc02_yes_L1));

            Mockito.when(mockBenefitUnit.getNumberChildren02_lag1()).thenReturn(1);
            assertEquals(1.0, testPerson.getDoubleValue(Person.DoublesVariables.Dnc02_yes_L1));
        }

        @Test
        @DisplayName("New_rel_L1 returns zero when lagged partnership status is missing")
        public void newRelLagHandlesMissingPartnershipStatus() throws Exception {
            setPrivateField(testPerson, "benefitUnit", null);
            testPerson.setDcpstLocal(Dcpst.Partnered);
            testPerson.setDcpst_lag1(null);

            assertDoesNotThrow(() -> testPerson.getDoubleValue(Person.DoublesVariables.New_rel_L1));
            assertEquals(0.0, testPerson.getDoubleValue(Person.DoublesVariables.New_rel_L1));
        }

        @Test
        @DisplayName("New_rel_L1 returns one for a newly partnered person")
        public void newRelLagFlagsNewPartnership() throws Exception {
            setPrivateField(testPerson, "benefitUnit", null);
            testPerson.setDcpstLocal(Dcpst.Partnered);
            testPerson.setDcpst_lag1(Dcpst.Single);

            assertEquals(1.0, testPerson.getDoubleValue(Person.DoublesVariables.New_rel_L1));
        }
    }

    // -------------------------------------------------------------------------
    // NESTED TESTS FOR inSchool()
    // -------------------------------------------------------------------------

    @Nested
    @DisplayName("InSchoolTests: E1a/E1b Flow")
    class InSchoolTests {

        @Test
        @DisplayName("OUTCOME A: Lagged Student < Min Age (Always Stays)")
        public void remainsBelowMinAge() throws Exception {
            testPerson.setDag(Parameters.MIN_AGE_TO_LEAVE_EDUCATION - 1);
            testPerson.setLes_c4_lag1(Les_c4.Student);
            assertTrue(testPerson.inSchool(), "Person must remain a student if below MIN_AGE_TO_LEAVE_EDUCATION (OUTCOME A).");
        }

        @Test
        @DisplayName("OUTCOME B: Lagged Student, Stays in E1a (Continue Spell)")
        public void continuesCurrentSpellE1a() throws Exception {
            final double PROBABILITY_TO_STAY = 0.9;
            final double INNOVATION_TO_STAY = 0.1;

            testPerson.setDag(25);
            testPerson.setLes_c4_lag1(Les_c4.Student);
            testPerson.setLes_c4(Les_c4.Student);

               parametersMock.when(() -> Parameters.getRegEducationE1a()).thenReturn(mockBinomialRegression);
               Mockito.when(mockBinomialRegression.getProbability(Mockito.anyDouble())).thenReturn(PROBABILITY_TO_STAY);
               Mockito.when(mockInnovations.getDoubleDraw(24)).thenReturn(INNOVATION_TO_STAY);

               assertTrue(testPerson.inSchool(), "Person remains in school (OUTCOME B).");
               assertEquals(Les_c4.Student, testPerson.getLes_c4());
               assertFalse(testPerson.isToLeaveSchool());
        }

        @Test
        @DisplayName("E2 Trigger: Lagged Student, Fails E1a (Leaves Spell)")
        public void triggersE2FromE1aFailure() throws Exception {
            final double PROBABILITY_TO_STAY = 0.5;
            final double INNOVATION_TO_LEAVE = 0.95;

            testPerson.setDag(25);
            testPerson.setLes_c4_lag1(Les_c4.Student);

               parametersMock.when(() -> Parameters.getRegEducationE1a()).thenReturn(mockBinomialRegression);
               Mockito.when(mockBinomialRegression.getProbability(Mockito.anyDouble())).thenReturn(PROBABILITY_TO_STAY);
               Mockito.when(mockInnovations.getDoubleDraw(24)).thenReturn(INNOVATION_TO_LEAVE);

               assertFalse(testPerson.inSchool(), "Should return false (triggers E2 process).");
               assertTrue(testPerson.isToLeaveSchool(), "toLeaveSchool flag should be true.");
        }

        @Test
        @DisplayName("E2 Trigger: Lagged Student, at Max Age (Forced Exit)")
        public void triggersE2FromMaxAge() throws Exception {
            testPerson.setDag(Parameters.MAX_AGE_TO_STAY_IN_CONTINUOUS_EDUCATION + 1);
            testPerson.setLes_c4_lag1(Les_c4.Student);

            assertFalse(testPerson.inSchool(), "Should return false (triggers E2 process).");
            assertTrue(testPerson.isToLeaveSchool(), "toLeaveSchool flag should be true.");
        }

        @Test
        @DisplayName("OUTCOME C: Lagged Retired (Cannot Re-enter)")
        public void cannotEnterIfLaggedRetired() throws Exception {
            testPerson.setLes_c4_lag1(Les_c4.Retired);

            assertFalse(testPerson.inSchool(), "Retired person cannot be student (OUTCOME C).");
            assertFalse(testPerson.isToLeaveSchool());
        }

        @Test
        @DisplayName("OUTCOME E: Lagged Not Student, Succeeds in E1b (Becomes Student)")
        public void becomesStudentE1bSuccess() throws Exception {
            final double PROBABILITY_TO_BECOME_STUDENT = 0.8;
            final double INNOVATION_TO_BECOME_STUDENT = 0.1;

            testPerson.setLes_c4_lag1(Les_c4.NotEmployed);
            testPerson.setLes_c4(Les_c4.NotEmployed);

               parametersMock.when(() -> Parameters.getRegEducationE1b()).thenReturn(mockBinomialRegression);
               Mockito.when(mockBinomialRegression.getProbability(Mockito.anyDouble())).thenReturn(PROBABILITY_TO_BECOME_STUDENT);
               Mockito.when(mockInnovations.getDoubleDraw(24)).thenReturn(INNOVATION_TO_BECOME_STUDENT);

               assertTrue(testPerson.inSchool(), "Person becomes a student (OUTCOME E).");
               assertEquals(Les_c4.Student, testPerson.getLes_c4());
               assertEquals(Indicator.False, testPerson.getDed());
               assertEquals(Indicator.True, testPerson.getDer());
        }

        @Test
        @DisplayName("OUTCOME D: Lagged Not Student, Fails in E1b (Remains Unchanged)")
        public void remainsUnchangedE1bFailure() throws Exception {
            final double PROBABILITY_TO_BECOME_STUDENT = 0.2;
            final double INNOVATION_REMAIN_UNCHANGED = 0.9;

            testPerson.setLes_c4_lag1(Les_c4.EmployedOrSelfEmployed);
            testPerson.setLes_c4(Les_c4.EmployedOrSelfEmployed);

               parametersMock.when(() -> Parameters.getRegEducationE1b()).thenReturn(mockBinomialRegression);
               Mockito.when(mockBinomialRegression.getProbability(Mockito.anyDouble())).thenReturn(PROBABILITY_TO_BECOME_STUDENT);
               Mockito.when(mockInnovations.getDoubleDraw(24)).thenReturn(INNOVATION_REMAIN_UNCHANGED);

               assertFalse(testPerson.inSchool(), "Person remains in current status (OUTCOME D).");
               assertEquals(Les_c4.EmployedOrSelfEmployed, testPerson.getLes_c4());
               assertFalse(testPerson.isToLeaveSchool());
        }
    }

    // -------------------------------------------------------------------------
    // NESTED TESTS FOR setEducationLevel()
    // -------------------------------------------------------------------------

    @Nested
    @DisplayName("SetEducationLevelTests: E2 Flow Logic")
    class SetEducationLevelTests {

        @Test
        @DisplayName("OUTCOME F (First Spell): Adopts New Level (e.g., Low -> High)")
        public void firstSpellAdoptsNewLevel() throws Exception {
            testPerson.setDeh_c4(Education.Low);
            testPerson.setDer(Indicator.False);

            setupEducationLevelRegressionMock(EducationLevel.High, 0.9);

            testPerson.setEducationLevel();

            assertEquals(Education.High, testPerson.getDeh_c4(), "First spell should always adopt the new regression result (OUTCOME F).");
        }

        @Test
        @DisplayName("OUTCOME F (Return Spell Improvement): Adopts New, Higher Level")
        public void returnSpellAdoptsHigherLevel() throws Exception {
            testPerson.setDeh_c4(Education.Low);
            testPerson.setDer(Indicator.True);

            setupEducationLevelRegressionMock(EducationLevel.Medium, 0.5); // Draw 0.5 < 0.6 (Cumulative Medium) --> Selects Medium

            testPerson.setEducationLevel();

            assertEquals(Education.Medium, testPerson.getDeh_c4(), "Return spell must adopt the new level because it is higher than current (OUTCOME F).");
        }

        @Test
        @DisplayName("OUTCOME G (Return Spell Downgrade): Retains Current Level (e.g., Medium -> Low)")
        public void returnSpellRetainsCurrentLevelOnDowngrade() throws Exception {
            testPerson.setDeh_c4(Education.Medium);
            testPerson.setDer(Indicator.True);

            setupEducationLevelRegressionMock(EducationLevel.Low, 0.2);

            testPerson.setEducationLevel();

            assertEquals(Education.Medium, testPerson.getDeh_c4(), "Return spell must retain the current level because the new level is not higher (OUTCOME G).");
        }

        @Test
        @DisplayName("OUTCOME G (Return Spell Same Level): Retains Current Level")
        public void returnSpellRetainsCurrentLevelOnSameLevel() throws Exception {
            testPerson.setDeh_c4(Education.Medium);
            testPerson.setDer(Indicator.True);

            setupEducationLevelRegressionMock(EducationLevel.Medium, 0.5);

            testPerson.setEducationLevel();

            assertEquals(Education.Medium, testPerson.getDeh_c4(), "Return spell must retain the current level because the new level is not strictly higher (OUTCOME G).");
        }
    }

    // -------------------------------------------------------------------------
    // NESTED TESTS FOR leavingSchool()
    // -------------------------------------------------------------------------

    @Nested
    @DisplayName("LeavingSchoolTests: Final State Transitions")
    class LeavingSchoolTests {

        @Test
        @DisplayName("When toLeaveSchool=True: Executes all state transitions")
        public void successfulExitExecution() throws Exception {
            testPerson.setToLeaveSchool(true);
            testPerson.setDag(20);
            testPerson.setDeh_c4(Education.Low);
            testPerson.setDed(Indicator.True);
            testPerson.setDer(Indicator.False);
            testPerson.setLes_c4(Les_c4.Student);
            testPerson.setLes_c4_lag1(Les_c4.Student);

            setupEducationLevelRegressionMock(EducationLevel.Medium, 0.5);

            testPerson.leavingSchool();

            assertFalse(testPerson.isToLeaveSchool(), "toLeaveSchool should be reset to false.");
            assertEquals(Indicator.False, testPerson.getDed(), "Ded should be set to False.");
            assertEquals(Indicator.False, testPerson.getDer(), "Der should be set to False.");
            assertTrue(testPerson.isLeftEducation(), "leftEducation flag should be true.");
            assertEquals(Les_c4.NotEmployed, testPerson.getLes_c4(), "Activity status should be set to NotEmployed.");
            assertEquals(Education.Medium, testPerson.getDeh_c4(), "Education level should be assigned to Medium.");
            assertEquals(Indicator.True, testPerson.getSedex(), "Sedex should be set to true.");
        }

        @Test
        @DisplayName("When toLeaveSchool=False: Skips execution and leaves state intact")
        public void noExecution() throws Exception {
            testPerson.setToLeaveSchool(false);
            testPerson.setLes_c4(Les_c4.EmployedOrSelfEmployed);
            testPerson.setDeh_c4(Education.High);

            testPerson.leavingSchool();

            assertEquals(Les_c4.EmployedOrSelfEmployed, testPerson.getLes_c4(), "Activity status should remain unchanged.");
            assertEquals(Education.High, testPerson.getDeh_c4(), "Education level must remain unchanged.");
            assertFalse(testPerson.isLeftEducation(), "leftEducation flag should remain false (default state).");
            Mockito.verify(mockInnovations, Mockito.never()).getDoubleDraw(30);
        }
    }
}
