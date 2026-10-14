package simpaths.model.macro;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Predicate;
import org.apache.log4j.Logger;

import simpaths.model.Person;
import simpaths.model.enums.Labour;

/**
 * Aggregates individual labor supply decisions into macro shocks for the DSGE model.
 * 
 * This class bridges the microsimulation (individual labor supply decisions) with the
 * macroeconomic model (aggregate labor force and hours shocks). It computes:
 * 
 * <ul>
 *   <li><b>eps_L</b>: Labor force participation shock (log-deviation from baseline)</li>
 *   <li><b>eps_h</b>: Average hours per worker shock (log-deviation from baseline)</li>
 * </ul>
 * 
 * <h3>Aggregation Strategy</h3>
 * 
 * <p>For each working-age person in the microsimulation:</p>
 * <ol>
 *   <li>Labor force participation: Count persons with positive hours (hours &gt; 0)</li>
 *   <li>Hours per worker: Average weekly hours among those working</li>
 * </ol>
 * 
 * <p>These are then compared to baseline values to compute PERCENT log-deviations
 * (the units of the exported DSGE, which is estimated on 100&times;log-dev data):</p>
 * <pre>
 *   eps_L = 100 &times; ln(L_current / L_baseline)
 *   eps_h = 100 &times; ln(h_current / h_baseline)
 * </pre>
 * 
 * <h3>Extensive Margin (L) — Critical Design Decision</h3>
 * 
 * <p>L is the population-weighted count of persons who are <b>at risk of work</b>
 * (SimPaths' {@link simpaths.model.Person#atRiskOfWork()} — the same gate the
 * labour market uses to enter the discrete-choice model) <b>and</b> have
 * <b>positive working hours</b> (hours &gt; 0.5). Gating L on the canonical
 * at-risk predicate, rather than a looser "not student/retired" test, both
 * makes L responsive to wage changes (the micro-macro feedback) and prevents a
 * person who never entered this year's labour-supply model from leaking into L
 * via stale hours. The at-risk pool determines who enters the labor supply
 * model but does not itself drive eps_L.</p>
 *
 * <h3>Weighting — Correct For Both Run Modes</h3>
 *
 * <p>Every count-like aggregate is a weighted sum of {@code Person.getWeight()},
 * not a raw head count. SimPaths supports two population modes:</p>
 * <ul>
 *   <li><b>Unweighted</b> ({@code useWeights = false}, the default): the survey
 *       is expanded by cloning and every person's weight is reset to exactly
 *       {@code 1.0} ({@code Household.resetWeights(1.0)}), newborns inheriting
 *       the mother's weight. Weighted sums then reduce identically to head
 *       counts, so behaviour is unchanged.</li>
 *   <li><b>Weighted</b> ({@code useWeights = true}): survey households are kept
 *       with heterogeneous survey weights. A head count would bias eps_L,
 *       eps_h, and the cumulative capital-deepening trend; weighting removes
 *       that bias.</li>
 * </ul>
 * <p>Because weighting by {@code getWeight()} is correct in <em>both</em> modes,
 * the aggregator no longer has a hidden coupling to the run mode. Invalid
 * weights (null, non-finite, non-positive) are rejected loudly rather than
 * silently degrading the shocks (see {@code personWeight}).</p>
 * 
 * <h3>Usage in Iterative Equilibrium</h3>
 * 
 * <pre>{@code
 * LaborSupplyAggregator aggregator = new LaborSupplyAggregator();
 * aggregator.setBaseline(baselineL, baselineH);
 * 
 * // After microsim labor market update:
 * LaborSupplyShocks shocks = aggregator.aggregate(model.getPersons());
 * 
 * // Feed to dynamic DSGE state-space step:
 * // DSGEState state = dsge.stepAnnual(shocks.epsL(), otherShocks);
 * }</pre>
 * 
 * @author DSGE-SimPaths Integration
 * @version 1.0
 */
public class LaborSupplyAggregator {
    
    private static final Logger log = Logger.getLogger(LaborSupplyAggregator.class);
    
    // ========== Constants ==========
    
