package simpaths.model.enums;

import microsim.statistics.regression.IntegerValuedEnum;
import simpaths.data.Parameters;
import simpaths.model.Person;

import java.util.Objects;

import static simpaths.data.Parameters.COUNTRY_STRING;

public enum Labour implements IntegerValuedEnum {
    //int categoryId, int femaleMin, int femaleMax, int maleMin, int maleMax
    //Representative hours default to the bracket midpoint and realised hours spread across the bracket unless set explicitly
    //Limits are numbers, not Parameters fields: a constant is fixed when the enum is first loaded, which may come before
    //parameters.xlsx is read. The first positive band must start at the country's MIN_HOURS_EMPLOYED, and a top band
    //running to the weekly cap must end at its MAX_LABOUR_HOURS_IN_WEEK (checked by Parameters.checkLabourBandLimits)
    ZERO(0, 0, 0, 0, 0),  // 0 hours for both genders

    // TODO: representative hours of HU, IT and EL are placeholder bracket midpoints; confirm against each estimation
    //HU; same as EL
    CATEGORY_HU_1(11, 1, 39, 1, 39),
    CATEGORY_HU_2(12, 40, 40, 40, 40),
    CATEGORY_HU_3(13, 41, 48, 41, 48),    // [41-48]
    //PL; bands as EL, representative hours as in the labour-supply estimation (temp_lhw_dobs in "1-input and output data-std model.do", also used for adult children)
    //int categoryId, int femaleMin, int femaleMax, int maleMin, int maleMax, int femaleRep, int maleRep
    CATEGORY_PL_1(21, 1, 39, 1, 39, 20, 20),  //sub categoryId 20 to 1
    CATEGORY_PL_2(22, 40, 40, 40, 40, 40, 40),
    CATEGORY_PL_3(23, 41, 80, 41, 80, 50, 50),    // [41-80]


    //IT
    CATEGORY_IT_1(31, 1, 29,   1, 35),   // [1-29] vs [1-35]
    CATEGORY_IT_2(32, 30, 35,  36, 39),  // [30-35] vs [36-39]
    CATEGORY_IT_3(33, 36, 39,  40, 49),  // [36-39] vs [40-49]
    CATEGORY_IT_4(34, 40, 55, 50, 65), // [40+] vs [50+]
    //EL
    CATEGORY_EL_1(41, 1, 39,   1, 39),   // [1-39]
    CATEGORY_EL_2(42, 40, 40,  40, 40),  // [40]
    CATEGORY_EL_3(43, 41, 70,  41, 70),  // [41-70]

    //ES; bands and representative hours as in the labour-supply estimation (ES master-elast.do)
    //Only the 35-39 band (ES_3 for women, ES_2 for men) spreads realised hours uniformly; every other band realises at its representative hours
    //int categoryId, int femaleMin, int femaleMax, int maleMin, int maleMax, int femaleRep, int maleRep, boolean femaleSpread, boolean maleSpread
    CATEGORY_ES_1(51, 6, 25, 6, 34, 20, 20, false, false),   // [6-25] vs [6-34]
    CATEGORY_ES_2(52, 26, 34, 35, 39, 30, 37, false, true),    // [26-34] vs [35-39]
    CATEGORY_ES_3(53, 35, 39, 40, 40, 37, 40, true, false),    // [35-39] vs [40]
    CATEGORY_ES_4(54, 40, 40, 41, 55, 40, 50, false, false),   // [40] vs [41-55]
    CATEGORY_ES_5(55, 41, 84, 56, 84, 50, 60, false, false);   // [41-84] vs [56-84]




    private final int categoryId;
    private final int femaleMin, femaleMax;
    private final int maleMin, maleMax;
    private final int femaleRep, maleRep;                   // representative hours: used to score the choice, and realised by brackets that do not spread hours
    private final boolean femaleSpread, maleSpread;         // true: realised hours spread within [min, max]; false: realised at the representative hours

    Labour(int categoryId, int femaleMin, int femaleMax, int maleMin, int maleMax) {
        this(categoryId, femaleMin, femaleMax, maleMin, maleMax, (femaleMin + femaleMax) / 2, (maleMin + maleMax) / 2);
    }

