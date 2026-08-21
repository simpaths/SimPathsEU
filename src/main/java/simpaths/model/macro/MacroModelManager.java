package simpaths.model.macro;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.DoubleAdder;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.commons.collections4.map.MultiKeyMap;
import org.apache.log4j.Logger;

import microsim.annotation.GUIparameter;
import simpaths.data.Parameters;
import simpaths.model.BenefitUnit;
import simpaths.model.Person;
import simpaths.model.enums.Labour;
import simpaths.model.enums.MacroFeedbackMargins;
import simpaths.model.enums.UpratingCase;

/**
 * Facade class managing all DSGE macro model integration with SimPaths.
 * 
 * <p>This class encapsulates all DSGE-related state and logic, keeping
 * SimPathsModel clean and focused on microsimulation orchestration.</p>
 * 
 * <h3>Integration Mode</h3>
 * <ul>
 *   <li><b>Dynamic Integration</b>: Uses the dynamic state-space DSGE model
 *       (s_t = A×s_{t-1} + B×ε). Single pass per year: labor market runs once,
 *       labor supply is aggregated, and the DSGE state evolves forward.</li>
 * </ul>
 * 
 * <h3>Responsibilities</h3>
 * <ul>
 *   <li>Loading and initializing DSGE models from CSV files</li>
 *   <li>Managing single-pass dynamic equilibrium updates</li>
 *   <li>Storing current wage/inflation deviations for individual wage adjustments</li>
 *   <li>Logging and diagnostics for debugging feedback chain</li>
 * </ul>
 * 
 * <h3>Usage</h3>
 * <pre>{@code
 * MacroModelManager dsge = new MacroModelManager();
 * dsge.setEnabled(true);
 * 
 * // In yearly schedule
 * dsge.updateEquilibrium(year, startYear, country, persons, benefitUnits, alignEmployment);
 * 
 * // Get wage deviation for individual wage equations
 * double wageMultiplier = 1.0 + dsge.getWageDeviation() / 100.0;
 * }</pre>
 * 
 * @author DSGE-SimPaths Integration
 * @version 2.0 (dynamic-only integration)
 */
public class MacroModelManager {
    
    private static final Logger log = Logger.getLogger(MacroModelManager.class);
    private static final String MACRO_PATHS_FILENAME = "MacroPaths.csv";
    private static final Pattern HANDOFF_TIME_PATTERN = Pattern.compile("\"handoff_time\"\\s*:\\s*\"([^\"]+)\"");
    private static final Pattern PROJECTION_QUARTERS_PATTERN =
            Pattern.compile("\"projection_quarters\"\\s*:\\s*(\\d+)");
    private static final Pattern QUARTER_LABEL_PATTERN =
            Pattern.compile("(\\d{4})q([1-4])");

    /** Forward horizon used before the exporter declared it (80 years). */
    private static final int LEGACY_PROJECTION_QUARTERS = 320;

    /** Forward horizon of the Ramsey handoff, taken from growth_terminal_state.json. */
    private int ramseyProjectionQuarters = LEGACY_PROJECTION_QUARTERS;

    /**
     * Handoff quarter declared by growth_terminal_state.json, e.g. "2023q1".
     *
     * <p>Every macro artifact is aligned to this quarter, and they are merged by DATE
     * rather than by row position. Positional merging is how a start-year change
     * silently corrupted a run: the reference CSV and the population projection both
     * carry a time column, both were consumed by index, and regenerating only some
     * artifacts left the splice off by however many quarters with every check still
     * passing.</p>
     */
    private String ramseyHandoffQuarter;
    private static final int DEMOGRAPHIC_TAIL_HALF_LIFE_QUARTERS = 20;
    
    // ========== Configuration ==========
    
    @GUIparameter(description = "Enable DSGE macro model for wage/inflation feedback")
    private boolean enabled = false;

    @GUIparameter(description = "Enable DSGE cycle layer alongside the macro trend layer")
    private boolean useDsge = false;
    
    @GUIparameter(description = "Log macro state each year to console")
    private boolean logMacroState = false;

    @GUIparameter(description = "Enable verbose macro diagnostics (iteration internals and sample micro logs)")
    private boolean verboseMacroLogging = false;

    @GUIparameter(description = "Path to exogenous shock scenario CSV (relative to MacroModel dir, empty = baseline with no exogenous shocks)")
    private String dsgeShockScenario = "";

    /** Maximum state deviation before stability check fires (log-deviation units, default 10.0) */
    private double maxBounds = 10.0;

    @GUIparameter(description = "Use Ramsey growth model for secular wage trend")
    private boolean useRamseyTrend = true;

    /**
     * Standalone recorder mode: record labor supply paths (MacroPaths.csv)
     * without any macro model feedback. When true AND enabled==false, only
     * the LaborSupplyAggregator and MacroPathRecorder are active; no DSGE,
     * no Ramsey, no wage/inflation feedback. All DSGE/trend columns are zero;
     * only l_level, h_level, participation_rate, and workers_over_atRiskPool
     * are populated from SimPaths behavioral labor supply.
     */
    private boolean recorderOnlyMode = false;

    /**
     * Whether path recording (MacroPaths.csv) is enabled. This is orthogonal to
     * macro model usage: the macro model can run without recording, and recording
     * can run without a macro model (recorder-only mode).
     */
    private boolean pathRecordingEnabled = true;

    @GUIparameter(description = "CSV file name for Ramsey scenario (relative to MacroModel dir, empty = baseline)")
    private String ramseyScenario = "";

    /**
     * Which realized labour-supply margins enter the yearly extended-path re-solve. Both by
     * default: the labour input is N*h, so single-margin feedback gets the capital-dilution
     * response wrong, in sign as well as size, whenever SimPaths moves the two margins in
     * opposite directions. The single-margin modes exist to decompose the channel.
     */
    private MacroFeedbackMargins ramseyFeedbackMargins = MacroFeedbackMargins.EMPLOYMENT_AND_HOURS;
    /** Belief persistence of the realized employment gap: 1 = permanent, 0 = current year only. */
    private double ramseyFeedbackPersistence = 1.0;
    /** Belief persistence of the realized hours gap. Separate from the headcount belief because
     *  hours deviations in SimPaths come from labour-category switching and are more plausibly
     *  transitory than headcount deviations. */
    private double ramseyFeedbackHoursPersistence = 1.0;
    /** SimPaths -> Ramsey level factor, latched in the first post-labour-market year. */
    private double ramseyFeedbackLambda = Double.NaN;
    /**
     * SimPaths' own hours-per-worker level in the latch year, the reference the realized hours
     * gap is measured against. Deliberately NOT a ratio to the planner's hours path, unlike
     * {@link #ramseyFeedbackLambda}: see {@link #applyRamseyFeedbackWithRealized(int, double, double)}.
     */
    private double ramseyFeedbackHoursBase = Double.NaN;
    /** Calendar year of quarter 0 of the currently solved Ramsey path (startYear, then each re-solve year). */
    private int ramseyQuarterZeroYear;
    /** Original projection slices passed to the startup solve; index 0 = startYear q1. */
    private double[] ramseyProjN;
    private double[] ramseyProjH;
    private double[] ramseyProjGY;
    private double[] ramseyProjNXY;
    private int ramseyProjLen = 0;

    // ========== Internal State ==========
    
    /** Dynamic DSGE model (state-space with A,B,C,D matrices) - for dynamic integration */
    private DSGEModel dynamicDsgeModel;

    /** Recorder used when DSGE is disabled and only Ramsey trends are exported */
    private MacroPathRecorder trendOnlyPathRecorder;

    /** Exogenous shock scenario for counterfactual simulations (dynamic mode only) */
    private DSGEShockScenario shockScenario;
    
    /** Labor supply aggregator (shared between both modes) */
    private LaborSupplyAggregator laborSupplyAggregator;
    
    /** Ramsey scenario for long-run counterfactual analysis */
    private RamseyScenario ramseyScenarioObj;

    /** Simulation start year (stored on first updateEquilibrium call for Ramsey scenario mapping) */
    private int simulationStartYear;

    /** Flag indicating DSGE model is initialized */
    private boolean initialized = false;
    
    /** Current wage deviation from DSGE (in %, e.g., 2.5 means wages are 2.5% above steady state) */
    private double wageDeviation = 0.0;
    
    /** Current inflation deviation from DSGE (in percentage points) */
    private double inflationDeviation = 0.0;
    
    /** Secular wage trend adjustment (in %, typically from Ramsey trend) */
    private double capitalDeepeningWageAdjustment = 0.0;

    /** Ramsey growth model providing structural trend paths (wages, output, r*) */
    private RamseyTrendModel ramseyTrend;

    /**
     * Quarter-0 Ramsey levels, against which every trend column is expressed as a
     * percentage. Null until the trend is initialised, and reset to null whenever
     * the Ramsey layer falls back.
     *
     * <p>This was eight parallel scalars latched from the same TrendState. Adding a
     * variable to the trend layer meant four synchronised edits (declare, latch,
     * reset, divide), and missing one yielded a silent 0.0 column rather than an
     * error. Holding the whole state keeps them in step by construction.</p>
     */
    private RamseyTrendModel.TrendState ramseyBaseline;

    /** Current year's Ramsey trend state (set by advanceRamseyTrend, read by logging) */
    private RamseyTrendModel.TrendState ramseyCurrentYearState;

    /**
     * Current Ramsey trend percentages for all key variables.
     * Keys: "w", "y", "c", "inv", "k". Values: % deviation from first-year baseline.
     * Passed to path recorders each year for CSV export.
     */
    private Map<String, Double> currentRamseyTrends = new LinkedHashMap<>();

    /**
     * Start-year anchor for the realized-wage diagnostic. Latched on the first
     * call to {@link #populateRealizedWageIndex(Set)} once a non-empty at-risk
     * pool wage sample is available; remains 0.0 until then. The exported
     * {@code wage_realized} column is {@code (meanWage / anchor - 1) * 100}, so
     * the series is 0 in the start year — matching the {@code w_trend} /
     * {@code w_total} "% from first year" convention.
     *
     * <p><b>The anchor is NOT comparable across run modes.</b> It is latched at
     * whichever schedule point first reaches this method with a usable pool, and
     * that point differs by mode: a macro-on run reaches it after the start-year
     * wage regression has been redrawn, so the anchor is a regression wage; a
     * recorder-only run reaches it before any redraw, so the anchor is the
     * database wage carried in from the input population. The two anchors differ
     * by the redraw, which means the {@code wage_realized} <i>level</i> in the
     * first few years partly reflects anchor construction rather than any
     * macro effect.</p>
     *
     * <p>Consequence for analysis: compare {@code wage_realized} across runs of
     * the <b>same</b> mode, or compare growth rates rather than levels. Do not
     * read an early-year gap between a macro-on and a recorder-only run as a
     * treatment effect. The series is a diagnostic; nothing in the model
     * consumes it. (Audit §6, item 2c.)</p>
     */
    private double startYearAtRiskWage = 0.0;

    // ========== Diagnostic Summary Tracking ==========

    private int diagnosticsCount = 0;
    private double epsLMin = Double.POSITIVE_INFINITY;
    private double epsLMax = Double.NEGATIVE_INFINITY;
    private double epsHMin = Double.POSITIVE_INFINITY;
    private double epsHMax = Double.NEGATIVE_INFINITY;
    private double wageDevMin = Double.POSITIVE_INFINITY;
    private double wageDevMax = Double.NEGATIVE_INFINITY;
    private double inflDevMin = Double.POSITIVE_INFINITY;
    private double inflDevMax = Double.NEGATIVE_INFINITY;
    private double outputDevMin = Double.POSITIVE_INFINITY;
    private double outputDevMax = Double.NEGATIVE_INFINITY;
    private double employmentDevMin = Double.POSITIVE_INFINITY;
    private double employmentDevMax = Double.NEGATIVE_INFINITY;
    private double epsLSum = 0.0;
    private double epsHSum = 0.0;
    private double wageDevSum = 0.0;
    private double inflDevSum = 0.0;
    private double outputDevSum = 0.0;
    private double employmentDevSum = 0.0;
    
    // ========== Tracking for Diagnostics ==========
    
    /** Counter for DSGE wage adjustments applied (reset each year, for logging). Thread-safe for parallelStream access. */
    private final AtomicInteger wageAdjustmentCount = new AtomicInteger(0);
    
    /** Sum of wage adjustments for logging average effect. Thread-safe for parallelStream access. */
    private final DoubleAdder wageAdjustmentSum = new DoubleAdder();
    
    /** Counter for labor supply decisions logged */
    private int laborSupplyLogCount = 0;
    
    /** Maximum number of labor supply decisions to log per iteration */
    private static final int MAX_LABOR_SUPPLY_LOG_SAMPLES = 2;
    
    // ========== Constructor ==========
    
    /**
     * Create a new DSGE model manager.
     * 
     * <p>The manager is created in disabled state. Call {@link #setEnabled(boolean)}
     * to enable DSGE integration.</p>
     */
    public MacroModelManager() {
        // Default configuration - DSGE disabled
    }
    
    // ========== Main Update Method ==========
    
    /**
     * Update DSGE equilibrium for the current year.
     * 
     * <p>This is the main entry point called from SimPathsModel. It handles:</p>
     * <ol>
     *   <li>Initialization (on first call)</li>
     *   <li>Single-pass dynamic equilibrium computation</li>
     *   <li>Storing wage/inflation deviations for use in individual wage equations</li>
     * </ol>
     *
     * <p>Dynamic-only coupling: the DSGE never re-runs the labour market within a
     * tick, so there is no callback and no within-period iteration.</p>
     *
     * @param year            Current simulation year
     * @param startYear       First year of simulation (for baseline detection)
     * @param countryCode     Country code (e.g., "PL") for locating model files
     * @param persons         Set of all persons in simulation
     * @param benefitUnits    Set of all benefit units
     * @param alignEmployment Whether employment alignment is enabled
     */
    public void updateEquilibrium(
            int year,
            int startYear,
            String countryCode,
            Set<Person> persons,
            Set<BenefitUnit> benefitUnits,
            boolean alignEmployment
    ) {
        if (!enabled && !recorderOnlyMode) {
            return;  // Neither macro model nor standalone recorder enabled
        }

        // Standalone recorder mode: lightweight path (no DSGE, no Ramsey, no wage feedback)
        if (recorderOnlyMode && !enabled) {
            if (!initialized) {
                this.simulationStartYear = startYear;
                initializeRecorderOnly(countryCode);
                if (logMacroState) {
                    log.info(String.format(
                        "Macro year %d: recorder-only mode initialized (no macro feedback, recording L/h paths).",
                        year));
                }
            }
            if (laborSupplyAggregator != null) {
                // Eagerly latch labour-market-invariant demographic anchors so
                // the demographic indices are emitted from year 1 (the L/h
                // baseline is still latched post-labour-market this tick).
                // runRecorderOnlyPass handles the year-1 (no L/h baseline) case.
                laborSupplyAggregator.latchDemographicAnchors(persons);
                runRecorderOnlyPass(year, persons);
            }
            return;
        }

        // Initialize on first call (year 1 = startYear)
        if (!initialized) {
            this.simulationStartYear = startYear;
            initialize(countryCode, persons);

            if (!useDsge) {
                runRamseyOnlyPass(year, persons);
                if (logMacroState) {
                    log.info(String.format(
                            "Macro year %d: DSGE disabled (mm_useDSGE=false), Ramsey-only trend applied.",
                            year));
                }
                return;
            }
            
            // CRITICAL: Do NOT run DSGE *cycle* feedback in the first simulation year.
            // The baseline L (extensive margin = persons with hours > 0) must be
            // set AFTER the first labor market update, not before. The initial
            // population's hours come from the input database and may differ
            // significantly from what SimPaths' labor supply model assigns.
            // Baseline will be set at the start of year 2 from the post-labor-
            // market population.
            //
            // However, the Ramsey trend is a deterministic forward-solved path
            // that does NOT depend on SimPaths feedback. Advance it now so that
            // wage trends (and scenario effects like higher g_A) are visible
            // immediately in year 1.
            runBaselinePendingPass(year, persons, "first year");
            return;
        }

        if (!useDsge) {
            runRamseyOnlyPass(year, persons);
            return;
        }

        // Strict timing rule: baseline must be latched after labor market update.
        // If it is still missing here, the DSGE cycle cannot run — but the Ramsey
        // trend is a deterministic forward-solved path that does not depend on
        // SimPaths feedback, so emit a Ramsey-only row (cycle = 0) for this year.
        // Without this, MacroPaths.csv would silently miss the year and every
        // cross-run levels comparison would be off by one year of trend growth.
        if (!laborSupplyAggregator.isBaselineSet()) {
            runBaselinePendingPass(year, persons, "baseline pending");
            return;
        }

        // Reset counters for this year
        resetCounters();
        
        // Advance Ramsey trend model (once per year, before DSGE computation)
        if (useRamseyTrend && ramseyTrend != null && ramseyTrend.isSolved()) {
            advanceRamseyTrend();
        }

        // Dynamic DSGE: single pass, state evolves forward.
        // Labor market is not updated internally in dynamic-only mode.
        runDynamicSinglePass(year, persons);
    }
    
