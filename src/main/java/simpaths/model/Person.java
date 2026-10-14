package simpaths.model;

import jakarta.persistence.*;
import microsim.agent.Weight;
import microsim.data.db.PanelEntityKey;
import microsim.engine.SimulationEngine;
import microsim.event.EventListener;
import microsim.statistics.IDoubleSource;
import microsim.statistics.IIntSource;
import microsim.statistics.Series;
import org.apache.commons.lang3.builder.EqualsBuilder;
import org.apache.commons.lang3.builder.HashCodeBuilder;
import org.apache.log4j.Logger;
import simpaths.data.ManagerRegressions;
import simpaths.data.MultiValEvent;
import simpaths.data.Parameters;
import simpaths.data.RegressionName;
import simpaths.data.filters.FertileFilter;
import simpaths.model.decisions.Axis;
import simpaths.model.decisions.DecisionParams;
import simpaths.model.enums.*;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.*;

import static simpaths.data.Parameters.*;

@Entity
public class Person implements EventListener, IDoubleSource, IIntSource, Weight, Comparable<Person> {

    @Transient private static Logger log = Logger.getLogger(Person.class);
    @Transient private final SimPathsModel model;
    @Transient public static long personIdCounter = 1L;			//Could perhaps initialise this to one above the max key number in initial population, in the same way that we pull the max Age information from the input files.

    // database keys
    @EmbeddedId @Column(unique = true, nullable = false) private final PanelEntityKey key;
    @ManyToOne(fetch = FetchType.EAGER, cascade = CascadeType.REFRESH)
    @JoinColumns({
            @JoinColumn(name = "buid", referencedColumnName = "id"),
            @JoinColumn(name = "butime", referencedColumnName = "simulation_time"),
            @JoinColumn(name = "burun", referencedColumnName = "simulation_run"),
            @JoinColumn(name = "prid", referencedColumnName = "working_id")
    }) private BenefitUnit benefitUnit;

    // identifiers
    private Long idPersOriginal;
    private Long idBuOriginal;
    private Long idHhOriginal;
    private Long idMother;
    private Long idFather;
    private Long idPartner;
    private Boolean demClonedFlag;
    private Boolean demBornInSimFlag; //Flag to keep track of newborns
    private Long statSeed;
    private Long idHh;
    private Long idBu;
    @Enumerated(EnumType.STRING) private SampleEntry demEnterSample;
    @Enumerated(EnumType.STRING) private SampleExit demExitSample = SampleExit.NotYet;  //entry to sample via international immigration

    @Column(name="immutable_mother_id")
    private Long idMotherImmutable;

    @Column(name="immutable_father_id")
    private Long idFatherImmutable;

    public Long getIdMotherImmutable() { return idMotherImmutable; }
    public Long getIdFatherImmutable() { return idFatherImmutable; }

    // person level variables
    private int demAge; //Age
    private Dcpst demPartnerStatus;
    @Enumerated(EnumType.STRING) private Indicator demAdultChildFlag;
    @Enumerated(EnumType.STRING) private Indicator demStaywparentsflag;
    @Transient private boolean ioFlag;         // true if a dummy person instantiated for IO decision solution
    @Enumerated(EnumType.STRING) private Gender demMaleFlag;             // gender
    @Enumerated(EnumType.STRING) private Education eduHighestC4;       //Education level
    @Transient private Education eduHighestC4L1;  //Lag(1) of education level
    @Enumerated(EnumType.STRING) private Education eduHighestMotherC4;      //Mother's education level
    @Enumerated(EnumType.STRING) private Education eduHighestFatherC4;      //Father's education level
    @Enumerated(EnumType.STRING) private Indicator eduSpellFlag;          // in continuous education
    @Enumerated(EnumType.STRING) private Indicator eduDedL1;          // in continuous education
    @Enumerated(EnumType.STRING) private Indicator eduReturnFlag;          // return to education
    @Enumerated(EnumType.STRING) private Les_c4 labC4;      //Activity (employment) status
    @Enumerated(EnumType.STRING) private Les_c7_covid labC7Covid; //Activity (employment) status used in the Covid-19 models
    @Enumerated(EnumType.STRING) private Les_c4 labC4L1;		//Lag(1) of activity_status
    @Transient private Les_c7_covid labC7CovidL1;     //Lag(1) of 7-category activity status
    private Integer labEmpNyear;                  //Work history in years (number of years in employment)
    @Enumerated(EnumType.STRING) private Indicator healthDsblLongtermFlag;	//Long-term sick or disabled if = 1
    @Transient private Indicator healthDsblLongtermFlagL1; //Lag(1) of long-term sick or disabled
    @Enumerated(EnumType.STRING) @Column(name="need_socare") private Indicator careNeedFlag;
    @Column(name="formal_socare_hrs") private Double careHrsFormalWeek;
    @Column(name="formal_socare_cost") private Double xCareFormalWeek;
    @Column(name="partner_socare_hrs") private Double careHrsFromPartnerWeek;
    @Column(name="parent_socare_hrs") private Double careHrsFromParentWeek;
    @Column(name="daughter_socare_hrs") private Double careHrsFromDaughterWeek;
    @Column(name="son_socare_hrs") private Double careHrsFromSonWeek;
    @Column(name="other_socare_hrs") private Double careHrsFromOtherWeek;
    private Boolean labWageOfferLowFlag;
    @Transient private Boolean labWageOfferLowFlagL1;
    @Transient private SocialCareReceipt careReceivedFlag;
    @Transient private Boolean careFormalFlag;
    @Transient private Boolean careFromPartnerFlag;
    @Transient private Boolean careFromDaughterFlag;
    @Transient private Boolean careFromSonFlag;
    @Transient private Boolean careFromOtherFlag;
    @Column(name="socare_provided_hrs") private Double careHrsProvidedWeek;
    @Enumerated(EnumType.STRING) @Column(name="socare_provided_to") private SocialCareProvision careProvidedFlag;
    @Transient private SocialCareProvision careProvidedFlagL1;
    @Transient private Indicator careNeedFlagL1;
    @Transient private Double careHrsFormalWeekL1;
    @Transient private Double careHrsFromPartnerWeekL1;
    @Transient private Double careHrsFromParentWeekL1;
    @Transient private Double careHrsFromDaughterWeekL1;
    @Transient private Double careHrsFromSonWeekL1;
    @Transient private Double careHrsFromOtherWeekL1;

    // partner lags
    @Transient private Dcpst demPartnerStatusL1;            // lag partnership status
    @Transient private Education eduDehspC4L1;     //Lag(1) of partner's education
    @Transient private Dhe healthPartnerSelfRatedL1;
    @Transient private Lesdf_c4 labStatusPartnerAndOwnC4L1;      //Lag(1) of own and partner's activity status
    @Transient private Long idPartnerL1;
    @Transient private HouseholdStatus demStatusHhL1;		//Lag(1) of household_status
    @Transient private Integer demAgePartnerDiffL1;        //Lag(1) of difference between ages of partners in union
    @Transient private Double yPersAndPartnerGrossDiffMonthL1;      //Lag(1) of difference between own and partner's gross personal non-benefit income

    @Enumerated(EnumType.STRING) private Indicator eduExitSampleFlag;    // year left education
    @Transient private Boolean demGiveBirthFlag;
    @Transient private Boolean labToRetire;
    @Transient private Boolean eduLeaveSchoolFlag;
    @Transient private Boolean demBePartnerFlag;
    @Transient private Boolean demAlignPartnerProcess;
    @Transient private Boolean demLeavePartnerFlag; // Used in partnership alignment process. Indicates that this person has found partner in a test run of union matching.
    private Double wgtCrossMainSurvey;
    @Column(name="dhm_ghq") private Boolean healthDhmGhq; //Psychological distress case-based
    @Transient private Boolean healthDhmGhqL1;
    @Transient private Dhe healthSelfRatedL1;
    @Enumerated(EnumType.STRING) private Dhe healthSelfRated;
    private Double healthWbScore0to36; //Psychological distress GHQ-12 Likert scale
    @Transient private Double healthWbScore0to36L1; //Lag(1) of dhm
    private Boolean wealthPrptyFlag; // Person is a homeowner, true / false
    @Transient private Boolean yBenReceivedFlagL1; // Lag(1) of whether person receives benefits
    @Transient private Boolean yBenReceivedFlag; // Does person receive benefits

    @Enumerated(EnumType.STRING) private Labour labHrsWorkEnumWeek;			//Number of hours of labour supplied each week
    //@Enumerated(EnumType.STRING) @Column(name="labour_categories_test") private Labour labourSupplyWeekly;

    @Transient private Labour labHrsWorkEnumWeekL1; // Lag(1) (previous year's value) of weekly labour supply
    private Integer labHrsWorkWeek;

//	Potential earnings is the gross hourly wage an individual can earn while working
//	and is estimated, for each individual, on the basis of observable characteristics as
//	age, education, civil status, number of children, etc. Hence, potential earnings
//	is a separate process in the simulation, and it is computed for every adult
//	individual in the simulated population, in each simulated period.
    private Double labWageHrly;		//Is hourly rate.  Initialised with value: ils_earns / (4.34 * lhw), where lhw is the weekly hours a person worked in EUROMOD input data
    private Double labWageHrlyL1; // Lag(1) of potentialHourlyEarnings
    // Pre-overlay regression wage of the current year (exp(wage regression), before the
    // macro/Ramsey multiplier and the experimental permanent wage shift). The wage-equation
    // AR(1) lag must propagate this, NOT the macro-multiplied wage, or the secular macro
    // trend is re-amplified by ~1/(1-rho) every year. See updateLaggedVariables.
    @Transient private Double labWageHrlyRegression;
    @Transient private Series.Double yearlyEquivalisedDisposableIncomeSeries;
    private Double xEquivYear;
    @Transient private Series.Double yearlyEquivalisedConsumptionSeries;
    private Double statSIndex;
    private Double statSIndexNormal;
    @Transient private LinkedHashMap<Integer, Double> sIndexYearMap;
    private Integer demPartnerNYear; //Number of years in partnership
    @Transient private Integer demPartnerNYearL1; //Lag(1) of number of years in partnership
    private Double yNonBenPersGrossMonth; // asinh of personal non-benefit income per month
    @Transient private Double yNonBenPersGrossMonthL1; //Lag(1) of gross personal non-benefit income
    private Double yPersDispMonth; // real personal monthly disposable income (from initial population)
    private Double yMiscPersGrossMonth; // asinh of non-employment non-benefit income per month (capital and pension)
    private Double yCapitalPersMonth; // asinh of capital income per month
    private Double yPensPersGrossMonth; // asinh of pension income per month
    @Transient private Double yCapitalPersMonthL1; //Lag(1) of ypncp
    @Transient private Double yCapitalPersMonthL2; //Lag(2) of capital income
    @Transient private Double yPensPersGrossMonthL1; //Lag(1) of pension income
    @Transient private Double yPensPersGrossMonthL2; //Lag(2) of pension income
    @Transient private Double yMiscPersGrossMonthL1; //Lag(1) of gross personal non-benefit non-employment income
    @Transient private Double yMiscPersGrossMonthL2; //Lag(2) of gross personal non-benefit non-employment income
    @Transient private Double yMiscPersGrossMonthL3; //Lag(3) of gross personal non-benefit non-employment income
    private Double yEmpPersGrossMonth;       // asinh transform of personal labour income per month
    @Transient private Double yEmpPersGrossMonthL1; //Lag(1) of gross personal employment income
    @Transient private Double yEmpPersGrossMonthL2; //Lag(2) of gross personal employment income
    @Transient private Double yEmpPersGrossMonthL3; //Lag(3) of gross personal employment income

    //For matching process
    @Transient private Double demAgeDiffDesired;
    @Transient private Double yWageDesired;
    @Transient private Integer demAgeGroup;

    //This is set to true at the point when individual leaves education and never reset. So if true, individual has not always been in continuous education.
    @Transient private Boolean eduLeftEduFlag;

    //This is set to true at the point when individual leaves partnership and never reset. So if true, individual has been / is in a partnership
    @Transient private Boolean demLeftPartnerFlag;
    @Transient private Integer labHrsWorkNewL1; // Define a variable to keep previous month's value of work hours to be used in the Covid-19 module
    @Transient private Double covidYLabGrossL1;
    @Transient private Indicator covidSEISSReceivedFlag = Indicator.False;
    @Transient private Double covidYLabGross;
    private Quintiles covidYLabGrossXt5;
    @Transient private Double labWageRegressRandomCompoponentEmp;
    @Transient private Double labWageRegressRandomCompoponentNotEmp;
    @Transient private Map<Labour, Integer> personContinuousHoursLabourSupplyMap = new EnumMap<>(Labour.class);

    // local variables interact with regression models
    @Transient private Integer i_demYear;
    @Transient private Region i_demRgn;
    @Transient private Dhhtp_c4 i_demCompHhC4L1;
    @Transient private Ydses_c5 i_yHhQuintilesC5;
    @Transient private Integer i_demNchildL1;
    @Transient private Integer i_demNchild;
    @Transient private Integer i_demNchild0to2L1;
    @Transient private Integer i_demNchild0to17;
    @Transient private Indicator i_demNChild0to2;
    @Transient private Dcpst i_demPartnerStatus;

    // innovations
    @Transient Innovations innovations;

    //TODO: Remove when no longer needed.  Used to calculate mean score of employment selection regression.
    @Transient public static Double statMScore;
    @Transient public static Double statFScore;
    @Transient public static Double countMale;
    @Transient public static Double countFemale;
    @Transient public static Double statInverseMillsRatioMaxM = Double.MIN_VALUE;
    @Transient public static Double statInverseMillsRatioMinM = Double.MAX_VALUE;
    @Transient public static Double statInverseMillsRatioMaxF = Double.MIN_VALUE;
    @Transient public static Double statInverseMillsRatioMinF = Double.MAX_VALUE;


    // ---------------------------------------------------------------------
    // Constructors
    // ---------------------------------------------------------------------
    public Person() {
        model = (SimPathsModel) SimulationEngine.getInstance().getManager(SimPathsModel.class.getCanonicalName());
        key = new PanelEntityKey();
    }

    public Person(long id) {
        model = (SimPathsModel) SimulationEngine.getInstance().getManager(SimPathsModel.class.getCanonicalName());
        key = new PanelEntityKey(id);
    }

    // used by expectations object when creating dummy person to interact with regression functions
    public Person(boolean regressionModel) {
        if (regressionModel) {
            model = null;
            key = null;
            setAllSocialCareVariablesToFalse();
        } else {
            throw new RuntimeException("Person constructor call not recognised");
        }
    }

    // used to create new people who enter the simulation during UpdateMaternityStatus
    // it is the “birth constructor” — used when the simulation generates a new child (e.g., during UpdateMaternityStatus)
    public Person(Gender gender, Person mother) {

        this(personIdCounter++, (long)(100000*mother.getFertilityRandomUniform2()));

        demEnterSample = SampleEntry.Birth;
        demMaleFlag = gender;
        idMother = mother.getId();
        eduHighestMotherC4 = mother.getDeh_c4();
        if (mother.getPartner()==null) {
            idFather = null;
            eduHighestFatherC4 = mother.getDeh_c4();
        } else {
            idFather = mother.getPartner().getId();
            eduHighestFatherC4 = mother.getPartner().getDeh_c4();
        }

        idMotherImmutable = idMother;        // set once
        idFatherImmutable = idFather;        // set once

        labEmpNyear = 0;
        yMiscPersGrossMonth = 0.0;
        yCapitalPersMonth = 0.0;
        yPensPersGrossMonth = 0.0;
        labWageHrly = Parameters.MIN_HOURLY_WAGE_RATE;
        healthDsblLongtermFlag = Indicator.False;
        setAllSocialCareVariablesToFalse();
        labWageOfferLowFlag = false;
        benefitUnit = mother.benefitUnit;
        idBu = benefitUnit.getId();
        demAge = 0;
        eduSpellFlag = Indicator.True;
        eduReturnFlag = Indicator.False;
        wgtCrossMainSurvey = mother.getWeight();			//Newborn has same weight as mother (the number of newborns will then be aligned in fertility alignment)
        healthSelfRated = Dhe.VeryGood;
        healthWbScore0to36 = 9.;			//Set to median for under 18's as a placeholder
        healthDhmGhq = false;
        eduHighestC4 = Education.NotAssigned;
        labC4 = Les_c4.Student;				//Set lag activity status as Student, i.e. in education from birth
        eduLeftEduFlag = false;
        labC7Covid = Les_c7_covid.Student;
        labHrsWorkEnumWeek = Labour.ZERO;			//Will be updated in Labour Market Module when the person stops being a student
        labHrsWorkWeek = getLabourSupplyWeekly().getHours(this);
        idHh = mother.getBenefitUnit().getHousehold().getId();
//		setDeviationFromMeanRetirementAge();			//This would normally be done within initialisation, but the line above has been commented out for reasons given...
        yearlyEquivalisedDisposableIncomeSeries = new Series.Double(this, DoublesVariables.EquivalisedIncomeYearly);
        yearlyEquivalisedConsumptionSeries = new Series.Double(this, DoublesVariables.EquivalisedConsumptionYearly);
        xEquivYear = 0.;
        sIndexYearMap = new LinkedHashMap<Integer, Double>();
        demBornInSimFlag = true;
        wealthPrptyFlag = false;
        yBenReceivedFlag = false;
        updateVariables(false);
    }

    // a "copy constructor" for persons: used by the cloneBenefitUnit method of the SimPathsModel object
    // used to generate clones both at population load (to un-weight data) and to generate international immigrants
    public Person (Person originalPerson, long statSeed, SampleEntry demEnterSample) {

        this(personIdCounter++, statSeed);
        switch (demEnterSample) {
            case ProcessedInputData -> {
                key.setId(originalPerson.getId());
                idPersOriginal = originalPerson.getIdOriginalPerson();
                idBuOriginal = originalPerson.getIdOriginalBU();
                idHhOriginal = originalPerson.getIdOriginalHH();
            }
            default -> {
                idPersOriginal = originalPerson.key.getId();
                idHhOriginal = originalPerson.benefitUnit.getHousehold().getId();
                idBuOriginal = originalPerson.benefitUnit.getId();
            }
        }

        // keep true ancestry
        this.idMotherImmutable = originalPerson.idMotherImmutable != null
                ? originalPerson.idMotherImmutable
                : originalPerson.idMother;   // fallback if legacy data
        this.idFatherImmutable = originalPerson.idFatherImmutable != null
                ? originalPerson.idFatherImmutable
                : originalPerson.idFather;   // fallback if legacy data

        this.demEnterSample = demEnterSample;

        demAge = originalPerson.demAge;
        demAgeGroup = originalPerson.demAgeGroup;
        demMaleFlag = originalPerson.demMaleFlag;
        eduHighestC4 = originalPerson.eduHighestC4;

        if (originalPerson.eduHighestC4L1 != null) { //If original person misses lagged level of education, assign current level of education
            eduHighestC4L1 = originalPerson.eduHighestC4L1;
        } else {
            eduHighestC4L1 = eduHighestC4;
        }

        eduHighestFatherC4 = originalPerson.eduHighestFatherC4;
        eduHighestMotherC4 = originalPerson.eduHighestMotherC4;
        eduDehspC4L1 = originalPerson.eduHighestC4L1;

        // set ded
        if (originalPerson.demAge < Parameters.MIN_AGE_TO_LEAVE_EDUCATION) { //If under age to leave education, set flag for being in education to true
            eduSpellFlag = Indicator.True;
        } else {
            eduSpellFlag = originalPerson.eduSpellFlag;
        }

        if (originalPerson.eduDedL1 != null) { //If original person misses lagged level of education, assign current level of education
            eduDedL1 = originalPerson.eduDedL1;
        } else {
            eduDedL1 = eduSpellFlag;
        }

        eduReturnFlag = originalPerson.eduReturnFlag;
        demPartnerNYear = Objects.requireNonNullElse(originalPerson.demPartnerNYear,0);
        demPartnerNYearL1 = Objects.requireNonNullElseGet(originalPerson.demPartnerNYearL1, () -> Math.max(0, this.demPartnerNYear - 1));
        demAgePartnerDiffL1 = originalPerson.demAgePartnerDiffL1;
        demStatusHhL1 = originalPerson.demStatusHhL1;
        if (originalPerson.labC4 != null) {
            labC4 = originalPerson.labC4;
        } else if (originalPerson.demAge < Parameters.MIN_AGE_TO_LEAVE_EDUCATION) {
            labC4 = Les_c4.Student;
        } else if (originalPerson.demAge > (int)Parameters.getTimeSeriesValue(model.getYear(), originalPerson.getDgn().toString(), TimeSeriesVariable.FixedRetirementAge)) {
            labC4 = Les_c4.Retired;
        } else if (originalPerson.getLabourSupplyWeekly() != null && originalPerson.getLabourSupplyWeekly().getHours(originalPerson) > 0) {
            labC4 = Les_c4.EmployedOrSelfEmployed;
        } else {
            labC4 = Les_c4.NotEmployed;
        }
        if (demAge < Parameters.MIN_AGE_TO_LEAVE_EDUCATION)
            eduLeftEduFlag = false;
        else if (demAge > Parameters.MAX_AGE_TO_STAY_IN_CONTINUOUS_EDUCATION)
            eduLeftEduFlag = true;
        else
            eduLeftEduFlag = (!Les_c4.Student.equals(labC4) || (Les_c4.Student.equals(labC4) && eduSpellFlag.equals(Indicator.False)));

        if (originalPerson.labC4L1 != null) { //If original persons misses lagged activity status, assign current activity status
            labC4L1 = originalPerson.labC4L1;
        } else {
            labC4L1 = labC4;
        }

        labC7Covid = originalPerson.labC7Covid;
        if (originalPerson.labC7CovidL1 != null) { //If original persons misses lagged activity status, assign current activity status
            labC7CovidL1 = originalPerson.labC7CovidL1;
        } else {
            labC7CovidL1 = labC7Covid;
        }

        labStatusPartnerAndOwnC4L1 = originalPerson.labStatusPartnerAndOwnC4L1;
        demPartnerStatusL1 = originalPerson.demPartnerStatusL1;
        yNonBenPersGrossMonth = originalPerson.getYpnbihs_dv();
        yNonBenPersGrossMonthL1 = originalPerson.yNonBenPersGrossMonthL1;
        yMiscPersGrossMonth = Objects.requireNonNullElse(originalPerson.yMiscPersGrossMonth, 0.0);
        yEmpPersGrossMonth = originalPerson.getYplgrs_dv();
        yEmpPersGrossMonthL1 = originalPerson.yEmpPersGrossMonthL1;
        yEmpPersGrossMonthL2 = originalPerson.yEmpPersGrossMonthL2;
        yEmpPersGrossMonthL3 = originalPerson.yEmpPersGrossMonthL3;
        yPersAndPartnerGrossDiffMonthL1 = originalPerson.yPersAndPartnerGrossDiffMonthL1;
        yCapitalPersMonth = Objects.requireNonNullElse(originalPerson.yCapitalPersMonth,0.0);
        yCapitalPersMonthL1 = originalPerson.yCapitalPersMonthL1;
        yCapitalPersMonthL2 = originalPerson.yCapitalPersMonthL2;
        yPensPersGrossMonth = Objects.requireNonNullElse(originalPerson.yPensPersGrossMonth, 0.0);
        yPensPersGrossMonthL1 = originalPerson.yPensPersGrossMonthL1;
        yPensPersGrossMonthL2 = originalPerson.yPensPersGrossMonthL2;

        labEmpNyear = Objects.requireNonNullElseGet(originalPerson.labEmpNyear, () -> ((Les_c4.EmployedOrSelfEmployed.equals(labC4)) ? 1 : 0));
        healthDsblLongtermFlag = originalPerson.healthDsblLongtermFlag;
        healthDsblLongtermFlagL1 = originalPerson.healthDsblLongtermFlagL1;
        careNeedFlag = Objects.requireNonNullElse(originalPerson.careNeedFlag, Indicator.False);
        careHrsFormalWeek = Objects.requireNonNullElse(originalPerson.careHrsFormalWeek, 0.0);
        xCareFormalWeek = Objects.requireNonNullElse(originalPerson.xCareFormalWeek, 0.0);
        careHrsFromPartnerWeek = Objects.requireNonNullElse(originalPerson.careHrsFromPartnerWeek, 0.0);
        careHrsFromParentWeek = Objects.requireNonNullElse(originalPerson.careHrsFromParentWeek, 0.0);
        careHrsFromDaughterWeek = Objects.requireNonNullElse(originalPerson.careHrsFromDaughterWeek, 0.0);
        careHrsFromSonWeek = Objects.requireNonNullElse(originalPerson.careHrsFromSonWeek, 0.0);
        careHrsFromOtherWeek = Objects.requireNonNullElse(originalPerson.careHrsFromOtherWeek, 0.0);
        careFormalFlag = Objects.requireNonNullElseGet(originalPerson.careFormalFlag, () -> (careHrsFormalWeek > 0.0));
        careFromPartnerFlag = Objects.requireNonNullElseGet(originalPerson.careFromPartnerFlag, () -> (careHrsFromPartnerWeek > 0.0));
        careFromDaughterFlag = Objects.requireNonNullElseGet(originalPerson.careFromDaughterFlag, () -> (careHrsFromDaughterWeek > 0.0));
        careFromSonFlag = Objects.requireNonNullElseGet(originalPerson.careFromSonFlag, () -> (careHrsFromSonWeek > 0.0));
        careFromOtherFlag = Objects.requireNonNullElseGet(originalPerson.careFromOtherFlag, () -> (careHrsFromOtherWeek > 0.0));
        if (originalPerson.careReceivedFlag!=null)
            careReceivedFlag = originalPerson.careReceivedFlag;
        else {
            if (careFormalFlag) {
                if (careFromPartnerFlag || careFromDaughterFlag || careFromSonFlag || careFromOtherFlag)
                    careReceivedFlag = SocialCareReceipt.Mixed;
                else
                    careReceivedFlag = SocialCareReceipt.Formal;
            } else {
                if (careFromPartnerFlag || careFromDaughterFlag || careFromSonFlag || careFromOtherFlag)
                    careReceivedFlag = SocialCareReceipt.Informal;
                else
                    careReceivedFlag = SocialCareReceipt.None;
            }
        }

        careHrsProvidedWeek = Objects.requireNonNullElse(originalPerson.careHrsProvidedWeek, 0.0);
        careProvidedFlag = Objects.requireNonNullElseGet(originalPerson.careProvidedFlag, () ->
                (careHrsProvidedWeek > 0.01) ? SocialCareProvision.OnlyOther : SocialCareProvision.None);

        careNeedFlagL1 = Objects.requireNonNullElse(originalPerson.careNeedFlagL1, careNeedFlag);
        careHrsFormalWeekL1 = Objects.requireNonNullElse(originalPerson.careHrsFormalWeekL1, careHrsFormalWeek);
        careHrsFromPartnerWeekL1 = Objects.requireNonNullElse(originalPerson.careHrsFromPartnerWeekL1, careHrsFromPartnerWeek);
        careHrsFromDaughterWeekL1 = Objects.requireNonNullElse(originalPerson.careHrsFromDaughterWeekL1, careHrsFromDaughterWeek);
        careHrsFromSonWeekL1 = Objects.requireNonNullElse(originalPerson.careHrsFromSonWeekL1, careHrsFromSonWeek);
        careHrsFromOtherWeekL1 = Objects.requireNonNullElse(originalPerson.careHrsFromOtherWeekL1, careHrsFromOtherWeek);
        careProvidedFlagL1 = Objects.requireNonNullElse(originalPerson.careProvidedFlagL1, careProvidedFlag);

        labWageOfferLowFlag = originalPerson.labWageOfferLowFlag;
        labWageOfferLowFlagL1 = originalPerson.labWageOfferLowFlagL1;
        eduExitSampleFlag = originalPerson.eduExitSampleFlag;
        demGiveBirthFlag = originalPerson.demGiveBirthFlag;
        eduLeaveSchoolFlag = originalPerson.eduLeaveSchoolFlag;
        wgtCrossMainSurvey = originalPerson.wgtCrossMainSurvey;
        healthSelfRated = originalPerson.healthSelfRated;
        healthWbScore0to36 = originalPerson.healthWbScore0to36;

        if (originalPerson.healthSelfRatedL1 != null) { //If original person misses lagged level of health, assign current level of health as lagged value
            healthSelfRatedL1 = originalPerson.healthSelfRatedL1;
        } else {
            healthSelfRatedL1 = originalPerson.healthSelfRated;
        }

        if (originalPerson.healthWbScore0to36L1 != null) {
            healthWbScore0to36L1 = originalPerson.healthWbScore0to36L1;
        } else {
            healthWbScore0to36L1 = originalPerson.healthWbScore0to36;
        }

        healthDhmGhq = Objects.requireNonNullElse(originalPerson.healthDhmGhq, false);
        healthDhmGhqL1 = Objects.requireNonNullElse(originalPerson.healthDhmGhqL1, healthDhmGhq);

        if (originalPerson.labHrsWorkEnumWeekL1 != null) {
            labHrsWorkEnumWeekL1 = originalPerson.labHrsWorkEnumWeekL1;
        } else {
            labHrsWorkEnumWeekL1 = originalPerson.getLabourSupplyWeekly();
        }

        healthPartnerSelfRatedL1 = originalPerson.healthPartnerSelfRatedL1;
        labHrsWorkWeek = originalPerson.labHrsWorkWeek;
        labHrsWorkEnumWeek = originalPerson.getLabourSupplyWeekly();
        double[] sampleDifferentials = setMarriageTargets();
        demAgeDiffDesired = Objects.requireNonNullElseGet(originalPerson.demAgeDiffDesired, () -> sampleDifferentials[0]);
        yWageDesired = Objects.requireNonNullElseGet(originalPerson.yWageDesired, () -> sampleDifferentials[1]);

        statMScore = originalPerson.statMScore;
        statFScore = originalPerson.statFScore;
        countMale = originalPerson.countMale;
        countFemale = originalPerson.countFemale;
        statInverseMillsRatioMaxM = originalPerson.statInverseMillsRatioMaxM;
        statInverseMillsRatioMinM  = originalPerson.statInverseMillsRatioMinM;
        statInverseMillsRatioMaxF = originalPerson.statInverseMillsRatioMaxF;
        statInverseMillsRatioMinF = originalPerson.statInverseMillsRatioMinF;

        demAdultChildFlag = originalPerson.demAdultChildFlag;
        yearlyEquivalisedDisposableIncomeSeries = new Series.Double(this, DoublesVariables.EquivalisedIncomeYearly);
        yearlyEquivalisedConsumptionSeries = new Series.Double(this, DoublesVariables.EquivalisedConsumptionYearly);
        xEquivYear = originalPerson.xEquivYear;
        sIndexYearMap = new LinkedHashMap<Integer, Double>();
        wealthPrptyFlag = originalPerson.wealthPrptyFlag;
        yBenReceivedFlag = originalPerson.yBenReceivedFlag;
        yBenReceivedFlagL1 = originalPerson.yBenReceivedFlagL1;

        if (originalPerson.labWageHrly > Parameters.MIN_HOURLY_WAGE_RATE) {
            labWageHrly = Math.min(Parameters.MAX_HOURLY_WAGE_RATE, Math.max(Parameters.MIN_HOURLY_WAGE_RATE, originalPerson.labWageHrly));
        } else {
            labWageHrly = -9.0;
        }
        if (originalPerson.labWageHrlyL1!=null && originalPerson.labWageHrlyL1>Parameters.MIN_HOURLY_WAGE_RATE) {
            labWageHrlyL1 = Math.min(Parameters.MAX_HOURLY_WAGE_RATE, Math.max(Parameters.MIN_HOURLY_WAGE_RATE, originalPerson.labWageHrlyL1));
        } else {
            labWageHrlyL1 = labWageHrly;
        }
        labWageHrlyRegression = (originalPerson.labWageHrlyRegression != null) ? originalPerson.labWageHrlyRegression : labWageHrlyL1;
    }