    /*
     * Working-age band for every macro aggregate (WAP, at-risk pool, L, hours).
     *
     * CONTRACT — this band is NOT arbitrary and must NOT be changed in
     * isolation. It deliberately encodes the Ramsey/DSGE working-age concept:
     *
     *  - It MUST equal the working-age band used by build_population_projection.m
     *    in the WELLSIM_SVEC repo (currently 15-64), because that script builds
     *    the WAP/N path the Ramsey trend layer consumes. eps_L and the exported
     *    demographic decomposition must be measured on the SAME population the
     *    DSGE's labour input N represents; if these diverge, the micro-macro
     *    feedback and the demographic series are silently measured against the
     *    wrong denominator. There is no shared config between the MATLAB build
     *    and this Java runtime, so the only thing keeping them in sync is this
     *    contract — change both sides together or not at all.
     *
     *  - It is intentionally NARROWER than SimPaths' own flexible-labour band
     *    (Parameters.MIN/MAX_AGE_FLEXIBLE_LABOUR_SUPPLY = 16-75, used by
     *    Person.atRiskOfWork()). L and the at-risk pool are the
     *    atRiskOfWork() subset of THIS band, so the effective at-risk lower
     *    bound is max(15, 16) = 16: a 15-year-old counts toward WAP but never
     *    toward the at-risk pool or L (atRiskOfWork() excludes age < 16). That
     *    asymmetry is correct — 15-year-olds are working-age population but not
     *    labour-market participants — and must not be "reconciled" by widening
     *    atRiskOfWork()'s band or narrowing WAP.
     */

    /** Minimum working age (inclusive). See CONTRACT above before changing. */
    public static final int DEFAULT_MIN_WORKING_AGE = 15;

    /** Maximum working age (inclusive). See CONTRACT above before changing. */
    public static final int DEFAULT_MAX_WORKING_AGE = 64;
    
    /** Minimum valid hours to count as "working" */
    private static final double MIN_HOURS_WORKING = 0.5;
    
    /** Small constant to avoid log(0) */
    private static final double EPSILON = 1e-10;

    /**
     * Conversion from natural-log deviations to the DSGE's percent units.
     * The exported policy matrices are estimated on 100&times;log-deviation data,
     * so eps_L/eps_h handed to {@code DSGEModel} must be percent log-deviations.
     */
    static final double PERCENT_PER_LOG_DEV = 100.0;
    
    // ========== Baseline Values ==========
    
    /** Baseline labor force participation (number of workers) */
    private double baselineL;
    
    /** Baseline average hours per worker */
    private double baselineH;
    
    /** Whether baseline has been set */
    private boolean baselineSet = false;

    /** Whether DSGE logging is enabled */
    private boolean logEnabled = false;
    
    // ========== Cumulative Tracking (for capital-deepening trend) ==========
    
    /** Start-year labor force (fixed, never rolls forward). Used for cumulative ln(L_t/L_0). */
    private double startYearL;
    
    /** Start-year average hours per worker (fixed, never rolls forward). Used for h level index. */
    private double startYearH;

    /** Start-year total population (all ages). Used for decomposition index. */
    private double startYearTotalPop;

    /** Start-year working-age population (15-64). Used for decomposition index. */
    private double startYearWAP;

    /** Start-year at-risk pool (non-student, non-retired 15-64). Used for decomposition index. */
    private double startYearAtRisk;
    
    /** Whether the L/h start-year values (post-labour-market) have been recorded */
    private boolean startYearLSet = false;

    /**
     * Whether the demographic start anchors (TotalPop, WAP, AtRisk) have been
     * recorded. These are labour-market-invariant head counts and are latched
     * eagerly in the first simulation year (before the labour market runs), so
     * the demographic indices are available from year 1 without waiting for the
     * post-labour-market L/h baseline latch. Split from {@link #startYearLSet}
     * on purpose: L/h MUST be captured post-labour-market (input-DB hours differ
     * from model-assigned hours), but the head counts must not be — see
     * {@link #latchDemographicAnchors}.
     */
    private boolean startYearDemogSet = false;
    
    /** Cumulative log-change in labor force since start year: sum of ln(L_t/L_{t-1}) */
    private double cumulativeLnL = 0.0;
    
    // ========== Working-Age Filter ==========
    
    /** Filter to determine which persons are in the working-age population */
    private Predicate<Person> workingAgeFilter;
    
    // ========== Latest Aggregation Results (for debugging) ==========
    
    private double lastL;
    private double lastH;
    private double lastWorkingAgeCount;
    private double lastWorkersCount;
    
    // ========== Constructor ==========
    
    /**
     * Create an aggregator with default working-age filter (15-64, not student/retired).
     */
    public LaborSupplyAggregator() {
        this.workingAgeFilter = this::defaultWorkingAgeFilter;
    }
    
    // ========== Baseline Management ==========
    