    /**
     * Called after UpdatePotentialHourlyEarnings to log wage adjustment summary.
     */
    public void logWageAdjustmentSummary() {
        int count = wageAdjustmentCount.get();
        if (logMacroState && count > 0) {
            double avgAdjustment = wageAdjustmentSum.sum() / count;
            System.out.println(String.format(
                "DSGE Wage Adjustment Summary: %d persons adjusted, avg change = %+.4f EUR/hour",
                count, avgAdjustment));
        }
    }

    /**
     * Log labor supply diagnostics after the labor market update.
     *
     * <p>Includes total wage decomposition and aggregate labor supply
     * relative to baseline to verify wage trend pass-through.</p>
     */
    public void logLaborSupplyDiagnostics(int year, Set<Person> persons, String phaseLabel) {
        if ((!enabled && !recorderOnlyMode) || !logMacroState || laborSupplyAggregator == null) {
            return;
        }
        
        // Skip if baseline not yet set (year 1 — baseline deferred to after labor market)
        if (!laborSupplyAggregator.isBaselineSet()) {
            return;
        }

        var shocks = laborSupplyAggregator.aggregate(persons);
        double baselineL = laborSupplyAggregator.getBaselineL();
        double baselineH = laborSupplyAggregator.getBaselineH();
        double currentL = shocks.aggregates().laborForce();
        double currentH = shocks.aggregates().avgHoursPerWorker();

        double lPct = (currentL / baselineL - 1.0) * 100.0;
        double hPct = (currentH / baselineH - 1.0) * 100.0;

        double wageCycle = wageDeviation - capitalDeepeningWageAdjustment;

        log.info(String.format(
            "DSGE %s (year %d): L=%.0f (%+.3f%% vs base), h=%.2f (%+.3f%% vs base), "
                + "eps_L=%+.4f, eps_h=%+.4f, wage_total=%+.3f%% (cycle=%+.3f%% + trend=%+.3f%%)",
            phaseLabel, year, currentL, lPct, currentH, hPct,
            shocks.epsL(), shocks.epsH(), wageDeviation, wageCycle, capitalDeepeningWageAdjustment
        ));
    }

    /**
     * Latch labor-supply baseline from the current post-labor-market population state.
     *
     * <p>This is intended to be called from SimPathsModel immediately after the
     * first labor market update in the first simulation year, so baseline L/h is
     * anchored on model-assigned hours rather than database-initialized hours.</p>
     *
     * @param year Current simulation year (for logging only)
     * @param persons Current person set after labor market update
     * @return true if baseline was latched by this call, false otherwise
     */
    public boolean latchBaselineFromPostLaborMarket(int year, Set<Person> persons) {
        if ((!enabled && !recorderOnlyMode) || !initialized || laborSupplyAggregator == null) {
            return false;
        }
        if (laborSupplyAggregator.isBaselineSet()) {
            return false;
        }

        laborSupplyAggregator.computeAndSetBaseline(persons);
        if (logMacroState) {
            log.info(String.format(
                "DSGE baseline latched post-labor-market (year %d): L=%.0f employed, h=%.1f hours/week",
                year, laborSupplyAggregator.getBaselineL(),
                laborSupplyAggregator.getBaselineH()));
        }
        return true;
    }

    /**
     * Expose whether labor-supply baseline has been latched.
     * Intended for diagnostics and integration tests.
     */
    public boolean isLaborSupplyBaselineSet() {
        return laborSupplyAggregator != null && laborSupplyAggregator.isBaselineSet();
    }

    /**
     * Re-emit SimPaths-side macro level aggregates against the post-alignment
     * population and overwrite the corresponding columns on the current year's
     * row in the active path recorder.
     *
     * <p>The default capture point for level columns is the DSGEMacroUpdate
     * event, which fires before {@code ConsiderMortality} and
     * {@code PopulationAlignment}. As a result the recorded {@code Pop},
     * {@code WAP}, {@code atRisk} and {@code L} levels for year t reflect the
     * pre-alignment snapshot, and any work the alignment does in year t shows
     * up in the year t+1 row. This call closes that gap so the recorded
     * demographic levels are the year's end-of-year, post-alignment values —
     * the same population the alignment contract aligns to the external
     * projection.</p>
     *
     * <p>Read-only with respect to the rolling baseline ({@code lastL},
     * {@code lastH}, {@code baselineL}, {@code baselineH}): uses
     * {@link LaborSupplyAggregator#computeRawAggregates} so {@code eps_L},
     * {@code eps_h}, {@code advanceBaseline}, the DSGE state, and the Ramsey
     * trend columns are unaffected. Only the SimPaths-aggregated level columns
     * are overwritten.</p>
     *
     * <p>To keep the row internally consistent, all SimPaths-aggregated
     * columns that depend on the population snapshot are re-emitted together:
     * the demographic level indices ({@code l_level}, {@code h_level},
     * {@code participation_rate}, {@code workers_over_atRiskPool},
     * {@code total_population}, {@code wap_level}, {@code atrisk_level}),
     * the labour-category metrics ({@code cat_*_share},
     * {@code cat_*_meanHours}), and the realised-wage index
     * ({@code wage_realized}).</p>
     *
     * @param year    Current simulation year (row to amend)
     * @param persons Post-alignment person set
     */
    public void updateLevelAggregatesPostAlignment(int year, Set<Person> persons) {
        if ((!enabled && !recorderOnlyMode) || !initialized
                || laborSupplyAggregator == null || persons == null) {
            return;
        }
        MacroPathRecorder recorder = getActivePathRecorder();
        if (recorder == null || !recorder.isEnabled()) {
            return;
        }

        LaborSupplyAggregator.LaborSupplyAggregates aggs =
                laborSupplyAggregator.computeRawAggregates(persons);

        Map<String, Double> updates = buildPostAlignmentLevelUpdates(aggs, persons);
        for (Map.Entry<String, Double> entry : updates.entrySet()) {
            recorder.amendTrendForYear(year, entry.getKey(), entry.getValue());
        }

        if (logMacroState) {
            log.info(String.format(
                    "Macro end-of-year capture (year %d): Pop=%.0f, WAP=%.0f, atRisk=%.0f, "
                    + "L=%.0f, h=%.2f (post-alignment).",
                    year, aggs.totalPopulation(), aggs.workingAgePopulation(),
                    aggs.atRiskPool(), aggs.laborForce(), aggs.avgHoursPerWorker()));
        }
    }

    /**
     * Return the path recorder that is currently receiving rows, or null if
     * none is active. Rows go to {@link #trendOnlyPathRecorder} whenever the
     * dynamic DSGE model is absent — that covers both recorder-only mode
     * (macro off) and the macro-on/DSGE-off Ramsey-only configuration, both of
     * which are emitted by {@link #runRamseyOnlyPass} / {@link #runRecorderOnlyPass}
     * into {@link #trendOnlyPathRecorder}. Only when the dynamic DSGE model
     * is loaded do rows go to its embedded recorder.
     */
    private MacroPathRecorder getActivePathRecorder() {
        if (dynamicDsgeModel == null) {
            return trendOnlyPathRecorder;
        }
        return dynamicDsgeModel.getPathRecorder();
    }

    /**
     * Build the map of (column → value) updates that re-express the
     * SimPaths-aggregated level columns against the supplied post-alignment
     * aggregates. Does not touch any field on this manager — purely builds the
     * map from inputs.
     */
    private Map<String, Double> buildPostAlignmentLevelUpdates(
            LaborSupplyAggregator.LaborSupplyAggregates aggs, Set<Person> persons) {
        // Exactly the formulas the in-year pass uses, applied to post-alignment
        // aggregates. Shared rather than mirrored: a divergence here would have
        // corrupted only the end-of-year level columns, which no single-pass
        // test compares against the in-year ones.
        Map<String, Double> m = new LinkedHashMap<>(demographicIndexUpdates(aggs));
        m.putAll(labourCategoryUpdates(aggs));

        // Realised-wage index: mean of full-time hourly earnings potential over
        // the post-alignment at-risk pool, expressed as % from the start-year
        // anchor. Per-person wages do not move between the DSGE step and
        // alignment; only the pool composition changes, so a mid-run re-anchor
        // is impossible by construction here (startYearAtRiskWage was latched
        // at the first call from runDynamicSinglePass / runRecorderOnlyPass).
        Double wageRealized = computeWageRealizedPostAlignment(persons);
        if (wageRealized != null) {
            m.put("wage_realized", wageRealized);
        }

        return m;
    }

    /**
     * Compute the realised-wage index against the supplied (post-alignment)
     * person set without mutating {@link #startYearAtRiskWage} or
     * {@link #currentRamseyTrends}. Returns null if the start-year anchor has
     * not been latched yet or the at-risk pool has no wage observations.
     */
    private Double computeWageRealizedPostAlignment(Set<Person> persons) {
        if (persons == null || persons.isEmpty() || startYearAtRiskWage == 0.0) {
            return null;
        }
        double sum = 0.0;
        int count = 0;
        for (Person p : persons) {
            if (!laborSupplyAggregator.isInAtRiskPool(p)) {
                continue;
            }
            double w = p.getFullTimeHourlyEarningsPotential();
            if (w > 0.0) {
                sum += w;
                count++;
            }
        }
        if (count == 0) {
            return null;
        }
        double mean = sum / count;
        return (mean / startYearAtRiskWage - 1.0) * 100.0;
    }
    
    // ========== Internal Methods ==========
    
    /**
     * Initialize the dynamic DSGE model by loading state-space files from CSV exports.
     */
    private void initialize(String countryCode, Set<Person> persons) {
        // Catch an invalid flag combination before loading any macro artefacts; ramseyTrend
        // is still null here, so the endogenous-labour check below is a no-op until re-run
        // after initializeRamseyTrend.
        validateRamseyFeedbackConfig();

        String macroModelPath = "input" + File.separator + countryCode +
                               File.separator + "MacroModel";

        // Validate directory exists
        File macroDir = new File(macroModelPath);
        if (!macroDir.exists() || !macroDir.isDirectory()) {
            String msg = String.format(
                "DSGE model directory not found: %s%n" +
                "Expected dynamic model files (policy_A.csv, policy_Bs.csv, etc.).%n" +
                "Run Dynare export scripts to generate these files.",
                macroModelPath);
            if (logMacroState) {
                log.error(msg);
            }
            throw new RuntimeException(msg);
        }
        
        try {
            // Create shared labor supply aggregator
            laborSupplyAggregator = new LaborSupplyAggregator();
            laborSupplyAggregator.setLogEnabled(logMacroState);
            // Eagerly latch labour-market-invariant demographic anchors (TotalPop,
            // WAP, AtRisk) from the year-1 population so the demographic indices
            // are emitted from the first simulated year. The L/h baseline stays
            // post-labour-market (latchBaselineFromPostLaborMarket) for eps_L /
            // capital-deepening correctness.
            laborSupplyAggregator.latchDemographicAnchors(persons);

            if (!useDsge) {
                trendOnlyPathRecorder = pathRecordingEnabled ? new MacroPathRecorder() : null;
                applyRecorderSchema(macroModelPath, trendOnlyPathRecorder);

                if (useRamseyTrend) {
                    initializeRamseyTrend(macroModelPath);
                    // ramseyTrend is now loaded (or null via self-disable): re-check so an
                    // endogenous-labour bundle cannot slip past the feedback flag, and so a
                    // silent artefact fallback becomes fatal instead of quietly running
                    // without the feedback channel.
                    validateRamseyFeedbackConfig();
                    requireRamseyTrendSolved();
                }

                dynamicDsgeModel = null;
                shockScenario = null;
                wageDeviation = 0.0;
                inflationDeviation = 0.0;
                resetDiagnostics();
                initialized = true;

                if (logMacroState) {
                    log.info("DSGE cycle is disabled; initialized Ramsey-only macro trend mode.");
                }
                return;
            }
            
            // Load dynamic DSGE model (state-space)
            dynamicDsgeModel = new DSGEModel();
            dynamicDsgeModel.setLogEnabled(logMacroState);
            dynamicDsgeModel.setMaxStateDeviation(maxBounds);
            dynamicDsgeModel.loadFromDirectory(macroModelPath);
            dynamicDsgeModel.resetToSteadyState();
            dynamicDsgeModel.setPathRecordingEnabled(pathRecordingEnabled);

            if (logMacroState) {
                log.info("Dynamic DSGE model loaded from: " + macroModelPath);
            }

            // NOTE: Baseline is NOT set here. It is deferred to the second call
            // to updateEquilibrium() (year 2), after the labor market has run once.
            // This avoids measuring L from database-loaded hours, which differ from
            // what SimPaths' labor supply model assigns.
            laborSupplyAggregator.setLogEnabled(logMacroState);
            
            // Load exogenous shock scenario if configured
            if (dsgeShockScenario != null) dsgeShockScenario = dsgeShockScenario.trim();
            if (dsgeShockScenario != null && !dsgeShockScenario.isEmpty()) {
                String scenarioPath = macroModelPath + File.separator + dsgeShockScenario;
                shockScenario = new DSGEShockScenario(
                        dynamicDsgeModel.getShockNames(),
                        dynamicDsgeModel.getNumShocks());
                shockScenario.loadFromFile(java.nio.file.Path.of(scenarioPath));
                if (logMacroState) {
                    log.info("Loaded DSGE shock scenario from: " + scenarioPath);
                    log.info(shockScenario.getSummary());
                }
            } else {
                shockScenario = null;
            }

            // Load Ramsey growth model for structural wage trend (if enabled)
            if (useRamseyTrend) {
                initializeRamseyTrend(macroModelPath);
                // Currently unreachable with the feedback on: checkpoint 1 at the
                // top of initialize() already rejects a DSGE mode with feedback margins, and
                // useDsge cannot change mid-call. Kept as defense-in-depth so this branch stays
                // correct if that ordering is ever changed.
                validateRamseyFeedbackConfig();
                requireRamseyTrendSolved();
            }

            wageDeviation = 0.0;
            inflationDeviation = 0.0;
            resetDiagnostics();
            initialized = true;
            trendOnlyPathRecorder = null;

            if (logMacroState) {
                logNormalizedResponseComparison();
                // Clear any path data recorded during diagnostic comparison (year-0 artifacts)
                if (dynamicDsgeModel != null && dynamicDsgeModel.getPathRecorder() != null) {
                    dynamicDsgeModel.getPathRecorder().clear();
                }
            }
            
        } catch (IOException e) {
            String msg = String.format(
                "Failed to read DSGE model files from %s: %s",
                macroModelPath, e.getMessage());
            if (logMacroState) {
                log.error(msg, e);
            }
            throw new RuntimeException(msg, e);
        } catch (IllegalArgumentException e) {
            String msg = String.format(
                "Invalid DSGE model files in %s: %s",
                macroModelPath, e.getMessage());
            if (logMacroState) {
                log.error(msg, e);
            }
            throw new RuntimeException(msg, e);
        }
    }
    
