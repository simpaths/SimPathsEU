// define package
package simpaths.data;

// import Java packages

import microsim.data.MultiKeyCoefficientMap;
import microsim.data.excel.ExcelAssistant;
import microsim.statistics.regression.*;
import microsim.statistics.regression.RegressionType;
import org.apache.commons.collections4.keyvalue.MultiKey;
import org.apache.commons.collections4.map.LinkedMap;
import org.apache.commons.collections4.map.MultiKeyMap;
import org.apache.commons.lang3.tuple.Triple;
import org.apache.commons.math3.distribution.MultivariateNormalDistribution;
import org.apache.commons.math3.distribution.NormalDistribution;
import org.apache.commons.math3.util.Pair;
import org.apache.commons.collections4.MapIterator;
import simpaths.data.startingpop.DataParser;
import simpaths.model.AnnuityRates;
import simpaths.model.decisions.Grids;
import simpaths.model.enums.*;
import simpaths.model.taxes.DonorTaxUnit;
import simpaths.model.taxes.MatchFeature;
import simpaths.model.taxes.database.TaxDonorDataParser;
import simpaths.model.taxes.database.TaxDonorParserTraining;

import java.io.File;
import java.io.IOException;
import java.lang.reflect.Modifier;
import java.nio.file.Files;
import java.util.*;
import java.lang.reflect.Field;
import java.util.Map;

import static microsim.statistics.regression.RegressionUtils.appendCoefficientMaps;



/**
 *
 * CLASS TO STORE MODEL PARAMETERS FOR GLOBAL ACCESS
 *
 */
public class Parameters {

    private static String getCountryInputDir(Country country) {
        return INPUT_DIRECTORY + country + File.separator;
    }

    private static String resolveCountryFile(Country country, String fileName) {
        return getCountryInputDir(country) + fileName;
    }


    // EUROMOD variables


    // Insert here names of EUROMOD variables to use in Person and BenefitUnit tables of the input database
    // NOTE: The model economises set-up costs for the donor population by considering policy projections generated
    // for multiple "system years" for the same input data. All non-financial statistics should consequently be the
    // same for the donor population (described under DONOR_STATIC_VARIABLES). Memory is further economised by assuming
    // a constant inflation adjustment for all factors in EUROMOD, so that exogenous financial inputs vary by system year
    // only by the inflation rate. Setting this rate to the rate of inflation loaded in via scenario_uprating_factor.xls
    // permits these exogenous inputs to be inferred across system years without storing them separately for each year
    // The only financial statistics that vary by system should consequently be policy dependant variables,
    // (described below under DONOR_POLICY_VARIABLES). The model performs checks to ensure that these conditions are
    // met when it loads in data.
    public static final String[] DONOR_STATIC_VARIABLES = new String[]{
            "idhh",                    //id of household
            "idperson",                //id of person
            "idfather",                //id of father
            "idmother",                //id of mother
            "idpartner",               //id of partner
            "dag",                     //age
            "dct",                     //country
            "deh",                     //highest education level
            "dgn",                     //gender
            "drgn1",                   //region (NUTS1)
            "dwt",                     //household weight
            "les",                     //labour employment status + health status
            "lcs",                     //labour civil servant dummy indicator
            //    "lcr01",                //carer status for benefits (0 no 1 yes)
            "lhw",                     //hours worked per week
            "ddi",                     //disability status
            "yem",                     //employment income - used to construct work sector *NOT VALID FOR POLICY ANALYSIS*
            "yse",                     //self-employment income - used to construct work sector *NOT VALID FOR POLICY ANALYSIS*
    };

    public static final String[] DONOR_POLICY_VARIABLES = new String[]{
            //    "xcc",                  //childcare costs
            "ils_earns",            //EUROMOD output variable:- total labour earnings (employment + self-employment income + potentially other labour earnings like temporary employment, depending on country classification)
            "ils_origy",            //EUROMOD output variable:- all gross income from labour, private pensions, investment income, property income, private transfers etc.
            "ils_dispy",            //Disposable income : from EUROMOD output data after tax / benefit transfers (monthly time-scale)
            "ils_benmt",            //EUROMOD output variable: income list: monetary benefits
            "ils_bennt",            //EUROMOD output variable: income list: non-monetary benefits
    };

    public static final String[] HOUSEHOLD_VARIABLES_INITIAL = new String[]{
            "idHh",                //id of household (can contain multiple benefit units)
    };

    public static final String[] BENEFIT_UNIT_VARIABLES_INITIAL = new String[]{
            "idHh",                //id of household (can contain multiple benefit units)
            "idBu",    //id of a benefit unit
            "demRgn",            //region (NUTS1)
            "yHhQuintilesMonthC5",            //household income quantile
            "wealthPrptyFlag",        //flag indicating if benefit unit owns a house
    };

    public static final String[] PERSON_VARIABLES_INITIAL = new String[]{
            "idHh",                    //id of household (can contain multiple benefit units)
            "idBu",        //id of a benefit unit
            "idPers",            //id of person
            "wgtCrossMainSurvey",                    //household weight
            "idFather",            //id of father
            "idMother",            //id of mother
            "demAge",                    //age
            "eduHighestC4",                //highest education level
            "eduHighestMotherC4",                //highest education level of mother
            "eduHighestFatherC4",                //highest education level of father
            "eduSpellFlag",                    //in education dummy
            "eduReturnFlag",                    //return to education dummy
            "healthSelfRated",                    //health status
            "demPartnerNYear",                //years in partnership
            "demAgePartnerDiff",                //partners age difference
            "demNChild0to2",                //number children aged 0-2
            "demNChild",                    //number children
            "yNonBenPersGrossMonth",            //gross personal non-benefit income
            "yMiscPersGrossMonth",            //gross personal non-employment non-benefit income
            "yCapitalPersMonth",                //gross personal capital income
            "yPensPersGrossMonth",                //gross personal pension (public / occupational) income
            "yEmpPersGrossMonth",            //gross personal employment income
            "yPersAndPartnerGrossDiffMonth",            //difference partner income
            "healthDsblLongtermFlag",                //long-term sick or disabled
            "eduExitSampleFlag",                //year left education
            "statInterviewYear",                    //system variable - year
            "statCollectionWave",                    //system variable - wave
            "demMaleFlag",                    //gender
            "labC4",                //labour employment status
            "labC4L1",            //lag(1) of labour employment status
            "labHrsWorkWeek",                    //hours worked per week
            "demAdultChildFlag",        //flag indicating adult child living at home in the data
            "wealthPrptyFlag",            //flag indicating if individual is a homeowner
            "labWageHrly", //initial value of hourly earnings from the data
            "labWageHrlyL1", //lag(1) of initial value of hourly earnings from the data
            "labEmpNyear",                    // number of years in employment
            "yPersDispMonth",                    //real personal monthly disposable income
            //"yem", 					//employment income
            //"yse", 					//self-employment income

            //From EUROMOD output data before tax / benefit transfers, so not affected by EUROMOD policy scenario (monthly time-scale).  We just use them calculated from EUROMOD output because EUROMOD has the correct way of aggregating each country's different component definitions
            //"ils_earns", 			//EUROMOD output variable:- total labour earnings (employment + self-employment income + potentially other labour earnings like temporary employment, depending on country classification)
            //"ils_origy"			//EUROMOD output variable:- all gross income from labour, private pensions, investment income, property income, private transfers etc.
    };

    // IMPORTANT: many of the default values declared in this class are overwritten at runtime
    // from input/<COUNTRY>/parameters.xlsx. When changing defaults here, make sure the
    // corresponding parameters.xlsx file is kept in sync, otherwise the Excel values will win.
    // Country-specific parameters which are then set by the Excel file
    public static String COUNTRY_STRING = "";

    public static int MIN_AGE_TO_HAVE_INCOME = 16; //Minimum age to have non-employment non-benefit income
    public static int MAX_LABOUR_HOURS_IN_WEEK = 60;
    public static int HOURS_IN_WEEK = 24*7; // currently, 24 hours per day is used to calculate leisure in labour supply
    public static boolean USE_CONTINUOUS_LABOUR_SUPPLY_HOURS = true; // If true, a random number of hours of weekly labour supply within each bracket will be generated. Otherwise, each discrete choice of labour supply corresponds to a fixed number of hours of labour supply, which is the same for all persons

    public static int AGE_TO_BECOME_RESPONSIBLE = 18;            // Age become reference person of own benefit unit
    public static int AGE_TO_BECOME_SEMI_RESPONSIBLE = 16;      //Age used in health processes H1, H2
    public static int AGE_LEAVE_PARENTAL_HOME = 18;
    public static int MIN_AGE_TO_LEAVE_EDUCATION = 16;        // Minimum age for a person to leave (full-time) education
    public static int MAX_AGE_TO_STAY_IN_CONTINUOUS_EDUCATION = 29;


    public static int MIN_AGE_TO_RETIRE = 50; //Minimum age to consider retirement
    public static int DEFAULT_AGE_TO_RETIRE = 67; //if pension included, but retirement decision not
    public static int MIN_AGE_FORMAL_SOCARE = 65; //Minimum age to receive formal social care
    public static int MIN_AGE_FLEXIBLE_LABOUR_SUPPLY = 16; //Used when filtering people who can be "flexible in labour supply"
    public static int MAX_AGE_FLEXIBLE_LABOUR_SUPPLY = 75;
    public static double SHARE_OF_WEALTH_TO_ANNUITISE_AT_RETIREMENT = 0.25;
    public static double ANNUITY_RATE_OF_RETURN = 0.015;

    public static int MIN_HOURS_FULL_TIME_EMPLOYED = 25;    // used to distinguish full-time from part-time employment (needs to be consistent with Labour enum)
    public static double MIN_HOURLY_WAGE_RATE = 0.0;
    public static double MAX_HOURLY_WAGE_RATE = 75.0;
    public static double MAX_HOURS_WEEKLY_FORMAL_CARE = 150.0;
    public static double MAX_HOURS_WEEKLY_INFORMAL_CARE = 16 * 7;
    public static double CHILDCARE_COST_EARNINGS_CAP = 0.5;  // maximum share of earnings payable as childcare (for benefit units with some earnings)

    public static double KEY_FUNCTION_HU2_HI_INCOME = 287.0; // 67th percentile observed in the EM data for 2018
    public static double KEY_FUNCTION_HU2_LO_INCOME = 140.0; // 33rd percentile observed in the EM data for 2018
    public static int KEY_FUNCTION_HU2_MID_AGE = 45;
    public static int KEY_FUNCTION_HU2_INCOME_REF_YEAR = 2018;
    // Country-specific parameters which are handled without using excel input
    public static int maxAge;                    // maximum age possible in simulation; set in GUI menu
    public static int MIN_AGE_COHABITATION = 18;    // Min age a person can marry, i.e. form a partnership; used in process U1
    public static int SEPARATION_STOP_AGE = 79;    //age partners cannot separate, i.e. terminate partnership; used in process U2
    public static AnnuityRates annuityRates;    // is set later in AnnuityRates class by evaluating other parameters

    //Parameters for managing tax and benefit imputations
    public static int TAXDB_REGIMES = 6;
    private static Map<MatchFeature, Map<Integer, Integer>> taxdbCounter = new HashMap<MatchFeature, Map<Integer, Integer>>();            // records, for each of the three donor keys (first Integer), the increments (second Integer) associated with one unit change in characteristic (String).  The properties of taxdbCounter are specific to the KeyFunction used (and are populated by the associated function)
    private static List<DonorTaxUnit> donorPool;                                                    // list of donors for tax imputation, in ascending order by private (original) income
    private static Map<Triple<Integer, Integer, Integer>, List<Integer>> taxdbReferences = new HashMap<>();        // for Triple <system year, matching regime, regime index> returns a list of indices to donorPool that describes members of grouping, in ascending order by private income
    private static MahalanobisDistance mdDualIncome;
    private static MahalanobisDistance mdChildcare;
    private static MahalanobisDistance mdDualIncomeChildcare;

    //Labour Demand/Supply Convergence parameters
    public static final double INITIAL_DECAY_FACTOR = 1.;    //Initialisation of field that is used to check whether labour market equilibrium is progressing fast enough (is multiplied by a factor at each iteration when needed, so the factor gets exponentially smaller)
    public static final DemandAdjustment demandAdjustment = DemandAdjustment.PopulationGrowth;        //Choose the method by which we derive the factor applied to the converged labour demand in order to get the initial labour demand at the following timestep
    public static final double ETA = 0.2;        //(eta in Matteo's document).  If excess labour demand is greater than this value (0.1 == 10%), then iterate convergence procedure again
    public static final double CHI_minus = 0.1;        //Lambda in Matteo's document is adjusted by reducing by lambda -> lambda * (1 - CHI_minus), or increasing lambda by lambda -> lambda * (1 + CHI_plus)
    public static final double CHI_plus = 0.1;        //Lambda in Matteo's document is adjusted by reducing by lambda -> lambda * (1 - CHI_minus), or increasing lambda by lambda -> lambda * (1 + CHI_plus)
    public static final Map<Education, Double> adjustmentFactorByEducation;    //Lambda_s in Matteo's document, where s is the education level
    public static final double initialLambda = ETA / 5.;    //Ensure adjustment is smaller than relative excess labour demand threshold
    public static final int MinimumIterationsBeforeTestingConvergenceCriteria = 20;    //Run this number of iterations to accumulate estimates of (aggregate) labour supply (cross) elasticities before testing the convergence criterion (i.e. the norm of (supply * demand elasticities) matrix < 1)
    public static final int MaxConvergenceAttempts = 2 * MinimumIterationsBeforeTestingConvergenceCriteria;        //Allow the equilibrium convergence criterion to fail the test this number of times before potentially terminating the simulation.
    public static final double RateOfConvergenceFactor = 0.9;
    //Childcare
    public static int MAX_CHILD_AGE_FOR_FORMAL_CARE = 14;

    //Alignment parameters — search bounds (max shift ± from starting value)
    public static final double RETIREMENT_ALIGNMENT_BOUND = 3.0;
    public static final double DISABILITY_ALIGNMENT_BOUND = 2.0;
    public static final double IN_SCHOOL_ALIGNMENT_BOUND = 4.0;
    public static final double EMPLOYMENT_ALIGNMENT_BOUND = 10.0;
    public static final double PARTNERSHIP_ALIGNMENT_BOUND = 4.0;
    public static final double FERTILITY_ALIGNMENT_BOUND = 10.0;

    // Determine probability of yearly labour supply matches persisting from previous year
    public static double labour_innovation_employment_persistence_probability = 0.00;
    public static double labour_innovation_notinemployment_persistence_probability = 0.00;

    // Set to true to print root-search diagnostics (iteration tables, summaries) to console
    public static final boolean LOG_ALIGNMENT_DETAILS = false;

    //Alignment parameters — end years
    public static final int EMPLOYMENT_ALIGNMENT_END_YEAR = 2023;
    public static final int IN_SCHOOL_ALIGNMENT_END_YEAR = 2023;
    public static final int PARTNERSHIP_ALIGNMENT_END_YEAR = 2023;
    public static final int FERTILITY_ALIGNMENT_END_YEAR = 2040;
    public static final int RETIREMENT_ALIGNMENT_END_YEAR = 2023;
    public static final int DISABILITY_ALIGNMENT_END_YEAR = 2023;

    // parameters to manage simulation of optimised decisions
    public static boolean projectLiquidWealth = false;
    public static boolean projectPensionWealth = false;
    public static boolean projectHousingWealth = false;
    public static boolean enableIntertemporalOptimisations = false;
    public static Grids grids = null;

    static {
        adjustmentFactorByEducation = new LinkedHashMap<Education, Double>();        //Initialise adjustment factor to the same value for all education levels
        for (Education edu : Education.values()) {
            adjustmentFactorByEducation.put(edu, initialLambda);
        }
    }

    public static void resetAdjustmentFactorByEducation() {
        for (Education edu : Education.values()) {
            adjustmentFactorByEducation.put(edu, initialLambda);
        }
    }

    public static final double childrenNumDiscrepancyConstraint(double numberOfChildren) {
        if (numberOfChildren <= 1) {
            return 0.;
        } else if (numberOfChildren <= 3) {
            return 1.;
        } else if (numberOfChildren <= 5) {
            return 2.;
        } else {
            return 3.;
        }
    }

    public static final double AgeDiscrepancyConstraint = 10;    //Difference of age must equal of be below this value (so we allow 10 year cumulated age difference)
    public static final TreeSet<Double> EarningsDiscrepancyConstraint = new TreeSet<>(Arrays.asList(0.01, 0.02, 0.03, 0.04, 0.05));    //Proportional difference

    //Initial matching differential bounds - the initial bounds that a match must satisfy, before being relaxed
    public static final double UNMATCHED_TOLERANCE_THRESHOLD = 0.1;        //Smallest proportion of a gender left unmatched (we take the minimum of the male proportion and female proportions).  If there are more than this, we will relax the constraints (e.g. the bounds on age difference and potential earnings difference) until this target has been reached
    public static final int MAXIMUM_ATTEMPTS_MATCHING = 10;
    public static final double RELAXATION_FACTOR = 1.5;

    public static final int AGE_DIFFERENCE_INITIAL_BOUND = 999;
    public static final double POTENTIAL_EARNINGS_DIFFERENCE_INITIAL_BOUND = 999.;

    public static final double WEEKS_PER_MONTH = 365.25 / (7. * 12.);    // = 4.348214286
    public static final double WEEKS_PER_YEAR = 365.25 / 7.;

    //Is it possible for people to start going to the labour module (e.g. age 17) while they are living with parents (until age 18)?
    //Cannot see how its possible if it is the household that decides how much labour to supply.  If someone finishes school at 17, they need to leave home before they can enter the labour market.  So set age for finishing school and leaving home to 18.
    public static final int MIN_DIFFERENCE_AGE_MOTHER_CHILD_IN_ALIGNMENT = 15; //When assigning children to mothers in the population alignment, specify how much older (at the minimum) the mother must be than the child
    public static final int MAX_EM_DONOR_RATIO = 3; // Used by BenefitUnit => convertGrossToDisposable() to decide whether gross-to-net ratio should be applied or disposable income from the donor used directly
    public static final double PERCENTAGE_OF_MEDIAN_EM_DONOR = 0.2; // Used by BenefitUnit => convertGrossToDisposable() to decide whether gross-to-net ratio should be applied or disposable income from the donor used directly
    public static final double PSYCHOLOGICAL_DISTRESS_GHQ12_CASES_CUTOFF = 4; // Define cut-off on the GHQ12 Likert scale above which individuals are classified as psychologically distressed

    //Initial value for the savings rate and multiplier for capital income:
    public static double SAVINGS_RATE = 0.056; //This is set in the country-specific part of this file

    //public static int MAX_AGE_IN_EDUCATION;// = MAX_AGE;//30;			// Max age a person can stay in education	//Cannot set here, as MAX_AGE is not known yet.  Now set to MAX_AGE in buildObjects in Model class.
    //public static int MAX_AGE_MARRIAGE;// = MAX_AGE;//75;  			// Max age a person can marry		//Cannot set here, as MAX_AGE is not known yet.  Now set to MAX_AGE in buildObjects in Model class.
    private static int MIN_START_YEAR = 2011; //Minimum allowed starting point. Should correspond to the oldest initial population.
    private static int MAX_START_YEAR = 2023; //Maximum allowed starting point. Should correspond to the most recent initial population.
    public static int startYear;
    public static int endYear;
    private static int MIN_START_YEAR_TRAINING = 2011;
    private static int MAX_START_YEAR_TRAINING = 2023; //Maximum allowed starting point. Should correspond to the most recent initial population.
    public static int MIN_AGE_MATERNITY = 18;            // Min age a person can give birth
    public static int MAX_AGE_MATERNITY = 49;            // Max age a person can give birth
    public static final boolean FLAG_SINGLE_MOTHERS = true;
    public static boolean flagUnemployment = false;

