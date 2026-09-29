/*******************************************************************************
* PROJECT:        SimPaths EU
* DO-FILE NAME:   01_key_function_income_thresholds_from_EUROMOD_2018.do
* DESCRIPTION:    Calculate clean 2018 KEY_FUNCTION income thresholds directly
*                 from raw EUROMOD output for PL, EL, HU, IT and ES.
*
*                 Rule implemented:
*                   1. Import raw 2018 EUROMOD person-level file
*                   2. Aggregate ils_origy to benefit-unit level
*                   3. Keep benefit units with 1 or 2 adults only
*                   4. Keep positive original income only
*                   5. Calculate unweighted 33rd and 67th percentiles
*                   6. Convert monthly values to weekly values
*
*                 The script evaluates two grouping approaches per country:
*                   - model_bu:     the benefit-unit HeadID that SimPaths uses
*                                   in the simulation (matches the Java model)
*                   - alternate_bu: an alternative EUROMOD tax-unit HeadID that
*                                   groups individuals differently (e.g. nuclear
*                                   family vs. extended cohabiting family), used
*                                   here for comparison to assess how the choice
*                                   of benefit-unit definition affects thresholds
*                                   (not available for ES, which only ships a
*                                   single tu_nucfam_HeadID definition)
*
* OUTPUTS:        documentation/key_function_income_thresholds_clean2018.dta
*                 documentation/key_function_income_thresholds_clean2018.xlsx
*
* NOTES:          - Percentiles use linear interpolation on the sorted
*                   aggregated benefit-unit incomes.
*                 - Values are reported in local currency per week.
*******************************************************************************/

version 18
clear all
set more off
set type double


/*******************************************************************************
* LOCATE PROJECT ROOT
*******************************************************************************/

local dir_w "`c(pwd)'"
capture confirm file "`dir_w'/input/DatabaseCountryYear.xlsx"
if _rc {
    local dir_w "/Users/pineapple/IdeaProjects/SimPathsEU_AUG"
}

capture confirm file "`dir_w'/input/DatabaseCountryYear.xlsx"
if _rc {
    di as error "Project root not found. Set local dir_w to the SimPathsEU_AUG root."
    exit 601
}

local dir_out "`dir_w'/input_processing"
local out_xlsx "`dir_out'/key_function_income_thresholds_2018.xlsx"

local ref_year 2018
local weeks_per_month = 365.25 / (7 * 12)


/*******************************************************************************
* HELPER: INTERPOLATED QUANTILE
*******************************************************************************/

