package simpaths.model.macro;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

import org.apache.log4j.Logger;

/**
 * Loads and serves time-varying Ramsey growth model parameter deviations from a
 * CSV scenario file for long-run counterfactual analysis.
 *
 * <p>This class enables structural counterfactuals by modifying the Ramsey growth
 * model's deep parameters (TFP growth, depreciation, discount rate, etc.) over the
 * simulation horizon. When a scenario is active, the Ramsey model re-solves with
 * the modified parameters, producing different trend paths for wages, output, capital,
 * and the natural interest rate.</p>
 *
 * <h3>CSV Format</h3>
 * <pre>
 *   year, g_A, delta, alpha_K, beta, sigma, g_Y, nx_Y
 *   2025, 0.0025, 0, 0, 0, 0, 0, 0
 *   2026, 0.0025, 0, 0, 0, 0, 0.005, 0
 *   ...
 * </pre>
 *
 * <p>All values are <b>absolute deviations from baseline</b> (additive), in the same
 * units as the annual parameter from {@code growth_params_{COUNTRY}.json}:</p>
 * <ul>
 *   <li><b>g_A</b>: deviation in annual TFP growth rate (e.g., 0.0025 = +0.25 pp)</li>
 *   <li><b>delta</b>: deviation in annual depreciation rate (e.g., 0.01 = +1 pp)</li>
 *   <li><b>alpha_K</b>: deviation in capital share (e.g., 0.02 = +2 pp)</li>
 *   <li><b>beta</b>: deviation in annual discount factor (e.g., -0.01 = more impatient)</li>
 *   <li><b>sigma</b>: deviation in CRRA coefficient (e.g., 0.5 = less willing to substitute)</li>
 *   <li><b>g_Y</b>: deviation in government spending share of GDP (e.g., 0.01 = +1 pp G/Y)</li>
 *   <li><b>nx_Y</b>: deviation in net exports share of GDP (e.g., -0.02 = -2 pp NX/Y)</li>
 *   <li><b>psi</b>: deviation in labor disutility weight (e.g., 5.0)</li>
 *   <li><b>phi</b>: deviation in inverse Frisch elasticity of labor supply (e.g., 0.5)</li>
 * </ul>
 *
 * <p>Not all parameter columns need to be present — missing columns default to zero.
 * Years not listed in the file also default to zero (baseline values).
 * For years <b>beyond the last row</b> in the CSV, the last row's values persist
 * (permanent shift assumption).</p>
 *
 * <h3>Economic interpretation examples</h3>
 * <ul>
 *   <li>"Innovation policy raises TFP growth by 0.25 pp permanently":
 *       g_A = 0.0025 in every row</li>
 *   <li>"Climate change raises depreciation by 1 pp after 2030":
 *       delta = 0 for 2025-2029, delta = 0.01 for 2030+</li>
 *   <li>"Aging society: discount factor falls 0.5 pp over 2025-2060":
 *       beta linearly declining from 0 to -0.005</li>
 * </ul>
 *
 * @author DSGE-SimPaths Integration
 * @version 1.0
 * @see RamseyTrendModel
 * @see DSGEShockScenario
 */
public class RamseyScenario {

    private static final Logger log = Logger.getLogger(RamseyScenario.class);

    /** Recognized parameter names (case-insensitive matching against CSV headers) */
    static final String[] PARAM_NAMES = {"g_A", "delta", "alpha_K", "beta", "sigma", "g_Y", "nx_Y", "psi", "phi"};

    /** Map from year → parameter deviations (indexed by PARAM_NAMES order) */
    private final TreeMap<Integer, double[]> deviationsByYear = new TreeMap<>();

    /** Name of the loaded scenario file (for logging) */
    private String scenarioName;

    /** Whether logging is enabled */
    private boolean logEnabled = false;

    // ========== Loading ==========