    // ========== Capital Deepening / Ramsey Trend ==========
    
    /**
     * Initialize the Ramsey growth model for forward trend projection.
     * 
     * <p>Loads growth parameters, terminal state (K, A at end of estimation sample),
     * and reference CSV (for N/h trend extrapolation). Solves the Ramsey model once
     * for the full forward horizon (~80 years).</p>
     * 
     * <p>Called only when {@code mm_macroModel} selects a Ramsey mode, so missing artefacts
     * are fatal. The earlier behaviour cleared {@code useRamseyTrend} and continued with a zero
     * secular trend, which ran a different model from the configured one while
     * {@code saveRunParameters} still recorded the configured mode.</p>
     * 
     * @param macroModelPath Directory containing growth_params_*.json and related files
     */
    void initializeRamseyTrend(String macroModelPath) throws IOException {
        File macroDir = new File(macroModelPath);
        
        // Find growth_params_*.json (country-specific)
        File[] growthParamFiles = macroDir.listFiles(
                (dir, name) -> name.startsWith("growth_params_") && name.endsWith(".json"));
        
        if (growthParamFiles == null || growthParamFiles.length == 0) {
            throw new IllegalStateException("Ramsey trend: no growth_params_*.json found in " + macroModelPath
                    + "; mm_macroModel requested the Ramsey trend layer, so this is fatal.");
        }

        Arrays.sort(growthParamFiles, Comparator.comparing(File::getName));
        
        Path paramsPath = growthParamFiles[0].toPath();
        String fileName = growthParamFiles[0].getName();
        String countryTag = fileName.substring("growth_params_".length(),
                fileName.length() - ".json".length());
        
        Path terminalPath = paramsPath.resolveSibling("growth_terminal_state.json");
        Path refPath = paramsPath.resolveSibling(
                "growth_model_reference_" + countryTag.toLowerCase() + ".csv");
        
        if (!terminalPath.toFile().exists()) {
            throw new IllegalStateException("Ramsey trend: growth_terminal_state.json not found in " + macroModelPath
                    + "; mm_macroModel requested the Ramsey trend layer, so this is fatal.");
        }
        validateRamseyHandoffTime(terminalPath);
        ramseyProjectionQuarters = readProjectionQuarters(terminalPath);
        if (!refPath.toFile().exists()) {
            throw new IllegalStateException("Ramsey trend: " + refPath.getFileName() + " not found in " + macroModelPath
                    + "; mm_macroModel requested the Ramsey trend layer, so this is fatal.");
        }
        
        ramseyTrend = new RamseyTrendModel();
        ramseyTrend.setLogEnabled(logMacroState);
        ramseyTrend.loadParams(paramsPath);
        ramseyTrend.loadTerminalState(terminalPath);
        
        // Load Ramsey scenario if configured
        if (ramseyScenario != null) ramseyScenario = ramseyScenario.trim();
        if (ramseyScenario != null && !ramseyScenario.isEmpty()) {
            String scenarioPath = macroModelPath + File.separator + ramseyScenario;
            ramseyScenarioObj = new RamseyScenario();
            ramseyScenarioObj.setLogEnabled(logMacroState);
            ramseyScenarioObj.loadFromFile(java.nio.file.Path.of(scenarioPath));
            ramseyTrend.setScenario(ramseyScenarioObj, simulationStartYear);
            if (logMacroState) {
                log.info("Loaded Ramsey scenario from: " + scenarioPath);
                log.info(ramseyScenarioObj.getSummary());
            }
        } else {
            ramseyScenarioObj = null;
        }
        
        // Load reference CSV and extract N/WAP, h, gY, nxY for growth-rate extrapolation
        var reference = RamseyTrendModel.loadReferenceCSV(refPath);
        int refSize = reference.size();

        // The whole forward splice hangs off the assumption that the LAST reference row
        // is the handoff quarter (startIdx = refSize - 1 below). The row carries its own
        // date, so verify rather than assume: a reference CSV regenerated for a different
        // start year would otherwise shift every downstream index silently.
        String refTerminalTime = refSize > 0 ? reference.get(refSize - 1).time() : null;
        if (ramseyHandoffQuarter != null && refTerminalTime != null
                && quarterIndex(refTerminalTime) != quarterIndex(ramseyHandoffQuarter)) {
            throw new IllegalStateException(String.format(
                    "Macro artifacts are not aligned: growth_terminal_state.json declares "
                    + "handoff %s, but %s ends at %s. The forward projection is anchored on "
                    + "the last reference row, so these must be the same quarter. Re-run the "
                    + "MATLAB workflow for the requested start year.",
                    ramseyHandoffQuarter, refPath.getFileName(), refTerminalTime));
        }
        double[] refN = new double[refSize];
        double[] refH = new double[refSize];
        double[] refGY = new double[refSize];
        double[] refNXY = new double[refSize];
        for (int i = 0; i < refSize; i++) {
            refN[i] = reference.get(i).N();
            refH[i] = reference.get(i).h();
            refGY[i] = reference.get(i).gY();
            refNXY[i] = reference.get(i).nxY();
        }

        // In endogenous labor mode, the demographic input to solveForPath is WAP, not N.
        // The solver determines participation rate l endogenously, then N = l * WAP.
        boolean endogenousLabor = ramseyTrend.isEndogenousLabor();
        double[] refDemographic;  // N in exogenous mode, WAP in endogenous mode
        if (endogenousLabor) {
            double[] refWAP = new double[refSize];
            for (int i = 0; i < refSize; i++) {
                refWAP[i] = reference.get(i).WAP();
            }
            if (refWAP[0] <= 0) {
                log.warn("Endogenous labor mode active but reference CSV has no WAP column. "
                        + "Falling back to exogenous mode.");
                endogenousLabor = false;
                ramseyTrend.setEndogenousLabor(false);
                refDemographic = refN;
            } else {
                refDemographic = refWAP;
            }
        } else {
            refDemographic = refN;
        }
        
        // Extend demographic/h paths forward from end of estimation sample. The horizon
        // comes from the bundle (ramsey_trend.m's projection_quarters) rather than a
        // constant duplicated here: MATLAB solves the handoff contract over exactly this
        // many quarters, and a silent mismatch changes the terminal closure on one side
        // only.
        int totalExtended = refSize + ramseyProjectionQuarters;
        double[] extDemographic = RamseyTrendModel.extendExogenous(refDemographic, totalExtended,
                DEMOGRAPHIC_EXTENSION_WINDOW);
        // Hours are NOT extended here. The bundle carries the planner's hours path as an
        // artefact (see the read below), because re-deriving it on this side made the
        // trailing-growth window an unenforced convention across the repository boundary.
        // refH still serves the in-sample portion of the reference CSV.
        double[] extGY = RamseyTrendModel.extendShare(refGY, totalExtended);
        double[] extNXY = RamseyTrendModel.extendShare(refNXY, totalExtended);
        
        // Override demographic path with population projection if available.
        // This ensures the Ramsey trend uses demographic projections consistent
        // with SimPaths (e.g., Polish WAP decline) rather than extrapolating the
        // estimation country's historical growth rate.
        // In endogenous mode: scale population_projection N values to WAP units
        // (both follow the same demographic growth rates, just different base levels).
        int startIdx = refSize - 1;
        // The projection MUST carry this bundle's country tag. There is deliberately no
        // fallback to a country-agnostic population_projection.csv: that name dates from
        // the period when the German macro model was run inside Polish SimPaths, and in a
        // per-country layout it can only ever feed one country's demographics into
        // another country's trend. A wrong demographic path invalidates the whole trend
        // layer silently, so a missing or unreadable projection fails loudly instead.
        Path popProjPath = refPath.resolveSibling("population_projection_" + countryTag + ".csv");

        if (!popProjPath.toFile().exists()) {
            throw new IllegalStateException(String.format(
                    "Ramsey trend for %s requires %s, which is missing from %s. "
                    + "Without it the trend extrapolates the estimation country's historical "
                    + "demographic growth instead of the SimPaths-consistent projection. "
                    + "Re-export the macro files (run_full_workflow without "
                    + "skip_population_projection) or disable mm_useRamseyTrend.",
                    countryTag, popProjPath.getFileName(), popProjPath.getParent()));
        }

        PopulationProjectionData popProjection;
        try {
            popProjection = loadPopulationProjection(popProjPath);
        } catch (IOException e) {
            throw new IllegalStateException(String.format(
                    "Ramsey trend for %s could not read %s: %s. Re-export the macro files.",
                    countryTag, popProjPath.getFileName(), e.getMessage()), e);
        }

        if (popProjection.n().length == 0) {
            throw new IllegalStateException(String.format(
                    "Ramsey trend for %s found %s but it contains no projection rows. "
                    + "Re-export the macro files.",
                    countryTag, popProjPath.getFileName()));
        }

        double[] popDemographic;
        if (endogenousLabor) {
            if (popProjection.hasWap()) {
                popDemographic = popProjection.wap();
            } else {
                // Backward compatibility: derive WAP from N if WAP column is missing.
                // build_population_projection.m writes "time,N,WAP" in endogenous mode and
                // "time,N" in exogenous mode, so a missing WAP column here means an
                // exogenous-mode projection is driving an endogenous-mode run. The derived
                // path holds the terminal WAP/N ratio fixed for all future quarters, which
                // is only right if participation never moves - exactly what endogenous
                // labour supply denies. Warn rather than approximate in silence.
                double wapToNRatio = refDemographic[refSize - 1] / refN[refSize - 1];
                log.warn(String.format(
                        "Endogenous labour supply, but %s has no WAP column "
                        + "(exogenous-mode export). Deriving WAP from N at a fixed ratio "
                        + "%.4f, which assumes constant participation. Re-export with "
                        + "ramsey_labor_supply='endogenous' for a consistent WAP path.",
                        popProjPath.getFileName(), wapToNRatio));
                popDemographic = new double[popProjection.n().length];
                for (int i = 0; i < popProjection.n().length; i++) {
                    popDemographic[i] = popProjection.n()[i] * wapToNRatio;
                }
            }
        } else {
            popDemographic = popProjection.n();
        }

        // Align the two series by DATE, not by row position. extDemographic[startIdx]
        // is the handoff quarter (the last reference row), so the projection must be
        // copied from ITS handoff row - which is not necessarily row 0. Assuming row 0
        // was the handoff is how a start-year change silently shifted the whole
        // demographic path while every other check still passed.
        int popStartIdx = indexOfHandoffQuarter(popProjection.times(), popProjPath, refTerminalTime);

        int maxOverride = Math.min(popDemographic.length - popStartIdx, totalExtended - startIdx);
        System.arraycopy(popDemographic, popStartIdx, extDemographic, startIdx, maxOverride);

        // Beyond the finite population projection horizon, taper the trailing
        // demographic growth rate smoothly to zero. The tail is a terminal
        // closure for the perfect-foresight solve, not an additional forecast.
        // maxOverride counts the handoff row; MATLAB's n_avail counts quarters beyond
        // it. With no quarters beyond the handoff MATLAB never calls the closure and
        // the window-20 extrapolation stands — mirror that exactly.
        int overrideQuartersAfterHandoff = maxOverride - 1;
        if (overrideQuartersAfterHandoff >= 1 && startIdx + maxOverride < totalExtended) {
            applySmoothTerminalDemographicClosure(
                    extDemographic, startIdx + maxOverride - 1, totalExtended,
                    demographicTaperWindow(overrideQuartersAfterHandoff));
        }

        if (logMacroState) {
            log.info(String.format(
                    "Population projection loaded: %d quarters from %s "
                    + "(%s[0]=%.1f → %s[%d]=%.1f, override applied from index %d, hasWAP=%s)",
                    popDemographic.length, popProjPath.getFileName(),
                    endogenousLabor ? "WAP" : "N",
                    popDemographic[0],
                    endogenousLabor ? "WAP" : "N",
                    popDemographic.length - 1, popDemographic[popDemographic.length - 1],
                    startIdx,
                    popProjection.hasWap()));
        }

        // Forward projection starts at terminal date (last reference observation)
        int projLen = totalExtended - startIdx;
        double[] projDemographic = Arrays.copyOfRange(extDemographic, startIdx, totalExtended);
        double[] projH = loadProjectedHours(refPath, countryTag, refTerminalTime, projLen);
        double[] projGY = Arrays.copyOfRange(extGY, startIdx, totalExtended);
        double[] projNXY = Arrays.copyOfRange(extNXY, startIdx, totalExtended);
        
        double K_terminal = ramseyTrend.getK();
        double A_terminal = ramseyTrend.getA();
        // solveForPath: N array when exogenous, WAP array when endogenous
        ramseyTrend.solveForPath(K_terminal, A_terminal, projDemographic, projH, projGY, projNXY, projLen);

        // Retain the original projection slices: a later recursive-feedback re-solve builds
        // each year's inputs from these, never from the (already-consumed) local arrays above.
        this.ramseyProjN = projDemographic.clone();
        this.ramseyProjH = projH.clone();
        this.ramseyProjGY = projGY.clone();
        this.ramseyProjNXY = projNXY.clone();
        this.ramseyProjLen = projLen;
        this.ramseyQuarterZeroYear = simulationStartYear;

        // Set Ramsey baseline from the starting position (quarter 0) immediately,
        // so that the first advanceRamseyTrend() call produces non-zero trends.
        // Without this, the first year of DSGE operation always reports trends = 0%
        // because advanceRamseyTrend() uses the first stepYear() output as baseline.
        var q0 = ramseyTrend.getTrendAtQuarter(0);
        ramseyBaseline = q0;
        
        if (logMacroState) {
            log.info(String.format(
                    "Ramsey trend initialized: country=%s, K0=%.0f, A0=%.6f, "
                    + "w0=%.6f, r*_q=%.4f%%, projection=%d quarters",
                    countryTag, K_terminal, A_terminal,
                    q0.wage(), q0.rQuarterly() * 100.0, projLen));
            log.info(String.format(
                    "Ramsey baseline set at quarter 0: w=%.6f, Y=%.1f, C=%.1f, I=%.1f, K=%.0f, N=%.1f",
                    ramseyBaseline.wage(), ramseyBaseline.output(), ramseyBaseline.consumption(),
                    ramseyBaseline.investment(), ramseyBaseline.capitalStock(), ramseyBaseline.labor()));
        }
    }

