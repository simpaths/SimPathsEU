package simpaths.model.macro;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Contract guards on the exported DSGE bundle: conventions that used to live in
 * prose (2026-08-19 boundary audit, findings C1/C2) and are now refused at load
 * time when a bundle violates them. Tampers a copy of the live PL bundle so the
 * guards are exercised against the exact files production reads.
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
    void nonZeroRhoOnSimPathsLevelInputIsRefused(@TempDir Path dir) throws IOException {
        assumeBundle();
        copyBundle(dir);

        List<String> lines = Files.readAllLines(dir.resolve("shock_params.csv"));
        boolean tampered = false;
        for (int i = 1; i < lines.size(); i++) {
            String[] parts = lines.get(i).split(",", -1);
            if (parts[0].trim().equals("eps_L")) {
                parts[2] = "0.95";
                lines.set(i, String.join(",", parts));
                tampered = true;
            }
        }
        assertTrue(tampered, "eps_L row not found in shock_params.csv");
        Files.write(dir.resolve("shock_params.csv"), lines);

        DSGEModel model = new DSGEModel();
        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> model.loadFromDirectory(dir.toString()));
        assertTrue(ex.getMessage().contains("eps_L"), ex.getMessage());
        assertTrue(ex.getMessage().contains("rho"), ex.getMessage());
    }

    @Test
    void missingInputScaleDeclarationIsRefused(@TempDir Path dir) throws IOException {
        assumeBundle();
        copyBundle(dir);
        String json = Files.readString(dir.resolve("model_info.json"));
        String stripped = json.replaceAll(",?\\s*\"simpaths_input_scale\"\\s*:\\s*[0-9.eE+\\-]+", "");
        assertNotEquals(json, stripped, "live bundle should declare simpaths_input_scale");
        Files.writeString(dir.resolve("model_info.json"), stripped);

        DSGEModel model = new DSGEModel();
        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> model.loadFromDirectory(dir.toString()));
        assertTrue(ex.getMessage().contains("simpaths_input_scale"), ex.getMessage());
    }

    @Test
    void wrongInputScaleDeclarationIsRefused(@TempDir Path dir) throws IOException {
        assumeBundle();
        copyBundle(dir);
        String json = Files.readString(dir.resolve("model_info.json"));
        Files.writeString(dir.resolve("model_info.json"),
                json.replaceAll("\"simpaths_input_scale\"\\s*:\\s*[0-9.eE+\\-]+",
                        "\"simpaths_input_scale\": 1"));

        DSGEModel model = new DSGEModel();
        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> model.loadFromDirectory(dir.toString()));
        assertTrue(ex.getMessage().contains("simpaths_input_scale"), ex.getMessage());
    }
}