    public static int BASE_PRICE_YEAR = 2015;            // Base price year of model parameters

    public static double PROB_NEWBORN_IS_MALE = 0.5;            // Must be strictly greater than 0.0 and less than 1.0

    public static final boolean systemOut = true;

    //Bootstrap all the regression coefficients if true, or only the female labour participation regressions when false
    public static final boolean bootstrapAll = true;

    //Scheduling
    public static final int MODEL_ORDERING = 0;
    public static final int COLLECTOR_ORDERING = 1; //-2
    public static final int OBSERVER_ORDERING = 2; //-1

    //Initialise values specifying domain of original sick probability curves
    public static int femaleMinAgeSick = Integer.MAX_VALUE;
    public static int maleMinAgeSick = Integer.MAX_VALUE;
    public static int femaleMaxAgeSick = Integer.MIN_VALUE;
    public static int maleMaxAgeSick = Integer.MIN_VALUE;

    //For use with EUROMOD and h2 input database construction
    public static final String WORKING_DIRECTORY = System.getProperty("user.dir");
    public static final String INPUT_DIRECTORY = WORKING_DIRECTORY + File.separator + "input" + File.separator;
    public static boolean trainingFlag = false;
    public static final String INPUT_DIRECTORY_INITIAL_POPULATIONS = INPUT_DIRECTORY + "InitialPopulations" + File.separator; //Path to directory containing initial population for each year
    public static final String EUROMOD_OUTPUT_DIRECTORY = INPUT_DIRECTORY + "EUROMODoutput" + File.separator;
    public static final String EUROMOD_TRAINING_DIRECTORY = EUROMOD_OUTPUT_DIRECTORY + "training" + File.separator;
    public static final String EUROMODpolicyScheduleFilename = "EUROMODpolicySchedule";
    public static final String DatabaseCountryYearFilename = "DatabaseCountryYear";

    //Headings in Excel file of EUROMOD policy scenarios
    public static final String EUROMODpolicyScheduleHeadingFilename = "Filename";
    public static final String EUROMODpolicyScheduleHeadingScenarioSystemYear = "Policy_System_Year";
    public static final String EUROMODpolicyScheduleHeadingScenarioYearBegins = "Policy_Start_Year";
    public static final String EUROMODpolicySchedulePlanHeadingDescription = "Description";
    //Names of donor attributes that depend on EUROMOD policy parameters
    public static final String DISPOSABLE_INCOME_VARIABLE_NAME = "DISPOSABLE_INCOME_MONTHLY";
    public static final String EMPLOYER_SOCIAL_INSURANCE_VARIABLE_NAME = "EMPLOYER_SOCIAL_INSURANCE_CONTRIBUTION_PER_HOUR";
    public static final String GROSS_EARNINGS_VARIABLE_NAME = "GROSS_EARNINGS_MONTHLY";
    public static final String ORIGINAL_INCOME_VARIABLE_NAME = "ORIGINAL_INCOME_MONTHLY";
    public static final String HOURLY_WAGE_VARIABLE_NAME = "HOURLY_WAGE";
    public static final String ILS_BENMT_NAME = "ILS_BENMT";
    public static final String ILS_BENNT_NAME = "ILS_BENNT";
    //public static final String SELF_EMPLOY_SOCIAL_INSURANCE_VARIABLE_NAME = "SELF_EMPLOY_SOC_INSUR_CONTR_PER_HOUR";
    public static final String HOURS_WORKED_WEEKLY = "HOURS_WORKED_WEEKLY";

    public static double MIN_CAPITAL_INCOME_PER_MONTH = 0.0;
    public static double EPS_YPNCP = 0.01; // set to positive value to avoid explosion of ln_ypncp
    public static double MAX_CAPITAL_INCOME_PER_MONTH = 4000.0;
    public static double MIN_PERSONAL_PENSION_PER_MONTH = 0.0;
    public static double MAX_PERSONAL_PENSION_PER_MONTH = 15000.0;

    private static String taxDonorInputFileName;
    private static String populationInitialisationInputFileName;
    private static MultiKeyMap<Object, Double> populationGrowthRatiosByRegionYear;

    public static boolean saveImperfectTaxDBMatches = false;
    public static final int IMPERFECT_THRESHOLD = 5999;


    /// //////////////////////////////////////////////////////////////// INITIALISATION OF DATA STRUCTURES //////////////////////////////////
    public static Map<Integer, String> EUROMODpolicySchedule = new TreeMap<Integer, String>();
    public static Map<Integer, Pair<String, Integer>> EUROMODpolicyScheduleSystemYearMap = new TreeMap<>(); // This map stores year from which policy applies, and then a Pair of <name of policy, policy system year as specified in EM>. This is used when uprating values from the policy system year to a current simulated year.
    private static MultiKeyMap<Object, Double> fertilityRateByRegionYear;
    private static Map<Integer, Double> fertilityRateByYear;
    private static Map<Integer, Double> retiredShareByYear;
    private static MultiKeyCoefficientMap populationProjections;
    public static final int ALIGN_MIN_AGE_ASSUME_DEATH = 65;
    public static final int ALIGN_MAX_AGE_REQUIRE_MATCH = 65;
    private static int populationProjectionsMaxYear;
    private static int populationProjectionsMinYear;
    private static int populationProjectionsMaxAge;
    private static MultiKeyCoefficientMap benefitUnitVariableNames;

    //RMSE for linear regressions
    private static MultiKeyCoefficientMap coefficientMapRMSE;

    //Uprating factor
    private static boolean flagDefaultToTimeSeriesAverages;
    private static Double averageSavingReturns, averageDebtCostLow, averageDebtCostHigh;
    private static MultiKeyCoefficientMap upratingIndexMapRealGDP, upratingIndexMapInflation, socialCareProvisionTimeAdjustment,
            partnershipTimeAdjustment, retirementTimeAdjustment, fertilityTimeAdjustment, disabilityTimeAdjustment, studentsTimeAdjustment, utilityTimeAdjustment, utilityTimeAdjustmentSingleMales, utilityTimeAdjustmentSingleFemales,
            utilityTimeAdjustmentCouples, utilityTimeAdjustmentACMales, utilityTimeAdjustmentACFemales, utilityTimeAdjustmentMaleWithDep, utilityTimeAdjustmentFemaleWithDep, upratingIndexMapRealWageGrowth, priceMapRealSavingReturns, priceMapRealDebtCostLow, priceMapRealDebtCostHigh,
            wageRateFormalSocialCare, socialCarePolicy, partneredShare, retiredShare, disabledShare, studentShare, employedShare, employedShareSingleMales, employedShareACMales, employedShareSingleFemales, employedShareACFemales, employedShareCouples, employedShareMaleWithDep, employedShareFemaleWithDep;
    public static Map<Integer, Double> partnershipAlignAdjustment, fertilityAlignAdjustment, retirementAlignAdjustment, studentsAlignAdjustment, disabilityAlignAdjustment;
    // Snapshot of initial utility adjustment values loaded from alignment_adjustment_factors.xlsx,
    // preserved so that activity alignment can cold-start from xlsx values each year
    // instead of warm-starting from the previous year's (potentially overshooting) result.
    private static final java.util.Map<TimeSeriesVariable, java.util.Map<Integer, Double>> initialUtilityAdjustments = new java.util.EnumMap<>(TimeSeriesVariable.class);
    public static MultiKeyMap upratingFactorsMap = new MultiKeyMap<>();

    //Education level projections
    private static MultiKeyCoefficientMap projectionsHighEdu;            //Alignment projections for High Education
    private static MultiKeyCoefficientMap projectionsLowEdu;            //Alignment projections for Medium Education

    //Student share projections for alignment

    //Employment alignment targets
    private static MultiKeyCoefficientMap employmentAlignment;

    //Mean and covariances for parametric matching
    private static MultiKeyCoefficientMap meanCovarianceParametricMatching;

    private static MultiKeyCoefficientMap fixedRetireAge;
    //	private static MultiKeyCoefficientMap rawProbSick;
    private static MultiKeyCoefficientMap unemploymentRates;
//	private static MultiKeyMap probSick;

    //MultivariateNormalDistribution of age and potential earnings differential to use in the parametric partnership process
    public final static boolean MARRIAGE_MATCH_TO_MEANS = false;
    public static double targetMeanWageDifferential, targetMeanAgeDifferential;
    private static MultivariateNormalDistribution wageAndAgeDifferentialMultivariateNormalDistribution;

    //Mortality, fertility, and unemployment tables for the intertemporal optimisation model
    private static MultiKeyCoefficientMap mortalityProbabilityByGenderAgeYear; //Load as MultiKeyCoefficientMap as all values are in the Excel file and just need to be accessible
    private static int mortalityProbabilityMaxYear;
    private static int mortalityProbabilityMinYear;
    private static int mortalityProbabilityMaxAge;
    private static MultiKeyCoefficientMap fertilityProjectionsByYear; //NB: these currently only go up to 2043
    public static int fertilityProjectionsMaxYear;
    public static int fertilityProjectionsMinYear;
    private static MultiKeyCoefficientMap unemploymentRatesMaleGraduatesByAgeYear; //Load as MultiKeyCoefficientMap as all values are in the Excel file and just need to be accessible
    private static int unemploymentRatesMaleGraduatesMaxYear;
    private static int unemploymentRatesMaleGraduatesMinYear;
    private static int unemploymentRatesMaleGraduatesMaxAge;
    private static MultiKeyCoefficientMap unemploymentRatesMaleNonGraduatesByAgeYear; //Load as MultiKeyCoefficientMap as all values are in the Excel file and just need to be accessible
    private static int unemploymentRatesMaleNonGraduatesMaxYear;
    private static int unemploymentRatesMaleNonGraduatesMinYear;
    private static int unemploymentRatesMaleNonGraduatesMaxAge;
    private static MultiKeyCoefficientMap unemploymentRatesFemaleGraduatesByAgeYear; //Load as MultiKeyCoefficientMap as all values are in the Excel file and just need to be accessible
    private static int unemploymentRatesFemaleGraduatesMaxYear;
    private static int unemploymentRatesFemaleGraduatesMinYear;
    private static int unemploymentRatesFemaleGraduatesMaxAge;
    private static MultiKeyCoefficientMap unemploymentRatesFemaleNonGraduatesByAgeYear; //Load as MultiKeyCoefficientMap as all values are in the Excel file and just need to be accessible
    private static int unemploymentRatesFemaleNonGraduatesMaxYear;
    private static int unemploymentRatesFemaleNonGraduatesMinYear;
    private static int unemploymentRatesFemaleNonGraduatesMaxAge;

    private static MultiKeyCoefficientMap employmentsFurloughedFlex;

    /// //////////////////////////////////////////////////////////////// REGRESSION COEFFICIENTS //////////////////////////////////////////

    //Health
    private static MultiKeyCoefficientMap coeffCovarianceHealthH1;
    private static MultiKeyCoefficientMap coeffCovarianceHealthH2; //Prob. long-term sick or disabled

    //Social care
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS1a; // prob of needing social care under 65
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS1b;
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS2a; // prob of needing social care 65+
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS2b;
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS2c;
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS2d;
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS2e;
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS2f;
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS2g;
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS2h;
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS2i;
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS2j;
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS2k;
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS3a;
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS3b;
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS3c;
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS3d;
    private static MultiKeyCoefficientMap coeffCovarianceSocialCareS3e;
    private static Map<SocialCareReceiptS2c, MultiKeyCoefficientMap> coeffCovarianceSocialCareS2cMap;
    private static Map<PartnerSupplementaryCarer, MultiKeyCoefficientMap> coeffCovarianceSocialCareS2eMap;
    private static Map<NotPartnerInformalCarer, MultiKeyCoefficientMap> coeffCovarianceSocialCareS2fMap;
    private static Map<SocialCareProvision, MultiKeyCoefficientMap> coeffCovarianceSocialCareS3dMap;

    //Unemployment
    private static MultiKeyCoefficientMap coeffCovarianceUnemploymentU1a;
    private static MultiKeyCoefficientMap coeffCovarianceUnemploymentU1b;
    private static MultiKeyCoefficientMap coeffCovarianceUnemploymentU1c;
    private static MultiKeyCoefficientMap coeffCovarianceUnemploymentU1d;

    //Mental health
    private static MultiKeyCoefficientMap coeffCovarianceHM1Level; //Step 1 coefficients for mental health
    private static MultiKeyCoefficientMap coeffCovarianceHM2LevelMales; //Step 2 coefficients for mental health for males
    private static MultiKeyCoefficientMap coeffCovarianceHM2LevelFemales;

    private static MultiKeyCoefficientMap coeffCovarianceHM1Case;
    private static MultiKeyCoefficientMap coeffCovarianceHM2CaseMales;
    private static MultiKeyCoefficientMap coeffCovarianceHM2CaseFemales;

    //Education
    private static MultiKeyCoefficientMap coeffCovarianceEducationE1a;
    private static MultiKeyCoefficientMap coeffCovarianceEducationE1b;
    private static MultiKeyCoefficientMap coeffCovarianceEducationE2a;

    //Partnership
    //Partnership
    private static MultiKeyCoefficientMap coeffCovariancePartnershipU1;
    private static MultiKeyCoefficientMap coeffCovariancePartnershipU2;

    //Fertility
    private static MultiKeyCoefficientMap coeffCovarianceFertilityF1; //Probit fertility


    //Income
    private static MultiKeyCoefficientMap coeffCovarianceIncomeI1b; // coefficients of OLS regression estimates of capital income amount
                                                                    // previously I3_amount
    private static MultiKeyCoefficientMap coeffCovarianceIncomeI1a; // coefficients of Logit regression estimates of the probability of receiving capital income
                                                                    // previously I3_selection
    //Homeownership
    private static MultiKeyCoefficientMap coeffCovarianceHomeownership; //Probit regression assigning homeownership status

    //Wages
    private static MultiKeyCoefficientMap coeffCovarianceWagesMales, coeffCovarianceW1ma, coeffCovarianceW1mb;
    private static MultiKeyCoefficientMap coeffCovarianceWagesFemales, coeffCovarianceW1fa, coeffCovarianceW1fb;

    //Labour Market
    private static MultiKeyCoefficientMap coeffCovarianceEmploymentSelectionMales, coeffCovarianceEmploymentSelectionMalesNE, coeffCovarianceEmploymentSelectionMalesE;
    private static MultiKeyCoefficientMap coeffCovarianceEmploymentSelectionFemales, coeffCovarianceEmploymentSelectionFemalesNE, coeffCovarianceEmploymentSelectionFemalesE;
    private static MultiKeyCoefficientMap coeffLabourSupplyUtilityMales;
    private static MultiKeyCoefficientMap coeffLabourSupplyUtilityFemales;
    private static MultiKeyCoefficientMap coeffLabourSupplyUtilityMalesWithDependent; //For use with couples where only male is flexible in labour supply (so has a dependent)
    private static MultiKeyCoefficientMap coeffLabourSupplyUtilityFemalesWithDependent;
    private static MultiKeyCoefficientMap coeffLabourSupplyUtilityACMales; //Adult children, male

    private static MultiKeyCoefficientMap coeffLabourSupplyUtilityACFemales; //Adult children, female
    private static MultiKeyCoefficientMap coeffLabourSupplyUtilityCouples;

    // Transitions
    // From lagged state "employed"
    private static MultiKeyCoefficientMap coeffC19LS_E1_NE; // For multi probit regressions, have to specify coefficients for each possible outcome, with "no changes" being the baseline. NE is not-employed.
    private static MultiKeyCoefficientMap coeffC19LS_E1_SE; // self-employed
    private static MultiKeyCoefficientMap coeffC19LS_E1_FF; // furloughed full
    private static MultiKeyCoefficientMap coeffC19LS_E1_FX; // furloughed flex
    private static MultiKeyCoefficientMap coeffC19LS_E1_SC; // some changes
    // From lagged state "furloughed full"
    private static MultiKeyCoefficientMap coeffC19LS_FF1_E; // employed
    private static MultiKeyCoefficientMap coeffC19LS_FF1_FX; // furloughed flex
    private static MultiKeyCoefficientMap coeffC19LS_FF1_NE; // not-employed
    private static MultiKeyCoefficientMap coeffC19LS_FF1_SE; // self-employed
    // From lagged state "furloughed flex"
    private static MultiKeyCoefficientMap coeffC19LS_FX1_E; // employed
    private static MultiKeyCoefficientMap coeffC19LS_FX1_FF; // furloughed flex
    private static MultiKeyCoefficientMap coeffC19LS_FX1_NE; // not-employed
    private static MultiKeyCoefficientMap coeffC19LS_FX1_SE; // self-employed
    // From lagged state "self-employed"
    private static MultiKeyCoefficientMap coeffC19LS_S1_E; // employed
    private static MultiKeyCoefficientMap coeffC19LS_S1_NE; // not-employed
    // From lagged state "not-employed"
    private static MultiKeyCoefficientMap coeffC19LS_U1_E; // employed
    private static MultiKeyCoefficientMap coeffC19LS_U1_SE; // self-employed

    // Define maps that the above coefficients are bundled into
    private static Map<Les_transitions_E1, MultiKeyCoefficientMap> coeffC19LS_E1Map;
    private static Map<Les_transitions_FF1, MultiKeyCoefficientMap> coeffC19LS_FF1Map;
    private static Map<Les_transitions_FX1, MultiKeyCoefficientMap> coeffC19LS_FX1Map;
    private static Map<Les_transitions_S1, MultiKeyCoefficientMap> coeffC19LS_S1Map;
    private static Map<Les_transitions_U1, MultiKeyCoefficientMap> coeffC19LS_U1Map;

    // Hours of work
    private static MultiKeyCoefficientMap coeffC19LS_E2a;
    private static MultiKeyCoefficientMap coeffC19LS_E2b;
    private static MultiKeyCoefficientMap coeffC19LS_F2a;
    private static MultiKeyCoefficientMap coeffC19LS_F2b;
    private static MultiKeyCoefficientMap coeffC19LS_F2c;
    private static MultiKeyCoefficientMap coeffC19LS_S2a;
    private static MultiKeyCoefficientMap coeffC19LS_U2a;

    // Probability of receiving SEISS
    private static MultiKeyCoefficientMap coeffC19LS_S3;

    //Leaving parental home
    private static MultiKeyCoefficientMap coeffCovarianceLeaveHomeP1;

    //Retirement
    private static MultiKeyCoefficientMap coeffCovarianceRetirementR1a;
    private static MultiKeyCoefficientMap coeffCovarianceRetirementR1b;

    //Childcare
    private static MultiKeyCoefficientMap coeffCovarianceChildcareC1a;
    private static MultiKeyCoefficientMap coeffCovarianceChildcareC1b;

    /// ////////////////////////////////////////////////////////STATISTICS FOR VALIDATION/////////////////////////////////////////////
    //Share of students by age
    private static MultiKeyCoefficientMap validationStudentsByAge;

    //Share of students by region
    private static MultiKeyCoefficientMap validationStudentsByRegion;

