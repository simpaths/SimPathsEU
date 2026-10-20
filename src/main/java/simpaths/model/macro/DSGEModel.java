package simpaths.model.macro;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import org.apache.log4j.Logger;

/**
 * Core DSGE policy function evaluator.
 *
 * Loads linearized policy function matrices from CSV files and evaluates
 * the state-space representation:
 *
 *     s_t = A  × s_{t-1} + Bs × ε_t    (state transition)
 *     y_t = C  × s_{t-1} + D  × ε_t    (jump variables)
 *
 * All model dimensions and variable indices are loaded dynamically from
 * model_info.json, with dimensions and indices read from export metadata.
 *
 * <h3>Key insight for SimPaths coupling</h3>
 * <ul>
 *   <li>Wage (w) is a STATE variable → extract from s_t directly</li>
 *   <li>Inflation (π) is a STATE since V15 (iota_p indexation puts pi(-1) in the NKPC); DSGEState resolves the side from model_info.json (piIsState)</li>
 * </ul>
 *
 * <h3>Shock Input Conventions</h3>
 * <p>Different shocks use different input conventions:</p>
 * <ul>
 *   <li><b>SimPaths level inputs (eps_L, eps_h)</b>: PERCENT log-deviations from baseline
 *       (100 &times; ln ratio — the model's units, since it is estimated on 100&times;log-dev data).
 *       The DSGE model equations define L = eps_L and h = eps_h (with rho_L = rho_h = 0),
 *       so a 5% labor force increase is passed as eps_L &asymp; 4.879 (= 100 &times; ln 1.05).
 *       No further scaling is applied inside this class.</li>
 *   <li><b>Other shocks (eps_a, eps_r, eps_d, eps_p, eps_sep, eps_inv)</b>: Standard deviation units.
 *       A value of 1.0 represents a one-standard-deviation shock. These inputs are converted
 *       to raw Dynare innovations by multiplying by the estimated shock standard deviation
 *       before applying the policy matrices.</li>
 * </ul>
 *
 * <p>The model runs at quarterly frequency internally and provides methods for
 * annual aggregation when interfacing with SimPaths.</p>
 *
 * @author DSGE-SimPaths Integration
 * @version 3.0 (dynamic dimensions from model_info.json)
 */
public class DSGEModel {

    private static final Logger log = Logger.getLogger(DSGEModel.class);

    /** Whether DSGE logging is enabled */
    private boolean logEnabled = false;

    // ========== Model Dimensions (loaded from model_info.json) ==========

    /** Number of state variables (predetermined) */
    private int nState;

    /** Number of jump variables (forward-looking) */
    private int nJump;

    /** Number of exogenous shocks */
    private int nExo;

    // ========== Shock Indices (loaded from model_info.json) ==========

    /** Labor force shock index (PRIMARY INTERFACE WITH SIMPATHS) */
    private int idxEpsL;

    /** Hours shock index */
    private int idxEpsH;

    // ========== Variable Index Mapping ==========

    /** Variable indices for DSGEState construction (loaded from JSON) */
    private DSGEState.VarIndices varIndices;

    /** State variable names (in order of state vector) */
    private String[] stateNames;

    /** Jump variable names (in order of jump vector) */
    private String[] jumpNames;

    // ========== Constants ==========

    /** Maximum allowed state deviation (for stability check). Default ±10 log-deviation units. */
    private double maxStateDeviation = 10.0;

    // ========== Policy Function Matrices ==========

    /** State transition matrix A (nState × nState) */
    private double[][] matrixA;

    /** Shock impact on states Bs (nState × nExo) */
    private double[][] matrixBs;

    /** Jump response to lagged states C (nJump × nState) */
    private double[][] matrixC;

    /** Jump response to shocks D (nJump × nExo) */
    private double[][] matrixD;

    // No steady-state field: the exported model is log-linearised, so every steady state
    // is identically zero. steady_state.csv is kept in the bundle for human inspection
    // but is not read - it is written in Dynare declaration order (states and jumps
    // interleaved), which does not match the states-then-jumps layout used here.

    /** Shock names in export order, from model_info.json's shock_indices_java */
    private String[] expectedShockNames;

    /** Shock standard deviations */
    private double[] shockStdDev;

    /** Shock AR(1) persistence parameters */
    private double[] shockRho;

    /** Shock names for logging */
    private String[] shockNames;

    /** Endogenous variable names */
    private String[] endoNames;

    /** Model name from JSON */
    private String modelName;

    // ========== Current State ==========

    /** Current state vector (lagged values for next step) */
    private double[] currentState;

    /** Whether model has been loaded */
    private boolean isLoaded = false;