    /**
     * Rejects flag combinations that would double-count the labour-supply response:
     * DSGE's eps_L channel and the Ramsey N revision, or the endogenous-labour FOC bundle
     * (which already approximates the labour response ex ante) alongside the feedback's own
     * realized-employment revision. Called both before {@link #initializeRamseyTrend(String)}
     * (catches an invalid flag combination before loading any files) and after it (by then
     * {@code ramseyTrend} is loaded, so the endogenous-labour check can actually fire).
     */
    void validateRamseyFeedbackConfig() {
        if (!ramseyFeedbackMargins.isOn()) return;
        String margins = "mm_ramseyFeedbackMargins=" + ramseyFeedbackMargins.name().toLowerCase();
        if (useDsge) log.warn(
                margins + " with a DSGE mode: the eps_L channel responds to the"
                + " year-over-year change in labour supply, the Ramsey re-solve to the cumulative level"
                + " gap against the projection, so the two overlap only while the cycle decays back to"
                + " the trend. Consider mm_ramseyFeedbackPersistence < 1 so that labour movements the"
                + " DSGE already treats as cyclical are not extrapolated as permanent shifts.");
        if (!useRamseyTrend) {
            // Inert rather than fatal: the margins default to on, so a deliberate
            // `mm_macroModel: dsge` run must not be required to switch them off by hand.
            log.warn(margins + " is inert: mm_macroModel does not run the Ramsey trend layer,"
                    + " so there is no trend path to re-solve.");
            return;
        }
        if (!(ramseyFeedbackPersistence >= 0.0 && ramseyFeedbackPersistence <= 1.0))
            throw new IllegalStateException(
                "mm_ramseyFeedbackPersistence must be in [0,1], got " + ramseyFeedbackPersistence);
        if (!(ramseyFeedbackHoursPersistence >= 0.0 && ramseyFeedbackHoursPersistence <= 1.0))
            throw new IllegalStateException(
                "mm_ramseyFeedbackHoursPersistence must be in [0,1], got " + ramseyFeedbackHoursPersistence);
        if (ramseyTrend != null && ramseyTrend.isEndogenousLabor()) throw new IllegalStateException(
                margins + " requires the exogenous-labour Ramsey bundle: the endogenous"
                + " FOC mode approximates the labour response ex ante and would double-count it");
    }

    /**
     * A requested Ramsey trend that fails to load is fatal. {@link #initializeRamseyTrend(String)}
     * has three fallbacks that clear {@code useRamseyTrend} and continue with a zero secular
     * trend; continuing would mean running a different model from the configured one while
     * {@code saveRunParameters} still records the configured mode.
     */
    private void requireRamseyTrendSolved() {
        if (ramseyTrend == null || !ramseyTrend.isSolved()) {
            throw new IllegalStateException("mm_macroModel requested the Ramsey trend layer, but it failed"
                    + " to initialise (missing MacroModel artefacts?); refusing to run a different model"
                    + " from the configured one");
        }
    }

    /**
     * Forward horizon of the Ramsey handoff contract, as declared by the export bundle.
     *
     * <p>Bundles written before the exporter declared it fall back to the historical 320
     * quarters with a warning, so an old bundle still runs but does not do so silently.</p>
     */
    private int readProjectionQuarters(Path terminalPath) throws IOException {
        String terminalJson = Files.readString(terminalPath);
        Matcher matcher = PROJECTION_QUARTERS_PATTERN.matcher(terminalJson);
        if (!matcher.find()) {
            log.warn(String.format(
                    "%s does not declare projection_quarters; assuming the legacy %d. "
                    + "Re-export the macro files so the forward horizon is pinned by the "
                    + "bundle rather than by a constant on each side.",
                    terminalPath.getFileName(), LEGACY_PROJECTION_QUARTERS));
            return LEGACY_PROJECTION_QUARTERS;
        }

        int quarters = Integer.parseInt(matcher.group(1));
        if (quarters <= 0) {
            throw new IllegalStateException(String.format(
                    "%s declares projection_quarters=%d, which must be positive.",
                    terminalPath.getFileName(), quarters));
        }
        if (logMacroState) {
            log.info("Ramsey projection horizon: " + quarters + " quarters (from bundle)");
        }
        return quarters;
    }

    /** Forward horizon actually in use, after reading the bundle. */
    public int getRamseyProjectionQuarters() {
        return ramseyProjectionQuarters;
    }

    private void validateRamseyHandoffTime(Path terminalPath) throws IOException {
        if (simulationStartYear <= 0) {
            return;
        }

        String expectedHandoff = simulationStartYear + "q1";
        String terminalJson = Files.readString(terminalPath);
        Matcher matcher = HANDOFF_TIME_PATTERN.matcher(terminalJson);
        if (!matcher.find()) {
            throw new IllegalStateException(String.format(
                    "Macro model enabled for simulation start year %d, but %s is missing handoff_time. "
                    + "Expected handoff_time=%s. Re-export the macro files or disable mm_useMacroModel.",
                    simulationStartYear, terminalPath.getFileName(), expectedHandoff));
        }

        String actualHandoff = matcher.group(1).trim().toLowerCase();
        if (!actualHandoff.equals(expectedHandoff)) {
            throw new IllegalStateException(String.format(
                    "Macro model handoff mismatch: simulation start year %d implies %s, "
                    + "but %s declares handoff_time=%s. Re-export the macro files for the requested start year "
                    + "or disable mm_useMacroModel.",
                    simulationStartYear, expectedHandoff, terminalPath.getFileName(), actualHandoff));
        }
        // Retained so the CSV merges can align on this quarter by DATE rather than
        // trusting row positions. Validating the scalar alone is not enough: it says
        // nothing about whether the reference CSV and the population projection were
        // regenerated for the same quarter.
        ramseyHandoffQuarter = actualHandoff;
    }

    /**
     * Convert a "YYYYqQ" label into a comparable quarter index.
     *
     * @return year*4 + (quarter-1), or {@link Integer#MIN_VALUE} if unparseable
     */
    static int quarterIndex(String label) {
        if (label == null) {
            return Integer.MIN_VALUE;
        }
        Matcher m = QUARTER_LABEL_PATTERN.matcher(label.trim().toLowerCase());
        if (!m.matches()) {
            return Integer.MIN_VALUE;
        }
        int year = Integer.parseInt(m.group(1));
        int quarter = Integer.parseInt(m.group(2));
        if (quarter < 1 || quarter > 4) {
            return Integer.MIN_VALUE;
        }
        return year * 4 + (quarter - 1);
    }

    /**
     * Original projection tail from quarter fromQ, with the realized gap delta applied under
     * a geometric per-year persistence belief: quarter j is scaled by 1 + (delta-1)*rho^floor(j/4).
     * rho=1: the gap is permanent (random walk); rho=0: only the realized year (j<4) is replaced
     * (Math.pow(0,0)==1) and the tail stays at the assumed path.
     */
    static double[] buildRevisedLaborSlice(double[] projN, int fromQ, double delta, double persistence) {
        double[] out = Arrays.copyOfRange(projN, fromQ, projN.length);
        for (int j = 0; j < out.length; j++) {
            double weight = Math.pow(persistence, j / 4);
            out[j] *= 1.0 + (delta - 1.0) * weight;
        }
        return out;
    }

    /**
     * Trailing-growth window for extending the demographic path past the estimation sample.
     * MUST match {@code extend_level_path(N_trend(} / {@code extend_level_path(WAP_trend(} in
     * the upstream WELLSIM_SVEC {@code macromodel/ramsey_trend.m}, which builds the same
     * projection on the MATLAB side.
     *
     * <p>Nothing enforces this across the repository boundary; the population projection file
     * overrides the extrapolated path over the years it covers, but this window still governs
     * the stretch beyond it. The hours window that used to live here is gone: the bundle now
     * carries {@code hours_projection_*.csv}, so the hours path has one owner rather than two
     * implementations. The terminal-tail windows are still duplicated on both sides and are
     * pinned in {@link RamseyTrendModel}.
     * See docs/superpowers/plans/2026-08-18-ramsey-hours-handoff-contract.md.</p>
     */
    static final int DEMOGRAPHIC_EXTENSION_WINDOW = 20;

    /**
     * Taper seed window, mirroring {@code tail_window = min(20, n_avail - 1)} in
     * ramsey_trend.m: the trailing growth rate must be measured inside the projection
     * override, never across the splice into pre-override extrapolated data.
     */
    static int demographicTaperWindow(int overrideQuartersAfterHandoff) {
        return Math.min(20, overrideQuartersAfterHandoff - 1);
    }

    static final String TREND_KEY_REALIZED_GAP = "n_realized_gap";
    static final String TREND_KEY_REALIZED_HOURS_GAP = "h_realized_gap";
    static final String TREND_KEY_WAGE_REVISION = "w_trend_revision";

    /**
     * Extended-path feedback step for one completed simulation year: map realized employment
     * into Ramsey units, rebuild the remaining-horizon labor path under the persistence belief,
     * and re-solve the trend from the predetermined capital state. The wage SimPaths used for
     * {@code year} is NOT revised (one-period-stale convention); the next {@link #advanceRamseyTrend()}
     * call steps the updated path for {@code year + 1}.
     */
    void applyRamseyFeedbackWithRealized(int year, double realizedLaborForce) {
        applyRamseyFeedbackWithRealized(year, realizedLaborForce, Double.NaN);
    }

    /**
     * As {@link #applyRamseyFeedbackWithRealized(int, double)}, additionally feeding realized
     * hours per worker into the planner's hours path when {@link #ramseyFeedbackMargins}
     * selects it. The Ramsey labor input is N*h, so an x% hours gap dilutes capital exactly as
     * an x% headcount gap does. Pass a non-finite or non-positive {@code realizedHours} to
     * leave hours inert.
     *
     * <p>Both gaps are measured in every mode; the mode decides which of them is applied to the
     * path handed to the re-solve. Measuring the unapplied gap costs nothing and keeps
     * {@code n_realized_gap} and {@code h_realized_gap} populated as diagnostics whichever
     * margin is being fed back.</p>
     *
     * <p><b>The two gaps use different references, deliberately.</b> The employment gap is
     * measured against the planner's projected N, which is legitimate because that projection
     * is overwritten at startup with the same population projection SimPaths aligns to, so
     * realized and projected employment are comparable and delta_n isolates genuine
     * labour-market surprises. No such reconciliation exists for hours: the planner's hours
     * path is a log-linear trend fitted to observed hours ({@code hours_trend_method} in the
     * growth params, about -0.2%/yr for PL) and SimPaths models no hours trend at all, so
     * measuring delta_h against the projection would convert that modelling disagreement into
     * a permanent labour-supply shift worth several percent of the trend wage. The gap is
     * therefore measured against SimPaths' OWN latch-year hours: the planner keeps its fitted
     * trend as a maintained assumption and SimPaths feeds back only its own hours movements on
     * top of it. Flat SimPaths hours give delta_h = 1 and no revision, which is correct,
     * because SimPaths carries no information about the hours trend.
     *
     * <p>Revisit this if SimPaths ever gains an exogenous hours projection of its own (for
     * example an hours alignment): the reference would then become that projection, exactly as
     * the population projection is the reference for employment.</p>
     */
    void applyRamseyFeedbackWithRealized(int year, double realizedLaborForce, double realizedHours) {
        if (!ramseyFeedbackMargins.isOn()) return;
        if (ramseyTrend == null || !ramseyTrend.isSolved() || ramseyProjN == null) return;
        if (year <= simulationStartYear) return; // no labour market in the start year

        if (!Double.isFinite(realizedLaborForce) || realizedLaborForce <= 0.0) {
            log.warn(String.format(
                    "Ramsey feedback %d: invalid realized labour force %.4f; skipping.",
                    year, realizedLaborForce));
            return;
        }
        int calQ = 4 * (year - simulationStartYear);   // quarter offset in the ORIGINAL projection arrays
        if (calQ + 8 > ramseyProjLen) {                 // need the realized year plus at least one more
            log.warn(String.format(
                    "Ramsey feedback %d: projection horizon exhausted; skipping re-solve.", year));
            return;
        }
        double assumedMeanN = (ramseyProjN[calQ] + ramseyProjN[calQ + 1]
                + ramseyProjN[calQ + 2] + ramseyProjN[calQ + 3]) / 4.0;
        boolean hoursUsable = Double.isFinite(realizedHours) && realizedHours > 0.0;

        if (Double.isNaN(ramseyFeedbackLambda)) {       // first post-labour-market year
            ramseyFeedbackLambda = assumedMeanN / realizedLaborForce;
            if (hoursUsable) ramseyFeedbackHoursBase = realizedHours;
            amendFeedbackDiagnostics(year, 0.0, hoursUsable ? 0.0 : Double.NaN, Double.NaN);
            if (logMacroState) {
                log.info(String.format(
                        "Ramsey feedback %d: latched lambda=%.6f (assumed N=%.1f, realized L=%.1f).",
                        year, ramseyFeedbackLambda, assumedMeanN, realizedLaborForce));
                if (hoursUsable) {
                    log.info(String.format(
                            "Ramsey feedback %d: latched hours reference h=%.4f (SimPaths' own base).",
                            year, ramseyFeedbackHoursBase));
                }
            }
            return;                                     // delta == 1 by construction
        }

        // Measured in every mode; applied only where the mode says so.
        boolean hoursMeasurable = hoursUsable && !Double.isNaN(ramseyFeedbackHoursBase)
                && ramseyFeedbackHoursBase > 0.0;
        double delta = ramseyFeedbackLambda * realizedLaborForce / assumedMeanN;
        double deltaH = hoursMeasurable ? realizedHours / ramseyFeedbackHoursBase : 1.0;
        boolean applyEmployment = ramseyFeedbackMargins.feedsEmployment();
        boolean applyHours = ramseyFeedbackMargins.feedsHours() && hoursMeasurable;
        int qYearCur = 4 * (year - ramseyQuarterZeroYear);  // offset of `year` in the CURRENT solved model
        double wOldNext = meanWageAtQuarterOrNaN(qYearCur + 4);

        double[] nSlice = applyEmployment
                ? buildRevisedLaborSlice(ramseyProjN, calQ, delta, ramseyFeedbackPersistence)
                : Arrays.copyOfRange(ramseyProjN, calQ, ramseyProjLen);
        double[] hSlice = applyHours
                ? buildRevisedLaborSlice(ramseyProjH, calQ, deltaH, ramseyFeedbackHoursPersistence)
                : Arrays.copyOfRange(ramseyProjH, calQ, ramseyProjLen);
        double[] gYSlice = Arrays.copyOfRange(ramseyProjGY, calQ, ramseyProjLen);
        double[] nxSlice = Arrays.copyOfRange(ramseyProjNXY, calQ, ramseyProjLen);

        double k0 = ramseyTrend.getKAtQuarter(qYearCur);    // predetermined at the start of `year`
        double a0 = ramseyTrend.getAAtQuarter(qYearCur);

        if (ramseyScenarioObj != null) {
            ramseyTrend.setScenario(ramseyScenarioObj, year);   // deviations are keyed to quarter-0's calendar year
        }
        ramseyTrend.setTfpPhaseOffsetQuarters(calQ);             // TFP convergence continues, does not restart
        ramseyTrend.solveForPath(k0, a0, nSlice, hSlice, gYSlice, nxSlice, ramseyProjLen - calQ);
        ramseyQuarterZeroYear = year;
        ramseyTrend.stepYear();                                  // consume the realized year; cursor now at year+1

        double wNewNext = meanWageAtQuarterOrNaN(4);
        double revisionPct = (!Double.isFinite(wOldNext) || wOldNext == 0.0) ? Double.NaN
                : (wNewNext / wOldNext - 1.0) * 100.0;
        amendFeedbackDiagnostics(year, (delta - 1.0) * 100.0,
                hoursMeasurable ? (deltaH - 1.0) * 100.0 : Double.NaN, revisionPct);
        if (logMacroState) {
            log.info(String.format(
                    "Ramsey feedback %d (%s): delta=%.4f%%, delta_h=%.4f%%, next-year trend wage revised by %.4f%%.",
                    year, ramseyFeedbackMargins.name().toLowerCase(),
                    (delta - 1.0) * 100.0, (deltaH - 1.0) * 100.0, revisionPct));
        }
    }