    /**
     * Set the baseline labor supply values.
     * 
     * <p>These should be computed from the microsim under baseline/status-quo conditions,
     * before any policy changes or shocks are applied.</p>
     * 
     * @param baselineL Baseline labor force (number of workers or participation rate)
     * @param baselineH Baseline average hours per worker
     * @throws IllegalArgumentException If values are non-positive
     */
    public void setBaseline(double baselineL, double baselineH) {
        if (baselineL <= 0) {
            throw new IllegalArgumentException("Baseline labor force must be positive: " + baselineL);
        }
        if (baselineH <= 0) {
            throw new IllegalArgumentException("Baseline hours must be positive: " + baselineH);
        }
        
        this.baselineL = baselineL;
        this.baselineH = baselineH;
        this.baselineSet = true;

        if (logEnabled) {
            log.info(String.format("Baseline set: L=%.2f workers, h=%.2f hours/week", baselineL, baselineH));
        }
    }
    
    /**
     * Compute and set baseline from current microsim state.
     * 
     * <p>Call this at the start of simulation (or after baseline run) to capture
     * the reference labor supply levels.</p>
     * 
     * @param persons Set of all persons in the simulation
     * @return The computed baseline aggregates
     */
    public LaborSupplyAggregates computeAndSetBaseline(Set<Person> persons) {
        LaborSupplyAggregates aggregates = computeRawAggregates(persons);
        setBaseline(aggregates.laborForce(), aggregates.avgHoursPerWorker());
        
        // L/h start anchors + cumulative tracking: MUST be the post-labour-market
        // state, latched once.
        if (!startYearLSet) {
            startYearL = aggregates.laborForce();
            startYearH = aggregates.avgHoursPerWorker();
            startYearLSet = true;
            cumulativeLnL = 0.0;
            if (logEnabled) {
                log.info(String.format("Start-year L/h recorded (post-labour-market): L_0=%.0f, h_0=%.2f",
                        startYearL, startYearH));
            }
        }

        // Demographic anchors are labour-market-invariant. If they were not
        // already latched eagerly in year 1 (latchDemographicAnchors), latch
        // them here as a fallback so callers that never call the eager path
        // still behave as before. If the eager latch already ran, its values
        // are kept (they are numerically identical — no demographic process
        // runs between the eager point and here within the first year).
        if (!startYearDemogSet) {
            startYearTotalPop = aggregates.totalPopulation();
            startYearWAP = aggregates.workingAgePopulation();
            startYearAtRisk = aggregates.atRiskPool();
            startYearDemogSet = true;
            if (logEnabled) {
                log.info(String.format("Start-year demographic anchors recorded (fallback): TotalPop_0=%.0f, WAP_0=%.0f, AtRisk_0=%.0f",
                        startYearTotalPop, startYearWAP, startYearAtRisk));
            }
        }

        return aggregates;
    }

    /**
     * Eagerly latch the demographic start anchors (TotalPop, WAP, AtRisk) from
     * the first-year population, before the labour market runs.
     *
     * <p>These are pure head counts, invariant to the labour-market update, so
     * latching them at the macro event in year 1 yields values numerically
     * identical to the post-labour-market latch — only earlier, so the
     * demographic indices (wap_level, atrisk_level, total_population) are
     * emitted from the first simulated year instead of being skipped until the
     * L/h baseline is set. It deliberately does NOT touch the L/h anchors,
     * {@code baselineSet}, or {@code cumulativeLnL}: those must remain
     * post-labour-market for eps_L / capital-deepening correctness.</p>
     *
     * <p>Idempotent: a no-op once the anchors are set (by this method or the
     * {@link #computeAndSetBaseline} fallback).</p>
     *
     * @param persons Set of all persons in the simulation
     */
    public void latchDemographicAnchors(Set<Person> persons) {
        if (startYearDemogSet) {
            return;
        }
        LaborSupplyAggregates a = computeRawAggregates(persons);
        startYearTotalPop = a.totalPopulation();
        startYearWAP = a.workingAgePopulation();
        startYearAtRisk = a.atRiskPool();
        startYearDemogSet = true;
        if (logEnabled) {
            log.info(String.format("Start-year demographic anchors recorded (eager, pre-labour-market): TotalPop_0=%.0f, WAP_0=%.0f, AtRisk_0=%.0f",
                    startYearTotalPop, startYearWAP, startYearAtRisk));
        }
    }
    
    /**
     * Check if baseline has been set.
     */
    public boolean isBaselineSet() {
        return baselineSet;
    }
    
    public void setLogEnabled(boolean logEnabled) {
        this.logEnabled = logEnabled;
    }
    