    // used by other constructors
    public Person(Long id, long statSeed) {
        super();
        key = new PanelEntityKey(id);
        model = (SimPathsModel) SimulationEngine.getInstance().getManager(SimPathsModel.class.getCanonicalName());
        demClonedFlag = false;

        // initialise random draws
        this.statSeed = statSeed;
        innovations = new Innovations(32, 1, 1, statSeed);

        //Draw desired age and wage differential for parametric partnership formation for people above age to get married:
        double[] sampleDifferentials = setMarriageTargets();
        demAgeDiffDesired = sampleDifferentials[0];
        yWageDesired = sampleDifferentials[1];
    }


    // ---------------------------------------------------------------------
    // Initialisation methods
    // ---------------------------------------------------------------------
    public void cloneCleanup() {

        if (labWageHrly < Parameters.MIN_HOURLY_WAGE_RATE) {
            updateFullTimeHourlyEarnings();
            if (labWageHrlyL1 < Parameters.MIN_HOURLY_WAGE_RATE)
                labWageHrlyL1 = labWageHrly;
        }
    }

    private double[] setMarriageTargets() {

        double[] sampleDifferentials = new double[2];
        if (Parameters.MARRIAGE_MATCH_TO_MEANS) {
            sampleDifferentials[0] = Parameters.targetMeanAgeDifferential;
            sampleDifferentials[1] = Parameters.targetMeanWageDifferential;
        } else {
            sampleDifferentials = Parameters.getWageAndAgeDifferentialMultivariateNormalDistribution(innovations.getSingleDrawLongInnov(0));
        }
        return sampleDifferentials;
    }

    private void setAllSocialCareVariablesToFalse() {
        careNeedFlag = Indicator.False;
        careHrsFormalWeek = -9.0;
        careHrsFromPartnerWeek = -9.0;
        careHrsFromParentWeek = -9.0;
        careHrsFromDaughterWeek = -9.0;
        careHrsFromSonWeek = -9.0;
        careHrsFromOtherWeek = -9.0;
        careHrsProvidedWeek = -9.0;
        xCareFormalWeek = -9.0;
        careReceivedFlag = SocialCareReceipt.None;
        careFormalFlag = false;
        careFromPartnerFlag = false;
        careFromDaughterFlag = false;
        careFromSonFlag = false;
        careFromOtherFlag = false;
        careProvidedFlag = SocialCareProvision.None;
        careNeedFlagL1 = Indicator.False;
        careHrsFormalWeekL1 = -9.0;
        careHrsFromPartnerWeekL1 = -9.0;
        careHrsFromParentWeekL1 = -9.0;
        careHrsFromDaughterWeekL1 = -9.0;
        careHrsFromSonWeekL1 = -9.0;
        careHrsFromOtherWeekL1 = -9.0;
        careProvidedFlagL1 = SocialCareProvision.None;
    }

    public void setAdditionalFieldsInInitialPopulation() {

        if (labHrsWorkEnumWeek==null) //check this condition is necessary
            labHrsWorkEnumWeek = Labour.convertHoursToLabour(labHrsWorkWeek != null ? labHrsWorkWeek : 0, getDgn());
        yBenReceivedFlagL1 = yBenReceivedFlag;
        labHrsWorkEnumWeekL1 = getLabourSupplyWeekly();

        // NEW: seed immutable parents from existing IDs for EVERYONE (adults and minors)
        if (idMotherImmutable == null) idMotherImmutable = idMother;
        if (idFatherImmutable == null) idFatherImmutable = idFather;

        updateVariables(true);
    }

    //This method assign people to age groups used to define types in the SBAM matching procedure
    private void updateAgeGroup() {
        if (demAge < 18) {
            demAgeGroup = 0;
            model.tmpPeopleAssigned++;
        } else if(demAge >= 18 && demAge < 21) {
            demAgeGroup = 1;
            model.tmpPeopleAssigned++;
        } else if(demAge >= 21 && demAge < 24) {
            demAgeGroup = 2;
            model.tmpPeopleAssigned++;
        } else if(demAge >= 24 && demAge < 27) {
            demAgeGroup = 3;
            model.tmpPeopleAssigned++;
        } else if(demAge >= 27 && demAge < 30) {
            demAgeGroup = 4;
            model.tmpPeopleAssigned++;
        } else if(demAge >= 30 && demAge < 33) {
            demAgeGroup = 5;
            model.tmpPeopleAssigned++;
        } else if(demAge >= 33 && demAge < 36) {
            demAgeGroup = 6;
            model.tmpPeopleAssigned++;
        } else if(demAge >= 36 && demAge < 40) {
            demAgeGroup = 7;
            model.tmpPeopleAssigned++;
        } else if(demAge >= 40 && demAge < 45) {
            demAgeGroup = 8;
            model.tmpPeopleAssigned++;
        } else if(demAge >= 45 && demAge < 55) {
            demAgeGroup = 9;
            model.tmpPeopleAssigned++;
        } else if(demAge >= 55 && demAge < 65) {
            demAgeGroup = 10;
            model.tmpPeopleAssigned++;
        } else if(demAge >= 65) {
            demAgeGroup = 11;
            model.tmpPeopleAssigned++;
        } else {
            System.out.println("Could not assign age group!");
        }
    }


    // ---------------------------------------------------------------------
    // Event Listener
    // ---------------------------------------------------------------------
    public enum Processes {
        Aging,
        Cohabitation,
        ConsiderMortality,
        ConsiderRetirement,
        Fertility,
        GiveBirth,
        Health,
        HealthMentalHM1, 				//Predict level of mental health on the GHQ-12 Likert scale (Step 1)
        HealthMentalHM2,				//Modify the prediction from Step 1 by applying increments / decrements for exposure
        HealthMentalHM1HM2Cases,		//Case-based prediction for psychological distress, Steps 1 and 2 together
        InSchool,
        LeavingSchool,
        PartnershipDissolution,
        ProjectEquivConsumption,
        SocialCareReceipt,
        SocialCareProvision,
        Unemployment,
        Update,
        UpdateOutputVariables,
        UpdatePotentialHourlyEarnings,	//Needed to union matching and labour supply
    }

    @Override
    public void onEvent(Enum<?> type) {
        switch ((Processes) type) {
            case Aging -> {
                aging();
            }
            case Update -> {
                updateVariables(false);
            }
            case UpdateOutputVariables ->  {
                updateOutputVariables();
            }
            case ProjectEquivConsumption -> {
                projectEquivConsumption();
            }
            case Cohabitation -> {
    //			log.debug("BenefitUnit Formation for person " + this.getKey().getId());
                cohabitation();
            }
            case PartnershipDissolution -> {
                partnershipDissolution();
            }
            case ConsiderMortality -> {
                considerMortality();
            }
            case ConsiderRetirement -> {
                considerRetirement();
                retire();
            }
            case Fertility -> {
                fertility();
            }
            case GiveBirth -> {
    //			log.debug("Check whether to give birth for person " + this.getKey().getId());
                giveBirth();
            }
            case Health -> {
    //			log.debug("Health for person " + this.getKey().getId());
                health();
                disability();
            }
            case SocialCareReceipt -> {
                evaluateSocialCareReceipt();
            }
            case SocialCareProvision -> {
                evaluateSocialCareProvision();
            }
            case HealthMentalHM1 -> {
                healthMentalHM1Level();
            }
            case HealthMentalHM2 -> {
                healthMentalHM2Level();
            }
            case HealthMentalHM1HM2Cases -> {
                healthMentalHM1HM2Cases();
            }
            case InSchool -> {
    //			log.debug("In Education for person " + this.getKey().getId());
                inSchool();
            }
            case LeavingSchool -> {
                leavingSchool();
            }
            case UpdatePotentialHourlyEarnings -> {
    //			System.out.println("Update wage equation for person " + this.getKey().getId() + " with age " + age + " with activity_status " + activity_status + " and activity_status_lag " + activity_status_lag + " and toLeaveSchool " + toLeaveSchool + " with education " + education);
                updateFullTimeHourlyEarnings();
            }
            case Unemployment -> {
                updateUnemploymentState();
            }
            default -> {
                throw new RuntimeException("failed to identify process type in Person.onEvent");
            }
        }
    }


    // ---------------------------------------------------------------------
    // Processes
    // ---------------------------------------------------------------------

    public void fertility() {
        double probitAdjustment = model.getFertilityAdjustment();
        fertility(probitAdjustment);
    }

    public void fertility(double probitAdjustment) {
        demGiveBirthFlag = false;
        FertileFilter filter = new FertileFilter();
        if (filter.evaluate(this)) {

            double prob;

            double score = Parameters.getRegFertilityF1().getScore(this, Person.DoublesVariables.class);
            prob = Parameters.getRegFertilityF1().getProbability(score + probitAdjustment);

            if (innovations.getDoubleDraw(29) < prob)
                demGiveBirthFlag = true;

        }
    }

    private void updateUnemploymentState() {
        labWageOfferLowFlag = false;
        if (Parameters.flagUnemployment) {

            if (this == benefitUnit.getRefPersonForDecisions()) {
                // unemployment currently limited to reference person for decisions

                double prob;
                if (demMaleFlag.equals(Gender.Male)) {
                    if (eduHighestC4.equals(Education.High)) {
                        prob = Parameters.getRegUnemploymentMaleGraduateU1a().getProbability(this, Person.DoublesVariables.class);
                    } else {
                        prob = Parameters.getRegUnemploymentMaleNonGraduateU1b().getProbability(this, Person.DoublesVariables.class);
                    }
                } else {
                    if (eduHighestC4.equals(Education.High)) {
                        prob = Parameters.getRegUnemploymentFemaleGraduateU1c().getProbability(this, Person.DoublesVariables.class);
                    } else {
                        prob = Parameters.getRegUnemploymentFemaleNonGraduateU1d().getProbability(this, Person.DoublesVariables.class);
                    }
                }
                labWageOfferLowFlag = (innovations.getDoubleDraw(22) < prob);
            }
        }
    }

    //********************************************************
    // method to adjust for one year increment
    //********************************************************
    private void aging() {

        // iterate years in cohabiting partnership
        Person partner = getPartner();
        if (partner != null) {
            if (Objects.equals(partner.getId(), idPartnerL1)) {
                if (demPartnerNYear==null)
                    throw new RuntimeException("problem identifying dcpyy");
                demPartnerNYear++;
            } else
                demPartnerNYear = 0;
        } else
            demPartnerNYear = 0;

        // iterate employment history
        if (Les_c4.EmployedOrSelfEmployed.equals(labC4)) {
            labEmpNyear += 1;
        }

        // iterate age and update for maturity
        demAge++;
        if (demAge == Parameters.AGE_TO_BECOME_RESPONSIBLE) {
            setupNewBenefitUnit(true);
            considerLeavingHome();
        } else if (demAge > Parameters.AGE_TO_BECOME_RESPONSIBLE && Indicator.True.equals(demAdultChildFlag)) {
            considerLeavingHome();
        }
        updateAgeGroup();   //Update ageGroup as person ages
     }

    private void considerMortality() {

        boolean flagDies = false;
        if (model.getProjectMortality()) {

            if ( Occupancy.Couple.equals(benefitUnit.getOccupancy()) || benefitUnit.getSize() == 1 ) {
                // exclude single parents with dependent children from death

                double mortalityProbability = Parameters.getMortalityProbability(demMaleFlag, demAge, model.getYear());
                if (innovations.getDoubleDraw(0) < mortalityProbability) {
                    flagDies = true;
                }
            }
        }
        if (flagDies || demAge > Parameters.maxAge)
            demExitSample = SampleExit.Death;
    }

    // This process should be applied to those at the age to become responsible / leave home OR above if they have the adultChildFlag set to True (i.e. people can move out, but not move back in).
    /// Adult child: an adult who lives with parents who are not yet in need of care
    /// (e.g. at least one parent is below pension age and not yet retired)
    private void considerLeavingHome() {

        //For those who are moving out, evaluate whether they should have stayed with parents and if yes, set the adultchildflag to true
        double prob = Parameters.getRegLeaveHomeP1().getProbability(this, Person.DoublesVariables.class);
        boolean toLeaveHome = (innovations.getDoubleDraw(21) < prob);

        // Students are assumed not to leave the parental home
        if (Les_c4.Student.equals(labC4) && !(eduLeftEduFlag == true)) {demAdultChildFlag = Indicator.True;}

        if ((!Les_c4.Student.equals(labC4) || (eduLeftEduFlag == true)) && (demAge>=AGE_LEAVE_PARENTAL_HOME-1)) {

            if (!toLeaveHome) { //If at the age to leave home but regression outcome is negative, person has adultchildflag set to true (although they still set up a new benefitUnit in the simulation, it's treated differently in the labour supply)
                demAdultChildFlag = Indicator.True;
            } else {
                demAdultChildFlag = Indicator.False;
                setupNewHousehold(); //If person leaves home, they set up a new household
            }

            if (demAdultChildFlag.equals(Indicator.True)){


                // --- Parent existence checks
                Person iDad = null;
                Person iMom = null;

                boolean dadExist = (getFatherImmutable() != null);
                boolean momExist = (getMotherImmutable() != null);

                if (dadExist) {iDad = getFatherImmutable();}
                if (momExist) {iMom = getMotherImmutable();}

                // Compute state pension ages for parents if they exist
                int iDadPSA = -9;
                int iMomPSA = -9;

                if (dadExist) {
                    iDadPSA = Parameters.getStatePensionAge(model.getYear(), iDad.getDgn());
                }
                if (momExist) {
                    iMomPSA = Parameters.getStatePensionAge(model.getYear(), iMom.getDgn());
                }

                // Identify whether each parent is at/above pension age or already retired
                boolean dadNeedsCare = false;
                boolean momNeedsCare = false;

                if (dadExist) {dadNeedsCare = (iDad.getDag() >= iDadPSA || iDad.getRetired() == 1.0);}
                if (momExist) {momNeedsCare = (iMom.getDag() >= iMomPSA || iMom.getRetired() == 1.0);}

                // Check if there is effectively no non-retired / sub-PSA parent available
                boolean noParentAvailable =
                        (!dadExist && !momExist) ||                       // no parents
                        (!dadExist && momNeedsCare) ||                    // only mother exists and she’s at/above PSA or retired
                        (!momExist && dadNeedsCare) ||                    // only father exists and he’s at/above PSA or retired
                        (dadExist && momExist && dadNeedsCare && momNeedsCare); // both exist and both at/above PSA or retired

                if (noParentAvailable) {
                    demAdultChildFlag = Indicator.False; // If no eligible parent is available then the person is no longer considered an adult child and will not consider leaving parental home in future
                }


            }
        }
    }

    public boolean considerRetirement() {
        double probitAdjustment = model.getRetirementAdjustment();
        return considerRetirement(probitAdjustment);
    }

    public boolean considerRetirement(double probitAdjustment) {

        labToRetire = false;
        if (demAge >= Parameters.MIN_AGE_TO_RETIRE && !Les_c4.Retired.equals(labC4) && !Les_c4.Retired.equals(labC4L1)) {
            if (Parameters.enableIntertemporalOptimisations && DecisionParams.flagRetirement) {
                if (Labour.ZERO.equals(labHrsWorkEnumWeekL1)) {
                    labToRetire = true;
                }
           } else {
                double prob;
                if (getPartner() != null) {
                    double score = Parameters.getRegRetirementR1b().getScore(this, Person.DoublesVariables.class);
                    prob = Parameters.getRegRetirementR1b().getProbability(score + probitAdjustment);
                } else {
                    double score = Parameters.getRegRetirementR1a().getScore(this, Person.DoublesVariables.class);
                    prob = Parameters.getRegRetirementR1a().getProbability(score + probitAdjustment);
                }
                labToRetire = (innovations.getDoubleDraw(23) < prob);
            }
        }
        return labToRetire;
    }

    public void retire() {
        if (labToRetire) {
            setLes_c4(Les_c4.Retired);
            healthDsblLongtermFlag = Indicator.False;
        }
    }

    
    /*
    This method corresponds to Step 1 of the mental health evaluation: predict level of mental health on the GHQ-12 Likert scale based on observable characteristics
     */
    protected void healthMentalHM1Level() {
        if (demAge >= 16) {
            double score = Parameters.getRegHealthHM1Level().getScore(this, Person.DoublesVariables.class);
            double rmse = Parameters.getRMSEForRegression("HM1");
            double gauss = Parameters.getStandardNormalDistribution().inverseCumulativeProbability(innovations.getDoubleDraw(1));
            healthWbScore0to36 = constrainDhmEstimate(score + rmse*gauss);
        }
    }

    /*
    This method corresponds to Step 2 of the mental health evaluation: increment / decrement the outcome of Step 1 depending on exposures that individual experienced.
    Filtering: only applies to those with Age>=16 & Age<=64. Different estimates for males and females.
     */
    protected void healthMentalHM2Level() {

        double dhmPrediction;
        if (demAge >= 25 && demAge <= 64) {
            if (Gender.Male.equals(getDgn())) {
                dhmPrediction = Parameters.getRegHealthHM2LevelMales().getScore(this, Person.DoublesVariables.class);
                healthWbScore0to36 = constrainDhmEstimate(dhmPrediction+healthWbScore0to36);
            } else if (Gender.Female.equals(getDgn())) {
                dhmPrediction = Parameters.getRegHealthHM2LevelFemales().getScore(this, Person.DoublesVariables.class);
                healthWbScore0to36 = constrainDhmEstimate(dhmPrediction+healthWbScore0to36);
            } else System.out.println("healthMentalHM2 method in Person class: Person has no gender!");
        }
    }

    /*
    Case-based measure of psychological distress, Steps 1 and 2 modelled together
    */
    protected void healthMentalHM1HM2Cases() {

        if (demAge >= 16) {
            double tmp_step1_score = 0, tmp_step2_score = 0, tmp_total_score = 0, tmp_probability = 0;
            boolean tmp_outcome;

            tmp_step1_score = Parameters.getRegHealthHM1Case().getScore(this, Person.DoublesVariables.class); // Obtain score from Step 1 of case-based psychological distress model

            if (demAge >= 25 && demAge <= 64) {
                if (Gender.Male.equals(getDgn())) {
                    tmp_step2_score = Parameters.getRegHealthHM2CaseMales().getScore(this, Person.DoublesVariables.class); // Obtain score from Step 2 of case-based psychological distress model
                } else if (Gender.Female.equals(getDgn())) {
                    tmp_step2_score = Parameters.getRegHealthHM2CaseFemales().getScore(this, Person.DoublesVariables.class); // Obtain score from Step 2 of case-based psychological distress model
                } else System.out.println("healthMentalHM2 method in Person class: Person has no gender!");
            }

            //Put together: get total score, convert to probability, get event, set dummy
            // 1. Sum scores from Step 1 and 2. This produces the basic score modified by the effect of transitions modelled in Step 2.
            tmp_total_score = tmp_step1_score + tmp_step2_score;
            // 2. Convert to probability
            tmp_probability = 1.0 / (1.0 + Math.exp(-tmp_total_score));
            // 3. Get event outcome
            tmp_outcome = (innovations.getDoubleDraw(2) < tmp_probability);
            // 4. Set dhm_ghq dummy
            setDhmGhq(tmp_outcome);
        }
    }

    /*
    Psychological distress on the GHQ-12 scale has no meaning outside of the original values between 0 and 36, but we model this variable on a continuous scale. If the predicted value is outside of this interval, limit it to fall within these values.
     */
    protected Double constrainDhmEstimate(Double healthWbScore0to36) {
        if (healthWbScore0to36 < 0.) {
            healthWbScore0to36 = 0.;
        } else if (healthWbScore0to36 > 36.) {
            healthWbScore0to36 = 36.;
        }
        return healthWbScore0to36;
    }

    //Health process defines health using H1 process
    protected void health() {
        double healthInnov1 = innovations.getDoubleDraw(3);
        if (demAge >= AGE_TO_BECOME_SEMI_RESPONSIBLE) {
            Map<Dhe,Double> probs = ManagerRegressions.getProbabilities(this, RegressionName.HealthH1);
            MultiValEvent event = new MultiValEvent(probs, healthInnov1);
            healthSelfRated = (Dhe) event.eval();
        }
    }

    public void disability() {
        double probitAdjustment = model.getDisabilityAdjustment();
        disability(probitAdjustment);
    }

    protected void disability(double probitAdjustment) {
        double healthInnov2 = innovations.getDoubleDraw(4);
        if (demAge >= AGE_TO_BECOME_SEMI_RESPONSIBLE && (!Les_c4.Retired.equals(labC4)) && (!Les_c4.Student.equals(labC4) )) {
            //If age is over 16 follow process H2 to calculate the probability of long-term sickness / disability:
            boolean becomeLTSickDisabled = false;
            if (!Parameters.enableIntertemporalOptimisations || DecisionParams.flagDisability) {
                double score = Parameters.getRegHealthH2().getScore(this, Person.DoublesVariables.class);
                double prob = Parameters.getRegHealthH2().getProbability(score + probitAdjustment);
                becomeLTSickDisabled = (healthInnov2 < prob);
            }
            if (becomeLTSickDisabled) {
                healthDsblLongtermFlag = Indicator.True;
            } else {
                healthDsblLongtermFlag = Indicator.False;
            }
        }
    }