    private double meanWageAtQuarterOrNaN(int firstQuarter) {
        if (firstQuarter < 0 || firstQuarter + 4 > ramseyTrend.getSimQuarters()) return Double.NaN;
        double sum = 0.0;
        for (int j = 0; j < 4; j++) sum += ramseyTrend.getTrendAtQuarter(firstQuarter + j).wage();
        return sum / 4.0;
    }

    private void amendFeedbackDiagnostics(int year, double gapPct, double hoursGapPct, double revisionPct) {
        MacroPathRecorder recorder = getActivePathRecorder();
        if (recorder == null) return;
        recorder.amendTrendForYear(year, TREND_KEY_REALIZED_GAP, gapPct);
        if (Double.isFinite(hoursGapPct)) recorder.amendTrendForYear(year, TREND_KEY_REALIZED_HOURS_GAP, hoursGapPct);
        if (Double.isFinite(revisionPct)) recorder.amendTrendForYear(year, TREND_KEY_WAGE_REVISION, revisionPct);
    }

    /** MacroEndYearCapture hook: realized post-alignment employment -> extended-path re-solve. */
    public void applyRamseyRecursiveFeedback(int year, Set<Person> persons) {
        if (!ramseyFeedbackMargins.isOn() || !enabled) return;
        if (laborSupplyAggregator == null) return;
        var aggregates = laborSupplyAggregator.computeRawAggregates(persons);
        applyRamseyFeedbackWithRealized(year, aggregates.laborForce(), aggregates.avgHoursPerWorker());
    }

    /**
     * Advance the Ramsey trend model by one year (4 quarters).
     * 
     * <p>Called once per simulation year in {@link #updateEquilibrium}, before the
     * DSGE cycle computation. Sets {@link #capitalDeepeningWageAdjustment} to the
     * percentage wage trend relative to the first simulation year.</p>
     * 
     * <p>Baselines for all key variables are set during {@link #initializeRamseyTrend}
     * from the quarter-0 position. So the first call here already produces non-zero
     * trends (measuring change from quarter 0 to the end of the first stepped year).</p>
     * 
    * <p>Populates {@link #currentRamseyTrends} with keys: w, y, c, inv, k,
    * n_ramsey, l_ramsey.</p>
     */
    void advanceRamseyTrend() {
        var ts = ramseyTrend.stepYear();
        ramseyCurrentYearState = ts;
        
        // Baselines are set during initializeRamseyTrend() from quarter 0.
        // Every call here computes trends relative to that baseline.
        capitalDeepeningWageAdjustment = (ts.wage() / ramseyBaseline.wage() - 1.0) * 100.0;
        currentRamseyTrends.clear();
        currentRamseyTrends.put("w", capitalDeepeningWageAdjustment);
        currentRamseyTrends.put("y", (ts.output() / ramseyBaseline.output() - 1.0) * 100.0);
        currentRamseyTrends.put("c", (ts.consumption() / ramseyBaseline.consumption() - 1.0) * 100.0);
        currentRamseyTrends.put("inv", (ts.investment() / ramseyBaseline.investment() - 1.0) * 100.0);
        currentRamseyTrends.put("k", (ts.capitalStock() / ramseyBaseline.capitalStock() - 1.0) * 100.0);
        // G and NX: use absolute difference since baseline could be near zero (especially NX)
        currentRamseyTrends.put("g", ramseyBaseline.government() != 0.0
                ? (ts.government() / ramseyBaseline.government() - 1.0) * 100.0 : 0.0);
        currentRamseyTrends.put("nx", ramseyBaseline.netExports() != 0.0
                ? (ts.netExports() / ramseyBaseline.netExports() - 1.0) * 100.0 : 0.0);
        // Ramsey model's labor input (employees N) — for comparison with SimPaths population
        currentRamseyTrends.put("n_ramsey", ramseyBaseline.labor() > 0.0
                ? (ts.labor() / ramseyBaseline.labor() - 1.0) * 100.0 : 0.0);
        // Participation rate from Ramsey model (endogenous labor only; 0 otherwise)
        currentRamseyTrends.put("l_ramsey", ts.participationRate() * 100.0);
        
        if (logMacroState) {
            System.out.println(String.format(
                "  Ramsey trend: w=%.6f (base=%.6f), Y=%.1f, r*_q=%.4f%% → wage_trend=%+.4f%%",
                ts.wage(), ramseyBaseline.wage(), ts.output(),
                ts.rQuarterly() * 100.0, capitalDeepeningWageAdjustment));
            log.info(String.format("Ramsey trend: w=%.6f → wage_trend=%+.4f%%",
                ts.wage(), capitalDeepeningWageAdjustment));
        }
    }
    
    /**
     * Compute the secular wage-trend adjustment.
     *
     * <p>Ramsey trend is the supported mechanism. If Ramsey trend is unavailable,
     * the secular adjustment falls back to zero.</p>
     */
    private void computeCapitalDeepeningTrend() {
        // Ramsey trend: already computed by advanceRamseyTrend()
        if (useRamseyTrend && ramseyTrend != null && ramseyTrend.isSolved()) {
            return;
        }

        // Fallback: no reduced-form capital-deepening approximation.
        currentRamseyTrends.clear();
        capitalDeepeningWageAdjustment = 0.0;
        currentRamseyTrends.put("w", capitalDeepeningWageAdjustment);

        if (logMacroState) {
            System.out.println("  Ramsey trend unavailable; secular wage trend fallback = 0.0000%.");
        }

        if (logMacroState) {
            log.info("Ramsey trend unavailable; secular wage trend fallback = 0.0000%.");
        }
    }
    
    /**
     * Parsed population projection data with mandatory N and optional WAP columns.
     */
    /**
     * @param times quarter labels ("2023q1", ...), one per row. Carried so the splice
     *              can align on DATE; merging this file by row position is what let a
     *              start-year change corrupt a run silently.
     */
    private record PopulationProjectionData(String[] times, double[] n, double[] wap,
                                            boolean hasWap) {}

    private record HoursProjectionData(String[] times, double[] h) {}

    /**
     * Read the planner's hours path for the forward horizon from the bundle.
     *
     * <p>Mandatory, with no fallback to extrapolating the reference CSV here. That fallback
     * is what this method exists to remove: until 2026-08-18 both sides derived the hours
     * path independently, and they used different trailing-growth windows (MATLAB
     * {@code extend_level_path(handoff_h_hist, ..., 1)}, Java 20). The divergence was
     * invisible only because {@code hours_trend_method} is {@code log_linear}, which makes
     * the exported {@code h} column a pure exponential so every window recovers the same
     * rate. A silent fallback would reopen exactly that gap, so a missing file fails loudly
     * — the same rule the population projection already follows.</p>
     *
     * @param refPath           the reference CSV, whose sibling the projection is
     * @param countryTag        bundle country tag, e.g. {@code Poland}
     * @param refTerminalTime   last reference quarter, used to align by date
     * @param projLen           quarters the solve needs, starting at the handoff
     */
    private double[] loadProjectedHours(Path refPath, String countryTag,
                                        String refTerminalTime, int projLen) {
        Path hoursPath = refPath.resolveSibling("hours_projection_" + countryTag + ".csv");

        if (!hoursPath.toFile().exists()) {
            throw new IllegalStateException(String.format(
                    "Ramsey trend for %s requires %s, which is missing from %s. The bundle "
                    + "carries the planner's hours path so that both sides cannot project "
                    + "different hours from the same handoff. Re-export the macro files "
                    + "(export_ramsey_for_simpaths refreshes the Ramsey half without Dynare).",
                    countryTag, hoursPath.getFileName(), hoursPath.getParent()));
        }

        HoursProjectionData hours;
        try {
            hours = loadHoursProjection(hoursPath);
        } catch (IOException e) {
            throw new IllegalStateException(String.format(
                    "Ramsey trend for %s could not read %s: %s. Re-export the macro files.",
                    countryTag, hoursPath.getFileName(), e.getMessage()), e);
        }

        int hoursStartIdx = indexOfHandoffQuarter(hours.times(), hoursPath, refTerminalTime);
        int available = hours.h().length - hoursStartIdx;
        if (available < projLen) {
            throw new IllegalStateException(String.format(
                    "%s covers %d quarters from the handoff, but the Ramsey forward horizon "
                    + "is %d. The hours projection and projection_quarters come from the same "
                    + "MATLAB workspace, so a shortfall means the bundle is a mixed vintage. "
                    + "Re-export the macro files.",
                    hoursPath.getFileName(), available, projLen));
        }

        double[] projH = Arrays.copyOfRange(hours.h(), hoursStartIdx, hoursStartIdx + projLen);
        for (int i = 0; i < projH.length; i++) {
            if (!Double.isFinite(projH[i]) || projH[i] <= 0.0) {
                throw new IllegalStateException(String.format(
                        "%s contains a non-positive or non-finite hours value (%.6f) at "
                        + "quarter %d. Re-export the macro files.",
                        hoursPath.getFileName(), projH[i], hoursStartIdx + i));
            }
        }

        if (logMacroState) {
            log.info(String.format(
                    "Ramsey hours path read from %s: %d quarters from %s (h=%.4f to %.4f).",
                    hoursPath.getFileName(), projLen, hours.times()[hoursStartIdx],
                    projH[0], projH[projH.length - 1]));
        }
        return projH;
    }

    /**
     * Load the planner's hours-per-worker path produced by MATLAB's
     * {@code internal/write_hours_projection.m}. Format: {@code time,h}, one row per
     * quarter, first row at the handoff quarter.
     *
     * @throws IOException if the file cannot be read or a row cannot be parsed
     */
    private HoursProjectionData loadHoursProjection(Path csvPath) throws IOException {
        List<String> lines = Files.readAllLines(csvPath);
        var times = new ArrayList<String>();
        var hValues = new ArrayList<Double>();

        for (int i = 1; i < lines.size(); i++) {   // row 0 is the header
            String line = lines.get(i).trim();
            if (line.isEmpty()) {
                continue;
            }
            String[] parts = line.split(",");
            if (parts.length < 2) {
                throw new IOException(String.format(
                        "%s line %d: expected 'time,h' but found '%s'",
                        csvPath.getFileName(), i + 1, line));
            }
            try {
                hValues.add(Double.parseDouble(parts[1].trim()));
            } catch (NumberFormatException e) {
                throw new IOException(String.format(
                        "%s line %d: cannot parse hours value '%s'",
                        csvPath.getFileName(), i + 1, parts[1].trim()), e);
            }
            times.add(parts[0].trim());
        }

        double[] h = new double[hValues.size()];
        for (int i = 0; i < h.length; i++) {
            h[i] = hValues.get(i);
        }
        return new HoursProjectionData(times.toArray(new String[0]), h);
    }

    /**
     * Locate the handoff quarter within the population projection.
     *
     * <p>Both this file and the reference CSV are aligned to the handoff quarter, but
     * neither is guaranteed to START there — a projection may legitimately begin
     * earlier. Finding the row by date makes that case work instead of silently
     * shifting the projected path by the offset.</p>
     *
     * <p>Shared by every bundle projection (population and hours) so the date alignment
     * has one implementation. A second copy is exactly what drifts.</p>
     *
     * @param times             the projection's quarter labels
     * @param referenceTerminal the last reference-CSV quarter, i.e. the handoff
     * @throws IllegalStateException if the handoff quarter is not present at all
     */
    private int indexOfHandoffQuarter(String[] times, Path csvPath,
                                      String referenceTerminal) {
        String handoff = ramseyHandoffQuarter != null ? ramseyHandoffQuarter : referenceTerminal;
        if (handoff == null) {
            // No declared handoff to align on (no simulation start year set, e.g. in a
            // bare unit test). Fall back to the historical row-0 assumption rather than
            // failing, but say so.
            log.warn(String.format(
                    "No handoff quarter available to align %s; assuming its first row is "
                    + "the handoff. Set the simulation start year so the alignment can be "
                    + "verified.", csvPath.getFileName()));
            return 0;
        }

        int target = quarterIndex(handoff);
        for (int i = 0; i < times.length; i++) {
            if (quarterIndex(times[i]) == target) {
                if (i != 0 && logMacroState) {
                    log.info(String.format(
                            "Population projection %s starts at %s; aligning on handoff %s "
                            + "at row %d.", csvPath.getFileName(), times[0], handoff, i));
                }
                return i;
            }
        }

        String span = times.length == 0 ? "(empty)"
                : times[0] + " to " + times[times.length - 1];
        throw new IllegalStateException(String.format(
                "Macro artifacts are not aligned: the Ramsey handoff is %s, but %s covers "
                + "%s and does not contain that quarter. This is what a start-year change "
                + "looks like when only some upstream artifacts were regenerated. Re-run "
                + "the MATLAB workflow for the requested start year, or disable "
                + "mm_useMacroModel.",
                handoff, csvPath.getFileName(), span));
    }