    /**
     * Advance the baseline to the most recently observed values.
     * 
     * <p>Call this at the END of each simulation year (after aggregate() has been called).
     * The next year's shocks will then be measured relative to this year's labor supply,
     * producing year-over-year changes instead of cumulative deviations.</p>
     * 
     * <p>Requires valid baseline and latest aggregate values.</p>
     */
    public void advanceBaseline() {
        if (!baselineSet) {
            if (logEnabled) {
                log.warn("Cannot advance baseline: baseline not yet set");
            }
            return;
        }
        if (lastL <= 0 || lastH <= 0) {
            if (logEnabled) {
                log.warn(String.format("Cannot advance baseline: invalid last values L=%.1f, h=%.2f", lastL, lastH));
            }
            return;
        }
        
        double oldL = baselineL;
        double oldH = baselineH;
        
        // Accumulate year-over-year log-change for capital-deepening trend
        if (oldL > EPSILON && lastL > EPSILON) {
            double yearOverYearLnL = Math.log(lastL / oldL);
            cumulativeLnL += yearOverYearLnL;
            if (logEnabled) {
                log.info(String.format("Capital deepening: year-over-year ln(L)=%+.4f, cumulative=%+.4f (L_0=%.0f, L_now=%.0f)",
                        yearOverYearLnL, cumulativeLnL, startYearL, lastL));
            }
        }
        
        baselineL = lastL;
        baselineH = lastH;
        
        if (logEnabled) {
            log.info(String.format("Rolling baseline advanced: L=%.0f→%.0f, h=%.2f→%.2f",
                oldL, baselineL, oldH, baselineH));
        }
    }
    
    /**
     * Get baseline labor force.
     */
    public double getBaselineL() {
        validateBaselineSet();
        return baselineL;
    }
    
    /**
     * Get baseline hours per worker.
     */
    public double getBaselineH() {
        validateBaselineSet();
        return baselineH;
    }
    
    /**
     * Get cumulative log-change in labor force since start year.
     * 
     * <p>This equals ln(L_current / L_startYear), accumulated via summing
     * year-over-year changes. Used for the capital-deepening wage trend.</p>
     * 
     * <p>Negative values mean the labor force has shrunk (typical for aging
     * economies), which produces a positive capital-deepening wage effect.</p>
     * 
     * @return cumulative ln(L_t / L_0), negative means labor force declined
     */
    public double getCumulativeLnL() {
        return cumulativeLnL;
    }

    /**
     * Get cumulative log-change including the current year-over-year step.
     *
     * <p>This is a preview that adds ln(L_t / L_{t-1}) based on the latest
     * aggregate (lastL) and current rolling baseline (baselineL) without
     * mutating state.</p>
     *
     * @return cumulative ln(L_t / L_0) including the current year
     */
    public double getCumulativeLnLIncludingCurrent() {
        if (!baselineSet || lastL <= EPSILON || baselineL <= EPSILON) {
            return cumulativeLnL;
        }
        double yearOverYearLnL = Math.log(lastL / baselineL);
        return cumulativeLnL + yearOverYearLnL;
    }
    
    /**
     * Get the start-year labor force (L_0).
     * @return start-year labor force count, or 0 if not yet set
     */
    public double getStartYearL() {
        return startYearLSet ? startYearL : 0.0;
    }
    
    /**
     * Get the start-year average hours per worker (h_0).
     * @return start-year hours per worker, or 0 if not yet set
     */
    public double getStartYearH() {
        return startYearLSet ? startYearH : 0.0;
    }

    /**
     * Get the start-year total population (all ages).
     * @return start-year total population, or 0 if not yet set
     */
    public double getStartYearTotalPop() {
        return startYearDemogSet ? startYearTotalPop : 0.0;
    }

    /**
     * Get the start-year working-age population (15-64).
     * @return start-year WAP, or 0 if not yet set
     */
    public double getStartYearWAP() {
        return startYearDemogSet ? startYearWAP : 0.0;
    }

    /**
     * Get the start-year at-risk pool (non-student, non-retired 15-64).
     * @return start-year at-risk count, or 0 if not yet set
     */
    public double getStartYearAtRisk() {
        return startYearDemogSet ? startYearAtRisk : 0.0;
    }
    
    // ========== Core Aggregation ==========
    