    // ========== Path Recording ==========

    /** Recorder for quarterly paths (enabled by default) */
    private MacroPathRecorder pathRecorder;

    /** Current simulation year (for path recording) */
    private int currentYear;

    // ========== Constructor ==========

    /**
     * Create an uninitialized DSGE model.
     * Call loadFromDirectory() to load policy functions.
     */
    public DSGEModel() {
        this.pathRecorder = new MacroPathRecorder();
        this.currentYear = 0;
        // Dimensions and state vector allocated in loadFromDirectory()
    }

    // ========== Loading Methods ==========

    /**
     * Load policy function matrices from a directory.
     *
     * Expected files:
     * - policy_A.csv: State transition matrix (nState×nState)
     * - policy_Bs.csv: Shock impact on states (nState×nExo)
     * - policy_C.csv: Jump response to lagged states (nJump×nState)
     * - policy_D.csv: Jump response to shocks (nJump×nExo)
     * - steady_state.csv: Steady state values
     * - shock_params.csv: Shock parameters (stderr, rho)
     * - model_info.json: Variable names, dimensions, and index mappings
     *
     * @param directoryPath Path to directory containing DSGE export files
     * @throws IOException If files cannot be read
     * @throws IllegalArgumentException If file format is invalid
     */
    public void loadFromDirectory(String directoryPath) throws IOException {
        Path dir = Paths.get(directoryPath);

        if (!Files.isDirectory(dir)) {
            throw new IllegalArgumentException("Not a directory: " + directoryPath);
        }

        if (logEnabled) {
            log.info("Loading DSGE model from: " + directoryPath);
        }

        // Load model metadata (must come first to get dimensions and indices)
        loadModelInfo(dir.resolve("model_info.json"));

        // Allocate state vector with loaded dimensions
        currentState = new double[nState];

        // Load state-space matrices using loaded dimensions. Row and column names are
        // checked against model_info.json so a CSV carried over from a different export
        // run fails loudly instead of misaligning silently. Lagged-state columns carry
        // the "_lag" suffix; shock columns are the bare shock names.
        matrixA = loadMatrix(dir.resolve("policy_A.csv"), nState, nState,
                stateNames, stateNames, "_lag");
        matrixBs = loadMatrix(dir.resolve("policy_Bs.csv"), nState, nExo,
                stateNames, expectedShockNames, "");
        matrixC = loadMatrix(dir.resolve("policy_C.csv"), nJump, nState,
                jumpNames, stateNames, "_lag");
        matrixD = loadMatrix(dir.resolve("policy_D.csv"), nJump, nExo,
                jumpNames, expectedShockNames, "");

        // Load shock parameters
        loadShockParams(dir.resolve("shock_params.csv"));

        // Update path recorder with loaded variable names
        pathRecorder.setVariableNames(stateNames, jumpNames, shockNames);

        // Reset to steady state
        resetToSteadyState();

        isLoaded = true;
        if (logEnabled) {
            log.info("DSGE model loaded successfully: " + modelName);
            log.info("  State variables: " + nState);
            log.info("  Jump variables: " + nJump);
            log.info("  Exogenous shocks: " + nExo);
            log.info("  Matrix A: " + nState + "×" + nState);
            log.info("  Matrix Bs: " + nState + "×" + nExo);
            log.info("  Matrix C: " + nJump + "×" + nState);
            log.info("  Matrix D: " + nJump + "×" + nExo);
            log.info("  eps_L index: " + idxEpsL + ", eps_h index: " + idxEpsH);
        }
    }

