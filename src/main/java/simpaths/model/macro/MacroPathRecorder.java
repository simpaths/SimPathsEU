package simpaths.model.macro;

import java.io.*;
import java.nio.file.*;
import java.util.*;

/**
 * Records quarterly evolution of DSGE state variables, jump variables, and shocks.
 *
 * The recorder accumulates data during simulation and exports to CSV at the end.
 * Each row represents one quarter with columns for:
 * - Year, Quarter
 * - All state variables (names loaded from model_info.json)
 * - All jump variables (names loaded from model_info.json)
 * - All shock values (names loaded from model_info.json)
 *
 * Variable names are set dynamically via {@link #setVariableNames} after
 * the DSGE model loads from its export directory. Default names matching the
 * current exported SimPaths DSGE schema are used if not explicitly set.
 *
 * @author DSGE-SimPaths Integration
 * @version 2.0 (dynamic variable names from model_info.json)
 */
public class MacroPathRecorder {

    // ========== Column Names (set dynamically or defaults) ==========

    /** Default state variable names (current exported SimPaths DSGE schema) */
    private static final String[] DEFAULT_STATE_NAMES = {
        "c", "R", "pi", "w", "v", "n", "h", "x", "L", "k", "inv", "sep_shock", "d_shock"
    };

    /** Default jump variable names (current exported SimPaths DSGE schema) */
    private static final String[] DEFAULT_JUMP_NAMES = {
        "y", "d", "gap", "w_star", "u", "u_rate", "m", "mc", "theta"
    };

    /** Default shock names (current exported SimPaths DSGE schema) */
    private static final String[] DEFAULT_SHOCK_NAMES = {
        "eps_a", "eps_r", "eps_d", "eps_p", "eps_L", "eps_sep", "eps_h", "eps_inv"
    };

    /** Active state variable names (loaded or default) */
    private String[] stateNames;

    /** Active jump variable names (loaded or default) */
    private String[] jumpNames;

    /** Active shock names (loaded or default) */
    private String[] shockNames;

    // ========== Data Storage ==========

    /** List of recorded quarters */
    private final List<QuarterRecord> records;

    /** Whether recording is enabled */
    private boolean enabled;

    /**
     * Current Ramsey trend values (% deviation from baseline) for all tracked variables.
     * Keys match DSGE variable names: "w", "y", "c", "inv", "k".
     * Set by MacroModelManager before each year so all 4 quarterly records capture the trend.
     */
    private Map<String, Double> currentTrends;

    /**
     * Ordered list of variables for which trend/total columns are exported.
     * For each entry, the CSV gets two extra columns: {var}_trend and {var}_total.
     */
    private static final String[] TREND_COLUMN_VARS = {"w", "y", "c", "inv", "k"};

    /**
     * Ordered list of extra variables exported as plain columns (no trend/total split).
     * Values are read from the trends map by key name and written as-is.
    * Used for level indices (l_level, h_level), Ramsey labor diagnostics
    * (n_ramsey and l_ramsey),
     * and SimPaths participation diagnostics:
     * participation_rate = workers / working-age population (WAP),
     * workers_over_atRiskPool = workers / at-risk pool,
     * total_population = % change in total SimPaths population from start year,
     * wap_level = % change in WAP (15-64) from start year,
     * atrisk_level = % change in at-risk pool from start year,
     * wage_realized = mean labWageHrly over the at-risk pool — the same
     * population that enters the SimPaths discrete-choice labour supply model
     * ({@link simpaths.model.Person#atRiskOfWork} restricted to ages 15-64) —
     * expressed as % change from the simulation start year (= 0 in the start
     * year), to match the {@code w_trend} / {@code w_total} convention so the
     * three series can be plotted side by side. Always emitted, including when
     * the macro model is off, so the wage that drives labour-supply decisions
     * can be inspected against the macro-coupled trajectory. Its start-year
     * anchor is mode-dependent and therefore not comparable across run modes —
     * see {@code MacroModelManager.startYearAtRiskWage} before reading an
     * early-year level difference as a treatment effect.
     * n_realized_gap / w_trend_revision: the recursive Ramsey feedback's diagnostics
     * (realized-vs-assumed labor-force gap, % change in next year's trend wage from the
     * re-solve); see {@code MacroModelManager.applyRamseyFeedbackWithRealized}. Zero for
     * every run where the feedback is disabled or has not yet latched its lambda.
     */
    private static final String[] EXTRA_COLUMN_VARS = {
        "l_level", "h_level", "n_ramsey", "l_ramsey", "participation_rate", "workers_over_atRiskPool",
        "total_population", "wap_level", "atrisk_level",
        "cat_0_share", "cat_1_share", "cat_2_share", "cat_3_share",
        "cat_0_meanHours", "cat_1_meanHours", "cat_2_meanHours", "cat_3_meanHours",
        "wage_realized", "n_realized_gap", "h_realized_gap", "w_trend_revision"
    };

    // ========== Inner Class for Quarter Data ==========