    /**
     * Aggregate individual labor supply into macro shocks.
     * 
     * <p>Computes current labor force and hours, then returns log-deviations from baseline.</p>
     * 
     * @param persons Set of all persons in the simulation
     * @return Labor supply shocks (eps_L, eps_h) for the DSGE model
     * @throws IllegalStateException If baseline not set
     */
    public LaborSupplyShocks aggregate(Set<Person> persons) {
        validateBaselineSet();
        Objects.requireNonNull(persons, "Persons set cannot be null");
        
        // Compute current aggregates
        LaborSupplyAggregates current = computeRawAggregates(persons);
        
        // Store for debugging
        this.lastL = current.laborForce();
        this.lastH = current.avgHoursPerWorker();
        this.lastWorkingAgeCount = current.workingAgePopulation();
        this.lastWorkersCount = current.laborForce();
        
        // Compute log-deviations from baseline
        double epsL = computeLogDeviation(current.laborForce(), baselineL);
        double epsH = computeLogDeviation(current.avgHoursPerWorker(), baselineH);
        
        if (logEnabled && log.isDebugEnabled()) {
            log.debug(String.format(
                "Labor aggregation: L=%.1f (baseline=%.1f, eps_L=%.4f), h=%.2f (baseline=%.2f, eps_h=%.4f)",
                current.laborForce(), baselineL, epsL,
                current.avgHoursPerWorker(), baselineH, epsH));
        }
        
        return new LaborSupplyShocks(epsL, epsH, current);
    }
    
    /**
     * Aggregate without computing deviations (for baseline computation or diagnostics).
     * 
     * @param persons Set of all persons in the simulation
     * @return Raw labor supply aggregates
     */
    public LaborSupplyAggregates computeRawAggregates(Set<Person> persons) {
        Objects.requireNonNull(persons, "Persons set cannot be null");

        // All aggregates are population-weighted. In unweighted runs every person's
        // weight is reset to exactly 1.0 (SimPathsModel.cloneHousehold ->
        // Household.resetWeights(1.0), and newborns inherit the mother's weight),
        // so these weighted sums reduce identically to plain head counts. In
        // weighted runs survey weights are heterogeneous and a head count would
        // bias eps_L / eps_h and the capital-deepening trend. Weighting by
        // getWeight() is therefore correct in BOTH modes.
        double totalPopulationWeight = 0.0;
        double workingAgeWeight = 0.0;
        double atRiskWeight = 0.0;
        double laborForceWeight = 0.0;   // extensive margin L = weighted workers with hours > 0
        double totalHours = 0.0;         // weighted hours = sum of weight * hours
        Labour[] countryCategories = Labour.valuesForCurrentCountry();
        Map<Labour, double[]> categoryAccumulators = new LinkedHashMap<>();
        for (Labour category : countryCategories) {
            categoryAccumulators.put(category, new double[2]);
        }

        for (Person person : persons) {
            if (person == null) {
                continue;
            }

            double weight = personWeight(person);

            totalPopulationWeight += weight;

            int age = person.getDag();
            if (age < DEFAULT_MIN_WORKING_AGE || age > DEFAULT_MAX_WORKING_AGE) {
                continue;
            }

            workingAgeWeight += weight;

            // Labor force: exclude students and retired by default
            if (!workingAgeFilter.test(person)) {
                continue;
            }

            atRiskWeight += weight;

            // Get hours worked
            Labour category = person.getLabourSupplyWeekly();
            if (category == null || !categoryAccumulators.containsKey(category)) {
                category = Labour.ZERO;
            }
            int hoursWeekly = getPersonHours(person);
            double[] categoryTotals = categoryAccumulators.get(category);
            categoryTotals[0] += weight;
            categoryTotals[1] += weight * hoursWeekly;

            if (hoursWeekly > MIN_HOURS_WORKING) {
                laborForceWeight += weight;
                totalHours += weight * hoursWeekly;
            }
        }

        // Intensive margin is the weighted mean hours among workers:
        // sum(w*h) / sum(w). Avoid division by zero.
        double avgHoursPerWorker = laborForceWeight > 0.0 ? totalHours / laborForceWeight : 0.0;
        // Employment rate: weighted share of working-age pop with positive hours
        double employmentRate = workingAgeWeight > 0.0 ? laborForceWeight / workingAgeWeight : 0.0;
        Map<Labour, LabourCategorySummary> categoryDistribution = new LinkedHashMap<>();
        for (Labour category : countryCategories) {
            double[] totals = categoryAccumulators.get(category);
            double categoryWeight = totals[0];
            double meanHours = categoryWeight > 0.0 ? totals[1] / categoryWeight : 0.0;
            double share = atRiskWeight > 0.0 ? 100.0 * categoryWeight / atRiskWeight : 0.0;
            categoryDistribution.put(category, new LabourCategorySummary(share, categoryWeight, meanHours));
        }

        return new LaborSupplyAggregates(
            laborForceWeight,       // laborForce = extensive margin (weighted workers, hours > 0)
            avgHoursPerWorker,      // avgHoursPerWorker (weighted mean among workers)
            totalHours,             // totalHours (weighted)
            workingAgeWeight,       // workingAgePopulation (weighted)
            employmentRate,         // participationRate (weighted employment rate)
            atRiskWeight,           // atRiskPool (weighted, non-student/retired 15-64)
            totalPopulationWeight,  // totalPopulation (weighted, all persons all ages)
            categoryDistribution
        );
    }

