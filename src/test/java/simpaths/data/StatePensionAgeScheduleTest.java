package simpaths.data;

import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import simpaths.model.enums.Gender;

import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Tests of the state pension age tables in input/<CC>/state_pension_age.xlsx and of their loader. */
public class StatePensionAgeScheduleTest {

    // The earliest year a lookup asks for: the earliest start year (2011) minus one, for the lagged regressors.
    // The EUROMOD system years used for the donor keys start in 2011 for every country.
    private static final int EARLIEST_YEAR_NEEDED = 2010;

    private static final String[] HEADER = {"year", "Male", "Female"};

    @TempDir
    Path tempDir;

    private static StatePensionAgeSchedule loadCountry(String country) {
        return StatePensionAgeSchedule.load(Path.of("input", country, StatePensionAgeSchedule.FILE_NAME).toString());
    }

    private static void assertAges(StatePensionAgeSchedule schedule, int year, int male, int female) {
        assertEquals(male, schedule.get(year, Gender.Male), "men, " + year);
        assertEquals(female, schedule.get(year, Gender.Female), "women, " + year);
    }

    @Test
    @DisplayName("Every country's table loads and covers the earliest year a lookup asks for")
    public void everyCountryLoadsAndCoversEarliestYear() {
        for (String country : new String[]{"PL", "ES", "EL", "IT", "HU"}) {
            StatePensionAgeSchedule schedule = loadCountry(country);
            assertTrue(schedule.getFirstYear() <= EARLIEST_YEAR_NEEDED, country + " starts in " + schedule.getFirstYear());
        }
    }

    @Test
    @DisplayName("PL ages match the PL estimation: 65/60, and 66/61 in 2016-2017")
    public void polandMatchesEstimation() {
        StatePensionAgeSchedule pl = loadCountry("PL");
        assertAges(pl, 2010, 65, 60);
        assertAges(pl, 2015, 65, 60);
        assertAges(pl, 2016, 66, 61);
        assertAges(pl, 2017, 66, 61);
        assertAges(pl, 2018, 65, 60);
    }

    @Test
    @DisplayName("ES ages are the statutory age rounded down, as in the ES estimation")
    public void spainRoundsDown() {
        StatePensionAgeSchedule es = loadCountry("ES");
        assertAges(es, 2017, 65, 65);
        assertAges(es, 2020, 65, 65);    // 65 years 10 months
        assertAges(es, 2021, 66, 66);
        assertAges(es, 2026, 66, 66);    // 66 years 10 months
        assertAges(es, 2027, 67, 67);
    }

    @Test
    @DisplayName("A year after the last row takes the last row's ages; a year before the first row is an error")
    public void yearsOutsideTheTable() {
        StatePensionAgeSchedule es = loadCountry("ES");
        assertAges(es, es.getLastYear() + 40, 67, 67);
        assertThrows(IllegalArgumentException.class, () -> es.get(es.getFirstYear() - 1, Gender.Male));
    }

    @Test
    @DisplayName("Blank rows after the last year are ignored")
    public void trailingBlankRowsAreIgnored() throws IOException {
        String file = write(StatePensionAgeSchedule.SHEET_NAME, HEADER, new Object[][]{
                {2020, 65, 60}, {2021, 66, 61}, {null, null, null}, {"", null, null}});
        StatePensionAgeSchedule schedule = StatePensionAgeSchedule.load(file);
        assertEquals(2020, schedule.getFirstYear());
        assertEquals(2021, schedule.getLastYear());
        assertAges(schedule, 2021, 66, 61);
    }

    @Test
    @DisplayName("A missing file, sheet or column fails at load")
    public void missingFileSheetOrColumn() throws IOException {
        assertFailure("not found", tempDir.resolve("absent.xlsx").toString());
        assertFailure("has no sheet", write("Retirement_age", HEADER, new Object[][]{{2020, 65, 60}}));
        assertFailure("has no column Female", write(StatePensionAgeSchedule.SHEET_NAME, new String[]{"year", "Male"},
                new Object[][]{{2020, 65}}));
    }