    /**
     * Load model metadata from JSON file.
     * Extracts dimensions, variable names, and index mappings.
     */
    private void loadModelInfo(Path jsonPath) throws IOException {
        String content = Files.readString(jsonPath);

        // Extract model name
        modelName = extractJsonString(content, "model_name");
        endoNames = extractJsonArray(content, "endo_names");

        // Extract dimensions dynamically from model metadata
        nState = extractJsonInt(content, "n_state");
        nJump = extractJsonInt(content, "n_jump");
        nExo = extractJsonInt(content, "n_exo");

        if (nState <= 0 || nJump <= 0 || nExo <= 0) {
            throw new IllegalArgumentException(String.format(
                "Invalid model dimensions in %s: n_state=%d, n_jump=%d, n_exo=%d",
                jsonPath, nState, nJump, nExo));
        }

        // Extract variable names
        stateNames = extractJsonArray(content, "state_names");
        jumpNames = extractJsonArray(content, "jump_names");

        // Extract index maps for state and jump variable indices
        Map<String, Integer> stateIdx = extractJsonIntMap(content, "state_idx_in_s");
        Map<String, Integer> jumpIdx = extractJsonIntMap(content, "jump_idx_in_y");
        varIndices = new DSGEState.VarIndices(stateIdx, jumpIdx);

        // Extract shock indices. There is deliberately no default: the historical
        // fallbacks (eps_L=3, eps_h=6) belong to a superseded schema in which 3 was
        // eps_L. In the current export 3 is eps_p, so defaulting would route SimPaths'
        // labour-supply signal into the cost-push slot and scale it by sigma_p, with
        // nothing in the logs to show for it. A bundle that cannot state its own shock
        // layout must not load.
        Map<String, Integer> shockIdx = extractJsonIntMap(content, "shock_indices_java");
        if (shockIdx.isEmpty()) {
            throw new IllegalStateException(String.format(
                    "%s has no usable shock_indices_java map. The DSGE shock layout cannot "
                    + "be inferred; re-export the macro files.", jsonPath.getFileName()));
        }
        for (String required : new String[] {"eps_L", "eps_h"}) {
            if (!shockIdx.containsKey(required)) {
                throw new IllegalStateException(String.format(
                        "%s: shock_indices_java is missing '%s', which the SimPaths coupling "
                        + "writes directly. Re-export the macro files.",
                        jsonPath.getFileName(), required));
            }
        }
        idxEpsL = shockIdx.get("eps_L");
        idxEpsH = shockIdx.get("eps_h");

        // The eps_L/eps_h channel is in PERCENT log-deviations only because the model
        // is estimated on 100x-log-dev data. That fact lived in prose on both sides
        // and was silently violated by ~100x once (pre-2026-08 attenuation bug). The
        // bundle declares it since 2026-08-19; refuse one that does not, or that
        // declares a scale different from what LaborSupplyAggregator applies.
        double declaredScale = MacroJson.number(content, "simpaths_input_scale", 0.0);
        if (declaredScale != LaborSupplyAggregator.PERCENT_PER_LOG_DEV) {
            throw new IllegalStateException(String.format(
                    "%s declares simpaths_input_scale=%s but this build converts labour "
                    + "supply at x%.0f (LaborSupplyAggregator.PERCENT_PER_LOG_DEV). The "
                    + "unit conventions have separated%s; re-export the macro files — "
                    + "never rescale downstream.",
                    jsonPath.getFileName(),
                    declaredScale == 0.0 ? "nothing" : String.valueOf(declaredScale),
                    LaborSupplyAggregator.PERCENT_PER_LOG_DEV,
                    declaredScale == 0.0 ? " (field missing: bundle predates the units contract)" : ""));
        }

        // Shock column order for validating policy_Bs / policy_D headers
        expectedShockNames = new String[nExo];
        for (Map.Entry<String, Integer> e : shockIdx.entrySet()) {
            int idx = e.getValue();
            if (idx < 0 || idx >= nExo) {
                throw new IllegalStateException(String.format(
                        "%s: shock_indices_java maps '%s' to %d, outside [0,%d).",
                        jsonPath.getFileName(), e.getKey(), idx, nExo));
            }
            expectedShockNames[idx] = e.getKey();
        }

        if (logEnabled) {
            log.info("  Loaded model dimensions: state=" + nState + ", jump=" + nJump + ", exo=" + nExo);
        }
    }

