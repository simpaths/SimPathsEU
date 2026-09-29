package simpaths.data.statistics;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;

import microsim.data.db.PanelEntityKey;
import microsim.statistics.CrossSection;
import microsim.statistics.IDoubleSource;
import microsim.statistics.functions.MeanArrayFunction;

import simpaths.data.filters.AgeGroupCSfilter;
import simpaths.data.filters.EmploymentHistoryFilter;
import simpaths.model.Person;
import simpaths.model.SimPathsModel;
import simpaths.model.enums.Les_c4;

/**
 * Labour-market statistics. One row per simulated year, exported to
 * {@code LabourStatistics.csv}. Records:
 *   - for the working-age adult population (16-64): transition rates between employed (E)
 *     and not-employed (NE) states, and headline proportions employed / not-employed
 *   - by age band (18-29, 30-54, 55-74): full-time and part-time shares
 *
 * <p>Formerly {@code EmploymentStatistics}, exported as {@code EmploymentStatistics1.csv}.
 * The age-band shares came out of the omnibus {@code Statistics2} (see
 * {@link DemographicStatistics}) and are fed from the shared {@link AgeBandAggregates};
 * the 16-64 figures are still computed here from the population directly.
 *
 * <p>The former {@code labNoWork*Share} columns are not carried over: every one of them
 * was a calibration residual rather than a share (see {@link DemographicStatistics}), and
 * the not-working share is in any case 1 - full-time - part-time.
 *
 * Ported from SimPathsUK. Uses the same Person.getEmployed()/getNonwork()
 * integer indicators and Les_c4 enum which are common to both UK and EU models.
 */
@Entity
public class LabourStatistics {

    @Id
    private PanelEntityKey key = new PanelEntityKey(1L);

    @Column(name = "EmpToNotEmp")
    private double labEmpToNotEmpShare;         // Proportion of employed persons who became not-employed

    @Column(name = "NotEmpToEmp")
    private double labNotEmpToEmpShare;         // Proportion of not-employed persons who became employed

    @Column(name = "PropEmployed")
    private double labEmpShare;

    @Column(name = "PropUnemployed")
    private double labUnempShare;

    //average labour status by age band
    @Column(name = "work_fulltime_18_29")
    private double labWorkFullTime18to29Share;

    @Column(name = "work_fulltime_30_54")
    private double labWorkFullTime30to54Share;

    @Column(name = "work_fulltime_55_74")
    private double labWorkFullTime55to74Share;

    @Column(name = "work_parttime_18_29")
    private double labWorkPartTime18to29Share;

    @Column(name = "work_parttime_30_54")
    private double labWorkPartTime30to54Share;

    @Column(name = "work_parttime_55_74")
    private double labWorkPartTime55to74Share;


    public double getEmpToNotEmp() {
        return labEmpToNotEmpShare;
    }

    public void setEmpToNotEmp(double empToNotEmp) {
        this.labEmpToNotEmpShare = empToNotEmp;
    }

    public double getNotEmpToEmp() {
        return labNotEmpToEmpShare;
    }

    public void setNotEmpToEmp(double notEmpToEmp) {
        this.labNotEmpToEmpShare = notEmpToEmp;
    }

    public double getPropEmployed() {
        return labEmpShare;
    }

    public void setPropEmployed(double propEmployed) {
        this.labEmpShare = propEmployed;
    }

    public double getPropUnemployed() {
        return labUnempShare;
    }

    public void setPropUnemployed(double propUnemployed) {
        this.labUnempShare = propUnemployed;
    }

    public double getAworkFulltime18to29() {
        return labWorkFullTime18to29Share;
    }

    public void setAworkFulltime18to29(double labWorkFullTime18to29Share) {
        this.labWorkFullTime18to29Share = labWorkFullTime18to29Share;
    }

    public double getAworkFulltime30to54() {
        return labWorkFullTime30to54Share;
    }

    public void setAworkFulltime30to54(double labWorkFullTime30to54Share) {
        this.labWorkFullTime30to54Share = labWorkFullTime30to54Share;
    }