    protected void evaluateSocialCareReceipt() {

        if (demAge < Parameters.MIN_AGE_FORMAL_SOCARE || getYear()>getStartYear()) {

            careNeedFlag = Indicator.False;
            careHrsFormalWeek = 0.0;
            xCareFormalWeek = 0.0;
            careHrsFromPartnerWeek = 0.0;
            careHrsFromParentWeek = 0.0;
            careHrsFromDaughterWeek = 0.0;
            careHrsFromSonWeek = 0.0;
            careHrsFromOtherWeek = 0.0;
            careReceivedFlag = SocialCareReceipt.None;
            careFormalFlag = false;
            careFromPartnerFlag = false;
            careFromDaughterFlag = false;
            careFromSonFlag = false;
            careFromOtherFlag = false;
        }
        if (careHrsFromParentWeek==null)
            careHrsFromParentWeek = 0.0;

        if ((demAge < Parameters.MIN_AGE_FORMAL_SOCARE) && Indicator.True.equals(healthDsblLongtermFlag)) {
            // under 65 years old with disability

            careNeedFlag = Indicator.True;
            double probRecCare;
            if (Indicator.False.equals(healthDsblLongtermFlagL1) || getYear()==getStartYear()) {
                // need to identify receipt of social care

                probRecCare = Parameters.getRegReceiveCareS1a().getProbability(this, Person.DoublesVariables.class);
            } else {
                // persist preceding receipt

                if (getTotalHoursSocialCare_L1()>0.5) {
                    probRecCare = 1.1;
                } else {
                    probRecCare = -0.1;
                }
            }

            if (innovations.getDoubleDraw(5) < probRecCare) {
                // receive social care

                double score = Parameters.getRegCareHoursS1b().getScore(this,Person.DoublesVariables.class);
                double rmse = Parameters.getRMSEForRegression("S1b");
                double gauss = Parameters.getStandardNormalDistribution().inverseCumulativeProbability(innovations.getDoubleDraw(6));
                double careHours = Math.min(Parameters.MAX_HOURS_WEEKLY_INFORMAL_CARE, Math.exp(score + rmse * gauss));
                Person partner = getPartner();
                if (partner!=null && partner.getDag() < 75) {
                    careFromPartnerFlag = true;
                    careHrsFromPartnerWeek = careHours;
                } else if (demAge < 50) {
                    careFromOtherFlag = true;
                    careHrsFromParentWeek = careHours;
                } else {
                    careFromOtherFlag = true;
                    careHrsFromOtherWeek = careHours;
                }
            }
        }

        if (demAge >= Parameters.MIN_AGE_FORMAL_SOCARE && getYear()>getStartYear()) {
            // need care only projected for 65 and over due to limitations of data used for parameterisation

            double probNeedCare = Parameters.getRegNeedCareS2a().getProbability(this, Person.DoublesVariables.class);
            double recCareInnov = innovations.getDoubleDraw(7);
            if (recCareInnov < probNeedCare) {
                // need care
                careNeedFlag = Indicator.True;
            }

            double probRecCare = Parameters.getRegReceiveCareS2b().getProbability(this, Person.DoublesVariables.class);
            if (recCareInnov < probRecCare) {
                // receive care

                Map<SocialCareReceiptS2c,Double> probs1 = Parameters.getRegSocialCareMarketS2c().getProbabilities(this, Person.DoublesVariables.class);
                MultiValEvent event = new MultiValEvent(probs1, innovations.getDoubleDraw(8));
                SocialCareReceiptS2c socialCareReceiptS2c = (SocialCareReceiptS2c) event.eval();
                careReceivedFlag = SocialCareReceipt.getCode(socialCareReceiptS2c);
                if (SocialCareReceipt.Mixed.equals(careReceivedFlag) || SocialCareReceipt.Formal.equals(careReceivedFlag))
                    careFormalFlag = true;

                if (SocialCareReceipt.Mixed.equals(careReceivedFlag) || SocialCareReceipt.Informal.equals(careReceivedFlag)) {
                    // some informal care received

                    if (getPartner()!=null) {
                        // check if receive care from partner

                        double probPartnerCare = Parameters.getRegReceiveCarePartnerS2d().getProbability(this, Person.DoublesVariables.class);
                        if (innovations.getDoubleDraw(9) < probPartnerCare) {
                            // receive care from partner - check for supplementary carers

                            careFromPartnerFlag = true;
                            Map<PartnerSupplementaryCarer,Double> probs2 =
                                    Parameters.getRegPartnerSupplementaryCareS2e().getProbabilities(this, Person.DoublesVariables.class);
                            event = new MultiValEvent(probs2, innovations.getDoubleDraw(10));
                            PartnerSupplementaryCarer cc = (PartnerSupplementaryCarer) event.eval();
                            if (PartnerSupplementaryCarer.Daughter.equals(cc))
                                careFromDaughterFlag = true;
                            if (PartnerSupplementaryCarer.Son.equals(cc))
                                careFromSonFlag = true;
                            if (PartnerSupplementaryCarer.Other.equals(cc))
                                careFromOtherFlag = true;
                        }
                    }
                    if (!careFromPartnerFlag) {
                        // no care from partner - identify who supplies informal care

                        Map<NotPartnerInformalCarer,Double> probs2 =
                                Parameters.getRegNotPartnerInformalCareS2f().getProbabilities(this, Person.DoublesVariables.class);
                        event = new MultiValEvent(probs2, innovations.getDoubleDraw(11));
                        NotPartnerInformalCarer cc = (NotPartnerInformalCarer) event.eval();
                        if (NotPartnerInformalCarer.DaughterOnly.equals(cc) || NotPartnerInformalCarer.DaughterAndSon.equals(cc) || NotPartnerInformalCarer.DaughterAndOther.equals(cc))
                            careFromDaughterFlag = true;
                        if (NotPartnerInformalCarer.SonOnly.equals(cc) || NotPartnerInformalCarer.DaughterAndSon.equals(cc) || NotPartnerInformalCarer.SonAndOther.equals(cc))
                            careFromSonFlag = true;
                        if (NotPartnerInformalCarer.OtherOnly.equals(cc) || NotPartnerInformalCarer.SonAndOther.equals(cc) || NotPartnerInformalCarer.DaughterAndOther.equals(cc))
                            careFromOtherFlag = true;
                    }
                }
                double careHoursInnov = innovations.getDoubleDraw(12);
                if (careFromPartnerFlag) {
                    double score = Parameters.getRegPartnerCareHoursS2g().getScore(this,Person.DoublesVariables.class);
                    double rmse = Parameters.getRMSEForRegression("S2g");
                    double gauss = Parameters.getStandardNormalDistribution().inverseCumulativeProbability(careHoursInnov);
                    careHrsFromPartnerWeek = Math.min(Parameters.MAX_HOURS_WEEKLY_INFORMAL_CARE, Math.exp(score + rmse * gauss));
                }
                careHoursInnov = Parameters.updateProbability(careHoursInnov);
                if (careFromDaughterFlag) {
                    double score = Parameters.getRegDaughterCareHoursS2h().getScore(this,Person.DoublesVariables.class);
                    double rmse = Parameters.getRMSEForRegression("S2h");
                    double gauss = Parameters.getStandardNormalDistribution().inverseCumulativeProbability(careHoursInnov);
                    careHrsFromDaughterWeek = Math.min(Parameters.MAX_HOURS_WEEKLY_INFORMAL_CARE, Math.exp(score + rmse * gauss));
                }
                careHoursInnov = Parameters.updateProbability(careHoursInnov);
                if (careFromSonFlag) {
                    double score = Parameters.getRegSonCareHoursS2i().getScore(this,Person.DoublesVariables.class);
                    double rmse = Parameters.getRMSEForRegression("S2i");
                    double gauss = Parameters.getStandardNormalDistribution().inverseCumulativeProbability(careHoursInnov);
                    careHrsFromSonWeek = Math.min(Parameters.MAX_HOURS_WEEKLY_INFORMAL_CARE, Math.exp(score + rmse * gauss));
                }
                careHoursInnov = Parameters.updateProbability(careHoursInnov);
                if (careFromOtherFlag) {
                    double score = Parameters.getRegOtherCareHoursS2j().getScore(this,Person.DoublesVariables.class);
                    double rmse = Parameters.getRMSEForRegression("S2j");
                    double gauss = Parameters.getStandardNormalDistribution().inverseCumulativeProbability(careHoursInnov);
                    careHrsFromOtherWeek = Math.min(Parameters.MAX_HOURS_WEEKLY_INFORMAL_CARE, Math.exp(score + rmse * gauss));
                }
                careHoursInnov = Parameters.updateProbability(careHoursInnov);
                if (careFormalFlag) {
                    double score = Parameters.getRegFormalCareHoursS2k().getScore(this,Person.DoublesVariables.class);
                    double rmse = Parameters.getRMSEForRegression("S2k");
                    double gauss = Parameters.getStandardNormalDistribution().inverseCumulativeProbability(careHoursInnov);
                    careHrsFormalWeek = Math.min(Parameters.MAX_HOURS_WEEKLY_FORMAL_CARE, Math.exp(score + rmse * gauss));
                    xCareFormalWeek = careHrsFormalWeek * Parameters.getTimeSeriesValue(model.getYear(), TimeSeriesVariable.CarerWageRate);
                }
            }
        }
        if (Parameters.flagSuppressSocialCareCosts)
            xCareFormalWeek = 0.0;
    }

    protected void evaluateSocialCareProvision() {
        evaluateSocialCareProvision(Parameters.getTimeSeriesValue(model.getYear(),TimeSeriesVariable.CareProvisionAdjustment));
    }

    public void evaluateSocialCareProvision(double probitAdjustment) {

        careProvidedFlag = SocialCareProvision.None;
        careHrsProvidedWeek = 0.0;
        boolean careToPartner = false;
        boolean careToOther;
        double careHoursToPartner = 0.0;
        if (demAge >= Parameters.AGE_TO_BECOME_RESPONSIBLE) {

            // check if care provided to partner
            // identified in method evaluateSocialCareReceipt
            Person partner = getPartner();
            if (partner!=null && partner.careFromPartnerFlag) {
                careToPartner = true;
                careHoursToPartner = partner.getCareHoursFromPartnerWeekly();
            }

            // check if care provided to "other"
            double prob;
            if (careToPartner) {
                double score = Parameters.getRegCarePartnerProvCareToOtherS3a().getScore(this, Person.DoublesVariables.class);
                prob = Parameters.getRegCarePartnerProvCareToOtherS3a().getProbability(score + probitAdjustment);
            } else {
                double score = Parameters.getRegNoCarePartnerProvCareToOtherS3b().getScore(this, Person.DoublesVariables.class);
                prob = Parameters.getRegNoCarePartnerProvCareToOtherS3b().getProbability(score + probitAdjustment);
            }
            careToOther = (innovations.getDoubleDraw(13) < prob);

            // update care provision states
            if (careToPartner || careToOther) {

                if (careToPartner && careToOther) {
                    careProvidedFlag = SocialCareProvision.PartnerAndOther;
                } else if (careToPartner) {
                    careProvidedFlag = SocialCareProvision.OnlyPartner;
                } else {
                    careProvidedFlag = SocialCareProvision.OnlyOther;
                }
                if (!Parameters.flagSuppressSocialCareCosts) {
                    if (SocialCareProvision.OnlyPartner.equals(careProvidedFlag)) {
                        careHrsProvidedWeek = careHoursToPartner;
                    } else {
                        double score = Parameters.getRegCareHoursProvS3e().getScore(this,Person.DoublesVariables.class);
                        double rmse = Parameters.getRMSEForRegression("S3e");
                        double gauss = Parameters.getStandardNormalDistribution().inverseCumulativeProbability(innovations.getDoubleDraw(14));
                        careHrsProvidedWeek = Math.min(Parameters.MAX_HOURS_WEEKLY_INFORMAL_CARE,
                                Math.max(careHoursToPartner + 1.0, Math.exp(score + rmse * gauss)));
                    }
                }
            }
        }
    }

    public void cohabitation() {
        double probitAdjustment = model.getPartnershipAdjustment();
        cohabitation(probitAdjustment);
    }

    protected void cohabitation(double probitAdjustment) {

        // parameter check
        if (probitAdjustment>(4.0+1.0E-5) || probitAdjustment<(-4.0-1.0E-5))
            throw new RuntimeException("odd value for probit adjustment supplied to considerCohabitation method: " + probitAdjustment);

        demBePartnerFlag = false;
        demLeavePartnerFlag = false;
        demAlignPartnerProcess = false;
        double cohabitInnov = innovations.getDoubleDraw(25);
        Person partner = getPartner();
        if (demAge >= Parameters.MIN_AGE_COHABITATION) {
            // cohabitation possible

                double prob;
                if (partner == null) {
                    // partnership formation
                    double score = Parameters.getRegPartnershipU1().getScore(this, Person.DoublesVariables.class);
                    prob = Parameters.getRegPartnershipU1().getProbability(score + probitAdjustment);

                    demBePartnerFlag = (cohabitInnov < prob);
                    if (demBePartnerFlag)
                        model.getPersonsToMatch().get(demMaleFlag).get(getRegion()).add(this);

                } else if (demMaleFlag == Gender.Female & demAge < Parameters.SEPARATION_STOP_AGE) {
                    // partnership dissolution

                    double score = Parameters.getRegPartnershipU2().getScore(this, Person.DoublesVariables.class);
                    prob = Parameters.getRegPartnershipU2().getProbability(score - probitAdjustment);
                    if (cohabitInnov < prob) {
                        demLeavePartnerFlag = true;
                    }
                }

        }
    }

    protected void partnershipDissolution() {

        if (demLeavePartnerFlag) {

            // update partner's variables first
            Person partner = getPartner();
            partner.setDcpyy(null);
            partner.setLeftPartnership(true); //Set to true if leaves partnership to use with fertility regression, this is never reset

            setDcpyy(null); 		  //Set number of years in partnership to null if leaving partner
            setLeftPartnership(true); //Set to true if leaves partnership to use with fertility regression, this is never reset
            idHh = null;

            setupNewBenefitUnit(true);
        }
    }

    public boolean inSchool() {
        double probitAdjustment = model.getInSchoolAdjustment();
        return inSchool(probitAdjustment);
    }


    protected boolean inSchool(double probitAdjustment) {
        // Documentation: diagram "SimPathsEU education module - MR2"

        eduLeaveSchoolFlag = false;

        // Innovation for education decisions
        double labourInnov = innovations.getDoubleDraw(24);

        // Initial case (laggedStudent): In the previous period, was the individual a student?

        // Yes
        if (Les_c4.Student.equals(labC4L1)) {

            // Is the age of the individual above the minimum age to leave education (age >= minQuittingAge)?

            // Yes
            if(demAge >= MIN_AGE_TO_LEAVE_EDUCATION){

                // Is the age of the individual below the max age to leave education (age < maxQuittingAge)?

                // Yes
                if(demAge <= MAX_AGE_TO_STAY_IN_CONTINUOUS_EDUCATION) {

                    // Yes
                    // --> process E1a
                    double score = Parameters.getRegEducationE1a().getScore(this, Person.DoublesVariables.class);
                    double prob = Parameters.getRegEducationE1a().getProbability(score + probitAdjustment);

                    if (labourInnov < prob) {
                        // Remain a student *OUTCOME B*
                        setLes_c4(Les_c4.Student);  //not needed, more of a precaution
                        //setDed(Indicator.True);           //(!) a bug; E1a is applied to everyone with Ded true and false
                        //setDer(Indicator.False);          //(!) a bug; Der is set to true only when individual re-enters education (i.e. process E1b)

                        return true; // Must return true as they remain in school
                    } else {
                        // Leave education --> Process E2
                        eduLeaveSchoolFlag = true; // Must set flag to true
                        return false; // Must return false as they are leaving
                    }
                }

                // No (dag > MAX_AGE_TO_LEAVE_CONTINUOUS_EDUCATION)
                else{
                    // Leave education --> Process E2
                    eduLeaveSchoolFlag = true; // Must set flag to true
                    return false; // Must return false as they are leaving
                }
            }

            // No (dag < MIN_AGE_TO_LEAVE_EDUCATION)
            else{
                return true; // The individual remains a student *OUTCOME A*
            }
        }


        // No (Not a Student in lag1)
        else {

            // In the previous period, was the individual a retired (laggedRetired)?

            // Yes
            if (Les_c4.Retired.equals(labC4L1)) {
                return false;   // The individual can't be a student *OUTCOME C*
                                // Remain in current status which is retired
            }

            // No
            // --> Process E1b
            else{

            double score = Parameters.getRegEducationE1b().getScore(this, Person.DoublesVariables.class);
            double prob = Parameters.getRegEducationE1b().getProbability(score);

            if (labourInnov < prob) {
                // Become a student *OUTCOME E*
                setLes_c4(Les_c4.Student);
                setDer(Indicator.True);
                setDed(Indicator.False); //not needed, more of a precaution as ded should already be false
                return true; // Must return true as they become a student
            } else {
                return false; // Remain in current status: employed/not employed (no changes) *OUTCOME D*
                }

            }

        }

    }


    public void leavingSchool() {

        if (eduLeaveSchoolFlag) {

            setEducationLevel(); //If individual leaves school follow process E2a to assign level of education
            setSedex(Indicator.True); //Set variable left education (sedex) if leaving school
            setDed(Indicator.False); //Set variable in education (ded) to false if leaving school
            setDer(Indicator.False);
            setLeftEducation(true); //This is not reset and indicates if individual has ever left school - used with health process
            setLes_c4(Les_c4.NotEmployed); //Set activity status to NotEmployed when leaving school to remove Student status

            this.eduLeaveSchoolFlag = false; // Reset the flag once the leaving process is complete

        }
    }


    private void giveBirth() {				//To be called once per year after fertility alignment

        if (demGiveBirthFlag) {		//toGiveBirth is determined by fertility process

            Gender babyGender = (innovations.getDoubleDraw(27) < Parameters.PROB_NEWBORN_IS_MALE) ? Gender.Male : Gender.Female;

            //Give birth to new person and add them to benefitUnit.
            Person child = new Person(babyGender, this);
            model.getPersons().add(child);
            benefitUnit.getMembers().add(child);
        }
    }


    protected void initialisePotentialHourlyEarnings() {

        double gauss = Parameters.getStandardNormalDistribution().inverseCumulativeProbability(innovations.getDoubleDraw(15));
        double logPotentialHourlyEarnings, score, rmse;
        if (demMaleFlag.equals(Gender.Male)) {
            score = Parameters.getRegWagesMales().getScore(this, Person.DoublesVariables.class);
            rmse = Parameters.getRMSEForRegression("Wages_Males");
        } else {
            score = Parameters.getRegWagesFemales().getScore(this, Person.DoublesVariables.class);
            rmse = Parameters.getRMSEForRegression("Wages_Females");
        }
        logPotentialHourlyEarnings = score + rmse * gauss;
        double upratedLevelPotentialHourlyEarnings = Math.exp(logPotentialHourlyEarnings);
        setFullTimeHourlyEarningsPotential(upratedLevelPotentialHourlyEarnings);
        setL1_fullTimeHourlyEarningsPotential(upratedLevelPotentialHourlyEarnings);
        labWageHrlyRegression = upratedLevelPotentialHourlyEarnings; // no macro overlay at init
    }


    protected void updateFullTimeHourlyEarnings() {

        double rmse, wagesInnov = innovations.getDoubleDraw(16);
        if (Les_c4.EmployedOrSelfEmployed.equals(labC4L1)) {
            if (labWageRegressRandomCompoponentEmp == null || !model.fixRegressionStochasticComponent) {
                if (Gender.Male.equals(demMaleFlag)) {
                    rmse = Parameters.getRMSEForRegression("W1mb");
                } else {
                    rmse = Parameters.getRMSEForRegression("W1fb");
                }
                double gauss = Parameters.getStandardNormalDistribution().inverseCumulativeProbability(wagesInnov);
                labWageRegressRandomCompoponentEmp = rmse * gauss;
            }
        } else {
            if (labWageRegressRandomCompoponentNotEmp == null || !model.fixRegressionStochasticComponent) {
                if (Gender.Male.equals(demMaleFlag)) {
                    rmse = Parameters.getRMSEForRegression("W1ma");
                } else {
                    rmse = Parameters.getRMSEForRegression("W1fa");
                }
                double gauss = Parameters.getStandardNormalDistribution().inverseCumulativeProbability(wagesInnov);
                labWageRegressRandomCompoponentNotEmp = rmse * gauss;
            }
        }

        double logFullTimeHourlyEarnings;
        if(Gender.Male.equals(demMaleFlag)) {
            if (Les_c4.EmployedOrSelfEmployed.equals(labC4L1)) {
                logFullTimeHourlyEarnings = Parameters.getRegW1mb().getScore(this, Person.DoublesVariables.class) + labWageRegressRandomCompoponentEmp;
            } else {
                logFullTimeHourlyEarnings = Parameters.getRegW1ma().getScore(this, Person.DoublesVariables.class) + labWageRegressRandomCompoponentNotEmp;
            }
        } else {
            if (Les_c4.EmployedOrSelfEmployed.equals(labC4L1)) {
                logFullTimeHourlyEarnings = Parameters.getRegW1fb().getScore(this, Person.DoublesVariables.class) + labWageRegressRandomCompoponentEmp;
            } else {
                logFullTimeHourlyEarnings = Parameters.getRegW1fa().getScore(this, Person.DoublesVariables.class) + labWageRegressRandomCompoponentNotEmp;
            }
        }

        // Uprate and set level of potential earnings
        double upratedFullTimeHourlyEarnings = Math.exp(logFullTimeHourlyEarnings);

        // Snapshot the pre-overlay regression wage (same MIN/MAX clamp as the effective wage)
        // so the AR(1) lag propagates the SimPaths wage process, not the macro-multiplied wage.
        if (upratedFullTimeHourlyEarnings < Parameters.MIN_HOURLY_WAGE_RATE) {
            labWageHrlyRegression = Parameters.MIN_HOURLY_WAGE_RATE;
        } else if (upratedFullTimeHourlyEarnings > Parameters.MAX_HOURLY_WAGE_RATE) {
            labWageHrlyRegression = Parameters.MAX_HOURLY_WAGE_RATE;
        } else {
            labWageHrlyRegression = upratedFullTimeHourlyEarnings;
        }

        // Apply DSGE macro wage deviation if macro model is enabled
        // wageDeviation is in % (e.g., 2.5 means 2.5% above steady state)
        if (model.getMm_macroModel().isOn()) {
            double wageDeviation = model.getMm_wageDeviation();
            if (Math.abs(wageDeviation) > 1e-9) {  // Only adjust if deviation is non-zero
                double originalWage = upratedFullTimeHourlyEarnings;
                double wageMultiplier = 1.0 + wageDeviation / 100.0;
                upratedFullTimeHourlyEarnings *= wageMultiplier;
                // Track for logging summary (includes sample individual logging)
                model.trackWageAdjustment(this, originalWage, upratedFullTimeHourlyEarnings, wageDeviation);
            }
        }

        if (upratedFullTimeHourlyEarnings < Parameters.MIN_HOURLY_WAGE_RATE) {
            setFullTimeHourlyEarningsPotential(Parameters.MIN_HOURLY_WAGE_RATE);
        } else if (upratedFullTimeHourlyEarnings > Parameters.MAX_HOURLY_WAGE_RATE) {
            setFullTimeHourlyEarningsPotential(Parameters.MAX_HOURLY_WAGE_RATE);
        } else {
            setFullTimeHourlyEarningsPotential(upratedFullTimeHourlyEarnings);
        }
    }
    public void setYpncp(double val) {
        yCapitalPersMonth = val;
    }
    public void setYpnoab(double val) {
        yPensPersGrossMonth = val;
    }
    public double getPensionIncomeAnnual() {
        return Math.sinh(yPensPersGrossMonth)*12.0;
    }
    private double setIncomeBySource(double score, double rmse, IncomeSource source, RegressionScoreType scoreType) {

        double income = 0.0, gauss, minInc, maxInc;
        boolean redraw = true;
        if (IncomeSource.PrivatePension.equals(source)) {

            minInc = Parameters.MIN_PERSONAL_PENSION_PER_MONTH;
            maxInc = Parameters.MAX_PERSONAL_PENSION_PER_MONTH;
        } else if (IncomeSource.CapitalIncome.equals(source)) {

            minInc = Parameters.MIN_CAPITAL_INCOME_PER_MONTH;
            maxInc = Parameters.MAX_CAPITAL_INCOME_PER_MONTH;
        } else {

            throw new RuntimeException("source not recognised for setting income");
        }
        double capitalInnov = innovations.getDoubleDraw(17);
        while (redraw) {

            gauss = Parameters.getStandardNormalDistribution().inverseCumulativeProbability(capitalInnov);
            double incomeVal = 0.;
            if (RegressionScoreType.Asinh.equals(scoreType)) {

                incomeVal = Math.sinh( score + rmse * gauss );
            } else if (RegressionScoreType.Level.equals(scoreType)) {

                incomeVal = score + rmse * gauss;
            } else if (RegressionScoreType.Log.equals(scoreType)) {

                incomeVal = Math.exp(score + rmse * gauss);   // NEW
            }
            income = Math.max(minInc, incomeVal);
            if (income < maxInc) {
                redraw = false;
            } else {
                capitalInnov /= 2.0;
            }
        }
        return income;
    }
    protected void updateNonLabourIncome() {
        
        if (Parameters.enableIntertemporalOptimisations)
            throw new RuntimeException("request to update non-labour income in person object when wealth is explicit");


        // ypnoab: inverse hyperbolic sine of pension income per month
        // when intertemporal optimisation is disabled, pension income is assumed to be zero,
        // code below ensures any inherited values from initial populations are not persisted, irrelevant of person's activity status
        double pensionIncLevel = 0.;
        yPensPersGrossMonth = Parameters.asinh(pensionIncLevel);

        // ypncp: inverse hyperbolic sine of capital income per month
        // yptciihs_dv: inverse hyperbolic sine of capital and pension income per month
        // variables updated with labour supply when enableIntertemporalOptimisations (as retirement can affect wealth and pension income)
        if (demAge >= Parameters.MIN_AGE_TO_HAVE_INCOME) {

            double capitalInnov = innovations.getDoubleDraw(18);

            double prob = Parameters.getRegIncomeI1a().getProbability(this, Person.DoublesVariables.class);
            boolean hasCapitalIncome = (capitalInnov < prob);
            if (hasCapitalIncome) {
                double score = Parameters.getRegIncomeI1b().getScore(this, Person.DoublesVariables.class);
                double rmse = Parameters.getRMSEForRegression("I3");
                double capinclevel = setIncomeBySource(score, rmse, IncomeSource.CapitalIncome, RegressionScoreType.Log);
                yCapitalPersMonth = Parameters.asinh(capinclevel); //Capital income amount, asinh
            } else yCapitalPersMonth = 0.; //If no capital income, set amount to 0

//            if (Les_c4.Retired.equals(les_c4)) {
//                double pensionIncLevel = 0.;
//                ypnoab = Parameters.asinh(pensionIncLevel);
//            }
        }

        double capital_income_multiplier = model.getSavingRate()/Parameters.SAVINGS_RATE;
        double yptciihs_dv_tmp_level = capital_income_multiplier*(Math.sinh(yCapitalPersMonth) + Math.sinh(yPensPersGrossMonth)); //Multiplied by the capital income multiplier, defined as chosen savings rate divided by the long-term average (specified in Parameters class)
        yMiscPersGrossMonth = Parameters.asinh(yptciihs_dv_tmp_level); //Non-employment non-benefit income is the sum of capital income and, for retired individuals, pension income.

        if (yMiscPersGrossMonth > 13.0) {
            yMiscPersGrossMonth = 13.5;
        }
        if (Parameters.enableIntertemporalOptimisations)
            throw new RuntimeException("request to update non-labour income in person object when wealth is explicit");
    }


