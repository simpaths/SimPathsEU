package simpaths.data.statistics;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import microsim.data.db.PanelEntityKey;
import simpaths.data.Parameters;
import simpaths.data.filters.FertileFilter;
import simpaths.model.BenefitUnit;
import simpaths.model.Person;
import simpaths.model.SimPathsModel;
import simpaths.model.enums.Dcpst;
import simpaths.model.enums.Indicator;
import simpaths.model.enums.Les_c4;
import simpaths.model.enums.Occupancy;
import simpaths.model.enums.OccupancyExtended;
import simpaths.model.enums.TargetShares;
import simpaths.model.enums.TimeSeriesVariable;

import java.util.Map;

/**
 * Alignment statistics. One row per simulated year, exported to
 * {@code AlignmentStatistics.csv}: the alignment adjustment factors together with the
 * simulated and target shares they are calibrated against.
 *
 * <p>Formerly {@code AlignmentAdjustmentFactors}, exported as
 * {@code AlignmentAdjustmentFactors1.csv} - the trailing digit was the entity id, not
 * part of the name.
 */
@Entity
public class AlignmentStatistics {

    @Id
    private PanelEntityKey key = new PanelEntityKey(1L);

    @Column(name = "partnership_adj_factor")
    private double alignPartnerAdj;

    @Column(name = "share_cohabiting_sim")
    private double alignPartnerSimShare;

    @Column(name = "share_cohabiting_tgt")
    private double alignPartnerTargetShare;

    @Column(name = "fertility_adj_factor")
    private double alignFertAdj;

    @Column(name = "fertiilty_rate_sim")
    private double alignFertRateSim;

    @Column(name = "fertiilty_rate_tgt")
    private double alignFertRateTarget;

    @Column(name = "retirement_adj_factor")
    private double alignRtrdAdj;

    @Column(name = "disability_adj_factor")
    private double alignDsblAdj;

    @Column(name = "retirement_share_sim")
    private double alignRtrdSimShare;

    @Column(name = "retirement_share_tgt")
    private double alignRtrdTgtShare;

    @Column(name = "disability_share_sim")
    private double alignDsblSimShare;

    @Column(name = "disability_share_tgt")
    private double alignDsblTgtShare;

    @Column(name = "in_school_adj_factor")
    private double alignInSchoolAdj;

    @Column(name = "in_school_share_sim")
    private double alignInSchoolSimShare;

    @Column(name = "in_school_share_tgt")
    private double alignInSchoolTgtShare;

    @Column(name = "utility_adj_factor_smales")
    private double alignUtilAdjSingleM;

    @Column(name = "utility_adj_factor_sfemales")
    private double alignUtilAdjSingleF;

    @Column(name = "utility_adj_factor_couples")
    private double alignUtilAdjCouple;

    @Column(name = "utility_adj_factor_ac_male")
    private double alignUtilAdjACM;

    @Column(name = "utility_adj_factor_ac_female")
    private double alignUtilAdjACF;

    @Column(name = "utility_adj_factor_male_with_dep")
    private double alignUtilAdjMWithDep;

    @Column(name = "utility_adj_factor_female_with_dep")
    private double alignUtilAdjFWithDep;

    @Column(name = "employed_share_sim_smales")
    private double alignEmpSimSingleMShare;

    @Column(name = "employed_share_tgt_smales")
    private double alignEmpTgtSingleMShare;

    @Column(name = "employed_share_sim_sfemales")
    private double alignEmpSimSingleFShare;

    @Column(name = "employed_share_tgt_sfemales")
    private double alignEmpTgtSingleFShare;

    @Column(name = "employed_share_sim_couples")
    private double alignEmpSimCouplesShare;

    @Column(name = "employed_share_tgt_couples")
    private double alignEmpTgtCouplesShare;

    @Column(name = "employed_share_sim_ac_male")
    private double alignEmpSimACMShare;

    @Column(name = "employed_share_tgt_ac_male")
    private double alignEmpTgtACMShare;

    @Column(name = "employed_share_sim_ac_female")
    private double alignEmpSimACFShare;

    @Column(name = "employed_share_tgt_ac_female")
    private double alignEmpTgtACFShare;

    @Column(name = "employed_share_sim_male_with_dep")
    private double alignEmpSimMWithDepShare;

    @Column(name = "employed_share_tgt_male_with_dep")
    private double alignEmpTgtMWithDepShare;

    @Column(name = "employed_share_sim_female_with_dep")
    private double alignEmpSimFWithDepShare;