    /**
     * Load a matrix from CSV file with strict dimension validation.
     *
     * @param csvPath Path to CSV file
     * @param expectedRows Expected number of data rows (excluding header)
     * @param expectedCols Expected number of data columns (excluding row names)
     * @return Loaded matrix
     * @throws IOException If file cannot be read
     * @throws IllegalArgumentException If dimensions don't match
     */
    private double[][] loadMatrix(Path csvPath, int expectedRows, int expectedCols,
                                  String[] expectedRowNames, String[] expectedColNames,
                                  String colNameSuffix) throws IOException {
        List<String> lines = Files.readAllLines(csvPath);

        if (lines.isEmpty()) {
            throw new IllegalArgumentException("Empty matrix file: " + csvPath);
        }

        // Validate row count (lines = header + data rows)
        int dataRows = lines.size() - 1;
        if (dataRows < expectedRows) {
            throw new IllegalArgumentException(String.format(
                "Matrix file %s has %d data rows, expected %d",
                csvPath.getFileName(), dataRows, expectedRows));
        }

        // The matrices are consumed positionally, so a file refreshed from a different
        // export run would misalign silently. The names in the bundle are the only
        // evidence that this file's layout is the one model_info.json describes.
        validateHeaderNames(csvPath, lines.get(0), expectedColNames, colNameSuffix);

        double[][] matrix = new double[expectedRows][expectedCols];

        for (int i = 1; i <= expectedRows; i++) {
            String[] parts = MacroCsv.splitRow(lines.get(i));

            // Validate column count (parts = row name + data columns)
            int dataCols = parts.length - 1;
            if (dataCols < expectedCols) {
                throw new IllegalArgumentException(String.format(
                    "Matrix file %s row %d has %d data columns, expected %d",
                    csvPath.getFileName(), i, dataCols, expectedCols));
            }

            String rowName = parts[0].trim();
            if (!rowName.equals(expectedRowNames[i - 1])) {
                throw new IllegalArgumentException(String.format(
                    "Matrix file %s row %d is '%s' but model_info.json expects '%s'. "
                    + "The bundle is inconsistent - re-export the macro files rather than "
                    + "copying individual CSVs between export runs.",
                    csvPath.getFileName(), i, rowName, expectedRowNames[i - 1]));
            }

            // First column is row name, skip it
            for (int j = 1; j <= expectedCols; j++) {
                try {
                    double value = Double.parseDouble(parts[j].trim());
                    if (!Double.isFinite(value)) {
                        throw new IllegalArgumentException(String.format(
                            "Non-finite value at row %d col %d in %s: %s",
                            i, j, csvPath.getFileName(), parts[j]));
                    }
                    matrix[i-1][j-1] = value;
                } catch (NumberFormatException e) {
                    throw new IllegalArgumentException(String.format(
                        "Invalid number at row %d col %d in %s: '%s'",
                        i, j, csvPath.getFileName(), parts[j]));
                }
            }
        }

        return matrix;
    }

    /**
     * Validate a CSV header row against the names the bundle declares for those columns.
     *
     * @param colNameSuffix appended to each expected name (the matrices label lagged
     *                      state columns "c_lag", "R_lag", ...); empty for shock columns
     */
    private void validateHeaderNames(Path csvPath, String headerLine,
                                     String[] expectedColNames, String colNameSuffix) {
        String[] header = MacroCsv.splitRow(headerLine);
        if (header.length - 1 < expectedColNames.length) {
            throw new IllegalArgumentException(String.format(
                "Matrix file %s header has %d columns, expected %d",
                csvPath.getFileName(), header.length - 1, expectedColNames.length));
        }
        for (int j = 0; j < expectedColNames.length; j++) {
            String actual = header[j + 1].trim();
            String expected = expectedColNames[j] + colNameSuffix;
            if (!actual.equals(expected)) {
                throw new IllegalArgumentException(String.format(
                    "Matrix file %s column %d is '%s' but model_info.json expects '%s'. "
                    + "The bundle is inconsistent - re-export the macro files rather than "
                    + "copying individual CSVs between export runs.",
                    csvPath.getFileName(), j + 1, actual, expected));
            }
        }
    }

    /**
     * Load shock parameters (stderr and rho) from CSV.
     *
     * <p>Row count and names are validated against the export's own shock layout: a short
     * file previously left trailing shocks at sigma=0, which silently disables their
     * scaling in {@link #stepQuarterly} instead of failing.</p>
     */
    private void loadShockParams(Path csvPath) throws IOException {
        List<String> lines = Files.readAllLines(csvPath);

        int dataRows = lines.size() - 1;
        if (dataRows < nExo) {
            throw new IllegalArgumentException(String.format(
                "Shock parameter file %s has %d shock rows, expected %d. A short file "
                + "would leave trailing shocks at sigma=0, silently disabling their scaling.",
                csvPath.getFileName(), dataRows, nExo));
        }

        shockNames = new String[nExo];
        shockStdDev = new double[nExo];
        shockRho = new double[nExo];

        for (int i = 1; i <= nExo; i++) {
            String[] parts = MacroCsv.splitRow(lines.get(i));
            if (parts.length < 3) {
                throw new IllegalArgumentException(String.format(
                    "Shock parameter file %s row %d has %d fields, expected at least 3",
                    csvPath.getFileName(), i, parts.length));
            }
            String name = parts[0].trim();
            if (!name.equals(expectedShockNames[i - 1])) {
                throw new IllegalArgumentException(String.format(
                    "Shock parameter file %s row %d is '%s' but shock_indices_java expects "
                    + "'%s'. Re-export the macro files.",
                    csvPath.getFileName(), i, name, expectedShockNames[i - 1]));
            }
            shockNames[i - 1] = name;
            shockStdDev[i - 1] = parseField(csvPath, i, 1, parts[1]);
            shockRho[i - 1] = parseField(csvPath, i, 2, parts[2]);
        }

        // SimPaths writes eps_L/eps_h as LEVEL deviations every quarter, so the
        // frozen export must carry rho_L = rho_h = 0 (@#define for_simpaths_export).
        // A bundle exported without that define accumulates the level inputs through
        // an AR(1) — a compounding corruption of the SimPaths->DSGE channel with
        // nothing in the logs. The rho column exists here so this side can refuse it.
        for (int idx : new int[] {idxEpsL, idxEpsH}) {
            if (shockRho[idx] != 0.0) {
                throw new IllegalArgumentException(String.format(
                        "%s declares rho=%.4f for %s, but SimPaths level inputs require rho=0. "
                        + "The frozen model was exported without @#define for_simpaths_export = "
                        + "true. Re-run generate_frozen_model + export_dynamic_for_simpaths.",
                        csvPath.getFileName(), shockRho[idx], shockNames[idx]));
            }
        }
    }