    private static class QuarterRecord {
        final int year;
        final int quarter;
        final double[] states;
        final double[] jumps;
        final double[] shocks;
        final Map<String, Double> trends;

        QuarterRecord(int year, int quarter, double[] states, double[] jumps, double[] shocks,
                      Map<String, Double> trends) {
            this.year = year;
            this.quarter = quarter;
            this.states = states.clone();
            this.jumps = jumps.clone();
            this.shocks = shocks.clone();
            this.trends = (trends != null) ? new LinkedHashMap<>(trends) : new LinkedHashMap<>();
        }
    }

    // ========== Constructor ==========

    /**
     * Create a new path recorder with default variable names.
     */
    public MacroPathRecorder() {
        this.records = new ArrayList<>();
        this.enabled = true;
        this.currentTrends = Collections.emptyMap();
        this.stateNames = DEFAULT_STATE_NAMES;
        this.jumpNames = DEFAULT_JUMP_NAMES;
        this.shockNames = DEFAULT_SHOCK_NAMES;
    }

    // ========== Configuration ==========

    /**
     * Set variable names from the loaded DSGE model.
     * Called by DSGEModel.loadFromDirectory() after parsing model_info.json.
     *
     * @param stateNames State variable names (in order of state vector)
     * @param jumpNames  Jump variable names (in order of jump vector)
     * @param shockNames Shock names (in order of shock vector)
     */
    public void setVariableNames(String[] stateNames, String[] jumpNames, String[] shockNames) {
        if (stateNames != null && stateNames.length > 0) {
            this.stateNames = stateNames.clone();
        }
        if (jumpNames != null && jumpNames.length > 0) {
            this.jumpNames = jumpNames.clone();
        }
        if (shockNames != null && shockNames.length > 0) {
            this.shockNames = shockNames.clone();
        }
    }

    // ========== Recording Methods ==========

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public boolean isEnabled() {
        return enabled;
    }

    public void clear() {
        records.clear();
    }

    /**
     * Set the current Ramsey trend values (% deviation from baseline).
     * Called by MacroModelManager before stepAnnual() so that all 4 quarterly
     * records in the year capture the correct trend values.
     *
     * @param trends Map of variable name to trend % (e.g., "w" → 0.686, "y" → 0.45)
     */
    public void setCurrentTrends(Map<String, Double> trends) {
        this.currentTrends = (trends != null) ? new LinkedHashMap<>(trends) : Collections.emptyMap();
    }

    /**
     * Record a quarter's data.
     *
     * @param year    Simulation year
     * @param quarter Quarter within year (1-4)
     * @param state   The DSGEState after the quarterly step
     * @param shocks  The shock vector applied this quarter
     */
    public void recordQuarter(int year, int quarter, DSGEState state, double[] shocks) {
        if (!enabled || year <= 0) return;  // Skip pre-simulation diagnostic data

        records.add(new QuarterRecord(
            year,
            quarter,
            state.getStateVector(),
            state.getJumpVector(),
            shocks,
            currentTrends
        ));
    }

    /**
     * Record 4 quarters of Ramsey-only data (zero DSGE cycle, zero shocks).
     *
     * <p>Used in the first simulation year when the DSGE cycle hasn't been stepped
     * yet but the Ramsey trend is available. Creates 4 quarterly records with
     * zero-filled state/jump/shock vectors so that the Ramsey trend columns
     * still appear in the CSV output.</p>
     *
     * @param year       Simulation year
     * @param nState     Number of state variables (for zero vector sizing)
     * @param nJump      Number of jump variables (for zero vector sizing)
     * @param nShocks    Number of shocks (for zero vector sizing)
     */
    public void recordRamseyOnlyYear(int year, int nState, int nJump, int nShocks) {
        if (!enabled || year <= 0) return;

        double[] zeroState = new double[nState];
        double[] zeroJumps = new double[nJump];
        double[] zeroShocks = new double[nShocks];

        for (int q = 1; q <= 4; q++) {
            records.add(new QuarterRecord(year, q, zeroState, zeroJumps, zeroShocks, currentTrends));
        }
    }

    /**
     * Record 4 quarters with zero DSGE cycle using the recorder's active dimensions.
     *
     * @param year Simulation year
     */
    public void recordRamseyOnlyYear(int year) {
        recordRamseyOnlyYear(year, stateNames.length, jumpNames.length, shockNames.length);
    }

    /**
     * Retroactively set a single trend key/value on every record for the given year.
     *
     * <p>Needed when a trend column has to be measured after the quarterly records
     * for a year have already been written — e.g. the realized-wage index, which
     * depends on labWageHrly values that are only updated after the DSGE step in
     * the dynamic path.</p>
     *
     * @param year   Simulation year whose records should be updated
     * @param key    Trend map key (must match an entry in {@code EXTRA_COLUMN_VARS}
     *               or {@code TREND_COLUMN_VARS} to appear in the CSV)
     * @param value  Trend value to assign
     */
    public void amendTrendForYear(int year, String key, double value) {
        for (QuarterRecord record : records) {
            if (record.year == year) {
                record.trends.put(key, value);
            }
        }
    }