    /**
     * Build a verbose diagnostic of the labour-supply category distribution and
     * mean hours per category over the current at-risk pool.
     *
     * <p>Uses exactly the age band and at-risk filter that
     * {@link #computeRawAggregates} applies, so the shares are taken over the
     * same denominator as the participation rate and {@code avgHoursPerWorker}.
     * Persons are binned by {@link Person#getLabourSupplyWeekly()} (the discrete
     * choice the labour-supply model assigned, {@code ZERO} = not working).
     * Mean hours per category is the population-weighted mean of the assigned
     * weekly hours within that category.</p>
     *
     * <p>This is the lens for the wage-feedback intensive-margin question:
     * because PL has only {@code ZERO/PL_1[1-39]/PL_2[40]/PL_3[41-60]} and the
     * within-bin hours draw is person-frozen, an aggregate mean-hours decline
     * can only come from mass shifting toward the wide {@code PL_1} bin — this
     * table makes that shift directly observable.</p>
     *
     * @param persons Set of all persons in the simulation
     * @return Multi-line, log-ready category distribution table
     */
    public String formatLabourCategoryDistribution(Set<Person> persons) {
        Objects.requireNonNull(persons, "Persons set cannot be null");

        return formatLabourCategoryDistribution(computeRawAggregates(persons));
    }

    public String formatLabourCategoryDistribution(LaborSupplyAggregates aggregates) {
        Objects.requireNonNull(aggregates, "Aggregates cannot be null");

        StringBuilder sb = new StringBuilder();
        sb.append(String.format(
                "Labour category distribution (at-risk pool=%.0f, mean hours/worker=%.2f):",
                aggregates.atRiskPool(), aggregates.avgHoursPerWorker()));
        for (Map.Entry<Labour, LabourCategorySummary> e : aggregates.categoryDistribution().entrySet()) {
            LabourCategorySummary summary = e.getValue();
            sb.append(String.format(
                    "%n    %-14s share=%5.1f%%  weight=%10.0f  meanHours=%5.2f",
                    e.getKey().name(), summary.share(), summary.weight(), summary.meanHours()));
        }
        return sb.toString();
    }

    /**
     * Returns the person's population weight, failing loudly on values that
     * would silently corrupt the aggregates. A non-finite or non-positive
     * weight means the run is misconfigured (e.g. a person created without a
     * weight); silently treating it as 0 or 1 would bias eps_L and the
     * capital-deepening trend with no warning, so this is a hard error rather
     * than a degraded-but-quiet path.
     */
    private double personWeight(Person person) {
        Double w = person.getWeight();
        if (w == null || !Double.isFinite(w) || w <= 0.0) {
            throw new IllegalStateException(
                "Person " + person.getKey() + " has invalid population weight (" + w
                + "). Labour-supply aggregation requires every person to carry a "
                + "positive, finite weight (1.0 in unweighted runs, the survey "
                + "weight in weighted runs).");
        }
        return w;
    }
    
    /**
     * Get hours worked by a person, handling nulls safely.
     */
    private int getPersonHours(Person person) {
        try {
            return person.getLabourSupplyHoursWeekly();
        } catch (RuntimeException e) {
            // Labour supply not yet initialized
            return 0;
        }
    }
    
    /**
     * Compute the shock in the DSGE's units: 100 * ln(current / baseline).
     *
     * <p><b>Units contract:</b> the exported policy matrices are estimated on
     * percent-unit data (the Ramsey detrending writes observables as
     * 100&times;log-deviations, so e.g. sigma_L = 0.783 means 0.78%). eps_L/eps_h
     * must therefore be handed to the DSGE as percent log-deviations. Passing a
     * raw ln fraction (0.05 for a 5% change) would enter the model as a 0.05%
     * shock — a factor-100 attenuation of the whole cyclical feedback channel.</p>
     *
     * <p>(Package-private for unit testing.)</p>
     */
    double computeLogDeviation(double current, double baseline) {
        // Handle edge cases
        if (baseline <= EPSILON) {
            if (logEnabled) {
                log.warn("Baseline is zero or negative, returning 0 for log-deviation");
            }
            return 0.0;
        }
        if (current <= EPSILON) {
            // Large negative shock (approaching -infinity), cap it
            if (logEnabled) {
                log.warn("Current value is zero or negative, capping log-deviation at -500 (percent)");
            }
            return -5.0 * PERCENT_PER_LOG_DEV;
        }

        return PERCENT_PER_LOG_DEV * Math.log(current / baseline);
    }
    