    Labour(int categoryId, int femaleMin, int femaleMax, int maleMin, int maleMax, int femaleRep, int maleRep) {
        this(categoryId, femaleMin, femaleMax, maleMin, maleMax, femaleRep, maleRep, true, true);
    }

    Labour(int categoryId, int femaleMin, int femaleMax, int maleMin, int maleMax, int femaleRep, int maleRep,
           boolean femaleSpread, boolean maleSpread) {
        this.categoryId = categoryId;
        this.femaleMin = femaleMin;
        this.femaleMax = femaleMax;
        this.maleMin = maleMin;
        this.maleMax = maleMax;
        this.femaleRep = femaleRep;
        this.maleRep = maleRep;
        this.femaleSpread = femaleSpread;
        this.maleSpread = maleSpread;
    }

    @Override
    public int getValue() {
        return categoryId;  // Now returns category ID instead of hours
    }

    // Gender-aware conversion methods
    public static Labour convertHoursToLabour(double hoursWorked, Gender gender) {
        // fewer than MIN_HOURS_EMPLOYED hours (ES: 1-5) lie outside the estimated choice set
        if (hoursWorked <= 0 || hoursWorked < Parameters.MIN_HOURS_EMPLOYED) return ZERO;

        return switch (gender) {
            case Female -> convertFemaleHours(hoursWorked);
            default -> convertMaleHours(hoursWorked);
        };
    }

    private static Labour convertFemaleHours(double hours) {

        String country = COUNTRY_STRING;
        if (Objects.equals(country, "EL")) {
            if (hours <= 39) return CATEGORY_EL_1;
            else if (hours <= 40) return CATEGORY_EL_2;
            else return CATEGORY_EL_3;
        }
        else if (Objects.equals(country, "IT")) {
            if (hours <= 29) return CATEGORY_IT_1;
            else if (hours <= 35) return CATEGORY_IT_2;
            else if (hours <= 39) return CATEGORY_IT_3;
            else return CATEGORY_IT_4;
        }
        else if (Objects.equals(country, "PL")) {
            if (hours <= 39) return CATEGORY_PL_1;
            else if (hours <= 40) return CATEGORY_PL_2;
            else return CATEGORY_PL_3;
        }
        else if (Objects.equals(country, "ES")) {
            if (hours < 26) return CATEGORY_ES_1;
            else if (hours < 35) return CATEGORY_ES_2;
            else if (hours < 40) return CATEGORY_ES_3;
            else if (hours < 41) return CATEGORY_ES_4;
            else return CATEGORY_ES_5;
        }
        else if (Objects.equals(country, "HU")) {
            if (hours <= 39) return CATEGORY_HU_1;
            else if (hours <= 40) return CATEGORY_HU_2;
            else return CATEGORY_HU_3;
        }
        else {
            throw new IllegalArgumentException("Country not recognized: " + COUNTRY_STRING);
        }
    }


    private static Labour convertMaleHours(double hours) {
        String country = COUNTRY_STRING;
        if (Objects.equals(country, "EL")) {
            if (hours <= 39) return CATEGORY_EL_1;
            else if (hours <= 40) return CATEGORY_EL_2;
            else return CATEGORY_EL_3;
        }
        else if (Objects.equals(country, "IT")) {
            if (hours <= 35) return CATEGORY_IT_1;
            else if (hours <= 39) return CATEGORY_IT_2;
            else if (hours <= 49) return CATEGORY_IT_3;
            else return CATEGORY_IT_4;
        }
        else if (Objects.equals(country, "PL")) {
            if (hours <= 39) return CATEGORY_PL_1;
            else if (hours <= 40) return CATEGORY_PL_2;
            else return CATEGORY_PL_3;
        }
        else if (Objects.equals(country, "ES")) {
            if (hours < 35) return CATEGORY_ES_1;
            else if (hours < 40) return CATEGORY_ES_2;
            else if (hours < 41) return CATEGORY_ES_3;
            else if (hours < 56) return CATEGORY_ES_4;
            else return CATEGORY_ES_5;
        }
        else if (Objects.equals(country, "HU")) {
            if (hours <= 39) return CATEGORY_HU_1;
            else if (hours <= 40) return CATEGORY_HU_2;
            else return CATEGORY_HU_3;
        }
        else {
            throw new IllegalArgumentException("Country not recognized: " + COUNTRY_STRING);
        }
    }

