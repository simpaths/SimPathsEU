package simpaths.model.enums;

import microsim.statistics.regression.IntegerValuedEnum;
import simpaths.data.Parameters;
import simpaths.model.Person;

import java.util.Objects;

import static simpaths.data.Parameters.COUNTRY_STRING;

public enum Labour implements IntegerValuedEnum {
    //int categoryId, int femaleMin, int femaleMax, int maleMin, int maleMax
    ZERO(0, 0, 0, 0, 0),  // 0 hours for both genders

    //HU; same as EL
    CATEGORY_HU_1(11, 1, 39, 1, 39),
    CATEGORY_HU_2(12, 40, 40, 40, 40),
    CATEGORY_HU_3(13, 41, Parameters.MAX_LABOUR_HOURS_IN_WEEK, 41, Parameters.MAX_LABOUR_HOURS_IN_WEEK),
    //PL; same as EL
    CATEGORY_PL_1(21, 1, 39, 1, 39),  //sub categoryId 20 to 1
    CATEGORY_PL_2(22, 40, 40, 40, 40),
    CATEGORY_PL_3(23, 41, Parameters.MAX_LABOUR_HOURS_IN_WEEK, 41, Parameters.MAX_LABOUR_HOURS_IN_WEEK),


    //IT
    CATEGORY_IT_1(31, 1, 29,   1, 35),   // [1-29] vs [1-35]
    CATEGORY_IT_2(32, 30, 35,  36, 39),  // [30-35] vs [36-39]
    CATEGORY_IT_3(33, 36, 39,  40, 49),  // [36-39] vs [40-49]
    CATEGORY_IT_4(34, 40, 55, 50, 65), // [40+] vs [50+]
    //EL
    CATEGORY_EL_1(41, 1, 39,   1, 39),   // [1-39]
    CATEGORY_EL_2(42, 40, 40,  40, 40),  // [40]
    CATEGORY_EL_3(43, 41, Parameters.MAX_LABOUR_HOURS_IN_WEEK,  41, Parameters.MAX_LABOUR_HOURS_IN_WEEK),  // [41+]

    //ES
    CATEGORY_ES_1(51, 6, 35, 6, 35),  //sub categoryId 20 to 1
    CATEGORY_ES_2(52, 36, 40, 36, 40),
    CATEGORY_ES_3(53, 41, Parameters.MAX_LABOUR_HOURS_IN_WEEK, 41, Parameters.MAX_LABOUR_HOURS_IN_WEEK);




    private final int categoryId;
    private final int femaleMin, femaleMax;
    private final int maleMin, maleMax;

    Labour(int categoryId, int femaleMin, int femaleMax, int maleMin, int maleMax) {
        this.categoryId = categoryId;
        this.femaleMin = femaleMin;
        this.femaleMax = femaleMax;
        this.maleMin = maleMin;
        this.maleMax = maleMax;
    }

    @Override
    public int getValue() {
        return categoryId;  // Now returns category ID instead of hours
    }

    // Gender-aware conversion methods
    public static Labour convertHoursToLabour(double hoursWorked, Gender gender) {
        if (hoursWorked <= 0) return ZERO;

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
            if (hours < 6) return ZERO;          // 1-5 hours: outside the estimated choice set
            else if (hours <= 35) return CATEGORY_ES_1;
            else if (hours <= 40) return CATEGORY_ES_2;
            else return CATEGORY_ES_3;
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
            if (hours < 6) return ZERO;          // 1-5 hours: outside the estimated choice set
            else if (hours <= 35) return CATEGORY_ES_1;
            else if (hours <= 40) return CATEGORY_ES_2;
            else return CATEGORY_ES_3;
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
            case "ES" -> new Labour[]{ZERO, CATEGORY_ES_1, CATEGORY_ES_2, CATEGORY_ES_3};
            case "HU" -> new Labour[]{ZERO, CATEGORY_HU_1, CATEGORY_HU_2, CATEGORY_HU_3};
            default -> values();
        };
    }

    public int getHours(Person person) {
        if (this == ZERO) return 0;
        if (person == null)
            throw new IllegalArgumentException("hours for " + name() + " are gender specific, so they cannot be evaluated without a person");

        Gender gender = person.getDgn();
        int min = (gender == Gender.Female) ? femaleMin : maleMin;
        int max = (gender == Gender.Female) ? femaleMax : maleMax;

        if (Parameters.USE_CONTINUOUS_LABOUR_SUPPLY_HOURS) {
            double draw = person.getLabourSupplySingleDraw();
            return (int) Math.round(draw * (max - min) + min);
        } else {
            // Return midpoint for discrete mode
            return (min + max) / 2;
        }
    }
}