    /**
     * Load a Ramsey scenario from a CSV file.
     *
     * <p>Expected format: header row with "year" and one or more parameter name
     * columns (g_A, delta, alpha_K, beta, sigma). Data rows with numeric values.
     * Comments (lines starting with # or //) and blank lines are skipped.</p>
     *
     * @param csvPath path to the scenario CSV file
     * @throws IOException              if the file cannot be read
     * @throws IllegalArgumentException if the format is invalid
     */
    public void loadFromFile(Path csvPath) throws IOException {
        if (!Files.exists(csvPath)) {
            throw new FileNotFoundException("Ramsey scenario file not found: " + csvPath);
        }

        scenarioName = csvPath.getFileName().toString();
        deviationsByYear.clear();

        List<String> allLines = Files.readAllLines(csvPath);

        // Comment/blank filtering and row splitting live in MacroCsv so the two
        // scenario readers cannot drift apart again (audit §9).
        List<String> lines = MacroCsv.stripCommentsAndBlanks(allLines);

        if (lines.size() < 2) {
            throw new IllegalArgumentException(
                    "Ramsey scenario file must have header + at least one data row: " + csvPath);
        }

        // Parse header
        String[] headers = MacroCsv.splitRow(lines.get(0));
        for (int i = 0; i < headers.length; i++) {
            headers[i] = headers[i].trim();
        }

        // Find year column
        int yearCol = findColumn(headers, "year");
        if (yearCol < 0) {
            throw new IllegalArgumentException(
                    "Ramsey scenario CSV must have a 'year' column: " + csvPath);
        }

        // Map CSV columns to parameter indices
        int[] columnToParamIndex = new int[headers.length];
        Arrays.fill(columnToParamIndex, -1);
        int mappedColumns = 0;

        for (int col = 0; col < headers.length; col++) {
            if (col == yearCol) continue;
            int paramIdx = findParamIndex(headers[col]);
            if (paramIdx >= 0) {
                columnToParamIndex[col] = paramIdx;
                mappedColumns++;
            } else if (!headers[col].isEmpty()) {
                if (logEnabled) {
                    log.warn("Ramsey scenario column '" + headers[col]
                            + "' does not match any Ramsey parameter — ignored");
                }
            }
        }

        if (mappedColumns == 0) {
            throw new IllegalArgumentException(
                    "No parameter columns matched. Expected some of: "
                            + String.join(", ", PARAM_NAMES) + ". Found: "
                            + String.join(", ", headers));
        }

        // Parse data rows
        for (int row = 1; row < lines.size(); row++) {
            String[] parts = MacroCsv.splitRow(lines.get(row));
            if (parts.length <= yearCol) {
                throw new IllegalArgumentException(String.format(
                        "Ramsey scenario row %d has too few columns (%d, need at least %d): %s",
                        row + 1, parts.length, yearCol + 1, csvPath));
            }

            int year;
            try {
                year = Integer.parseInt(parts[yearCol].trim());
            } catch (NumberFormatException e) {
                throw new IllegalArgumentException(String.format(
                        "Invalid year at row %d in %s: '%s'",
                        row + 1, csvPath, parts[yearCol].trim()));
            }

            double[] deviations = new double[PARAM_NAMES.length];
            for (int col = 0; col < parts.length && col < columnToParamIndex.length; col++) {
                int paramIdx = columnToParamIndex[col];
                if (paramIdx >= 0) {
                    String val = parts[col].trim();
                    if (!val.isEmpty()) {
                        deviations[paramIdx] = MacroCsv.requireFinite(val, row + 1, headers[col], csvPath);
                    }
                }
            }

            if (deviationsByYear.containsKey(year)) {
                throw new IllegalArgumentException(String.format(
                        "Duplicate entry for year %d in Ramsey scenario file %s", year, csvPath));
            }
            deviationsByYear.put(year, deviations);
        }

        if (logEnabled) {
            log.info(String.format("Loaded Ramsey scenario '%s': %d years, %d parameter columns mapped",
                    scenarioName, deviationsByYear.size(), mappedColumns));
            logScenarioSummary();
        }
    }

    /**
     * Load a Ramsey scenario from a CSV file path string.
     *
     * @param csvPath string path to the scenario CSV file
     * @throws IOException if the file cannot be read
     */
    public void loadFromFile(String csvPath) throws IOException {
        loadFromFile(Path.of(csvPath));
    }

    // ========== Querying ==========

    /**
     * Get the parameter deviation for a given year and parameter name.
     *
     * <p>For years before the first row, returns 0 (baseline).
     * For years after the last row, returns the last row's value (permanent shift).
    * For years in between but not listed, carries forward the nearest earlier row.</p>
     *
     * @param year      simulation year (e.g., 2025)
     * @param paramName parameter name (g_A, delta, alpha_K, beta, sigma)
     * @return deviation from baseline (absolute units)
     */
    public double getDeviation(int year, String paramName) {
        int paramIdx = findParamIndex(paramName);
        if (paramIdx < 0) return 0.0;
        return getDeviation(year, paramIdx);
    }

    /**
     * Get the parameter deviation for a given year by parameter index.
     *
     * @param year     simulation year
     * @param paramIdx index into PARAM_NAMES (0=g_A, 1=delta, 2=alpha_K, 3=beta, 4=sigma, 5=g_Y, 6=nx_Y)
     * @return deviation from baseline
     */
    public double getDeviation(int year, int paramIdx) {
        if (deviationsByYear.isEmpty() || paramIdx < 0 || paramIdx >= PARAM_NAMES.length) {
            return 0.0;
        }

        // Exact match
        double[] exact = deviationsByYear.get(year);
        if (exact != null) return exact[paramIdx];

        // Before first year → baseline (no deviation)
        if (year < deviationsByYear.firstKey()) return 0.0;

        // After last year → persist last value (permanent shift)
        if (year > deviationsByYear.lastKey()) {
            return deviationsByYear.lastEntry().getValue()[paramIdx];
        }

        // Between rows: use the nearest earlier (floor) entry
        var floorEntry = deviationsByYear.floorEntry(year);
        if (floorEntry != null) {
            return floorEntry.getValue()[paramIdx];
        }
        return 0.0;
    }