    @Column(name = "employed_share_tgt_female_with_dep")
    private double alignEmpTgtFWithDepShare;

    public double getPartnershipAdjustmentFactor() {
        return alignPartnerAdj;
    }

    public void setPartnershipAdjustmentFactor(double alignPartnerAdj) {
        this.alignPartnerAdj = alignPartnerAdj;
    }

    public double getFertilityAdjustmentFactor() {
        return alignFertAdj;
    }

    public void setFertilityAdjustmentFactor(double factor) {
        this.alignFertAdj = factor;
    }

    public double getRetirementAdjustmentFactor() {
        return alignRtrdAdj;
    }

    public void setRetirementAdjustmentFactor(double alignRtrdAdj) {
        this.alignRtrdAdj = alignRtrdAdj;
    }

    public double getDisabilityAdjustmentFactor() {
        return alignDsblAdj;
    }

    public void setDisabilityAdjustmentFactor(double alignDsblAdj) {
        this.alignDsblAdj = alignDsblAdj;
    }

    public double getInSchoolAdjustmentFactor() {
        return alignInSchoolAdj;
    }

    public void setInSchoolAdjustmentFactor(double alignInSchoolAdj) {
        this.alignInSchoolAdj = alignInSchoolAdj;
    }

    public double getRetirementShareSimulated() { return alignRtrdSimShare; }

    public void setRetirementShareSimulated(double alignRtrdSimShare) { this.alignRtrdSimShare = alignRtrdSimShare; }

    public double getRetirementShareTarget() { return alignRtrdTgtShare; }

    public void setRetirementShareTarget(double alignRtrdTgtShare) { this.alignRtrdTgtShare = alignRtrdTgtShare; }

    public double getDisabilityShareSimulated() { return alignDsblSimShare; }

    public void setDisabilityShareSimulated(double alignDsblSimShare) { this.alignDsblSimShare = alignDsblSimShare; }

    public double getDisabilityShareTarget() { return alignDsblTgtShare; }

    public void setDisabilityShareTarget(double alignDsblTgtShare) { this.alignDsblTgtShare = alignDsblTgtShare; }

    public double getInSchoolShareSimulated() { return alignInSchoolSimShare; }

    public void setInSchoolShareSimulated(double alignInSchoolSimShare) { this.alignInSchoolSimShare = alignInSchoolSimShare; }

    public double getInSchoolShareTarget() { return alignInSchoolTgtShare; }

    public void setInSchoolShareTarget(double alignInSchoolTgtShare) { this.alignInSchoolTgtShare = alignInSchoolTgtShare; }

    public double getUtilityAdjustmentFactorSmales() {
        return alignUtilAdjSingleM;
    }

    public void setUtilityAdjustmentFactorSmales(double alignUtilAdjSingleM) {
        this.alignUtilAdjSingleM = alignUtilAdjSingleM;
    }

    public double getUtilityAdjustmentFactorSfemales() {
        return alignUtilAdjSingleF;
    }

    public void setUtilityAdjustmentFactorSfemales(double alignUtilAdjSingleF) {
        this.alignUtilAdjSingleF = alignUtilAdjSingleF;
    }

    public double getUtilityAdjustmentFactorCouples() {
        return alignUtilAdjCouple;
    }

    public double getUtilityAdjustmentFactorACMale() {
        return alignUtilAdjACM;
    }

    public double getUtilityAdjustmentFactorACFemale() {
        return alignUtilAdjACF;
    }

    public double getUtilityAdjustmentFactorMaleWithDep() {
        return alignUtilAdjMWithDep;
    }

    public double getUtilityAdjustmentFactorFemaleWithDep() {
        return alignUtilAdjFWithDep;
    }

    public void setUtilityAdjustmentFactorCouples(double alignUtilAdjCouple) {
        this.alignUtilAdjCouple = alignUtilAdjCouple;
    }

    public void setUtilityAdjustmentFactorACMale(double alignUtilAdjACM) {
        this.alignUtilAdjACM = alignUtilAdjACM;
    }

    public void setUtilityAdjustmentFactorACFemale(double alignUtilAdjACF) {
        this.alignUtilAdjACF = alignUtilAdjACF;
    }

    public void setUtilityAdjustmentFactorMaleWithDep(double alignUtilAdjMWithDep) {
        this.alignUtilAdjMWithDep = alignUtilAdjMWithDep;
    }

    public void setUtilityAdjustmentFactorFemaleWithDep(double alignUtilAdjFWithDep) {
        this.alignUtilAdjFWithDep = alignUtilAdjFWithDep;
    }