    /**
     * Load population projection CSV produced by MATLAB's {@code build_population_projection.m}.
     *
     * <p>Supported formats:</p>
     * <ul>
     *   <li>{@code time,N} (legacy / exogenous mode)</li>
     *   <li>{@code time,N,WAP} (endogenous labor mode)</li>
     * </ul>
     *
     * @param csvPath Path to population_projection_[COUNTRY].csv
     * @return Parsed N path and optional WAP path
     * @throws IOException If the file cannot be read or parsed
     */
    private PopulationProjectionData loadPopulationProjection(Path csvPath) throws IOException {
        List<String> lines = Files.readAllLines(csvPath);
        var times = new ArrayList<String>();
        var nValues = new ArrayList<Double>();
        var wapValues = new ArrayList<Double>();

        if (lines.isEmpty()) {
            return new PopulationProjectionData(new String[0], new double[0], new double[0], false);
        }

        String[] header = MacroCsv.splitRow(lines.get(0));
        int timeCol = -1;
        int nCol = -1;
        int wapCol = -1;
        for (int i = 0; i < header.length; i++) {
            String name = header[i].trim();
            if (name.equalsIgnoreCase("time")) timeCol = i;
            if (name.equalsIgnoreCase("N")) nCol = i;
            if (name.equalsIgnoreCase("WAP")) wapCol = i;
        }

        if (nCol < 0) {
            throw new IOException("Population projection CSV missing mandatory N column: " + csvPath);
        }
        // Mandatory: without it the splice can only guess that row 0 is the handoff
        // quarter, which is precisely the failure this loader now prevents.
        if (timeCol < 0) {
            throw new IOException("Population projection CSV missing mandatory time column: "
                    + csvPath + ". The splice aligns on the handoff quarter by date; "
                    + "re-export the macro files.");
        }

        boolean hasWap = wapCol >= 0;
        for (int i = 1; i < lines.size(); i++) {
            String line = lines.get(i).trim();
            if (line.isEmpty()) continue;
            String[] parts = MacroCsv.splitRow(line);
            if (parts.length <= nCol || parts.length <= timeCol) continue;

            times.add(parts[timeCol].trim().toLowerCase());
            nValues.add(Double.parseDouble(parts[nCol].trim()));
            if (hasWap) {
                if (parts.length <= wapCol || parts[wapCol].trim().isEmpty()) {
                    hasWap = false;
                    wapValues.clear();
                } else {
                    wapValues.add(Double.parseDouble(parts[wapCol].trim()));
                }
            }
        }

        double[] n = nValues.stream().mapToDouble(Double::doubleValue).toArray();
        double[] wap = hasWap
                ? wapValues.stream().mapToDouble(Double::doubleValue).toArray()
                : new double[0];
        return new PopulationProjectionData(times.toArray(new String[0]), n, wap,
                hasWap && wap.length == n.length);
    }

    /**
     * Taper the post-projection demographic log-growth rate geometrically to zero.
     *
     * <p>The finite population projection remains authoritative through
     * {@code lastProjectionIdx}. Beyond that point, the Ramsey tail only closes
     * the terminal condition, so the recent growth rate is allowed to fade out
     * instead of being extrapolated forever or stopped with a hard kink.</p>
     */
    // Package-private rather than private so MacroModelManagerTest can assert this
    // directly against the taper-window bound. Visibility only - no behavioural difference.
    static void applySmoothTerminalDemographicClosure(
            double[] path, int lastProjectionIdx, int totalLength, int window) {
        if (path == null || lastProjectionIdx < 0 || lastProjectionIdx >= totalLength - 1) {
            return;
        }

        window = Math.min(window, lastProjectionIdx);
        if (window < 1) {
            Arrays.fill(path, lastProjectionIdx + 1, totalLength, path[lastProjectionIdx]);
            return;
        }

        double last = path[lastProjectionIdx];
        double base = path[lastProjectionIdx - window];
        if (last <= 0 || base <= 0 || !Double.isFinite(last) || !Double.isFinite(base)) {
            Arrays.fill(path, lastProjectionIdx + 1, totalLength, last);
            return;
        }

        double logGrowth = Math.log(last / base) / window;
        if (!Double.isFinite(logGrowth)) {
            Arrays.fill(path, lastProjectionIdx + 1, totalLength, last);
            return;
        }

        double rho = Math.pow(0.5, 1.0 / DEMOGRAPHIC_TAIL_HALF_LIFE_QUARTERS);
        for (int t = lastProjectionIdx + 1; t < totalLength; t++) {
            logGrowth *= rho;
            path[t] = path[t - 1] * Math.exp(logGrowth);
        }
    }
    
    /**
     * Run dynamic DSGE single-pass (state-space evolution).
     * 
     * <p>For dynamic integration:</p>
     * <ol>
     *   <li>Aggregate current labor supply into shocks (eps_L, eps_h)</li>
     *   <li>Step the dynamic DSGE forward (4 quarterly steps, returns annual average)</li>
     *   <li>State carries forward to next year</li>
     * </ol>
     * 
     * <p>NO iteration within year - that would destroy the dynamic state information.</p>
     */
    /**
     * Run a year in which the SimPaths labour-supply baseline is not yet latched.
     *
     * <p>The baseline L/h must be latched AFTER the first labour-market update, so
     * eps_L/eps_h cannot be measured in {@code startYear} (and in {@code startYear+1}
     * until the latch happens). That is a limitation of the <em>feedback</em> channel
     * only. The DSGE itself is a deterministic state-space system, and scenario
     * shocks (energy, monetary, demand) are exogenous — they do not need the
     * baseline. Setting eps_L = eps_h = 0 here is not a fudge: in the baseline year
     * the labour deviation from baseline is zero by construction.</p>
     *
     * <p>Previously these years returned before the shock scenario was ever
     * consulted, so a scenario declared from {@code startYear} silently lost its
     * first eight quarters — an "energy shock from 2023" actually began in 2025 at
     * its already-decayed magnitude, with nothing in the logs to say so.</p>
     *
     * <p>Stepping the DSGE with all-zero shocks from a zero state leaves it at zero,
     * so baseline runs are numerically unchanged; what changes is that the year is
     * recorded through the DSGE path (which also closes the year-gap that appeared
     * when the Ramsey trend was disabled) and that scenario shocks land in the year
     * they declare.</p>
     *
     * <p>The rolling baseline is deliberately NOT advanced here: it is latched from
     * the post-labour-market state by the normal schedule.</p>
     */
    private void runBaselinePendingPass(int year, Set<Person> persons, String reason) {
        boolean ramseyActive = useRamseyTrend && ramseyTrend != null && ramseyTrend.isSolved();
        if (ramseyActive) {
            advanceRamseyTrend();
        } else {
            computeCapitalDeepeningTrend();
        }

        dynamicDsgeModel.setCurrentYear(year);
        MacroPathRecorder recorder = dynamicDsgeModel.getPathRecorder();
        if (recorder != null) {
            recorder.setCurrentTrends(currentRamseyTrends);
        }

        boolean scenarioApplied = shockScenario != null && shockScenario.hasShocksForYear(year);
        DSGEState annualState;
        if (scenarioApplied) {
            // Zero feedback, full scenario: the shock happens in the year it declares.
            annualState = dynamicDsgeModel.stepAnnualWithScenario(0.0, 0.0, shockScenario, year);
        } else {
            double[] otherShocks = new double[dynamicDsgeModel.getNumShocks()];
            annualState = dynamicDsgeModel.stepAnnual(0.0, otherShocks);
        }

        wageDeviation = annualState.getWageDeviation() + capitalDeepeningWageAdjustment;
        inflationDeviation = annualState.getInflationDeviation();

        updatePotentialHourlyEarnings(persons);

        // labWageHrly now reflects this year's wages incl. any Ramsey overlay, so the
        // start-year anchor latches on the correct sample.
        double wageRealizedPct = populateRealizedWageIndex(persons);
        if (recorder != null && !Double.isNaN(wageRealizedPct)) {
            recorder.amendTrendForYear(year, "wage_realized", wageRealizedPct);
        }

        if (logMacroState) {
            log.info(String.format(
                "DSGE year %d: %s — labour feedback suppressed (eps_L=eps_h=0), "
                + "scenario %s, wage=%+.4f%% (cycle %+.4f%% + trend %+.4f%%).",
                year, reason, scenarioApplied ? "APPLIED" : "none",
                wageDeviation, annualState.getWageDeviation(),
                capitalDeepeningWageAdjustment));
        }
    }

    private void runDynamicSinglePass(int year, Set<Person> persons) {
        // Aggregate labor supply into shocks
        var shocks = laborSupplyAggregator.aggregate(persons);
        
        // Compute capital-deepening trend BEFORE stepping the DSGE model,
        // so the path recorder captures the trend for all 4 quarterly records
        computeCapitalDeepeningTrend();
        
        // Add SimPaths labor supply level indices (% from start year) to trends map
        populateDemographicIndices(shocks.aggregates());
        populateLabourCategoryMetrics(shocks.aggregates());

        logLabourCategoryDistribution(year, shocks.aggregates());
        
        // Set year for path recording
        dynamicDsgeModel.setCurrentYear(year);
        
        // Set trend on path recorder so quarterly records include it
        MacroPathRecorder recorder = dynamicDsgeModel.getPathRecorder();
        if (recorder != null) {
            recorder.setCurrentTrends(currentRamseyTrends);
        }
        
        // Step dynamic model forward (4 quarters internally, returns annual average)
        DSGEState annualState;
        if (shockScenario != null && shockScenario.hasShocksForYear(year)) {
            // Counterfactual: use scenario shocks additively on top of SimPaths shocks
            annualState = dynamicDsgeModel.stepAnnualWithScenario(
                    shocks.epsL(), shocks.epsH(), shockScenario, year);
        } else {
            // Baseline: only SimPaths-generated eps_L and eps_h
            double[] otherShocks = new double[dynamicDsgeModel.getNumShocks()];
            otherShocks[dynamicDsgeModel.getIdxEpsH()] = shocks.epsH();
            annualState = dynamicDsgeModel.stepAnnual(shocks.epsL(), otherShocks);
        }
        
        // Extract wage and inflation deviations (cycle component from DSGE)
        wageDeviation = annualState.getWageDeviation();
        inflationDeviation = annualState.getInflationDeviation();

        // Add capital-deepening trend (secular component, computed outside DSGE)
        wageDeviation += capitalDeepeningWageAdjustment;

        // Update individual wages with the new deviation before labor market runs
        updatePotentialHourlyEarnings(persons);

        // Compute the realized-wage index on the post-overlay wages and amend
        // the just-written quarterly records (recorder.setCurrentTrends was
        // called before stepAnnual, so the records do not yet carry this year's
        // wage index).
        double wageRealizedPct = populateRealizedWageIndex(persons);
        MacroPathRecorder pathRecorder = dynamicDsgeModel.getPathRecorder();
        if (pathRecorder != null && !Double.isNaN(wageRealizedPct)) {
            pathRecorder.amendTrendForYear(year, "wage_realized", wageRealizedPct);
        }

        // Log the results
        logDynamicEquilibrium("Dynamic", year, annualState, shocks);
        updateDiagnostics(shocks, annualState);
        
        // Advance rolling baseline: next year's shock measured relative to this year
        laborSupplyAggregator.advanceBaseline();
    }

    /**
     * Run one simulation year with DSGE bypassed (Ramsey-only).
     *
     * <p>All DSGE cycle variables and shocks are exported as zeros, while trend
     * and total columns are exported from Ramsey trend values. This guarantees
     * x_total == x_trend when DSGE is disabled.</p>
     */
    /**
     * Verbose-only diagnostic: log the labour-supply category distribution and
     * mean hours per category for the year. Gated on
     * {@code logMacroState && verboseMacroLogging} (the same convention as the
     * other verbose macro diagnostics) so it never appears in standard runs.
     * This is the lens for the wage-feedback intensive-margin question (whether
     * a mean-hours decline is driven by mass shifting into the wide PL_1 bin).
     */
    private void logLabourCategoryDistribution(int year, LaborSupplyAggregator.LaborSupplyAggregates aggregates) {
        if (!logMacroState || !verboseMacroLogging || laborSupplyAggregator == null
                || aggregates == null || !laborSupplyAggregator.isBaselineSet()) {
            return;
        }
        log.info(String.format("Macro Year %d — %s", year,
                laborSupplyAggregator.formatLabourCategoryDistribution(aggregates)));
    }

    private void runRamseyOnlyPass(int year, Set<Person> persons) {
        if (useRamseyTrend && ramseyTrend != null && ramseyTrend.isSolved()) {
            advanceRamseyTrend();
        } else {
            computeCapitalDeepeningTrend();
        }

        if (laborSupplyAggregator != null) {
            // Year 1 (L/h baseline not yet latched): use raw aggregates so the
            // demographic indices still emit (against the eagerly-latched
            // anchors). l_level/h_level remain self-gated on the post-labour-
            // market L/h anchors inside populateDemographicIndices.
            LaborSupplyAggregator.LaborSupplyAggregates aggs =
                    laborSupplyAggregator.isBaselineSet()
                            ? laborSupplyAggregator.aggregate(persons).aggregates()
                            : laborSupplyAggregator.computeRawAggregates(persons);
            populateDemographicIndices(aggs);
                populateLabourCategoryMetrics(aggs);
                logLabourCategoryDistribution(year, aggs);
        }

        wageDeviation = capitalDeepeningWageAdjustment;
        inflationDeviation = 0.0;
        updatePotentialHourlyEarnings(persons);

        populateRealizedWageIndex(persons);

        if (trendOnlyPathRecorder != null) {
            trendOnlyPathRecorder.setCurrentTrends(currentRamseyTrends);
            trendOnlyPathRecorder.recordRamseyOnlyYear(year);
        }

        if (logMacroState) {
            log.info(String.format(
                    "Macro Year %d (Ramsey-only): wage_total=%+.3f%% (cycle=+0.000%% + trend=%+.3f%%)",
                    year, wageDeviation, capitalDeepeningWageAdjustment));
        }
    }

    /**
     * Initialize standalone recorder mode (no DSGE, no Ramsey, no file loading).
     *
     * <p>Creates only a {@link LaborSupplyAggregator} and a {@link MacroPathRecorder}.
     * No model files are loaded from disk; the MacroModel directory is not required.
     * All DSGE/Ramsey state remains null/zero.</p>
     */
    private void initializeRecorderOnly(String countryCode) {
        laborSupplyAggregator = new LaborSupplyAggregator();
        laborSupplyAggregator.setLogEnabled(logMacroState);

        trendOnlyPathRecorder = pathRecordingEnabled ? new MacroPathRecorder() : null;
        if (countryCode != null && !countryCode.isBlank()) {
            String macroModelPath = "input" + File.separator + countryCode + File.separator + "MacroModel";
            applyRecorderSchema(macroModelPath, trendOnlyPathRecorder);
        }

        dynamicDsgeModel = null;
        shockScenario = null;
        ramseyTrend = null;
        wageDeviation = 0.0;
        inflationDeviation = 0.0;
        capitalDeepeningWageAdjustment = 0.0;
        initialized = true;

        if (logMacroState) {
            log.info("Recorder-only mode initialized: LaborSupplyAggregator + MacroPathRecorder active, "
                + "no DSGE/Ramsey model loaded, no wage feedback.");
        }
    }

    /**
     * Configure a non-DSGE recorder from the active MacroModel schema when model_info.json exists.
     * Falls back to the recorder's built-in defaults when metadata is unavailable.
     */
    private void applyRecorderSchema(String macroModelPath, MacroPathRecorder recorder) {
        if (recorder == null || macroModelPath == null || macroModelPath.isBlank()) {
            return;
        }

        Path modelInfoPath = Path.of(macroModelPath, "model_info.json");
        if (!Files.exists(modelInfoPath)) {
            if (logMacroState) {
                log.info("Macro recorder schema fallback: model_info.json not found at " + modelInfoPath);
            }
            return;
        }

        try {
            String content = Files.readString(modelInfoPath);
            String[] stateNames = extractJsonStringArray(content, "state_names");
            String[] jumpNames = extractJsonStringArray(content, "jump_names");
            String[] shockNames = extractJsonStringArray(content, "exo_names");
            recorder.setVariableNames(stateNames, jumpNames, shockNames);

            if (logMacroState) {
                log.info(String.format(
                        "Macro recorder schema loaded from %s: %d states, %d jumps, %d shocks",
                        modelInfoPath, stateNames.length, jumpNames.length, shockNames.length));
            }
        } catch (IOException e) {
            if (logMacroState) {
                log.warn("Failed to load recorder schema from " + modelInfoPath + ": " + e.getMessage());
            }
        }
    }

