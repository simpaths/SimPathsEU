package simpaths.model.macro;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Unit tests for DSGEShockScenario.
 *
 * Tests cover:
 * 1. CSV loading and column matching
 * 2. Shock retrieval for specific quarters
 * 3. Missing quarters (default to zero)
 * 4. Partial column specification
 * 5. Validation and error handling
 * 6. Year-level queries (hasShocksForYear)
 */
public class DSGEShockScenarioTest {

    /** Standard model shock names matching Germany v14 model */
    private static final String[] SHOCK_NAMES = {
        "eps_a", "eps_r", "eps_d", "eps_p", "eps_L", "eps_sep", "eps_h", "eps_inv"
    };
    private static final int N_EXO = SHOCK_NAMES.length;

    @TempDir
    Path tempDir;

    private DSGEShockScenario scenario;

    @BeforeEach
    public void setUp() {
        scenario = new DSGEShockScenario(SHOCK_NAMES, N_EXO);
    }

    // ========== Constructor Tests ==========

    @Test
    public void testConstructorValidation() {
        assertThrows(NullPointerException.class,
            () -> new DSGEShockScenario(null, 8));

        assertThrows(IllegalArgumentException.class,
            () -> new DSGEShockScenario(SHOCK_NAMES, 5),
            "Should reject mismatched nExo");
    }

    @Test
    public void testEmptyBeforeLoading() {
        assertFalse(scenario.isLoaded());
        assertEquals(0, scenario.getQuarterCount());
        assertNull(scenario.getScenarioName());
    }

    // ========== Loading Tests ==========

    @Test
    public void testLoadFullScenario() throws IOException {
        Path csv = tempDir.resolve("test_scenario.csv");
        Files.writeString(csv,
            "year,quarter,eps_a,eps_r,eps_d,eps_p,eps_L,eps_sep,eps_h,eps_inv\n" +
            "2025,1,0.0,0.0,0.0,2.0,0.0,0.0,0.0,0.0\n" +
            "2025,2,0.0,0.0,0.0,1.5,0.0,0.0,0.0,0.0\n" +
            "2025,3,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0\n" +
            "2025,4,0.0,0.0,0.0,0.5,0.0,0.0,0.0,0.0\n");

        scenario.loadFromFile(csv);

        assertTrue(scenario.isLoaded());
        assertEquals(4, scenario.getQuarterCount());
        assertEquals("test_scenario.csv", scenario.getScenarioName());
    }

    @Test
    public void testLoadPartialColumns() throws IOException {
        // Only specify eps_p — all other shocks should default to zero
        Path csv = tempDir.resolve("partial.csv");
        Files.writeString(csv,
            "year,quarter,eps_p\n" +
            "2025,1,2.0\n" +
            "2025,2,1.0\n");

        scenario.loadFromFile(csv);

        assertTrue(scenario.isLoaded());
        assertEquals(2, scenario.getQuarterCount());

        // eps_p is at index 3
        double[] q1 = scenario.getShocks(2025, 1);
        assertEquals(N_EXO, q1.length);
        assertEquals(2.0, q1[3], 1e-10, "eps_p should be 2.0 in Q1");
        assertEquals(0.0, q1[0], 1e-10, "eps_a should be 0.0");
        assertEquals(0.0, q1[4], 1e-10, "eps_L should be 0.0");

        double[] q2 = scenario.getShocks(2025, 2);
        assertEquals(1.0, q2[3], 1e-10, "eps_p should be 1.0 in Q2");
    }

    @Test
    public void testLoadMultipleShockColumns() throws IOException {
        Path csv = tempDir.resolve("multi.csv");
        Files.writeString(csv,
            "year,quarter,eps_p,eps_r,eps_a\n" +
            "2026,1,1.5,-0.25,0.5\n" +
            "2026,2,1.0,0.0,0.3\n");

        scenario.loadFromFile(csv);

        double[] q1 = scenario.getShocks(2026, 1);
        assertEquals(0.5, q1[0], 1e-10, "eps_a");    // index 0
        assertEquals(-0.25, q1[1], 1e-10, "eps_r");   // index 1
        assertEquals(1.5, q1[3], 1e-10, "eps_p");     // index 3
    }

