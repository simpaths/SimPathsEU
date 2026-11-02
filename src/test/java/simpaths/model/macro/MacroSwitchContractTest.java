package simpaths.model.macro;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.yaml.snakeyaml.Yaml;

import simpaths.model.SimPathsModel;
import simpaths.model.enums.ConfigEnumValue;
import simpaths.model.enums.Country;
import simpaths.model.enums.MacroFeedbackMargins;
import simpaths.model.enums.MacroLogLevel;
import simpaths.model.enums.MacroModelMode;

/**
 * Pins the user-facing macro switch surface: which {@code mm_*} keys exist, what they default
 * to, and how config values are parsed into the mode enums.
 *
 * <p>The switch table in the macro model documentation
 * ({@code WELLSIM_SVEC_Overleaf/Tables/table_macro_switches.tex}) is written by hand and has
 * no other link to this code. It went stale once already, missing four switches and misstating
 * two defaults. When this test fails, update that table in the same commit as the code.</p>
 */
class MacroSwitchContractTest {

    /** name -> "type default", exactly as the documentation table reports it. */
    private static final Map<String, String> EXPECTED = new LinkedHashMap<>();
    static {
        EXPECTED.put("mm_macroModel",                     "MacroModelMode OFF");
        EXPECTED.put("mm_macroLogging",                   "MacroLogLevel OFF");
        EXPECTED.put("mm_useMacroPathRecorder",           "boolean true");
        EXPECTED.put("mm_dsgeShockScenario",              "String ");
        EXPECTED.put("mm_ramseyScenario",                 "String ");
        EXPECTED.put("mm_ramseyFeedbackMargins",          "MacroFeedbackMargins EMPLOYMENT_AND_HOURS");
        EXPECTED.put("mm_ramseyFeedbackPersistence",      "double 1.0");
        EXPECTED.put("mm_ramseyFeedbackHoursPersistence", "double 1.0");
        EXPECTED.put("mm_dsgeMaxStateDeviation",          "double 10.0");
    }

    @Test
    @DisplayName("the mm_* switch surface matches the documented table")
    void switchSurfaceMatchesDocumentation() throws Exception {
        SimPathsModel model = new SimPathsModel(Country.PL, 2023);
        Map<String, String> actual = new LinkedHashMap<>();
        List<String> names = new ArrayList<>();
        for (Field f : SimPathsModel.class.getDeclaredFields()) {
            if (!f.getName().startsWith("mm_")) continue;
            f.setAccessible(true);
            Object value = f.get(model);
            String rendered = value instanceof Enum<?> e ? e.name() : String.valueOf(value);
            actual.put(f.getName(), f.getType().getSimpleName() + " " + rendered);
            names.add(f.getName());
        }
        assertEquals(EXPECTED, actual,
                "The mm_* switches changed. Update Tables/table_macro_switches.tex in the"
                + " WELLSIM_SVEC_Overleaf repo and the appendix prose, then update EXPECTED here."
                + " Found: " + names);
    }

    @Test
    @DisplayName("unquoted `off` survives SnakeYAML's boolean resolver")
    void unquotedOffParsesToTheDisabledConstant() {
        // YAML 1.1 resolves off/no/false to Boolean before any enum conversion runs, so the
        // natural spelling reaches the parser as Boolean.FALSE rather than the string "off".
        Object raw = ((Map<?, ?>) new Yaml().load("mm_macroModel: off\n")).get("mm_macroModel");
        assertEquals(Boolean.FALSE, raw, "SnakeYAML is expected to resolve `off` to a Boolean");
        assertEquals(MacroModelMode.OFF, MacroModelMode.fromConfigValue(raw));
        assertEquals(MacroLogLevel.OFF, MacroLogLevel.fromConfigValue(raw));
    }

    @Test
    @DisplayName("mode values parse case- and separator-insensitively")
    void modeValuesParse() {
        assertEquals(MacroModelMode.RAMSEY_DSGE, MacroModelMode.fromConfigValue("ramsey_dsge"));
        assertEquals(MacroModelMode.RAMSEY_DSGE, MacroModelMode.fromConfigValue("ramsey-dsge"));
        assertEquals(MacroModelMode.RAMSEY, MacroModelMode.fromConfigValue("RAMSEY"));
        assertEquals(MacroFeedbackMargins.EMPLOYMENT_AND_HOURS,
                MacroFeedbackMargins.fromConfigValue("employment_and_hours"));
        assertEquals(MacroLogLevel.VERBOSE, MacroLogLevel.fromConfigValue("verbose"));
    }

    @Test
    @DisplayName("`true` and unknown values are rejected by name")
    void badValuesAreRejected() {
        IllegalArgumentException onTrue = assertThrows(IllegalArgumentException.class,
                () -> MacroModelMode.fromConfigValue(Boolean.TRUE));
        assertTrue(onTrue.getMessage().contains("ramsey_dsge"),
                "the message should list the valid modes, got: " + onTrue.getMessage());

        IllegalArgumentException onJunk = assertThrows(IllegalArgumentException.class,
                () -> MacroModelMode.fromConfigValue("ramsy"));
        assertTrue(onJunk.getMessage().contains("mm_macroModel"),
                "the message should name the key, got: " + onJunk.getMessage());
    }

    @Test
    @DisplayName("the enum lattices agree with what each mode claims to run")
    void modeLatticesAreConsistent() {
        assertEquals("off | ramsey | dsge | ramsey_dsge", ConfigEnumValue.valueList(MacroModelMode.class));
        assertEquals("none | employment | hours | employment_and_hours",
                ConfigEnumValue.valueList(MacroFeedbackMargins.class));
        assertEquals("off | state | verbose", ConfigEnumValue.valueList(MacroLogLevel.class));

        assertTrue(MacroModelMode.RAMSEY_DSGE.usesRamseyTrend() && MacroModelMode.RAMSEY_DSGE.usesDsge());
        assertTrue(MacroModelMode.DSGE.usesDsge() && !MacroModelMode.DSGE.usesRamseyTrend());
        assertTrue(MacroFeedbackMargins.HOURS.feedsHours() && !MacroFeedbackMargins.HOURS.feedsEmployment());
        assertTrue(MacroFeedbackMargins.EMPLOYMENT.feedsEmployment() && !MacroFeedbackMargins.EMPLOYMENT.feedsHours());
        assertTrue(MacroLogLevel.VERBOSE.logsState(), "verbose must imply state");
    }
}
