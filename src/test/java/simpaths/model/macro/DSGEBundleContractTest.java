package simpaths.model.macro;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Contract guards on the exported DSGE bundle: conventions that the loader refuses
 * at load time when a bundle violates them. Tampers a copy of the live PL bundle so
 * the guards are exercised against the exact files production reads.
 */
class DSGEBundleContractTest {

    private static final Path MODEL_PATH = Paths.get("input", "PL", "MacroModel");

    /** Files DSGEModel.loadFromDirectory actually reads (steady_state.csv is not read). */
    private static final String[] LOADED_FILES = {
            "model_info.json", "policy_A.csv", "policy_Bs.csv",
            "policy_C.csv", "policy_D.csv", "shock_params.csv"};

    static void assumeBundle() {
        Assumptions.assumeTrue(Files.exists(MODEL_PATH.resolve("policy_A.csv")),
                "PL MacroModel bundle required");
    }

    static void copyBundle(Path dir) throws IOException {
        for (String f : LOADED_FILES) {
            Files.copy(MODEL_PATH.resolve(f), dir.resolve(f));
        }
    }

    @Test
    void currentBundleStillLoads() throws IOException {
        assumeBundle();
        DSGEModel model = new DSGEModel();
        model.loadFromDirectory(MODEL_PATH.toString());
        assertTrue(model.isLoaded(), "the guards must not reject the real bundle");
    }

    @Test
    void missingDeviationScaleIsRefused(@TempDir Path dir) throws IOException {
        assumeBundle();
        copyBundle(dir);
        String json = Files.readString(dir.resolve("model_info.json"));
        String stripped = json.replaceAll(",?\\s*\"deviation_scale\"\\s*:\\s*[0-9.eE+\\-]+", "");
        assertNotEquals(json, stripped, "live bundle should declare deviation_scale");
        Files.writeString(dir.resolve("model_info.json"), stripped);

        DSGEModel model = new DSGEModel();
        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> model.loadFromDirectory(dir.toString()));
        assertTrue(ex.getMessage().contains("deviation_scale"), ex.getMessage());
    }

    @Test
    void wrongDeviationScaleIsRefused(@TempDir Path dir) throws IOException {
        assumeBundle();
        copyBundle(dir);
        String json = Files.readString(dir.resolve("model_info.json"));
        Files.writeString(dir.resolve("model_info.json"),
                json.replaceAll("\"deviation_scale\"\\s*:\\s*[0-9.eE+\\-]+",
                        "\"deviation_scale\": 1"));

        DSGEModel model = new DSGEModel();
        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> model.loadFromDirectory(dir.toString()));
        assertTrue(ex.getMessage().contains("deviation_scale"), ex.getMessage());
    }

    /**
     * A bundle that declares its units under {@code simpaths_input_scale} instead of
     * {@code deviation_scale} (an export that gives the labour shocks zero persistence) must
     * be refused with a message that says to re-export.
     */
    @Test
    void testBundleWithTheOldUnitFieldIsRefused(@TempDir Path dir) throws IOException {
        assumeBundle();
        copyBundle(dir);
        String json = Files.readString(dir.resolve("model_info.json"));
        String old = json.replace("\"deviation_scale\"", "\"simpaths_input_scale\"");
        assertNotEquals(json, old, "live bundle should declare deviation_scale");
        Files.writeString(dir.resolve("model_info.json"), old);

        DSGEModel model = new DSGEModel();
        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> model.loadFromDirectory(dir.toString()));
        assertTrue(ex.getMessage().contains("deviation_scale") && ex.getMessage().contains("re-export"),
                ex.getMessage());
    }
}