    public double getAworkFulltime55to74() {
        return labWorkFullTime55to74Share;
    }

    public void setAworkFulltime55to74(double labWorkFullTime55to74Share) {
        this.labWorkFullTime55to74Share = labWorkFullTime55to74Share;
    }

    public double getAworkParttime18to29() {
        return labWorkPartTime18to29Share;
    }

    public void setAworkParttime18to29(double labWorkPartTime18to29Share) {
        this.labWorkPartTime18to29Share = labWorkPartTime18to29Share;
    }

    public double getAworkParttime30to54() {
        return labWorkPartTime30to54Share;
    }

    public void setAworkParttime30to54(double labWorkPartTime30to54Share) {
        this.labWorkPartTime30to54Share = labWorkPartTime30to54Share;
    }

    public double getAworkParttime55to74() {
        return labWorkPartTime55to74Share;
    }

    public void setAworkParttime55to74(double labWorkPartTime55to74Share) {
        this.labWorkPartTime55to74Share = labWorkPartTime55to74Share;
    }

    /**
     * Recompute the 16-64 transition and participation rates from the population, and map
     * the shared age-band aggregates onto the full-time / part-time shares.
     */
    public void update(SimPathsModel model, AgeBandAggregates agg) {

        setAworkFulltime18to29(agg.workFullTime(0));
        setAworkFulltime30to54(agg.workFullTime(1));
        setAworkFulltime55to74(agg.workFullTime(2));

        setAworkParttime18to29(agg.workPartTime(0));
        setAworkParttime30to54(agg.workPartTime(1));
        setAworkParttime55to74(agg.workPartTime(2));

        EmploymentHistoryFilter employedLastPeriod = new EmploymentHistoryFilter(Les_c4.EmployedOrSelfEmployed);
        EmploymentHistoryFilter notEmployedLastPeriod = new EmploymentHistoryFilter(Les_c4.NotEmployed);

        // Entering employment transition rate: among those NE last period, share that are E now
        CrossSection.Integer personsNotEmpToEmp = new CrossSection.Integer(model.getPersons(), Person.class, "getEmployed", true);
        personsNotEmpToEmp.setFilter(notEmployedLastPeriod);
        // Entering not-employed transition rate: among those E last period, share that are NE now
        CrossSection.Integer personsEmpToNotEmp = new CrossSection.Integer(model.getPersons(), Person.class, "getNonwork", true);
        personsEmpToNotEmp.setFilter(employedLastPeriod);

        MeanArrayFunction notEmpToEmpFn = new MeanArrayFunction(personsNotEmpToEmp);
        notEmpToEmpFn.applyFunction();
        setNotEmpToEmp(notEmpToEmpFn.getDoubleValue(IDoubleSource.Variables.Default));

        MeanArrayFunction empToNotEmpFn = new MeanArrayFunction(personsEmpToNotEmp);
        empToNotEmpFn.applyFunction();
        setEmpToNotEmp(empToNotEmpFn.getDoubleValue(IDoubleSource.Variables.Default));

        // Working-age adults (16-64) employment and unemployment proportions
        AgeGroupCSfilter workingAgeFilter = new AgeGroupCSfilter(16, 64);

        CrossSection.Integer personsEmployed = new CrossSection.Integer(model.getPersons(), Person.class, "getEmployed", true);
        CrossSection.Integer personsUnemployed = new CrossSection.Integer(model.getPersons(), Person.class, "getNonwork", true);

        personsEmployed.setFilter(workingAgeFilter);
        personsUnemployed.setFilter(workingAgeFilter);

        MeanArrayFunction isEmployed = new MeanArrayFunction(personsEmployed);
        isEmployed.applyFunction();
        setPropEmployed(isEmployed.getDoubleValue(IDoubleSource.Variables.Default));

        MeanArrayFunction isUnemployed = new MeanArrayFunction(personsUnemployed);
        isUnemployed.applyFunction();
        setPropUnemployed(isUnemployed.getDoubleValue(IDoubleSource.Variables.Default));
    }
}