    //Education level of over 17 year olds
    private static MultiKeyCoefficientMap validationEducationLevel;

    //Education level by age group
    private static MultiKeyCoefficientMap validationEducationLevelByAge;

    //Education level by region
    private static MultiKeyCoefficientMap validationEducationLevelByRegion;

    //Share of couple by region
    private static MultiKeyCoefficientMap validationPartneredShareByRegion;

    //Share of disabled by age
    private static MultiKeyCoefficientMap validationDisabledByAge;

    private static MultiKeyCoefficientMap validationDisabledByGender;

    //Health by age
    private static MultiKeyCoefficientMap validationHealthByAge;

    //Mental health by age and gender
    private static MultiKeyCoefficientMap validationMentalHealthByAge;

    //Psychological distress cases by age and gender
    private static MultiKeyCoefficientMap validationPsychDistressByAge, validationPsychDistressByAgeLow, validationPsychDistressByAgeMed, validationPsychDistressByAgeHigh;

    //Employment by gender
    private static MultiKeyCoefficientMap validationEmploymentByGender;

    //Employment by gender and age
    private static MultiKeyCoefficientMap validationEmploymentByAgeAndGender;

    //Employment by maternity
    private static MultiKeyCoefficientMap validationEmploymentByMaternity;

    //Employment by gender and region
    private static MultiKeyCoefficientMap validationEmploymentByGenderAndRegion;

    private static MultiKeyCoefficientMap validationLabourSupplyByEducation;

    //Activity status
    private static MultiKeyCoefficientMap validationActivityStatus;

    //Homeownership status for benefit units
    private static MultiKeyCoefficientMap validationHomeownershipBenefitUnits;

    //Gross earnings yearly by education and gender (for employed persons)
    private static MultiKeyCoefficientMap validationGrossEarningsByGenderAndEducation;

    //Hourly wages by education and gender (for employed persons)
    private static MultiKeyCoefficientMap validationLhwByGenderAndEducation;

    //Hours worked weekly by education and gender (for employed persons)
    private static MultiKeyCoefficientMap hourlyWageByGenderAndEducation;

    /// //////////////////////////////////////////////////////////////// REGRESSION OBJECTS //////////////////////////////////////////

    //Health
    private static GeneralisedOrderedRegression regHealthH1;
    private static BinomialRegression regHealthH2;

    //Social care
    private static BinomialRegression regReceiveCareS1a;
    private static LinearRegression regCareHoursS1b;
    private static BinomialRegression regNeedCareS2a;
    private static BinomialRegression regReceiveCareS2b;
    private static MultinomialRegression<SocialCareReceiptS2c> regSocialCareMarketS2c;
    private static BinomialRegression regReceiveCarePartnerS2d;
    private static MultinomialRegression<PartnerSupplementaryCarer> regPartnerSupplementaryCareS2e;
    private static MultinomialRegression<NotPartnerInformalCarer> regNotPartnerInformalCareS2f;
    private static LinearRegression regPartnerCareHoursS2g;
    private static LinearRegression regDaughterCareHoursS2h;
    private static LinearRegression regSonCareHoursS2i;
    private static LinearRegression regOtherCareHoursS2j;
    private static LinearRegression regFormalCareHoursS2k;
    private static BinomialRegression regCarePartnerProvCareToOtherS3a;
    private static BinomialRegression regNoCarePartnerProvCareToOtherS3b;
    private static BinomialRegression regNoPartnerProvCareToOtherS3c;
    private static MultinomialRegression<SocialCareProvision> regInformalCareToS3d;
    private static LinearRegression regCareHoursProvS3e;

    //Unemployment
    private static BinomialRegression regUnemploymentMaleGraduateU1a;
    private static BinomialRegression regUnemploymentMaleNonGraduateU1b;
    private static BinomialRegression regUnemploymentFemaleGraduateU1c;
    private static BinomialRegression regUnemploymentFemaleNonGraduateU1d;

    //Health mental
    private static LinearRegression regHealthHM1Level;
    private static LinearRegression regHealthHM2LevelMales;
    private static LinearRegression regHealthHM2LevelFemales;

    private static BinomialRegression regHealthHM1Case;
    private static BinomialRegression regHealthHM2CaseMales;
    private static BinomialRegression regHealthHM2CaseFemales;

    //Education
    private static BinomialRegression regEducationE1a;
    private static BinomialRegression regEducationE1b;
    private static GeneralisedOrderedRegression regEducationE2a;

    //Partnership
    private static BinomialRegression regPartnershipU1;
    private static BinomialRegression regPartnershipU2;

//    //Partnership
//    private static BinomialRegression regPartnershipU1a;
//    private static BinomialRegression regPartnershipU1b;
//    private static BinomialRegression regPartnershipU2b;

    private static BinomialRegression regPartnershipITU1;
    private static BinomialRegression regPartnershipITU2;

    //Fertility
    private static BinomialRegression regFertilityF1;

    //Income
    private static LinearRegression regIncomeI1b;   // OLS regression estimates (ihs) capital income amount -  who receive capital income
    private static BinomialRegression regIncomeI1a; // Logit regression estimates of the probability of receiving capital income

    //Homeownership
    private static BinomialRegression regHomeownershipHO1;

    //New regressions from Lia
    private static BinomialRegression regSchooling;
    private static MultinomialRegression<Education> regEducationLevel;

    //New simple educ level
    private static MultinomialRegression<Education> regSimpleEducLevel;

    //For Labour market
    private static LinearRegression regWagesMales;
    private static LinearRegression regW1mb;
    private static LinearRegression regW1ma;
    private static LinearRegression regWagesFemales, regW1fb, regW1fa;

    private static LinearRegression regEmploymentSelectionMale, regEmploymentSelectionMaleE, regEmploymentSelectionMaleNE;        //To calculate Inverse Mills Ratio for Heckman Two-Step Procedure
    private static LinearRegression regEmploymentSelectionFemale, regEmploymentSelectionFemaleE, regEmploymentSelectionFemaleNE;    //To calculate Inverse Mills Ratio for Heckman Two-Step Procedure
    private static NormalDistribution standardNormalDistribution;    //To sample the inverse mills ratio

    private static LinearRegression regLabourSupplyUtilityMales;
    private static LinearRegression regLabourSupplyUtilityFemales;

    private static LinearRegression regLabourSupplyUtilityMalesWithDependent;
    private static LinearRegression regLabourSupplyUtilityFemalesWithDependent;

    private static LinearRegression regLabourSupplyUtilityACMales;
    private static LinearRegression regLabourSupplyUtilityACFemales;
    private static LinearRegression regLabourSupplyUtilityCouples;

    // Covid-19 labour transitions regressions below
    // Initialisation
    private static BinomialRegression regC19LS_SE; // Assigns self-employed status in the simulated population
    // Transitions
    private static MultinomialRegression<Les_transitions_E1> regC19LS_E1;  // Models transitions from employment
    private static MultinomialRegression<Les_transitions_FF1> regC19LS_FF1;  // Models transitions from furlough full
    private static MultinomialRegression<Les_transitions_FX1> regC19LS_FX1;  // Models transitions from furlough flex
    private static MultinomialRegression<Les_transitions_S1> regC19LS_S1;  // Models transitions from self-employment
    private static MultinomialRegression<Les_transitions_U1> regC19LS_U1;  // Models transitions from non-employment
    // Hours of work
    private static LinearRegression regC19LS_E2a;
    private static LinearRegression regC19LS_E2b;
    private static LinearRegression regC19LS_F2a;
    private static LinearRegression regC19LS_F2b;
    private static LinearRegression regC19LS_F2c;
    private static LinearRegression regC19LS_S2a;
    private static LinearRegression regC19LS_U2a;

    // Probability of SEISS
    private static BinomialRegression regC19LS_S3;

    //Leaving parental home
    private static BinomialRegression regLeaveHomeP1;

    //Retirement
    private static BinomialRegression regRetirementR1a;
    private static BinomialRegression regRetirementR1b;

    //Childcare
    private static BinomialRegression regChildcareC1a;
    private static LinearRegression regChildcareC1b;

    private static BinomialRegression regBirthFemales;
    private static BinomialRegression regUnionFemales;
    private static Set<Region> countryRegions;
    private static Map<Region, Double> unemploymentRatesByRegion;
    public static boolean isFixTimeTrend;
    public static boolean isFixTimeTrendR1a;
    public static boolean isFixTimeTrendR1b;
    public static boolean isFixTimeTrendE1a;
    public static boolean isFixTimeTrendE1b;
    public static boolean isFixTimeTrendE2a;
    public static Integer timeTrendStopsIn;
    public static Integer timeTrendStopsInR1a;
    public static Integer timeTrendStopsInR1b;
    public static Integer timeTrendStopsInE1a;
    public static Integer timeTrendStopsInE1b;
    public static Integer timeTrendStopsInE2a;
    // When the Ramsey macro layer supplies the secular wage trend, the exogenous WageGrowth
    // index must not also trend out of sample, or the secular real wage is double-counted
    // (Ramsey trend stacked on top of the extrapolated wage_growth index). Freeze the index
    // at its last in-sample year for the projection; in-sample years are untouched.
    public static boolean freezeWageGrowthForRamseyTrend = false;
    public static int wageGrowthLastInSampleYear = Integer.MAX_VALUE;
    public static boolean flagFormalChildcare;
    public static boolean flagSocialCare;
    public static boolean flagSuppressChildcareCosts;
    public static boolean flagSuppressSocialCareCosts;
    public static boolean donorPoolAveraging;

    public static double realInterestRateInnov;
    public static double disposableIncomeFromLabourInnov;

    private static MultiKeyCoefficientMap countrySpecificParameters;



    public static class ParametersLoader {

        public static void setParametersFromMap(Map<MultiKey<?>, Object> countrySpecificParameters) {
            Class<?> parametersClass = Parameters.class;

            for (Map.Entry<MultiKey<?>, Object> entry : countrySpecificParameters.entrySet()) {
                MultiKey<?> multiKey = entry.getKey();
                Object value = entry.getValue();

                // Extract parameter name from MultiKey (adjust index as needed)
                String paramName;
                if (multiKey != null && multiKey.size() > 1) {
                    paramName = multiKey.getKey(1).toString();  // Allow the MultiKey to be composed of several fields - e.g. the first could be some numerical ID
                } else if (multiKey != null && multiKey.size() == 1) {
                    paramName = multiKey.getKey(0).toString();  // However, currently only using the first column as the key
                } else {
                    throw new IllegalArgumentException("Invalid multi-key parameter defined in Excel: " + multiKey);
                }

                try {
                    Field field = parametersClass.getDeclaredField(paramName);
                    if ((field.getModifiers() & Modifier.STATIC) != 0) {
                        field.setAccessible(true);

                        Class<?> fieldType = field.getType();

                        Object convertedValue = convertValueToFieldType(value, fieldType);

                        if (convertedValue != null) {
                            field.set(null, convertedValue);
                        }
                    }
                } catch (NoSuchFieldException e) {
                    System.out.println("No such field: " + paramName);
                } catch (IllegalAccessException e) {
                    System.err.println("Failed to set field: " + paramName + " - " + e.getMessage());
                }
            }
        }

        private static Object convertValueToFieldType(Object value, Class<?> fieldType) {
            if (value == null) return null;
            if (fieldType.isAssignableFrom(value.getClass())) return value;

            // --- BOOLEAN ---
            if (fieldType == boolean.class || fieldType == Boolean.class) {
                if (value instanceof Boolean) return value;
                if (value instanceof Number) return ((Number) value).intValue() != 0;
                if (value instanceof String) {
                    String s = ((String) value).trim();
                    if (s.isEmpty()) return null; // keep default if Excel cell is blank
                    Boolean b = parseFlexibleBoolean(s);
                    if (b != null) return b;
                }
                throw new IllegalArgumentException("Cannot convert '" + value + "' to boolean");
            }

            // --- INT ---
            if (fieldType == int.class || fieldType == Integer.class) {
                if (value instanceof Number) return ((Number) value).intValue();
                if (value instanceof String) return Integer.parseInt((String) value);
            }

            // --- LONG ---
            else if (fieldType == long.class || fieldType == Long.class) {
                if (value instanceof Number) return ((Number) value).longValue();
                if (value instanceof String) return Long.parseLong((String) value);
            }

            // --- DOUBLE ---
            else if (fieldType == double.class || fieldType == Double.class) {
                if (value instanceof Number) return ((Number) value).doubleValue();
                if (value instanceof String) return Double.parseDouble((String) value);
            }

            // --- STRING ---
            else if (fieldType == String.class) {
                return value.toString();
            }

            throw new IllegalArgumentException("Cannot convert " + value + " to " + fieldType);
        }

        // Boolean parser from String
        private static Boolean parseFlexibleBoolean(String s) {
            String v = s.trim().toLowerCase();
            switch (v) {
                case "true":
                case "t":
                case "yes":
                case "y":
                case "1":
                    return true;
                case "false":
                case "f":
                case "no":
                case "n":
                case "0":
                    return false;
                default:
                    return null; // signals "unrecognised" to caller
            }
        }


    }

    // the method adds missing fixed-cost regressors with zero values to enable employment alignment
    private static void addFixedCostRegressors(MultiKeyCoefficientMap map, List<String> regressors) {
        for (String reg : regressors) {
            if ((reg.equals("AlignmentFixedCostMen") || reg.equals("AlignmentFixedCostWomen"))
                    && map.getValue(reg) == null) {
                // Infer the format from an existing coefficient
                Object sample = map.getValue("IncomeDiv100");
                if (sample instanceof Object[]) {
                    map.putValue(reg, new Object[]{0.0});
                } else {
                    map.putValue(reg, 0.0);
                }
            }
        }
    }


    public static void defineCountryString(Country country) {COUNTRY_STRING  =country.toString(); }

    /**
     * METHOD TO LOAD PARAMETERS FOR GIVEN COUNTRY
     *
     * @param country
     * @param macroShockPopulation
     */