    /** Delegate to {@link MacroJson}, the reader shared with DSGEModel and
     *  RamseyTrendModel. Do not re-inline a local parser. */
    private static String[] extractJsonStringArray(String json, String key) {
        return MacroJson.stringArray(json, key);
    }

    /**
     * Run one simulation year in recorder-only mode.
     *
     * <p>Aggregates SimPaths behavioral labor supply into l_level, h_level,
     * participation_rate, and workers_over_atRiskPool. All DSGE state/jump/shock
     * columns remain zero. No wage or inflation feedback is applied.</p>
     *
     * @param year    Current simulation year
     * @param persons Current population
     */
    private void runRecorderOnlyPass(int year, Set<Person> persons) {
        // Year 1 (L/h baseline not yet latched): use raw aggregates so the
        // demographic indices still emit against the eagerly-latched anchors.
        // Year >= 2: aggregate() also rolls lastL/lastH for advanceBaseline.
        boolean baselineSet = laborSupplyAggregator.isBaselineSet();
        LaborSupplyAggregator.LaborSupplyAggregates aggs = baselineSet
                ? laborSupplyAggregator.aggregate(persons).aggregates()
                : laborSupplyAggregator.computeRawAggregates(persons);

        // Populate the trends map with SimPaths labor supply diagnostics only
        currentRamseyTrends.clear();

        populateDemographicIndices(aggs);
        populateLabourCategoryMetrics(aggs);
        populateRealizedWageIndex(persons);
        // Emit the exogenous SimPaths real-wage trend as w_trend (= w_total in
        // this mode, since the DSGE cycle is zero). Mirrors the Person wage
        // regression's RealWageGrowth lookup so the exported series matches
        // what the wage equation actually consumes.
        populateExogenousWageTrend(year);

        logLabourCategoryDistribution(year, aggs);

        // Record to path recorder (zero DSGE state/jumps/shocks)
        if (trendOnlyPathRecorder != null) {
            trendOnlyPathRecorder.setCurrentTrends(currentRamseyTrends);
            trendOnlyPathRecorder.recordRamseyOnlyYear(year);
        }

        // Advance rolling baseline only once the L/h baseline exists (year >= 2);
        // advanceBaseline is a no-op pre-baseline but gating avoids a warn log.
        if (baselineSet) {
            laborSupplyAggregator.advanceBaseline();
        }

        if (logMacroState) {
            log.info(String.format(
                    "Macro Year %d (recorder-only): L=%.0f, h=%.2f, participation=%.1f%%, workers/atRisk=%.1f%%",
                    year, aggs.laborForce(),
                    aggs.avgHoursPerWorker(),
                    aggs.participationRate() * 100.0,
                    aggs.atRiskPool() > 0
                        ? 100.0 * aggs.laborForce() / aggs.atRiskPool()
                        : 0.0));
        }
    }

    /**
     * Populate demographic level indices in the trends map.
     *
     * <p>Writes l_level, h_level, participation_rate, workers_over_atRiskPool,
     * total_population, wap_level, and atrisk_level into {@code currentRamseyTrends}.
     * All level indices are expressed as % change from the start year.</p>
     *
     * @param aggregates Current labor supply aggregates
     */
    private void populateDemographicIndices(LaborSupplyAggregator.LaborSupplyAggregates aggregates) {
        currentRamseyTrends.putAll(demographicIndexUpdates(aggregates));
    }

    /**
     * The SimPaths-aggregated level columns for one set of aggregates.
     *
     * <p>Pure: reads only the aggregator's latched start-year anchors and the
     * supplied aggregates. Both writers use it — the in-year pass through
     * {@link #populateDemographicIndices} and the end-of-year re-expression in
     * {@link #buildPostAlignmentLevelUpdates} — which is the point: the two used
     * to hold near-verbatim copies of these formulas, and a divergence would have
     * silently corrupted the post-alignment level columns of MacroPaths.csv while
     * the in-year ones stayed right.</p>
     *
     * <p>participation_rate and workers_over_atRiskPool are workers/L-derived:
     * they are only meaningful once L comes from the SimPaths labour-supply model,
     * i.e. post-labour-market (isBaselineSet() is true only then). Emitting them
     * in the eager year-1 pre-labour-market pass would expose input-DB hours and,
     * because compare_scenarios.do anchors pr0/ar0 on the first non-zero value,
     * corrupt its WAP/atRisk reconstruction. Only the labour-market-invariant
     * head-count anchors are safe to emit from year 1.</p>
     */
    private Map<String, Double> demographicIndexUpdates(
            LaborSupplyAggregator.LaborSupplyAggregates aggregates) {
        Map<String, Double> m = new LinkedHashMap<>();

        double startL = laborSupplyAggregator.getStartYearL();
        double startH = laborSupplyAggregator.getStartYearH();
        double startTotalPop = laborSupplyAggregator.getStartYearTotalPop();
        double startWAP = laborSupplyAggregator.getStartYearWAP();
        double startAtRisk = laborSupplyAggregator.getStartYearAtRisk();

        if (startL > 0.0) {
            m.put("l_level", (aggregates.laborForce() / startL - 1.0) * 100.0);
        }
        if (startH > 0.0) {
            m.put("h_level", (aggregates.avgHoursPerWorker() / startH - 1.0) * 100.0);
        }
        if (laborSupplyAggregator.isBaselineSet()) {
            m.put("participation_rate", aggregates.participationRate() * 100.0);
            m.put("workers_over_atRiskPool",
                    aggregates.atRiskPool() > 0
                        ? 100.0 * aggregates.laborForce() / aggregates.atRiskPool()
                        : 0.0);
        }
        if (startTotalPop > 0.0) {
            m.put("total_population",
                    ((double) aggregates.totalPopulation() / startTotalPop - 1.0) * 100.0);
        }
        if (startWAP > 0.0) {
            m.put("wap_level",
                    ((double) aggregates.workingAgePopulation() / startWAP - 1.0) * 100.0);
        }
        if (startAtRisk > 0.0) {
            m.put("atrisk_level",
                    ((double) aggregates.atRiskPool() / startAtRisk - 1.0) * 100.0);
        }
        return m;
    }

    /**
     * Compute the mean {@code labWageHrly} over the at-risk pool — i.e. the
     * exact population that enters the SimPaths discrete-choice labour supply
     * model ({@link LaborSupplyAggregator#isInAtRiskPool}) — latch the start-
     * year anchor on first call, and write the resulting % change from the
     * start year ({@code (mean / anchor - 1) * 100}) into
     * {@link #currentRamseyTrends} under the key {@code wage_realized}.
     *
     * <p>The series is intentionally always constructed — including in
     * recorder-only and Ramsey-only modes — so the wage faced by labour-supply
     * decisions remains visible alongside (or in the absence of) the macro
     * multiplier (see SP_CHATS_107 / SP_CHATS_108). Averaging over the at-risk
     * pool aligns the wage diagnostic with the participation / hours / labour-
     * category panels in the same MacroPaths.csv, which all use the same gate.
     * Units (% from first year) match {@code w_trend} / {@code w_total} so the
     * realized wage and the exogenous / Ramsey wage trends can be plotted on a
     * common axis.</p>
     *
     * @param persons SimPaths person set
     * @return the computed % change value, or {@link Double#NaN} when no at-
     *         risk person has a valid wage (in which case the trends map is
     *         left untouched)
     */
    private double populateRealizedWageIndex(Set<Person> persons) {
        currentRamseyTrends.remove("wage_realized");
        if (persons == null || persons.isEmpty() || laborSupplyAggregator == null) {
            return Double.NaN;
        }
        double sum = 0.0;
        int count = 0;
        for (Person p : persons) {
            if (!laborSupplyAggregator.isInAtRiskPool(p)) {
                continue;
            }
            double w = p.getFullTimeHourlyEarningsPotential();
            if (w > 0.0) {
                sum += w;
                count++;
            }
        }
        if (count == 0) {
            return Double.NaN;
        }
        double mean = sum / count;
        if (startYearAtRiskWage == 0.0) {
            startYearAtRiskWage = mean;
        }
        double pctFromFirstYear = (mean / startYearAtRiskWage - 1.0) * 100.0;
        currentRamseyTrends.put("wage_realized", pctFromFirstYear);
        return pctFromFirstYear;
    }

    /**
     * Recorder-only path: emit the exogenous SimPaths real-wage trend as
     * {@code currentRamseyTrends["w"]} so the recorder writes it to the
     * {@code w_trend} (and, since the DSGE cycle is zero in this mode,
     * identically to the {@code w_total}) column. The series is the
     * {@code wage_growth} index from {@code time_series_factor.xlsx} (or its
     * geometric out-of-sample extrapolation, transparently handled by
     * {@link Parameters#getTimeSeriesIndex}) expressed as
     * {@code (idx_t / idx_startYear - 1) * 100} so the units match the macro-
     * on Ramsey {@code w_trend}.
     *
     * <p>The lookup mirrors the {@code RealWageGrowth} regressor in
     * {@link Person} (including the {@code freezeWageGrowthForRamseyTrend}
     * cap), so the exported series is literally the wage trend the SimPaths
     * wage equation consumes.</p>
     */
    private void populateExogenousWageTrend(int year) {
        if (simulationStartYear <= 0) {
            return;
        }
        int yearLookup = effectiveWageGrowthYear(year);
        int startLookup = effectiveWageGrowthYear(simulationStartYear);
        Double idxNow = Parameters.getTimeSeriesIndex(yearLookup, UpratingCase.Earnings);
        Double idxStart = Parameters.getTimeSeriesIndex(startLookup, UpratingCase.Earnings);
        if (idxNow == null || idxStart == null || idxStart == 0.0) {
            return;
        }
        double wTrendPct = (idxNow / idxStart - 1.0) * 100.0;
        currentRamseyTrends.put("w", wTrendPct);
    }

    private static int effectiveWageGrowthYear(int year) {
        if (Parameters.freezeWageGrowthForRamseyTrend
                && year > Parameters.wageGrowthLastInSampleYear) {
            return Parameters.wageGrowthLastInSampleYear;
        }
        return year;
    }

    private void populateLabourCategoryMetrics(LaborSupplyAggregator.LaborSupplyAggregates aggregates) {
        currentRamseyTrends.putAll(labourCategoryUpdates(aggregates));
    }

    /**
     * The four labour-category share/mean-hours columns for one set of
     * aggregates, padded with zeros when fewer than four categories are present.
     * Shared with {@link #buildPostAlignmentLevelUpdates} for the same reason as
     * {@link #demographicIndexUpdates}.
     */
    private Map<String, Double> labourCategoryUpdates(
            LaborSupplyAggregator.LaborSupplyAggregates aggregates) {
        Map<String, Double> m = new LinkedHashMap<>();
        int index = 0;
        for (LaborSupplyAggregator.LabourCategorySummary summary
                : aggregates.categoryDistribution().values()) {
            if (index >= 4) {
                break;
            }
            m.put("cat_" + index + "_share", summary.share());
            m.put("cat_" + index + "_meanHours", summary.meanHours());
            index++;
        }
        while (index < 4) {
            m.put("cat_" + index + "_share", 0.0);
            m.put("cat_" + index + "_meanHours", 0.0);
            index++;
        }
        return m;
    }

    /**
     * Log dynamic DSGE state evolution (for dynamic integration mode).
     */
    private void logDynamicEquilibrium(
            String mode,
            int year,
            DSGEState state,
            LaborSupplyAggregator.LaborSupplyShocks shocks
    ) {
        if (logMacroState) {
            System.out.println("\n========== DSGE MACRO MODEL UPDATE (" + mode + ") ==========");
            System.out.println(String.format("Year: %d", year));
            System.out.println("--- Labor Supply Aggregation ---");
            System.out.println(String.format("  Participants         %.0f (extensive margin, hours > 0)", shocks.aggregates().laborForce()));
            System.out.println(String.format("  At-risk pool:        %.0f (non-student/retired 15-64)", shocks.aggregates().atRiskPool()));
            System.out.println(String.format("  Avg hours/week:      %.1f", shocks.aggregates().avgHoursPerWorker()));
            System.out.println(String.format("  Participation rate:  %.1f%%", shocks.aggregates().participationRate() * 100));
            System.out.println("--- DSGE Shocks ---");
            System.out.println(String.format("  eps_L (participation): %+.4f", shocks.epsL()));
            System.out.println(String.format("  eps_h (hours):       %+.4f", shocks.epsH()));
            System.out.println("--- DSGE State Evolution (Annual Average) ---");
            System.out.println(String.format("  Wage deviation:      %+.4f%%", state.getWageDeviation()));
            System.out.println(String.format("  Inflation deviation: %+.4f pp", state.getInflationDeviation()));
            System.out.println(String.format("  Output deviation:    %+.4f%%", state.getOutputDeviation()));
            System.out.println(String.format("  Employment dev:      %+.4f%%", state.getEmploymentDeviation()));
            System.out.println(String.format("  Labor force dev:     %+.4f%%", state.getLaborForceDeviation()));
            System.out.println(String.format("  Hours deviation:     %+.4f%%", state.getHoursDeviation()));
            System.out.println("--- Wage Decomposition ---");
            System.out.println(String.format("  DSGE cycle:          %+.4f%%", state.getWageDeviation()));
            String trendLabel = (useRamseyTrend && ramseyTrend != null) ? "Ramsey trend" : "Capital deepening";
            System.out.println(String.format("  %s:   %+.4f%%", trendLabel, capitalDeepeningWageAdjustment));
            System.out.println(String.format("  Total wage dev:      %+.4f%%", wageDeviation));
            System.out.println("--- Wage Multiplier for Individuals ---");
            System.out.println(String.format("  Multiplier:          %.6f (= 1 + %.4f/100)", 
                1.0 + wageDeviation / 100.0, wageDeviation));
            System.out.println("=======================================================\n");
        }
        
        if (logMacroState) {
            log.info(String.format("DSGE Year %d (Dynamic): wage_dev=%.3f%% (cycle=%.3f%% + trend=%.3f%%), inflation_dev=%.3f%%, eps_L=%.4f, eps_h=%.4f",
                year, wageDeviation, state.getWageDeviation(), capitalDeepeningWageAdjustment,
                inflationDeviation, shocks.epsL(), shocks.epsH()));
        }
    }
    
    /**
     * Reset counters at start of each year.
     */
    private void resetCounters() {
        wageAdjustmentCount.set(0);
        wageAdjustmentSum.reset();
    }

    private void resetDiagnostics() {
        diagnosticsCount = 0;
        epsLMin = Double.POSITIVE_INFINITY;
        epsLMax = Double.NEGATIVE_INFINITY;
        epsHMin = Double.POSITIVE_INFINITY;
        epsHMax = Double.NEGATIVE_INFINITY;
        wageDevMin = Double.POSITIVE_INFINITY;
        wageDevMax = Double.NEGATIVE_INFINITY;
        inflDevMin = Double.POSITIVE_INFINITY;
        inflDevMax = Double.NEGATIVE_INFINITY;
        outputDevMin = Double.POSITIVE_INFINITY;
        outputDevMax = Double.NEGATIVE_INFINITY;
        employmentDevMin = Double.POSITIVE_INFINITY;
        employmentDevMax = Double.NEGATIVE_INFINITY;
        epsLSum = 0.0;
        epsHSum = 0.0;
        wageDevSum = 0.0;
        inflDevSum = 0.0;
        outputDevSum = 0.0;
        employmentDevSum = 0.0;
    }