    /**
     * Get all parameter deviations for a given year as an array.
     *
     * @param year simulation year
     * @return array of deviations indexed by PARAM_NAMES order (length 7)
     */
    public double[] getDeviations(int year) {
        double[] result = new double[PARAM_NAMES.length];
        for (int i = 0; i < PARAM_NAMES.length; i++) {
            result[i] = getDeviation(year, i);
        }
        return result;
    }

    /**
     * Check whether scenario data has been loaded.
     *
     * @return true if a file has been loaded with at least one data row
     */
    public boolean isLoaded() {
        return !deviationsByYear.isEmpty();
    }

    /**
     * Check whether any parameter has a non-zero deviation in any year.
     *
     * @return true if any deviation is non-zero
     */
    public boolean hasAnyDeviations() {
        for (double[] devs : deviationsByYear.values()) {
            for (double v : devs) {
                if (v != 0.0) return true;
            }
        }
        return false;
    }

    /**
     * Get the name of the loaded scenario file.
     *
     * @return filename or null if not loaded
     */
    public String getScenarioName() {
        return scenarioName;
    }

    /**
     * Get a summary of the loaded scenario for logging.
     *
     * @return human-readable summary string
     */
    public String getSummary() {
        if (deviationsByYear.isEmpty()) {
            return "No Ramsey scenario loaded";
        }

        int minYear = deviationsByYear.firstKey();
        int maxYear = deviationsByYear.lastKey();

        // Identify which parameters have non-zero deviations
        var activeParams = new ArrayList<String>();
        double[] maxAbs = new double[PARAM_NAMES.length];
        for (double[] devs : deviationsByYear.values()) {
            for (int i = 0; i < PARAM_NAMES.length; i++) {
                maxAbs[i] = Math.max(maxAbs[i], Math.abs(devs[i]));
            }
        }
        for (int i = 0; i < PARAM_NAMES.length; i++) {
            if (maxAbs[i] > 0) {
                activeParams.add(String.format("%s(max|%.6f|)", PARAM_NAMES[i], maxAbs[i]));
            }
        }

        return String.format("Ramsey scenario '%s': %d years (%d-%d), active: %s",
                scenarioName, deviationsByYear.size(), minYear, maxYear,
                activeParams.isEmpty() ? "none" : String.join(", ", activeParams));
    }

    public void setLogEnabled(boolean logEnabled) {
        this.logEnabled = logEnabled;
    }

    // ========== Internal Helpers ==========

    private int findColumn(String[] headers, String name) {
        for (int i = 0; i < headers.length; i++) {
            if (headers[i].equalsIgnoreCase(name)) return i;
        }
        return -1;
    }

    private static int findParamIndex(String columnName) {
        for (int i = 0; i < PARAM_NAMES.length; i++) {
            if (PARAM_NAMES[i].equalsIgnoreCase(columnName)) return i;
        }
        return -1;
    }

    private void logScenarioSummary() {
        if (!logEnabled || deviationsByYear.isEmpty()) return;

        var nl = System.lineSeparator();
        var sb = new StringBuilder("  Ramsey scenario deviations:");
        for (var entry : deviationsByYear.entrySet()) {
            sb.append(nl).append(String.format("    %d:", entry.getKey()));
            double[] devs = entry.getValue();
            for (int i = 0; i < PARAM_NAMES.length; i++) {
                if (devs[i] != 0.0) {
                    sb.append(String.format(" %s=%+.6f", PARAM_NAMES[i], devs[i]));
                }
            }
        }
        log.info(sb.toString());
    }

    // ========== Parameter Index Constants ==========

    /** Index of g_A (TFP growth) in PARAM_NAMES / deviation arrays */
    public static final int IDX_G_A = 0;

    /** Index of delta (depreciation) in PARAM_NAMES / deviation arrays */
    public static final int IDX_DELTA = 1;

    /** Index of alpha_K (capital share) in PARAM_NAMES / deviation arrays */
    public static final int IDX_ALPHA_K = 2;

    /** Index of beta (discount factor) in PARAM_NAMES / deviation arrays */
    public static final int IDX_BETA = 3;

    /** Index of sigma (CRRA) in PARAM_NAMES / deviation arrays */
    public static final int IDX_SIGMA = 4;

    /** Index of g_Y (government spending share) in PARAM_NAMES / deviation arrays */
    public static final int IDX_G_Y = 5;

    /** Index of nx_Y (net exports share) in PARAM_NAMES / deviation arrays */
    public static final int IDX_NX_Y = 6;

    /** Index of psi (labor disutility weight) in PARAM_NAMES / deviation arrays */
    public static final int IDX_PSI = 7;

    /** Index of phi (inverse Frisch elasticity) in PARAM_NAMES / deviation arrays */
    public static final int IDX_PHI = 8;
}