    private double parseField(Path csvPath, int row, int col, String raw) {
        try {
            double value = Double.parseDouble(raw.trim());
            if (!Double.isFinite(value)) {
                throw new IllegalArgumentException(String.format(
                    "Non-finite value at row %d col %d in %s: %s",
                    row, col, csvPath.getFileName(), raw));
            }
            return value;
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException(String.format(
                "Invalid number at row %d col %d in %s: '%s'",
                row, col, csvPath.getFileName(), raw));
        }
    }

    // ========== JSON Parsing Helpers ==========
    // Thin delegates to MacroJson, the single reader shared with
    // RamseyTrendModel and MacroModelManager. Do not re-inline a local parser:
    // the three copies these replaced disagreed on whitespace after the colon,
    // so a change of MATLAB writer would have zeroed parameters silently.

    private String extractJsonString(String json, String key) {
        return MacroJson.string(json, key, "");
    }

    private int extractJsonInt(String json, String key) {
        return MacroJson.integer(json, key, 0);
    }

    private String[] extractJsonArray(String json, String key) {
        return MacroJson.stringArray(json, key);
    }

    /**
     * Extract a JSON object of string-to-int mappings, e.g.
     * {@code "key":{"a":0,"b":1}}.
     */
    private Map<String, Integer> extractJsonIntMap(String json, String key) {
        return MacroJson.intMap(json, key);
    }

    // ========== State Management ==========

    /**
     * Reset the model state to steady state (all zeros).
     */
    public void resetToSteadyState() {
        if (currentState != null) {
            Arrays.fill(currentState, 0.0);
        }
    }

    /**
     * Set the current state vector explicitly.
     * @param state State vector (must match loaded nState dimensions)
     */
    public void setState(double[] state) {
        checkLoaded();
        if (state.length != nState) {
            throw new IllegalArgumentException("State must have " + nState + " elements");
        }
        System.arraycopy(state, 0, currentState, 0, nState);
    }

    /**
     * Get the current state vector.
     * @return Copy of current state
     */
    public double[] getState() {
        return currentState != null ? currentState.clone() : new double[0];
    }

    // ========== Policy Function Evaluation ==========

