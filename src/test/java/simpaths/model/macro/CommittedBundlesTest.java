package simpaths.model.macro;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.stream.Stream;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import static org.junit.jupiter.api.Assertions.*;

/**
 * The other macro tests pin the Java import against Poland's bundle. Every committed bundle
 * (each input/{CC}/MacroModel/, the set BundleProvenanceTest checks) is read by the same code,
 * so each must pass the same import checks: the DSGE half loads past the contract guards and
 * replays MATLAB's exported impulse response for every shock it ships one for, and the Ramsey
 * half solves its forward projection from the handoff state and carries a growing wage trend.
 */
class CommittedBundlesTest {

    /** The key_shocks of export_dynamic_for_simpaths: eps_L, eps_a, eps_d, eps_r, eps_h, eps_inv. */
    private static final int EXPORTED_IRFS = 6;

    static Stream<Path> committedBundles() throws IOException {
        return BundleProvenanceTest.committedBundles().stream();
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("committedBundles")
    void dsgeImpulseResponsesMatchMatlab(Path bundle) throws IOException {
        DSGEModel model = new DSGEModel();
        model.loadFromDirectory(bundle.toString());
        assertTrue(model.isLoaded(), bundle + ": the load guards rejected the bundle");

        int replayed = 0;
        String[] shocks = model.getShockNames();
        for (int j = 0; j < shocks.length; j++) {
            if (!Files.exists(bundle.resolve("irfs_" + shocks[j] + ".csv"))) continue;
            // eps_L and eps_h arrive from SimPaths in percent; every other shock in sigma units.
            boolean sigmaUnits = j != model.getIdxEpsL() && j != model.getIdxEpsH();
            DSGEIrfParityTest.assertIrfMatches(bundle.toString(), shocks[j], sigmaUnits);
            replayed++;
        }
        assertEquals(EXPORTED_IRFS, replayed, bundle + ": expected an exported IRF for "
                + EXPORTED_IRFS + " shocks; re-export the bundle");
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("committedBundles")
    void ramseyTrendSolvesAndGrows(Path bundle) throws IOException {
        MacroModelManager manager = new MacroModelManager();
        manager.setUseRamseyTrend(true);
        manager.initializeRamseyTrend(bundle.toString());
        assertTrue(manager.getRamseyTrend().isSolved(), bundle + ": the Ramsey forward projection did not solve");

        manager.advanceRamseyTrend();
        double firstYear = manager.getCapitalDeepeningWageAdjustment();
        double tenthYear = firstYear;
        for (int year = 2; year <= 10; year++) {
            manager.advanceRamseyTrend();
            tenthYear = manager.getCapitalDeepeningWageAdjustment();
            assertTrue(Double.isFinite(tenthYear), bundle + ": non-finite wage trend in year " + year);
        }
        // Every template has positive labour-augmenting TFP growth, so the trend wage rises.
        assertTrue(tenthYear > firstYear, String.format(
                "%s: the Ramsey wage trend does not grow over ten years (year 1 %.4f%%, year 10 %.4f%%)",
                bundle, firstYear, tenthYear));
    }
}
