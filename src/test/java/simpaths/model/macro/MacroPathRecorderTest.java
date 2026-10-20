package simpaths.model.macro;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class MacroPathRecorderTest {

    @TempDir
    Path tempDir;

    @Test
    void testRecordRamseyOnlyYearExportsConfiguredSchema() throws IOException {
        MacroPathRecorder recorder = new MacroPathRecorder();
        recorder.setVariableNames(
                new String[]{"c", "R", "pi", "w", "v", "n", "h", "x", "L", "k", "inv", "sep_shock", "d_shock"},
                new String[]{"y", "d", "gap", "w_star", "u", "u_rate", "m", "mc", "theta"},
                new String[]{"eps_a", "eps_r", "eps_d", "eps_p", "eps_L", "eps_sep", "eps_h", "eps_inv"});

        Map<String, Double> trends = new LinkedHashMap<>();
        trends.put("w", 1.5);
        trends.put("y", 2.5);
        trends.put("c", 3.5);
        trends.put("inv", 4.5);
        trends.put("k", 5.5);
        trends.put("l_level", 6.5);
        trends.put("participation_rate", 7.5);
        trends.put("cat_0_share", 8.5);
        trends.put("cat_1_share", 9.5);
        trends.put("cat_2_share", 10.5);
        trends.put("cat_3_share", 11.5);
        trends.put("cat_0_meanHours", 12.5);
        trends.put("cat_1_meanHours", 13.5);
        trends.put("cat_2_meanHours", 14.5);
        trends.put("cat_3_meanHours", 15.5);
        recorder.setCurrentTrends(trends);

        recorder.recordRamseyOnlyYear(2030);

        Path exportDir = tempDir.resolve("csv");
        recorder.exportToCSV(exportDir.toString(), "MacroPaths.csv");
        List<String> lines = Files.readAllLines(exportDir.resolve("MacroPaths.csv"));

        assertEquals(5, lines.size(), "Ramsey-only export should contain header + 4 quarters");

        String header = lines.get(0);
        assertTrue(header.contains(",c,R,pi,w,v,n,h,x,L,k,inv,sep_shock,d_shock,"),
                "Header should use configured state schema from model_info ordering");
        assertTrue(header.contains(",y,d,gap,w_star,u,u_rate,m,mc,theta,"),
                "Header should use configured jump schema from model_info ordering");
        assertTrue(header.contains(",eps_a,eps_r,eps_d,eps_p,eps_L,eps_sep,eps_h,eps_inv,"),
                "Header should use configured shock schema from model_info ordering");
        assertFalse(header.contains("match_shock"), "Header should not fall back to stale match_shock schema");
        assertFalse(header.contains("eps_match"), "Header should not fall back to stale eps_match schema");

        Map<String, Integer> columns = headerIndex(header);
        String[] firstRow = lines.get(1).split(",");
        assertEquals("1", firstRow[columns.get("run")]);
        assertEquals("2030", firstRow[columns.get("year")]);
        assertEquals("1", firstRow[columns.get("quarter")]);
        assertEquals("0", firstRow[columns.get("w")], "Ramsey-only cycle column should be zero");
        assertEquals("1.500000000", firstRow[columns.get("w_trend")]);
        assertEquals("1.500000000", firstRow[columns.get("w_total")]);
        assertEquals("2.500000000", firstRow[columns.get("y_trend")]);
        assertEquals("2.500000000", firstRow[columns.get("y_total")]);
        assertEquals("3.500000000", firstRow[columns.get("c_trend")]);
        assertEquals("3.500000000", firstRow[columns.get("c_total")]);
        assertEquals("6.500000000", firstRow[columns.get("l_level")]);
        assertEquals("7.500000000", firstRow[columns.get("participation_rate")]);
        assertEquals("8.500000000", firstRow[columns.get("cat_0_share")]);
        assertEquals("9.500000000", firstRow[columns.get("cat_1_share")]);
        assertEquals("10.50000000", firstRow[columns.get("cat_2_share")]);
        assertEquals("11.50000000", firstRow[columns.get("cat_3_share")]);
        assertEquals("12.50000000", firstRow[columns.get("cat_0_meanHours")]);
        assertEquals("13.50000000", firstRow[columns.get("cat_1_meanHours")]);
        assertEquals("14.50000000", firstRow[columns.get("cat_2_meanHours")]);
        assertEquals("15.50000000", firstRow[columns.get("cat_3_meanHours")]);
    }

        @Test
        void testDefaultFallbackSchemaMatchesCurrentExportLayout() throws IOException {
        MacroPathRecorder recorder = new MacroPathRecorder();
        recorder.recordRamseyOnlyYear(2035);

        Path exportDir = tempDir.resolve("default-schema");
        recorder.exportToCSV(exportDir.toString(), "MacroPaths.csv");
        List<String> lines = Files.readAllLines(exportDir.resolve("MacroPaths.csv"));

        String header = lines.get(0);
        assertTrue(header.contains(",c,R,pi,w,v,n,h,x,L,k,inv,sep_shock,d_shock,"),
            "Default fallback state schema should match current export layout");
        assertTrue(header.contains(",y,d,gap,w_star,u,u_rate,m,mc,theta,"),
            "Default fallback jump schema should match current export layout");
        assertTrue(header.contains(",eps_a,eps_r,eps_d,eps_p,eps_L,eps_sep,eps_h,eps_inv,"),
            "Default fallback shock schema should match current export layout");
        assertFalse(header.contains("match_shock"), "Fallback header should not include removed match_shock");
        assertFalse(header.contains("eps_match"), "Fallback header should not include removed eps_match");
        }

    @Test
    void testRecordQuarterExportsTrendPlusCycleTotals() throws IOException {
        MacroPathRecorder recorder = new MacroPathRecorder();
        recorder.setVariableNames(
                new String[]{"w", "k", "s2", "s3", "s4", "s5", "s6", "s7", "s8"},
                new String[]{"y", "c", "inv", "j3", "j4", "j5", "j6", "j7", "j8", "j9"},
                new String[]{"eps_L"});

        Map<String, Double> trends = new LinkedHashMap<>();
        trends.put("w", 1.0);
        trends.put("y", 2.0);
        trends.put("c", 3.0);
        trends.put("inv", 4.0);
        trends.put("k", 5.0);
        recorder.setCurrentTrends(trends);

        double[] states = new double[9];
        double[] jumps = new double[10];
        states[0] = 0.25;  // w
        states[1] = 0.75;  // k
        jumps[0] = 0.50;   // y
        jumps[1] = 0.60;   // c
        jumps[2] = 0.70;   // inv

        DSGEState.VarIndices customIndices = new DSGEState.VarIndices(
            Map.of(
                "R", 2,
                "w", 0,
                "v", 3,
                "n", 4,
                "h", 5,
                "x", 6,
                "L", 7,
                "sep_shock", 8,
                "d_shock", 8),
            Map.of(
                "y", 0,
                "d", 1,
                "gap", 2,
                "pi", 3,
                "w_star", 4,
                "u", 5,
                "u_rate", 6,
                "m", 7,
                "mc", 8,
                "theta", 9));

        recorder.recordQuarter(2031, 2, new DSGEState(states, jumps, customIndices), new double[]{0.125});

        Path exportDir = tempDir.resolve("csv");
        recorder.exportToCSV(exportDir.toString(), "MacroPaths.csv");
        List<String> lines = Files.readAllLines(exportDir.resolve("MacroPaths.csv"));

        assertEquals(2, lines.size(), "Quarter export should contain header + 1 row");

        Map<String, Integer> columns = headerIndex(lines.get(0));
        String[] row = lines.get(1).split(",");
        assertEquals("1", row[columns.get("run")]);
        assertEquals("2031", row[columns.get("year")]);
        assertEquals("2", row[columns.get("quarter")]);
        assertEquals("0.2500000000", row[columns.get("w")]);
        assertEquals("0.5000000000", row[columns.get("y")]);
        assertEquals("0.1250000000", row[columns.get("eps_L")]);
        assertEquals("1.000000000", row[columns.get("w_trend")]);
        assertEquals("1.250000000", row[columns.get("w_total")]);
        assertEquals("2.000000000", row[columns.get("y_trend")]);
        assertEquals("2.500000000", row[columns.get("y_total")]);
        assertEquals("3.000000000", row[columns.get("c_trend")]);
        assertEquals("3.600000000", row[columns.get("c_total")]);
        assertEquals("4.000000000", row[columns.get("inv_trend")]);
        assertEquals("4.700000000", row[columns.get("inv_total")]);
        assertEquals("5.000000000", row[columns.get("k_trend")]);
        assertEquals("5.750000000", row[columns.get("k_total")]);
    }

    @Test
    void testExportToCsvAppendsRunsWithRunColumn() throws IOException {
        Path exportDir = tempDir.resolve("multi-run");

        MacroPathRecorder firstRun = new MacroPathRecorder();
        firstRun.recordRamseyOnlyYear(2030);
        firstRun.exportToCSV(exportDir.toString(), "MacroPaths.csv");

        MacroPathRecorder secondRun = new MacroPathRecorder();
        secondRun.recordRamseyOnlyYear(2031);
        secondRun.exportToCSV(exportDir.toString(), "MacroPaths.csv");

        List<String> lines = Files.readAllLines(exportDir.resolve("MacroPaths.csv"));
        assertEquals(9, lines.size(), "Two runs should append 8 quarterly rows under one header");

        Map<String, Integer> columns = headerIndex(lines.get(0));
        String[] firstRunRow = lines.get(1).split(",");
        String[] secondRunRow = lines.get(5).split(",");

        assertEquals("1", firstRunRow[columns.get("run")]);
        assertEquals("2030", firstRunRow[columns.get("year")]);
        assertEquals("2", secondRunRow[columns.get("run")]);
        assertEquals("2031", secondRunRow[columns.get("year")]);
    }

    @Test
    void testFeedbackDiagnosticColumnsExported() throws IOException {
        MacroPathRecorder recorder = new MacroPathRecorder();
        recorder.recordRamseyOnlyYear(2025);
        recorder.amendTrendForYear(2025, "n_realized_gap", 2.5);
        recorder.amendTrendForYear(2025, "w_trend_revision", -0.6);

        Path exportDir = tempDir.resolve("feedback-columns");
        recorder.exportToCSV(exportDir.toString(), "MacroPaths.csv");
        List<String> lines = Files.readAllLines(exportDir.resolve("MacroPaths.csv"));

        String header = lines.get(0);
        assertTrue(header.contains("n_realized_gap"), "Header should carry the realized-gap diagnostic");
        assertTrue(header.contains("w_trend_revision"), "Header should carry the wage-revision diagnostic");

        Map<String, Integer> columns = headerIndex(header);
        String[] firstRow = lines.get(1).split(",");
        assertEquals(2.5, Double.parseDouble(firstRow[columns.get("n_realized_gap")]), 1e-9);
        assertEquals(-0.6, Double.parseDouble(firstRow[columns.get("w_trend_revision")]), 1e-9);
    }

    private static Map<String, Integer> headerIndex(String headerLine) {
        String[] header = headerLine.split(",");
        Map<String, Integer> index = new LinkedHashMap<>();
        for (int i = 0; i < header.length; i++) {
            index.put(header[i], i);
        }
        return index;
    }
}