    // ---------------------------------------------------------------------
    // Other Methods
    // ---------------------------------------------------------------------
    public boolean atRiskOfWork() {

        /*
        Person "flexible in labour supply" must meet the following conditions:
        age >= 16 and <= 75
        not a student or retired
        not disabled
         */

        if (demAge < Parameters.MIN_AGE_FLEXIBLE_LABOUR_SUPPLY)
            return false;
        if (demAge > Parameters.MAX_AGE_FLEXIBLE_LABOUR_SUPPLY)
            return false;
        if (Les_c4.Retired.equals(labC4))
            return false;
        if (Les_c4.Student.equals(labC4))
            return false;
        if (Indicator.True.equals(healthDsblLongtermFlag))
            return false;

        //For cases where the participation equation used for the Heckmann Two-stage correction of the wage equation results in divide by 0 errors.
        //These people will not work for any wage (their activity status will be set to Nonwork in the Labour Market Module
        Double inverseMillsRatio = getInverseMillsRatio();
        if (!Double.isFinite(inverseMillsRatio))
            return false;

        return true;		//Else return true
    }


    // Assign education level to school leavers using Generalised Ordered Logit regression.
    // Note that persons are now assigned a Low education level by default at birth (to prevent null pointer exceptions when persons become old enough to marry while still being a student).
    // (We now allow students to marry, given they can re-enter school throughout their lives).
    // The module only applies to students who are leaving school (Les_c4.Student.equals(les_c4_lag1) and toLeaveSchool == true) - see inSchool()
    public void setEducationLevel() {

        // Process E2

        // --- Step 1: Regression Result ---
        // The regression determines the highest possible qualification achieved this spell.
        Map<EducationLevel,Double> probs = Parameters.getRegEducationE2a().getProbabilities(this, Person.DoublesVariables.class);
        MultiValEvent event = new MultiValEvent(probs, innovations.getDoubleDraw(30));
        EducationLevel regressionEducationLevel = (EducationLevel) event.eval();
        Education newEducationLevel = Education.valueOf(regressionEducationLevel.name());

        // Education has been set to Low by default for all newborn babies, so it should never be null.
        // This is because we no longer prevent people in school to get married, given that people can re-enter education throughout their lives.
        // Note that by not filtering out students, we must assign a low education level by default to persons at birth to prevent a null pointer exception when new born persons become old enough to marry if they have not yet left school because
        // their education level has not yet been assigned.

        // --- Step 2: Update counters based on regression result ---
        if (newEducationLevel.equals(Education.Low)) {
            model.lowEd++;
        } else if (newEducationLevel.equals(Education.Medium)) {
            model.medEd++;
        } else if (newEducationLevel.equals(Education.High)) {
            model.highEd++;
        } else if (newEducationLevel.equals(Education.NotAssigned)) {
            model.naEd++;
        } else {
            model.nothing++;
        }

        // --- Step 3: process E2 in the diagaram ---
        if(eduHighestC4 != null) {
            if (newEducationLevel.getRank() > eduHighestC4.getRank()) {		//Assume Education level cannot decrease after re-entering school.
                eduHighestC4 = newEducationLevel;
            }
        } /*else {
            // retain old level -> deh_c3 remains the same
        }*/

    }

    public double getLiquidWealth() {

        if (demAge <= Parameters.AGE_TO_BECOME_RESPONSIBLE) {
            return 0.0;
        } else if (benefitUnit != null) {
            return (Occupancy.Couple.equals(benefitUnit.getOccupancy())) ? benefitUnit.getLiquidWealth() / 2.0 : benefitUnit.getLiquidWealth();
        } else {
            throw new RuntimeException("Call to get liquid wealth for person object without benefit unit assigned");
        }
    }

    protected void projectEquivConsumption() {

        if (Parameters.enableIntertemporalOptimisations) {

            xEquivYear = benefitUnit.getDiscretionaryConsumptionPerYear() / benefitUnit.getEquivalisedWeight();
        } else {

            if (getLes_c4().equals(Les_c4.Retired)) {
                xEquivYear = benefitUnit.getEquivalisedDisposableIncomeYearly();
            } else {
                xEquivYear = Math.max(0., (1-model.getSavingRate())*benefitUnit.getEquivalisedDisposableIncomeYearly());
            }
        }
    }

    protected void updateVariables(boolean initialUpdate) {

        //Reset flags to default values
        eduLeaveSchoolFlag = false;
        demGiveBirthFlag = false;
        demBePartnerFlag = false;
        demLeavePartnerFlag = false;
        setSedex(Indicator.False); //This variable is False by default
        // is set to true only when person leaves school in this specific year

        //ded = (Les_c4.Student.equals(les_c4)) ? Indicator.True : Indicator.False; it's a bug!
        // now it's fixed - it's set up from init pop and is updated in inSchool method

        if (initialUpdate && careHrsFromParentWeek==null)
            careHrsFromParentWeek = 0.0;
        if (demAge<Parameters.AGE_TO_BECOME_RESPONSIBLE) {
            Person mother = benefitUnit.getFemale();
            if (mother!=null)
                idMother = mother.getId();
            else
                idMother = null;
            Person father = benefitUnit.getMale();
            if (father!=null)
                idFather = father.getId();
            else
                idFather = null;
        }

        if (idMotherImmutable == null) idMotherImmutable = idMother;
        if (idFatherImmutable == null) idFatherImmutable = idFather;

        //Lagged variables
        updateLaggedVariables(initialUpdate);

        // generate year specific random draws
        if (!initialUpdate) {
            if (Parameters.enableIntertemporalOptimisations && !DecisionParams.flagDisability) {
                healthDsblLongtermFlag = Indicator.False;
                healthDsblLongtermFlagL1 = Indicator.False;
            }
            if (!Parameters.flagSocialCare) {
                setAllSocialCareVariablesToFalse();
            }
            innovations.getNewDoubleDraws();
        }
    }

    /*
    Contemporaneous values of idPartner, dcpst, dhhtp_c4 are required for validation. Update and output here.
     */
    private void updateOutputVariables() {
        idPartner = getPartnerID();
        demPartnerStatus = getDcpst();
    }

    private void updateLaggedVariables(boolean initialUpdate) {

        labC4L1 = labC4;
        labC7CovidL1 = labC7Covid;
        demStatusHhL1 = getHouseholdStatus();
        healthSelfRatedL1 = healthSelfRated; //Update lag(1) of health
        healthWbScore0to36L1 = healthWbScore0to36; //Update lag(1) of mental health
        healthDhmGhqL1 = healthDhmGhq;
        healthDsblLongtermFlagL1 = healthDsblLongtermFlag; //Update lag(1) of long-term sick or disabled status
        careNeedFlagL1 = careNeedFlag;
        careHrsFormalWeekL1 = careHrsFormalWeek;
        careHrsFromPartnerWeekL1 = careHrsFromPartnerWeek;
        careHrsFromParentWeekL1 = careHrsFromParentWeek;
        careHrsFromDaughterWeekL1 = careHrsFromDaughterWeek;
        careHrsFromSonWeekL1 = careHrsFromSonWeek;
        careHrsFromOtherWeekL1 = careHrsFromOtherWeek;
        careProvidedFlagL1 = careProvidedFlag;
        labWageOfferLowFlagL1 = getLowWageOffer();
        eduHighestC4L1 = eduHighestC4; //Update lag(1) of education level
        eduDedL1 = eduSpellFlag; //Update lag(1) of education level
        yNonBenPersGrossMonthL1 = getYpnbihs_dv(); //Update lag(1) of gross personal non-benefit income
        labHrsWorkEnumWeekL1 = getLabourSupplyWeekly(); // Lag(1) of labour supply
        yBenReceivedFlagL1 = yBenReceivedFlag; // Lag(1) of flag indicating if individual receives benefits
        // Lag(1) of the wage process must be the PRE-overlay regression wage, so the macro
        // (Ramsey/DSGE) trend is applied once per year and not re-amplified through the AR(1)
        // term. Fall back to labWageHrly only if the regression wage was not set this year.
        labWageHrlyL1 = (labWageHrlyRegression != null) ? labWageHrlyRegression : labWageHrly;

        if (initialUpdate) {
            yEmpPersGrossMonthL1 = getYplgrs_dv(); //Lag(1) of gross personal employment income
            yEmpPersGrossMonthL2 = getYplgrs_dv();
            yEmpPersGrossMonthL3 = getYplgrs_dv();

            yMiscPersGrossMonthL1 = getYptciihs_dv();
            yMiscPersGrossMonthL2 = getYptciihs_dv();
            yMiscPersGrossMonthL3 = getYptciihs_dv();

            yCapitalPersMonthL1 = getYpncp();
            yCapitalPersMonthL2 = getYpncp();

            yPensPersGrossMonthL1 = getYpnoab();
            yPensPersGrossMonthL2 = getYpnoab();
        } else {
            yEmpPersGrossMonthL3 = yEmpPersGrossMonthL2; //Lag(3) of gross personal employment income
            yEmpPersGrossMonthL2 = yEmpPersGrossMonthL1; //Lag(2) of gross personal employment income
            yEmpPersGrossMonthL1 = getYplgrs_dv(); //Lag(1) of gross personal employment income

            yMiscPersGrossMonthL3 = yMiscPersGrossMonthL2; //Lag(3) of gross personal non-employment non-benefit income
            yMiscPersGrossMonthL2 = yMiscPersGrossMonthL1; //Lag(2) of gross personal non-employment non-benefit income
            yMiscPersGrossMonthL1 = getYptciihs_dv(); //Lag(1) of gross personal non-employment non-benefit income

            yCapitalPersMonthL2 = yCapitalPersMonthL1;
            yCapitalPersMonthL1 = getYpncp();

            yPensPersGrossMonthL2 = yPensPersGrossMonthL1;
            yPensPersGrossMonthL1 = getYpnoab();
        }

        // partner variables
        Person partner = getPartner();
        if (partner!=null) {
            eduDehspC4L1 = partner.eduHighestC4;
            healthPartnerSelfRatedL1 = partner.healthSelfRated;
            demPartnerStatusL1 = Dcpst.Partnered;
            demAgePartnerDiffL1 = demAge - partner.demAge;
            idPartnerL1 = partner.getId();
        } else {
            eduDehspC4L1 = null;
            healthPartnerSelfRatedL1 = null;
            demAgePartnerDiffL1 = null;
            demPartnerStatusL1 = getDcpst();
            idPartnerL1 = null;
        }
        yPersAndPartnerGrossDiffMonthL1 = getYnbcpdf_dv(); //Lag(1) of difference between own and partner's gross personal non-benefit income
        labStatusPartnerAndOwnC4L1 = getLesdf_c4(); //Lag(1) of own and partner's activity status
    }

    // used when children leave home
    protected void setupNewHousehold() {

        Household newHousehold = new Household();
        model.getHouseholds().add(newHousehold);
        benefitUnit.setHousehold(newHousehold);
        idHh = newHousehold.getId();
        idBu = benefitUnit.getId();
    }


    /**
     *
     *   CREATE NEW BENEFIT UNIT FOR PERSON
     *
     *   A new benefit unit is created for someone when:
     *     they reach age of maturity
     *      - default to parental household (no change in household)
     *     they enter a new cohabiting relationship
     *     they leave a cohabiting relationship (in which case it is the woman that is allocated a new benefit unit)
     *
     *   @param automaticUpdateOfBenefitUnits - This is a toggle to control the automatic update of the model's set of benefitUnits,
     *   which would cause concurrent modification exception to be thrown if called within an iteration through benefitUnits.
     *
     *   There are two possible causes of concurrent modification issues: 1) adding of the new benefitUnit to the model's
     *   benefitUnits set and 2) removal of the last person from the benefitUnit when updateHousehold() method is called would
     *   lead to the automatic removal of the old house from the model's benefitUnits set.
     *
     *   To prevent concurrent modification
     *   exception being thrown, set this parameter to false and use the iterator on the benefitUnits to add the new
     *   benefitUnit manually e.g. (houseIterator.add(newHouse)).  Also the updateHousehold() method will need to be called and the person
     *   removed from the old house manually outside the iteration through benefitUnits.
     *
     */
    public void setupNewBenefitUnit(boolean automaticUpdateOfBenefitUnits) {
        setupNewBenefitUnit(null, automaticUpdateOfBenefitUnits);
    }
    public void setupNewBenefitUnit(Person partner, boolean automaticUpdateOfBenefitUnits) {

        // identify children transferring to new benefit unit
        // this needs to be done before new benefit units are created because the new benefit units
        // are instantiated with the transferred responsible adults, at which time the old benefit unit
        // references are also transferred
        Set<Person> childrenToNewBenefitUnit = childrenToFollowPerson(this);
        if (partner != null) {
            childrenToNewBenefitUnit.addAll(childrenToFollowPerson(partner));
        }

        Household newHousehold;
        BenefitUnit newBenefitUnit;
        if (partner != null) {
            // relationship forms
            // when a relationship forms newBenefitUnit is populated with data described by person and partner, both of whom
            // are re-assigned from their previous benefitUnits to newBenefitUnit and households to newHousehold

            newHousehold = new Household();
            newBenefitUnit = new BenefitUnit(this, partner);
        } else {
            // includes when reach age of maturity and when relationship dissolves.
            // When relationship dissolves person is the female, and this routine sets up a new benefit unit for the woman,
            // updates characteristics for both newBenefitUnit and benefitUnit, and then leaves benefitUnit to the man

            if (demAge==Parameters.AGE_TO_BECOME_RESPONSIBLE) {
                newHousehold = benefitUnit.getHousehold();
            } else {
                newHousehold = new Household();
            }
            long statSeed = (long)(getBenefitUnitRandomUniform()*100000);
            newBenefitUnit = new BenefitUnit(this, statSeed);
            if (model.getBenefitUnits().contains(newBenefitUnit)) {
                throw new RuntimeException("New benefit unit already found in benefitUnits - Hint: Primary keys may be corrupted");
            }
        }

        // establish links between objects
        newBenefitUnit.setHousehold(newHousehold);
        for (Person child : childrenToNewBenefitUnit) {
            child.setBenefitUnit(newBenefitUnit);
        }
        if (partner!=null)
            partner.setBenefitUnit(newBenefitUnit);
        this.setBenefitUnit(newBenefitUnit);
        newBenefitUnit.initializeFields();


        // Automatic update of collections if required
        // Removing children (above) from the benefitUnit should not lead to the removal of the benefitUnit (due to becoming an empty benefitUnit)
        // because there should still be the responsible male or female (this person or partner) in the benefitUnit, which we shall now remove from
        // their benefitUnit below.
        //
        // automaticUpdateOfBenefitUnits is a toggle to prevent automatic update to the model's set of benefitUnits, which would cause concurrent
        // modification exception to be thrown if called within an iteration through benefitUnits.  In this case, set parameter to false and use the
        // iterator on the benefitUnits to add manually e.g. (houseIterator.add(newBU)).
        model.getHouseholds().add(newHousehold);
        if (automaticUpdateOfBenefitUnits) {

            model.getBenefitUnits().add(newBenefitUnit);	//This will cause concurrent modification if setupNewHome is called in an iteration through benefitUnits
        }
    }

    private Set<Person> childrenToFollowPerson(Person person) {
        // by default children follow their mother, but if no mother then they follow their father

        Set<Person> childrenToNewBenefitUnit = new LinkedHashSet<>();
        if (person.demAge<Parameters.AGE_TO_BECOME_RESPONSIBLE)
            throw new RuntimeException("problem identifying allocation of children to new benefit unit");
        if (Gender.Female.equals(person.demMaleFlag))
            for (Person child : person.getBenefitUnit().getChildren()) {
                if (child.getIdMother()!=null && person.getId()==child.getIdMother())
                    childrenToNewBenefitUnit.add(child);
            }
        else {
            for (Person child : person.getBenefitUnit().getChildren()) {
                if (child.idMother==null && child.getIdFather()!=null && person.getId()==child.getIdFather())
                    childrenToNewBenefitUnit.add(child);
            }
        }

        return childrenToNewBenefitUnit;
    }

    @Override
    public int compareTo(Person person) {
        if (benefitUnit==null || person.benefitUnit==null)
            throw new IllegalArgumentException("attempt to compare benefit units prior to initialisation");
        return (int) (benefitUnit.getId() - person.getBenefitUnit().getId());
    }

    /*
    This method takes les_c4 (which is a more aggregated version of labour force activity statuses) and returns les_c6 version.
    Used when setting initial values of les_c6 from existing les_c4.
    */
    public void initialise_les_c6_from_c4() {
        if (labC4.equals(Les_c4.EmployedOrSelfEmployed)) {
            labC7Covid = Les_c7_covid.Employee;
        } else if (labC4.equals(Les_c4.NotEmployed)) {
            labC7Covid = Les_c7_covid.NotEmployed;
        } else if (labC4.equals(Les_c4.Student)) {
            labC7Covid = Les_c7_covid.Student;
        } else if (labC4.equals(Les_c4.Retired)) {
            labC7Covid = Les_c7_covid.Retired;
        }

        //In the first period the lagged value will be equal to the contemporaneous value
        if (labC7CovidL1 == null) {
            labC7CovidL1 = labC7Covid;
        }
    }


    //-----------------------------------------------------------------------------------
    // IIntSource implementation for the CrossSection.Integer objects in the collector
    //-----------------------------------------------------------------------------------

    public enum IntegerVariables {			//For cross section of Collector
        isEmployed,
        isNotEmployed,
        isRetired,
        isStudent,
        isNotEmployedOrRetired,
        isToBePartnered,
        isPsychologicallyDistressed,
        isNeedSocialCare,
    }

    public int getIntValue(Enum<?> variableID) {

        switch ((IntegerVariables) variableID) {

        case isEmployed:
            if (labC4 == null) return 0;		//For inactive people, who don't participate in the labour market
            else if (labC4.equals(Les_c4.EmployedOrSelfEmployed)) return 1;
            else return 0;		//For unemployed case

        case isNotEmployed:
            if (labC4 == null) return 0;
            else if (labC4.equals(Les_c4.NotEmployed)) return 1;
            else return 0;

        case isRetired:
            if (labC4 == null) return 0;
            else if (labC4.equals(Les_c4.Retired)) return 1;
            else return 0;

        case isStudent:
            if (labC4 == null) return 0;
            else if (labC4.equals(Les_c4.Student)) return 1;
            else return 0;

        case isNotEmployedOrRetired:
            if (labC4 == null) return 0;
            else if (labC4.equals(Les_c4.NotEmployed) || labC4.equals(Les_c4.Retired)) return 1;
            else return 0;

        case isToBePartnered:
            return (isToBePartnered())? 1 : 0;

        case isPsychologicallyDistressed:
            return (healthDhmGhq)? 1 : 0;

        case isNeedSocialCare:
            return (Indicator.True.equals(careNeedFlag)) ? 1 : 0;

        default:
            throw new RuntimeException("Unsupported variable " + variableID.name() + " in Person#getIntValue");
        }
    }


    // ---------------------------------------------------------------------
    // implements IDoubleSource for use with Regression classes
    // ---------------------------------------------------------------------

    public enum DoublesVariables {
        // ORGANISED ALPHABETICALLY TO ASSIST IDENTIFICATION

        Age,
        Constant, 						// For the constant (intercept) term of the regression
        D_Children,
        D_Children_L1,
        D_Children_2under,				// Indicator (dummy variables for presence of children of certain ages in the benefitUnit)
        D_Children_3_6,
        D_Children_7_12,
        D_Children_13_17,
        D_Children_18over,				//Currently this will return 0 (false) as children leave home when they are 18
        D_Econ_benefits,
        D_Home_owner,
        Dhh_owned_L1,
        Dag,
        Dag_sq,
        Dag_knot17,
        Dag_knot23,
        Dag_knot26,
        Dcpagdf_L1, 					//Lag(1) of age difference between partners
        Dcpyy_L1, 						//Lag(1) number of years in partnership
        Dcpst_Partnered,				//Partnered
        Dcpst_Partnered_L1,
        Dcpst_Single,					//Single never married
        Dcpst_Single_L1, 				//Lag(1) of partnership status is Single
        Ded,
        Ded_L1,


        Ded_Dag,
        Ded_Dag_sq,
        Ded_Dgn,

        Ded_Dcpst_Single,
        Ded_Dcpst_Single_L1,
        Ded_Dhe_VeryGood,

        Ded_Dhe_Fair_L1,
        Ded_Dhe_Good_L1,
        Ded_Dhe_VeryGood_L1,
        Ded_Dhe_Excellent_L1,
        Ded_Ypncp_L2,

        Ded_Ydses_c5_Q2_L1,
        Ded_Ydses_c5_Q3_L1,
        Ded_Ydses_c5_Q4_L1,
        Ded_Ydses_c5_Q5_L1,
        Ded_Yplgrs_dv_L1,
        Ded_Yplgrs_dv_L2,
        Ded_Ypncp_L1,

        Ded_Dnc_L1,
        Ded_Dnc02_L1,


        Deh_c3_Low,
        Deh_c3_Low_Dag,
        Deh_c3_Medium,
        Deh_c3_Medium_Dag,

        Deh_c4_High,
        Deh_c4_Low,
        Deh_c4_Low_Dag,
        Deh_c4_Low_L1,					//Education level lag(1) equals low
        Deh_c4_High_L1,					//Education level lag(1) equals high
        Deh_c4_Medium,
        Deh_c4_Medium_Dag,
        Deh_c4_Medium_L1, 				//Education level lag(1) equals medium
        Deh_c4_Na,
        Deh_c4_Na_L1,


        Dehsp_c4_Low_L1,				//Partner's education == Low at lag(1)
        Dehsp_c4_Medium_L1,				//Partner's education == Medium at lag(1)
        Dehsp_c4_High_L1,

        Dehf_c4_High,					//Father's education == High indicator
        Dehf_c4_Low,					//Father's education == Low indicator
        Dehf_c4_Medium,					//Father's education == Medium indicator
        Dehm_c4_High,					//Mother's education == High indicator
        Dehm_c4_Low,					//Mother's education == Low indicator
        Dehm_c4_Medium,					//Mother's education == Medium indicator
        Dehmf_c3_High,
        Dehmf_c3_Medium,
        Dehmf_c3_Low,
        Dehmf_c4_High,
        Dehmf_c4_Medium,
        Dehmf_c4_Low,

        Dgn,							//Gender: returns 1 if male
        Dgn_baseline,
        Dgn_Dag,
        Dgn_Les_c4_NotEmployed_L1,
        Dgn_Les_c4_Retired_L1,
        Dgn_Les_c4_Student_L1,
        Dgn_Lhw_L1,
        Dhe,							//Health status
        Dhe_Poor,
        Dhe_Fair,
        Dhe_Good,
        Dhe_VeryGood,
        Dhe_Excellent,
        Dhe_Poor_L1,
        Dhe_Fair_L1,
        Dhe_Good_L1,
        Dhe_VeryGood_L1,
        Dhe_Excellent_L1,
        Dhesp_L1, 						//Lag(1) of partner's health status
        Dhesp_Poor_L1,
        Dhesp_Fair_L1,
        Dhesp_Good_L1,
        Dhesp_VeryGood_L1,
        Dhesp_Excellent_L1,
        Dhhtp_c4_CoupleChildren_L1,
        Dhhtp_c4_CoupleNoChildren_L1,
        Dhhtp_c4_SingleChildren_L1,
        Dhhtp_c4_SingleNoChildren_L1,
        Dhhtp_c8_2_L1,
        Dhhtp_c8_3_L1,
        Dhhtp_c8_4_L1,
        Dhhtp_c8_5_L1,
        Dhhtp_c8_6_L1,
        Dhhtp_c8_7_L1,
        Dhhtp_c8_8_L1,
        Dhm,							//Mental health status
        Dhm_L1,							//Mental health status lag(1)
        Dhmghq_L1,
        Dlltsd,							//Long-term sick or disabled
        Dlltsd_L1,						//Long-term sick or disabled lag(1)
        Dlltsdsp_L1,
        Dnc_L1, 						//Lag(1) of number of children of all ages in the benefitUnit
        Dnc02_L1, 						//Lag(1) of number of children aged 0-2 in the benefitUnit
        Dnc017, 						//Number of children aged 0-17 in the benefitUnit
        EmployedToUnemployed,
        EquivalisedConsumptionYearly,
        EquivalisedIncomeYearly, 							//Equivalised income for use with the security index
        Female,
        FertilityRate,
        GrossEarningsYearly,
        GrossLabourIncomeMonthly,
        InverseMillsRatio,
        HUA, // Hungary
        HUB,
        HUC,
        ITC,			//Italy
        ITF,
        ITG,
        ITH,
        ITI,
        L1_hourly_wage,
        L1_log_hourly_wage,
        L1_log_hourly_wage_sq,
        Ld_children_2under,
        Ld_children_3under,
        Ld_children_4_12,
        Lemployed,
        Lhw_L1,
        Les_c3_Employed_L1,
        Les_c3_NotEmployed_L1,
        Les_c3_Sick_L1,					//This is based on dlltsd
        Les_c3_Student_L1,
        Les_c4_Student_L1,
        Les_c4_NotEmployed_L1,
        Les_c4_NotEmployed_Dgn,
        Les_c4_Retired_L1,
        Les_c4_Retired_Dgn,
        Les_c4_Student_Dgn,
        Les_c4_Student_L1_Dgn,
        Les_c4_NotEmployed_L1_Dgn,
        Les_c4_Retired_L1_Dgn,
        Les_c7_Covid_Furlough_L1,
        Lesdf_c4_BothNotEmployed_L1,
        Lesdf_c4_EmployedSpouseNotEmployed_L1, 					//Own and partner's activity status lag(1)
        Lesdf_c4_NotEmployedSpouseEmployed_L1,
        Lessp_c3_NotEmployed_L1,
        Lessp_c3_Sick_L1,
        Lessp_c3_Student_L1,			//Partner variables
        Liwwh,									//Work history in months
        LnAge,
        Lnonwork,
        Lstudent,
        Lunion,
        NeedCare_L1,
        NonPovertyToPoverty,
        NotEmployed_L1,
        NumberChildren,
        NumberChildren_2under,
        OtherIncome,
        Parents,
        PersistentPoverty,
        PersistentUnemployed,

