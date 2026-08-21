package simpaths.model.macro;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The two scenario readers parse the same family of files and must agree on the
 * two things they had silently drifted apart on.
 *
 * <p><b>NaN.</b> {@code Double.parseDouble("NaN")} succeeds. {@link RamseyScenario}
 * rejected non-finite values; {@link DSGEShockScenario} did not, so a NaN in a
 * shock column entered the state vector — and because every comparison against
 * NaN is false, the ±bound stability guard did not fire either.</p>
 *
 * <p><b>Trailing empty fields.</b> {@code split(",")} discards them, so a row
 * ending in {@code ,} produced fewer columns than the header declared and the
 * final column was never assigned.</p>
 */
class ScenarioLoaderParityTest {

    private static final String[] SHOCK_NAMES = {
        "eps_a", "eps_r", "eps_d", "eps_p", "eps_L", "eps_sep", "eps_h", "eps_inv"
    };

    private static Path write(Path dir, String name, String body) throws IOException {
        Path p = dir.resolve(name);
        Files.writeString(p, body);
        return p;
    }

    private static DSGEShockScenario dsge() {
        return new DSGEShockScenario(SHOCK_NAMES, SHOCK_NAMES.length);
    }

    @Test
    @DisplayName("both readers reject a NaN cell, naming it as non-finite")
    void bothRejectNaN(@TempDir Path dir) throws IOException {
        Path d = write(dir, "dsge_nan.csv", "year,quarter,eps_a,eps_p\n2030,1,0.5,NaN\n");
        Path r = write(dir, "ramsey_nan.csv", "year,g_A,delta\n2030,0.01,NaN\n");

        IllegalArgumentException a = assertThrows(IllegalArgumentException.class,
                () -> dsge().loadFromFile(d));
        IllegalArgumentException b = assertThrows(IllegalArgumentException.class,
                () -> new RamseyScenario().loadFromFile(r));

        assertTrue(a.getMessage().contains("non-finite"),
                "DSGE reader must name the non-finite value: " + a.getMessage());
        assertTrue(b.getMessage().contains("non-finite"),
                "Ramsey reader must name the non-finite value: " + b.getMessage());
    }

    @Test
    @DisplayName("both readers reject an Infinity cell")
    void bothRejectInfinity(@TempDir Path dir) throws IOException {
        Path d = write(dir, "dsge_inf.csv", "year,quarter,eps_a\n2030,1,Infinity\n");
        Path r = write(dir, "ramsey_inf.csv", "year,g_A\n2030,-Infinity\n");

        assertThrows(IllegalArgumentException.class, () -> dsge().loadFromFile(d));
        assertThrows(IllegalArgumentException.class, () -> new RamseyScenario().loadFromFile(r));
    }

    @Test
    @DisplayName("a trailing empty field is a present-but-blank column, not a missing one")
    void trailingEmptyFieldIsKept(@TempDir Path dir) throws IOException {
        // The last column is declared in the header and left blank in the data row.
        // Under split(",") the row yields one part fewer than the header declares.
        Path d = write(dir, "dsge_trailing.csv", "year,quarter,eps_a,eps_p\n2030,1,0.5,\n");
        DSGEShockScenario s = dsge();
        s.loadFromFile(d);
        assertTrue(s.hasShocksForYear(2030), "scenario should load despite the blank trailing field");

        Path r = write(dir, "ramsey_trailing.csv", "year,g_A,delta\n2030,0.01,\n");
        RamseyScenario rs = new RamseyScenario();
        rs.loadFromFile(r);
        assertTrue(rs.hasAnyDeviations(), "scenario should load despite the blank trailing field");
    }

    @Test
    @DisplayName("valid finite values still load")
    void finiteValuesLoad(@TempDir Path dir) throws IOException {
        Path d = write(dir, "dsge_ok.csv", "year,quarter,eps_a\n2030,1,1.5\n2030,2,-0.25\n");
        DSGEShockScenario s = dsge();
        s.loadFromFile(d);
        assertTrue(s.hasShocksForYear(2030));

        Path r = write(dir, "ramsey_ok.csv", "year,g_A\n2030,0.012\n2031,0.011\n");
        RamseyScenario rs = new RamseyScenario();
        rs.loadFromFile(r);
        assertTrue(rs.hasAnyDeviations());
    }

    @Test
    @DisplayName("MacroCsv.splitRow keeps trailing empty fields and drops a stray CR")
    void splitRowKeepsTrailingFields() {
        assertEquals(4, MacroCsv.splitRow("2030,1,0.5,").length);
        assertEquals(5, MacroCsv.splitRow("2030,1,0.5,,").length);
        assertEquals(3, MacroCsv.splitRow("a,b,c\r").length);
        assertEquals("c", MacroCsv.splitRow("a,b,c\r")[2]);
    }
}
