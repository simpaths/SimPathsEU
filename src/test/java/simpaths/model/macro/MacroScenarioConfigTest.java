package simpaths.model.macro;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.yaml.snakeyaml.Yaml;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Field;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

/**
 * Keeps the macro scenario config families ceteris paribus.
 *
 * <p>Each family exists to isolate one treatment: the {@code phi-*} runs vary the
 * permanent wage shift to identify the labour-supply elasticity, and the
 * {@code batch-*} runs vary which macro layers are active. Every other setting
 * must be identical across the siblings, because the families are read by
 * differencing their outputs. A setting changed in one sibling and not the others
 * shows up as a treatment effect in exactly the comparison the family exists to
 * make — the one place nobody would look for a config bug.</p>
 *
 * <p>The check is deliberately <b>not</b> a list of expected values. It asserts
 * that nothing differs across a family <i>except</i> the keys declared as its
 * treatment, so a newly added key that differs fails even though this test knows
 * nothing about it. Changing the seed or horizon for a whole family stays a
 * one-line edit per file and keeps passing.</p>
 *
 * <p>Reading the YAML here rather than through the production loader is
 * deliberate: these config files must stay plain, self-contained YAML that runs
 * on an unmodified SimPaths build. Nothing in {@code simpaths.experiment} is
 * involved.</p>
 */
class MacroScenarioConfigTest {

    private static final File CONFIG_DIR = new File("config");

    /** Keys the batch family is allowed to differ on. */
    private static final Set<String> BATCH_TREATMENT = Set.of(
            "model_args.mm_macroModel",
            "model_args.mm_ramseyScenario",
            "model_args.mm_dsgeShockScenario");

    private static final List<String> BATCH_FAMILY = List.of(
            "batch-1-no-macro.yml",
            "batch-2-ramsey-baseline.yml",
            "batch-3-ramsey-counterfactual.yml",
            "batch-4-ramsey-perfect-foresight.yml",
            "batch-5-ramsey-plus-dsge.yml");

    @Test
    @DisplayName("the batch family differs only in which macro layers and scenarios are active")
    void batchFamilyIsCeterisParibus() throws IOException {
        assertFamilyDiffersOnlyIn(BATCH_FAMILY, BATCH_TREATMENT);
    }

    @Test
    @DisplayName("the batch family pins the Ramsey feedback off, so the layers are the only treatment")
    void batchFamilyPinsFeedbackOff() throws IOException {
        for (String name : BATCH_FAMILY) {
            Object v = flatten(read(name)).get("model_args.mm_ramseyFeedbackMargins");
            assertEquals("none", v,
                    name + " must pin model_args.mm_ramseyFeedbackMargins to none; the margins"
                    + " default to employment_and_hours, which would silently add a second treatment");
        }
    }

    @Test
    @DisplayName("macro scenario configs stay plain YAML that a stock SimPaths build can read")
    void macroConfigsUseNoNonStandardKeys() throws IOException {
        // The upstream loader reflects each top-level key onto a SimPathsMultiRun
        // field and, on NoSuchFieldException, prints a stack trace and CONTINUES.
        // A key it does not know therefore does not stop the run - it just drops
        // whatever that key was carrying. So an inheritance-style key here would
        // silently reduce the run to its own contents on an unmodified build, which
        // is why these configs stay self-contained rather than sharing a base file.
        //
        // The recognised set is read from the class the loader actually reflects on,
        // so this cannot drift as upstream adds settings.
        Set<String> known = new LinkedHashSet<>(ARG_MAP_KEYS);
        for (java.lang.reflect.Field f
                : simpaths.experiment.SimPathsMultiRun.class.getDeclaredFields()) {
            known.add(f.getName());
        }

        for (String name : macroConfigFiles()) {
            Map<String, Object> cfg = read(name);
            for (String key : cfg.keySet()) {
                assertTrue(known.contains(key),
                        name + " declares top-level key '" + key + "', which the stock "
                        + "SimPathsMultiRun loader does not recognise. It would be silently "
                        + "ignored rather than rejected, so the run would proceed missing "
                        + "whatever that key carried.");
            }
        }
    }