        Post2015,

        PovertyToNonPoverty,
        Pt,
        Reached_Retirement_Age,						//Indicator whether individual is at or above retirement age
        Reached_Retirement_Age_Les_c3_NotEmployed_L1, //Interaction term for being at or above retirement age and not employed in the previous year
        Reached_Retirement_Age_Sp,					//Indicator whether spouse is at or above retirement age
        Elig_pen,     // Age == state retirement age
        Elig_pen_L1, // Age == state retirement age +1
        Elig_pen_Sp, // Partner's age == state retirement age
        Elig_pen_L1_Sp, // // Partner's age == state retirement age +1
        RealGDPGrowth,
        RealIncomeChange, //Note: the above return a 0 or 1 value, but income variables will return the change in income or 0
        RealIncomeDecrease_D,
        RealWageGrowth,
        ReceiveCare_L1,
        ResStanDev,
        Retired,
        sIndex,
        sIndexNormalised,
        Single,
        Single_kids,
        StatePensionAge,
        UnemployedToEmployed,
        UnemploymentRate,
        Union,
        Union_kids,

        PL4,
        PL5,
        PL6,
        PL10,
        EL3,
        EL4,
        EL7,
        Y2011,
        Y2012,
        Y2013,
        Y2014,
        Y2015,
        Y2016,
        Y2017,
        Y2018,
        Y2019,
        Y2020,
        Y2021,
        Y2022,
        Y2022_2023,
        Y2223,
        Y2023,

        Year,										//Year as in the simulation, e.g. 2009
        Year2010,
        Year2011,
        Year2012,
        Year2013,
        Year2014,
        Year2015,
        Year2016,
        Year2017,
        Year2018,
        Year2019,
        Year2020,
        Year2021,
        Year2022,
        Year2023,
        Year2024,
        Year2025,
        Year2026,
        Year2027,
        Year2028,
        Year2029,
        Year2030,
        Year2031,
        Year2032,
        Year2033,
        Year2034,
        Year2035,
        Year2036,
        Year2037,
        Year2038,
        Year2039,
        Year2040,
        Year2041,
        Year2042,
        Year2043,
        Year2044,
        Year2045,
        Year2046,
        Year2047,
        Year2048,
        Year2049,
        Year2050,
        Year2051,
        Year2052,
        Year2053,
        Year2054,
        Year2055,
        Year2056,
        Year2057,
        Year2058,
        Year2059,
        Year2060,
        Year2061,
        Year2062,
        Year2063,
        Year2064,
        Year2065,
        Year2066,
        Year2067,
        Year2068,
        Year2069,
        Year2070,
        Year2071,
        Year2072,
        Year2073,
        Year2074,
        Year2075,
        Year2076,
        Year2077,
        Year2078,
        Year2079,

        Ydses_c5_Q2_L1, 							//HH Income Lag(1) 2nd Quantile
        Ydses_c5_Q3_L1,								//HH Income Lag(1) 3rd Quantile
        Ydses_c5_Q4_L1,								//HH Income Lag(1) 4th Quantile
        Ydses_c5_Q5_L1,								//HH Income Lag(1) 5th Quantile
        Ydses_L1,
        Ydses_c5_L1,
        Year_transformed,							//Year - 2000
        Year_transformed_R1a,
        Year_transformed_R1b,
        Year_transformed_E1a,
        Year_transformed_E1b,
        Year_transformed_E2a,

        Year_transformed_sq,
        Year_transformed_sq_E1b,
        Year_transformed_sq_E2a,
        Year_transformed_monetary,					//Year-2000 that stops in 2017, for use with monetary processes
        Ynbcpdf_dv_L1, 								//Lag(1) of difference between own and partner's gross personal non-benefit income
        Yplgrs_dv_L1,								//Lag(1) of gross personal employment income
        Yplgrs_dv_L2,								//Lag(2) of gross personal employment income
        Yplgrs_dv_L3,								//Lag(3) of gross personal employment income
        Ypnbihs_dv_L1,								//Gross personal non-benefit income lag(1)
        Ypnbihs_dv_L1_sq,							//Square of gross personal non-benefit income lag(1)
        Ypncp_L1,									//Lag(1) of capital income
        Ypncp_L2,									//Lag(2) of capital income

        Ln_Ypncp_L1,
        Ln_Ypncp_L2,
        Ded_Ln_Ypncp_L1,
        Ded_Ln_Ypncp_L2,

        Ypnoab_L1,									//Lag(1) of pension income
        Ypnoab_L2,									//Lag(2) of pension income
        Yptciihs_dv_L1,								//Lag(1) of gross personal non-employment non-benefit income
        Yptciihs_dv_L2,								//Lag(2) of gross personal non-employment non-benefit income
        Yptciihs_dv_L3,								//Lag(3) of gross personal non-employment non-benefit income
        New_rel_L1,                                 // New relation indicator
    }

