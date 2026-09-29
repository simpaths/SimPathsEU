package simpaths.data.statistics;

import simpaths.data.Parameters;
import simpaths.model.Person;
import simpaths.model.SimPathsModel;
import simpaths.model.enums.Indicator;

/**
 * Age-band population aggregates, computed in a single pass over the population.
 *
 * <p>These figures used to be calculated inside {@code Statistics2.update(model)}, which
 * exported all of them — demographics, health, labour, income and wealth — to one omnibus
 * CSV. That file has been split by domain across {@link DemographicStatistics},
 * {@link HealthStatistics}, {@link LabourStatistics} and {@link WealthIncomeStatistics}.
 *
 * <p>Each of those outputs has its own {@code persist*} toggle and its own scheduled dump
 * event, so none of them may assume that another has already run. Rather than repeat the
 * traversal four times — four places to drift apart — the loop lives here once and the
 * collector caches one instance per simulated year (see {@code SimPathsCollector.ageBands()}).
 * One traversal per year whatever combination of outputs is enabled, and no ordering
 * dependency between the dump events.
 *
 * <p>The loop body is a verbatim copy of the original, minus the twelve calibration
 * residuals that were dropped in the same restructure (see the class javadoc of
 * {@link DemographicStatistics}), so no surviving statistic can have shifted.
 *
 * <p>Age bands are index 0 = 18-29, 1 = 30-54, 2 = 55-74 throughout.
 */
public class AgeBandAggregates {

    /** Number of age bands: 18-29, 30-54, 55-74. */
    public static final int BANDS = 3;

    // demographics
    private final double[] prMarr = {0.,0.,0.};
    private final double[] avkids = {0.,0.,0.};
    private final double[] popula = {0.,0.,0.};

    // health
    private final double[] health = {0.,0.,0.};
    private final double[] prDisa = {0.,0.,0.};

    // labour
    private final double[] workFT = {0.,0.,0.};
    private final double[] workPT = {0.,0.,0.};

    // income and wealth
    private final double[] labInc = {0.,0.,0.};
    private final double[] invInc = {0.,0.,0.};
    private final double[] penInc = {0.,0.,0.};
    private final double[] invLosses = {0.,0.,0.};
    private final double[] grossDisInc = {0.,0.,0.};
    private final double[] wealth = {0.,0.,0.};

    private AgeBandAggregates() {}

    /**
     * Traverse the population once and return the age-band aggregates for the current
     * simulated year.
     */
    public static AgeBandAggregates compute(SimPathsModel model) {

        AgeBandAggregates agg = new AgeBandAggregates();

        double[] prMarr = agg.prMarr;
        double[] avkids = agg.avkids;
        double[] health = agg.health;
        double[] prDisa = agg.prDisa;
        double[] workFT = agg.workFT;
        double[] workPT = agg.workPT;
        double[] labInc = agg.labInc;
        double[] invInc = agg.invInc;
        double[] invLosses = agg.invLosses;
        double[] penInc = agg.penInc;
        double[] grossDisInc = agg.grossDisInc;
        double[] wealth = agg.wealth;
        double[] popula = agg.popula;

        for (Person person : model.getPersons()) {
            // loop over entire population

            int ii = -1;
            if (person.getDag()>=18 && person.getDag()<=29) {
                ii = 0;
            } else if (person.getDag()>=30 && person.getDag()<=54) {
                ii = 1;
            } else if (person.getDag()>=55 && person.getDag()<=74) {
                ii = 2;
            }
            if (ii>=0) {

                double es = person.getBenefitUnit().getEquivalisedWeight();

                prMarr[ii] += person.getCohabiting();
                avkids[ii] += person.getBenefitUnit().getNumberChildrenAll();
                health[ii] += person.getDheValue();
                prDisa[ii] += (Indicator.True.equals(person.getDlltsd()))? 1.0: 0.0;
                labInc[ii] += person.getEarningsWeekly();
                if ((double)person.getLabourSupplyHoursWeekly() > Parameters.MIN_HOURS_FULL_TIME_EMPLOYED)
                    workFT[ii] += 1.0;
                else if ((double)person.getLabourSupplyHoursWeekly() > 1.0)
                    workPT[ii] += 1.0;

                invInc[ii] += person.getBenefitUnit().getInvestmentIncomeAnnual() / 12.0 / es;
                penInc[ii] += person.getBenefitUnit().getPensionIncomeAnnual() / 12.0 / es;
                if (person.getBenefitUnit().getInvestmentIncomeAnnual()<0.0) {
                    invLosses[ii] += person.getBenefitUnit().getInvestmentIncomeAnnual() / 12.0 / es;
                    grossDisInc[ii] += (person.getBenefitUnit().getDisposableIncomeMonthly() -
                            person.getBenefitUnit().getInvestmentIncomeAnnual() / 12.0) / es;
                } else {
                    grossDisInc[ii] += person.getBenefitUnit().getDisposableIncomeMonthly() / es;
                }
                wealth[ii] += person.getBenefitUnit().getLiquidWealth(false) / es;
                popula[ii] += 1.0;
            }
        }
        for (int ii=0; ii<=2; ii++) {

            // NOTE: this guard is always true for a count, so an empty age band divides by
            // zero and yields NaN. Preserved verbatim from the original: fixing it would
            // change output whenever a band empties.
            if (popula[ii]>=0) {

                labInc[ii] /= (workFT[ii] + workPT[ii]);    // per worker, so must precede the workFT/workPT normalisation
                prMarr[ii] /= popula[ii];
                avkids[ii] /= popula[ii];
                health[ii] /= popula[ii];
                prDisa[ii] /= popula[ii];
                workFT[ii] /= popula[ii];
                workPT[ii] /= popula[ii];
                invInc[ii] /= popula[ii];
                penInc[ii] /= popula[ii];
                invLosses[ii] /= popula[ii];
                grossDisInc[ii] /= popula[ii];
                wealth[ii] /= popula[ii];
            }
        }
        return agg;
    }

    // ------------------------------------------------------------------
    // Accessors, one per statistic; the argument is the age-band index
    // ------------------------------------------------------------------

    /** Share of the age band that is cohabiting. */
    public double prMarried(int band) { return prMarr[band]; }

    /** Mean number of dependent children in the benefit unit. */
    public double nChildren(int band) { return avkids[band]; }

    /** Head count of the age band. */
    public double population(int band) { return popula[band]; }

    /** Mean self-rated health score. */
    public double healthScore(int band) { return health[band]; }

    /** Share of the age band that is long-term sick or disabled. */
    public double prDisabled(int band) { return prDisa[band]; }

    /** Share of the age band working full time. */
    public double workFullTime(int band) { return workFT[band]; }

    /** Share of the age band working part time. */
    public double workPartTime(int band) { return workPT[band]; }

    /** Mean weekly earnings per worker (not equivalised). */
    public double labourIncomeWeeklyPerWorker(int band) { return labInc[band]; }

    /** Mean equivalised monthly investment income per capita. */
    public double investmentIncome(int band) { return invInc[band]; }

    /** Mean equivalised monthly pension income per capita. */
    public double pensionIncome(int band) { return penInc[band]; }

    /** Mean equivalised monthly investment losses per capita. */
    public double investmentLosses(int band) { return invLosses[band]; }

    /** Mean equivalised monthly disposable income gross of investment losses, per capita. */
    public double dispIncomeGrossOfLosses(int band) { return grossDisInc[band]; }

    /** Mean equivalised liquid wealth per capita. */
    public double wealth(int band) { return wealth[band]; }
}
