package simpaths.experiment;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;

public class SimPathsMultiRunTest {

    private static final ByteArrayOutputStream outContent = new ByteArrayOutputStream();
    private static final ByteArrayOutputStream errContent = new ByteArrayOutputStream();

    @BeforeAll
    public static void setUpStreams() {
        System.setOut(new PrintStream(outContent));
        System.setErr(new PrintStream(errContent));
    }

    @BeforeEach
    public void resetStreams() {
        outContent.reset();
        errContent.reset();
    }

    @Test
    public void testSimPathsMultiRunHelpOption() {
        String[] args = {"-h"};
        SimPathsMultiRun.main(args);

        String expectedHelpText = "SimPathsMultiRun can run multiple sequential runs";

        assertTrue(outContent.toString().contains(expectedHelpText));
//        assertEquals("", errContent.toString().trim());
    }

    @Test
    public void testBadConfigFile() {
        String[] args = {"-config", "wrong.yml"};
        SimPathsMultiRun.main(args);

        String expectedErrorText = "Config file wrong.yml not found; please supply a valid config file";
        assertTrue(errContent.toString().contains(expectedErrorText));
    }

    private static String runLabel(java.util.Map<String, Object> args) throws Exception {
        java.lang.reflect.Field field = SimPathsMultiRun.class.getDeclaredField("modelArgs");
        field.setAccessible(true);
        Object saved = field.get(null);
        try {
            field.set(null, args);
            java.lang.reflect.Method method =
                    SimPathsMultiRun.class.getDeclaredMethod("buildRunLabel", Long.class, Long.class);
            method.setAccessible(true);
            return (String) method.invoke(null, 42L, 0L);
        } finally {
            field.set(null, saved);
        }
    }

    @Test
    public void runLabelNamesInputScenarioBeforeRamseyScenario() throws Exception {
        assertEquals("42_0_migration_200k_ramsey_migration", runLabel(java.util.Map.of(
                "inputScenario", "migration_200k", "mm_ramseyScenario", "ramsey_migration.csv")));
    }

    @Test
    public void runLabelWithoutScenariosIsSeedAndCounter() throws Exception {
        assertEquals("42_0", runLabel(java.util.Map.of()));
    }

    // Add more test methods for other scenarios as needed
}