    /**
     * Evaluate one quarterly step of the DSGE model.
     *
     * Computes:
     *     s_t = A  × s_{t-1} + Bs × ε_t    (state transition)
     *     y_t = C  × s_{t-1} + D  × ε_t    (jump variables)
     *
     * <h3>Shock Input Conventions</h3>
     * <p>Two different conventions are used depending on the shock source:</p>
     * <ul>
     *   <li><b>SimPaths level inputs (eps_L, eps_h)</b>: PERCENT log-deviations from baseline
     *       (100 &times; ln ratio). Example: eps_L &asymp; 4.879 means labor force is 5% above baseline.
     *       These are passed directly to the policy matrices WITHOUT further scaling,
     *       because the DSGE model equations define L = eps_L (with rho_L = 0) and the
     *       model's units are percent (it is estimated on 100&times;log-dev data).</li>
    *   <li><b>Other shocks (eps_a, eps_r, eps_d, eps_p, eps_sep, eps_inv)</b>: Standard deviation units.
    *       Example: eps_a = 1.0 means a 1-σ technology shock.
    *       These are converted to raw innovations by multiplying by their std dev before
    *       applying to the policy matrices.</li>
     * </ul>
     *
     * @param shocks Array of shock values (length must match nExo).
     *               eps_L, eps_h: percent log-deviations (e.g., 5.0 ≈ 5%)
     *               Others: σ-units (e.g., 1.0 = 1 std dev)
     * @return DSGEState containing all endogenous variables
     * @throws IllegalStateException If model not loaded
     * @throws RuntimeException If state becomes numerically unstable
     */
    public DSGEState stepQuarterly(double[] shocks) {
        checkLoaded();

        if (shocks == null || shocks.length != nExo) {
            throw new IllegalArgumentException("Shocks must have " + nExo + " elements");
        }

        if (shockStdDev == null || shockStdDev.length < nExo) {
            throw new IllegalStateException("Shock standard deviations not loaded");
        }

        // Prepare shocks for policy function application.
        // The policy matrices (Bs, D) contain Dynare's RAW ghu derivatives mapping
        // unit-variance innovations to variable responses. To apply a shock specified
        // in σ-units, we must convert to raw innovations by MULTIPLYING by σ.
        // SimPaths-level inputs (eps_L, eps_h) arrive already in the model's PERCENT
        // units (100×ln ratio, converted in LaborSupplyAggregator) — no scaling here.
        //
        // Cross-validation: ghu(π, eps_d) × σ_d = 0.2704 × 0.3641 = 0.0984 = Dynare IRF(π, eps_d, t=0)
        double[] processedShocks = new double[nExo];
        for (int j = 0; j < nExo; j++) {
            if (j == idxEpsL || j == idxEpsH) {
                // SimPaths level inputs: pass percent log-deviation directly
                processedShocks[j] = shocks[j];
            } else {
                // Other shocks: convert from σ-units to raw innovations (multiply by σ)
                double std = shockStdDev[j];
                if (std > 0.0) {
                    processedShocks[j] = shocks[j] * std;
                } else {
                    processedShocks[j] = shocks[j];
                }
            }
        }

        // Compute s_t = A × s_{t-1} + Bs × ε_t (state variables)
        double[] newState = new double[nState];
        for (int i = 0; i < nState; i++) {
            double sum = 0.0;
            for (int j = 0; j < nState; j++) {
                sum += matrixA[i][j] * currentState[j];
            }
            for (int j = 0; j < nExo; j++) {
                sum += matrixBs[i][j] * processedShocks[j];
            }
            newState[i] = sum;
        }

        // Compute y_t = C × s_{t-1} + D × ε_t (jump variables)
        double[] jumps = new double[nJump];
        for (int i = 0; i < nJump; i++) {
            double sum = 0.0;
            for (int j = 0; j < nState; j++) {
                sum += matrixC[i][j] * currentState[j];
            }
            for (int j = 0; j < nExo; j++) {
                sum += matrixD[i][j] * processedShocks[j];
            }
            jumps[i] = sum;
        }

        // Create state object with loaded variable indices
        DSGEState state = new DSGEState(newState, jumps, varIndices);

        // Update current state for next period
        System.arraycopy(newState, 0, currentState, 0, nState);

        // Stability check
        checkStability();

        return state;
    }

    /**
     * Run 4 quarterly steps and return annual average deviations.
     *
     * <p>The shock represents a LEVEL deviation from baseline (not an innovation).
     * SimPaths computes eps_L = 100 × ln(L_current / L_baseline) — the percent
     * log-deviation of the labor force from baseline at this point in time.</p>
     *
     * @param laborForceShock Labor force shock (eps_L) value — a level deviation
     * @return DSGEState with annual average deviations
     */
    public DSGEState stepAnnual(double laborForceShock) {
        return stepAnnual(laborForceShock, new double[nExo]);
    }

    /**
     * Run 4 quarterly steps with full shock vector.
     * Records quarterly paths if path recording is enabled.
     *
     * <p><b>IMPORTANT:</b> SimPaths shocks (eps_L, eps_h) represent LEVEL deviations from baseline,
     * so they are applied to all 4 quarters to maintain the level throughout the year.
    * Other shocks (for example eps_a, eps_r, eps_d, eps_p, eps_sep, eps_inv) are treated
    * as innovations that enter only in Q1 and propagate via state dynamics in Q2-Q4.</p>
     *
     * @param laborForceShock Primary labor force shock (level deviation)
     * @param otherShocks Additional shocks including eps_h (can be null or empty for zeros)
     * @return DSGEState with annual average deviations
     */
    public DSGEState stepAnnual(double laborForceShock, double[] otherShocks) {
        checkLoaded();

        final double[] shocks = new double[nExo];
        if (otherShocks != null) {
            System.arraycopy(otherShocks, 0, shocks, 0, Math.min(otherShocks.length, nExo));
        }
        shocks[idxEpsL] = laborForceShock;

        return runFourQuarters(q -> {
            if (q == 1) {
                // Q1: all shocks, innovations included.
                return shocks;
            }
            // Q2-Q4: hold the SimPaths level deviations; the innovations were
            // one-off and now propagate through the state dynamics.
            double[] quarterShocks = new double[nExo];
            quarterShocks[idxEpsL] = shocks[idxEpsL];
            quarterShocks[idxEpsH] = shocks[idxEpsH];
            return quarterShocks;
        });
    }