    @Test
    public void testCaseInsensitiveColumns() throws IOException {
        Path csv = tempDir.resolve("case.csv");
        Files.writeString(csv,
            "Year,Quarter,EPS_P\n" +
            "2025,1,1.0\n");

        // Header matching is case-insensitive for shock names but year/quarter are lowercased
        // Let's check: findColumn lowercases headers, so "Year" → "year", "Quarter" → "quarter" works
        scenario.loadFromFile(csv);
        assertTrue(scenario.isLoaded());

        double[] q1 = scenario.getShocks(2025, 1);
        assertEquals(1.0, q1[3], 1e-10);
    }

    // ========== Query Tests ==========

    @Test
    public void testGetShocksMissingQuarterReturnsZeros() throws IOException {
        Path csv = tempDir.resolve("sparse.csv");
        Files.writeString(csv,
            "year,quarter,eps_p\n" +
            "2025,1,2.0\n");

        scenario.loadFromFile(csv);

        // Quarter 2 not specified → should return zeros
        double[] q2 = scenario.getShocks(2025, 2);
        assertNotNull(q2);
        assertEquals(N_EXO, q2.length);
        for (double v : q2) {
            assertEquals(0.0, v, 1e-10);
        }

        // Year 2030 not specified → should return zeros
        double[] future = scenario.getShocks(2030, 1);
        for (double v : future) {
            assertEquals(0.0, v, 1e-10);
        }
    }

    @Test
    public void testGetShocksReturnsDefensiveCopy() throws IOException {
        Path csv = tempDir.resolve("copy.csv");
        Files.writeString(csv,
            "year,quarter,eps_p\n" +
            "2025,1,2.0\n");

        scenario.loadFromFile(csv);

        double[] q1a = scenario.getShocks(2025, 1);
        q1a[3] = 999.0;  // Mutate the returned array

        double[] q1b = scenario.getShocks(2025, 1);
        assertEquals(2.0, q1b[3], 1e-10, "Original should be unmodified");
    }

    @Test
    public void testHasShocksForYear() throws IOException {
        Path csv = tempDir.resolve("years.csv");
        Files.writeString(csv,
            "year,quarter,eps_p\n" +
            "2025,1,2.0\n" +
            "2025,3,1.0\n" +
            "2026,2,0.5\n");

        scenario.loadFromFile(csv);

        assertTrue(scenario.hasShocksForYear(2025), "2025 has shocks");
        assertTrue(scenario.hasShocksForYear(2026), "2026 has shocks");
        assertFalse(scenario.hasShocksForYear(2027), "2027 has no shocks");
        assertFalse(scenario.hasShocksForYear(2024), "2024 has no shocks");
    }

    @Test
    public void testHasShocksForYearAllZeros() throws IOException {
        // A year with only zero shocks should return false
        Path csv = tempDir.resolve("zeros.csv");
        Files.writeString(csv,
            "year,quarter,eps_p\n" +
            "2025,1,0.0\n" +
            "2025,2,0.0\n");

        scenario.loadFromFile(csv);

        assertFalse(scenario.hasShocksForYear(2025), "All-zero shocks should count as no shocks");
    }

    // ========== Validation / Error Tests ==========

    @Test
    public void testRejectMissingFile() {
        Path nonexistent = tempDir.resolve("nonexistent.csv");
        assertThrows(IOException.class,
            () -> scenario.loadFromFile(nonexistent));
    }

    @Test
    public void testRejectNoHeader() throws IOException {
        Path csv = tempDir.resolve("empty.csv");
        Files.writeString(csv, "year,quarter,eps_p\n");  // header only, no data

        assertThrows(IllegalArgumentException.class,
            () -> scenario.loadFromFile(csv));
    }

    @Test
    public void testRejectMissingYearColumn() throws IOException {
        Path csv = tempDir.resolve("no_year.csv");
        Files.writeString(csv,
            "quarter,eps_p\n" +
            "1,2.0\n");

        assertThrows(IllegalArgumentException.class,
            () -> scenario.loadFromFile(csv));
    }

    @Test
    public void testRejectMissingQuarterColumn() throws IOException {
        Path csv = tempDir.resolve("no_quarter.csv");
        Files.writeString(csv,
            "year,eps_p\n" +
            "2025,2.0\n");

        assertThrows(IllegalArgumentException.class,
            () -> scenario.loadFromFile(csv));
    }

    @Test
    public void testRejectNoMatchingShockColumns() throws IOException {
        Path csv = tempDir.resolve("no_match.csv");
        Files.writeString(csv,
            "year,quarter,unknown_shock\n" +
            "2025,1,2.0\n");

        assertThrows(IllegalArgumentException.class,
            () -> scenario.loadFromFile(csv));
    }

