package simpaths.data.statistics;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;

import microsim.data.db.PanelEntityKey;

/**
 * Demographic statistics by age band: partnership rates, dependent children and
 * population counts. One row per simulated year, exported to
 * {@code DemographicStatistics.csv}.
 *
 * <p>Formerly {@code Statistics2}, which exported {@code Statistics21.csv} — an omnibus of
 * 51 columns spanning demographics, health, labour, income, wealth and consumption. That
 * file has been split by domain across this class, {@link HealthStatistics},
 * {@link LabourStatistics} and {@link WealthIncomeStatistics}, all fed from one shared
 * traversal of the population ({@link AgeBandAggregates}).
 *
 * <p>Twelve of the original 51 columns were dropped in the same change. They were not
 * statistics but calibration loss-function terms — a hard-coded empirical target was
 * subtracted from the simulated value, invisibly, so a share could be reported as
 * -0.0416 and monthly expenditure as a negative number. The targets came from pooled
 * 2019 UK (UKHLS) data, did not vary with simulation year, and nothing in the codebase
 * read them. The affected fields were {@code labNoWork*Share} (recoverable as
 * 1 - full-time - part-time from {@link LabourStatistics}), {@code x*Avg} (expenditure),
 * {@code xToLeisureRatio} and {@code statYDisp*Avg} (disposable income net of losses;
 * {@code statYDispGrossOfLosses*Avg} survives in {@link WealthIncomeStatistics}).
 *
 * <p>The population counts here are the denominator for the age-band statistics in the
 * other three wide files, so keep this output enabled when interpreting them.
 */
@Entity
public class DemographicStatistics {

    @Id
    private PanelEntityKey key = new PanelEntityKey(1L);

    //population shares in cohabiting relationships
    @Column(name = "pr_married_18_29")
    private double demMarried18to29Share;

    @Column(name = "pr_married_30_54")
    private double demMarried30to54Share;

    @Column(name = "pr_married_55_74")
    private double demMarried55to74Share;

    //average dependent children
    @Column(name = "avkids_18_29")
    private double demNChild18to29Avg;

    @Column(name = "avkids_30_54")
    private double demNChild30to54Avg;

    @Column(name = "avkids_55_74")
    private double demNChild55to74Avg;

    //population counts
    @Column(name= "population_18_29")
    private double demPop18to29N;

    @Column(name= "population_30_54")
    private double demPop30to54N;

    @Column(name= "population_55_74")
    private double demPop55to74N;


    public double getPrMarried18to29() {
        return demMarried18to29Share;
    }

    public void setPrMarried18to29(double demMarried18to29Share) {
        this.demMarried18to29Share = demMarried18to29Share;
    }

    public double getPrMarried30to54() {
        return demMarried30to54Share;
    }

    public void setPrMarried30to54(double demMarried30to54Share) {
        this.demMarried30to54Share = demMarried30to54Share;
    }

    public double getPrMarried55to74() {
        return demMarried55to74Share;
    }

    public void setPrMarried55to74(double demMarried55to74Share) {
        this.demMarried55to74Share = demMarried55to74Share;
    }

    public double getAvkids18to29() {
        return demNChild18to29Avg;
    }

    public void setAvkids18to29(double demNChild18to29Avg) {
        this.demNChild18to29Avg = demNChild18to29Avg;
    }

    public double getAvkids30to54() {
        return demNChild30to54Avg;
    }

    public void setAvkids30to54(double demNChild30to54Avg) {
        this.demNChild30to54Avg = demNChild30to54Avg;
    }

    public double getAvkids55to74() {
        return demNChild55to74Avg;
    }

    public void setAvkids55to74(double demNChild55to74Avg) {
        this.demNChild55to74Avg = demNChild55to74Avg;
    }

    public double getPopulation18to29() {
        return demPop18to29N;
    }

    public void setPopulation18to29(double demPop18to29N) {
        this.demPop18to29N = demPop18to29N;
    }

    public double getPopulation30to54() {
        return demPop30to54N;
    }

    public void setPopulation30to54(double demPop30to54N) {
        this.demPop30to54N = demPop30to54N;
    }

    public double getPopulation55to74() {
        return demPop55to74N;
    }

    public void setPopulation55to74(double demPop55to74N) {
        this.demPop55to74N = demPop55to74N;
    }

    /** Map the shared age-band aggregates onto this output. */
    public void update(AgeBandAggregates agg) {

        setPrMarried18to29(agg.prMarried(0));
        setPrMarried30to54(agg.prMarried(1));
        setPrMarried55to74(agg.prMarried(2));

        setAvkids18to29(agg.nChildren(0));
        setAvkids30to54(agg.nChildren(1));
        setAvkids55to74(agg.nChildren(2));

        setPopulation18to29(agg.population(0));
        setPopulation30to54(agg.population(1));
        setPopulation55to74(agg.population(2));
    }
}