    private void updateDiagnostics(LaborSupplyAggregator.LaborSupplyShocks shocks, DSGEState state) {
        if (!logMacroState || shocks == null || state == null) {
            return;
        }
        updateDiagnosticsValues(shocks.epsL(), shocks.epsH(), state.getWageDeviation(),
                state.getInflationDeviation(), state.getOutputDeviation(), state.getEmploymentDeviation());
    }

    private void updateDiagnosticsValues(double epsL, double epsH, double wageDev,
                                          double inflDev, double outputDev, double employmentDev) {
        diagnosticsCount++;

        epsLMin = Math.min(epsLMin, epsL);
        epsLMax = Math.max(epsLMax, epsL);
        epsHMin = Math.min(epsHMin, epsH);
        epsHMax = Math.max(epsHMax, epsH);

        wageDevMin = Math.min(wageDevMin, wageDev);
        wageDevMax = Math.max(wageDevMax, wageDev);
        inflDevMin = Math.min(inflDevMin, inflDev);
        inflDevMax = Math.max(inflDevMax, inflDev);
        outputDevMin = Math.min(outputDevMin, outputDev);
        outputDevMax = Math.max(outputDevMax, outputDev);
        employmentDevMin = Math.min(employmentDevMin, employmentDev);
        employmentDevMax = Math.max(employmentDevMax, employmentDev);

        epsLSum += epsL;
        epsHSum += epsH;
        wageDevSum += wageDev;
        inflDevSum += inflDev;
        outputDevSum += outputDev;
        employmentDevSum += employmentDev;
    }

    public void logDiagnosticsSummary() {
        if (!logMacroState || diagnosticsCount == 0) {
            return;
        }

        log.info(String.format(
                "DSGE Diagnostics Summary: n=%d | eps_L[min=%.4f,max=%.4f,mean=%.4f] " +
                "eps_h[min=%.4f,max=%.4f,mean=%.4f] | wage[min=%.4f,max=%.4f,mean=%.4f] " +
                "pi[min=%.4f,max=%.4f,mean=%.4f] | y[min=%.4f,max=%.4f,mean=%.4f] | n[min=%.4f,max=%.4f,mean=%.4f]",
                diagnosticsCount,
                epsLMin, epsLMax, epsLSum / diagnosticsCount,
                epsHMin, epsHMax, epsHSum / diagnosticsCount,
                wageDevMin, wageDevMax, wageDevSum / diagnosticsCount,
                inflDevMin, inflDevMax, inflDevSum / diagnosticsCount,
                outputDevMin, outputDevMax, outputDevSum / diagnosticsCount,
                employmentDevMin, employmentDevMax, employmentDevSum / diagnosticsCount
        ));
    }

    private void logNormalizedResponseComparison() {
        if (!logMacroState || !verboseMacroLogging || dynamicDsgeModel == null || !dynamicDsgeModel.isLoaded()) {
            return;
        }

        double[] shockStdDev = dynamicDsgeModel.getShockStdDev();
        if (shockStdDev == null || shockStdDev.length <= dynamicDsgeModel.getIdxEpsH()) {
            return;
        }

        double sigmaL = shockStdDev[dynamicDsgeModel.getIdxEpsL()];
        double sigmaH = shockStdDev[dynamicDsgeModel.getIdxEpsH()];

        // Dynamic: 1-sigma shocks (suppress path recording to avoid year-0 artifact in CSV)
        boolean wasRecording = dynamicDsgeModel.isPathRecordingEnabled();
        dynamicDsgeModel.setPathRecordingEnabled(false);
        dynamicDsgeModel.resetToSteadyState();
        double[] otherShocks = new double[dynamicDsgeModel.getNumShocks()];
        otherShocks[dynamicDsgeModel.getIdxEpsH()] = sigmaH;
        DSGEState dynamicResponse = dynamicDsgeModel.stepAnnual(sigmaL, otherShocks);
        dynamicDsgeModel.resetToSteadyState();
        dynamicDsgeModel.setPathRecordingEnabled(wasRecording);

        log.info(String.format(
                "DSGE 1σ Dynamic Response (eps_L=%.4f, eps_h=%.4f): w=%.4f, pi=%.4f, y=%.4f, n=%.4f",
                sigmaL, sigmaH,
                dynamicResponse.getWageDeviation(), dynamicResponse.getInflationDeviation(),
                dynamicResponse.getOutputDeviation(), dynamicResponse.getEmploymentDeviation()
        ));
    }

    private void updatePotentialHourlyEarnings(Set<Person> persons) {
        if (persons == null || persons.isEmpty()) {
            return;
        }
        persons.parallelStream().forEach(person -> person.onEvent(Person.Processes.UpdatePotentialHourlyEarnings));
    }
    
    // ========== Tracking Methods ==========
    
    /**
     * Track a wage adjustment for logging purposes.
     * 
     * <p>Called by Person.updateFullTimeHourlyEarnings() when DSGE adjustment is applied.</p>
     * 
     * @param person        the person whose wage is being adjusted
     * @param originalWage  wage before DSGE adjustment
     * @param adjustedWage  wage after DSGE adjustment
     * @param deviation     the DSGE wage deviation in percent
     */
    public void trackWageAdjustment(Person person, double originalWage, double adjustedWage, double deviation) {
        int count = wageAdjustmentCount.incrementAndGet();
        wageAdjustmentSum.add(adjustedWage - originalWage);
        
        // Log sample individuals (first 3 each iteration)
        if (logMacroState && verboseMacroLogging && count <= 3) {
            System.out.println(String.format(
                "  [Wage Adj] Person %d (%s, age %d): %.2f → %.2f EUR/hr (%.3f%% deviation)",
                person.getKey().getId(), person.getDgn(), person.getDag(),
                originalWage, adjustedWage, deviation));
        }
    }
    
    /**
     * Backward compatibility overload without person details.
     */
    public void trackWageAdjustment(double originalWage, double adjustedWage) {
        wageAdjustmentCount.incrementAndGet();
        wageAdjustmentSum.add(adjustedWage - originalWage);
    }
    
    /**
     * Track labor supply decision for logging.
     * 
     * <p>Shows how disposable income varies across hours options and affects choice probabilities.</p>
     */
    public void trackLaborSupplyDecision(
            BenefitUnit bu,
            MultiKeyMap<Labour, Double> disposableIncomeByHours,
            MultiKeyMap<Labour, Double> probabilitiesByHours
    ) {
        if (!logMacroState || !verboseMacroLogging) {
            return;
        }

        laborSupplyLogCount++;
        
        if (laborSupplyLogCount > MAX_LABOR_SUPPLY_LOG_SAMPLES) {
            return;
        }
        
        System.out.println(String.format("  [LS Decision] BU %d:", bu.getKey().getId()));
        
        // Find min/max disposable income
        double minDI = Double.MAX_VALUE;
        double maxDI = Double.MIN_VALUE;
        double maxProb = 0;
        Object maxProbKey = null;
        
        for (var entry : probabilitiesByHours.entrySet()) {
            Double di = disposableIncomeByHours.get(entry.getKey());
            if (di != null) {
                minDI = Math.min(minDI, di);
                maxDI = Math.max(maxDI, di);
            }
            if (entry.getValue() > maxProb) {
                maxProb = entry.getValue();
                maxProbKey = entry.getKey();
            }
        }
        
        System.out.println(String.format(
            "    Disposable income range: %.0f - %.0f EUR/month (spread: %.0f)",
            minDI, maxDI, maxDI - minDI));
        System.out.println(String.format(
            "    Most likely choice: %s (prob=%.1f%%)",
            maxProbKey, maxProb * 100));
        
        // Show top 3 options
        var sortedEntries = new ArrayList<>(probabilitiesByHours.entrySet());
        sortedEntries.sort((a, b) -> Double.compare(b.getValue(), a.getValue()));
        System.out.println("    Top options:");
        for (int i = 0; i < Math.min(3, sortedEntries.size()); i++) {
            var entry = sortedEntries.get(i);
            Double di = disposableIncomeByHours.get(entry.getKey());
            System.out.println(String.format(
                "      %s: prob=%.1f%%, DI=%.0f EUR/mo",
                entry.getKey(), entry.getValue() * 100, di != null ? di : 0));
        }
    }
    
    /**
     * Reset labor supply log counter (call at start of each iteration).
     */
    public void resetLaborSupplyLogCounter() {
        laborSupplyLogCount = 0;
    }
    
    // ========== Getters/Setters ==========
    
    public boolean isEnabled() {
        return enabled;
    }
    
    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    /**
     * Whether recording infrastructure is active (either full macro model or standalone recorder).
     * Use this as the gate for operations that should work in both modes:
     * baseline latching, labor supply diagnostics, path export.
     */
    public boolean isRecorderActive() {
        return enabled || recorderOnlyMode;
    }

    public boolean isRecorderOnlyMode() {
        return recorderOnlyMode;
    }

    public void setRecorderOnlyMode(boolean recorderOnlyMode) {
        this.recorderOnlyMode = recorderOnlyMode;
    }

    public boolean isPathRecordingEnabled() {
        return pathRecordingEnabled;
    }

    public void setPathRecordingEnabled(boolean pathRecordingEnabled) {
        this.pathRecordingEnabled = pathRecordingEnabled;
    }

    public boolean isUseDsge() {
        return useDsge;
    }

    public void setUseDsge(boolean useDsge) {
        this.useDsge = useDsge;
    }
    
    public boolean isLogMacroState() {
        return logMacroState;
    }

    public void setLogMacroState(boolean logMacroState) {
        this.logMacroState = logMacroState;
        if (laborSupplyAggregator != null) {
            laborSupplyAggregator.setLogEnabled(logMacroState);
        }
        if (dynamicDsgeModel != null) {
            dynamicDsgeModel.setLogEnabled(logMacroState);
        }
    }

    public boolean isVerboseMacroLogging() {
        return verboseMacroLogging;
    }

    public void setVerboseMacroLogging(boolean verboseMacroLogging) {
        this.verboseMacroLogging = verboseMacroLogging;
    }

    public String getDsgeShockScenario() {
        return dsgeShockScenario;
    }

    public void setDsgeShockScenario(String dsgeShockScenario) {
        this.dsgeShockScenario = dsgeShockScenario;
    }

    public String getRamseyScenario() {
        return ramseyScenario;
    }

    public void setRamseyScenario(String ramseyScenario) {
        this.ramseyScenario = ramseyScenario;
    }

    public double getMaxBounds() {
        return maxBounds;
    }

    public void setMaxBounds(double maxBounds) {
        this.maxBounds = maxBounds;
        if (dynamicDsgeModel != null) {
            dynamicDsgeModel.setMaxStateDeviation(maxBounds);
        }
    }

    public boolean isUseRamseyTrend() {
        return useRamseyTrend;
    }

    public void setUseRamseyTrend(boolean useRamseyTrend) {
        this.useRamseyTrend = useRamseyTrend;
    }

    public void setRamseyFeedbackMargins(MacroFeedbackMargins value) { this.ramseyFeedbackMargins = value; }
    public MacroFeedbackMargins getRamseyFeedbackMargins() { return ramseyFeedbackMargins; }
    public void setRamseyFeedbackPersistence(double value) { this.ramseyFeedbackPersistence = value; }
    public void setRamseyFeedbackHoursPersistence(double value) { this.ramseyFeedbackHoursPersistence = value; }

    /**
     * Get the Ramsey trend model (for testing/diagnostics).
     * @return RamseyTrendModel or null if not initialized
     */
    public RamseyTrendModel getRamseyTrend() {
        return ramseyTrend;
    }

    /**
     * Get the current Ramsey trend values (for testing/diagnostics).
     *
    * <p>Keys include: w, y, c, inv, k, g, nx, n_ramsey, l_ramsey.
     * Values are percentage changes from the first simulation year baseline.</p>
     *
     * @return Unmodifiable map of trend names to percentage changes, or empty if unavailable
     */
    public Map<String, Double> getCurrentRamseyTrends() {
        return Collections.unmodifiableMap(currentRamseyTrends);
    }

    /**
     * Get the current capital-deepening wage trend adjustment (in %).
     * 
     * <p>This is the secular trend component added on top of the DSGE's
     * business-cycle wage deviation. Positive means wages are above what
     * the DSGE alone would predict, due to rising K/L ratio.</p>
     * 
     * @return capital-deepening wage adjustment in percent
     */
    public double getCapitalDeepeningWageAdjustment() {
        return capitalDeepeningWageAdjustment;
    }

    /**
     * Get current DSGE wage deviation (% from steady state).
     * 
     * <p>Positive means wages are above steady state.</p>
     * 
     * @return wage deviation in percent (e.g., 2.5 means 2.5% above steady state)
     */
    public double getWageDeviation() {
        return wageDeviation;
    }
    
    /**
     * Get current DSGE inflation deviation (percentage points from steady state).
     * 
     * @return inflation deviation in percentage points
     */
    public double getInflationDeviation() {
        return inflationDeviation;
    }
    
    /**
     * Check if DSGE model has been initialized.
     */
    public boolean isInitialized() {
        return initialized;
    }
    
    /**
     * Export recorded dynamic DSGE paths to CSV.
     * 
     * @param outputFolder The experiment's output folder (where csv/ subdirectory will be created)
     */
    public void exportPaths(String outputFolder) {
        if ((!enabled && !recorderOnlyMode) || !initialized || !pathRecordingEnabled) {
            return;  // Nothing to export
        }
        
        try {
            if (recorderOnlyMode || !useDsge) {
                if (trendOnlyPathRecorder == null || !trendOnlyPathRecorder.hasData()) {
                    if (logMacroState) {
                        String mode = recorderOnlyMode ? "recorder-only" : "Ramsey-only";
                        log.warn("Macro path export skipped: recorder has no " + mode + " data");
                    }
                    return;
                }
                trendOnlyPathRecorder.exportToSimPathsOutput(outputFolder, MACRO_PATHS_FILENAME);
                if (logMacroState) {
                    String mode = recorderOnlyMode ? "recorder-only" : "Ramsey-only";
                    log.info("Macro paths exported (" + mode + "): " + trendOnlyPathRecorder.getSummary());
                }
                return;
            }

            if (dynamicDsgeModel == null) {
                if (logMacroState) {
                    log.warn("DSGE path export skipped: dynamic model not initialized");
                }
                return;
            }
            dynamicDsgeModel.exportPaths(outputFolder, MACRO_PATHS_FILENAME);
            MacroPathRecorder recorder = dynamicDsgeModel.getPathRecorder();
            if (recorder != null && recorder.hasData() && logMacroState) {
                log.info("DSGE paths exported: " + recorder.getSummary());
            }
        } catch (IOException e) {
            if (logMacroState) {
                log.error("Failed to export DSGE paths: " + e.getMessage(), e);
            }
        }
    }
    
    /**
     * Get path recording status summary.
     * @return Summary string or null if not available
     */
    public String getPathRecorderSummary() {
        if (!enabled && !recorderOnlyMode) {
            return null;
        }
        if (recorderOnlyMode || !useDsge) {
            return (trendOnlyPathRecorder != null) ? trendOnlyPathRecorder.getSummary() : null;
        }
        if (dynamicDsgeModel == null) return null;
        MacroPathRecorder recorder = dynamicDsgeModel.getPathRecorder();
        return (recorder != null) ? recorder.getSummary() : null;
    }
}
