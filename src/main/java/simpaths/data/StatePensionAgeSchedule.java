package simpaths.data;

import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.ss.usermodel.DataFormatter;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import simpaths.model.enums.Gender;

import java.io.File;
import java.io.IOException;
import java.util.Arrays;
import java.util.EnumMap;
import java.util.Map;
import java.util.Objects;

/**
 * State pension age by calendar year and gender, in whole years, from input/<CC>/state_pension_age.xlsx (sheet
 * State_pension_age, columns year, Male and Female). Parameters.getStatePensionAge, the only accessor of the state
 * pension age, reads it. Parameters.loadCountrySpecificParameters loads it, so that setup (the tax-donor keys) and
 * the simulation use the same ages.
 *
 * Every year from the first row to the last must be present. A year after the last row takes the ages of the last
 * row; a year before the first row is an error. The workbook's Info sheet gives the statutory ages, the source and
 * the rounding rule.
 */
public final class StatePensionAgeSchedule {

    public static final String FILE_NAME = "state_pension_age.xlsx";
    public static final String SHEET_NAME = "State_pension_age";
    private static final String YEAR_COLUMN = "year";

    /** Plausible range of a state pension age, checked at load. */
    public static final int MIN_AGE = 50, MAX_AGE = 75;

    private final String file;
    private final int firstYear;
    private final int lastYear;
    private final Map<Gender, int[]> agesByGender;   // indexed by year - firstYear

    private StatePensionAgeSchedule(String file, int firstYear, Map<Gender, int[]> agesByGender) {
        this.file = file;
        this.firstYear = firstYear;
        this.lastYear = firstYear + agesByGender.get(Gender.Male).length - 1;
        this.agesByGender = agesByGender;
    }

    /** Loads and checks the table of the given workbook; throws IllegalStateException if it is missing or invalid. */
    public static StatePensionAgeSchedule load(String file) {
        File source = new File(file);
        if (!source.isFile())
            throw new IllegalStateException("State pension age table not found: " + file);
        try (Workbook workbook = WorkbookFactory.create(source, null, true)) {
            Sheet sheet = workbook.getSheet(SHEET_NAME);
            if (sheet == null)
                throw new IllegalStateException(file + " has no sheet " + SHEET_NAME);
            return read(file, sheet);
        } catch (IOException e) {
            throw new IllegalStateException("Could not read " + file, e);
        }
    }

    /** Uses the baseline ages after checking that a scenario workbook contains the same years and ages. */
    static StatePensionAgeSchedule loadMatchingBaseline(String baselineFile, String scenarioFile) {
        StatePensionAgeSchedule baseline = load(baselineFile);
        StatePensionAgeSchedule scenario = load(scenarioFile);
        if (!baseline.hasSameAgesAs(scenario)) {
            throw new IllegalArgumentException("Scenario pension-age workbook " + scenarioFile
                    + " must have the same years and ages as " + baselineFile
                    + ". Tax-donor matching uses the baseline pension-age schedule.");
        }
        return baseline;
    }

    private boolean hasSameAgesAs(StatePensionAgeSchedule other) {
        if (firstYear != other.firstYear) {
            return false;
        }
        for (Gender gender : Gender.values()) {
            if (!Arrays.equals(agesByGender.get(gender), other.agesByGender.get(gender))) {
                return false;
            }
        }
        return true;
    }

    private static StatePensionAgeSchedule read(String file, Sheet sheet) {
        String where = file + ", sheet " + SHEET_NAME;
        Row header = sheet.getRow(0);
        if (header == null)
            throw new IllegalStateException(where + " has no header row");
        int yearColumn = findColumn(header, YEAR_COLUMN, where);
        Map<Gender, Integer> genderColumns = new EnumMap<>(Gender.class);
        for (Gender gender : Gender.values())
            genderColumns.put(gender, findColumn(header, gender.name(), where));

        // the years run from the second row to the last row with a year; blank rows after it are ignored
        int lastRow = sheet.getLastRowNum();
        while (lastRow > 0 && isBlank(sheet.getRow(lastRow), yearColumn))
            lastRow--;
        if (lastRow == 0)
            throw new IllegalStateException(where + " has no years");

        int firstYear = wholeNumber(sheet, 1, yearColumn, YEAR_COLUMN, where);
        Map<Gender, int[]> agesByGender = new EnumMap<>(Gender.class);
        for (Gender gender : Gender.values())
            agesByGender.put(gender, new int[lastRow]);
        for (int r = 1; r <= lastRow; r++) {
            int year = wholeNumber(sheet, r, yearColumn, YEAR_COLUMN, where);
            int expectedYear = firstYear + r - 1;
            if (year != expectedYear)
                throw new IllegalStateException(where + ", row " + (r + 1) + ": year " + year + " where "
                        + expectedYear + " was expected (years must be consecutive, with none missing)");
            for (Gender gender : Gender.values()) {
                int age = wholeNumber(sheet, r, genderColumns.get(gender), gender.name(), where);
                if (age < MIN_AGE || age > MAX_AGE)
                    throw new IllegalStateException(where + ", row " + (r + 1) + ": " + gender + " age " + age
                            + " in " + year + " is outside the plausible range " + MIN_AGE + "-" + MAX_AGE);
                agesByGender.get(gender)[r - 1] = age;
            }
        }
        return new StatePensionAgeSchedule(file, firstYear, agesByGender);
    }

    private static int findColumn(Row header, String name, String where) {
        DataFormatter formatter = new DataFormatter();
        for (Cell cell : header) {
            if (formatter.formatCellValue(cell).trim().equalsIgnoreCase(name))
                return cell.getColumnIndex();
        }
        throw new IllegalStateException(where + " has no column " + name);
    }

    private static boolean isBlank(Row row, int column) {
        Cell cell = (row == null) ? null : row.getCell(column);
        return cell == null || cell.getCellType() == CellType.BLANK
                || (cell.getCellType() == CellType.STRING && cell.getStringCellValue().isBlank());
    }

    /** Value of a cell that must hold a whole number; r is the zero-based row index. */
    private static int wholeNumber(Sheet sheet, int r, int column, String columnName, String where) {
        Row row = sheet.getRow(r);
        Cell cell = (row == null) ? null : row.getCell(column);
        CellType type = (cell == null) ? CellType.BLANK : cell.getCellType();
        if (type == CellType.FORMULA)
            type = cell.getCachedFormulaResultType();
        if (type != CellType.NUMERIC)
            throw new IllegalStateException(where + ", row " + (r + 1) + ": " + columnName + " is not a number");
        double value = cell.getNumericCellValue();
        if (value != Math.rint(value))
            throw new IllegalStateException(where + ", row " + (r + 1) + ": " + columnName + " is " + value
                    + ", not a whole number");
        return (int) value;
    }

    /**
     * State pension age of the given gender in the given year. A year after the last row takes the ages of the last
     * row; a year before the first row is an error.
     */
    public int get(int year, Gender gender) {
        Objects.requireNonNull(gender, "gender");
        if (year < firstYear)
            throw new IllegalArgumentException("No state pension age for " + year + ": " + file + " starts in " + firstYear);
        return agesByGender.get(gender)[Math.min(year, lastYear) - firstYear];
    }

    public int getFirstYear() {
        return firstYear;
    }

    public int getLastYear() {
        return lastYear;
    }
}
