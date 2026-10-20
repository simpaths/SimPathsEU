package simpaths.model.macro;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Contract #18: every committed bundle must be built from the inputs tracked next to
 * it. The MATLAB exporter writes BUNDLE_PROVENANCE.txt with a SHA-256 per input
 * (MODEL_ROOT/internal/write_bundle_provenance.m): seven inputs (the frozen model, the
 * Dynare datafile, the Stata levels CSV, the growth-params template,
 * Macromodel_template.mod, the country calibration .mod and
 * input/{CC}/align_popProjections.xlsx), then the bundle folder's own exporter files.
 * This test checks every MacroModel folder under input/ (each must hold policy_A.csv),
 * recomputes the hashes from the working tree, and fails on a committed
 * BUNDLE_NOT_VERIFIED.txt, so a PR that changes any of those files without
 * re-exporting goes red in CI. No MATLAB on the runner.
 *
 * The failure message names the repair that fits what failed: a changed or missing
 * input needs the full workflow with estimation, because the frozen model and the
 * Dynare datafile are built from the inputs and the skip-estimation re-export would
 * re-hash the edit around an unchanged posterior; a changed bundle file alone needs
 * only the skip-estimation re-export.
 *
 * Text inputs (kind "t") are hashed with CR bytes dropped: the repository is CRLF
 * on Windows checkouts and LF on Linux CI. MODEL_ROOT/internal/sha256_file.m applies
 * the same rule; the two share the known digest asserted below.
 */
class BundleProvenanceTest {

    /** The model root relative to the repository root; must agree with internal/model_location.m. */
    static final String MODEL_ROOT = "input_processing/macromodel";
    private static final Path INPUT = Paths.get("input");
    private static final String KNOWN_DIGEST =
            "492d5ea496056f1a6a6592241032fab764c321596317930b4fa0e1e8bc3b7470";

    /** The re-export that rebuilds the whole bundle from the tracked inputs, without re-estimating. */
    static String reexport(String country) {
        return "re-export without re-estimating: from " + MODEL_ROOT + "/ in MATLAB run "
                + "run_full_workflow('" + country + "', 'skip_estimation', true, 'skip_frozen', true, "
                + "'skip_postestimation', true) (needs MATLAB + Dynare, about five minutes), then commit "
                + "the bundle folder together with the changed input; see " + MODEL_ROOT + "/README.md, "
                + "\"Verifying it\"";
    }

    /** The full workflow with estimation: the frozen model and the datafile are rebuilt from the inputs. */
    static String reestimate(String country, List<String> inputs) {
        String frozen = MODEL_ROOT + "/Macromodel_" + country + "_frozen.mod";
        String datafile = MODEL_ROOT + "/data/data_for_dynare_" + country + ".csv";
        return "re-estimate and re-export: " + String.join(", ", inputs) + " changed; the frozen model and "
                + "the Ramsey datafile are rebuilt from the tracked inputs, so a re-export without "
                + "re-estimating would keep the old posterior. "
                + "From " + MODEL_ROOT + "/ in MATLAB run run_full_workflow('" + country + "') (with "
                + "estimation; needs MATLAB + Dynare, about five minutes for Poland), then commit " + frozen
                + ", " + datafile + " and the bundle folder together with the changed input; see "
                + MODEL_ROOT + "/README.md, \"Verifying it\"";
    }

    /**
     * The repair for the listed failing paths: any path outside the bundle's own folder is an
     * input and needs the workflow with estimation; bundle files alone need the re-export.
     */
    static String repair(String country, String ownPrefix, List<String> failed) {
        List<String> inputs = failed.stream().filter(p -> !p.startsWith(ownPrefix)).toList();
        return inputs.isEmpty() ? reexport(country) : reestimate(country, inputs);
    }

    static String sha256(Path file, boolean text) throws IOException, NoSuchAlgorithmException {
        byte[] bytes = Files.readAllBytes(file);
        if (text) {
            byte[] kept = new byte[bytes.length];
            int n = 0;
            for (byte b : bytes) {
                if (b != '\r') kept[n++] = b;
            }
            bytes = Arrays.copyOf(kept, n);
        }
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(bytes);
        StringBuilder sb = new StringBuilder(64);
        for (byte b : digest) sb.append(String.format("%02x", b));
        return sb.toString();
    }

    /** Every committed bundle: each input/{CC}/MacroModel/ folder; checkBundle requires policy_A.csv in it. */
    static List<Path> committedBundles() throws IOException {
        List<Path> bundles = new ArrayList<>();
        try (var countries = Files.list(INPUT)) {
            for (Path country : (Iterable<Path>) countries.sorted()::iterator) {
                Path bundle = country.resolve("MacroModel");
                if (Files.isDirectory(bundle)) bundles.add(bundle);
            }
        }
        return bundles;
    }

    @Test
    void crlfAndLfHashAlikeInTextMode(@TempDir Path dir) throws Exception {
        Path lf = dir.resolve("lf.csv");
        Path crlf = dir.resolve("crlf.csv");
        Files.write(lf, "a,b\n1,2\n".getBytes(StandardCharsets.US_ASCII));
        Files.write(crlf, "a,b\r\n1,2\r\n".getBytes(StandardCharsets.US_ASCII));
        assertEquals(KNOWN_DIGEST, sha256(lf, true),
                "must agree with " + MODEL_ROOT + "/tests/test_bundle_provenance.m");
        assertEquals(sha256(lf, true), sha256(crlf, true), "text mode ignores CR");
        assertNotEquals(sha256(lf, false), sha256(crlf, false), "raw mode sees CR");
    }

