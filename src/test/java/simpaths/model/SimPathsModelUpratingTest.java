package simpaths.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import simpaths.data.Parameters;

/**
 * A start year past the last available population loads that population and moves it to the start
 * year ({@link SimPathsModel#moveStartingPopulationToStartYear}). No integration test starts there,
 * so these tests pin the column names to the starting-population schema and run the SQL on a PERSON
 * table built the way setup builds it, from a CSV through {@code CSVREAD}.
 */
class SimPathsModelUpratingTest {

    private static final double FACTOR = 1.25;
    private static final int LAST_POPULATION_YEAR = 2019;
    private static final int START_YEAR = 2023;

    @Test
    @DisplayName("every column the move writes is a column of the starting population")
    void everyColumnTheMoveWritesIsInTheStartingPopulationSchema() {
        List<String> schema = Arrays.asList(Parameters.PERSON_VARIABLES_INITIAL);
        List<String> written = new ArrayList<>(Arrays.asList(SimPathsModel.ASINH_MONETARY_PERSON_COLUMNS));
        written.add("statInterviewYear");
        for (String column : written) {
            assertTrue(schema.contains(column), column + " is not in Parameters.PERSON_VARIABLES_INITIAL;"
                    + " a start year past the last population would fail with 'Column not found'");
        }
    }

    @Test
    @DisplayName("the move uprates each asinh income, sets both years and leaves the other columns alone")
    void moveUpratesIncomesAndSetsTheYears(@TempDir Path tempDir) throws Exception {
        List<String> uprated = Arrays.asList(SimPathsModel.ASINH_MONETARY_PERSON_COLUMNS);
        String[] header = Parameters.PERSON_VARIABLES_INITIAL;
        // Row 1 has an income in every uprated column (asinh values, as in the starting populations);
        // row 2 has none. yPersDispMonth is a level and is not uprated.
        double[] asinhIncomes = {9.78, 7.88, 3.04, 0.0, 4.04};
        List<String> withIncome = new ArrayList<>();
        List<String> withoutIncome = new ArrayList<>();
        for (String column : header) {
            int k = uprated.indexOf(column);
            String other = column.equals("statInterviewYear") ? Integer.toString(LAST_POPULATION_YEAR)
                    : column.equals("yPersDispMonth") ? "1234.5" : "1";
            withIncome.add(column.equals("idPers") ? "1" : k >= 0 ? Double.toString(asinhIncomes[k]) : other);
            withoutIncome.add(column.equals("idPers") ? "2" : k >= 0 ? "0" : other);
        }
        Path csv = tempDir.resolve("population.csv");
        Files.write(csv, List.of(String.join(",", header), String.join(",", withIncome), String.join(",", withoutIncome)));

        Class.forName("org.h2.Driver");
        try (Connection conn = DriverManager.getConnection("jdbc:h2:mem:uprating_" + System.nanoTime(), "sa", "");
             Statement stat = conn.createStatement()) {
            // As in DataParser: the table comes from the CSV, then gets its simulation time.
            stat.execute("CREATE TABLE PERSON AS SELECT * FROM CSVREAD('"
                    + csv.toAbsolutePath().toString().replace('\\', '/').replace("'", "''") + "');"
                    + "ALTER TABLE PERSON ADD COLUMN simulation_time INT DEFAULT " + LAST_POPULATION_YEAR + ";");

            SimPathsModel.moveStartingPopulationToStartYear(stat, START_YEAR, FACTOR);

            try (ResultSet rs = stat.executeQuery("SELECT * FROM PERSON WHERE idPers = 1")) {
                assertTrue(rs.next());
                for (int k = 0; k < asinhIncomes.length; k++) {
                    double expected = asinh(Math.sinh(asinhIncomes[k]) * FACTOR);
                    assertEquals(expected, rs.getDouble(uprated.get(k)), 1e-6,
                            uprated.get(k) + " should hold asinh(" + FACTOR + " x sinh(old))");
                }
                assertEquals(1234.5, rs.getDouble("yPersDispMonth"), 0.0, "yPersDispMonth is not uprated");
                assertYears(rs);
            }
            try (ResultSet rs = stat.executeQuery("SELECT * FROM PERSON WHERE idPers = 2")) {
                assertTrue(rs.next());
                for (String column : uprated) {
                    assertEquals(0.0, rs.getDouble(column), 0.0, column + ": no income stays no income");
                }
                assertYears(rs);
            }
        }
    }

    private static void assertYears(ResultSet rs) throws Exception {
        assertEquals(START_YEAR, rs.getInt("simulation_time"), "simulation_time should be the start year");
        assertEquals(START_YEAR, rs.getInt("statInterviewYear"), "statInterviewYear should be the start year");
    }

    private static double asinh(double x) {
        return Math.log(x + Math.sqrt(x * x + 1.0));
    }
}