    public double getDoubleValue(Enum<?> variableID) {

        switch ((DoublesVariables) variableID) {

            case Age -> {
                return (double) demAge;
            }
            case Dag -> {
                return (double) demAge;
            }
            case Dag_sq -> {
                return (double) demAge * demAge;
            }


            case Dag_knot17 -> {
                return (double) Math.max(0, demAge - 17);
            }
            case Dag_knot23 -> {
                return (double) Math.max(0, demAge - 23);
            }
            case Dag_knot26 -> {
                return (double) Math.max(0, demAge - 26);
            }




            case LnAge -> {
                return Math.log(demAge);
            }
            case StatePensionAge -> {
                return (demAge >= 68) ? 1. : 0.;
            }
            case NeedCare_L1 -> {
                return (Indicator.True.equals(careNeedFlagL1)) ? 1. : 0.;
            }
            case ReceiveCare_L1 -> {
                return (getTotalHoursSocialCare_L1() > 0.01) ? 1. : 0.;
            }
            case Constant -> {
                return 1.;
            }
            case Dcpyy_L1 -> {
                return (demPartnerNYearL1 != null) ? (double) demPartnerNYearL1 : 0.0;
            }
            case Dcpagdf_L1 -> {
                return (demAgePartnerDiffL1 != null) ? (double) demAgePartnerDiffL1 : 0.0;
            }
            case Dcpst_Single -> {
                return (Dcpst.Single.equals(getDcpst())) ? 1.0 : 0.0;
            }
            case Dcpst_Partnered -> {
                return (Dcpst.Partnered.equals(getDcpst())) ? 1.0 : 0.0;
            }

            case Dcpst_Partnered_L1 -> {
                if (demPartnerStatusL1 != null) {
                    return demPartnerStatusL1.equals(Dcpst.Partnered) ? 1. : 0.;
                } else return 0.;
            }
            case Dcpst_Single_L1 -> {
                if (demPartnerStatusL1 != null) {
                    return demPartnerStatusL1.equals(Dcpst.Single) ? 1. : 0.;
                } else return 0.;
            }


            case Ded -> {
                return (Indicator.True.equals(eduSpellFlag)) ? 1.0 : 0.0;
            }
            case Ded_L1 -> {
                return (double) eduDedL1.getValue() ;
            }


            case Ded_Dgn -> {
                return (Indicator.True.equals(eduSpellFlag) && Gender.Male.equals(demMaleFlag)) ? 1.0 : 0.0;
            }

            case Ded_Dag -> {
                return Indicator.True.equals(eduSpellFlag) ? demAge : 0;
            }

            case Ded_Dag_sq -> {
                return Indicator.True.equals(eduSpellFlag) ? demAge*demAge : 0;
            }


            case Ded_Dcpst_Single -> {
                return (Indicator.True.equals(eduSpellFlag) && Dcpst.Single.equals(getDcpst())) ? 1.0 : 0.0;
            }

            case Ded_Dcpst_Single_L1 -> {
                if (demPartnerStatusL1 != null) {
                    return (Indicator.True.equals(eduSpellFlag) && Dcpst.Single.equals(demPartnerStatusL1)) ? 1.0 : 0.0;
                } else return 0.0;
            }

            case Ded_Dhe_VeryGood -> {
                return (Indicator.True.equals(eduSpellFlag) && Dhe.VeryGood.equals(getDhe())) ? 1.0 : 0.0;
            }



            case Ded_Dhe_Fair_L1 -> {
                return (Indicator.True.equals(eduSpellFlag) && Dhe.Fair.equals(healthSelfRatedL1)) ? 1. : 0.;
            }

            case Ded_Dhe_Good_L1 -> {
                return (Indicator.True.equals(eduSpellFlag) && Dhe.Good.equals(healthSelfRatedL1)) ? 1. : 0.;
            }

            case Ded_Dhe_VeryGood_L1 -> {
                return (Indicator.True.equals(eduSpellFlag) && Dhe.VeryGood.equals(healthSelfRatedL1)) ? 1. : 0.;
            }

            case Ded_Dhe_Excellent_L1 -> {
                return (Indicator.True.equals(eduSpellFlag) && Dhe.Excellent.equals(healthSelfRatedL1)) ? 1. : 0.;
            }

            case Ded_Ypncp_L2 -> {
                return (Indicator.True.equals(eduSpellFlag)) ? yCapitalPersMonthL2 : 0.;
            }


            case Ded_Ydses_c5_Q2_L1 -> {
                return (Indicator.True.equals(eduSpellFlag) && Ydses_c5.Q2.equals(getYdses_c5_lag1())) ? 1.0 : 0.0;
            }

            case Ded_Ydses_c5_Q3_L1 -> {
                return (Indicator.True.equals(eduSpellFlag) && Ydses_c5.Q3.equals(getYdses_c5_lag1())) ? 1.0 : 0.0;
            }
            case Ded_Ydses_c5_Q4_L1 -> {
                return (Indicator.True.equals(eduSpellFlag) && Ydses_c5.Q4.equals(getYdses_c5_lag1())) ? 1.0 : 0.0;
            }
            case Ded_Ydses_c5_Q5_L1 -> {
                return (Indicator.True.equals(eduSpellFlag) && Ydses_c5.Q5.equals(getYdses_c5_lag1())) ? 1.0 : 0.0;
            }
            case Ded_Yplgrs_dv_L1 -> {
                return Indicator.True.equals(eduSpellFlag) ? yEmpPersGrossMonthL1 : 0;
            }
            case Ded_Yplgrs_dv_L2 -> {
                return Indicator.True.equals(eduSpellFlag) ? yEmpPersGrossMonthL2 : 0;
            }
            case Ded_Ypncp_L1 -> {
                return Indicator.True.equals(eduSpellFlag) ? yCapitalPersMonthL1 : 0;
            }

            case Ded_Dnc_L1 -> {
                return Indicator.True.equals(eduSpellFlag) ? getNumberChildrenAll_lag1() : 0;
            }


            case Ded_Dnc02_L1 -> {
                return Indicator.True.equals(eduSpellFlag) ? getNumberChildren02_lag1() : 0;
            }



            case Deh_c3_Medium -> {
                return (Education.Medium.equals(eduHighestC4)) ? 1.0 : 0.0;
            }
            case Deh_c3_Low -> {
                return (Education.Low.equals(eduHighestC4) || Education.NotAssigned.equals(eduHighestC4)) ? 1.0 : 0.0;
            }
            case Deh_c4_High -> {
                return (Education.High.equals(eduHighestC4)) ? 1.0 : 0.0;
            }
            case Deh_c4_High_L1 -> {
                return (Education.High.equals(eduHighestC4L1)) ? 1.0 : 0.0;
            }
            case Deh_c4_Medium -> {
                return (Education.Medium.equals(eduHighestC4)) ? 1.0 : 0.0;
            }
            case Deh_c4_Medium_L1 -> {
                return (Education.Medium.equals(eduHighestC4L1)) ? 1.0 : 0.0;
            }
            case Deh_c4_Low -> {
                return (Education.Low.equals(eduHighestC4)) ? 1.0 : 0.0;
            }
            case Deh_c4_Low_L1 -> {
                return (Education.Low.equals(eduHighestC4L1)) ? 1.0 : 0.0;
            }
            case Deh_c4_Na -> {
                return (Education.NotAssigned.equals(eduHighestC4) && demAge <=18) ? 1.0 : 0.0;
            }
            case Deh_c4_Na_L1 -> {
                return (Education.NotAssigned.equals(eduHighestC4L1) && demAge <=19) ? 1.0 : 0.0;
            }
            case Dehm_c4_High -> {
                return (Education.High.equals(eduHighestMotherC4)) ? 1.0 : 0.0;
            }
            case Dehm_c4_Medium -> {
                return (Education.Medium.equals(eduHighestMotherC4)) ? 1.0 : 0.0;
            }
            case Dehm_c4_Low -> {
                return (Education.Low.equals(eduHighestMotherC4)) ? 1.0 : 0.0;
            }
            case Dehf_c4_High -> {
                return (Education.High.equals(eduHighestFatherC4)) ? 1.0 : 0.0;
            }
            case Dehf_c4_Medium -> {
                return (Education.Medium.equals(eduHighestFatherC4)) ? 1.0 : 0.0;
            }
            case Dehf_c4_Low -> {
                return (Education.Low.equals(eduHighestFatherC4)) ? 1.0 : 0.0;
            }
            case Dehmf_c3_High -> {
                return (checkHighestParentalEducationEquals(Education.High)) ? 1.0 : 0.0;
            }
            case Dehmf_c3_Medium -> {
                return (checkHighestParentalEducationEquals(Education.Medium)) ? 1.0 : 0.0;
            }
            case Dehmf_c3_Low -> {
                return (checkHighestParentalEducationEquals(Education.Low) || checkHighestParentalEducationEquals(Education.NotAssigned)) ? 1.0 : 0.0;
            }
            case Dehmf_c4_High -> {
                return (checkHighestParentalEducationEquals(Education.High)) ? 1.0 : 0.0;
            }
            case Dehmf_c4_Medium -> {
                return (checkHighestParentalEducationEquals(Education.Medium)) ? 1.0 : 0.0;
            }
            case Dehmf_c4_Low -> {
                return (checkHighestParentalEducationEquals(Education.Low)) ? 1.0 : 0.0;
            }
            case Dehsp_c4_Medium_L1 -> {
                return (Education.Medium.equals(eduDehspC4L1)) ? 1. : 0.;
            }
            case Dehsp_c4_Low_L1 -> {
                return (Education.Low.equals(eduDehspC4L1)) ? 1. : 0.;
            }
            case Dehsp_c4_High_L1 -> {
                return (Education.High.equals(eduDehspC4L1)) ? 1. : 0.;
            }

            case Dnc_L1 -> {
                return (double) getNumberChildrenAll_lag1();
            }
            case Dnc02_L1 -> {
                return (double) getNumberChildren02_lag1();
            }
            case Dnc017 -> {
                return (double) getNumberChildren017();
            }
            case Dgn -> {
                return (Gender.Male.equals(demMaleFlag)) ? 1.0 : 0.0;
            }


            case Dhe -> {
                return (double) healthSelfRated.getValue();
            }
            case Dhe_Excellent -> {
                return (Dhe.Excellent.equals(healthSelfRated)) ? 1. : 0.;
            }
            case Dhe_VeryGood -> {
                return (Dhe.VeryGood.equals(healthSelfRated)) ? 1. : 0.;
            }
            case Dhe_Good -> {
                return (Dhe.Good.equals(healthSelfRated)) ? 1. : 0.;
            }
            case Dhe_Fair -> {
                return (Dhe.Fair.equals(healthSelfRated)) ? 1. : 0.;
            }
            case Dhe_Poor -> {
                return (Dhe.Poor.equals(healthSelfRated)) ? 1. : 0.;
            }
            case Dhe_Excellent_L1 -> {
                return (Dhe.Excellent.equals(healthSelfRatedL1)) ? 1. : 0.;
            }
            case Dhe_VeryGood_L1 -> {
                return (Dhe.VeryGood.equals(healthSelfRatedL1)) ? 1. : 0.;
            }
            case Dhe_Good_L1 -> {
                return (Dhe.Good.equals(healthSelfRatedL1)) ? 1. : 0.;
            }
            case Dhe_Fair_L1 -> {
                return (Dhe.Fair.equals(healthSelfRatedL1)) ? 1. : 0.;
            }
            case Dhe_Poor_L1 -> {
                return (Dhe.Poor.equals(healthSelfRatedL1)) ? 1. : 0.;
            }
            case Dhesp_Excellent_L1 -> {
                return (Dhe.Excellent.equals(healthPartnerSelfRatedL1)) ? 1. : 0.;
            }
            case Dhesp_VeryGood_L1 -> {
                return (Dhe.VeryGood.equals(healthPartnerSelfRatedL1)) ? 1. : 0.;
            }
            case Dhesp_Good_L1 -> {
                return (Dhe.Good.equals(healthPartnerSelfRatedL1)) ? 1. : 0.;
            }
            case Dhesp_Fair_L1 -> {
                return (Dhe.Fair.equals(healthPartnerSelfRatedL1)) ? 1. : 0.;
            }
            case Dhesp_Poor_L1 -> {
                return (Dhe.Poor.equals(healthPartnerSelfRatedL1)) ? 1. : 0.;
            }
            case Dhm -> {
                return healthWbScore0to36;
            }
            case Dhm_L1 -> {
                if (healthWbScore0to36L1 != null && healthWbScore0to36L1 >= 0.) {
                    return healthWbScore0to36L1;
                } else return 0.;
            }
            case Dhmghq_L1 -> {
                return (getDhmGhq_lag1()) ? 1. : 0.;
            }
            case Dhesp_L1 -> {
                return (healthPartnerSelfRatedL1 != null) ? (double) healthPartnerSelfRatedL1.getValue() : 0.0;
            }
            case Dhhtp_c4_CoupleChildren_L1 -> {
                return (Dhhtp_c4.CoupleChildren.equals(getDhhtp_c4_lag1())) ? 1.0 : 0.0;
            }
            case Dhhtp_c4_CoupleNoChildren_L1 -> {
                return (Dhhtp_c4.CoupleNoChildren.equals(getDhhtp_c4_lag1())) ? 1.0 : 0.0;
            }
            case Dhhtp_c4_SingleNoChildren_L1 -> {
                return (Dhhtp_c4.SingleNoChildren.equals(getDhhtp_c4_lag1())) ? 1.0 : 0.0;
            }
            case Dhhtp_c4_SingleChildren_L1 -> {
                return (Dhhtp_c4.SingleChildren.equals(getDhhtp_c4_lag1())) ? 1.0 : 0.0;
            }
            case Dhhtp_c8_2_L1 -> {
                // Couple with no children, spouse student
                Person partner = getPartner();
                if (partner != null && partner.labC4L1 != null)
                    return (partner.labC4L1.equals(Les_c4.Student) && Dhhtp_c4.CoupleNoChildren.equals(getDhhtp_c4_lag1())) ? 1. : 0.;
                else
                    return 0.;
            }
            case Dhhtp_c8_3_L1 -> {
                // Couple with no children, spouse not employed
                Person partner = getPartner();
                if (partner != null && partner.labC4L1 != null)
                    return ((partner.labC4L1.equals(Les_c4.NotEmployed) || partner.labC4L1.equals(Les_c4.Retired)) && Dhhtp_c4.CoupleNoChildren.equals(getDhhtp_c4_lag1())) ? 1. : 0.;
                else
                    return 0.;
            }
            case Dhhtp_c8_4_L1 -> {
                // Couple with children, spouse employed
                Person partner = getPartner();
                if (partner != null && partner.labC4L1 != null)
                    return (partner.labC4L1.equals(Les_c4.EmployedOrSelfEmployed) && Dhhtp_c4.CoupleChildren.equals(getDhhtp_c4_lag1())) ? 1. : 0.;
                else
                    return 0.;
            }
            case Dhhtp_c8_5_L1 -> {
                // Couple with children, spouse student
                Person partner = getPartner();
                if (partner != null && partner.labC4L1 != null)
                    return (partner.labC4L1.equals(Les_c4.Student) && Dhhtp_c4.CoupleChildren.equals(getDhhtp_c4_lag1())) ? 1. : 0.;
                else
                    return 0.;
            }
            case Dhhtp_c8_6_L1 -> {
                // Couple with children, spouse not employed
                Person partner = getPartner();
                if (partner != null && partner.labC4L1 != null)
                    return ((partner.labC4L1.equals(Les_c4.NotEmployed) || partner.labC4L1.equals(Les_c4.Retired)) && Dhhtp_c4.CoupleChildren.equals(getDhhtp_c4_lag1())) ? 1. : 0.;
                else
                    return 0.;
            }
            case Dhhtp_c8_7_L1 -> {
                // Single with no children
                return Dhhtp_c4.SingleNoChildren.equals(getDhhtp_c4_lag1()) ? 1. : 0.;
            }
            case Dhhtp_c8_8_L1 -> {
                // Single with children
                return Dhhtp_c4.SingleChildren.equals(getDhhtp_c4_lag1()) ? 1. : 0.;
            }
            case Dlltsd -> {
                return Indicator.True.equals(healthDsblLongtermFlag) ? 1. : 0.;
            }
            case Dlltsd_L1 -> {
                return Indicator.True.equals(healthDsblLongtermFlagL1) ? 1. : 0.;
            }
            case Dlltsdsp_L1 -> {
                Person partner = getPartner();
                if (partner != null && partner.healthDsblLongtermFlagL1 != null) {
                    return Indicator.True.equals(partner.healthDsblLongtermFlagL1) ? 1. : 0.;
                }
                else return 0.;
            }

            case D_Children_2under -> {
                return (double) benefitUnit.getIndicatorChildren(0, 2).ordinal();
            }
            case D_Children_3_6 -> {
                return (double) benefitUnit.getIndicatorChildren(3, 6).ordinal();
            }
            case D_Children_7_12 -> {
                return (double) benefitUnit.getIndicatorChildren(7, 12).ordinal();
            }
            case D_Children_13_17 -> {
                return (double) benefitUnit.getIndicatorChildren(13, 17).ordinal();
            }
            case D_Children_18over -> {
                return (double) benefitUnit.getIndicatorChildren(18, 99).ordinal();
            }
            case D_Children -> {
                return (getNumberChildrenAll() > 0) ? 1. : 0.;
            }
            case D_Children_L1 -> {
                return (getNumberChildrenAll_lag1() > 0) ? 1. : 0.;
            }
            case FertilityRate -> {
                if (ioFlag)
                    return Parameters.getFertilityProjectionsByYear(getYear());
                else
                    return Parameters.getFertilityRateByRegionYear(getRegion(), getYear());
            }
            case Female -> {
                return demMaleFlag.equals(Gender.Female) ? 1. : 0.;
            }
            case GrossEarningsYearly -> {
                return getGrossEarningsYearly();
            }
            case GrossLabourIncomeMonthly -> {
                return getCovidModuleGrossLabourIncome_Baseline();
            }
            case InverseMillsRatio -> {
                return getInverseMillsRatio();
            }
            case Ld_children_2under -> {
                return (getNumberChildren02_lag1() > 0) ? 1.0 : 0.0;
            }
            case Ld_children_3under -> {
                return benefitUnit.getIndicatorChildren03_lag1().ordinal();
            }
            case Ld_children_4_12 -> {
                return benefitUnit.getIndicatorChildren412_lag1().ordinal();
            }
            case Lemployed -> {
                if (labC4L1 != null)        //Problem will null pointer exceptions for those who are inactive and then become active as their lagged employment status is null!
                    return labC4L1.equals(Les_c4.EmployedOrSelfEmployed) ? 1. : 0.;
                else
                    return 0.;
            }            //A person who was not active but has become active in this year should have an employment_status_lag == null.  In this case, we assume this means 0 for the Employment regression, where Lemployed is used.
            case Lnonwork -> {
                return (labC4L1.equals(Les_c4.NotEmployed) || labC4L1.equals(Les_c4.Retired)) ? 1. : 0.;
            }
            case Lstudent -> {
                //			log.debug("Lstudent");
                return labC4L1.equals(Les_c4.Student) ? 1. : 0.;
            }
            case Lunion -> {
                //			log.debug("Lunion");
                return demStatusHhL1.equals(HouseholdStatus.Couple) ? 1. : 0.;
            }
            case Les_c3_Student_L1 -> {
                return (Les_c4.Student.equals(labC4L1)) ? 1.0 : 0.0;
            }
            case Les_c4_Student_L1 -> {
                return (Les_c4.Student.equals(labC4L1)) ? 1.0 : 0.0;
            }
            case Les_c4_NotEmployed_L1 -> {
                return (Les_c4.NotEmployed.equals(labC4L1)) ? 1.0 : 0.0;
            }
            case Les_c4_NotEmployed_Dgn -> {
                return (Les_c4.NotEmployed.equals(labC4) && Gender.Male.equals(demMaleFlag)) ? 1.0 : 0.0;
            }

            case Les_c4_Retired_L1 -> {
                return (Les_c4.Retired.equals(labC4L1)) ? 1.0 : 0.0;
            }
            case Les_c4_Retired_Dgn -> {
                return (Les_c4.Retired.equals(labC4) && Gender.Male.equals(demMaleFlag)) ? 1.0 : 0.0;
            }
            case Les_c4_Student_Dgn -> {
                return (Les_c4.Student.equals(labC4) && Gender.Male.equals(demMaleFlag)) ? 1.0 : 0.0;
            }
            case Dgn_Les_c4_Student_L1, Les_c4_Student_L1_Dgn -> {
                return (Les_c4.Student.equals(labC4L1) && Gender.Male.equals(demMaleFlag)) ? 1.0 : 0.0;
            }
            case Dgn_Les_c4_NotEmployed_L1, Les_c4_NotEmployed_L1_Dgn -> {
                return (Les_c4.NotEmployed.equals(labC4L1) && Gender.Male.equals(demMaleFlag)) ? 1.0 : 0.0;
            }
            case Dgn_Les_c4_Retired_L1, Les_c4_Retired_L1_Dgn -> {
                return (Les_c4.Retired.equals(labC4L1) && Gender.Male.equals(demMaleFlag)) ? 1.0 : 0.0;
            }
            case Les_c3_NotEmployed_L1 -> {
                return ((Les_c4.NotEmployed.equals(labC4L1)) || (Les_c4.Retired.equals(labC4L1))) ? 1.0 : 0.0;
            }
            case Les_c3_Employed_L1 -> {
                return (Les_c4.EmployedOrSelfEmployed.equals(labC4L1)) ? 1.0 : 0.0;
            }
            case Les_c3_Sick_L1 -> {
                if (healthDsblLongtermFlagL1 != null)
                    return healthDsblLongtermFlagL1.equals(Indicator.True) ? 1. : 0.;
                else
                    return 0.0;
            }
            case Lessp_c3_Student_L1 -> {
                Person partner = getPartner();
                if (partner != null && partner.labC4L1 != null)
                    return partner.labC4L1.equals(Les_c4.Student) ? 1. : 0.;
                else
                    return 0.;
            }
            case Lessp_c3_NotEmployed_L1 -> {
                Person partner = getPartner();
                if (partner != null && partner.labC4L1 != null)
                    return (partner.labC4L1.equals(Les_c4.NotEmployed) || partner.labC4L1.equals(Les_c4.Retired)) ? 1. : 0.;
                else
                    return 0.;
            }
            case Lessp_c3_Sick_L1 -> {
                Person partner = getPartner();
                if (partner != null && partner.healthDsblLongtermFlagL1 != null)
                    return partner.healthDsblLongtermFlagL1.equals(Indicator.True) ? 1. : 0.;
                else
                    return 0.;
            }
            case Retired -> {
                return Les_c4.Retired.equals(labC4) ? 1. : 0.;
            }
            case Lesdf_c4_EmployedSpouseNotEmployed_L1 -> {                    //Own and partner's activity status lag(1)
                return (Lesdf_c4.EmployedSpouseNotEmployed.equals(labStatusPartnerAndOwnC4L1)) ? 1. : 0.;
            }
            case Lesdf_c4_NotEmployedSpouseEmployed_L1 -> {
                return (Lesdf_c4.NotEmployedSpouseEmployed.equals(labStatusPartnerAndOwnC4L1)) ? 1. : 0.;
            }
            case Lesdf_c4_BothNotEmployed_L1 -> {
                if (labStatusPartnerAndOwnC4L1 != null)
                    return labStatusPartnerAndOwnC4L1.equals(Lesdf_c4.BothNotEmployed) ? 1. : 0.;
                else
                    return 0.;
            }
            case Liwwh -> {
                return (double) labEmpNyear;
            }
            case NotEmployed_L1 -> {
                return (labC4L1.equals(Les_c4.NotEmployed)) ? 1. : 0.;
            }
            case NumberChildren -> {
                return (double) benefitUnit.getNumberChildrenAll();
            }
            case NumberChildren_2under -> {
                return (double) benefitUnit.getNumberChildren(0, 2);
            }
            case OtherIncome -> {            // "Other income corresponds to other benefitUnit incomes divided by 10,000." (From Bargain et al. (2014).  From employment selection equation.
                return 0.;
            }                // Other incomes "correspond to partner's and other family members' income as well as capital income of various sources."
            case Parents -> {
                return HouseholdStatus.Parents.equals(getHouseholdStatus()) ? 1. : 0.;
            }
            case ResStanDev -> {        //Draw from standard normal distribution will be multiplied by the value in the .xls file, which represents the standard deviation
                //If model.addRegressionStochasticComponent set to true, return a draw from standard normal distribution, if false return 0.
                return (model.addRegressionStochasticComponent) ?
                        Parameters.getStandardNormalDistribution().inverseCumulativeProbability(innovations.getDoubleDraw(20)) : 0.0;
            }
            case Single -> {
                return HouseholdStatus.Single.equals(getHouseholdStatus()) ? 1. : 0.;
            }
            case Single_kids -> {        //TODO: Is this sufficient, or do we need to take children aged over 12 into account as well?
                if (HouseholdStatus.Single.equals(getHouseholdStatus())) {
                    if (benefitUnit.getChildren().isEmpty())
                        return 0.0;
                    else
                        return 1.0;
                } else return 0.;
            }
            case UnemploymentRate -> {
                return getUnemploymentRateByGenderEducationAgeYear(getDgn(), getDeh_c4(), getDag(), getYear());
            }
            case Union -> {
                return HouseholdStatus.Couple.equals(getHouseholdStatus()) ? 1. : 0.;
            }
            case Union_kids -> {        //TODO: Is this sufficient, or do we need to take children aged over 12 into account as well?
                if (HouseholdStatus.Couple.equals(getHouseholdStatus())) {
                    if (benefitUnit.getChildren().isEmpty())
                        return 0.0;
                    else
                        return 1.0;
                } else return 0.0;
            }
            case Year -> {
                return (Parameters.isFixTimeTrend && getYear() >= Parameters.timeTrendStopsIn) ? (double) Parameters.timeTrendStopsIn : (double) getYear();
            }
            case Year2010 -> {
                return (getYear() <= 2010) ? 1. : 0.;
            }
            case Year2011, Y2011 -> {
                return (getYear() == 2011) ? 1. : 0.;
            }
            case Year2012, Y2012 -> {
                return (getYear() == 2012) ? 1. : 0.;
            }
            case Year2013, Y2013 -> {
                return (getYear() == 2013) ? 1. : 0.;
            }
            case Year2014, Y2014 -> {
                return (getYear() == 2014) ? 1. : 0.;
            }
            case Year2015, Y2015 -> {
                return (getYear() == 2015) ? 1. : 0.;
            }
            case Year2016, Y2016 -> {
                return (getYear() == 2016) ? 1. : 0.;
            }
            case Year2017, Y2017 -> {
                return (getYear() == 2017) ? 1. : 0.;
            }
            case Year2018, Y2018 -> {
                return (getYear() == 2018) ? 1. : 0.;
            }
            case Year2019, Y2019 -> {
                return (getYear() == 2019) ? 1. : 0.;
            }
            case Year2020, Y2020 -> {
                return (getYear() == 2020) ? 1. : 0.;
            }
            case Year2021, Y2021 -> {
                return (getYear() == 2021) ? 1. : 0.;
            }
            case Year2022, Y2022 -> {
                return (getYear() == 2022) ? 1. : 0.;
            }
            case Year2023, Y2023 -> {
                return (getYear() == 2023) ? 1. : 0.;
            }
            case Y2223, Y2022_2023 -> {
                return (getYear() == 2022 || getYear() == 2023) ? 1. : 0.;
            }

            case Year2024 -> {
                return (getYear() == 2024) ? 1. : 0.;
            }
            case Year2025 -> {
                return (getYear() == 2025) ? 1. : 0.;
            }
            case Year2026 -> {
                return (getYear() == 2026) ? 1. : 0.;
            }
            case Year2027 -> {
                return (getYear() == 2027) ? 1. : 0.;
            }
            case Year2028 -> {
                return (getYear() == 2028) ? 1. : 0.;
            }
            case Year2029 -> {
                return (getYear() == 2029) ? 1. : 0.;
            }
            case Year2030 -> {
                return (getYear() == 2030) ? 1. : 0.;
            }
            case Year2031 -> {
                return (getYear() == 2031) ? 1. : 0.;
            }
            case Year2032 -> {
                return (getYear() == 2032) ? 1. : 0.;
            }
            case Year2033 -> {
                return (getYear() == 2033) ? 1. : 0.;
            }
            case Year2034 -> {
                return (getYear() == 2034) ? 1. : 0.;
            }
            case Year2035 -> {
                return (getYear() == 2035) ? 1. : 0.;
            }
            case Year2036 -> {
                return (getYear() == 2036) ? 1. : 0.;
            }
            case Year2037 -> {
                return (getYear() == 2037) ? 1. : 0.;
            }
            case Year2038 -> {
                return (getYear() == 2038) ? 1. : 0.;
            }
            case Year2039 -> {
                return (getYear() == 2039) ? 1. : 0.;
            }
            case Year2040 -> {
                return (getYear() == 2040) ? 1. : 0.;
            }
            case Year2041 -> {
                return (getYear() == 2041) ? 1. : 0.;
            }
            case Year2042 -> {
                return (getYear() == 2042) ? 1. : 0.;
            }
            case Year2043 -> {
                return (getYear() == 2043) ? 1. : 0.;
            }
            case Year2044 -> {
                return (getYear() == 2044) ? 1. : 0.;
            }
            case Year2045 -> {
                return (getYear() == 2045) ? 1. : 0.;
            }
            case Year2046 -> {
                return (getYear() == 2046) ? 1. : 0.;
            }
            case Year2047 -> {
                return (getYear() == 2047) ? 1. : 0.;
            }
            case Year2048 -> {
                return (getYear() == 2048) ? 1. : 0.;
            }
            case Year2049 -> {
                return (getYear() == 2049) ? 1. : 0.;
            }
            case Year2050 -> {
                return (getYear() == 2050) ? 1. : 0.;
            }
            case Year2051 -> {
                return (getYear() == 2051) ? 1. : 0.;
            }
            case Year2052 -> {
                return (getYear() == 2052) ? 1. : 0.;
            }
            case Year2053 -> {
                return (getYear() == 2053) ? 1. : 0.;
            }
            case Year2054 -> {
                return (getYear() == 2054) ? 1. : 0.;
            }
            case Year2055 -> {
                return (getYear() == 2055) ? 1. : 0.;
            }
            case Year2056 -> {
                return (getYear() == 2056) ? 1. : 0.;
            }
            case Year2057 -> {
                return (getYear() == 2057) ? 1. : 0.;
            }
            case Year2058 -> {
                return (getYear() == 2058) ? 1. : 0.;
            }
            case Year2059 -> {
                return (getYear() == 2059) ? 1. : 0.;
            }
            case Year2060 -> {
                return (getYear() == 2060) ? 1. : 0.;
            }
            case Year2061 -> {
                return (getYear() == 2061) ? 1. : 0.;
            }
            case Year2062 -> {
                return (getYear() == 2062) ? 1. : 0.;
            }
            case Year2063 -> {
                return (getYear() == 2063) ? 1. : 0.;
            }
            case Year2064 -> {
                return (getYear() == 2064) ? 1. : 0.;
            }
            case Year2065 -> {
                return (getYear() == 2065) ? 1. : 0.;
            }
            case Year2066 -> {
                return (getYear() == 2066) ? 1. : 0.;
            }
            case Year2067 -> {
                return (getYear() == 2067) ? 1. : 0.;
            }
            case Year2068 -> {
                return (getYear() == 2068) ? 1. : 0.;
            }
            case Year2069 -> {
                return (getYear() == 2069) ? 1. : 0.;
            }
            case Year2070 -> {
                return (getYear() == 2070) ? 1. : 0.;
            }
            case Year2071 -> {
                return (getYear() == 2071) ? 1. : 0.;
            }
            case Year2072 -> {
                return (getYear() == 2072) ? 1. : 0.;
            }
            case Year2073 -> {
                return (getYear() == 2073) ? 1. : 0.;
            }
            case Year2074 -> {
                return (getYear() == 2074) ? 1. : 0.;
            }
            case Year2075 -> {
                return (getYear() == 2075) ? 1. : 0.;
            }
            case Year2076 -> {
                return (getYear() == 2076) ? 1. : 0.;
            }
            case Year2077 -> {
                return (getYear() == 2077) ? 1. : 0.;
            }
            case Year2078 -> {
                return (getYear() == 2078) ? 1. : 0.;
            }
            case Year2079 -> {
                return (getYear() >= 2079) ? 1. : 0.;
            }

            case Year_transformed -> {
                return (Parameters.isFixTimeTrend && getYear() >= Parameters.timeTrendStopsIn) ? (double) Parameters.timeTrendStopsIn - 2000 : (double) getYear() - 2000;
            }
            case Year_transformed_sq -> {
                return (Parameters.isFixTimeTrend && getYear() >= Parameters.timeTrendStopsIn) ? (double) (Parameters.timeTrendStopsIn - 2000)*(Parameters.timeTrendStopsIn - 2000) : (double) (getYear() - 2000)*(getYear() - 2000);
            }
            case Year_transformed_sq_E1b -> {
                return (Parameters.isFixTimeTrendE1b && getYear() >= Parameters.timeTrendStopsInE1b) ? (double) (Parameters.timeTrendStopsInE1b - 2000)*(Parameters.timeTrendStopsInE1b - 2000) : (double) (getYear() - 2000)*(getYear() - 2000);
            }
            case Year_transformed_sq_E2a -> {
                return (Parameters.isFixTimeTrendE2a && getYear() >= Parameters.timeTrendStopsInE2a) ? (double) (Parameters.timeTrendStopsInE2a - 2000)*(Parameters.timeTrendStopsInE2a - 2000) : (double) (getYear() - 2000)*(getYear() - 2000);
            }

            case Year_transformed_R1a -> {
                return (Parameters.isFixTimeTrendR1a && getYear() >= Parameters.timeTrendStopsInR1a) ? (double) Parameters.timeTrendStopsInR1a - 2000 : (double) getYear() - 2000;
            }
            case Year_transformed_R1b -> {
                return (Parameters.isFixTimeTrendR1b && getYear() >= Parameters.timeTrendStopsInR1b) ? (double) Parameters.timeTrendStopsInR1b - 2000 : (double) getYear() - 2000;
            }

            case Year_transformed_E1a -> {
                return (Parameters.isFixTimeTrendE1a && getYear() >= Parameters.timeTrendStopsInE1a) ? (double) Parameters.timeTrendStopsInE1a - 2000 : (double) getYear() - 2000;
            }
            case Year_transformed_E1b -> {
                return (Parameters.isFixTimeTrendE1b && getYear() >= Parameters.timeTrendStopsInE1b) ? (double) Parameters.timeTrendStopsInE1b - 2000 : (double) getYear() - 2000;
            }
            case Year_transformed_E2a -> {
                return (Parameters.isFixTimeTrendE2a && getYear() >= Parameters.timeTrendStopsInE2a) ? (double) Parameters.timeTrendStopsInE2a - 2000 : (double) getYear() - 2000;
            }


            case Year_transformed_monetary -> {
                return (double) model.getTimeTrendStopsInMonetaryProcesses() - 2000;
            } //Note: this returns base price year - 2000 (e.g. 17 for 2017 as base price year) and monetary variables are then uprated from 2017 level to the simulated year
            case Ydses_c5_Q2_L1 -> {
                return (Ydses_c5.Q2.equals(getYdses_c5_lag1())) ? 1.0 : 0.0;
            }
            case Ydses_c5_Q3_L1 -> {
                return (Ydses_c5.Q3.equals(getYdses_c5_lag1())) ? 1.0 : 0.0;
            }
            case Ydses_c5_Q4_L1 -> {
                return (Ydses_c5.Q4.equals(getYdses_c5_lag1())) ? 1.0 : 0.0;
            }
            case Ydses_c5_Q5_L1 -> {
                return (Ydses_c5.Q5.equals(getYdses_c5_lag1())) ? 1.0 : 0.0;
            }
            case Ydses_L1, Ydses_c5_L1 -> {
                if (getYdses_c5_lag1() != null) {
                    return (double) getYdses_c5_lag1().getValue();
                } else return 0.;
            }
            case Ypnbihs_dv_L1 -> {
                if (yNonBenPersGrossMonthL1 != null) {
                    return yNonBenPersGrossMonthL1;
                } else {
                    throw new RuntimeException("call to uninitialised ypnbihs_dv_lag1 in Person");
                }
            }
            case Ypnbihs_dv_L1_sq -> {
                if (yNonBenPersGrossMonthL1 != null) {
                    return yNonBenPersGrossMonthL1 * yNonBenPersGrossMonthL1;
                } else {
                    throw new RuntimeException("call to uninitialised ypnbihs_dv_lag1 in Person");
                }
            }
            case Ynbcpdf_dv_L1 -> {
                return (yPersAndPartnerGrossDiffMonthL1 != null) ? yPersAndPartnerGrossDiffMonthL1 : 0.0;
            }
            case Yptciihs_dv_L1 -> {
                return yMiscPersGrossMonthL1;
            }
            case Yptciihs_dv_L2 -> {
                return yMiscPersGrossMonthL2;
            }
            case Yptciihs_dv_L3 -> {
                return yMiscPersGrossMonthL3;
            }
            case New_rel_L1 -> {
                return (Dcpst.Partnered.equals(getDcpst()) &&
                        demPartnerStatusL1 != null &&
                        !Dcpst.Partnered.equals(demPartnerStatusL1)) ? 1. : 0.;
            }
            case Ypncp_L1 -> {
                return yCapitalPersMonthL1;
            }
            case Ypncp_L2 -> {
                return yCapitalPersMonthL2;
            }
            case Ln_Ypncp_L1 -> {

                return Math.log(Math.max(Math.sinh(yCapitalPersMonthL1), Parameters.EPS_YPNCP));
            }

            case Ln_Ypncp_L2 -> {
                return Math.log(Math.max(Math.sinh(yCapitalPersMonthL2), Parameters.EPS_YPNCP));
            }

            case Ded_Ln_Ypncp_L1 -> {
                double lnYpncp = Math.log(Math.max(Math.sinh(yCapitalPersMonthL1), Parameters.EPS_YPNCP));
                return (Indicator.True.equals(eduSpellFlag)) ? (lnYpncp) : 0.;
            }

            case Ded_Ln_Ypncp_L2 -> {
                double lnYpncp = Math.log(Math.max(Math.sinh(yCapitalPersMonthL2), Parameters.EPS_YPNCP));
                return (Indicator.True.equals(eduSpellFlag)) ? (lnYpncp) : 0.;
            }

            case Ypnoab_L1 -> {
                return yPensPersGrossMonthL1;
            }
            case Ypnoab_L2 -> {
                return yPensPersGrossMonthL2;
            }
            case Yplgrs_dv_L1 -> {
                return yEmpPersGrossMonthL1;
            }
            case Yplgrs_dv_L2 -> {
                return yEmpPersGrossMonthL2;
            }
            case Yplgrs_dv_L3 -> {
                return yEmpPersGrossMonthL3;
            }
            case Reached_Retirement_Age -> {
                int retirementAge;
                if (demMaleFlag.equals(Gender.Female)) {
                    retirementAge = (int) Parameters.getTimeSeriesValue(getYear(), Gender.Female.toString(), TimeSeriesVariable.FixedRetirementAge);
                } else {
                    retirementAge = (int) Parameters.getTimeSeriesValue(getYear(), Gender.Male.toString(), TimeSeriesVariable.FixedRetirementAge);
                }
                return (demAge >= retirementAge) ? 1. : 0.;
            }
            case Reached_Retirement_Age_Sp -> {
                int retirementAgePartner;
                Person partner = getPartner();
                if (partner != null) {
                    if (partner.demMaleFlag.equals(Gender.Female)) {
                        retirementAgePartner = (int) Parameters.getTimeSeriesValue(getYear(), Gender.Female.toString(), TimeSeriesVariable.FixedRetirementAge);
                    } else {
                        retirementAgePartner = (int) Parameters.getTimeSeriesValue(getYear(), Gender.Male.toString(), TimeSeriesVariable.FixedRetirementAge);
                    }
                    return (partner.demAge >= retirementAgePartner) ? 1. : 0.;
                } else {
                    return 0.;
                }
            }
            case Elig_pen -> { // Age == state retirement age
                int retirementAge;
                if (demMaleFlag.equals(Gender.Female)) {
                    retirementAge = (int) Parameters.getTimeSeriesValue(getYear(), Gender.Female.toString(), TimeSeriesVariable.FixedRetirementAge);
                } else {
                    retirementAge = (int) Parameters.getTimeSeriesValue(getYear(), Gender.Male.toString(), TimeSeriesVariable.FixedRetirementAge);
                }
                return (demAge == retirementAge) ? 1. : 0.;
            }
            case Elig_pen_L1 -> { // Age == state retirement age +1
                int retirementAge = 1;
                if (demMaleFlag.equals(Gender.Female)) {
                    retirementAge += (int) Parameters.getTimeSeriesValue(getYear(), Gender.Female.toString(), TimeSeriesVariable.FixedRetirementAge);
                } else {
                    retirementAge += (int) Parameters.getTimeSeriesValue(getYear(), Gender.Male.toString(), TimeSeriesVariable.FixedRetirementAge);
                }
                return (demAge == retirementAge) ? 1. : 0.;
            }

            case Elig_pen_Sp -> { // Partner's age == state retirement age
                int retirementAgePartner;
                Person partner = getPartner();
                if (partner != null) {
                    if (partner.demMaleFlag.equals(Gender.Female)) {
                        retirementAgePartner = (int) Parameters.getTimeSeriesValue(getYear(), Gender.Female.toString(), TimeSeriesVariable.FixedRetirementAge);
                    } else {
                        retirementAgePartner = (int) Parameters.getTimeSeriesValue(getYear(), Gender.Male.toString(), TimeSeriesVariable.FixedRetirementAge);
                    }
                    return (partner.demAge == retirementAgePartner) ? 1. : 0.;
                } else {
                    return 0.;
                }
            }
            case Elig_pen_L1_Sp -> { // Partner's age == state retirement age +1
                int retirementAgePartner = 1;
                Person partner = getPartner();
                if (partner != null) {
                    if (partner.demMaleFlag.equals(Gender.Female)) {
                        retirementAgePartner += (int) Parameters.getTimeSeriesValue(getYear(), Gender.Female.toString(), TimeSeriesVariable.FixedRetirementAge);
                    } else {
                        retirementAgePartner += (int) Parameters.getTimeSeriesValue(getYear(), Gender.Male.toString(), TimeSeriesVariable.FixedRetirementAge);
                    }
                    return (partner.demAge >= retirementAgePartner) ? 1. : 0.;
                } else {
                    return 0.;
                }
            }
            case Reached_Retirement_Age_Les_c3_NotEmployed_L1 -> { //Reached retirement age and was not employed in the previous year
                int retirementAge;
                if (demMaleFlag.equals(Gender.Female)) {
                    retirementAge = (int) Parameters.getTimeSeriesValue(getYear(), Gender.Female.toString(), TimeSeriesVariable.FixedRetirementAge);
                } else {
                    retirementAge = (int) Parameters.getTimeSeriesValue(getYear(), Gender.Male.toString(), TimeSeriesVariable.FixedRetirementAge);
                }
                return ((demAge >= retirementAge) && (labC4L1.equals(Les_c4.NotEmployed) || labC4L1.equals(Les_c4.Retired))) ? 1. : 0.;
            }
            case EquivalisedIncomeYearly -> {
                return getBenefitUnit().getEquivalisedDisposableIncomeYearly();
            }
            case EquivalisedConsumptionYearly -> {
                if (xEquivYear != null) {
                    return xEquivYear;
                } else return -9999.99;
            }
            case sIndex -> {
                return getsIndex();
            }
            case sIndexNormalised -> {
                return getsIndexNormalised();
            }

            //New enums for the mental health Step 1 and 2:
            case EmployedToUnemployed -> {
                return (labC4L1.equals(Les_c4.EmployedOrSelfEmployed) && labC4.equals(Les_c4.NotEmployed) && healthDsblLongtermFlag.equals(Indicator.False)) ? 1. : 0.;
            }
            case UnemployedToEmployed -> {
                return (labC4L1.equals(Les_c4.NotEmployed) && healthDsblLongtermFlagL1.equals(Indicator.False) && labC4.equals(Les_c4.EmployedOrSelfEmployed)) ? 1. : 0.;
            }
            case PersistentUnemployed -> {
                return (labC4.equals(Les_c4.NotEmployed) && labC4L1.equals(Les_c4.NotEmployed) && healthDsblLongtermFlag.equals(Indicator.False) && healthDsblLongtermFlagL1.equals(Indicator.False)) ? 1. : 0.;
            }
            case Post2015 -> {
                return (getYear() > 2015) ? 1. : 0.;
            }

            case NonPovertyToPoverty -> {
                if (benefitUnit.getAtRiskOfPoverty_lag1() != null) {
                    return (benefitUnit.getAtRiskOfPoverty_lag1() == 0 && benefitUnit.getAtRiskOfPoverty() == 1) ? 1. : 0.;
                } else return 0.;
            }
            case PovertyToNonPoverty -> {
                if (benefitUnit.getAtRiskOfPoverty_lag1() != null) {
                    return (benefitUnit.getAtRiskOfPoverty_lag1() == 1 && benefitUnit.getAtRiskOfPoverty() == 0) ? 1. : 0.;
                } else return 0.;
            }
            case PersistentPoverty -> {
                if (benefitUnit.getAtRiskOfPoverty_lag1() != null) {
                    return (benefitUnit.getAtRiskOfPoverty_lag1() == 1 && benefitUnit.getAtRiskOfPoverty() == 1) ? 1. : 0.;
                } else return 0.;
            }
            case RealIncomeChange -> {
                return (benefitUnit.getYearlyChangeInLogEDI());
            }
            case RealIncomeDecrease_D -> {
                return (benefitUnit.isDecreaseInYearlyEquivalisedDisposableIncome()) ? 1. : 0.;
            }
            case D_Econ_benefits -> {
                return isReceivesBenefitsFlag_L1() ? 1. : 0.;
            }
            case D_Home_owner -> {
                return getBenefitUnit().isDhhOwned() ? 1. : 0.;
            } // Evaluated at the level of a benefit unit. If required, can be changed to individual-level homeownership status.
            case Dhh_owned_L1 -> {
                return getBenefitUnit().isDhhOwned_lag1() ? 1. : 0.;
            }
            case Pt -> {
                return (getLabourSupplyHoursWeekly() > 0 && getLabourSupplyHoursWeekly() < Parameters.MIN_HOURS_FULL_TIME_EMPLOYED) ? 1. : 0.;
            }
            case L1_log_hourly_wage -> {
                if (labWageHrlyL1 == null) {
                    throw new RuntimeException("call to evaluate lag potential hourly earnings before initialisation");
                } else {
                    return Math.log(labWageHrlyL1);
                }
            }
            case L1_log_hourly_wage_sq -> {
                if (labWageHrlyL1 > 0) {
                    return Math.pow(Math.log(labWageHrlyL1), 2);
                } else {
                    throw new RuntimeException("call to evaluate lag potential hourly earnings before initialisation");
                }
            }
            case L1_hourly_wage -> {
                if (labWageHrlyL1 > 0) {
                    return labWageHrlyL1;
                } else {
                    throw new RuntimeException("call to evaluate lag potential hourly earnings before initialisation");
                }
            }
            case Deh_c3_Low_Dag -> {
                return (Education.Low.equals(eduHighestC4) || Education.NotAssigned.equals(eduHighestC4)) ? demAge : 0.0;
            }
            case Deh_c3_Medium_Dag -> {
                return (Education.Medium.equals(eduHighestC4)) ? demAge : 0.0;
            }
            case Deh_c4_Low_Dag -> {
                return (Education.Low.equals(eduHighestC4)) ? demAge : 0.0;
            }
            case Deh_c4_Medium_Dag -> {
                return (Education.Medium.equals(eduHighestC4)) ? demAge : 0.0;
            }
            // Hungary
            case HUA -> {
                return Region.HUA.equals(getRegion()) ? 1.0 : 0.0;
            }
            case HUB -> {
                return Region.HUB.equals(getRegion()) ? 1.0 : 0.0;
            }
            case HUC -> {
                return Region.HUC.equals(getRegion()) ? 1.0 : 0.0;
            }
            //Italy
            case ITC -> {
                return (getRegion().equals(Region.ITC)) ? 1. : 0.;
            }
            case ITF -> {
                return (getRegion().equals(Region.ITF)) ? 1. : 0.;
            }
            case ITG -> {
                return (getRegion().equals(Region.ITG)) ? 1. : 0.;
            }
            case ITH -> {
                return (getRegion().equals(Region.ITH)) ? 1. : 0.;
            }
            case ITI -> {
                return (getRegion().equals(Region.ITI)) ? 1. : 0.;
            }

            // Poland
            case PL4 -> {
                return Region.PL4.equals(getRegion()) ? 1.0 : 0.0;
            }
            case PL5 -> {
                return Region.PL5.equals(getRegion()) ? 1.0 : 0.0;
            }
            case PL6 -> {
                return Region.PL6.equals(getRegion()) ? 1.0 : 0.0;
            }
            case PL10 -> {
                return Region.PL10.equals(getRegion()) ? 1.0 : 0.0;
            }
            case EL3 -> {
                return Region.EL3.equals(getRegion()) ? 1.0 : 0.0;
            }
            case EL4 -> {
                return Region.EL4.equals(getRegion()) ? 1.0 : 0.0;
            }
            case EL7 -> {
                return Region.EL7.equals(getRegion()) ? 1.0 : 0.0;
            }
            // Regressors used in the Covid-19 labour market module below:
            case Dgn_Dag -> {
                if (demMaleFlag.equals(Gender.Male)) {
                    return (double) demAge;
                } else return 0.;
            }
            case Lhw_L1 -> {
                if (getNewWorkHours_lag1() != null) {
                    return getNewWorkHours_lag1();
                } else return 0.;
            }
            case Dgn_Lhw_L1 -> {
                if (getNewWorkHours_lag1() != null && demMaleFlag.equals(Gender.Male)) {
                    return getNewWorkHours_lag1();
                } else return 0.;
            }
            case Les_c7_Covid_Furlough_L1 -> {
                return (getLes_c7_covid_lag1().equals(Les_c7_covid.FurloughedFlex) || getLes_c7_covid_lag1().equals(Les_c7_covid.FurloughedFull)) ? 1. : 0.;
            }
            case Dgn_baseline -> {
                return 0.;
            }
            case RealWageGrowth -> { // Note: the values provided to the wage regression must be rebased to 2015, the default BASE_PRICE_YEAR.
                // When Ramsey supplies the secular wage trend, freeze this index at the last
                // in-sample year so the trend is not double-counted (see Parameters).
                int wageGrowthYear = getYear();
                if (Parameters.freezeWageGrowthForRamseyTrend && wageGrowthYear > Parameters.wageGrowthLastInSampleYear)
                    wageGrowthYear = Parameters.wageGrowthLastInSampleYear;
                return 100*Parameters.getTimeSeriesIndex(wageGrowthYear, UpratingCase.Earnings); //wage estimates use WageGrowth upscaled to 100 base
            }
            case RealGDPGrowth -> {
                return Parameters.getTimeSeriesIndex(getYear(), UpratingCase.Capital);
            }
            default -> {
                throw new IllegalArgumentException("Unsupported regressor " + variableID.name() + " in Person#getDoubleValue");
            }
        }
    }