    /**
     * Run 4 quarterly steps with per-quarter exogenous scenario shocks.
     *
     * <p>This method supports counterfactual simulations where exogenous DSGE shocks
     * (e.g., cost-push, technology, monetary) are specified for each quarter via a
     * {@link DSGEShockScenario}. The scenario shocks are <b>additive</b> to the
     * SimPaths-generated labor supply shocks (eps_L, eps_h).</p>
     *
     * <p>For each quarter:</p>
     * <ul>
     *   <li>SimPaths level shocks (eps_L, eps_h) are applied every quarter (level deviations)</li>
     *   <li>Scenario shocks for that specific quarter are added on top</li>
     *   <li>With no scenario, this matches {@link #stepAnnual(double, double[])}
     *       only when its {@code otherShocks} are zero: stepAnnual applies non-SimPaths
     *       shocks in Q1 alone, whereas a scenario declares them per quarter</li>
     * </ul>
     *
     * @param laborForceShock SimPaths labor force shock (level deviation, applied every quarter)
     * @param hoursShock      SimPaths hours shock (level deviation, applied every quarter)
     * @param scenario        optional shock scenario (null = no exogenous shocks)
     * @param year            simulation year (for scenario lookup)
     * @return DSGEState with annual average deviations
     */
    public DSGEState stepAnnualWithScenario(double laborForceShock, double hoursShock,
                                             DSGEShockScenario scenario, int year) {
        checkLoaded();

        return runFourQuarters(q -> {
            double[] quarterShocks = new double[nExo];
            quarterShocks[idxEpsL] = laborForceShock;
            quarterShocks[idxEpsH] = hoursShock;
            if (scenario != null) {
                double[] scenarioShocks = scenario.getShocks(year, q);
                for (int j = 0; j < nExo; j++) {
                    quarterShocks[j] += scenarioShocks[j];
                }
            }
            return quarterShocks;
        });
    }

    /** Supplies the shock vector for quarter {@code q} (1-based). */
    @FunctionalInterface
    private interface QuarterShocks {
        double[] forQuarter(int q);
    }

    /**
     * Advance four quarters and return the annual average state.
     *
     * <p>The loop, the path recording, the accumulation and the averaging are
     * identical for every annual step; only the per-quarter shock vector differs.
     * {@link #stepAnnual(double, double[])} and
     * {@link #stepAnnualWithScenario(double, double, DSGEShockScenario, int)} held
     * separate copies of all of it and had already begun to drift apart
     * stylistically (one indexed q=0..3, the other q=1..4). A divergence here would
     * change the annual aggregation on one path only, which is not something any
     * single-path test would catch.</p>
     */
    private DSGEState runFourQuarters(QuarterShocks shocksForQuarter) {
        double[] sumState = new double[nState];
        double[] sumJumps = new double[nJump];

        for (int q = 1; q <= 4; q++) {
            double[] quarterShocks = shocksForQuarter.forQuarter(q);
            DSGEState quarterState = stepQuarterly(quarterShocks);

            if (pathRecorder != null && pathRecorder.isEnabled()) {
                pathRecorder.recordQuarter(currentYear, q, quarterState, quarterShocks);
            }

            double[] qState = quarterState.getStateVector();
            double[] qJumps = quarterState.getJumpVector();
            for (int i = 0; i < nState; i++) {
                sumState[i] += qState[i];
            }
            for (int i = 0; i < nJump; i++) {
                sumJumps[i] += qJumps[i];
            }
        }

        double[] annualState = new double[nState];
        double[] annualJumps = new double[nJump];
        for (int i = 0; i < nState; i++) {
            annualState[i] = sumState[i] / 4.0;
        }
        for (int i = 0; i < nJump; i++) {
            annualJumps[i] = sumJumps[i] / 4.0;
        }
        return new DSGEState(annualState, annualJumps, varIndices);
    }

    /**
     * Check that model state hasn't exploded (numerical stability).
     */
    private void checkStability() {
        for (int i = 0; i < nState; i++) {
            double val = currentState[i];

            if (!Double.isFinite(val)) {
                throw new RuntimeException(String.format(
                    "DSGE state[%d] is %s (not finite). Model numerically unstable. " +
                    "This typically indicates a matrix computation error or explosive dynamics.",
                    i, Double.isNaN(val) ? "NaN" : "Infinity"));
            }

            if (Math.abs(val) > maxStateDeviation) {
                throw new RuntimeException(String.format(
                    "DSGE state[%d] exceeded bounds: %.4f (max allowed: ±%.1f). " +
                    "Model appears numerically unstable or shock too large. " +
                    "Consider increasing mm_dsgeMaxStateDeviation (current: %.1f).",
                    i, val, maxStateDeviation, maxStateDeviation));
            }
        }
    }