    public static Labour[] valuesForCurrentCountry() {
        return valuesForCountry(COUNTRY_STRING);
    }

    public static Labour[] valuesForCountry(String country) {
        if (country == null || country.isEmpty()) {
            return values();
        }
        return switch (country) {
            case "EL" -> new Labour[]{ZERO, CATEGORY_EL_1, CATEGORY_EL_2, CATEGORY_EL_3};
            case "IT" -> new Labour[]{ZERO, CATEGORY_IT_1, CATEGORY_IT_2, CATEGORY_IT_3, CATEGORY_IT_4};
            case "PL" -> new Labour[]{ZERO, CATEGORY_PL_1, CATEGORY_PL_2, CATEGORY_PL_3};
            case "ES" -> new Labour[]{ZERO, CATEGORY_ES_1, CATEGORY_ES_2, CATEGORY_ES_3, CATEGORY_ES_4, CATEGORY_ES_5};
            case "HU" -> new Labour[]{ZERO, CATEGORY_HU_1, CATEGORY_HU_2, CATEGORY_HU_3};
            default -> values();
        };
    }

    public int getRepresentativeHours(Gender gender) {
        return (gender == Gender.Female) ? femaleRep : maleRep;
    }

    public boolean spreadsRealisedHours(Gender gender) {
        return (gender == Gender.Female) ? femaleSpread : maleSpread;
    }

    public int getMinHours(Gender gender) {
        return (gender == Gender.Female) ? femaleMin : maleMin;
    }

    public int getMaxHours(Gender gender) {
        return (gender == Gender.Female) ? femaleMax : maleMax;
    }

    public int getHours(Person person) {
        if (this == ZERO) return 0;
        if (person == null)
            throw new IllegalArgumentException("hours for " + name() + " are gender specific, so they cannot be evaluated without a person");

        Gender gender = person.getDgn();
        if (Parameters.useRepresentativeHoursInUtility && person.isEvaluatingLabourChoice())
            return getRepresentativeHours(gender);

        int min = (gender == Gender.Female) ? femaleMin : maleMin;
        int max = (gender == Gender.Female) ? femaleMax : maleMax;

        // ES, PL: draw realised hours from the EU-SILC within-band distribution
        if (Parameters.useSilcLhwDistribution()) {
            int hours = Parameters.drawSilcLhwHours(person.getSilcLhwSheet(), min, max, person.getLabourSupplyHoursDraw());
            if (hours > 0) return hours;
        }

        // brackets that do not spread hours use a single point: the representative hours while the choice is scored,
        // and for realised hours either those or (with USE_MIDPOINT_HOURS) the bracket midpoint
        if (!spreadsRealisedHours(gender))
            return (Parameters.USE_MIDPOINT_HOURS && !person.isEvaluatingLabourChoice()) ? (min + max) / 2 : getRepresentativeHours(gender);

        if (Parameters.USE_CONTINUOUS_LABOUR_SUPPLY_HOURS) {
            // each whole hour in [min, max] gets an equal share of the unit interval; min() guards a draw of exactly 1
            double draw = person.getLabourSupplyHoursDraw();
            return Math.min(min + (int) (draw * (max - min + 1)), max);
        } else {
            // Representative hours for discrete mode (the band midpoint unless set explicitly)
            return getRepresentativeHours(gender);
        }
    }

    /**
     * Position of an ES band in the labour-supply choice set: 0 for ZERO, 1 to 5 for CATEGORY_ES_1 to CATEGORY_ES_5,
     * -1 otherwise. Used to decode the alternative suffix of ES labour-supply regressors.
     */
    public int getEsIndex() {
        return switch (this) {
            case ZERO -> 0;
            case CATEGORY_ES_1 -> 1;
            case CATEGORY_ES_2 -> 2;
            case CATEGORY_ES_3 -> 3;
            case CATEGORY_ES_4 -> 4;
            case CATEGORY_ES_5 -> 5;
            default -> -1;
        };
    }
}