    public double getShareCohabitingSimulated() {return alignPartnerSimShare;}

    public void setShareCohabitingSimulated(double alignPartnerSimShare) { this.alignPartnerSimShare = alignPartnerSimShare; }

    public double getFertilityRateSimulated() {
        return alignFertRateSim;
    }

    public void setFertilityRateSimulated(double alignFertRateSim) {
        this.alignFertRateSim = alignFertRateSim;
    }

    public double getFertilityRateTarget() {
        return alignFertRateTarget;
    }

    public void setFertilityRateTarget(double alignFertRateTarget) {
        this.alignFertRateTarget = alignFertRateTarget;
    }

    public double getShareCohabitingTarget() {
        return alignPartnerTargetShare;
    }

    public void setShareCohabitingTarget(double alignPartnerTargetShare) {
        this.alignPartnerTargetShare = alignPartnerTargetShare;
    }

    // employed share getters/setters
    public double getEmployedShareSimSingleMales() { return alignEmpSimSingleMShare; }
    public void setEmployedShareSimSingleMales(double v) { this.alignEmpSimSingleMShare = v; }
    public double getEmployedShareTgtSingleMales() { return alignEmpTgtSingleMShare; }
    public void setEmployedShareTgtSingleMales(double v) { this.alignEmpTgtSingleMShare = v; }

    public double getEmployedShareSimSingleFemales() { return alignEmpSimSingleFShare; }
    public void setEmployedShareSimSingleFemales(double v) { this.alignEmpSimSingleFShare = v; }
    public double getEmployedShareTgtSingleFemales() { return alignEmpTgtSingleFShare; }
    public void setEmployedShareTgtSingleFemales(double v) { this.alignEmpTgtSingleFShare = v; }

    public double getEmployedShareSimCouples() { return alignEmpSimCouplesShare; }
    public void setEmployedShareSimCouples(double v) { this.alignEmpSimCouplesShare = v; }
    public double getEmployedShareTgtCouples() { return alignEmpTgtCouplesShare; }
    public void setEmployedShareTgtCouples(double v) { this.alignEmpTgtCouplesShare = v; }

    public double getEmployedShareSimACMale() { return alignEmpSimACMShare; }
    public void setEmployedShareSimACMale(double v) { this.alignEmpSimACMShare = v; }
    public double getEmployedShareTgtACMale() { return alignEmpTgtACMShare; }
    public void setEmployedShareTgtACMale(double v) { this.alignEmpTgtACMShare = v; }

    public double getEmployedShareSimACFemale() { return alignEmpSimACFShare; }
    public void setEmployedShareSimACFemale(double v) { this.alignEmpSimACFShare = v; }
    public double getEmployedShareTgtACFemale() { return alignEmpTgtACFShare; }
    public void setEmployedShareTgtACFemale(double v) { this.alignEmpTgtACFShare = v; }

    public double getEmployedShareSimMaleWithDep() { return alignEmpSimMWithDepShare; }
    public void setEmployedShareSimMaleWithDep(double v) { this.alignEmpSimMWithDepShare = v; }
    public double getEmployedShareTgtMaleWithDep() { return alignEmpTgtMWithDepShare; }
    public void setEmployedShareTgtMaleWithDep(double v) { this.alignEmpTgtMWithDepShare = v; }

    public double getEmployedShareSimFemaleWithDep() { return alignEmpSimFWithDepShare; }
    public void setEmployedShareSimFemaleWithDep(double v) { this.alignEmpSimFWithDepShare = v; }
    public double getEmployedShareTgtFemaleWithDep() { return alignEmpTgtFWithDepShare; }
    public void setEmployedShareTgtFemaleWithDep(double v) { this.alignEmpTgtFWithDepShare = v; }