    ////////////////////////////////////////////////////////////////////////////////
    //
    //	Override equals and hashCode to make unique BenefitUnit determined by Key.getId()
    //
    ////////////////////////////////////////////////////////////////////////////////

     @Override
    public boolean equals(Object o) {

        if (o == this) return true;
        if (!(o instanceof Person)) {
            return false;
        }

        Person p = (Person) o;

        boolean idIsEqual = new EqualsBuilder()
                .append(key.getId(), p.key.getId())		//Add more fields to compare to check for equality if desired
                .isEquals();

        return idIsEqual;
    }

    @Override
    public int hashCode() {
        return new HashCodeBuilder(17, 37)
                .append(key.getId())
                .toHashCode();
    }


    /**
     * 
     * Returns a defensive copy of the field.
     * The caller of this method can do anything they want with the
     * returned Key object, without affecting the internals of this
     * class in any way.
     * 
     */
     public PanelEntityKey getKey() {
       return new PanelEntityKey(key.getId());
     }

     public int getPersonCount() {
        return 1;
     }

    public int getDag() {
        return demAge;
    }

    public void setDag(Integer demAge) {
        this.demAge = demAge;
    }

    public Gender getDgn() {
        return demMaleFlag;
    }

    public int getGender() {
         if (demMaleFlag == Gender.Male) return 0;
         else return 1;
    }

    public void setDgn(Gender demMaleFlag) {
        this.demMaleFlag = demMaleFlag;
    }

    public Les_c4 getLes_c4() {
        return labC4;
    }

    public int getStudent() {
        return Les_c4.Student.equals(labC4)? 1 : 0;
    }

    public int getEducation() {

        if (eduHighestC4 ==Education.Medium) return 1;
        else if (eduHighestC4 ==Education.High) return (int)(DecisionParams.PTS_EDUCATION - 1.0);
        else return 0; // case for Low or NotAssigned Education
    }

    public void setLes_c4(Les_c4 labC4) {
        this.labC4 = labC4;
    }


    public void setLes_c7_covid(Les_c7_covid labC7Covid) { this.labC7Covid = labC7Covid; }

    public Les_c7_covid getLes_c7_covid() { return labC7Covid; }

    public Les_c4 getLes_c4_lag1() {
        return labC4L1;
    }

    public int getEmployed_Lag1() {
        return (Les_c4.EmployedOrSelfEmployed.equals(labC4L1)) ? 1 : 0;
    }

    public Les_c7_covid getLes_c7_covid_lag1() { return labC7CovidL1; }

    public void setLes_c7_covid_lag1(Les_c7_covid labC7CovidL1) {
         this.labC7CovidL1 = labC7CovidL1;
    }

    public HouseholdStatus getHouseholdStatus() {
         Household household = benefitUnit.getHousehold();
         if (household.getBenefitUnits().size()>1 && (idMother!=null || idFather!=null)) {
             for (BenefitUnit unit : household.getBenefitUnits()) {
                 if (unit != benefitUnit) {
                     for (Person member : unit.getMembers()) {
                         if (idMother!=null && member.getId()==idMother)
                             return HouseholdStatus.Parents;
                         if (idFather!=null && member.getId()==idFather)
                             return HouseholdStatus.Parents;
                     }
                 }
             }
         }
        if (benefitUnit.getCoupleBoolean())
            return HouseholdStatus.Couple;
        else
            return HouseholdStatus.Single;
    }

    public int getCohabiting() {
        return benefitUnit.getCoupleDummy();
    }

    public Education getDeh_c4() {
        return eduHighestC4;
    }

    public void setDeh_c4(Education deh_c3) {
         this.eduHighestC4 = deh_c3;
     }

    public void setDeh_c4_lag1(Education eduHighestC4L1) {
         this.eduHighestC4L1 = eduHighestC4L1;
     }

    public Education getDehm_c4() {
        return eduHighestMotherC4;
    }

    public void setDehm_c4(Education dehm_c3) {
        this.eduHighestMotherC4 = dehm_c3;
    }

    public Education getDehf_c4() {
        return eduHighestFatherC4;
    }

    public void setDehf_c4(Education dehf_c3) {
        this.eduHighestFatherC4 = dehf_c3;
    }

    public Indicator getDed() {
        return eduSpellFlag;
    }

    public Indicator getDed_lag1() {
        return eduDedL1;
    }

    public void setDed(Indicator eduSpellFlag) {
        this.eduSpellFlag = eduSpellFlag;
    }

    public void setDed_lag1(Indicator eduDedL1) {
        this.eduDedL1 = eduDedL1;
    }


    public int getLeaveSchool() {
        if(eduLeaveSchoolFlag != null && eduLeaveSchoolFlag == true) {
            return 1;
        }
        else {
            return 0;
        }
    }

    public int getLowEducation() {
        if(eduHighestC4 != null) {
            if (eduHighestC4.equals(Education.Low)) return 1;
            else return 0;
        }
        else {
            return 0;
        }
    }

    public int getMidEducation() {
        if(eduHighestC4 != null) {
            if (eduHighestC4.equals(Education.Medium)) return 1;
            else return 0;
        }
        else {
            return 0;
        }
    }

    public int getHighEducation() {
        if(eduHighestC4 != null) {
            if (eduHighestC4.equals(Education.High)) return 1;
            else return 0;
        }
        else {
            return 0;
        }
    }

    public void setEducation(Education educationlevel) {
        this.eduHighestC4 = educationlevel;
    }

    public int getGoodHealth() {
        if(healthDsblLongtermFlag != null && !healthDsblLongtermFlag.equals(Indicator.True)) { //Good / bad health depends on dlltsd (long-term sick or disabled). If true, then person is in bad health.
            return 1;
        }
        else return 0;
    }

    public int getBadHealth() {
        if(healthDsblLongtermFlag != null && healthDsblLongtermFlag.equals(Indicator.True)) {
            return 1;
        }
        else return 0;
    }

    /*
     * In the initial population, there is continuous health score and an indicator for long-term sickness or disability. In EUROMOD to which we match, health is either
     * Good or Poor. This method checks the Dlltsd indicator and returns corresponding HealthStatus to use in matching the EUROMOD donor.
     */
    public HealthStatus getHealthStatusConversion() {
        if(healthDsblLongtermFlag != null && healthDsblLongtermFlag.equals(Indicator.True)) {
            return HealthStatus.Poor; //If long-term sick or disabled, return Poor HealthStatus
        }
        else return HealthStatus.Good; //Otherwise, return Good HealthStatus
    }

    public int getEmployed() {
        return (Les_c4.EmployedOrSelfEmployed.equals(labC4)) ? 1 : 0;
    }

    public int getNonwork() {
        return (Les_c4.NotEmployed.equals(labC4)) ? 1 : 0;
    }

    public void setRegionLocal(Region region) {
        i_demRgn = region;
    }

    public Region getRegion() {
        if (benefitUnit == null) {
            if (i_demRgn==null)
                throw new RuntimeException("attempt to access regionLocal before it has been assigned");
            return i_demRgn;
        } else {
            return benefitUnit.getRegion();
        }
    }

    public void setRegion(Region region) {
        this.benefitUnit.setRegion(region);
    }

    public HouseholdStatus getHousehold_status_lag() {
        return demStatusHhL1;
    }

//	public double getDeviationFromMeanRetirementAge() {
//		return deviationFromMeanRetirementAge;
//	}

    public boolean isToGiveBirth() {
        return demGiveBirthFlag;
    }

    public void setToGiveBirth(boolean toGiveBirth_) {
            demGiveBirthFlag = toGiveBirth_;
    }

    public Boolean getToRetire() {
        return labToRetire;
    }

    public void setToRetire(Boolean labToRetire) {
        this.labToRetire = labToRetire;
    }

    public boolean isToLeaveSchool() {
        return eduLeaveSchoolFlag;
    }

    public void setToLeaveSchool(boolean eduLeaveSchoolFlag) {
        this.eduLeaveSchoolFlag = eduLeaveSchoolFlag;
    }

    public double getWeight() {
        return wgtCrossMainSurvey;
    }

    public void setWeight(double wgtCrossMainSurvey) {
        this.wgtCrossMainSurvey = wgtCrossMainSurvey;
    }

    public BenefitUnit getBenefitUnit() {
        if (benefitUnit == null) {
            return null;
        } else {
            return benefitUnit;
        }
    }

    public void setBenefitUnit(BenefitUnit newBenefitUnit) {

        if (benefitUnit!=null && !benefitUnit.equals(newBenefitUnit)) {
            benefitUnit.removeMember(this);
        }

        benefitUnit = newBenefitUnit;
        idBu = benefitUnit.getId();
        if (newBenefitUnit == null)
            idHh = null;
        else  {
            if (newBenefitUnit.getHousehold()==null)
                throw new RuntimeException("problem identifying household of benefit unit");
            idHh = newBenefitUnit.getHousehold().getId();
            benefitUnit.getMembers().add(this);
        }
    }

    public Person getPartner() {

        if (demAge >= Parameters.AGE_TO_BECOME_RESPONSIBLE) {

            for (Person member : benefitUnit.getMembers()) {

                boolean accept = true;
                if (member==this || member.getDag()<Parameters.AGE_TO_BECOME_RESPONSIBLE)
                    accept = false;
                if (idMother!=null && member.getId()==idMother)
                    accept = false;
                if (idFather!=null && member.getId()==idFather)
                    accept = false;
                if (accept)
                    return member;
            }
        }
        return null;
    }

    public Person getMotherImmutable() {
        if (idMotherImmutable == null) {
            return null;
        }

        for (Person member : model.getPersons()) {
            // Use equals() and guard against nulls
            if (idMotherImmutable.equals(member.getIdOriginalPerson())) {
                return member;
            }
        }

        return null;
    }

    public Person getFatherImmutable() {
        if (idFatherImmutable == null) {
            return null;
        }

        for (Person member : model.getPersons()) {
            // Use equals() and guard against nulls
            if (idFatherImmutable.equals(member.getIdOriginalPerson())) {
                return member;
            }
        }

        return null;
    }

    public Person getMother() {
        if (idMother == null) {
            return null;
        }

        for (Person member : model.getPersons()) {
            // Use equals() and guard against nulls
            if (idMother.equals(member.getId())) {
                return member;
            }
        }

        return null;
    }

    public Person getFather() {
        if (idFather == null) {
            return null;
        }

        for (Person member : model.getPersons()) {
            // Use equals() and guard against nulls
            if (idFather.equals(member.getId())) {
                return member;
            }
        }

        return null;
    }


    public Long getPartnerID() {
        Person partner = this.getPartner();
        if (partner != null) {
            return partner.getId();
        } else return null;
    }

    private void nullPartnerVariables() {

        careHrsFromPartnerWeek = 0.0;
        demPartnerNYear = 0;
        if (SocialCareProvision.OnlyPartner.equals(careProvidedFlag))
            careProvidedFlag = SocialCareProvision.None;
        else if (SocialCareProvision.PartnerAndOther.equals(careProvidedFlag))
            careProvidedFlag = SocialCareProvision.OnlyOther;
    }

    public Labour getLabourSupplyWeekly() {
        if (labHrsWorkEnumWeek==null)
            throw new RuntimeException("request for labourSupplyWeekly before it has been initialised");
        return labHrsWorkEnumWeek;
    }

    public Labour getLabourSupplyWeekly_L1() {
        return labHrsWorkEnumWeekL1;
    }

    public int getL1LabourSupplyHoursWeekly() {
        if (labHrsWorkEnumWeekL1==null)
            throw new RuntimeException("request for labourSupplyWeekly_L1 before it has been initialised");
        return labHrsWorkEnumWeekL1.getHours(this);
    }

    public int getLabourSupplyHoursWeekly() {
        return (labHrsWorkEnumWeek != null) ? labHrsWorkEnumWeek.getHours(this) : 0;
    }

    public double getDoubleLabourSupplyHoursWeekly() {
        // this method is needed for the stupid observer
        return (double)getLabourSupplyHoursWeekly();
    }

    public void setLabourSupplyWeekly(Labour labourSupply) {
        labHrsWorkEnumWeek = labourSupply;
        if (labHrsWorkEnumWeek != null && labHrsWorkEnumWeek != Labour.ZERO) {
            String country = Parameters.COUNTRY_STRING;
            if (country != null && !country.isEmpty()) {
                String expectedPrefix = "CATEGORY_" + country + "_";
                String name = labHrsWorkEnumWeek.name();
                if (name.startsWith("CATEGORY_") && !name.startsWith(expectedPrefix)) {
                    throw new IllegalStateException("Non-" + country + " labour category assigned: " + labHrsWorkEnumWeek);
                }
            }
        }
        labHrsWorkWeek = getLabourSupplyHoursWeekly(); // Update number of hours worked weekly
    }

    public double getLabourSupplyHoursYearly() {
        return (double) getLabourSupplyHoursWeekly() * Parameters.WEEKS_PER_YEAR;
    }

    public double getScaledLabourSupplyYearly() {
        return getLabourSupplyHoursYearly() * model.getScalingFactor();
    }


    public double getGrossEarningsWeekly() {
        return labWageHrly * (double) getLabourSupplyHoursWeekly();
    }

    public double getGrossEarningsYearly() {
        Double gew = getGrossEarningsWeekly();
        if(Double.isFinite(gew) && gew > 0.) {
            return gew * Parameters.WEEKS_PER_YEAR;
        }
        else return 0.;
//		else return null;
    }

    public int getAtRiskOfPoverty() {
        return benefitUnit.getAtRiskOfPoverty();
    }

    public double getFullTimeHourlyEarningsPotential() {
        return labWageHrly;
    }

    public double getDesiredAgeDiff() {
        return demAgeDiffDesired;
    }

    public double getDesiredEarningsPotentialDiff() {
        return yWageDesired;
    }

    public Dhe getDhe() {
        return healthSelfRated;
    }

    public void setDhe(Dhe health) {
        this.healthSelfRated = health;
    }

    public double getDheValue() {
        return (double)healthSelfRated.getValue();
    }
    public double getDhm() {
        double val;
        if (healthWbScore0to36 == null) {
            val = -1.0;
        } else {
            val = healthWbScore0to36;
        }
        return val;
    }

    public void populateSocialCareReceipt(SocialCareReceiptState state) {
        if (SocialCareReceiptState.NoFormal.equals(state)) {
            careNeedFlag = Indicator.True;
            careReceivedFlag = SocialCareReceipt.Informal;
            careHrsFromOtherWeek = 10.0;
            careFromOtherFlag = true;
        } else if (SocialCareReceiptState.Mixed.equals(state)) {
            careNeedFlag = Indicator.True;
            careReceivedFlag = SocialCareReceipt.Mixed;
            careHrsFromOtherWeek = 10.0;
            careHrsFormalWeek = 10.0;
            xCareFormalWeek = 100.0;
            careFormalFlag = true;
            careFromOtherFlag = true;
        } else if (SocialCareReceiptState.Formal.equals(state)) {
            careNeedFlag = Indicator.True;
            careReceivedFlag = SocialCareReceipt.Formal;
            careHrsFormalWeek = 10.0;
            xCareFormalWeek = 100.0;
            careFormalFlag = true;
        }
    }

    public void populateSocialCareReceipt_lag1(SocialCareReceiptState state) {
        if (SocialCareReceiptState.NoFormal.equals(state)) {
            careNeedFlagL1 = Indicator.True;
            careHrsFromOtherWeekL1 = 10.0;
        } else if (SocialCareReceiptState.Mixed.equals(state)) {
            careNeedFlagL1 = Indicator.True;
            careHrsFromOtherWeekL1 = 10.0;
            careHrsFormalWeekL1 = 10.0;
        } else if (SocialCareReceiptState.Formal.equals(state)) {
            careNeedFlagL1 = Indicator.True;
            careHrsFormalWeekL1 = 10.0;
        }
    }

    public void setSocialCareFromOther(boolean val) {
        careFromOtherFlag = val;
    }

    public void setCareHoursFromOtherWeekly_lag1(double val) {
        careHrsFromOtherWeekL1 = val;
    }

    public void setCareHoursFromFormalWeekly_lag1(double val) {
        careHrsFormalWeekL1 = val;
    }
    public void setSocialCareProvision_lag1(SocialCareProvision careProvision) {
        careProvidedFlagL1 = careProvision;
    }

    public void setDhm(Double healthWbScore0to36) {
        this.healthWbScore0to36 = healthWbScore0to36;
    }

    public void setDhe_lag1(Dhe health) {
        this.healthSelfRatedL1 = health;
    }

    public void setDhm_lag1(Double healthWbScore0to36) {
        this.healthWbScore0to36L1 = healthWbScore0to36;
    }

    public boolean getDhmGhq() {
        return healthDhmGhq;
    }

    public void setDhmGhq(boolean dhm_ghq) {
        this.healthDhmGhq = dhm_ghq;
    }

    public Indicator getNeedSocialCare() {
        return careNeedFlag;
    }

    public void setNeedSocialCare(Indicator careNeedFlag) {
        this.careNeedFlag = careNeedFlag;
    }

    public Indicator getDer() {
        return eduReturnFlag;
    }

    public Indicator getSedex() {
        return eduExitSampleFlag; }

    public void setDer(Indicator eduReturnFlag) {
        this.eduReturnFlag = eduReturnFlag;
    }

    public Long getIdOriginalPerson() {
        return idPersOriginal;
    }

    public Long getIdOriginalBU() {
        return idBuOriginal;
    }

    public Long getIdOriginalHH() {
        return idHhOriginal;
    }

    public int getAgeGroup() {
        return demAgeGroup;
    }

    public boolean isClonedFlag() {
        return demClonedFlag;
    }

    public void setClonedFlag(boolean demClonedFlag) {
        this.demClonedFlag = demClonedFlag;
    }

    public Dcpst getDcpst() {
        if (benefitUnit==null) {
            if (i_demPartnerStatus==null)
                throw new RuntimeException("attempt to access unassigned value for dcpstLocal");
            return i_demPartnerStatus;
        }
        if (getPartner()!=null)
            return Dcpst.Partnered;
        else {return Dcpst.Single;}
    }

    public void setDcpstLocal(Dcpst demPartnerStatus) {
        this.i_demPartnerStatus = demPartnerStatus;
    }

    public Indicator getDlltsd() {
        return healthDsblLongtermFlag;
    }
    public void setDlltsd(Indicator healthDsblLongtermFlag) {
        this.healthDsblLongtermFlag = healthDsblLongtermFlag;
    }

    public void setSocialCareReceipt(SocialCareReceipt who) {
        careReceivedFlag = who;
    }

    public void setSocialCareProvision(SocialCareProvision who) {
        careProvidedFlag = who;
    }

    public Indicator getDlltsd_lag1() {
        return healthDsblLongtermFlagL1;
    }

    public void setDlltsd_lag1(Indicator healthDsblLongtermFlagL1) {
        this.healthDsblLongtermFlagL1 = healthDsblLongtermFlagL1;
    }

    public void setSedex(Indicator eduExitSampleFlag) {
        this.eduExitSampleFlag = eduExitSampleFlag;
    }

    public boolean isLeftEducation() {
        return eduLeftEduFlag;
    }

    public void setLeftEducation(boolean eduLeftEduFlag) {
        this.eduLeftEduFlag = eduLeftEduFlag;
    }

    public boolean isLeftPartnership() {
        return demLeftPartnerFlag;
    }

    public void setLeftPartnership(boolean demLeftPartnerFlag) {
        this.demLeftPartnerFlag = demLeftPartnerFlag;
    }

    public Integer getDcpyy() {
        return demPartnerNYear;
    }

    public void setDcpyy(Integer demPartnerNYear) {
        this.demPartnerNYear = demPartnerNYear;
    }

    public Integer getDcpagdf() {
        Person partner = getPartner();
        if (partner!=null)
            return (demAge - partner.demAge);
        else
            return null;
    }

    public Double getYpnbihs_dv() {
        return yNonBenPersGrossMonth;
    }

    public void setYpnbihs_dv(Double val) {
        yNonBenPersGrossMonth = val;
    }

    public Double getYdispPersInitial() {
        return yPersDispMonth;
    }

    public Double getYpnbihs_dv_lag1() {
        return yNonBenPersGrossMonthL1;
    }

    public double getYptciihs_dv() {
        return yMiscPersGrossMonth;
    }

    public double getYpncp() {
        return yCapitalPersMonth;
    }

    public double getYpnoab() {
        return yPensPersGrossMonth;
    }

    public void setYptciihs_dv(double yMiscPersGrossMonth) {
        this.yMiscPersGrossMonth = yMiscPersGrossMonth;
        if (Double.isNaN(this.yMiscPersGrossMonth) || Double.isInfinite(this.yMiscPersGrossMonth)) throw new IllegalArgumentException("yptciihs_dv is not finite");
    }

    public double getYptciihs_dv_lag1() {
        return yMiscPersGrossMonthL1;
    }

    public double getYplgrs_dv() {
        return (yEmpPersGrossMonth!=null) ? yEmpPersGrossMonth : 0.0;
    }

    public void setYplgrs_dv(double val) {
        yEmpPersGrossMonth = val;
    }

    public double getYplgrs_dv_lag1() {
        return yEmpPersGrossMonthL1;
    }

    public double getYplgrs_dv_lag2() {
        return yEmpPersGrossMonthL2;
    }

    public double getYplgrs_dv_lag3() {
        return yEmpPersGrossMonthL3;
    }

    public Double getYnbcpdf_dv_lag1() {
        return yPersAndPartnerGrossDiffMonthL1;
    }

    public Lesdf_c4 getLesdf_c4() {
        if (benefitUnit.getCoupleBoolean() && demAge>=Parameters.AGE_TO_BECOME_RESPONSIBLE) {
            if (getPartner()==null)
                throw new RuntimeException("inconsistency between couple and partner identifiers");
            if (Les_c4.EmployedOrSelfEmployed.equals(labC4) && Les_c4.EmployedOrSelfEmployed.equals(getPartner().labC4))
                return Lesdf_c4.BothEmployed;
            else if (Les_c4.EmployedOrSelfEmployed.equals(labC4))
                return Lesdf_c4.EmployedSpouseNotEmployed;
            else if (Les_c4.EmployedOrSelfEmployed.equals(getPartner().labC4))
                return Lesdf_c4.NotEmployedSpouseEmployed;
            else
                return Lesdf_c4.BothNotEmployed;
        }
        return null;
    }

    public Lesdf_c4 getLesdf_c4_lag1() {
        return labStatusPartnerAndOwnC4L1;
    }

    public void setLes_c4_lag1(Les_c4 labC4L1) {
        this.labC4L1 = labC4L1;
    }