    @Test
    @DisplayName("Missing years, implausible ages and fractional ages fail at load")
    public void invalidRowsFail() throws IOException {
        assertFailure("consecutive", write(StatePensionAgeSchedule.SHEET_NAME, HEADER,
                new Object[][]{{2020, 65, 60}, {2022, 65, 60}}));
        assertFailure("plausible range", write(StatePensionAgeSchedule.SHEET_NAME, HEADER,
                new Object[][]{{2020, 65, 45}}));
        assertFailure("not a whole number", write(StatePensionAgeSchedule.SHEET_NAME, HEADER,
                new Object[][]{{2020, 65.5, 60}}));
        assertFailure("is not a number", write(StatePensionAgeSchedule.SHEET_NAME, HEADER,
                new Object[][]{{2020, 65, null}}));
    }

    @Test
    void scenarioCanRepeatBaselinePensionAgesWithColumnsInADifferentOrder() throws IOException {
        String baseline = write(StatePensionAgeSchedule.SHEET_NAME, HEADER, new Object[][]{
                {2020, 65, 60}, {2021, 66, 61}});
        String scenario = write(StatePensionAgeSchedule.SHEET_NAME, new String[]{"Female", "year", "Male"},
                new Object[][]{{60, 2020, 65}, {61, 2021, 66}});

        StatePensionAgeSchedule schedule = StatePensionAgeSchedule.loadMatchingBaseline(baseline, scenario);
        assertAges(schedule, 2020, 65, 60);
        assertAges(schedule, 2021, 66, 61);
    }

    @Test
    void scenarioCannotChangeBaselinePensionAges() throws IOException {
        String baseline = write(StatePensionAgeSchedule.SHEET_NAME, HEADER, new Object[][]{{2020, 65, 60}});
        String scenario = write(StatePensionAgeSchedule.SHEET_NAME, HEADER, new Object[][]{{2020, 65, 62}});

        var error = assertThrows(IllegalArgumentException.class,
                () -> StatePensionAgeSchedule.loadMatchingBaseline(baseline, scenario));
        assertTrue(error.getMessage().contains(scenario), error.getMessage());
        assertTrue(error.getMessage().contains("baseline pension-age schedule"), error.getMessage());
    }

    @Test
    void scenarioCannotChangeBaselinePensionAgeYears() throws IOException {
        String baseline = write(StatePensionAgeSchedule.SHEET_NAME, HEADER, new Object[][]{{2020, 65, 60}});
        String scenario = write(StatePensionAgeSchedule.SHEET_NAME, HEADER, new Object[][]{{2021, 65, 60}});

        assertThrows(IllegalArgumentException.class,
                () -> StatePensionAgeSchedule.loadMatchingBaseline(baseline, scenario));
    }

    private static void assertFailure(String expectedMessagePart, String file) {
        IllegalStateException e = assertThrows(IllegalStateException.class, () -> StatePensionAgeSchedule.load(file));
        assertTrue(e.getMessage().contains(expectedMessagePart), e.getMessage());
    }

    private String write(String sheetName, String[] header, Object[][] rows) throws IOException {
        Path file = tempDir.resolve(sheetName + "_" + header.length + "_" + rows.length + "_" + System.nanoTime() + ".xlsx");
        try (XSSFWorkbook workbook = new XSSFWorkbook(); FileOutputStream out = new FileOutputStream(file.toFile())) {
            Sheet sheet = workbook.createSheet(sheetName);
            Row headerRow = sheet.createRow(0);
            for (int c = 0; c < header.length; c++)
                headerRow.createCell(c).setCellValue(header[c]);
            for (int r = 0; r < rows.length; r++) {
                Row row = sheet.createRow(r + 1);
                for (int c = 0; c < rows[r].length; c++) {
                    Object value = rows[r][c];
                    if (value instanceof Number number)
                        row.createCell(c).setCellValue(number.doubleValue());
                    else if (value != null)
                        row.createCell(c).setCellValue(value.toString());
                }
            }
            workbook.write(out);
        }
        return file.toString();
    }
}