    public static void loadParameters(Country country, int maxAgeModel, boolean enableIntertemporalOptimisations,
                                      boolean projectFormalChildcare, boolean projectSocialCare, boolean donorPoolAveraging1,
                                      boolean fixTimeTrend, boolean fixTimeTrendR1a, boolean fixTimeTrendR1b, boolean fixTimeTrendE1a, boolean fixTimeTrendE1b, boolean fixTimeTrendE2a,
                                      boolean defaultToTimeSeriesAverages, boolean taxDBMatches,
                                      Integer timeTrendStops, Integer timeTrendStopsR1a, Integer timeTrendStopsR1b,  Integer timeTrendStopsE1a, Integer timeTrendStopsE1b, Integer timeTrendStopsE2a,
                                      int startYearModel, int endYearModel, double interestRateInnov1,
                                      double disposableIncomeFromLabourInnov1, boolean flagSuppressChildcareCosts1,
                                      boolean flagSuppressSocialCareCosts1, MacroScenarioPopulation macroShockPopulation,
                                      MacroScenarioProductivity macroShockProductivity, MacroScenarioGreenPolicy macroShockGreenPolicy, boolean macroShocksOn) {

        // display a dialog box to let the user know what is happening
        System.out.println("Loading model parameters");
        System.out.flush();

        /**
         * countrySpecificParameters map contains country-specific values of parameters declared in this Parameters class.
         * setParametersFromMap overrides many of the defaults declared above with values read from
         * input/<COUNTRY>/parameters.xlsx, so keep that file updated when changing parameter defaults.
         */

        countrySpecificParameters = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "parameters.xlsx"), "Parameters", 1);
        ParametersLoader.setParametersFromMap(countrySpecificParameters);

        maxAge      = maxAgeModel;
        startYear   = startYearModel;
        endYear     = endYearModel;
        MIN_AGE_COHABITATION = AGE_TO_BECOME_RESPONSIBLE;  	// Min age a person can marry


        EUROMODpolicySchedule = calculateEUROMODpolicySchedule(country);
        //taxDonorInputFileName = "population_" + country;
        populationInitialisationInputFileName = "population_initial_" + country;
        setCountryRegions(country);
        setEnableIntertemporalOptimisations(enableIntertemporalOptimisations);
        setProjectLiquidWealth();
        String countryString = country.toString();
        COUNTRY_STRING  = country.toString();
        loadTimeSeriesFactorMaps(country);
        instantiateAlignmentMaps();

        // scenario parameters
        saveImperfectTaxDBMatches = taxDBMatches;

        flagDefaultToTimeSeriesAverages = defaultToTimeSeriesAverages;
        isFixTimeTrend = fixTimeTrend;
        isFixTimeTrendR1a = fixTimeTrendR1a;
        isFixTimeTrendR1b = fixTimeTrendR1b;
        isFixTimeTrendE1a = fixTimeTrendE1a;
        isFixTimeTrendE1b = fixTimeTrendE1b;
        isFixTimeTrendE2a = fixTimeTrendE2a;
        timeTrendStopsIn = timeTrendStops;
        timeTrendStopsInR1a = timeTrendStopsR1a;
        timeTrendStopsInR1b = timeTrendStopsR1b;
        timeTrendStopsInE1a = timeTrendStopsE1a;
        timeTrendStopsInE1b = timeTrendStopsE1b;
        timeTrendStopsInE2a = timeTrendStopsE2a;
        flagFormalChildcare = projectFormalChildcare;
        flagSocialCare = projectSocialCare;
        flagSuppressChildcareCosts = flagSuppressChildcareCosts1;
        flagSuppressSocialCareCosts = flagSuppressSocialCareCosts1;
        donorPoolAveraging = donorPoolAveraging1;
        realInterestRateInnov = interestRateInnov1;
        disposableIncomeFromLabourInnov = disposableIncomeFromLabourInnov1;
        fixedRetireAge = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_retirementAgeFixed.xlsx"), "Retirement_age", 1);

        /*
        Code below introduces macro shocks in terms of population, productivity, and employment

         */

        //Load country specific data on columns number in excel estimate and alignment files


            // Macro population switch
        if (macroShocksOn) {
            switch (macroShockPopulation) {
                case High:
                    populationProjections = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "population_high", 3);

                    // Productivity sub-switch
                    switch (macroShockProductivity) {
                        case Baseline:
                            // Green policy sub-switch
                            switch (macroShockGreenPolicy) {
                                case Yes:
                                    upratingIndexMapRealGDP = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "gdp_highpop_baseprod_green", 1);
                                    upratingIndexMapRealWageGrowth = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "wage_highpop_baseprod_green", 1);
                                    rebaseIndexMap(TimeSeriesVariable.GDP);
                                    rebaseIndexMap(TimeSeriesVariable.WageGrowth);
                                    employedShareSingleMales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_highpop_baseprod_green", 1);
                                    employedShareSingleFemales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_highpop_baseprod_green", 1);
                                    employedShareCouples = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_highpop_baseprod_green", 1);
                                    employedShare = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_highpop_baseprod_green", 1);
                                    break;
                                case No:
                                default:
                                    throw new IllegalArgumentException("Unsupported combination: High population + "
                                            + macroShockProductivity + " + " + macroShockGreenPolicy);
                            }
                            break;
                        case High:
                        case Low:
                            throw new IllegalArgumentException("Unsupported combination: High population + "
                                    + macroShockProductivity);
                        default:
                            throw new IllegalStateException("Unexpected productivity value: " + macroShockProductivity);
                    }
                    break;

                case Low:
                    populationProjections = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "population_low", 3);

                    switch (macroShockProductivity) {
                        case Baseline:
                            switch (macroShockGreenPolicy) {
                                case Yes:
                                    upratingIndexMapRealGDP = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "gdp_lowpop_baseprod_green", 1);
                                    upratingIndexMapRealWageGrowth = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "wage_lowpop_baseprod_green", 1);
                                    rebaseIndexMap(TimeSeriesVariable.GDP);
                                    rebaseIndexMap(TimeSeriesVariable.WageGrowth);
                                    employedShareSingleMales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_lowpop_baseprod_green", 1);
                                    employedShareSingleFemales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_lowpop_baseprod_green", 1);
                                    employedShareCouples = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_lowpop_baseprod_green", 1);
                                    employedShare = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_lowpop_baseprod_green", 1);
                                    break;
                                case No:
                                default:
                                    throw new IllegalArgumentException("Unsupported combination: Low population + "
                                            + macroShockProductivity + " + " + macroShockGreenPolicy);
                            }
                            break;
                        case High:
                        case Low:
                            throw new IllegalArgumentException("Unsupported combination: Low population + "
                                    + macroShockProductivity);
                        default:
                            throw new IllegalStateException("Unexpected productivity value: " + macroShockProductivity);
                    }
                    break;

                case Baseline:
                default:
                    populationProjections = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "align_popProjections.xlsx"), "Population_projections", 3);

                    switch (macroShockProductivity) {
                        case Baseline:
                            switch (macroShockGreenPolicy) {
                                case Yes:
                                    upratingIndexMapRealGDP = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "gdp_basepop_baseprod_green", 1);
                                    upratingIndexMapRealWageGrowth = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "wage_basepop_baseprod_green", 1);
                                    rebaseIndexMap(TimeSeriesVariable.GDP);
                                    rebaseIndexMap(TimeSeriesVariable.WageGrowth);
                                    employedShareSingleMales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_baseprod_green", 1);
                                    employedShareSingleFemales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_baseprod_green", 1);
                                    employedShareCouples = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_baseprod_green", 1);
                                    employedShare = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_baseprod_green", 1);
                                    break;
                                case No:
                                default:
                                    upratingIndexMapRealGDP = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "gdp_basepop_baseprod", 1);
                                    upratingIndexMapRealWageGrowth = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "wage_basepop_baseprod", 1);
                                    rebaseIndexMap(TimeSeriesVariable.GDP);
                                    rebaseIndexMap(TimeSeriesVariable.WageGrowth);
                                    employedShareSingleMales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_baseprod", 1);
                                    employedShareSingleFemales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_baseprod", 1);
                                    employedShareCouples = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_baseprod", 1);
                                    employedShare = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_baseprod_green", 1);
                                    break;
                            }
                            break;
                        case High:
                            switch (macroShockGreenPolicy) {
                                case Yes:
                                    upratingIndexMapRealGDP = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "gdp_basepop_highprod_green", 1);
                                    upratingIndexMapRealWageGrowth = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "wage_basepop_highprod_green", 1);
                                    rebaseIndexMap(TimeSeriesVariable.GDP);
                                    rebaseIndexMap(TimeSeriesVariable.WageGrowth);
                                    employedShareSingleMales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_highprod_green", 1);
                                    employedShareSingleFemales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_highprod_green", 1);
                                    employedShareCouples = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_highprod_green", 1);
                                    employedShare = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_baseprod_green", 1);
                                    break;
                                case No:
                                default:
                                    upratingIndexMapRealGDP = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "gdp_basepop_highprod", 1);
                                    upratingIndexMapRealWageGrowth = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "wage_basepop_highprod", 1);
                                    rebaseIndexMap(TimeSeriesVariable.GDP);
                                    rebaseIndexMap(TimeSeriesVariable.WageGrowth);
                                    employedShareSingleMales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_highprod", 1);
                                    employedShareSingleFemales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_highprod", 1);
                                    employedShareCouples = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_highprod", 1);
                                    employedShare = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_macro_shocks.xlsx"), "emp_basepop_baseprod_green", 1);
                                    break;
                            }
                            break;
                        case Low:
                            throw new IllegalArgumentException("Unsupported combination: Baseline population + Low productivity");
                        default:
                            throw new IllegalStateException("Unexpected productivity value: " + macroShockProductivity);
                    }
                    break;
            }
        } else {
            populationProjections = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "align_popProjections.xlsx"), "Population_projections", 3);
        }


        setMapBounds(MapBounds.Population, countryString);



        // Not currently used. Consider removing.
        projectionsHighEdu = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "align_educLevel.xlsx"), "High", 1);
        projectionsLowEdu = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "align_educLevel.xlsx"), "Low", 1);

        //Employment alignment
        //employmentAlignment = ExcelAssistant.loadCoefficientMap("input/align_employment.xlsx", countryString, 2);

        //Fertility rates:
        fertilityProjectionsByYear = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "projections_fertility.xlsx"), "FertilityByYear", 1);
        setMapBounds(MapBounds.Fertility, countryString);

        //RMSE
        coefficientMapRMSE = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_RMSE.xlsx"), "RMSE", 1);

        //Mortality rates
        mortalityProbabilityByGenderAgeYear = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "projections_mortality.xlsx"), "MortalityByGenderAgeYear", 2);
        setMapBounds(MapBounds.Mortality, countryString);



        //The Raw maps contain the estimates and covariance matrices, from which we bootstrap at the start of each simulation

        // Wages
        coeffCovarianceW1mb = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_wages.xlsx"), "W1mb", 1);
        coeffCovarianceW1ma = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_wages.xlsx"), "W1ma", 1);
        coeffCovarianceW1fb = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_wages.xlsx"), "W1fb", 1);
        coeffCovarianceW1fa = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_wages.xlsx"), "W1fa", 1);

        //Labour Supply utility function coefficients
        //Employment alignment adjusts *fixed-cost* -> add the relevant alignment fixed-cost regressors to each subgroup
        coeffLabourSupplyUtilityMales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_labourSupplyUtility.xlsx"),"Single_male", 1);
        coeffLabourSupplyUtilityFemales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_labourSupplyUtility.xlsx"),"Single_female", 1);
        coeffLabourSupplyUtilityMalesWithDependent = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_labourSupplyUtility.xlsx"),"SingleDep_Males", 1);
        coeffLabourSupplyUtilityFemalesWithDependent = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_labourSupplyUtility.xlsx"),"SingleDep_Females", 1);
        coeffLabourSupplyUtilityACMales =ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_labourSupplyUtility.xlsx"),"SingleAC_Males", 1);
        coeffLabourSupplyUtilityACFemales =ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_labourSupplyUtility.xlsx"),"SingleAC_Females", 1);
        coeffLabourSupplyUtilityCouples =ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_labourSupplyUtility.xlsx"),"Couples", 1);


        //Heckman model employment selection
        coeffCovarianceEmploymentSelectionMalesE = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_employmentSelection.xlsx"), "W1mb-sel", 1);
        coeffCovarianceEmploymentSelectionMalesNE = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_employmentSelection.xlsx"), "W1ma-sel", 1);
        coeffCovarianceEmploymentSelectionFemalesE = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_employmentSelection.xlsx"), "W1fb-sel", 1);
        coeffCovarianceEmploymentSelectionFemalesNE = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_employmentSelection.xlsx"), "W1fa-sel", 1);

        //Health
        coeffCovarianceHealthH1 = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_health.xlsx"), "H1", 1);
        coeffCovarianceHealthH2 = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_health.xlsx"),  "H2", 1);

        //Education
        coeffCovarianceEducationE1a = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_education.xlsx"), "E1a", 1);
        coeffCovarianceEducationE1b = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_education.xlsx"), "E1b", 1);
        coeffCovarianceEducationE2a = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_education.xlsx"), "E2a", 1);

        //Partnership
        coeffCovariancePartnershipU1 = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_partnership.xlsx"),"U1", 1);
        coeffCovariancePartnershipU2 = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_partnership.xlsx"), "U2", 1);

        //Partnership - parameters for matching based on wage and age differential
        meanCovarianceParametricMatching = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "scenario_parametricMatching.xlsx"), "Parameters", 1);

        //Fertility
        coeffCovarianceFertilityF1 = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_fertility.xlsx"), "F1", 1);

        //Income
        coeffCovarianceIncomeI1a = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_income.xlsx"), "I1a", 1);
        coeffCovarianceIncomeI1b = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_income.xlsx"), "I1b", 1);

        //Leaving parental home
        coeffCovarianceLeaveHomeP1 = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_leave_parental_home.xlsx"), "P1", 1);

        //Homeownership
        coeffCovarianceHomeownership = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_home_ownership.xlsx"), "HO1", 1);

        //Retirement
        coeffCovarianceRetirementR1a = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_retirement.xlsx"), "R1a", 1);
        coeffCovarianceRetirementR1b = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "reg_retirement.xlsx"), "R1b", 1);


        //Bootstrap the coefficients
        if(bootstrapAll) {
            validateCoefficientMapsForBootstrap(new Object[][]{

                    {"coeffCovarianceW1mb", coeffCovarianceW1mb},
                    {"coeffCovarianceW1ma", coeffCovarianceW1ma},
                    {"coeffCovarianceW1fb", coeffCovarianceW1fb},
                    {"coeffCovarianceW1fa", coeffCovarianceW1fa},

                    {"coeffCovarianceEmploymentSelectionMalesE", coeffCovarianceEmploymentSelectionMalesE},
                    {"coeffCovarianceEmploymentSelectionMalesNE", coeffCovarianceEmploymentSelectionMalesNE},
                    {"coeffCovarianceEmploymentSelectionFemalesE", coeffCovarianceEmploymentSelectionFemalesE},
                    {"coeffCovarianceEmploymentSelectionFemalesNE", coeffCovarianceEmploymentSelectionFemalesNE},

                    {"coeffLabourSupplyUtilityMales", coeffLabourSupplyUtilityMales},
                    {"coeffLabourSupplyUtilityFemales", coeffLabourSupplyUtilityFemales},
                    {"coeffLabourSupplyUtilityMalesWithDependent", coeffLabourSupplyUtilityMalesWithDependent},
                    {"coeffLabourSupplyUtilityFemalesWithDependent", coeffLabourSupplyUtilityFemalesWithDependent},
                    {"coeffLabourSupplyUtilityACMales", coeffLabourSupplyUtilityACMales},
                    {"coeffLabourSupplyUtilityACFemales", coeffLabourSupplyUtilityACFemales},
                    {"coeffLabourSupplyUtilityCouples", coeffLabourSupplyUtilityCouples},
                    {"coeffCovarianceEducationE1a", coeffCovarianceEducationE1a},
                    {"coeffCovarianceEducationE1b", coeffCovarianceEducationE1b},
                    {"coeffCovarianceEducationE2a", coeffCovarianceEducationE2a},

                    {"coeffCovarianceHealthH1", coeffCovarianceHealthH1},
                    {"coeffCovarianceHealthH2", coeffCovarianceHealthH2},

                    {"coeffCovarianceIncomeI1a", coeffCovarianceIncomeI1a},
                    {"coeffCovarianceIncomeI1b", coeffCovarianceIncomeI1b},
                    {"coeffCovarianceLeaveHomeP1", coeffCovarianceLeaveHomeP1},
                    {"coeffCovarianceHomeownership", coeffCovarianceHomeownership},
                    {"coeffCovarianceRetirementR1a", coeffCovarianceRetirementR1a},
                    {"coeffCovarianceRetirementR1b", coeffCovarianceRetirementR1b},

                    {"coeffCovariancePartnershipU1", coeffCovariancePartnershipU1},
                    {"coeffCovariancePartnershipU2", coeffCovariancePartnershipU2},
                    {"coeffCovarianceFertilityF1", coeffCovarianceFertilityF1},
            });


            //Wages
            coeffCovarianceW1mb = RegressionUtils.bootstrap(coeffCovarianceW1mb);
            coeffCovarianceW1ma = RegressionUtils.bootstrap(coeffCovarianceW1ma);
            coeffCovarianceW1fb = RegressionUtils.bootstrap(coeffCovarianceW1fb);
            coeffCovarianceW1fa = RegressionUtils.bootstrap(coeffCovarianceW1fa);

            //Employment selection
            coeffCovarianceEmploymentSelectionMalesE = RegressionUtils.bootstrap(coeffCovarianceEmploymentSelectionMalesE);
            coeffCovarianceEmploymentSelectionMalesNE = RegressionUtils.bootstrap(coeffCovarianceEmploymentSelectionMalesNE);
            coeffCovarianceEmploymentSelectionFemalesE = RegressionUtils.bootstrap(coeffCovarianceEmploymentSelectionFemalesE);
            coeffCovarianceEmploymentSelectionFemalesNE = RegressionUtils.bootstrap(coeffCovarianceEmploymentSelectionFemalesNE);

            //Labour supply utility
            coeffLabourSupplyUtilityMales = RegressionUtils.bootstrap(coeffLabourSupplyUtilityMales);
            addFixedCostRegressors(coeffLabourSupplyUtilityMales,List.of("AlignmentFixedCostMen"));
            coeffLabourSupplyUtilityFemales = RegressionUtils.bootstrap(coeffLabourSupplyUtilityFemales);
            addFixedCostRegressors(coeffLabourSupplyUtilityFemales,List.of("AlignmentFixedCostWomen"));
            coeffLabourSupplyUtilityMalesWithDependent = RegressionUtils.bootstrap(coeffLabourSupplyUtilityMalesWithDependent);
            addFixedCostRegressors(coeffLabourSupplyUtilityMalesWithDependent,List.of("AlignmentFixedCostMen"));
            coeffLabourSupplyUtilityFemalesWithDependent = RegressionUtils.bootstrap(coeffLabourSupplyUtilityFemalesWithDependent);
            addFixedCostRegressors(coeffLabourSupplyUtilityFemalesWithDependent,List.of("AlignmentFixedCostWomen"));
            coeffLabourSupplyUtilityACMales = RegressionUtils.bootstrap(coeffLabourSupplyUtilityACMales);
            addFixedCostRegressors(coeffLabourSupplyUtilityACMales,List.of("AlignmentFixedCostMen"));
            coeffLabourSupplyUtilityACFemales = RegressionUtils.bootstrap(coeffLabourSupplyUtilityACFemales);
            addFixedCostRegressors(coeffLabourSupplyUtilityACFemales,List.of("AlignmentFixedCostWomen"));
            coeffLabourSupplyUtilityCouples = RegressionUtils.bootstrap(coeffLabourSupplyUtilityCouples);
            addFixedCostRegressors(coeffLabourSupplyUtilityCouples,List.of("AlignmentFixedCostMen", "AlignmentFixedCostWomen"));




            //Education
            coeffCovarianceEducationE1a = RegressionUtils.bootstrap(coeffCovarianceEducationE1a);
            coeffCovarianceEducationE1b = RegressionUtils.bootstrap(coeffCovarianceEducationE1b);
            coeffCovarianceEducationE2a = RegressionUtils.bootstrap(coeffCovarianceEducationE2a);

            //Health
            coeffCovarianceHealthH1 = RegressionUtils.bootstrap(coeffCovarianceHealthH1); //Note that this overrides the original coefficient map with bootstrapped values
            coeffCovarianceHealthH2 = RegressionUtils.bootstrap(coeffCovarianceHealthH2);

            //Non-labour income
            coeffCovarianceIncomeI1a = RegressionUtils.bootstrap(coeffCovarianceIncomeI1a);
            coeffCovarianceIncomeI1b = RegressionUtils.bootstrap(coeffCovarianceIncomeI1b);

            //Leave parental home
            coeffCovarianceLeaveHomeP1 = RegressionUtils.bootstrap(coeffCovarianceLeaveHomeP1);

            //Homeownership
            coeffCovarianceHomeownership = RegressionUtils.bootstrap(coeffCovarianceHomeownership);

            //Retirement
            coeffCovarianceRetirementR1a = RegressionUtils.bootstrap(coeffCovarianceRetirementR1a);
            coeffCovarianceRetirementR1b = RegressionUtils.bootstrap(coeffCovarianceRetirementR1b);

            //Partnership:
            coeffCovariancePartnershipU1 = RegressionUtils.bootstrap(coeffCovariancePartnershipU1);
            coeffCovariancePartnershipU2 = RegressionUtils.bootstrap(coeffCovariancePartnershipU2);

            //Fertility
            coeffCovarianceFertilityF1 = RegressionUtils.bootstrap(coeffCovarianceFertilityF1);

        }

        // Define regression objects



        //Health
        regHealthH1 = new GeneralisedOrderedRegression<>(RegressionType.GenOrderedLogit, Dhe.class, coeffCovarianceHealthH1);
        MultiKeyCoefficientMap coeffHealthH2Appended = appendCoefficientMaps(coeffCovarianceHealthH2, disabilityTimeAdjustment, "Year");
        regHealthH2 = new BinomialRegression(RegressionType.Probit, Indicator.class, coeffHealthH2Appended);

        //Education
        MultiKeyCoefficientMap coeffEducationE1aAppended = appendCoefficientMaps(coeffCovarianceEducationE1a, studentsTimeAdjustment, "Year");
        MultiKeyCoefficientMap coeffEducationE1bAppended = appendCoefficientMaps(coeffCovarianceEducationE1b, studentsTimeAdjustment, "Year");
        regEducationE1a = new BinomialRegression(RegressionType.Probit, Indicator.class, coeffEducationE1aAppended);
        regEducationE1b = new BinomialRegression(RegressionType.Probit, Indicator.class, coeffEducationE1bAppended);
        regEducationE2a = new GeneralisedOrderedRegression(RegressionType.GenOrderedLogit, EducationLevel.class, coeffCovarianceEducationE2a);

        //Partnership
        MultiKeyCoefficientMap coeffPartnershipU1Appended = appendCoefficientMaps(coeffCovariancePartnershipU1, partnershipTimeAdjustment, "Year");
        MultiKeyCoefficientMap coeffPartnershipU2Appended = appendCoefficientMaps(coeffCovariancePartnershipU2, partnershipTimeAdjustment, "Year", true);
        regPartnershipU1 = new BinomialRegression(RegressionType.Probit, Indicator.class, coeffPartnershipU1Appended);
        regPartnershipU2 = new BinomialRegression(RegressionType.Probit, ReversedIndicator.class, coeffPartnershipU2Appended);

        //Fertility
        MultiKeyCoefficientMap coeffFertilityF1Appended = appendCoefficientMaps(coeffCovarianceFertilityF1, fertilityTimeAdjustment, "Year");
        regFertilityF1 = new BinomialRegression(RegressionType.Probit, Indicator.class, coeffFertilityF1Appended);

        //Income
        regIncomeI1b = new LinearRegression(coeffCovarianceIncomeI1b);
        regIncomeI1a = new BinomialRegression(RegressionType.Logit, Indicator.class, coeffCovarianceIncomeI1a);

        //Homeownership
        regHomeownershipHO1 = new BinomialRegression(RegressionType.Probit, Indicator.class, coeffCovarianceHomeownership);

        //XXX: Note: the model used for selection in Heckman procedure is a Probit, but to obtain Inverse Mills Ratio, linear prediction needs to be obtained - so linear regression used here
        regEmploymentSelectionMaleE = new LinearRegression(coeffCovarianceEmploymentSelectionMalesE);
        regEmploymentSelectionMaleNE = new LinearRegression(coeffCovarianceEmploymentSelectionMalesNE);
        regEmploymentSelectionFemaleE = new LinearRegression(coeffCovarianceEmploymentSelectionFemalesE);
        regEmploymentSelectionFemaleNE = new LinearRegression(coeffCovarianceEmploymentSelectionFemalesNE);
        standardNormalDistribution = new NormalDistribution();

        //Wages
        regW1mb = new LinearRegression(coeffCovarianceW1mb);
        regW1ma = new LinearRegression(coeffCovarianceW1ma);
        regW1fb = new LinearRegression(coeffCovarianceW1fb);
        regW1fa = new LinearRegression(coeffCovarianceW1fa);

        //Labour Supply regressions from Zhechun's estimates on the EM input data
        regLabourSupplyUtilityMales = new LinearRegression(coeffLabourSupplyUtilityMales);
        regLabourSupplyUtilityFemales = new LinearRegression(coeffLabourSupplyUtilityFemales);
        regLabourSupplyUtilityMalesWithDependent = new LinearRegression(coeffLabourSupplyUtilityMalesWithDependent);
        regLabourSupplyUtilityFemalesWithDependent = new LinearRegression(coeffLabourSupplyUtilityFemalesWithDependent);
        regLabourSupplyUtilityACMales = new LinearRegression(coeffLabourSupplyUtilityACMales);
        regLabourSupplyUtilityACFemales = new LinearRegression(coeffLabourSupplyUtilityACFemales);
        regLabourSupplyUtilityCouples = new LinearRegression(coeffLabourSupplyUtilityCouples);

        //Leaving parental home
        regLeaveHomeP1 = new BinomialRegression(RegressionType.Probit, Indicator.class, coeffCovarianceLeaveHomeP1);

        //Retirement
        MultiKeyCoefficientMap coeffRetirementR1aAppended = appendCoefficientMaps(coeffCovarianceRetirementR1a, retirementTimeAdjustment, "Year");
        MultiKeyCoefficientMap coeffRetirementR1bAppended = appendCoefficientMaps(coeffCovarianceRetirementR1b, retirementTimeAdjustment, "Year");
        regRetirementR1a = new BinomialRegression(RegressionType.Probit, Indicator.class, coeffRetirementR1aAppended);
        regRetirementR1b = new BinomialRegression(RegressionType.Probit, Indicator.class, coeffRetirementR1bAppended);

        //Create the age and wage differential MultivariateNormalDistribution for partnership formation, using means and var-cov matrix loaded from Excel
        targetMeanAgeDifferential = ((Number) meanCovarianceParametricMatching.getValue("mean_dag_diff")).doubleValue();
        targetMeanWageDifferential = ((Number) meanCovarianceParametricMatching.getValue("mean_wage_diff")).doubleValue();
        double[] means = {targetMeanAgeDifferential, targetMeanWageDifferential};
        double[][] covariances = { {((Number) meanCovarianceParametricMatching.getValue("var_dag_diff")).doubleValue(), ((Number) meanCovarianceParametricMatching.getValue("cov_dag_wage_diff")).doubleValue()} , {((Number) meanCovarianceParametricMatching.getValue("cov_dag_wage_diff")).doubleValue(), ((Number) meanCovarianceParametricMatching.getValue("var_wage_diff")).doubleValue()}};
        wageAndAgeDifferentialMultivariateNormalDistribution = getMultivariateNormalDistribution(means, covariances);

        calculateFertilityRatesFromProjections();
        calculatePopulationGrowthRatiosFromProjections();

    }


    public static NormalDistribution getStandardNormalDistribution() {
        return standardNormalDistribution;
    }

    //For a given vector of means and a variance-covariance matrix, return a MultivariateNormalDistribution that can be sampled from using sample() method
    public static MultivariateNormalDistribution getMultivariateNormalDistribution(double[] means, double[][] covariances) {
        MultivariateNormalDistribution multivariateNormalDistribution = new MultivariateNormalDistribution(means, covariances);
        return multivariateNormalDistribution;
    }

    public static double getRMSEForRegression(String regressionName) {
        double valueRMSE = ((Number) coefficientMapRMSE.getValue(regressionName)).doubleValue();
        return valueRMSE;
    }

    private static void calculateFertilityRatesFromProjections() {

        fertilityRateByRegionYear = MultiKeyMap.multiKeyMap(new LinkedMap<>());
        fertilityRateByYear = new HashMap<>();
        for (int year = startYear; year <= endYear; year++) {

            double projectedNumFertileWomenAll = 0.0, numNewBornAll = 0.0;
            for (Region region : countryRegions) {

                double projectedNumFertileWomenByRegion = 0.0;
                for (int age = MIN_AGE_MATERNITY; age <= MAX_AGE_MATERNITY; age++) {
                    projectedNumFertileWomenByRegion += getPopulationProjections(Gender.Female, region, age, year);
                }

                double numNewBornByRegion = 0.;
                for (Gender gender: Gender.values()) {
                    numNewBornByRegion += getPopulationProjections(gender, region, 0, year);		//Number of people aged 0 in projected years
                }

                if (projectedNumFertileWomenByRegion <= 0.) {
                    throw new IllegalArgumentException("Projected Number of Females of Fertile Age is not positive!");
                }
                else {
                    projectedNumFertileWomenAll += projectedNumFertileWomenByRegion;
                    numNewBornAll += numNewBornByRegion;
                    fertilityRateByRegionYear.put(region, year, numNewBornByRegion / projectedNumFertileWomenByRegion);
                }
            }
            fertilityRateByYear.put(year, numNewBornAll / projectedNumFertileWomenAll);
        }
    }


    private static void calculatePopulationGrowthRatiosFromProjections() {

        populationGrowthRatiosByRegionYear = MultiKeyMap.multiKeyMap(new LinkedMap<>());
        for(int year = startYear+1; year <= endYear; year++) {		//Year is the latter year, i.e. growth ratio for year t is Pop(t)/Pop(t-1)
            for(Region region : countryRegions) {
                double numberOfPeopleInRegionThisYear = 0.;
                double numberOfPeopleInRegionPreviousYear = 0.;
                for(Gender gender: Gender.values()) {
                    for(int age = 0; age <= maxAge; age++) {
                        numberOfPeopleInRegionThisYear += getPopulationProjections(gender, region, age, year);
                        numberOfPeopleInRegionPreviousYear += getPopulationProjections(gender, region, age, year-1);
                    }
                }
                populationGrowthRatiosByRegionYear.put(region, year, numberOfPeopleInRegionThisYear / numberOfPeopleInRegionPreviousYear);
            }
        }
    }

    public static TreeMap<Integer, String> calculateEUROMODpolicySchedule(Country country) {
        //Load current values for policy description and initiation year
        String countryInputPath = "input" + File.separator + country.toString();
        MultiKeyCoefficientMap currentEUROMODpolicySchedule = ExcelAssistant.loadCoefficientMap(
                countryInputPath + File.separator + EUROMODpolicyScheduleFilename + ".xlsx",
                country.toString(),
                1
        );
        TreeMap<Integer, String> newEUROMODpolicySchedule = new TreeMap<>();

        for(Object o: currentEUROMODpolicySchedule.keySet()) {
            MultiKey k = (MultiKey)o;
            if(k.getKey(0) != null) {
                String name = k.getKey(0).toString();
                if(name != null &&
                        currentEUROMODpolicySchedule.getValue(name, EUROMODpolicyScheduleHeadingScenarioYearBegins) != null &&
                        currentEUROMODpolicySchedule.getValue(name, EUROMODpolicyScheduleHeadingScenarioSystemYear) != null) {
                    String policyStartYearString = currentEUROMODpolicySchedule.getValue(name, EUROMODpolicyScheduleHeadingScenarioYearBegins).toString();
                    String policySystemYearString = currentEUROMODpolicySchedule.getValue(name, EUROMODpolicyScheduleHeadingScenarioSystemYear).toString();
                    if(policyStartYearString != null && !policyStartYearString.isEmpty()) {
                        Integer policyStartYear = Integer.parseInt(policyStartYearString);
                        Integer policySystemYear = Integer.parseInt(policySystemYearString);
                        if(newEUROMODpolicySchedule.containsKey(policyStartYear)) {
                            throw new IllegalArgumentException("ERROR - there is more than one EUROMOD policy scenario with the same policy start year of " + policyStartYear + "!");
                        }
                        newEUROMODpolicySchedule.put(policyStartYear, name.split(".txt")[0]);

                        if (policySystemYearString == null) {
                            throw new IllegalArgumentException("ERROR - there is at least one EUROMOD policy scenario (" + name + ") with policy start year but no policy system year!");
                        } else {
                            Pair<String, Integer> policyNameSystemYearPair = new Pair<>(name.split(".txt")[0], policySystemYear);
                            EUROMODpolicyScheduleSystemYearMap.put(policyStartYear, policyNameSystemYearPair);
                        }
                    }
                }
            }
        }
        if(newEUROMODpolicySchedule.isEmpty())
            throw new IllegalArgumentException("ERROR - there are no EUROMOD policies with valid \'" + EUROMODpolicyScheduleHeadingScenarioYearBegins + "\' values specified in worksheet \'" + country + "\' of the " + EUROMODpolicyScheduleFilename + ".xlsx file");

        // validate EUROMOD input years
        boolean flagMissingBasePriceYear = true;
        for (int fromYear : EUROMODpolicyScheduleSystemYearMap.keySet()) {
            int systemYear = EUROMODpolicyScheduleSystemYearMap.get(fromYear).getValue();
            if (systemYear == BASE_PRICE_YEAR) {
                flagMissingBasePriceYear = false;
                break;
            }
        }
        if (flagMissingBasePriceYear)
            throw new RuntimeException("Must include a tax database generated for the base price year assumed for analysis (" + BASE_PRICE_YEAR + ")");

        return newEUROMODpolicySchedule;
    }

    public static String getEUROMODpolicyForThisYear(int year, Map<Integer, String> scenarioPlan) {
        String policyName;
        policyName = scenarioPlan.get(year);
        if(policyName == null) {	//Then, no EUROMOD policy begins in that year.  Instead, must apply the prevailing policy.
            for(Integer policyStartYear: scenarioPlan.keySet()) {	//Should iterate in order of increasing value of integer
                if(policyStartYear <= year) {		//In case the start year of the whole simulation is later than the first entry, assign but iterate again and check the following year.  Stop when the policyStartYear is greater than the year
                    policyName = scenarioPlan.get(policyStartYear);
                }
                else {
                    if(policyName == null) {		//Check for case when the earliest policyStartYear is later than the current year.  Need to apply the policy with the earliest policyStartYear anyway, just so there is a policy to apply!
                        policyName = scenarioPlan.get(policyStartYear);
                    }
                    break;		//Stop if policyStartYear is greater than year
                }
            }
        }
        return policyName;
    }

    public static void setCountryRegions(Country country) {
        countryRegions = new LinkedHashSet<Region>();
        for(Region region : Region.values()) {			//TODO: restrict this to only regions in the simulated country
            if(region.toString().startsWith(country.toString())) {			//Only assess the relevant regions for the country
                countryRegions.add(region);				//Create a set of only relevant regions that we can use below TODO: This should be done in the Parameters class, once and for all!
            }
        }
    }

    //Benefit Unit ID is different in different countries of EUROMOD. This method creates a map with name of the country and name of the benefit unit variable. It is used to create input database in the
    //SQLdataParser class.
    public static LinkedHashMap<Country, String> countryBenefitUnitNames = new LinkedHashMap<>();


    public static void setCountryBenefitUnitName() {

        //Benefit unit variable has different name in each country. This method loads the correct name of the benefit unit variable from Excel file system_bu_names.xlsx in the input folder.
        benefitUnitVariableNames = ExcelAssistant.loadCoefficientMap("input/system_bu_names.xlsx", "Names", 1);
    }

    //-----------------------------------------------------------------------------------------------------
    // Access methods
    //-----------------------------------------------------------------------------------------------------

    public static MultiKeyCoefficientMap getBenefitUnitVariableNames() { return benefitUnitVariableNames; }

    public static MultinomialRegression<Education> getRegEducationLevel() {
        return regEducationLevel;
    }

    public static GeneralisedOrderedRegression getRegHealthH1() { return regHealthH1; }
    public static BinomialRegression getRegHealthH2() { return regHealthH2; }

    public static BinomialRegression getRegReceiveCareS1a() { return regReceiveCareS1a; }
    public static LinearRegression getRegCareHoursS1b() { return regCareHoursS1b; }
    public static BinomialRegression getRegNeedCareS2a() { return regNeedCareS2a; }
    public static BinomialRegression getRegReceiveCareS2b() { return regReceiveCareS2b; }
    public static MultinomialRegression getRegSocialCareMarketS2c() { return regSocialCareMarketS2c; }
    public static BinomialRegression getRegReceiveCarePartnerS2d() { return regReceiveCarePartnerS2d; }
    public static MultinomialRegression getRegPartnerSupplementaryCareS2e() { return regPartnerSupplementaryCareS2e; }
    public static MultinomialRegression getRegNotPartnerInformalCareS2f() { return regNotPartnerInformalCareS2f; }
    public static LinearRegression getRegPartnerCareHoursS2g() { return regPartnerCareHoursS2g; }
    public static LinearRegression getRegDaughterCareHoursS2h() { return regDaughterCareHoursS2h; }
    public static LinearRegression getRegSonCareHoursS2i() { return regSonCareHoursS2i; }
    public static LinearRegression getRegOtherCareHoursS2j() { return regOtherCareHoursS2j; }
    public static LinearRegression getRegFormalCareHoursS2k() { return regFormalCareHoursS2k; }
    public static BinomialRegression getRegCarePartnerProvCareToOtherS3a() { return regCarePartnerProvCareToOtherS3a; }
    public static BinomialRegression getRegNoCarePartnerProvCareToOtherS3b() { return regNoCarePartnerProvCareToOtherS3b; }
    public static BinomialRegression getRegNoPartnerProvCareToOtherS3c() { return regNoPartnerProvCareToOtherS3c; }
    public static MultinomialRegression getRegInformalCareToS3d() { return regInformalCareToS3d; }
    public static LinearRegression getRegCareHoursProvS3e() { return regCareHoursProvS3e; }

    public static BinomialRegression getRegUnemploymentMaleGraduateU1a() { return regUnemploymentMaleGraduateU1a; }
    public static BinomialRegression getRegUnemploymentMaleNonGraduateU1b() { return regUnemploymentMaleNonGraduateU1b; }
    public static BinomialRegression getRegUnemploymentFemaleGraduateU1c() { return regUnemploymentFemaleGraduateU1c; }
    public static BinomialRegression getRegUnemploymentFemaleNonGraduateU1d() { return regUnemploymentFemaleNonGraduateU1d; }

    public static LinearRegression getRegHealthHM1Level() { return regHealthHM1Level; }
    public static LinearRegression getRegHealthHM2LevelMales() { return regHealthHM2LevelMales; }
    public static LinearRegression getRegHealthHM2LevelFemales() { return regHealthHM2LevelFemales; }
    public static BinomialRegression getRegHealthHM1Case() {return regHealthHM1Case;}
    public static BinomialRegression getRegHealthHM2CaseMales() {return regHealthHM2CaseMales;}
    public static BinomialRegression getRegHealthHM2CaseFemales() {return regHealthHM2CaseFemales;}

    public static BinomialRegression getRegEducationE1a() {return regEducationE1a;}
    public static BinomialRegression getRegEducationE1b() {return regEducationE1b;}
    public static GeneralisedOrderedRegression getRegEducationE2a() {return regEducationE2a;}

    public static BinomialRegression getRegPartnershipU1() {return regPartnershipU1;}
    public static BinomialRegression getRegPartnershipU2() {return regPartnershipU2;}


    public static BinomialRegression getRegFertilityF1() {return regFertilityF1;}

    public static LinearRegression getRegIncomeI1b() { return regIncomeI1b; }
    public static BinomialRegression getRegIncomeI1a() { return regIncomeI1a; }


    public static BinomialRegression getRegHomeownershipHO1() {return regHomeownershipHO1;}

    public static Set<Region> getCountryRegions() {
        return countryRegions;
    }

    public static MultiKeyMap getFertilityRateByRegionYear() {
        return fertilityRateByRegionYear;
    }

    public static double getFertilityRateByRegionYear(Region region, int year) {
        int yearHere = Math.max(fertilityProjectionsMinYear, Math.min(fertilityProjectionsMaxYear, year));
        //We calculate the rate per woman, but the standard to report (and what is used in the estimates) is per 1000 hence multiplication
         return 1000*((Number)fertilityRateByRegionYear.get(region, yearHere)).doubleValue();
        //return ((Number)fertilityRateByRegionYear.get(region, yearHere)).doubleValue();
    }

    public static double getUnemploymentRateByGenderEducationAgeYear(Gender gender, Education education, int age, int year) {
        double val;
        if (gender.equals(Gender.Male)) {
            if (education.equals(Education.High)) {
                int yearHere = Math.max(unemploymentRatesMaleGraduatesMinYear, Math.min(unemploymentRatesMaleGraduatesMaxYear, year));
                int ageHere = Math.min(unemploymentRatesMaleGraduatesMaxAge, age);
                val = ((Number)unemploymentRatesMaleGraduatesByAgeYear.getValue(ageHere, yearHere)).doubleValue();
            } else {
                int yearHere = Math.max(unemploymentRatesMaleNonGraduatesMinYear, Math.min(unemploymentRatesMaleNonGraduatesMaxYear, year));
                int ageHere = Math.min(unemploymentRatesMaleNonGraduatesMaxAge, age);
                val = ((Number) unemploymentRatesMaleNonGraduatesByAgeYear.getValue(ageHere, yearHere)).doubleValue();
            }
        } else {
            if (education.equals(Education.High)) {
                int yearHere = Math.max(unemploymentRatesFemaleGraduatesMinYear, Math.min(unemploymentRatesFemaleGraduatesMaxYear, year));
                int ageHere = Math.min(unemploymentRatesFemaleGraduatesMaxAge, age);
                val = ((Number)unemploymentRatesFemaleGraduatesByAgeYear.getValue(ageHere, yearHere)).doubleValue();
            } else {
                int yearHere = Math.max(unemploymentRatesFemaleNonGraduatesMinYear, Math.min(unemploymentRatesFemaleNonGraduatesMaxYear, year));
                int ageHere = Math.min(unemploymentRatesFemaleNonGraduatesMaxAge, age);
                val = ((Number)unemploymentRatesFemaleNonGraduatesByAgeYear.getValue(ageHere, yearHere)).doubleValue();
            }
        }
        return val;
    }

    public static LinearRegression getRegWagesMales() {
        return regWagesMales;
    }

    public static LinearRegression getRegWagesFemales() {
        return regWagesFemales;
    }

    public static String getTaxDonorInputFileName() {
        return taxDonorInputFileName;
    }

    public static void setTaxDonorInputFileName(String taxDonorInputFileName) {
        Parameters.taxDonorInputFileName = taxDonorInputFileName;
    }

    public static String getInputDirectoryInitialPopulations(Country country) {
        return (trainingFlag) ? INPUT_DIRECTORY + country + File.separator + "InitialPopulations" + File.separator + "training"  + File.separator  : INPUT_DIRECTORY + country + File.separator + "InitialPopulations" + File.separator;
    }
    public static String getPopulationInitialisationInputFileName() {
        return populationInitialisationInputFileName;
    }

    public static void setPopulationInitialisationInputFileName(String name) {
        populationInitialisationInputFileName = name;
    }


    public static LinearRegression getRegLabourSupplyUtilityCouples() {
        return regLabourSupplyUtilityCouples;
    }

    public static LinearRegression getRegLabourSupplyUtilityFemales() {
        return regLabourSupplyUtilityFemales;
    }

    public static LinearRegression getRegLabourSupplyUtilityMales() {
        return regLabourSupplyUtilityMales;
    }

    public static LinearRegression getRegLabourSupplyUtilityFemalesWithDependent() {
        return regLabourSupplyUtilityFemalesWithDependent;
    }

    public static LinearRegression getRegLabourSupplyUtilityMalesWithDependent() {
        return regLabourSupplyUtilityMalesWithDependent;
    }

    public static LinearRegression getRegLabourSupplyUtilityACMales() {
        return regLabourSupplyUtilityACMales;
    }

    public static LinearRegression getRegLabourSupplyUtilityACFemales() {
        return regLabourSupplyUtilityACFemales;
    }

    public static LinearRegression getRegEmploymentSelectionMale() {
        return regEmploymentSelectionMale;
    }

    public static LinearRegression getRegEmploymentSelectionFemale() {
        return regEmploymentSelectionFemale;
    }

    public static MultiKeyMap<Object, Double> getPopulationGrowthRatiosByRegionYear() {
        return populationGrowthRatiosByRegionYear;
    }


    public static DemandAdjustment getDemandAdjustment() {
        return demandAdjustment;
    }

    public static int getMaxStartYear() {
        return (trainingFlag) ? MAX_START_YEAR_TRAINING : MAX_START_YEAR;
    }

    public static int getMinStartYear() {
        return (trainingFlag) ? MIN_START_YEAR_TRAINING : MIN_START_YEAR;
    }

    public static String getEuromodOutputDirectory(Country country) {
        //return (trainingFlag) ? EUROMOD_TRAINING_DIRECTORY : EUROMOD_OUTPUT_DIRECTORY;
        return (trainingFlag) ? INPUT_DIRECTORY + country + File.separator + "EUROMODoutput" + File.separator + "training"  + File.separator  : INPUT_DIRECTORY + country + File.separator + "EUROMODoutput" + File.separator;
    }

    public static String getEUROMODpolicyForThisYear(int year) {
        return getEUROMODpolicyForThisYear(year, EUROMODpolicySchedule);
    }


    public static MultiKeyCoefficientMap getCoeffCovarianceHealthH1() { return coeffCovarianceHealthH1; }

    public static MultiKeyCoefficientMap getCoeffCovarianceW1mb() { return coeffCovarianceW1mb; }
    public static MultiKeyCoefficientMap getCoeffCovarianceW1ma() { return coeffCovarianceW1ma; }
    public static MultiKeyCoefficientMap getCoeffCovarianceW1fb() { return coeffCovarianceW1fb; }
    public static MultiKeyCoefficientMap getCoeffCovarianceW1fa() { return coeffCovarianceW1fa; }
    public static MultiKeyCoefficientMap getCoefficientMapRMSE() { return coefficientMapRMSE; }


    public static double getMortalityProbability(Gender gender, int age, int year) {

        double mortalityProbability;
        int yearEval = Math.min(mortalityProbabilityMaxYear, Math.max(mortalityProbabilityMinYear, year));
        int ageEval = Math.min(mortalityProbabilityMaxAge, age);
        Number prob = ((Number) mortalityProbabilityByGenderAgeYear.getValue(gender.toString(), ageEval, yearEval));
        if (prob==null) {
            throw new IllegalAccessError("ERROR - problem evaluating mortality probability for year: " + yearEval + ", age: " + ageEval + " and gender " + gender.toString());
        }
        mortalityProbability = prob.doubleValue() / 100000.0;

        return mortalityProbability;
    }

    public static double getPopulationProjections(Gender gender, Region region, int age, int year) {

        double populationProjection;
        int yearEval = Math.min(populationProjectionsMaxYear, Math.max(populationProjectionsMinYear, year));
        int ageEval = Math.min(populationProjectionsMaxAge, age);
        Number val = ((Number)populationProjections.getValue(gender.toString(), region.toString(), ageEval, yearEval));
        if (val==null)
            throw new IllegalAccessError("ERROR - problem evaluating population projection for year: " + yearEval + ", age: " + ageEval + ", region: " + region.toString() + " and gender: " + gender.toString());
        populationProjection = val.doubleValue();

        return populationProjection;
    }

    public static int getPopulationProjectionsMaxAge() { return populationProjectionsMaxAge; }

    public static int getPopulationProjectionsMaxYear() { return populationProjectionsMaxYear; }

    public static MultiKeyCoefficientMap getFertilityProjectionsByYear() { return fertilityProjectionsByYear; }
    public static double getFertilityProjectionsByYear(int year) {
        int yearHere = Math.min(fertilityProjectionsMaxYear, Math.max(fertilityProjectionsMinYear, year));
        return ((Number) fertilityProjectionsByYear.getValue("Value", yearHere)).doubleValue();
    }

    public synchronized static double[] getWageAndAgeDifferentialMultivariateNormalDistribution(long seed) {
        wageAndAgeDifferentialMultivariateNormalDistribution.reseedRandomGenerator(seed);
        return wageAndAgeDifferentialMultivariateNormalDistribution.sample();
    }

    public static BinomialRegression getRegLeaveHomeP1() {
        return regLeaveHomeP1;
    }

    public static BinomialRegression getRegRetirementR1a() {
        return regRetirementR1a;
    }

    public static BinomialRegression getRegRetirementR1b() {
        return regRetirementR1b;
    }

    public static BinomialRegression getRegChildcareC1a() { return regChildcareC1a; }

    public static LinearRegression getRegChildcareC1b() {
        return regChildcareC1b;
    }

    ///////////////////////////////////////////GETTERS FOR VALIDATION///////////////////////////////////////////////////
    public static MultiKeyCoefficientMap getValidationStudentsByAge() {
        return validationStudentsByAge;
    }

    public static MultiKeyCoefficientMap getValidationStudentsByRegion() {
        return validationStudentsByRegion;
    }

    public static MultiKeyCoefficientMap getValidationEducationLevel() {
        return validationEducationLevel;
    }

    public static MultiKeyCoefficientMap getValidationEducationLevelByAge() {
        return validationEducationLevelByAge;
    }

    public static MultiKeyCoefficientMap getValidationEducationLevelByRegion() {
        return validationEducationLevelByRegion;
    }

    public static MultiKeyCoefficientMap getValidationPartneredShareByRegion() {
        return validationPartneredShareByRegion;
    }

    public static MultiKeyCoefficientMap getValidationDisabledByAge() {
        return validationDisabledByAge;
    }

    public static MultiKeyCoefficientMap getValidationDisabledByGender() {
        return validationDisabledByGender;
    }

    public static MultiKeyCoefficientMap getValidationHealthByAge() {
        return validationHealthByAge;
    }

    public static MultiKeyCoefficientMap getValidationMentalHealthByAge() {
        return validationMentalHealthByAge;
    }

    public static MultiKeyCoefficientMap getValidationPsychDistressByAge() {
        return validationPsychDistressByAge;
    }

    public static MultiKeyCoefficientMap getValidationPsychDistressByAgeLow() {
        return validationPsychDistressByAgeLow;
    }

    public static MultiKeyCoefficientMap getValidationPsychDistressByAgeMed() {
        return validationPsychDistressByAgeMed;
    }

    public static MultiKeyCoefficientMap getValidationPsychDistressByAgeHigh() {
        return validationPsychDistressByAgeHigh;
    }

    public static MultiKeyCoefficientMap getValidationEmploymentByGender() {
        return validationEmploymentByGender;
    }

    public static MultiKeyCoefficientMap getValidationEmploymentByAgeAndGender() {
        return validationEmploymentByAgeAndGender;
    }

    public static MultiKeyCoefficientMap getValidationEmploymentByMaternity() {
        return validationEmploymentByMaternity;
    }

    public static MultiKeyCoefficientMap getValidationEmploymentByGenderAndRegion() {
        return validationEmploymentByGenderAndRegion;
    }

    public static MultiKeyCoefficientMap getValidationLabourSupplyByEducation() {
        return validationLabourSupplyByEducation;
    }

    public static MultiKeyCoefficientMap getValidationActivityStatus() {
        return validationActivityStatus;
    }

    public static MultiKeyCoefficientMap getValidationHomeownershipBenefitUnits() {
        return validationHomeownershipBenefitUnits;
    }

    public static MultiKeyCoefficientMap getValidationGrossEarningsByGenderAndEducation() {
        return validationGrossEarningsByGenderAndEducation;
    }

    public static MultiKeyCoefficientMap getValidationLhwByGenderAndEducation() {
        return validationLhwByGenderAndEducation;
    }

    public static MultiKeyCoefficientMap getHourlyWageByGenderAndEducation() {
        return hourlyWageByGenderAndEducation;
    }

    ///////////////////////////////////////////GETTERS FOR COVID-19 LABOUR TRANSITIONS//////////////////////////////////
    public static BinomialRegression getRegC19LS_SE() {
        return regC19LS_SE;
    }

    public static MultinomialRegression getRegC19LS_E1() {return regC19LS_E1;}
    public static MultinomialRegression getRegC19LS_FF1() {return regC19LS_FF1;}
    public static MultinomialRegression getRegC19LS_FX1() {return regC19LS_FX1;}
    public static MultinomialRegression getRegC19LS_S1() {return regC19LS_S1;}
    public static MultinomialRegression getRegC19LS_U1() {return regC19LS_U1;}

    public static LinearRegression getRegC19LS_E2a() {
        return regC19LS_E2a;
    }

    public static LinearRegression getRegC19LS_E2b() {
        return regC19LS_E2b;
    }

    public static LinearRegression getRegC19LS_F2a() {
        return regC19LS_F2a;
    }

    public static LinearRegression getRegC19LS_F2b() {
        return regC19LS_F2b;
    }

    public static LinearRegression getRegC19LS_F2c() {
        return regC19LS_F2c;
    }

    public static LinearRegression getRegC19LS_S2a() {
        return regC19LS_S2a;
    }

    public static LinearRegression getRegC19LS_U2a() {
        return regC19LS_U2a;
    }

    public static BinomialRegression getRegC19LS_S3() {
        return regC19LS_S3;
    }

    public static LinearRegression getRegW1mb() {
        return regW1mb;
    }

    public static LinearRegression getRegW1ma() {
        return regW1ma;
    }

    public static LinearRegression getRegW1fb() {
        return regW1fb;
    }

    public static LinearRegression getRegW1fa() {
        return regW1fa;
    }

    public static LinearRegression getRegEmploymentSelectionMaleE() {
        return regEmploymentSelectionMaleE;
    }

    public static LinearRegression getRegEmploymentSelectionMaleNE() {
        return regEmploymentSelectionMaleNE;
    }

    public static LinearRegression getRegEmploymentSelectionFemaleE() {
        return regEmploymentSelectionFemaleE;
    }

    public static LinearRegression getRegEmploymentSelectionFemaleNE() {
        return regEmploymentSelectionFemaleNE;
    }

    public static void loadTimeSeriesFactorMaps(Country country) {


        // load time varying indices
        upratingIndexMapRealGDP = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "time_series_factor.xlsx"), "gdp", 1);
        upratingIndexMapInflation = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "time_series_factor.xlsx"), "inflation", 1);
        upratingIndexMapRealWageGrowth = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "time_series_factor.xlsx"), "wage_growth", 1);
        partnershipTimeAdjustment = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_adjustment_factors.xlsx"), "cohabitation_adjustment", 1);
        retirementTimeAdjustment = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_adjustment_factors.xlsx"), "retirement_adjustment", 1);
        disabilityTimeAdjustment = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_adjustment_factors.xlsx"), "disability_adjustment", 1);
        studentsTimeAdjustment = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_adjustment_factors.xlsx"), "students_adjustment", 1);
        fertilityTimeAdjustment = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_adjustment_factors.xlsx"), "fertility_adjustment", 1);
        utilityTimeAdjustmentSingleMales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_adjustment_factors.xlsx"), "utility_adj_smales", 1);
        utilityTimeAdjustmentACMales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_adjustment_factors.xlsx"), "utility_adj_acmales", 1);
        utilityTimeAdjustmentACFemales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_adjustment_factors.xlsx"), "utility_adj_acfemales", 1);
        utilityTimeAdjustmentSingleFemales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_adjustment_factors.xlsx"), "utility_adj_sfemales", 1);
        utilityTimeAdjustmentCouples = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_adjustment_factors.xlsx"), "utility_adj_couples", 1);
        utilityTimeAdjustmentMaleWithDep = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_adjustment_factors.xlsx"), "utility_adj_malewdep", 1);
        utilityTimeAdjustmentFemaleWithDep = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_adjustment_factors.xlsx"), "utility_adj_femalewdep", 1);
        utilityTimeAdjustment = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_adjustment_factors.xlsx"), "utility_adj_all", 1);

        // Snapshot initial utility adjustment values from xlsx before alignment can overwrite them.
        // Activity alignment uses these as cold-start values each year to avoid whiplash oscillation.
        snapshotInitialUtilityAdjustments();

        // rebase indices to base year defined by BASE_PRICE_YEAR
        rebaseIndexMap(TimeSeriesVariable.GDP);
        rebaseIndexMap(TimeSeriesVariable.Inflation);
        rebaseIndexMap(TimeSeriesVariable.WageGrowth);

        // load year-specific fiscal policy parameters
        socialCarePolicy = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "social_care_parameters.xlsx"), "social care", 1);
        partneredShare = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_targets_partnered_share.xlsx"), "partnered", 1);
        retiredShare = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_targets_retirement.xlsx"), "retirement", 1);
        disabledShare = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_targets_disability.xlsx"), "disability", 1);
        studentShare = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_targets_inSchool.xlsx"), "students", 1);

        //Employment targets
        employedShareSingleMales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_targets_employment.xlsx"), "Single_male", 1);
        employedShareACMales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_targets_employment.xlsx"), "SingleAC_Males", 1);
        employedShareSingleFemales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_targets_employment.xlsx"), "Single_female", 1);
        employedShareACFemales = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_targets_employment.xlsx"), "SingleAC_Females", 1);
        employedShareCouples = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_targets_employment.xlsx"), "Couples", 1);
        employedShareMaleWithDep = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_targets_employment.xlsx"), "SingleDep_Males", 1);
        employedShareFemaleWithDep = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "alignment_targets_employment.xlsx"), "SingleDep_Females", 1);
    }

    public static void instantiateAlignmentMaps() {
        partnershipAlignAdjustment = new HashMap<>();
        retirementAlignAdjustment = new HashMap<>();
        disabilityAlignAdjustment = new HashMap<>();
        studentsAlignAdjustment = new HashMap<>();
        fertilityAlignAdjustment = new HashMap<>();
        for (int yy=startYear; yy<=endYear; yy++) {
            partnershipAlignAdjustment.put(yy,0.0);
            fertilityAlignAdjustment.put(yy,0.0);
            retirementAlignAdjustment.put(yy,0.0);
            disabilityAlignAdjustment.put(yy,0.0);
            studentsAlignAdjustment.put(yy,0.0);
        }
    }

    public static void loadTimeSeriesFactorForTaxDonor(Country country) {

        TimeSeriesVariable index = getTimeSeriesVariable(UpratingCase.TaxDonor);
        switch (index) {
            case GDP -> {
                upratingIndexMapRealGDP = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "time_series_factor.xlsx"), "gdp", 1);
                rebaseIndexMap(TimeSeriesVariable.GDP);
            }
            case WageGrowth -> {
                upratingIndexMapRealWageGrowth = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "time_series_factor.xlsx"), "wage_growth", 1);

                rebaseIndexMap(TimeSeriesVariable.WageGrowth);
            }
            case Inflation -> {
                upratingIndexMapInflation = ExcelAssistant.loadCoefficientMap(resolveCountryFile(country, "time_series_factor.xlsx"), "inflation", 1);
                rebaseIndexMap(TimeSeriesVariable.Inflation);
            }
        }
    }

    private static void rebaseIndexMap(TimeSeriesVariable indexType) {
        rebaseIndexMap(indexType, BASE_PRICE_YEAR, true);
    }

    private static void rebaseIndexMap(TimeSeriesVariable timeSeriesVariable, int baseYear, boolean ratioAdjust) {

        MultiKeyCoefficientMap map = getTimeSeriesValueMap(timeSeriesVariable);
        double valueBase = getTimeSeriesValue(baseYear, timeSeriesVariable);
        // Captured here because the map still holds only explicit (in-sample) keys; once
        // extendValueTimeSeries extrapolates forward this maximum would be polluted.
        boolean captureWageGrowthLastYear = (timeSeriesVariable == TimeSeriesVariable.WageGrowth);
        int wageGrowthMaxYear = Integer.MIN_VALUE;
        for (Object key: map.keySet()) {

            if (captureWageGrowthLastYear) {
                int yearHere = key.hashCode();
                if (yearHere >= 1900 && yearHere <= 2500 && yearHere > wageGrowthMaxYear)
                    wageGrowthMaxYear = yearHere;
            }
            double valueHere = ((Number) map.getValue(key)).doubleValue();
            if (ratioAdjust) {
                map.replace(key, valueHere/valueBase);
            } else {
                map.replace(key, valueHere - valueBase);
            }
        }
        if (captureWageGrowthLastYear && wageGrowthMaxYear != Integer.MIN_VALUE)
            wageGrowthLastInSampleYear = wageGrowthMaxYear;
    }

    private static MultiKeyCoefficientMap getTimeSeriesValueMap(TimeSeriesVariable timeSeriesVariable) {

        MultiKeyCoefficientMap map = null;
        switch (timeSeriesVariable) {
            case GDP -> {
                map = upratingIndexMapRealGDP;
            }
            case Inflation -> {
                map = upratingIndexMapInflation;
            }
            case WageGrowth -> {
                map = upratingIndexMapRealWageGrowth;
            }
            case CarerWageRate -> {
                map = wageRateFormalSocialCare;
            }
            case CareProvisionAdjustment -> {
                map = socialCareProvisionTimeAdjustment;
            }
            case PartnershipAdjustment -> {
                map = partnershipTimeAdjustment;
            }
            case FertilityAdjustment -> {
                map = fertilityTimeAdjustment;
            }
            case UtilityAdjustment -> {
                map = utilityTimeAdjustment;
            }
            case UtilityAdjustmentSingleMales -> {
                map = utilityTimeAdjustmentSingleMales;
            }
            case UtilityAdjustmentSingleFemales -> {
                map = utilityTimeAdjustmentSingleFemales;
            }
            case UtilityAdjustmentCouples -> {
                map = utilityTimeAdjustmentCouples;
            }
            case UtilityAdjustmentACMales ->
                map = utilityTimeAdjustmentACMales;
            case UtilityAdjustmentACFemales ->
                map = utilityTimeAdjustmentACFemales;
            case UtilityAdjustmentMaleWithDep ->
                map = utilityTimeAdjustmentMaleWithDep;
            case UtilityAdjustmentFemaleWithDep ->
                map = utilityTimeAdjustmentFemaleWithDep;
            case RetirementAdjustment -> {
                map = retirementTimeAdjustment;
            }
            case DisabilityAdjustment -> {
                map = disabilityTimeAdjustment;
            }
            case InSchoolAdjustment -> {
                map = studentsTimeAdjustment;
            }
            case HighEducationRate -> {
                map = projectionsHighEdu;
            }
            case LowEducationRate -> {
                map = projectionsLowEdu;
            }
            case FixedRetirementAge -> {
                map = fixedRetireAge;
            }
        }
        return map;
    }

    private static MultiKeyCoefficientMap getTargetShareMap(TargetShares targetShareType) {

        MultiKeyCoefficientMap map = null;
        switch (targetShareType) {
            case Partnership -> {
                map = partneredShare;
            }
            case Retirement -> {
                map = retiredShare;
            }
            case Disability -> {
                map = disabledShare;
            }
            case Students -> {
                map = studentShare;
            }
            case EmploymentSingleMales -> {
                map = employedShareSingleMales;
            }
            case EmploymentSingleFemales -> {
                map = employedShareSingleFemales;
            }
            case EmploymentCouples -> {
                map = employedShareCouples;
            }
            case EmploymentMaleAdultChildren ->
                map = employedShareACMales;
            case EmploymentFemaleAdultChildren ->
                map = employedShareACFemales;
            case EmploymentMaleWithDependent ->
                map = employedShareMaleWithDep;
            case EmploymentFemaleWithDependent ->
                map = employedShareFemaleWithDep;
            case Employment -> {
                map = employedShare;
            }
        }

        return map;
    }

    public static Double getTimeSeriesIndex(int year, UpratingCase upratingCase) {

        TimeSeriesVariable timeSeriesVariable = getTimeSeriesVariable(upratingCase);
        return getTimeSeriesValue(year, timeSeriesVariable);
    }

    private static TimeSeriesVariable getTimeSeriesVariable(UpratingCase upratingCase) {

        TimeSeriesVariable timeSeriesVariable = null;
        switch (upratingCase) {
            case Capital, ModelInitialise, Pension -> {
                timeSeriesVariable = TimeSeriesVariable.GDP;
            }
            case Earnings -> {
                timeSeriesVariable = TimeSeriesVariable.WageGrowth;
            }
            case TaxDonor -> {
                timeSeriesVariable = TimeSeriesVariable.Inflation;
            }
        }
        return timeSeriesVariable;
    }

    public static double getTimeSeriesValue(int year, TimeSeriesVariable timeSeriesVariable) {
        return getTimeSeriesValue(year, null, null, timeSeriesVariable);
    }

    /**
     * Returns the initial utility adjustment value loaded from alignment_adjustment_factors.xlsx,
     * ignoring any overwrites made by alignment during the simulation.
     * Falls back to 0.0 if no initial value was recorded for the given year/variable.
     */
    public static double getInitialUtilityAdjustment(int year, TimeSeriesVariable timeSeriesVariable) {
        java.util.Map<Integer, Double> yearMap = initialUtilityAdjustments.get(timeSeriesVariable);
        if (yearMap == null) return 0.0;
        Double val = yearMap.get(year);
        return (val != null) ? val : 0.0;
    }

    /**
     * Snapshots the initial utility adjustment values from the just-loaded xlsx maps
     * into {@link #initialUtilityAdjustments} so they are preserved even after
     * alignment overwrites the live maps via putTimeSeriesValue.
     */
    private static void snapshotInitialUtilityAdjustments() {
        TimeSeriesVariable[] utilityVars = {
                TimeSeriesVariable.UtilityAdjustmentSingleMales,
                TimeSeriesVariable.UtilityAdjustmentSingleFemales,
                TimeSeriesVariable.UtilityAdjustmentCouples,
                TimeSeriesVariable.UtilityAdjustmentACMales,
                TimeSeriesVariable.UtilityAdjustmentACFemales,
                TimeSeriesVariable.UtilityAdjustmentMaleWithDep,
                TimeSeriesVariable.UtilityAdjustmentFemaleWithDep,
        };
        for (TimeSeriesVariable tsv : utilityVars) {
            java.util.Map<Integer, Double> yearMap = new java.util.HashMap<>();
            MultiKeyCoefficientMap liveMap = getTimeSeriesValueMap(tsv);
            if (liveMap != null) {
                for (int year = startYear; year <= endYear; year++) {
                    Object val = liveMap.getValue(year);
                    if (val != null) {
                        yearMap.put(year, ((Number) val).doubleValue());
                    }
                }
            }
            initialUtilityAdjustments.put(tsv, yearMap);
        }
    }

    public static double getTimeSeriesValue(int year, String stringKey1, TimeSeriesVariable timeSeriesVariable) {
        return getTimeSeriesValue(year, stringKey1, null, timeSeriesVariable);
    }

    public static double getTimeSeriesValue(int year, String stringKey1, String stringKey2, TimeSeriesVariable timeSeriesVariable) {

        MultiKeyCoefficientMap valueMap = getTimeSeriesValueMap(timeSeriesVariable);
        Object val = getObjectFromTimeSeriesValueMap(year, stringKey1, stringKey2, valueMap);
        if (val == null)
            val = extendValueTimeSeries(year, stringKey1, stringKey2, valueMap);
        return ((Number) val).doubleValue();
    }

    private static Object getObjectFromTimeSeriesValueMap(int year, String stringKey1, String stringKey2, MultiKeyCoefficientMap map) {
        if (stringKey1==null)
            return map.getValue(year);
        else if (stringKey2==null)
            return map.getValue(year, stringKey1);
        else
            return map.getValue(stringKey1, stringKey2, year);
    }

    /*
    public static double getValuePreferPrev(int year, TimeSeriesVariable variableType) {
    MultiKeyCoefficientMap map = getTimeSeriesValueMap(variableType);

    Object prev = getObjectFromTimeSeriesValueMap(year - 1, null, null, map);
    if (prev != null) return ((Number) prev).doubleValue();

    Object cur = getObjectFromTimeSeriesValueMap(year, null, null, map);
    if (cur != null) return ((Number) cur).doubleValue();

    return 0.0; // or whatever default makes sense
}

public static void putPrevOrNewTarget(int year, Object newTarget, TimeSeriesVariable variableType) {
    MultiKeyCoefficientMap map = getTimeSeriesValueMap(variableType);

    // If last year's value exists, use it; otherwise use the new target
    Object prev = getObjectFromTimeSeriesValueMap(year - 1, null, null, map);
    Object valueToWrite = (prev != null) ? prev : newTarget;

    Object existing = getObjectFromTimeSeriesValueMap(year, null, null, map);
    if (existing == null) {
        map.putValue(year, valueToWrite);
    } else if (!existing.equals(valueToWrite)) {
        map.replaceValue(year, valueToWrite);
    }
}
     */

    public static void putTimeSeriesValue(int year, Object valPut, TimeSeriesVariable variableType) {
        putTimeSeriesValue(year, null, null, valPut, variableType);
    }

    public static void putTimeSeriesValue(int year, String stringKey1, Object valPut, TimeSeriesVariable variableType) {
        putTimeSeriesValue(year, stringKey1, null, valPut, variableType);
    }

    public static void putTimeSeriesValue(int year, String stringKey1, String stringKey2, Object valPut, TimeSeriesVariable variableType) {

        MultiKeyCoefficientMap valueMap = getTimeSeriesValueMap(variableType);
        putTimeSeriesValue(year, stringKey1, stringKey2, valPut, valueMap);
    }

    public static void putTimeSeriesValue(int year, String stringKey1, String stringKey2, Object valPut, MultiKeyCoefficientMap valueMap) {

        Object val = getObjectFromTimeSeriesValueMap(year, stringKey1, stringKey2, valueMap);
        if (val == null) {
            if (stringKey1==null)
                valueMap.putValue(year, valPut);
            else if (stringKey2==null)
                valueMap.putValue(year, stringKey1, valPut);
            else
                valueMap.putValue(stringKey1, stringKey2, year, valPut);
        } else {
            if (stringKey1==null)
                valueMap.replaceValue(year, valPut);
            else if (stringKey2==null)
                valueMap.replaceValue(year, stringKey1, valPut);
            else
                valueMap.replaceValue(stringKey1, stringKey2, year, valPut);
        }
    }

    private synchronized static Object extendValueTimeSeries(int year, String stringKey1, String stringKey2, MultiKeyCoefficientMap mapToExtend) {

        Object valObj = getObjectFromTimeSeriesValueMap(year, stringKey1, stringKey2, mapToExtend);
        if (valObj == null) {
            // assume that series is capped at end by assumed geometric growth rate

            int mapYear = year;
            while (valObj == null) {

                if ( year < getMinStartYear() ) {
                    // year must be below lower bound of series - search up
                    mapYear++;
                } else {
                    // year must be above upper bound of series - search down
                    mapYear--;
                }
                valObj = getObjectFromTimeSeriesValueMap(mapYear, stringKey1, stringKey2, mapToExtend);
            }
            double val = ((Number)valObj).doubleValue();
            double growthFactor = 0.0;
            if (year > mapYear) {
                // extend series forward through time

                if (Math.abs(val)>1.0E-9) {
                    // assume constant exponential growth rate

                    Object valObj1 = getObjectFromTimeSeriesValueMap(mapYear-1, stringKey1, stringKey2, mapToExtend);
                    double val1 = ((Number)valObj1).doubleValue();
                    growthFactor = val / val1;
                }
                for (int yy = mapYear + 1; yy <= year; yy++) {
                    val *= growthFactor;
                    putTimeSeriesValue(yy, stringKey1, stringKey2, val, mapToExtend);
                }
            } else {
                // extend series backward through time

                if (Math.abs(val)>1.0E-9) {
                    // assume constant exponential growth rate

                    Object valObj1 = getObjectFromTimeSeriesValueMap(mapYear+1, stringKey1, stringKey2, mapToExtend);
                    double val1 = ((Number)valObj1).doubleValue();
                    growthFactor = val / val1;
                }
                for (int yy = mapYear - 1; yy >= year; yy--) {
                    val *= growthFactor;
                    putTimeSeriesValue(yy, stringKey1, stringKey2, val, mapToExtend);
                }
            }
        }
        return getObjectFromTimeSeriesValueMap(year, stringKey1, stringKey2, mapToExtend);
    }

    private static MultiKeyCoefficientMap getTimeSeriesRateMap(TimeVaryingRate rateType) {

        MultiKeyCoefficientMap map = null;
        switch (rateType) {
            case RealSavingReturns -> {
                map = priceMapRealSavingReturns;
            }
            case RealDebtCostLow -> {
                map = priceMapRealDebtCostLow;
            }
            case RealDebtCostHigh -> {
                map = priceMapRealDebtCostHigh;
            }
        }

        return map;
    }

    private static Double getTimeSeriesRateParameter(TimeVaryingRate rateType) {

        switch (rateType) {
            case RealSavingReturns -> {
                return averageSavingReturns;
            }
            case RealDebtCostLow -> {
                return averageDebtCostLow;
            }
            case RealDebtCostHigh -> {
                return averageDebtCostHigh;
            }
        }
        throw new RuntimeException("failed to find requested time varying rate");
    }

    private static void setTimeSeriesRateParameter(TimeVaryingRate rateType, double val) {

        switch (rateType) {
            case RealSavingReturns -> {
                averageSavingReturns = val;
                return;
            }
            case RealDebtCostLow -> {
                averageDebtCostLow = val;
                return;
            }
            case RealDebtCostHigh -> {
                averageDebtCostHigh = val;
                return;
            }
        }
        throw new RuntimeException("failed to find requested time varying rate");
    }

    public static double getTimeSeriesRate(int year, TimeVaryingRate rateType) {

        if (flagDefaultToTimeSeriesAverages) {
            return getSampleAverageRate(rateType);
        } else {
            MultiKeyCoefficientMap rateMap = getTimeSeriesRateMap(rateType);
            Object val = rateMap.getValue(year);
            if (val == null)
                val = extendRateTimeSeries(year, rateMap);
            return ((Number) val).doubleValue();
        }
    }

    private synchronized static Object extendRateTimeSeries(int year, MultiKeyCoefficientMap mapToExtend) {

        Object val = mapToExtend.getValue(year);
        if (val == null) {
            // assume that series is capped at end by rates to assume for out-of sample projections

            Integer yearMin = null, yearMax = null;
            for (Object key: mapToExtend.keySet()) {
                // loop over all existing keys to search for min and max

                int yearHere = key.hashCode();
                if (yearHere>0) {

                    if (yearHere<1900 || yearHere>2500)
                        throw new RuntimeException("problem extending time series");
                    if (yearMin == null) {
                        yearMin = yearHere;
                        yearMax = yearHere;
                    }
                    if (yearHere < yearMin) yearMin = yearHere;
                    if (yearHere > yearMax) yearMax = yearHere;
                }
            }
            if (year > yearMax) {
                // extend series forward through time

                double outOfSampleRate = ((Number) mapToExtend.getValue(yearMax)).doubleValue();
                for (int yy = yearMax + 1; yy <= year; yy++) {
                    mapToExtend.putValue(yy, outOfSampleRate);
                }
                val = outOfSampleRate;
            }
            if (year < yearMin) {
                // extend series backward through time

                double outOfSampleRate = ((Number) mapToExtend.getValue(yearMin)).doubleValue();
                for (int yy = yearMin - 1; yy >= year; yy--) {
                    mapToExtend.putValue(yy, outOfSampleRate);
                }
                val = outOfSampleRate;
            }
        }
        return val;
    }

    public static double getSampleAverageRate(TimeVaryingRate rateType) {

        Double val = getTimeSeriesRateParameter(rateType);
        if (val==null) {

            val = 0.0;
            double nn = 0.0;
            MultiKeyCoefficientMap rateMapToUse = getTimeSeriesRateMap(rateType);
            for (Object key: rateMapToUse.keySet()) {
                // loop over all existing keys to obtain sample average

                nn ++;
                val += ((Number) rateMapToUse.getValue(key)).doubleValue();
            }
            val /= nn;
            setTimeSeriesRateParameter(rateType, val);
        }
        return val;
    }

    public static void setEnableIntertemporalOptimisations(boolean val) {
        enableIntertemporalOptimisations = val;
    }
    public static void setProjectLiquidWealth() {
        setProjectLiquidWealth(enableIntertemporalOptimisations);
    }
    public static void setProjectLiquidWealth(boolean val) {
        projectLiquidWealth = val;
    }

    public static double getTargetShare(int year, TargetShares targetShareType) {

        MultiKeyCoefficientMap map = getTargetShareMap(targetShareType);
        Object val = map.getValue(year);
        if (val == null)
            val = extendRateTimeSeries(year, map);
        return ((Number) val).doubleValue();
    }

    public static double getSocialCarePolicyValue(int year, String param) {

        Object val = socialCarePolicy.getRowColumnValue(year, param);
        if (val == null)
            val = extendSocialCarePolicy(year, param);
        return ((Number) val).doubleValue();
    }

    public synchronized static Object extendSocialCarePolicy(int year, String param) {

        Object val = socialCarePolicy.getRowColumnValue(year, param);
        if (val==null) {
            // assume that series is capped at end by assumed geometric growth rate

            int minYear = 9999, maxYear=0;
            for (Object key : socialCarePolicy.keySet()) {
                if (key.hashCode()>0) {
                    if (key.hashCode()<1900 || key.hashCode()>2500)
                        throw new RuntimeException("problem extending time series for social policy parameters");
                    if (key.hashCode() < minYear)
                        minYear = key.hashCode();
                    if (key.hashCode() > maxYear)
                        maxYear = key.hashCode();
                }
            }
            if (year < minYear) {
                // extend backward through time

                Object[] values0 = (Object[]) socialCarePolicy.getValue(minYear+1);
                Object[] values1 = (Object[]) socialCarePolicy.getValue(minYear);
                for( int yy=minYear-1; yy>=year; yy--) {
                    Object[] values2 = new Object[values1.length];
                    for (int ii=0; ii<values1.length; ii++) {
                        double val0 = ((Number) values0[ii]).doubleValue();
                        double val1 = ((Number) values1[ii]).doubleValue();
                        values2[ii] = val1 * val1 / val0;
                    }
                    socialCarePolicy.putValue(yy, values2);
                    values0 = values1;
                    values1 = values2;
                }
            }
            else {
                // extend forward through time

                Object[] values0 = (Object[]) socialCarePolicy.getValue(maxYear-1);
                Object[] values1 = (Object[]) socialCarePolicy.getValue(maxYear);
                for( int yy=maxYear+1; yy<=year; yy++) {
                    Object[] values2 = new Object[values1.length];
                    for (int ii=0; ii<values1.length; ii++) {
                        double val0 = ((Number) values0[ii]).doubleValue();
                        double val1 = ((Number) values1[ii]).doubleValue();
                        values2[ii] = val1 * val1 / val0;
                    }
                    socialCarePolicy.putValue(yy, values2);
                    values0 = values1;
                    values1 = values2;
                }
            }
            val = socialCarePolicy.getRowColumnValue(year, param);
        }
        return val;
    }

    public static Map<MatchFeature, Map<Integer, Integer>> getTaxdbCounter() {
        return taxdbCounter;
    }
    public static void setTaxdbCounter(Map<MatchFeature, Map<Integer, Integer>> map) {
        taxdbCounter = map;
    }

    /**
     * Triple: system year, matching regime, regime index
     * @return
     */
    public static Map<Triple<Integer,Integer,Integer>,List<Integer>> getTaxdbReferences() {
        return taxdbReferences;
    }
    public static void setTaxdbReferences(Map<Triple<Integer,Integer,Integer>,List<Integer>> map) {
        taxdbReferences = map;
    }
    public static List<DonorTaxUnit> getDonorPool() {
        return donorPool;
    }
    public static void setDonorPool(List<DonorTaxUnit> list) {
        donorPool = list;
    }
    public static double asinh(double xx) {
        return Math.log(xx + Math.sqrt(xx * xx + 1.0));
    }
    public static void setMdDualIncome(MahalanobisDistance md) {
        mdDualIncome = md;
    }
    public static MahalanobisDistance getMdDualIncome() {
        return mdDualIncome;
    }
    public static void setMdChildcare(MahalanobisDistance md) {
        mdChildcare = md;
    }
    public static MahalanobisDistance getMdChildcare() {
        return mdChildcare;
    }
    public static void setMdDualIncomeChildcare(MahalanobisDistance md) {
        mdDualIncomeChildcare = md;
    }
    public static MahalanobisDistance getMdDualIncomeChildcare() {
        return mdDualIncomeChildcare;
    }
    public static double normaliseWeeklyIncome(int priceYear, double weeklyFinancial) {
        return normaliseMonthlyIncome(priceYear, weeklyFinancial * WEEKS_PER_MONTH);
    }
    public static double normaliseMonthlyIncome(int priceYear, double monthlyFinancial) {
        double infAdj = 1.0;
        if (priceYear != BASE_PRICE_YEAR)
            infAdj = getTimeSeriesValue(BASE_PRICE_YEAR, TimeSeriesVariable.Inflation) / getTimeSeriesValue(priceYear, TimeSeriesVariable.Inflation);
        return Parameters.asinh(monthlyFinancial * infAdj);
    }
    public static void setTrainingFlag(boolean flag) {
        trainingFlag = flag;
    }

    private static void setMapBounds(MapBounds map, String countryString) {

        String rgn = switch (countryString) {
            case "EL" -> countryString + "3";
            case "HU" -> countryString + "C";
            case "IT" -> countryString + "C";
            case "PL" -> countryString + "2";
            default -> null;
        };

        boolean searchBack = true;
        boolean searchForward = true;
        boolean searchAge;
        searchAge = !map.equals(MapBounds.Fertility);
        int ii = 1;
        int maxYear=0, minYear=0, maxAge=0;
        while (searchBack || searchForward || searchAge) {

            if (searchForward) {

                Number val = switch (map) {
                    case UnemploymentMaleGraduates -> (Number) unemploymentRatesMaleGraduatesByAgeYear.getValue(25, MIN_START_YEAR + ii);
                    case UnemploymentMaleNonGraduates -> (Number) unemploymentRatesMaleNonGraduatesByAgeYear.getValue(25, MIN_START_YEAR + ii);
                    case UnemploymentFemaleGraduates -> (Number) unemploymentRatesFemaleGraduatesByAgeYear.getValue(25, MIN_START_YEAR + ii);
                    case UnemploymentFemaleNonGraduates -> (Number) unemploymentRatesFemaleNonGraduatesByAgeYear.getValue(25, MIN_START_YEAR + ii);
                    case Fertility -> (Number)  fertilityProjectionsByYear.getValue("Value", MIN_START_YEAR + ii);
                    case Mortality -> (Number) mortalityProbabilityByGenderAgeYear.getValue("Female", 25, MIN_START_YEAR + ii);
                    default -> (Number) populationProjections.getValue("Female", rgn, 25, MIN_START_YEAR + ii);
                };
                if (val==null) {
                    maxYear = MIN_START_YEAR + ii - 1;
                    searchForward = false;
                }
            }
            if (searchBack) {

                Number val = switch (map) {
                    case UnemploymentMaleGraduates -> (Number) unemploymentRatesMaleGraduatesByAgeYear.getValue(25, MIN_START_YEAR - ii);
                    case UnemploymentMaleNonGraduates -> (Number) unemploymentRatesMaleNonGraduatesByAgeYear.getValue(25, MIN_START_YEAR - ii);
                    case UnemploymentFemaleGraduates -> (Number) unemploymentRatesFemaleGraduatesByAgeYear.getValue(25, MIN_START_YEAR - ii);
                    case UnemploymentFemaleNonGraduates -> (Number) unemploymentRatesFemaleNonGraduatesByAgeYear.getValue(25, MIN_START_YEAR - ii);
                    case Fertility -> (Number) fertilityProjectionsByYear.getValue("Value", MIN_START_YEAR - ii);
                    case Mortality -> (Number) mortalityProbabilityByGenderAgeYear.getValue("Female", 25, MIN_START_YEAR - ii);
                    default -> (Number) populationProjections.getValue("Female", rgn, 25, MIN_START_YEAR - ii);
                };
                if (val==null) {
                    minYear = MIN_START_YEAR - ii + 1;
                    searchBack = false;
                }
            }
            if (searchAge) {

                Number val = switch (map) {
                    case UnemploymentMaleGraduates -> (Number) unemploymentRatesMaleGraduatesByAgeYear.getValue(55+ii, MIN_START_YEAR);
                    case UnemploymentMaleNonGraduates -> (Number) unemploymentRatesMaleNonGraduatesByAgeYear.getValue(55+ii, MIN_START_YEAR);
                    case UnemploymentFemaleGraduates -> (Number) unemploymentRatesFemaleGraduatesByAgeYear.getValue(55+ii, MIN_START_YEAR);
                    case UnemploymentFemaleNonGraduates -> (Number) unemploymentRatesFemaleNonGraduatesByAgeYear.getValue(55+ii, MIN_START_YEAR);
                    case Mortality -> (Number) mortalityProbabilityByGenderAgeYear.getValue("Female", 55+ii, MIN_START_YEAR);
                    default -> (Number) populationProjections.getValue("Female", rgn, 55+ii, MIN_START_YEAR);
                };
                if (val==null) {
                    maxAge = 55 + ii - 1;
                    searchAge = false;
                }
            }
            ii++;
        }
        switch (map) {
            case UnemploymentMaleGraduates -> {
                unemploymentRatesMaleGraduatesMaxYear = maxYear;
                unemploymentRatesMaleGraduatesMinYear = minYear;
                unemploymentRatesMaleGraduatesMaxAge = maxAge;
            }
            case UnemploymentMaleNonGraduates -> {
                unemploymentRatesMaleNonGraduatesMaxYear = maxYear;
                unemploymentRatesMaleNonGraduatesMinYear = minYear;
                unemploymentRatesMaleNonGraduatesMaxAge = maxAge;
            }
            case UnemploymentFemaleGraduates -> {
                unemploymentRatesFemaleGraduatesMaxYear = maxYear;
                unemploymentRatesFemaleGraduatesMinYear = minYear;
                unemploymentRatesFemaleGraduatesMaxAge = maxAge;
            }
            case UnemploymentFemaleNonGraduates -> {
                unemploymentRatesFemaleNonGraduatesMaxYear = maxYear;
                unemploymentRatesFemaleNonGraduatesMinYear = minYear;
                unemploymentRatesFemaleNonGraduatesMaxAge = maxAge;
            }
            case Fertility -> {
                fertilityProjectionsMaxYear = maxYear;
                fertilityProjectionsMinYear = minYear;
            }
            case Mortality -> {
                mortalityProbabilityMaxYear = maxYear;
                mortalityProbabilityMinYear = minYear;
                mortalityProbabilityMaxAge = maxAge;
            }
            default -> {
                populationProjectionsMaxYear = maxYear;
                populationProjectionsMinYear = minYear;
                populationProjectionsMaxAge = maxAge;
            }
        }
    }

    public static int getStatePensionAge(int year, Gender demMaleFlag) {

        int spa = -9;

        switch (COUNTRY_STRING) {

            case "PL":                                      // Poland
                if (demMaleFlag == Gender.Male) {
                    // Men: 65 (<2016), 66 (2016-2017), 65 (2018+)
                    if      (year >= 2005 && year < 2016)   spa = 65;
                    else if (year >= 2016 && year < 2018)   spa = 66;
                    else if (year >= 2018 )                 spa = 65;
                } else if (demMaleFlag == Gender.Female){
                    // Women: 60 (<2016), 61 (2016-2017), 60 (2018+)
                    if      (year >= 2005 && year < 2016)   spa = 60;
                    else if (year >= 2016 && year < 2018)   spa = 61;
                    else if (year >= 2018 )                 spa = 60;
                }
                break;

            case "EL":                                      // Greece
                if (demMaleFlag == Gender.Male) {
                    // Men: 65 (<2013), 67 (2013+)
                    if      (year >= 2005 && year < 2013)   spa = 65;
                    else if (year >= 2013  )                spa = 67;
                } else if (demMaleFlag == Gender.Female){
                    // Women: 60 (<2009), 61 (2010), 63 (2011), 65 (2012), 67 (2013+)
                    if      (year >= 2005 && year < 2010)   spa = 60;
                    else if (year == 2010)                  spa = 61;
                    else if (year == 2011)                  spa = 63;
                    else if (year == 2012)                  spa = 65;
                    else if (year >= 2013 )                 spa = 67;
                }
                break;

            case "IT":                                      // Italy
                if (demMaleFlag == Gender.Male) {
                    // Men: 65 (<2012), 66 (2012–2018), 67 (2019+)
                    if      (year >= 2005 && year < 2012)   spa = 65;
                    else if (year >= 2012 && year < 2019)   spa = 66;
                    else if (year >= 2019 )                 spa = 67;
                } else if (demMaleFlag == Gender.Female) {
                    // Women: 60 (<2012), 62 (2012), 63 (2013–2014), 65 (2015–2017), 66 (2018), 67 (2019+)
                    if      (year >= 2005 && year < 2012)   spa = 60;
                    else if (year == 2012)                  spa = 62;
                    else if (year >= 2013 && year < 2015)   spa = 63;
                    else if (year >= 2015 && year < 2018)   spa = 65;
                    else if (year == 2018)                  spa = 66;
                    else if (year >= 2019 )                 spa = 67;
                }
                break;

            case "HU":                                      // Hungary
                if (demMaleFlag == Gender.Male) {
                    // Men: 62 (<2014), 63 (2014–2016), 64 (2017–2020), 65 (2021+)
                    if      (year >= 2005 && year < 2014)   spa = 62;
                    else if (year >= 2014 && year < 2017)   spa = 63;
                    else if (year >= 2017 && year < 2021)   spa = 64;
                    else if (year >= 2021 )                 spa = 65;
                } else if (demMaleFlag == Gender.Female) {
                    // Women: 60 (<2010), 62 (2010–2013), 63 (2014–2016), 64 (2017–2020), 65 (2021+)
                if          (year >= 2005 && year < 2010)   spa = 60;
                    else if (year >= 2010 && year < 2014)   spa = 62;
                    else if (year >= 2014 && year < 2017)   spa = 63;
                    else if (year >= 2017 && year < 2021)   spa = 64;
                    else if (year >= 2021 )                 spa = 65;
                }
                break;

            default:
                throw new IllegalStateException("No PSA rules for country=" + COUNTRY_STRING);
        }

        // Throw if nothing matched
        if (spa == -9) {
            throw new IllegalStateException(
                "Could not determine state pension age for: " + "country=" + COUNTRY_STRING + ", gender=" + demMaleFlag + ", year=" + year);
        }


        return spa;
    }

    public static MultiKeyCoefficientMap getCoeffLabourSupplyUtilityMales() {
        return coeffLabourSupplyUtilityMales;
    }

    public static MultiKeyCoefficientMap getCoeffLabourSupplyUtilityMalesWithDependent() {
        return coeffLabourSupplyUtilityMalesWithDependent;
    }

    public static MultiKeyCoefficientMap getCoeffLabourSupplyUtilityFemalesWithDependent() {
        return coeffLabourSupplyUtilityFemalesWithDependent;
    }

    public static MultiKeyCoefficientMap getCoeffLabourSupplyUtilityACMales() {
        return coeffLabourSupplyUtilityACMales;
    }

    public static MultiKeyCoefficientMap getCoeffLabourSupplyUtilityACFemales() {
        return coeffLabourSupplyUtilityACFemales;
    }


    public static void setCoeffLabourSupplyUtilityMales(MultiKeyCoefficientMap coeffLabourSupplyUtilityMales) {
        Parameters.coeffLabourSupplyUtilityMales = coeffLabourSupplyUtilityMales;
    }

    public static MultiKeyCoefficientMap getCoeffLabourSupplyUtilityFemales() {
        return coeffLabourSupplyUtilityFemales;
    }

    public static void setCoeffLabourSupplyUtilityFemales(MultiKeyCoefficientMap coeffLabourSupplyUtilityFemales) {
        Parameters.coeffLabourSupplyUtilityFemales = coeffLabourSupplyUtilityFemales;
    }

    public static MultiKeyCoefficientMap getCoeffLabourSupplyUtilityCouples() {
        return coeffLabourSupplyUtilityCouples;
    }

    public static void setCoeffLabourSupplyUtilityCouples(MultiKeyCoefficientMap coeffLabourSupplyUtilityCouples) {
        Parameters.coeffLabourSupplyUtilityCouples = coeffLabourSupplyUtilityCouples;
    }

    public static double getLiquidWealthDiscount() {
        return 0.0;
    }

    public static double getPensionWealthDiscount(int age) {
        int youngAgeCeiling = 45, midAgeFloor = 55, oldAgeFloor = 65;
        double discountYoung = 0.9, discountMid = 0.9, discountOld = 0.0;
        if (age <= youngAgeCeiling) {
            return discountYoung;
        } else if (age <= midAgeFloor) {
            return (discountYoung * (double)(midAgeFloor - age) + discountMid * (double)(age - youngAgeCeiling)) /
                    (double)(midAgeFloor - youngAgeCeiling);
        } else if (age < oldAgeFloor) {
            return (discountMid * (double)(oldAgeFloor-age) + discountOld * (double)(age - midAgeFloor)) /
                    (double)(oldAgeFloor - midAgeFloor);
        } else {
            return discountOld;
        }
    }

    public static double getHousingWealthDiscount(int age) {
        int youngAgeCeiling = 45, midAgeFloor = 55, oldAgeFloor = 65;
        double discountYoung = 0.9, discountMid = 0.9, discountOld = 0.0;
        if (age <= youngAgeCeiling) {
            return discountYoung;
        } else if (age <= midAgeFloor) {
            return (discountYoung * (double)(midAgeFloor - age) + discountMid * (double)(age - youngAgeCeiling)) /
                    (double)(midAgeFloor - youngAgeCeiling);
        } else if (age < oldAgeFloor) {
            return (discountMid * (double)(oldAgeFloor-age) + discountOld * (double)(age - midAgeFloor)) /
                    (double)(oldAgeFloor - midAgeFloor);
        } else {
            return discountOld;
        }
    }

    public static double updateProbability(double init, double threshold) {

        if (init<0.0 || init>1.0)
            throw new RuntimeException("call to update probability that is not strictly within range of 0 and 1");
        if (threshold<0.0 || threshold>1.0)
            throw new RuntimeException("call to update probability where threshold is not strictly within range of 0 and 1");

        return (init<threshold) ? init/threshold : (1.0-init)/(1.0-threshold);
    }
    public static double updateProbability(double init) {

        return (init<0.5) ? init/0.5 : (1-init) / 0.5;
    }

    public static double getAlignmentValue(int year, AlignmentVariable variableType) {
        switch (variableType) {
            case PartnershipAlignment -> {
                Double val = partnershipAlignAdjustment.get(year);
                if (val==null)
                    throw new RuntimeException("value undefined for partnershipAlignAdjustment in year " + year);
                return val;
            }
            case FertilityAlignment -> {
                Double val = fertilityAlignAdjustment.get(year);
                if (val==null)
                    throw new RuntimeException("value undefined for fertilityAlignAdjustment in year " + year);
                return val;
            }
            case RetirementAlignment -> {
                Double val = retirementAlignAdjustment.get(year);
                if (val==null)
                    throw new RuntimeException("value undefined for retirementAlignAdjustment in year " + year);
                return val;
            }
            case DisabilityAlignment -> {
                Double val = disabilityAlignAdjustment.get(year);
                if (val==null)
                    throw new RuntimeException("value undefined for disabilityAlignAdjustment in year " + year);
                return val;
            }
            default -> {
                throw new RuntimeException("failed to identify alignment value type to get");
            }
        }
    }

    public static void setAlignmentValue(int year, double val, AlignmentVariable variableType) {
        switch (variableType) {
            case PartnershipAlignment -> {
                partnershipAlignAdjustment.put(year, val);
            }
            case FertilityAlignment -> {
                fertilityAlignAdjustment.put(year, val);
            }
            case RetirementAlignment -> {
                retirementAlignAdjustment.put(year, val);
            }
            case DisabilityAlignment -> {
                disabilityAlignAdjustment.put(year, val);
            }
            default -> {
                throw new RuntimeException("failed to identify alignment value type in set");
            }
        }
    }

    public static double getFertilityRateByYear(int year) {
        Double val = fertilityRateByYear.get(year);
        if (val==null)
            throw new RuntimeException("value undefined for getFertilityRateByYear in year " + year);
        return val;
    }

    public static double getRetiredShareByYear(int year) {
        Double val = retiredShareByYear.get(year);
        if (val==null)
            throw new RuntimeException("value undefined for getRetiredShareByYear in year " + year);
        return val;
    }

    public static void databaseSetup(Country country, boolean executeWithGui, int startYear) {

        // remove database file if it exists
        String filePath = "./input" + File.separator + "input.mv.db";
        safeDelete(filePath);

        // populate new database for starting data
        DataParser.databaseFromCSV(country, executeWithGui); // Initial database tables

        // populate new database for tax donors
        String taxDonorInputFilename = "tax_donor_population_" + country;
        Parameters.setTaxDonorInputFileName(taxDonorInputFilename);
        Parameters.loadTimeSeriesFactorForTaxDonor(country);
        TaxDonorDataParser.constructAggregateTaxDonorPopulationCSVfile(country, executeWithGui);
        if (trainingFlag) {
            TaxDonorParserTraining.databaseFromCSV(country, startYear, executeWithGui); // Training-data variant: drops deh/drgn1/lcs, uses idhh as tuid
        } else {
            TaxDonorDataParser.databaseFromCSV(country, startYear, executeWithGui); // Donor database tables from csv data
        }
        TaxDonorDataParser.populateDonorTaxUnitTables(country, executeWithGui); // Populate tax unit donor tables from person data
    }
    private static void safeDelete(String filePath) {
        File file = new File(filePath);
        try {
            Files.deleteIfExists(file.toPath());
        } catch (IOException e) {
            e.printStackTrace();
        } catch (Throwable e) {
            e.printStackTrace();
            throw e;
        }
    }



    private static void validateCoefficientMapsForBootstrap(Object[][] namedMaps) {
        if (namedMaps == null) {
            return;
        }
        for (Object[] entry : namedMaps) {
            if (entry == null || entry.length != 2) {
                continue;
            }
            validateCoefficientMapForBootstrap((String) entry[0], (MultiKeyCoefficientMap) entry[1]);
        }
    }

    private static void validateCoefficientMapForBootstrap(String name, MultiKeyCoefficientMap map) {
        if (map == null) {
            System.out.println("Bootstrap validation: map is null: " + name);
            return;
        }
        String[] keyNames = map.getKeysNames();
        if (keyNames == null || keyNames.length == 0
                || !RegressionColumnNames.REGRESSOR.toString().equals(keyNames[0])) {
            System.out.println("Bootstrap validation: unexpected key names for " + name + ": " + Arrays.toString(keyNames));
        }
        String[] valueNames = map.getValuesNames();
        if (valueNames == null || valueNames.length == 0) {
            System.out.println("Bootstrap validation: missing value names for " + name);
            return;
        }
        for (int i = 0; i < valueNames.length; i++) {
            String valueName = valueNames[i];
            if (valueName == null || valueName.trim().isEmpty()) {
                System.out.println("Bootstrap validation: blank value name for " + name + " at index " + i
                        + " valueNames=" + Arrays.toString(valueNames));
            }
        }
        int coeffIndex = -1;
        Map<String, Integer> covariateIndex = new HashMap<>();
        for (int i = 0; i < valueNames.length; i++) {
            String valueName = valueNames[i];
            if (RegressionColumnNames.COEFFICIENT.toString().equals(valueName)) {
                coeffIndex = i;
            } else {
                covariateIndex.put(valueName, i);
            }
        }
        if (coeffIndex == -1) {
            System.out.println("Bootstrap validation: missing COEFFICIENT column for " + name);
        }
        int issueCount = 0;
        MapIterator<Object, Object> it = map.mapIterator();
        while (it.hasNext()) {
            it.next();
            MultiKey key = (MultiKey) it.getKey();
            Object[] rowValues = (Object[]) map.getValue(new Object[]{key});
            String regressor = String.valueOf(key.getKey(0));
            if (rowValues == null) {
                System.out.println("Bootstrap validation: null row for " + name + " regressor=" + regressor);
                issueCount++;
                if (issueCount >= 20) {
                    break;
                }
                continue;
            }
            if (coeffIndex >= 0) {
                if (coeffIndex >= rowValues.length || rowValues[coeffIndex] == null) {
                    System.out.println("Bootstrap validation: missing coefficient for " + name + " regressor=" + regressor);
                    issueCount++;
                }
            }
            for (Map.Entry<String, Integer> entry : covariateIndex.entrySet()) {
                Integer idx = entry.getValue();
                if (idx == null || idx >= rowValues.length || rowValues[idx] == null) {
                    System.out.println("Bootstrap validation: missing covariance for " + name
                            + " regressor=" + regressor + " covariate=" + entry.getKey());
                    issueCount++;
                    if (issueCount >= 20) {
                        break;
                    }
                }
            }
            if (issueCount >= 20) {
                System.out.println("Bootstrap validation: stopping after 20 issues for " + name);
                break;
            }
        }
    }
}