    public int size() {
        return records.size();
    }

    public boolean hasData() {
        return !records.isEmpty();
    }

    // ========== Export Methods ==========

    public void exportToCSV(String directory, String filename) throws IOException {
        if (records.isEmpty()) {
            return;
        }

        Path dirPath = Paths.get(directory);
        Files.createDirectories(dirPath);

        Path filePath = dirPath.resolve(filename);
        boolean append = Files.exists(filePath) && Files.size(filePath) > 0;
        int runNumber = determineRunNumber(filePath);

        try (PrintWriter writer = new PrintWriter(new BufferedWriter(new FileWriter(filePath.toFile(), append)))) {
            if (!append) {
                writer.println(buildHeader());
            }

            for (QuarterRecord record : records) {
                writer.println(buildRow(record, runNumber));
            }
        }
    }

    public void exportToSimPathsOutput(String outputFolder) throws IOException {
        exportToSimPathsOutput(outputFolder, "MacroPaths.csv");
    }

    public void exportToSimPathsOutput(String outputFolder, String filename) throws IOException {
        String csvDir = outputFolder + File.separator + "csv";
        exportToCSV(csvDir, filename);
    }

    // ========== Helper Methods ==========

    private String buildHeader() {
        StringBuilder sb = new StringBuilder();
        sb.append("run,year,quarter");

        for (String name : stateNames) {
            sb.append(",").append(name);
        }

        for (String name : jumpNames) {
            sb.append(",").append(name);
        }

        for (String name : shockNames) {
            sb.append(",").append(name);
        }

        // Ramsey trend and total columns for each tracked variable
        for (String var : TREND_COLUMN_VARS) {
            sb.append(",").append(var).append("_trend");
            sb.append(",").append(var).append("_total");
        }

        // Extra plain columns (level indices, Ramsey N comparison)
        for (String var : EXTRA_COLUMN_VARS) {
            sb.append(",").append(var);
        }

        return sb.toString();
    }

    private String buildRow(QuarterRecord record, int runNumber) {
        StringBuilder sb = new StringBuilder();
        sb.append(runNumber).append(",").append(record.year).append(",").append(record.quarter);

        for (double val : record.states) {
            sb.append(",").append(formatValue(val));
        }

        for (double val : record.jumps) {
            sb.append(",").append(formatValue(val));
        }

        for (double val : record.shocks) {
            sb.append(",").append(formatValue(val));
        }

        // Append trend and total for each tracked variable
        for (String var : TREND_COLUMN_VARS) {
            double trend = record.trends.getOrDefault(var, 0.0);
            double cycle = findCycleValue(var, record);
            sb.append(",").append(formatValue(trend));
            sb.append(",").append(formatValue(cycle + trend));
        }

        // Append extra plain columns
        for (String var : EXTRA_COLUMN_VARS) {
            double val = record.trends.getOrDefault(var, 0.0);
            sb.append(",").append(formatValue(val));
        }

        return sb.toString();
    }

    private int determineRunNumber(Path filePath) throws IOException {
        if (!Files.exists(filePath) || Files.size(filePath) == 0) {
            return 1;
        }

        int lastRun = 0;
        try (BufferedReader reader = Files.newBufferedReader(filePath)) {
            String line = reader.readLine();
            while ((line = reader.readLine()) != null) {
                if (line.isBlank()) {
                    continue;
                }

                int firstComma = line.indexOf(',');
                if (firstComma <= 0) {
                    continue;
                }

                try {
                    lastRun = Integer.parseInt(line.substring(0, firstComma).trim());
                } catch (NumberFormatException ignored) {
                    // Ignore malformed legacy rows and keep scanning for the last valid run id.
                }
            }
        }

        return Math.max(lastRun, 0) + 1;
    }

    /**
     * Look up a variable's cycle value (DSGE deviation) from state or jump vectors.
     */
    private double findCycleValue(String varName, QuarterRecord record) {
        for (int i = 0; i < stateNames.length && i < record.states.length; i++) {
            if (varName.equals(stateNames[i])) return record.states[i];
        }
        for (int i = 0; i < jumpNames.length && i < record.jumps.length; i++) {
            if (varName.equals(jumpNames[i])) return record.jumps[i];
        }
        return 0.0;
    }

    private String formatValue(double val) {
        if (val == 0.0) {
            return "0";
        }
        return String.format(Locale.US, "%.10g", val);
    }

    // ========== Summary Statistics ==========

    public String getSummary() {
        if (records.isEmpty()) {
            return "MacroPathRecorder: No data recorded";
        }

        QuarterRecord first = records.get(0);
        QuarterRecord last = records.get(records.size() - 1);

        return String.format("MacroPathRecorder: %d quarters recorded (%d Q%d to %d Q%d)",
            records.size(),
            first.year, first.quarter,
            last.year, last.quarter);
    }
}