    public void update(SimPathsModel model) {

        // The collector fires AFTER the model's yearlySchedule (ordering 1 > 0),
        // and UpdateYear (year++) is the last step in that schedule.
        // So model.getYear() here is already the NEXT year.
        // Use model.getYear()-1 to read the year that was just processed.
        int processedYear = model.getYear() - 1;

        // cohabitation
        double val = model.getPartnershipAdjustment(processedYear);
        setPartnershipAdjustmentFactor(val);
        long numPersonsWhoCanHavePartner = model.getPersons().stream()
                .filter(person -> person.getDag() >= Parameters.MIN_AGE_COHABITATION)
                .count();
        long numPersonsPartnered = model.getPersons().stream()
                .filter(person -> (person.getDcpst().equals(Dcpst.Partnered)))
                .count();
        val = (numPersonsWhoCanHavePartner > 0) ? (double) numPersonsPartnered / numPersonsWhoCanHavePartner : 0.0;
        setShareCohabitingSimulated(val);
        setShareCohabitingTarget(Parameters.getTargetShare(processedYear, TargetShares.Partnership));

        // fertility
        val = model.getFertilityAdjustment(processedYear);
        setFertilityAdjustmentFactor(val);
        FertileFilter filter = new FertileFilter();
        long numFertilePersons = model.getPersons().stream()
                .filter(person -> filter.evaluate(person))
                .count();
        long numBirths = model.getPersons().stream()
                .filter(person -> (person.getDag() < 1))
                .count();
        val = (numFertilePersons > 0) ? (double) numBirths / numFertilePersons : 0.0;
        setFertilityRateSimulated(val);
        setFertilityRateTarget(Parameters.getFertilityRateByYear(processedYear));

        // retirement
        setRetirementAdjustmentFactor(model.getRetirementAdjustment(processedYear));
        long numWithLes = model.getPersons().stream()
                .filter(person -> person.getLes_c4() != null)
                .count();
        long numRetired = model.getPersons().stream()
                .filter(person -> Les_c4.Retired.equals(person.getLes_c4()))
                .count();
        val = (numWithLes > 0) ? (double) numRetired / numWithLes : 0.0;
        setRetirementShareSimulated(val);
        setRetirementShareTarget(Parameters.getTargetShare(processedYear, TargetShares.Retirement));

        // disability
        setDisabilityAdjustmentFactor(model.getDisabilityAdjustment(processedYear));
        long numWithDlltsd = model.getPersons().stream()
                .filter(person -> person.getDlltsd() != null)
                .count();
        long numDisabled = model.getPersons().stream()
                .filter(person -> Indicator.True.equals(person.getDlltsd()))
                .count();
        val = (numWithDlltsd > 0) ? (double) numDisabled / numWithDlltsd : 0.0;
        setDisabilityShareSimulated(val);
        setDisabilityShareTarget(Parameters.getTargetShare(processedYear, TargetShares.Disability));

        // inSchool
        setInSchoolAdjustmentFactor(model.getInSchoolAdjustment(processedYear));
        long numPersonsInAgeRange = model.getPersons().stream()
                .filter(person -> person.getDag() >= 16 && person.getDag() <= 29 && person.getLes_c4() != null)
                .count();
        long numStudents = model.getPersons().stream()
                .filter(person -> person.getDag() >= 16 && person.getDag() <= 29
                        && person.getLes_c4() != null
                        && Les_c4.Student.equals(person.getLes_c4()))
                .count();
        val = (numPersonsInAgeRange > 0) ? (double) numStudents / numPersonsInAgeRange : 0.0;
        setInSchoolShareSimulated(val);
        setInSchoolShareTarget(Parameters.getTargetShare(processedYear, TargetShares.Students));

        // utility — maps may be null if alignment_adjustment_factors.xlsx sheets are absent
        setUtilityAdjustmentFactorSmales(safeGetTimeSeriesValue(processedYear, TimeSeriesVariable.UtilityAdjustmentSingleMales));
        setUtilityAdjustmentFactorSfemales(safeGetTimeSeriesValue(processedYear, TimeSeriesVariable.UtilityAdjustmentSingleFemales));
        setUtilityAdjustmentFactorCouples(safeGetTimeSeriesValue(processedYear, TimeSeriesVariable.UtilityAdjustmentCouples));
        setUtilityAdjustmentFactorACMale(safeGetTimeSeriesValue(processedYear, TimeSeriesVariable.UtilityAdjustmentACMales));
        setUtilityAdjustmentFactorACFemale(safeGetTimeSeriesValue(processedYear, TimeSeriesVariable.UtilityAdjustmentACFemales));
        setUtilityAdjustmentFactorMaleWithDep(safeGetTimeSeriesValue(processedYear, TimeSeriesVariable.UtilityAdjustmentMaleWithDep));
        setUtilityAdjustmentFactorFemaleWithDep(safeGetTimeSeriesValue(processedYear, TimeSeriesVariable.UtilityAdjustmentFemaleWithDep));

        // employment shares by occupancy type
        // accumulate counts and fractional employment in a single pass over benefit units
        Map<OccupancyExtended, double[]> empStats = new java.util.EnumMap<>(OccupancyExtended.class);
        for (OccupancyExtended occ : OccupancyExtended.values()) {
            empStats.put(occ, new double[2]); // [0] = count, [1] = sum of fracEmployed
        }
        for (BenefitUnit bu : model.getBenefitUnits()) {
            OccupancyExtended ext = classifyBenefitUnit(bu);
            if (ext != null) {
                double[] stats = empStats.get(ext);
                stats[0]++;
                stats[1] += bu.fracEmployed();
            }
        }
        setEmployedShareSimSingleMales(computeShare(empStats.get(OccupancyExtended.Single_Male)));
        setEmployedShareTgtSingleMales(Parameters.getTargetShare(processedYear, TargetShares.EmploymentSingleMales));
        setEmployedShareSimSingleFemales(computeShare(empStats.get(OccupancyExtended.Single_Female)));
        setEmployedShareTgtSingleFemales(Parameters.getTargetShare(processedYear, TargetShares.EmploymentSingleFemales));
        setEmployedShareSimCouples(computeShare(empStats.get(OccupancyExtended.Couple)));
        setEmployedShareTgtCouples(Parameters.getTargetShare(processedYear, TargetShares.EmploymentCouples));
        setEmployedShareSimACMale(computeShare(empStats.get(OccupancyExtended.Male_AC)));
        setEmployedShareTgtACMale(Parameters.getTargetShare(processedYear, TargetShares.EmploymentMaleAdultChildren));
        setEmployedShareSimACFemale(computeShare(empStats.get(OccupancyExtended.Female_AC)));
        setEmployedShareTgtACFemale(Parameters.getTargetShare(processedYear, TargetShares.EmploymentFemaleAdultChildren));
        setEmployedShareSimMaleWithDep(computeShare(empStats.get(OccupancyExtended.Male_With_Dependent)));
        setEmployedShareTgtMaleWithDep(Parameters.getTargetShare(processedYear, TargetShares.EmploymentMaleWithDependent));
        setEmployedShareSimFemaleWithDep(computeShare(empStats.get(OccupancyExtended.Female_With_Dependent)));
        setEmployedShareTgtFemaleWithDep(Parameters.getTargetShare(processedYear, TargetShares.EmploymentFemaleWithDependent));

    }