    /**
     * CONTRACT: every {@code model_args} key beginning {@code mm_} must name a field
     * actually declared on {@link simpaths.model.SimPathsModel}.
     *
     * <p>{@code SimPathsMultiRun.updateParameters} resolves {@code model_args} keys by
     * reflection and, on {@code NoSuchFieldException}, prints a stack trace and
     * <b>continues</b> — the run proceeds at that field's default rather than failing. A
     * typo in an {@code mm_*} key (e.g. in the persistence arm of the recursive-feedback
     * experiment) would therefore run silently at the wrong value while the config claims
     * otherwise. {@link #macroConfigsUseNoNonStandardKeys()} only checks top-level keys
     * ({@code model_args} itself, not what is inside it), so it does not catch this.</p>
     */
    @Test
    @DisplayName("every model_args mm_* key matches a field declared on SimPathsModel")
    void macroConfigsMmKeysMatchDeclaredSimPathsModelFields() throws IOException {
        Set<String> declaredFields = Arrays.stream(simpaths.model.SimPathsModel.class.getDeclaredFields())
                .map(Field::getName)
                .collect(Collectors.toSet());

        for (String name : macroConfigFiles()) {
            Map<String, Object> modelArgs = modelArgs(read(name));
            for (String key : modelArgs.keySet()) {
                if (!key.startsWith("mm_")) {
                    continue;
                }
                assertTrue(declaredFields.contains(key),
                        name + " declares model_args key '" + key + "', which is not a field "
                        + "declared on SimPathsModel. SimPathsMultiRun.updateParameters resolves "
                        + "model_args keys by reflection and silently drops (stack-trace-and-"
                        + "continue) anything it cannot find, so this key would run at its field's "
                        + "default instead of the value configured here.");
            }
        }
    }

    // ---------------------------------------------------------------- helpers

    @SuppressWarnings("unchecked")
    private static Map<String, Object> modelArgs(Map<String, Object> cfg) {
        Object modelArgs = cfg.get("model_args");
        return (modelArgs instanceof Map) ? (Map<String, Object>) modelArgs : Map.of();
    }

    private static void assertFamilyDiffersOnlyIn(List<String> family, Set<String> treatment)
            throws IOException {

        Map<String, Map<String, Object>> flat = new LinkedHashMap<>();
        for (String name : family) {
            flat.put(name, flatten(read(name)));
        }

        Set<String> allKeys = new TreeSet<>();
        flat.values().forEach(m -> allKeys.addAll(m.keySet()));

        String reference = family.get(0);
        for (String key : allKeys) {
            if (treatment.contains(key)) {
                continue;
            }
            Object expected = flat.get(reference).get(key);
            for (String name : family) {
                Object actual = flat.get(name).get(key);
                if (!java.util.Objects.equals(expected, actual)) {
                    fail(String.format(
                            "%s differs from %s on '%s' (%s vs %s), which is not a declared "
                            + "treatment for this family. Either the two runs are no longer "
                            + "ceteris paribus, or '%s' belongs in the treatment set.",
                            name, reference, key, actual, expected, key));
                }
            }
        }
    }

    /** Top-level keys that are argument maps rather than SimPathsMultiRun fields. */
    private static final Set<String> ARG_MAP_KEYS = Set.of(
            "model_args", "innovation_args", "collector_args", "parameter_args");

    /**
     * The configs this test governs: the batch family, plus any other config that
     * sets a macro (mm_*) argument. Configs belonging to the wider model are not
     * this test's business.
     */
    private static List<String> macroConfigFiles() throws IOException {
        Set<String> names = new LinkedHashSet<>(BATCH_FAMILY);

        File[] files = CONFIG_DIR.listFiles((d, n) -> n.endsWith(".yml"));
        assertTrue(files != null && files.length > 0, "config directory must be present");
        for (File f : files) {
            if (flatten(read(f.getName())).keySet().stream()
                    .anyMatch(k -> k.startsWith("model_args.mm_"))) {
                names.add(f.getName());
            }
        }
        return List.copyOf(names);
    }

    private static Map<String, Object> read(String name) throws IOException {
        File file = new File(CONFIG_DIR, name);
        assertTrue(file.isFile(), "missing scenario config: " + file.getPath());
        try (InputStream in = new FileInputStream(file)) {
            Map<String, Object> loaded = new Yaml().load(in);
            return loaded == null ? new LinkedHashMap<>() : loaded;
        }
    }

    /** Flatten one nesting level of argument maps into dotted keys. */
    @SuppressWarnings("unchecked")
    private static Map<String, Object> flatten(Map<String, Object> cfg) {
        Map<String, Object> flat = new LinkedHashMap<>();
        for (Map.Entry<String, Object> e : cfg.entrySet()) {
            if (e.getValue() instanceof Map) {
                for (Map.Entry<String, Object> inner
                        : ((Map<String, Object>) e.getValue()).entrySet()) {
                    flat.put(e.getKey() + "." + inner.getKey(), inner.getValue());
                }
            } else {
                flat.put(e.getKey(), e.getValue());
            }
        }
        return flat;
    }
}