capture program drop interp_quantile
program define interp_quantile, rclass
    syntax varname(numeric) , P(real)

    quietly count if !missing(`varlist')
    local N = r(N)
    if `N' == 0 {
        return scalar q = .
        return scalar n = 0
        exit
    }

    scalar __h = 1 + (`N' - 1) * `p'
    local lo = floor(scalar(__h))
    local hi = ceil(scalar(__h))

    quietly summarize `varlist' in `lo'/`lo', meanonly
    scalar __q_lo = r(mean)

    quietly summarize `varlist' in `hi'/`hi', meanonly
    scalar __q_hi = r(mean)

    return scalar q = scalar(__q_lo) + (scalar(__h) - `lo') * (scalar(__q_hi) - scalar(__q_lo))
    return scalar n = `N'

    scalar drop __h __q_lo __q_hi
end


/*******************************************************************************
* INITIALISE RESULTS STORAGE
*******************************************************************************/

tempfile results_tmp
tempname post_handle

postfile `post_handle' ///
    str2 country ///
    str3 currency ///
    str12 approach ///
    str32 bu_id ///
    int ref_year ///
    long n_bu ///
    double lo_monthly ///
    double hi_monthly ///
    double lo_weekly ///
    double hi_weekly ///
    long lo_weekly_rounded ///
    long hi_weekly_rounded ///
    using `results_tmp', replace


/*******************************************************************************
* LOOP OVER COUNTRIES
*******************************************************************************/
foreach country in PL EL HU IT ES {


    if "`country'" == "PL" {
        local iso_code   "pl"
        local currency   "PLN"
        local model_bu   "tu_fambu_pl_HeadID"
        local alt_bu     "tu_fa_itjt_pl_HeadID"
    }
    else if "`country'" == "EL" {
        local iso_code   "el"
        local currency   "EUR"
        local model_bu   "tu_bu_el_HeadID"
        local alt_bu     "tu_it_fa_el_HeadID"
    }
    else if "`country'" == "HU" {
        local iso_code   "hu"
        local currency   "HUF"
        local model_bu   "tu_cbfam_hu_HeadID"
        local alt_bu     "tu_cpfam_hu_HeadID"
    }
    else if "`country'" == "IT" {
        local iso_code   "it"
        local currency   "EUR"
        local model_bu   "tu_bu_it_HeadID"
        local alt_bu     "tu_fa_family_it_HeadID"
    }
    else if "`country'" == "ES" {
        local iso_code   "es"
        local currency   "EUR"
        local model_bu   "tu_nucfam_HeadID"
        local alt_bu     ""
    }

    local euromod_file "`dir_w'/input/`country'/EUROMODoutput/`iso_code'_`ref_year'_std.txt"
    capture confirm file "`euromod_file'"
    if _rc {
        di as error "Missing EUROMOD file: `euromod_file'"
        exit 601
    }

    di as txt "Processing `country' from `euromod_file'"

    import delimited using "`euromod_file'", clear delim(tab) stringcols(_all) varnames(1) case(preserve)

    if "`alt_bu'" == "" {
        keep `model_bu' dag ils_origy
    }
    else {
        keep `model_bu' `alt_bu' dag ils_origy
    }
    destring dag ils_origy, replace force

    local approach_list "model_bu"
    if "`alt_bu'" != "" {
        local approach_list "model_bu alternate_bu"
    }

    foreach approach of local approach_list {

        preserve

        if "`approach'" == "model_bu" {
            local active_bu "`model_bu'"
        }
        else {
            local active_bu "`alt_bu'"
        }

        keep `active_bu' dag ils_origy
        rename `active_bu' bu_head_id

        drop if missing(bu_head_id)
        drop if missing(dag)
        drop if missing(ils_origy)

        gen byte adult = dag >= 18

        collapse ///
            (sum) monthly_original_income = ils_origy ///
            (sum) adult_count = adult, ///
            by(bu_head_id)

        keep if inrange(adult_count, 1, 2)
        keep if monthly_original_income > 0

        sort monthly_original_income

        quietly interp_quantile monthly_original_income, p(0.33)
        scalar __lo_monthly = r(q)
        local n_bu = r(n)

        quietly interp_quantile monthly_original_income, p(0.67)
        scalar __hi_monthly = r(q)

        scalar __lo_weekly = __lo_monthly / `weeks_per_month'
        scalar __hi_weekly = __hi_monthly / `weeks_per_month'

        local lo_round = round(scalar(__lo_weekly))
        local hi_round = round(scalar(__hi_weekly))

        post `post_handle' ///
            ("`country'") ///
            ("`currency'") ///
            ("`approach'") ///
            ("`active_bu'") ///
            (`ref_year') ///
            (`n_bu') ///
            (scalar(__lo_monthly)) ///
            (scalar(__hi_monthly)) ///
            (scalar(__lo_weekly)) ///
            (scalar(__hi_weekly)) ///
            (`lo_round') ///
            (`hi_round')

        scalar drop __lo_monthly __hi_monthly __lo_weekly __hi_weekly

        restore
    }
}

postclose `post_handle'


/*******************************************************************************
* SAVE AND EXPORT RESULTS
*******************************************************************************/

use `results_tmp', clear

gen str30 sample_rule = "1-2 adults, positive income"
gen str18 weighting = "unweighted"
gen str24 income_measure = "ils_origy aggregated"
gen str20 time_unit = "weekly"

gen str20 lo_hi_weekly_exact = string(lo_weekly, "%9.2f") + " / " + string(hi_weekly, "%9.2f")
gen str20 lo_hi_weekly_round = string(lo_weekly_rounded, "%9.0f") + " / " + string(hi_weekly_rounded, "%9.0f")

order country currency approach bu_id ref_year n_bu sample_rule weighting income_measure time_unit ///
    lo_monthly hi_monthly lo_weekly hi_weekly lo_weekly_rounded hi_weekly_rounded ///
    lo_hi_weekly_exact lo_hi_weekly_round

sort country approach

format lo_monthly hi_monthly lo_weekly hi_weekly %12.2f
compress

export excel using "`out_xlsx'", sheet("results") firstrow(variables) sheetreplace

putexcel set "`out_xlsx'", sheet("info") modify
putexcel A1=("Field")            B1=("Value")
putexcel A2=("Reference year")   B2=("2018")
putexcel A3=("Income variable")  B3=("ils_origy from raw EUROMOD output")
putexcel A4=("Aggregation")      B4=("Benefit-unit level sum by HeadID")
putexcel A5=("Sample rule")      B5=("Keep only benefit units with 1 or 2 adults and positive original income")
putexcel A6=("Percentiles")      B6=("33rd and 67th")
putexcel A7=("Weighting")        B7=("Unweighted")
putexcel A8=("Time conversion")  B8=("Weekly = monthly / (365.25 / (7 * 12))")
putexcel A9=("Approaches")       B9=("model_bu = model benefit-unit ID; alternate_bu = plausible raw EUROMOD alternative (not available for ES)")
putexcel A10=("Countries")       B10=("PL, EL, HU, IT, ES")
putexcel A11=("Output values")   B11=("Local currency per week, exact and rounded")
putexcel A12=("Do-file")         B12=("01_key_function_income_thresholds_from_EUROMOD_2018.do")

di as txt "Saved results to:"
di as txt "  `out_xlsx'"
list country approach bu_id lo_hi_weekly_exact lo_hi_weekly_round, noobs abbreviate(32)
