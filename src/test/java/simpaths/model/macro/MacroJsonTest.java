package simpaths.model.macro;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Contract tests for {@link MacroJson}, the single JSON reader for the MATLAB
 * export bundle.
 *
 * <p>The defect these pin: the macro package used to carry three separate
 * hand-rolled parsers, and they disagreed about whitespace after the colon.
 * MATLAB's {@code jsonencode(..., 'PrettyPrint', true)} emits {@code "k": v}
 * while the exporter's own pretty-printer emits {@code "k":v}, so a reader that
 * matched the literal {@code "k":} returned its default — a silent 0.0
 * parameter — depending only on which writer produced the file.</p>
 */
class MacroJsonTest {

    /** Same document, no space after the colons — the exporter's style. */
    private static final String COMPACT =
            "{\"model_name\":\"Poland\",\"n_state\":13,\"phi\":1.35,"
          + "\"enabled\":true,\"state_names\":[\"R\",\"w\",\"pi\"],"
          + "\"state_idx_in_s\":{\"R\":0,\"w\":1,\"pi\":2},"
          + "\"terminal_growth\":{\"g_A_terminal_annual\":0.005}}";

    /** Same document, pretty-printed — MATLAB jsonencode's style. */
    private static final String PRETTY =
            "{\n  \"model_name\": \"Poland\",\n  \"n_state\": 13,\n  \"phi\": 1.35,\n"
          + "  \"enabled\": true,\n  \"state_names\": [\"R\", \"w\", \"pi\"],\n"
          + "  \"state_idx_in_s\": {\"R\": 0, \"w\": 1, \"pi\": 2},\n"
          + "  \"terminal_growth\": {\"g_A_terminal_annual\": 0.005}\n}";

    @Test
    @DisplayName("every accessor reads compact and pretty-printed JSON identically")
    void readsBothWriterStylesIdentically() {
        assertEquals(MacroJson.string(COMPACT, "model_name", "?"),
                     MacroJson.string(PRETTY, "model_name", "?"));
        assertEquals("Poland", MacroJson.string(PRETTY, "model_name", "?"));

        assertEquals(MacroJson.integer(COMPACT, "n_state", -1),
                     MacroJson.integer(PRETTY, "n_state", -1));
        assertEquals(13, MacroJson.integer(PRETTY, "n_state", -1));

        assertEquals(MacroJson.number(COMPACT, "phi", -1.0),
                     MacroJson.number(PRETTY, "phi", -1.0), 0.0);
        assertEquals(1.35, MacroJson.number(PRETTY, "phi", -1.0), 0.0);

        assertEquals(MacroJson.bool(COMPACT, "enabled", false),
                     MacroJson.bool(PRETTY, "enabled", false));
        assertTrue(MacroJson.bool(PRETTY, "enabled", false));

        assertArrayEquals(MacroJson.stringArray(COMPACT, "state_names"),
                          MacroJson.stringArray(PRETTY, "state_names"));
        assertArrayEquals(new String[]{"R", "w", "pi"},
                          MacroJson.stringArray(PRETTY, "state_names"));

        assertEquals(MacroJson.intMap(COMPACT, "state_idx_in_s"),
                     MacroJson.intMap(PRETTY, "state_idx_in_s"));
        Map<String, Integer> idx = MacroJson.intMap(PRETTY, "state_idx_in_s");
        assertEquals(0, idx.get("R"));
        assertEquals(2, idx.get("pi"));
    }

    @Test
    @DisplayName("nested objects are reachable in both styles")
    void readsNestedObjects() {
        for (String doc : new String[]{COMPACT, PRETTY}) {
            String block = MacroJson.object(doc, "terminal_growth");
            assertEquals(0.005, MacroJson.number(block, "g_A_terminal_annual", -1.0), 0.0);
        }
    }

    @Test
    @DisplayName("a key that appears only as an array VALUE is not treated as a key")
    void doesNotMatchArrayElements() {
        // "pi" occurs inside state_names as a value before it occurs as a key in
        // state_idx_in_s. A naive indexOf("\"pi\"") lands on the array element.
        assertEquals(2, MacroJson.integer(PRETTY, "pi", -1));
    }

    @Test
    @DisplayName("absent keys yield the caller's default, not a fabricated zero")
    void absentKeysReturnDefaults() {
        assertEquals("fallback", MacroJson.string(COMPACT, "no_such_key", "fallback"));
        assertEquals(-7, MacroJson.integer(COMPACT, "no_such_key", -7));
        assertEquals(-7.5, MacroJson.number(COMPACT, "no_such_key", -7.5), 0.0);
        assertTrue(MacroJson.bool(COMPACT, "no_such_key", true));
        assertEquals(0, MacroJson.stringArray(COMPACT, "no_such_key").length);
        assertTrue(MacroJson.intMap(COMPACT, "no_such_key").isEmpty());
        assertNull(MacroJson.object(COMPACT, "no_such_key"));
        assertFalse(MacroJson.has(COMPACT, "no_such_key"));
        assertTrue(MacroJson.has(COMPACT, "phi"));
    }

    @Test
    @DisplayName("scientific notation and string-wrapped numbers both parse")
    void parsesNumberVariants() {
        String doc = "{\"tol\": 1.0E-10, \"scaled\": 9.35E+6, \"asText\": \"1.5\", \"neg\": -0.25}";
        assertEquals(1.0e-10, MacroJson.number(doc, "tol", 0.0), 0.0);
        assertEquals(9.35e6, MacroJson.number(doc, "scaled", 0.0), 0.0);
        assertEquals(1.5, MacroJson.number(doc, "asText", 0.0), 0.0);
        assertEquals(-0.25, MacroJson.number(doc, "neg", 0.0), 0.0);
    }

    @Test
    @DisplayName("a brace inside a comment string does not truncate the enclosing object")
    void braceInsideStringDoesNotTruncate() {
        String doc = "{\"solver\": {\"x_comment\": \"uses {I + lambda D'D} form\", \"iters\": 200}}";
        String block = MacroJson.object(doc, "solver");
        assertEquals(200, MacroJson.integer(block, "iters", -1));
    }

    /**
     * Task 7 of the 2026-08-19 contract-fixes plan rewrites growth_terminal_state.json
     * numbers as %.16e (K_terminal/A_terminal join psi_terminal). A number reader that
     * silently truncated at 'e' would be exactly the class of bug this plan removes,
     * so the format is pinned here before the writer changes.
     */
    @Test
    void numberParsesScientificNotation() {
        String json = "{\n  \"K_terminal\": 1.3607012165440000e+06,\n"
                + "  \"A_terminal\": 3.4518608300000002e-02,\n"
                + "  \"psi_terminal\": 1.2397643478786207e+00\n}";
        assertEquals(1.3607012165440000e+06, MacroJson.number(json, "K_terminal", 0.0));
        assertEquals(3.4518608300000002e-02, MacroJson.number(json, "A_terminal", 0.0));
        assertEquals(1.2397643478786207e+00, MacroJson.number(json, "psi_terminal", 0.0));
    }
}