    @Test
    void repairNamesTheWorkflowThatFitsTheFailure() {
        String own = "input/PL/MacroModel/";
        String template = MODEL_ROOT + "/Macromodel_template.mod";
        assertTrue(repair("Poland", own, List.of(own + "policy_A.csv")).startsWith("re-export without re-estimating"),
                "a bundle file alone needs the skip recipe");
        assertTrue(repair("Poland", own, List.of(template)).startsWith("re-estimate and re-export"),
                "an input needs the workflow with estimation");
        assertTrue(repair("Poland", own, List.of(own + "policy_A.csv", template)).startsWith("re-estimate and re-export"),
                "an input together with a bundle file still needs estimation");
        assertTrue(repair("Poland", own, List.of("input/PL/align_popProjections.xlsx")).contains("run_full_workflow('Poland')"),
                "the population workbook is an input too");
        assertTrue(repair("Poland", own, List.of(template)).contains(MODEL_ROOT + "/Macromodel_Poland_frozen.mod"),
                "the full recipe names the frozen model to commit");
    }

    @Test
    void everyCommittedBundleMatchesItsTrackedInputs() throws Exception {
        List<Path> bundles = committedBundles();
        assertTrue(bundles.contains(INPUT.resolve("PL").resolve("MacroModel")),
                "the tracked PL MacroModel bundle is missing; found " + bundles);
        for (Path bundle : bundles) {
            checkBundle(bundle);
        }
    }

    private static void checkBundle(Path bundle) throws Exception {
        String cc = bundle.getParent().getFileName().toString();
        String ownPrefix = "input/" + cc + "/MacroModel/";
        assertFalse(Files.exists(bundle.resolve("BUNDLE_NOT_VERIFIED.txt")),
                bundle + " carries BUNDLE_NOT_VERIFIED.txt: a refused bundle is never committed, "
                + "and SimPaths refuses to start on it; re-export it");
        Path provenance = bundle.resolve("BUNDLE_PROVENANCE.txt");
        assertTrue(Files.exists(provenance),
                bundle + " has no BUNDLE_PROVENANCE.txt: re-export it from " + MODEL_ROOT + "/ "
                + "(the exporters write the file)");

        String country = null;
        List<String> hashed = new ArrayList<>();
        List<String> failures = new ArrayList<>();
        List<String> failedPaths = new ArrayList<>();
        for (String line : Files.readAllLines(provenance)) {
            if (line.startsWith("country ")) {
                country = line.substring("country ".length()).trim();
                continue;
            }
            if (!line.startsWith("sha256 ")) continue;
            String[] p = line.split(" ", 4);
            assertEquals(4, p.length, "malformed provenance line in " + provenance + ": " + line);
            assertTrue(p[1].equals("t") || p[1].equals("b"),
                    "unknown kind '" + p[1] + "' in " + provenance + ": " + line);
            Path input = Paths.get(p[3]);
            if (!Files.exists(input)) {
                failures.add("input no longer exists: " + p[3]);
                failedPaths.add(p[3]);
                continue;
            }
            String actual = sha256(input, p[1].equals("t"));
            if (!actual.equals(p[2])) {
                failures.add(p[3] + " changed since the bundle was exported");
                failedPaths.add(p[3]);
            }
            hashed.add(p[3]);
        }
        assertNotNull(country, provenance + " has no 'country' line");
        assertTrue(Files.exists(bundle.resolve("policy_A.csv")),
                bundle + " has no policy_A.csv, so its DSGE half is missing; " + reexport(country));
        assertTrue(failures.isEmpty(),
                bundle + " is stale; " + repair(country, ownPrefix, failedPaths) + ":\n  "
                + String.join("\n  ", failures));
        for (String required : List.of(
                MODEL_ROOT + "/Macromodel_" + country + "_frozen.mod",
                MODEL_ROOT + "/data/data_for_dynare_" + country + ".csv",
                MODEL_ROOT + "/data/data_for_dynare_levels_" + country + ".csv",
                MODEL_ROOT + "/country_params/" + country + "_growth_params.json",
                MODEL_ROOT + "/Macromodel_template.mod",
                MODEL_ROOT + "/country_params/" + country + "_calibration.mod",
                "input/" + cc + "/align_popProjections.xlsx")) {
            assertTrue(hashed.contains(required),
                    required + " must be among the hashed inputs of " + bundle + ", got " + hashed
                    + "; the bundle was exported without it (a Ramsey-only export of a bundle with "
                    + "no DSGE-half lines?); " + reestimate(country, List.of(required)));
        }
        for (String own : List.of("policy_A.csv", "growth_params_" + country + ".json", "SIMPATHS_INTERFACE.md")) {
            assertTrue(hashed.contains(ownPrefix + own),
                    "the bundle's own file " + own + " must be among the hashed lines of " + bundle
                    + "; " + reexport(country));
        }
    }
}