    @Test
    public void testRejectInvalidQuarter() throws IOException {
        Path csv = tempDir.resolve("bad_quarter.csv");
        Files.writeString(csv,
            "year,quarter,eps_p\n" +
            "2025,5,2.0\n");

        assertThrows(IllegalArgumentException.class,
            () -> scenario.loadFromFile(csv));
    }

    @Test
    public void testRejectDuplicateQuarter() throws IOException {
        Path csv = tempDir.resolve("duplicate.csv");
        Files.writeString(csv,
            "year,quarter,eps_p\n" +
            "2025,1,2.0\n" +
            "2025,1,1.0\n");

        assertThrows(IllegalArgumentException.class,
            () -> scenario.loadFromFile(csv));
    }

    @Test
    public void testRejectInvalidNumber() throws IOException {
        Path csv = tempDir.resolve("bad_number.csv");
        Files.writeString(csv,
            "year,quarter,eps_p\n" +
            "2025,1,abc\n");

        assertThrows(IllegalArgumentException.class,
            () -> scenario.loadFromFile(csv));
    }

    // ========== Comments and Blank Lines ==========

    @Test
    public void testSkipCommentsAndBlankLines() throws IOException {
        Path csv = tempDir.resolve("comments.csv");
        Files.writeString(csv,
            "year,quarter,eps_p\n" +
            "# This is a comment\n" +
            "2025,1,2.0\n" +
            "\n" +
            "// Another comment\n" +
            "2025,2,1.0\n");

        scenario.loadFromFile(csv);

        assertEquals(2, scenario.getQuarterCount());
        assertEquals(2.0, scenario.getShocks(2025, 1)[3], 1e-10);
        assertEquals(1.0, scenario.getShocks(2025, 2)[3], 1e-10);
    }

    // ========== Summary ==========

    @Test
    public void testSummary() throws IOException {
        Path csv = tempDir.resolve("summary.csv");
        Files.writeString(csv,
            "year,quarter,eps_p,eps_a\n" +
            "2025,1,2.0,0.0\n" +
            "2025,2,1.0,0.5\n" +
            "2025,3,0.0,0.0\n" +
            "2025,4,0.0,0.0\n");

        scenario.loadFromFile(csv);

        String summary = scenario.getSummary();
        assertNotNull(summary);
        assertTrue(summary.contains("4 quarters"), "Summary should mention quarter count");
        assertTrue(summary.contains("2025-2025"), "Summary should report the correct single-year range");
    }

    @Test
    public void testSummaryUsesCorrectMultiYearRange() throws IOException {
        Path csv = tempDir.resolve("summary_multi_year.csv");
        Files.writeString(csv,
            "year,quarter,eps_p\n" +
            "2025,4,1.0\n" +
            "2026,1,0.0\n" +
            "2029,4,0.5\n");

        scenario.loadFromFile(csv);

        String summary = scenario.getSummary();
        assertTrue(summary.contains("2025-2029"), "Summary should decode the stored quarter keys back to the correct year range");
        assertTrue(summary.contains("2 with non-zero shocks"), "Summary should still count non-zero quarters correctly");
    }

    @Test
    public void testSummaryEmptyScenario() {
        String summary = scenario.getSummary();
        assertEquals("No scenario loaded", summary);
    }

    // ========== Multi-year Scenario ==========

    @Test
    public void testMultiYearScenario() throws IOException {
        Path csv = tempDir.resolve("multi_year.csv");
        var sb = new StringBuilder("year,quarter,eps_p,eps_r\n");
        // 5 years × 4 quarters = 20 quarters
        for (int y = 2025; y <= 2029; y++) {
            for (int q = 1; q <= 4; q++) {
                double epsp = 2.0 * Math.exp(-0.1 * ((y - 2025) * 4 + q - 1));
                sb.append(String.format("%d,%d,%.4f,0.0%n", y, q, epsp));
            }
        }

        Files.writeString(csv, sb.toString());
        scenario.loadFromFile(csv);

        assertEquals(20, scenario.getQuarterCount());
        assertTrue(scenario.hasShocksForYear(2025));
        assertTrue(scenario.hasShocksForYear(2029));
        assertFalse(scenario.hasShocksForYear(2030));

        // First quarter should have the largest shock
        double firstShock = scenario.getShocks(2025, 1)[3];
        double lastShock = scenario.getShocks(2029, 4)[3];
        assertTrue(firstShock > lastShock, "Shock should decay over time");
    }
}