    /**
     * Classifies a BenefitUnit into an OccupancyExtended subgroup.
     * Mirrors the matchesSubgroup logic used in ActivityAlignmentV2.
     * Returns null if the unit does not fall into any at-risk-of-work subgroup.
     */
    private static OccupancyExtended classifyBenefitUnit(BenefitUnit bu) {
        Occupancy occ = bu.getOccupancy();
        Person male = bu.getMale();
        Person female = bu.getFemale();
        boolean maleAtRisk = (male != null) && male.atRiskOfWork();
        boolean femaleAtRisk = (female != null) && female.atRiskOfWork();

        if (occ == Occupancy.Couple) {
            if (maleAtRisk && femaleAtRisk) return OccupancyExtended.Couple;
            if (maleAtRisk) return OccupancyExtended.Male_With_Dependent;
            if (femaleAtRisk) return OccupancyExtended.Female_With_Dependent;
            return null;
        } else if (occ == Occupancy.Single_Male && male != null) {
            return (male.getAdultChildFlag() == 1) ? OccupancyExtended.Male_AC : OccupancyExtended.Single_Male;
        } else if (occ == Occupancy.Single_Female && female != null) {
            return (female.getAdultChildFlag() == 1) ? OccupancyExtended.Female_AC : OccupancyExtended.Single_Female;
        }
        return null;
    }

    private static double computeShare(double[] stats) {
        return (stats[0] > 0) ? stats[1] / stats[0] : 0.0;
    }

    /**
     * Safely reads a time series value, returning 0.0 if the underlying map is null
     * (e.g. when the corresponding sheet is absent from alignment_adjustment_factors.xlsx).
     */
    private static final java.util.Set<TimeSeriesVariable> reportedMissing = java.util.EnumSet.noneOf(TimeSeriesVariable.class);

    private static double safeGetTimeSeriesValue(int year, TimeSeriesVariable variable) {
        try {
            return Parameters.getTimeSeriesValue(year, variable);
        } catch (NullPointerException e) {
            if (reportedMissing.add(variable)) {
                System.out.println("WARNING: time series map for " + variable + " is null — "
                        + "corresponding sheet is missing from alignment_adjustment_factors.xlsx. Defaulting to 0.0.");
            }
            return 0.0;
        }
    }
}