    // ========== Working-Age Filter ==========
    
    /**
     * Default filter: working-age (15-64) AND at risk of work in SimPaths'
     * own sense.
     *
     * <p>This delegates the eligibility decision to {@link Person#atRiskOfWork()}
     * — the exact predicate the labour market uses to decide who enters the
     * discrete-choice labour-supply model. It excludes not only students and
     * retirees but also the long-term disabled and persons with a non-finite
     * inverse Mills ratio ("will not work for any wage"). Using the looser
     * Les_c4-only test previously made the at-risk pool — and hence the
     * participation/employment-rate denominator and the exported demographic
     * series — diverge from the population SimPaths actually sends through the
     * labour market, with a bias that grows as disability prevalence rises with
     * age.</p>
     *
     * <p>Because this gate is applied before the hours test, it also makes the
     * extensive margin L robust: a person who did not pass through this year's
     * labour-supply model cannot leak into L via a stale positive
     * {@code labHrsWorkEnumWeek}, even though the labour market normally already
     * resets not-at-risk persons to zero hours.</p>
     *
     * <p>The explicit [15, 64] age band is retained for working-age-population
     * consistency and is intentionally <em>not</em> reconciled here with
     * {@code atRiskOfWork()}'s own flexible-labour age bounds (16-75); that age
     * basis is tracked separately. The net effect is the intersection of the
     * two bands.</p>
     */
    private boolean defaultWorkingAgeFilter(Person person) {
        if (person == null) {
            return false;
        }

        // Check age (working-age-population band; see Javadoc on the age basis)
        int age = person.getDag();
        if (age < DEFAULT_MIN_WORKING_AGE || age > DEFAULT_MAX_WORKING_AGE) {
            return false;
        }

        // Canonical SimPaths labour-market entry gate (single source of truth).
        return isAtRiskOfWork(person);
    }

    /**
     * Safe wrapper around {@link Person#atRiskOfWork()}. That method recomputes
     * an inverse Mills ratio and can throw on a degenerate probit CDF; a
     * pathological individual must not abort the whole macro aggregation, and
     * "cannot evaluate participation" is conservatively treated as not at risk
     * of work — consistent with {@code atRiskOfWork()}'s own non-finite-IMR
     * branch.
     */
    private boolean isAtRiskOfWork(Person person) {
        try {
            return person.atRiskOfWork();
        } catch (RuntimeException e) {
            return false;
        }
    }
    
    /**
     * Set a custom working-age filter.
     * 
     * @param filter Predicate that returns true for persons in the working-age population
     */
    public void setWorkingAgeFilter(Predicate<Person> filter) {
        this.workingAgeFilter = Objects.requireNonNull(filter, "Filter cannot be null");
    }
    
    /**
     * Reset to default working-age filter.
     */
    public void resetWorkingAgeFilter() {
        this.workingAgeFilter = this::defaultWorkingAgeFilter;
    }

    /**
     * Whether a person is in the at-risk pool — i.e. would pass the current
     * working-age filter and so be eligible to enter the discrete-choice labour
     * supply model. This is the canonical entry gate used by {@link #aggregate}
     * to compute {@code atRiskPool}, so callers that need to measure something
     * over the same population (e.g. the realized-wage diagnostic) should use
     * this predicate rather than re-implementing the filter.
     *
     * @param person the person to test (may be null)
     * @return true if the person is in the at-risk pool
     */
    public boolean isInAtRiskPool(Person person) {
        if (person == null) {
            return false;
        }
        return workingAgeFilter.test(person);
    }
    
    // ========== Diagnostic Methods ==========
    
    /**
     * Get the last computed labor force (from most recent aggregate() call).
     */
    public double getLastL() {
        return lastL;
    }
    
    /**
     * Get the last computed average hours (from most recent aggregate() call).
     */
    public double getLastH() {
        return lastH;
    }
    
    /**
     * Get the last working-age population (weighted).
     */
    public double getLastWorkingAgeCount() {
        return lastWorkingAgeCount;
    }

    /**
     * Get the last workers count (weighted extensive margin).
     */
    public double getLastWorkersCount() {
        return lastWorkersCount;
    }
    