    private void checkLoaded() {
        if (!isLoaded) {
            throw new IllegalStateException("DSGE model not loaded. Call loadFromDirectory() first.");
        }
    }

    // ========== Getters ==========

    public boolean isLoaded() {
        return isLoaded;
    }

    public void setLogEnabled(boolean logEnabled) {
        this.logEnabled = logEnabled;
    }

    public double getMaxStateDeviation() {
        return maxStateDeviation;
    }

    public void setMaxStateDeviation(double maxStateDeviation) {
        if (maxStateDeviation <= 0) {
            throw new IllegalArgumentException("maxStateDeviation must be positive, got: " + maxStateDeviation);
        }
        this.maxStateDeviation = maxStateDeviation;
    }

    public String getModelName() {
        return modelName;
    }

    public int getNumEndogenous() {
        return nState + nJump;
    }

    public int getNumStates() {
        return nState;
    }

    public int getNumJumps() {
        return nJump;
    }

    public int getNumShocks() {
        return nExo;
    }

    /** Get the shock index for eps_L (labor force shock). */
    public int getIdxEpsL() {
        return idxEpsL;
    }

    /** Get the shock index for eps_h (hours shock). */
    public int getIdxEpsH() {
        return idxEpsH;
    }

    /** Get the variable indices used for DSGEState construction. */
    public DSGEState.VarIndices getVarIndices() {
        return varIndices;
    }

    public double[] getShockStdDev() {
        return shockStdDev != null ? shockStdDev.clone() : null;
    }

    public double[] getShockRho() {
        return shockRho != null ? shockRho.clone() : null;
    }

    public String[] getEndoNames() {
        return endoNames != null ? endoNames.clone() : null;
    }

    public String[] getStateNames() {
        return stateNames != null ? stateNames.clone() : null;
    }

    public String[] getJumpNames() {
        return jumpNames != null ? jumpNames.clone() : null;
    }

    public String[] getShockNames() {
        return shockNames != null ? shockNames.clone() : null;
    }

    /**
     * Get the A matrix (state transition).
     * @return Copy of matrix A (nState × nState)
     */
    public double[][] getMatrixA() {
        if (matrixA == null) return null;
        double[][] copy = new double[nState][nState];
        for (int i = 0; i < nState; i++) {
            System.arraycopy(matrixA[i], 0, copy[i], 0, nState);
        }
        return copy;
    }

    /**
     * Get the Bs matrix (shock impact on states).
     * @return Copy of matrix Bs (nState × nExo)
     */
    public double[][] getMatrixBs() {
        if (matrixBs == null) return null;
        double[][] copy = new double[nState][nExo];
        for (int i = 0; i < nState; i++) {
            System.arraycopy(matrixBs[i], 0, copy[i], 0, nExo);
        }
        return copy;
    }

    /**
     * Get the C matrix (jump response to lagged states).
     * @return Copy of matrix C (nJump × nState)
     */
    public double[][] getMatrixC() {
        if (matrixC == null) return null;
        double[][] copy = new double[nJump][nState];
        for (int i = 0; i < nJump; i++) {
            System.arraycopy(matrixC[i], 0, copy[i], 0, nState);
        }
        return copy;
    }

    /**
     * Get the D matrix (jump response to shocks).
     * @return Copy of matrix D (nJump × nExo)
     */
    public double[][] getMatrixD() {
        if (matrixD == null) return null;
        double[][] copy = new double[nJump][nExo];
        for (int i = 0; i < nJump; i++) {
            System.arraycopy(matrixD[i], 0, copy[i], 0, nExo);
        }
        return copy;
    }

    // ========== Path Recording Methods ==========

    public void setCurrentYear(int year) {
        this.currentYear = year;
    }

    public int getCurrentYear() {
        return currentYear;
    }

    public MacroPathRecorder getPathRecorder() {
        return pathRecorder;
    }

    public void setPathRecordingEnabled(boolean enabled) {
        if (pathRecorder != null) {
            pathRecorder.setEnabled(enabled);
        }
    }

    public boolean isPathRecordingEnabled() {
        return pathRecorder != null && pathRecorder.isEnabled();
    }

    public void exportPaths(String outputFolder) throws java.io.IOException {
        exportPaths(outputFolder, "MacroPaths.csv");
    }

    public void exportPaths(String outputFolder, String filename) throws java.io.IOException {
        if (pathRecorder != null && pathRecorder.hasData()) {
            pathRecorder.exportToSimPathsOutput(outputFolder, filename);
        }
    }
}