    public void setLesdf_c4_lag1(Lesdf_c4 labStatusPartnerAndOwnC4L1) {
        this.labStatusPartnerAndOwnC4L1 = labStatusPartnerAndOwnC4L1;
    }

    public void setYpnbihs_dv_lag1(Double val) {
        yNonBenPersGrossMonthL1 = val;
    }

    public void setDehsp_c4_lag1(Education eduDehspC4L1) {
        this.eduDehspC4L1 = eduDehspC4L1;
    }

    public void setDhesp_lag1(Dhe healthPartnerSelfRatedL1) {
        this.healthPartnerSelfRatedL1 = healthPartnerSelfRatedL1;
    }

    public void setYnbcpdf_dv_lag1(Double val) {
        yPersAndPartnerGrossDiffMonthL1 = val;
    }

    public void setDcpyy_lag1(Integer demPartnerNYearL1) {
        this.demPartnerNYearL1 = demPartnerNYearL1;
    }

    public void setDcpagdf_lag1(Integer demAgePartnerDiffL1) {
        this.demAgePartnerDiffL1 = demAgePartnerDiffL1;
    }

    public void setDcpst_lag1(Dcpst demPartnerStatusL1) {
        this.demPartnerStatusL1 = demPartnerStatusL1;
    }

    public void setFullTimeHourlyEarningsPotential(double potentialHourlyEarnings) {
        this.labWageHrly = potentialHourlyEarnings;
    }

    public double getL1_fullTimeHourlyEarningsPotential() {
        return labWageHrlyL1;
    }

    public void setL1_fullTimeHourlyEarningsPotential(double potentialHourlyEarnings) {
        labWageHrlyL1 = potentialHourlyEarnings;
    }


    public void setLiwwh(Integer labEmpNyear) {
        this.labEmpNyear = labEmpNyear;
    }

    public int getLiwwh() {
        return labEmpNyear != null? labEmpNyear : 0 ;
    }

    public void setIoFlag(boolean ioFlag) {
        this.ioFlag = ioFlag;
    }

    public boolean isToBePartnered() {
        return demBePartnerFlag != null && demBePartnerFlag;
    }

    public void setToBePartnered(boolean demBePartnerFlag) {
        this.demBePartnerFlag = demBePartnerFlag;
    }

    public int getAdultChildFlag() {
        if (demAdultChildFlag!= null) {
            if (demAdultChildFlag.equals(Indicator.True)) {
                return 1;
            }
            else return 0;
        }
        else return 0;
    }

    public Long getIdHousehold() {
        return idHh;
    }

    public void setIdHousehold(Long idHh) {
        // should only be called from BenefitUnit.setHousehold
        this.idHh = idHh;
    }

    public Series.Double getYearlyEquivalisedDisposableIncomeSeries() {
        return yearlyEquivalisedDisposableIncomeSeries;
    }

    public void setYearlyEquivalisedDisposableIncomeSeries(Series.Double yearlyEquivalisedDisposableIncomeSeries) {
        this.yearlyEquivalisedDisposableIncomeSeries = yearlyEquivalisedDisposableIncomeSeries;
    }

    public Double getYearlyEquivalisedConsumption() {
        return xEquivYear;
    }

    public void setYearlyEquivalisedConsumption(Double xEquivYear) {
        this.xEquivYear = xEquivYear;
    }

    public Series.Double getYearlyEquivalisedConsumptionSeries() {
        return yearlyEquivalisedConsumptionSeries;
    }

    public void setYearlyEquivalisedConsumptionSeries(Series.Double yearlyEquivalisedConsumptionSeries) {
        this.yearlyEquivalisedConsumptionSeries = yearlyEquivalisedConsumptionSeries;
    }

    /*
    public Double getsIndex() {
        if (sIndexYearMap.get(model.getYear()-model.getsIndexTimeWindow()) != null) {
            return sIndexYearMap.get(model.getYear() - model.getsIndexTimeWindow());
        } else {
            return Double.NaN;
        }
    }

    public void setsIndex(Double sIndex) {
        sIndexYearMap.put(model.getYear(), sIndex);
    }

     */

    public Double getsIndex() {
        if (statSIndex != null && statSIndex > 0. && !statSIndex.isInfinite() && (model.getYear() >= model.getStartYear()+model.getsIndexTimeWindow())) {
            return statSIndex;
        }
        else return Double.NaN;
    }

    public void setsIndex(Double statSIndex) {
        this.statSIndex = statSIndex;
    }

    public Double getsIndexNormalised() {
        if (statSIndexNormal != null && statSIndexNormal > 0. && !statSIndexNormal.isInfinite() && (model.getYear() >= model.getStartYear()+model.getsIndexTimeWindow())) {
            return statSIndexNormal;
        }
        else return Double.NaN;
    }

    public void setsIndexNormalised(Double statSIndexNormal) {
        this.statSIndexNormal = statSIndexNormal;
    }

    public Map<Integer, Double> getsIndexYearMap() {
        return sIndexYearMap;
    }

    public Integer getNewWorkHours_lag1() {
        return labHrsWorkNewL1;
    }

    public void setNewWorkHours_lag1(Integer labHrsWorkNewL1) {
        this.labHrsWorkNewL1 = labHrsWorkNewL1;
    }

    public double getCovidModuleGrossLabourIncome_lag1() {
        return covidYLabGrossL1;
    }

    public void setCovidModuleGrossLabourIncome_lag1(double covidYLabGrossL1) {
        this.covidYLabGrossL1 = covidYLabGrossL1;
    }

    public Indicator getCovidModuleReceivesSEISS() {
        return covidSEISSReceivedFlag;
    }

    public void setCovidModuleReceivesSEISS(Indicator covidSEISSReceivedFlag) {
        this.covidSEISSReceivedFlag = covidSEISSReceivedFlag;
    }

    public double getCovidModuleGrossLabourIncome_Baseline() {
        return (covidYLabGross!=null) ? covidYLabGross : 0.0;
    }

    public void setCovidModuleGrossLabourIncome_Baseline(double val) {
        covidYLabGross = val;
    }

    public Quintiles getCovidModuleGrossLabourIncomeBaseline_Xt5() {
        return covidYLabGrossXt5;
    }

    public void setCovidModuleGrossLabourIncomeBaseline_Xt5(Quintiles covidYLabGrossXt5) {
        this.covidYLabGrossXt5 = covidYLabGrossXt5;
    }

    public boolean isDhhOwned() {
        return wealthPrptyFlag;
    }

    public void setDhhOwned(boolean dhh_owned) {
        this.wealthPrptyFlag = dhh_owned;
    }

    public boolean isReceivesBenefitsFlag() {
        return yBenReceivedFlag;
    }

    public void setReceivesBenefitsFlag(boolean yBenReceivedFlag) {
        this.yBenReceivedFlag = yBenReceivedFlag;
    }

    public boolean isReceivesBenefitsFlag_L1() {
        return (yBenReceivedFlagL1!=null) ? yBenReceivedFlagL1 : false;
    }

    public void setReceivesBenefitsFlag_L1(boolean yBenReceivedFlagL1) {
        this.yBenReceivedFlagL1 = yBenReceivedFlagL1;
    }

    public double getEquivalisedDisposableIncomeYearly() {
        return benefitUnit.getEquivalisedDisposableIncomeYearly();
    }

    public double getDisposableIncomeMonthly() { return benefitUnit.getDisposableIncomeMonthly();}

    public double getWageOffer() {
        if (labWageOfferLowFlag)
            return 0.0;
        else
            return 1.0;
    }

    public int getDisability() {
        return (Indicator.True.equals(getDlltsd())) ? 1 : 0;
    }

    public SocialCareReceipt getSocialCareReceipt() {
        // market = 0 for no social care
        //          1 for only informal care
        //          2 for informal and formal care
        //          3 for only formal care
        if (getHoursFormalSocialCare()<0.01 && getHoursInformalSocialCare()<0.01)
            return SocialCareReceipt.None;
        else if (getHoursFormalSocialCare()<0.01 && getHoursInformalSocialCare()>0.01)
            return SocialCareReceipt.Informal;
        else if (getHoursFormalSocialCare()>0.01 && getHoursInformalSocialCare()>0.01)
            return SocialCareReceipt.Mixed;
        else return SocialCareReceipt.Formal;
    }

    public SocialCareReceiptState getSocialCareReceiptState() {
        // market = 0 for no social care
        //          1 for only informal care
        //          2 for informal and formal care
        //          3 for only formal care
        if (Indicator.False.equals(careNeedFlag))
            return SocialCareReceiptState.NoneNeeded;
        else if (getHoursFormalSocialCare()<0.01)
            return SocialCareReceiptState.NoFormal;
        else if (getHoursInformalSocialCare()<0.01)
            return SocialCareReceiptState.Formal;
        else return SocialCareReceiptState.Mixed;
    }

    public double getSocialCareProvisionState() {
//        double val = getSocialCareProvision().getValue();
//        if (dag>DecisionParams.MAX_AGE_COHABITATION && val > 0.1 && val < 2.1)
//            val = 3.0;
        return (double)getSocialCareProvision().getValue();
    }

    public SocialCareProvision getSocialCareProvision() {
        if (careProvidedFlag==null)
            return SocialCareProvision.None;
        else
            return careProvidedFlag;
    }

    public double getRetired() {
        return (Les_c4.Retired.equals(getLes_c4())) ? 1.0 : 0.0;
    }

    public void setYearLocal(Integer i_demYear) {
        this.i_demYear = i_demYear;
    }

    public int getYear() {
        if (model != null) {
            return model.getYear();
        } else {
            if (i_demYear == null) {
                throw new RuntimeException("call to get uninitialised year in benefit unit");
            }
            return i_demYear;
        }
    }
    private int getStartYear() {
        if (model != null) {
            return model.getStartYear();
        } else {
            return 0;
        }
    }

    public void setNumberChildren017Local(Integer nbr) {
        i_demNchild0to17 = nbr;
    }
    public void setIndicatorChildren02Local(Indicator idctr) {
        i_demNChild0to2 = idctr;
    }

    private Ydses_c5 getYdses_c5_lag1() {
        if (model!=null) {
            if (benefitUnit==null)
                throw new RuntimeException("attempt to access unassigned benefit unit");
            return benefitUnit.getYdses_c5_lag1();
        } else {
            if (i_yHhQuintilesC5==null)
                throw new RuntimeException("attempt to access unassigned ydses_c5_lag1Local");
            return i_yHhQuintilesC5;
        }
    }

    public void setYdses_c5_lag1Local(Ydses_c5 ydses_c5_lag1) {
        i_yHhQuintilesC5 = ydses_c5_lag1;
    }

    private Dhhtp_c4 getDhhtp_c4_lag1() {
        if (model!=null) {
            if (benefitUnit==null)
                throw new RuntimeException("attempt to access unassigned benefit unit");
            return benefitUnit.getDhhtp_c4_lag1();
        } else {
            if (i_demCompHhC4L1==null)
                throw new RuntimeException("attempt to access unassigned dhhtp_c4_lag1Local");
            return i_demCompHhC4L1;
        }
    }

    public void setDhhtp_c4_lag1Local(Dhhtp_c4 dhhtp_c4_lag1) {
        i_demCompHhC4L1 = dhhtp_c4_lag1;
    }

    private Integer getNumberChildrenAll_lag1() {
        if (benefitUnit != null) {
            return (benefitUnit.getNumberChildrenAll_lag1() != null) ? benefitUnit.getNumberChildrenAll_lag1() : 0;
        } else {
            return (i_demNchildL1==null) ? 0 : i_demNchildL1;
        }
    }

    public void setNumberChildrenAllLocal(Integer nbr) {
        i_demNchild = nbr;
    }

    private Integer getNumberChildrenAll() {
        if (model != null) {
            if (benefitUnit==null)
                throw new RuntimeException("attempt to access unassigned benefit unit");
            return benefitUnit.getNumberChildrenAll();
        } else {
            if (i_demNchild==null)
                throw new RuntimeException("attempt to access unassigned numberChildrenAllLocal");
            return i_demNchild;
        }
    }

    public void setNumberChildrenAllLocal_lag1(Integer nbr) {
        i_demNchildL1 = nbr;
    }

    public void setNumberChildren02Local_lag1(Integer nbr) {
        i_demNchild0to2L1 = nbr;
    }

    private Integer getNumberChildren02_lag1() {
        if (model != null) {
            if (benefitUnit==null)
                throw new RuntimeException("attempt to access unassigned benefit unit");
            return benefitUnit.getNumberChildren02_lag1();
        } else {
            if (i_demNchild0to2L1==null)
                throw new RuntimeException("attempt to access unassigned numberChildren02Local_lag1");
            return i_demNchild0to2L1;
        }
    }

    private Integer getNumberChildren017() {
        if (model != null) {
            if (benefitUnit==null)
                throw new RuntimeException("attempt to access unassigned benefit unit");
            return benefitUnit.getNumberChildren(0,17);
        } else {
            if (i_demNchild0to17==null)
                throw new RuntimeException("attempt to access unassigned numberChildren017Local");
            return i_demNchild0to17;
        }
    }

    private Double getInverseMillsRatio() {

        double score;
        if(Gender.Male.equals(demMaleFlag)) {
            if (Les_c4.EmployedOrSelfEmployed.equals(labC4L1)) {
                score = Parameters.getRegEmploymentSelectionMaleE().getScore(this, Person.DoublesVariables.class);
            } else {
                score = Parameters.getRegEmploymentSelectionMaleNE().getScore(this, Person.DoublesVariables.class);
            }
        } else {
            // for females
            if (Les_c4.EmployedOrSelfEmployed.equals(labC4L1)) {
                score = Parameters.getRegEmploymentSelectionFemaleE().getScore(this, Person.DoublesVariables.class);
            } else {
                score = Parameters.getRegEmploymentSelectionFemaleNE().getScore(this, Person.DoublesVariables.class);
            }
        }
        Double inverseMillsRatio; //IMR is the PDF(x) / CDF(x) where x is score of probit of employment
        double cdf = Parameters.getStandardNormalDistribution().cumulativeProbability(score);
        if(cdf != 0.) {
            String pdfString = Double.toString(Parameters.getStandardNormalDistribution().density(score));
            String cdfString = Double.toString(cdf);
            BigDecimal bigPdf = new BigDecimal(pdfString);
            BigDecimal bigCdf = new BigDecimal(cdfString);
            BigDecimal result = bigPdf.divide(bigCdf, RoundingMode.HALF_EVEN);
            inverseMillsRatio = result.doubleValue();
        } else {
            throw new RuntimeException("problem evaluating inverse Mills ratio for wage rate projections");
        }
        if (Double.isFinite(inverseMillsRatio)) {
            if(Gender.Male.equals(demMaleFlag)) {
                if (inverseMillsRatio > statInverseMillsRatioMaxM) {
                    statInverseMillsRatioMaxM = inverseMillsRatio;
                }
                if (inverseMillsRatio < statInverseMillsRatioMinM) {
                    statInverseMillsRatioMinM = inverseMillsRatio;
                }
            } else {
                if (inverseMillsRatio > statInverseMillsRatioMaxF) {
                    statInverseMillsRatioMaxF = inverseMillsRatio;
                }
                if (inverseMillsRatio < statInverseMillsRatioMinF) {
                    statInverseMillsRatioMinF = inverseMillsRatio;
                }
            }
        } else {
            log.debug("inverse Mills ratio is not finite, return 0 instead!!!   IMR: " + inverseMillsRatio + ", score: " + score/* + ", num: " + num + ", denom: " + denom*/ + ", age: " + demAge + ", gender: " + demMaleFlag + ", education " + eduHighestC4 + ", activity_status from previous time-step " + labC4);
            return 0.;
        }
        return inverseMillsRatio;		//XXX: Currently only returning non-zero IMR if it is finite
    }

    public double getHourlyWageRate1() {
        return getHourlyWageRate(getLabourSupplyHoursWeekly());
    }
    public double getHourlyWageRate() {
        return getHourlyWageRate(getLabourSupplyHoursWeekly());
    }
    public double getHourlyWageRate(double labourHoursWeekly) {
        int weeklyHours = (int) Math.round(labourHoursWeekly);
        return getHourlyWageRate(weeklyHours);
    }
    public double getHourlyWageRate(int labourHoursWeekly) {

        if (labourHoursWeekly >= Parameters.MIN_HOURS_FULL_TIME_EMPLOYED) {
            return labWageHrly;
        } else {
            double ptPremium;
            if (labC4L1.equals(Les_c4.EmployedOrSelfEmployed)) {
                if (Gender.Male.equals(demMaleFlag)) {
                    ptPremium = ManagerRegressions.getRegressionCoeff(RegressionName.W1mb, "Pt");
                } else {
                    ptPremium = ManagerRegressions.getRegressionCoeff(RegressionName.W1fb, "Pt");
                }
            } else {
                if (Gender.Male.equals(demMaleFlag)) {
                    ptPremium = ManagerRegressions.getRegressionCoeff(RegressionName.W1ma, "Pt");
                } else {
                    ptPremium = ManagerRegressions.getRegressionCoeff(RegressionName.W1fa, "Pt");
                }
            }
            return Math.exp( Math.log(labWageHrly) + ptPremium);
        }
    }

    public double getEarningsWeekly() {
        return getEarningsWeekly(getLabourSupplyHoursWeekly());
    }
    public double getEarningsWeekly(double labourHoursWeekly) {
        int hours = (int) Math.round(labourHoursWeekly);
        return getHourlyWageRate(hours) * labourHoursWeekly;
    }
    public double getEarningsWeekly(int labourHoursWeekly) {
        return getHourlyWageRate(labourHoursWeekly) * (double) labourHoursWeekly;
    }
    public Integer getNumberChildren017Local() {
        return i_demNchild0to17;
    }
    public Integer getNumberChildrenAllLocal() {
        return i_demNchild;
    }
    public Indicator getIndicatorChildren02Local() {
        return i_demNChild0to2;
    }
    public Map<Labour, Integer> getPersonContinuousHoursLabourSupplyMap() {
        return personContinuousHoursLabourSupplyMap;
    }
    public void setPersonContinuousHoursLabourSupplyMap(Map<Labour, Integer> personContinuousHoursLabourSupplyMap) {
        this.personContinuousHoursLabourSupplyMap = personContinuousHoursLabourSupplyMap;
    }
    public double getLabourSupplySingleDraw() {
        return innovations.getSingleDrawDoubleInnov(0);
    }
    public double getBenefitUnitRandomUniform() {return innovations.getDoubleDraw(31);}

    public double getHoursFormalSocialCare_L1() {
        return (careHrsFormalWeekL1 > 0.0) ? careHrsFormalWeekL1 : 0.0;
    }

    public double getHoursFormalSocialCare() {
        double hours = 0.0;
        if (careHrsFormalWeek !=null)
            if (careHrsFormalWeek >0.0)
                hours = careHrsFormalWeek;
        return hours;
    }

    public double getHoursInformalSocialCare() {
        return getCareHoursFromPartnerWeekly() + getCareHoursFromDaughterWeekly() + getCareHoursFromSonWeekly() + getCareHoursFromOtherWeekly() + getCareHoursFromParentWeekly();
    }

    public double getCareHoursFromPartnerWeekly() {
        double hours = 0.0;
        if (careHrsFromPartnerWeek != null)
            if (careHrsFromPartnerWeek >0.0)
                hours = careHrsFromPartnerWeek;
        return hours;
    }
    public void setCareHoursFromPartnerWeekly(double hours) {
        careHrsFromPartnerWeek = hours;
    }

    public double getCareHoursFromParentWeekly() {
        double hours = 0.0;
        if (careHrsFromParentWeek !=null)
            if (careHrsFromParentWeek >0.0)
                hours = careHrsFromParentWeek;
        return hours;
    }

    public double getCareHoursFromDaughterWeekly() {
        double hours = 0.0;
        if (careHrsFromDaughterWeek !=null)
            if (careHrsFromDaughterWeek >0.0)
                hours = careHrsFromDaughterWeek;
        return hours;
    }

    public double getCareHoursFromSonWeekly() {
        double hours = 0.0;
        if (careHrsFromSonWeek !=null)
            if (careHrsFromSonWeek >0.0)
                hours = careHrsFromSonWeek;
        return hours;
    }

    public double getCareHoursFromOtherWeekly() {
        double hours = 0.0;
        if (careHrsFromOtherWeek !=null)
            if (careHrsFromOtherWeek >0.0)
                hours = careHrsFromOtherWeek;
        return hours;
    }

    public double getCareHoursProvidedWeekly() {
        double hours = 0.0;
        if (careHrsProvidedWeek != null)
            if (careHrsProvidedWeek > 0.0)
                hours = careHrsProvidedWeek;
        return hours;
    }

    public double getHoursInformalSocialCare_L1() {
        return getCareHoursFromPartner_L1() + getCareHoursFromDaughter_L1() + getCareHoursFromSon_L1() + getCareHoursFromOther_L1() + getCareHoursFromParent_L1();
    }

    public double getTotalHoursSocialCare_L1() {
        return getHoursFormalSocialCare_L1() + getHoursInformalSocialCare_L1();
    }

    public double getCareHoursFromParent_L1() {
        return (careHrsFromParentWeekL1 >0.0) ? careHrsFromParentWeekL1 : 0.0;
    }

    public double getCareHoursFromPartner_L1() {
        return (careHrsFromPartnerWeekL1 > 0.0) ? careHrsFromPartnerWeekL1 : 0.0;
    }

    public double getCareHoursFromDaughter_L1() {
        return (careHrsFromDaughterWeekL1 >0.0) ? careHrsFromDaughterWeekL1 : 0.0;
    }

    public double getCareHoursFromSon_L1() {
        return (careHrsFromSonWeekL1 >0.0) ? careHrsFromSonWeekL1 : 0.0;
    }

    public double getCareHoursFromOther_L1() {
        return (careHrsFromOtherWeekL1 >0.0) ? careHrsFromOtherWeekL1 : 0.0;
    }

    public double getSocialCareCostWeekly() {
        double cost = 0.0;
        if (xCareFormalWeek !=null)
            if (xCareFormalWeek >0.0)
                cost = xCareFormalWeek;
        return cost;
    }

    public boolean getTestPartner() {
        return (demAlignPartnerProcess!=null) && demAlignPartnerProcess;
    }

    public void setHasTestPartner(boolean demAlignPartnerProcess) {
        this.demAlignPartnerProcess = demAlignPartnerProcess;
    }

    public boolean getLeavePartner() {
        return (demLeavePartnerFlag!=null) && demLeavePartnerFlag;
    }

    public void setLeavePartner(boolean demLeavePartnerFlag) {
        this.demLeavePartnerFlag = demLeavePartnerFlag;
    }

    public boolean getLowWageOffer() {
        return (labWageOfferLowFlag!=null) && labWageOfferLowFlag;
    }

    private boolean checkHighestParentalEducationEquals(Education ee) {
        if (eduHighestFatherC4 !=null && eduHighestMotherC4 !=null) {
            if (eduHighestFatherC4.getValue() > eduHighestMotherC4.getValue())
                return ee.equals(eduHighestFatherC4);
            else
                return ee.equals(eduHighestMotherC4);
        } else if (eduHighestFatherC4 !=null) {
            return ee.equals(eduHighestFatherC4);
        } else {
            return ee.equals(eduHighestMotherC4);
        }
    }

    public boolean getBornInSimulation() {
        return demBornInSimFlag;
    }

    public void setBornInSimulation(boolean demBornInSimFlag) {
        this.demBornInSimFlag = demBornInSimFlag;
    }

    public double getHoursWorkedWeekly() {
        return ( (labHrsWorkWeek != null) && labHrsWorkWeek > 0 ) ? (double) labHrsWorkWeek : 0.0;
    }

    public double getLeisureHoursPerWeek() {
        return Parameters.HOURS_IN_WEEK - getCareHoursProvidedWeekly() - getHoursWorkedWeekly();
    }

    public void setSampleExit(SampleExit demExitSample) {
        if (!SampleExit.NotYet.equals(this.demExitSample))
            throw new RuntimeException("Attempt to exit person from the simulated sample twice");
        this.demExitSample = demExitSample;
    }
    public SampleExit getSampleExit() {return demExitSample;}
    public double getFertilityRandomUniform2() { return innovations.getDoubleDraw(28); }
    public double getCohabitRandomUniform2() { return innovations.getDoubleDraw(26); }
    public RegressionName getRegressionName(Axis axis) {
        switch (axis) {
            case Student -> {return RegressionName.EducationE1a;}
            case Education -> {return RegressionName.EducationE2a;}
            case Health -> {return RegressionName.HealthH1;}
            case Disability -> {return RegressionName.HealthH2;}
            case Cohabitation -> {
                if (Dcpst.Partnered.equals(demPartnerStatusL1))
                    return RegressionName.PartnershipU2;
                else
                    return RegressionName.PartnershipU1;
            }
            case SocialCareProvision -> {
                if (Dcpst.Partnered.equals(getDcpst()))
                    return RegressionName.SocialCareS3d;
                else
                    return RegressionName.SocialCareS3c;
            }
            case WagePotential -> {
                if (Gender.Male.equals(demMaleFlag))
                    return RegressionName.W1mb;
                else
                    return RegressionName.W1fb;
            }
            case WageOffer1 -> {
                if (Gender.Male.equals(demMaleFlag)) {
                    if (Education.High.equals(eduHighestC4L1)) {
                        return RegressionName.UnemploymentU1a;
                    } else {
                        return RegressionName.UnemploymentU1b;
                    }
                } else {
                    if (Education.High.equals(eduHighestC4L1)) {
                        return RegressionName.UnemploymentU1c;
                    } else {
                        return RegressionName.UnemploymentU1d;
                    }
                }
            }
            default -> {
                throw new RuntimeException("failed to recognise axis for regression identification");
            }
        }
    }

    public void setProcessedId(long id) {
        key.setWorkingId(id);
    }

    public long getSeed() {return (statSeed!=null) ? statSeed : 0L;}

    private boolean getDhmGhq_lag1() {
        if (healthDhmGhqL1 == null)
            throw new RuntimeException("attempt to access dhmGhq_lag1 before it has been initialised");
        return healthDhmGhqL1;
    }

    public Double getYnbcpdf_dv() {
        Person partner = getPartner();
        if (partner != null) {
            if (partner.getYpnbihs_dv() != null && getYpnbihs_dv() != null)
                return getYpnbihs_dv() - partner.getYpnbihs_dv();
        }
        return null;
    }

    public long getId() {
        return key.getId();
    }

    public Long getIdMother() {
        return idMother;
    }

    public Long getIdFather() {
        return idFather;
    }

    public boolean getToBePartnered() {return demBePartnerFlag;}

    public static void setPersonIdCounter(long id) {personIdCounter=id;}
}