    // ========== Validation ==========
    
    private void validateBaselineSet() {
        if (!baselineSet) {
            throw new IllegalStateException(
                "Baseline not set. Call setBaseline() or computeAndSetBaseline() first.");
        }
    }
    
    @Override
    public String toString() {
        if (!baselineSet) {
            return "LaborSupplyAggregator[baseline not set]";
        }
        return String.format(
            "LaborSupplyAggregator[baseline: L=%.1f, h=%.2f; last: L=%.1f, h=%.2f]",
            baselineL, baselineH, lastL, lastH);
    }
    
    // ========== Inner Records ==========
    
    /**
     * Container for labor supply shocks to feed into the DSGE model.
     * 
     * @param epsL  Labor force shock (log-deviation from baseline participation)
     * @param epsH  Hours shock (log-deviation from baseline hours per worker)
     * @param aggregates The raw aggregates that produced these shocks
     */
    public record LaborSupplyShocks(
            double epsL,
            double epsH,
            LaborSupplyAggregates aggregates
    ) {
        /**
         * Create zero shocks (steady state).
         */
        public static LaborSupplyShocks zero() {
            return new LaborSupplyShocks(0.0, 0.0, null);
        }
        
        @Override
        public String toString() {
            return String.format("LaborSupplyShocks[eps_L=%.4f, eps_h=%.4f]", epsL, epsH);
        }
    }
    
    /**
     * Container for raw labor supply aggregates (before computing deviations).
     * 
     * <p><b>Critical distinction:</b></p>
     * <ul>
     *   <li>{@code laborForce} = extensive margin of labor supply = at-risk-of-work
     *       persons with positive hours (hours > 0.5). This is what drives eps_L in the
     *       DSGE and can respond to wage changes because it is measured AFTER the discrete
     *       choice labor supply model.</li>
     *   <li>{@code atRiskPool} = persons aged 15-64 who are at risk of work in SimPaths'
     *       sense ({@link simpaths.model.Person#atRiskOfWork()}: not student/retired, not
     *       long-term disabled, finite inverse Mills ratio) and therefore ENTER the labor
     *       supply model. This is a demographic concept that does not respond to wages.</li>
     * </ul>
     * 
     * <p>All count-like fields ({@code laborForce}, {@code workingAgePopulation},
     * {@code atRiskPool}, {@code totalPopulation}) are population-weighted sums,
     * not raw head counts: they equal the head count when every weight is 1.0
     * (unweighted runs) and the survey-weighted total otherwise.</p>
     *
     * @param laborForce          Extensive margin: weighted at-risk persons with positive hours (drives eps_L)
     * @param avgHoursPerWorker   Weighted mean weekly hours among workers (intensive margin)
     * @param totalHours          Weighted total hours worked by all workers (sum of weight*hours)
     * @param workingAgePopulation Weighted working-age population (15-64)
     * @param participationRate   Weighted employment rate (laborForce / workingAgePop)
     * @param atRiskPool          Weighted persons entering labor supply model (Person.atRiskOfWork(), age 15-64)
     * @param totalPopulation     Weighted total simulation population (all ages)
     */
    public record LaborSupplyAggregates(
            double laborForce,
            double avgHoursPerWorker,
            double totalHours,
            double workingAgePopulation,
            double participationRate,
            double atRiskPool,
            double totalPopulation,
            Map<Labour, LabourCategorySummary> categoryDistribution
    ) {
        public LaborSupplyAggregates {
            categoryDistribution = categoryDistribution == null
                    ? Collections.emptyMap()
                    : Collections.unmodifiableMap(new LinkedHashMap<>(categoryDistribution));
        }

        public LaborSupplyAggregates(
                double laborForce,
                double avgHoursPerWorker,
                double totalHours,
                double workingAgePopulation,
                double participationRate,
                double atRiskPool,
                double totalPopulation
        ) {
            this(laborForce, avgHoursPerWorker, totalHours, workingAgePopulation,
                    participationRate, atRiskPool, totalPopulation, Collections.emptyMap());
        }

        @Override
        public String toString() {
            return String.format(
                "LaborSupplyAggregates[L=%.0f employed (%.1f%% of %.0f WAP, %.0f at-risk, %.0f total pop), h=%.1f hrs/wk, total=%.0f hrs]",
                laborForce, participationRate * 100, workingAgePopulation,
                atRiskPool, totalPopulation, avgHoursPerWorker, totalHours);
        }
    }

    public record LabourCategorySummary(
            double share,
            double weight,
            double meanHours
    ) {}
}
