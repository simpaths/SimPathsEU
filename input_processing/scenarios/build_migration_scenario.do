/*******************************************************************************
* PROJECT:        SimPaths EU
* SECTION:        INPUT SCENARIOS
*
* COUNTRY:        any country with input/<CC>/align_popProjections.xlsx and a
*                 Eurostat extract eurostat_proj_23naasfr_<CC>.csv in this folder
*
* DATA:           input/<CC>/align_popProjections.xlsx, sheet
*                 Population_projections (the baseline population projection)
*                 input_processing/scenarios/eurostat_proj_23naasfr_<CC>.csv
*                 (Eurostat's projected age-specific fertility rates, baseline
*                 variant; see eurostat_extracts.md)
*
* DESCRIPTION:    Builds a migration scenario folder for the model argument
*                 inputScenario: a constant number of arrivals a year from a
*                 first arrival year on (to the workbook's last year, or to an
*                 optional last arrival year), added to the baseline projection as a
*                 migrant stock that ages, dies and has children through the
*                 cells, and the deviations of the Ramsey planner's workers N
*                 and population P that this population implies.
*
*                 Method:
*                  - Arrivals of year t count in column t: arrivals x share of
*                    the gender / number of ages for every age age_lo..age_hi,
*                    spread over regions in proportion to the baseline's
*                    gender-age-region cell in t.
*                  - The migrant stock ages from t to t+1 with the survival
*                    min(1, pop(g,a+1,t+1) / pop(g,a,t)) of the baseline summed
*                    over regions, set to 1 below age 50. The open age group
*                    keeps 0.7 of itself plus the survivors from the age below.
*                  - Births during t: Eurostat's rate of t (the last year's
*                    rates beyond the extract) x migrant women of each age
*                    15-49 in t; half boys; they enter age 0 in t+1 in the
*                    mother's region.
*                  - Scenario workbook = baseline + migrant stock, cell by cell.
*                  - N = WAP_scen / WAP_base - 1 (ages 15-64) and
*                    P = TOT_scen / TOT_base - 1 (all ages), summed over genders
*                    and regions, one row per workbook year, as in
*                    input_processing/macromodel/build_population_projection.m.
*
*                 Checks (the do-file stops and removes its outputs on failure):
*                  (a) every scenario cell before first_year equals the
*                      baseline, and N and P are exactly 0 there;
*                  (b) N and P recomputed from the re-imported workbook equal
*                      the written CSV within 1e-12;
*                  (c) with arrivals 0, every cell equals the baseline and every
*                      N and P is 0.
*                 It also lists, from first_year on, the fertility target
*                 SimPaths reads from each workbook
*                 (Parameters.calculateFertilityRatesFromProjections: age-0
*                 count of both genders over women aged 18-49).
*
* USAGE:          From the repository root, in PowerShell (Git Bash mangles /e):
*                   Start-Process <Stata>\StataMP-64.exe -ArgumentList '/e','do',
*                     'input_processing/scenarios/build_migration_scenario.do',
*                     'PL','migration_200k','2030','200000','20','34','0.5' -Wait
*                 Arguments: cc name first_year arrivals age_lo age_hi
*                 share_female [last_arrival_year]. Without the last argument
*                 the arrivals continue to the workbook's last year. The log is
*                 build_migration_scenario.log in the working directory.
*
* OUTPUTS:        input/<CC>/scenarios/<name>/align_popProjections.xlsx
*                 input/<CC>/scenarios/<name>/ramsey_migration.csv
*                 input/<CC>/scenarios/<name>/README.md
*                 The workbook and the CSV come from one run and are rebuilt
*                 together.
*
*******************************************************************************/

version 18
clear all
set type double
set more off

args cc name first_year arrivals age_lo age_hi share_female last_arrival


* --- PROGRAMS ---------------------------------------------------------------- *

capture program drop fail
program define fail
    * Stops the do-file with an argument or input error.
    di as error `"build_migration_scenario: `0'"'
    exit 198
end

capture program drop read_projection
program define read_projection, rclass
    * Loads sheet Population_projections of a population workbook: Gender,
    * Region, Age and one double variable <prefix><year> per year column, the
    * year taken from the column's header. row keeps the file's row order.
    syntax using/, prefix(name)
    import excel using `"`using'"', sheet("Population_projections") firstrow clear
    quietly describe, varlist
    local allvars `r(varlist)'
    if "`: word 1 of `allvars''" != "Gender" | "`: word 2 of `allvars''" != "Region" | "`: word 3 of `allvars''" != "Age" {
        di as error `"`using': the first three columns must be Gender, Region, Age; found `: word 1 of `allvars'', `: word 2 of `allvars'', `: word 3 of `allvars''"'
        exit 459
    }
    confirm string variable Gender Region
    confirm numeric variable Age
    quietly drop if missing(Gender) & missing(Region) & missing(Age)
    local years
    local types
    local k 0
    foreach v of local allvars {
        local ++k
        if `k' <= 3 continue
        local lab : variable label `v'
        capture confirm integer number `lab'
        if _rc {
            di as error `"`using': column `v' has the header "`lab'", not a year"'
            exit 459
        }
        capture confirm numeric variable `v'
        if _rc {
            di as error `"`using': the column of `lab' is not numeric"'
            exit 459
        }
        local types `types' `: type `v''
        rename `v' `prefix'`lab'
        local years `years' `lab'
    }
    recast double `prefix'*
    gen long row = _n
    isid Gender Region Age
    assert inlist(Gender, "Female", "Male")
    foreach t of local years {
        assert !missing(`prefix'`t') & `prefix'`t' >= 0
    }
    sort Gender Region Age
    by Gender Region: assert Age == _n - 1
    quietly summarize Age
    local maxage = r(max)
    by Gender Region: assert _N == `maxage' + 1
    sort row
    local types : list uniq types
    return local years "`years'"
    return local types "`types'"
    return scalar maxage = `maxage'
end

capture program drop yearly_totals
program define yearly_totals
    * For the wide data in memory, per year: working-age (15-64) and total
    * population, age-0 count and women aged 18-49 (Parameters.MIN_AGE_MATERNITY
    * to MAX_AGE_MATERNITY), for the baseline variables <base><year> and the
    * scenario variables <scen><year>, and from them N, P, total / 15-64 and the
    * fertility target. Both are summed over the same observations in the same
    * order, so equal columns give equal sums and exactly zero N and P.
    syntax, base(name) scen(name) years(numlist) saving(string)
    tempname h wb ws tb ts zb zs fb fs
    postfile `h' int year double(wap_b wap_s tot_b tot_s age0_b age0_s fw_b fw_s) using `"`saving'"', replace
    foreach t of local years {
        quietly summarize `base'`t' if inrange(Age, 15, 64), meanonly
        scalar `wb' = r(sum)
        quietly summarize `scen'`t' if inrange(Age, 15, 64), meanonly
        scalar `ws' = r(sum)
        quietly summarize `base'`t', meanonly
        scalar `tb' = r(sum)
        quietly summarize `scen'`t', meanonly
        scalar `ts' = r(sum)
        quietly summarize `base'`t' if Age == 0, meanonly
        scalar `zb' = r(sum)
        quietly summarize `scen'`t' if Age == 0, meanonly
        scalar `zs' = r(sum)
        quietly summarize `base'`t' if Gender == "Female" & inrange(Age, 18, 49), meanonly
        scalar `fb' = r(sum)
        quietly summarize `scen'`t' if Gender == "Female" & inrange(Age, 18, 49), meanonly
        scalar `fs' = r(sum)
        post `h' (`t') (`wb') (`ws') (`tb') (`ts') (`zb') (`zs') (`fb') (`fs')
    }
    postclose `h'
    preserve
    use `"`saving'"', clear
    gen double N = wap_s / wap_b - 1
    gen double P = tot_s / tot_b - 1
    gen double dep_b = tot_b / wap_b
    gen double dep_s = tot_s / wap_s
    gen double fert_b = age0_b / fw_b
    gen double fert_s = age0_s / fw_s
    save `"`saving'"', replace
    restore
end


* --- ARGUMENTS --------------------------------------------------------------- *

foreach a in cc name first_year arrivals age_lo age_hi share_female {
    if `"``a''"' == "" fail argument `a' is missing. Arguments: cc name first_year arrivals age_lo age_hi share_female [last_arrival_year]
}
if "`last_arrival'" != "" {
    capture confirm integer number `last_arrival'
    if _rc fail last_arrival_year must be an integer, got `last_arrival'
}
if !ustrregexm("`cc'", "^[A-Z]{2}$") fail cc must be a two-letter country code such as PL, got `cc'
if !ustrregexm("`name'", "^[A-Za-z0-9_][A-Za-z0-9_-]*$") fail name must be a folder name of letters, digits, _ and -, got `name'
foreach a in first_year age_lo age_hi {
    capture confirm integer number ``a''
    if _rc fail `a' must be an integer, got ``a''
}
foreach a in arrivals share_female {
    capture confirm number ``a''
    if _rc fail `a' must be a number, got ``a''
}
if `arrivals' < 0 fail arrivals must not be negative, got `arrivals'
if `share_female' < 0 | `share_female' > 1 fail share_female must lie between 0 and 1, got `share_female'
if `age_lo' < 0 | `age_lo' > `age_hi' fail the arrival ages must satisfy 0 <= age_lo <= age_hi, got `age_lo' and `age_hi'

local baseline "input/`cc'/align_popProjections.xlsx"
local asfr_csv "input_processing/scenarios/eurostat_proj_23naasfr_`cc'.csv"
local outdir   "input/`cc'/scenarios/`name'"
local xlsx     "`outdir'/align_popProjections.xlsx"
local csv      "`outdir'/ramsey_migration.csv"
local readme   "`outdir'/README.md"
local today : display %tdCCYY-NN-DD date(c(current_date), "DMY")

capture confirm file "`baseline'"
if _rc fail `baseline' not found; run this do-file from the repository root
capture confirm file "`asfr_csv'"
if _rc fail `asfr_csv' not found; download it as input_processing/scenarios/eurostat_extracts.md describes

local to_txt = cond("`last_arrival'" != "", " to `last_arrival'", "")
di as text _n "Scenario `name' for `cc': `arrivals' arrivals a year from `first_year'`to_txt', ages `age_lo'-`age_hi', share of women `share_female'"


* --- 1. BASELINE WORKBOOK ---------------------------------------------------- *

read_projection using "`baseline'", prefix(y)
local years `r(years)'
local maxage = r(maxage)
di as text "Baseline `baseline': `=_N' rows, ages 0-`maxage', storage type of the year columns as imported: `r(types)' (recast to double)"

local nyears : word count `years'
local first_wb : word 1 of `years'
local last_wb : word `nyears' of `years'
local k 0
foreach t of local years {
    if `t' != `first_wb' + `k' fail the year columns of `baseline' are not consecutive (`years')
    local ++k
}
if `nyears' + 3 > 702 fail the workbook has more year columns than this do-file can label
if `first_year' < `first_wb' | `first_year' > `last_wb' fail first_year `first_year' lies outside the workbook years `first_wb'-`last_wb'
if `age_hi' > `maxage' fail age_hi `age_hi' exceeds the workbook's oldest age `maxage'
di as text "Workbook years `first_wb'-`last_wb'"
* the arrivals' last year: the workbook's last year unless given; the texts name it only when given
local stops = "`last_arrival'" != ""
if !`stops' local last_arrival `last_wb'
if `last_arrival' < `first_year' | `last_arrival' > `last_wb' fail last_arrival_year `last_arrival' must lie between first_year `first_year' and the workbook's last year `last_wb'
local span     = cond(`stops', "from `first_year' to `last_arrival'", "from `first_year' on")
local stop_arg = cond(`stops', ",'`last_arrival''", "")
local stop_par = cond(`stops', "last arrival year `last_arrival'; ", "")

tempfile base
save `base'


* --- 2. EUROSTAT FERTILITY RATES --------------------------------------------- *

import delimited using "`asfr_csv'", clear varnames(1) case(lower) stringcols(_all) delimiters(",")
confirm variable projection unit geo age time_period obs_value
quietly keep if projection == "BSL" & unit == "NR" & geo == "`cc'" & ustrregexm(age, "^Y[0-9]+$")
gen int Age = real(substr(age, 2, .))
quietly keep if inrange(Age, 15, 49)
if _N == 0 fail `asfr_csv' holds no single-age rates 15-49 of projection BSL for `cc'
gen int year = real(time_period)
gen double rate = real(obs_value)
assert !missing(Age, year, rate) & rate >= 0
isid Age year
bysort year: assert _N == 35
quietly summarize year
local ext_first = r(min)
local ext_last = r(max)
quietly levelsof year
if `: word count `r(levels)'' != `ext_last' - `ext_first' + 1 fail the years of `asfr_csv' are not consecutive
if `first_year' < `ext_first' fail `asfr_csv' starts in `ext_first', after the first arrival year `first_year'
keep Age year rate
quietly reshape wide rate, i(Age) j(year)
forvalues t = `first_year'/`last_wb' {
    local ry = min(`t', `ext_last')
    gen double fr`t' = rate`ry'
}
keep Age fr*
quietly summarize fr`first_year'
local tfr_first = r(sum)
quietly summarize fr`last_wb'
local tfr_last = r(sum)
di as text "Eurostat rates `ext_first'-`ext_last' (projection BSL); sum over ages 15-49: " %6.4f (`tfr_first') " in `first_year', " %6.4f (`tfr_last') " in `last_wb'" cond(`last_wb' > `ext_last', " (rates of `ext_last')", "")
tempfile asfr
save `asfr'


* --- 3. MIGRANT STOCK -------------------------------------------------------- *

use `base', clear
merge m:1 Age using `asfr', nogenerate keep(master match)
forvalues t = `first_year'/`last_wb' {
    quietly replace fr`t' = 0 if missing(fr`t')
}
gen byte female = Gender == "Female"
gen double gshare = cond(female, `share_female', 1 - `share_female')
local nages = `age_hi' - `age_lo' + 1
foreach t of local years {
    * national population of the gender-age cell, for region shares and survival
    egen double nb`t' = total(y`t'), by(Gender Age)
    assert nb`t' > 0
    gen double m`t' = 0
}

sort Gender Region Age
forvalues t = `first_year'/`last_wb' {
    local p = `t' - 1
    if `t' > `first_year' {
        * ageing from p to t: survival of age a-1 in p to age a in t
        quietly by Gender Region (Age): replace m`t' = cond(Age[_n-1] < 50, 1, min(1, nb`t' / nb`p'[_n-1])) * m`p'[_n-1] if _n > 1
        * the open age group keeps 0.7 of itself
        quietly replace m`t' = m`t' + 0.7 * m`p' if Age == `maxage'
        * births during p by migrant women 15-49, half boys, age 0 in t in the mother's region
        egen double births = total(female * fr`p' * m`p'), by(Region)
        quietly replace m`t' = 0.5 * births if Age == 0
        drop births
        sort Gender Region Age
    }
    * arrivals in t, uniform over ages, spread over regions like the baseline's cell
    if `t' <= `last_arrival' {
        quietly replace m`t' = m`t' + `arrivals' * gshare / `nages' * y`t' / nb`t' if inrange(Age, `age_lo', `age_hi')
    }
}

foreach t of local years {
    assert !missing(m`t') & m`t' >= 0
    if `t' < `first_year' assert m`t' == 0
    gen double s`t' = y`t' + m`t'
}

tempname mig_last tot_last
quietly summarize m`last_wb'
scalar `mig_last' = r(sum)
quietly summarize s`last_wb'
scalar `tot_last' = r(sum)
local s_arrivals = strtrim(string(`arrivals' * (`last_arrival' - `first_year' + 1), "%15.0fc"))
local s_migrants = strtrim(string(`mig_last', "%15.0fc"))
local s_share = strtrim(string(100 * `mig_last' / `tot_last', "%5.1f"))
local migrant_line "Arrivals `first_year'-`last_arrival': `s_arrivals'; migrants and descendants in `last_wb': `s_migrants' (`s_share'% of the population)"
di as text "`migrant_line'"

tempfile tot_mem
yearly_totals, base(y) scen(s) years(`years') saving(`tot_mem')


* --- 4. SCENARIO WORKBOOK AND DEVIATION FILE --------------------------------- *

capture mkdir "input/`cc'/scenarios"
capture mkdir "`outdir'"
mata: st_local("dir_ok", strofreal(direxists(st_local("outdir"))))
if !`dir_ok' fail could not create `outdir'

preserve
keep row Gender Region Age s*
sort row
drop row
rename s* y*
order Gender Region Age
export excel using "`xlsx'", sheet("Population_projections") firstrow(variables) replace
* year headers as numbers, as Parameters and build_population_projection.m read them
local cells
local c 3
foreach t of local years {
    local ++c
    local col = cond(`c' <= 26, char(64 + `c'), char(64 + floor((`c' - 1) / 26)) + char(65 + mod(`c' - 1, 26)))
    local cells `cells' `col'1 = `t'
}
putexcel set "`xlsx'", sheet("Population_projections") modify
putexcel `cells'
putexcel clear
restore

preserve
use `tot_mem', clear
* %24.0g writes every double exactly (zeros as 0); a leading 0 before a bare decimal point
foreach v in N P {
    gen str40 str`v' = strtrim(string(`v', "%24.0g"))
    quietly replace str`v' = "0" + str`v' if substr(str`v', 1, 1) == "."
    quietly replace str`v' = "-0" + substr(str`v', 2, .) if substr(str`v', 1, 2) == "-."
}
tempname fh
file open `fh' using "`csv'", write text replace
file write `fh' "# Ramsey scenario `name' (`cc'): relative deviations of the planner's workers N (ages 15-64) and population P (all ages) from the baseline" _n
file write `fh' "# N = WAP_scenario / WAP_baseline - 1 and P = TOT_scenario / TOT_baseline - 1 over all genders and regions of align_popProjections.xlsx in this folder against input/`cc'/align_popProjections.xlsx" _n
file write `fh' "# Parameters: first arrival year `first_year'; `stop_par'`arrivals' arrivals a year; ages `age_lo'-`age_hi' uniform; share of women `share_female'" _n
file write `fh' "# Built by input_processing/scenarios/build_migration_scenario.do on `today'" _n
file write `fh' "# Rebuild together with align_popProjections.xlsx of this folder: both come from one run of the do-file" _n
file write `fh' "year,N,P" _n
forvalues i = 1/`=_N' {
    local line = string(year[`i']) + "," + strN[`i'] + "," + strP[`i']
    file write `fh' "`line'" _n
}
file close `fh'
restore
di as text "Wrote `xlsx' and `csv'"


* --- 5. CHECKS --------------------------------------------------------------- *

tempfile wbase tot_file
capture noisily {
    * both workbooks as SimPaths reads them
    read_projection using "`baseline'", prefix(b)
    rename row brow
    save `wbase'
    read_projection using "`xlsx'", prefix(s)
    di as text "Written workbook re-imported: `=_N' rows, storage type of the year columns as imported: `r(types)'"
    if "`r(years)'" != "`years'" {
        di as error "the written workbook has the years `r(years)', the baseline `years'"
        exit 9
    }
    merge 1:1 Gender Region Age using `wbase'
    assert _merge == 3
    drop _merge
    * same rows in the same order, no cell below the baseline
    assert row == brow
    foreach t of local years {
        assert s`t' >= b`t'
    }

    * (a) cells before first_year
    foreach t of local years {
        if `t' < `first_year' assert s`t' == b`t'
    }

    * (c) arrivals 0: every cell
    if `arrivals' == 0 {
        foreach t of local years {
            assert s`t' == b`t'
        }
    }

    yearly_totals, base(b) scen(s) years(`years') saving(`tot_file')

    * the year headers are numbers
    import excel using "`xlsx'", sheet("Population_projections") clear
    assert A == "Gender" & B == "Region" & C == "Age" in 1
    quietly describe, varlist
    local k 0
    foreach v in `r(varlist)' {
        local ++k
        if `k' <= 3 continue
        confirm numeric variable `v'
        local t : word `=`k' - 3' of `years'
        assert `v' == `t' in 1
    }
    if `k' - 3 != `nyears' {
        di as error "the written workbook has `=`k' - 3' year columns, the baseline `nyears'"
        exit 9
    }
    di as result "Year headers of the written workbook are numeric: `first_wb'-`last_wb'"

    * (b) the CSV as written against N and P recomputed from the written workbook
    import delimited using "`csv'", clear varnames(nonames) stringcols(_all) delimiters(",")
    quietly drop if substr(strtrim(v1), 1, 1) == "#"
    assert v1 == "year" & v2 == "N" & v3 == "P" in 1
    quietly drop in 1
    gen int year = real(v1)
    gen double N_csv = real(v2)
    gen double P_csv = real(v3)
    assert !missing(year, N_csv, P_csv)
    keep year N_csv P_csv
    merge 1:1 year using `tot_file', keepusing(N P)
    assert _merge == 3
    gen double dN = abs(N_csv - N)
    gen double dP = abs(P_csv - P)
    quietly summarize dN
    local max_dN = r(max)
    quietly summarize dP
    local max_dP = r(max)
    assert dN <= 1e-12 & dP <= 1e-12
    di as result "Check (b) passed: N and P recomputed from the written workbook equal the CSV for all `=_N' years (largest differences " %9.2e `max_dN' " and " %9.2e `max_dP' ")"

    assert N_csv == 0 & P_csv == 0 if year < `first_year'
    di as result "Check (a) passed: every cell before `first_year' equals the baseline, and N and P are exactly 0 for `first_wb'-`=`first_year' - 1'"
    if `arrivals' == 0 {
        assert N_csv == 0 & P_csv == 0
        di as result "Check (c) passed: arrivals are 0; every cell of `first_wb'-`last_wb' equals the baseline, and N and P are 0 in every year"
    }
    else {
        di as text "Check (c) not applicable: arrivals are `arrivals', not 0"
    }
}
if _rc {
    local rc = _rc
    capture erase "`xlsx'"
    capture erase "`csv'"
    capture erase "`readme'"
    di as error "build_migration_scenario: a check failed (r(`rc')); the outputs in `outdir' were removed"
    exit `rc'
}


* --- 6. FERTILITY TARGET, N, P ----------------------------------------------- *

use `tot_file', clear
gen double fert_pct = 100 * (fert_s / fert_b - 1)
format N P %10.6f
format dep_b dep_s fert_b fert_s %9.6f
format fert_pct %8.3f
di as text _n "Fertility target SimPaths reads (age-0 count of both genders over women aged 18-49), from `first_year' on"
list year fert_b fert_s fert_pct if year >= `first_year', noobs sep(0) abbreviate(10)
di as text _n "Planner deviations N, P and total / 15-64, from `first_year' on"
list year N P dep_b dep_s if year >= `first_year', noobs sep(0) abbreviate(10)


* --- 7. README --------------------------------------------------------------- *

local tyears
forvalues t = `first_year'(10)`last_wb' {
    local tyears `tyears' `t'
}
local has_last : list last_wb in tyears
if !`has_last' local tyears `tyears' `last_wb'

local bq "_char(96)"
file open `fh' using "`readme'", write text replace
file write `fh' "# Input scenario " `bq' "`name'" `bq' " (`cc')" _n _n
file write `fh' "A population in which `cc' receives `arrivals' immigrants a year more than in the baseline projection, `span'," _n
file write `fh' "aged `age_lo'-`age_hi' (uniform), share of women `share_female'. The folder holds:" _n _n
file write `fh' "- " `bq' "align_popProjections.xlsx" `bq' ": the scenario population (sheet " `bq' "Population_projections" `bq' ", same rows and years as" _n
file write `fh' "  " `bq' "input/`cc'/align_popProjections.xlsx" `bq' "). With the model argument " `bq' "inputScenario: `name'" `bq' " SimPaths reads it in place" _n
file write `fh' "  of the baseline workbook: the population alignment follows it, and so does the fertility alignment, whose target" _n
file write `fh' "  is the age-0 count of both genders over women aged 18-49." _n
file write `fh' "- " `bq' "ramsey_migration.csv" `bq' ": the relative deviations " `bq' "N" `bq' " and " `bq' "P" `bq' " of the Ramsey planner's workers (ages 15-64)" _n
file write `fh' "  and population (all ages) from the baseline, one row per workbook year. Named in " `bq' "mm_ramseyScenario" `bq' "," _n
file write `fh' "  it gives the planner the scenario's paths from the start year on (foresight); without it the planner sees the" _n
file write `fh' "  arrivals only through the feedback from SimPaths (surprise). In a foresight run the feedback's reference year" _n
file write `fh' "  (" `bq' "mm_ramseyFeedbackReferenceYear" `bq' ", by default the year after the start year) must be `=`first_year' - 2' at the latest, two years" _n
file write `fh' "  before the first arrivals, so with the default the run must start in `=`first_year' - 3' at the latest: the planner refuses a" _n
file write `fh' "  non-zero " `bq' "N" `bq' " or " `bq' "P" `bq' " from the start year through the year after the reference year." _n
file write `fh' "- " `bq' "ramsey_migration_workers.csv" `bq' ", when present: the same file with " `bq' "N" `bq' " replaced by the deviation of SimPaths' workers," _n
file write `fh' "  built by " `bq' "input_processing/scenarios/build_ramsey_workers_path.do" `bq' " from two runs with the macro layer off, one on" _n
file write `fh' "  the baseline inputs and one with this scenario. The planner's " `bq' "N" `bq' " is workers; the population aged 15-64 stands in" _n
file write `fh' "  for them in " `bq' "ramsey_migration.csv" `bq' ", which needs no SimPaths run, and arrivals who work more or less often than" _n
file write `fh' "  the average person aged 15-64 then reach the planner as a surprise through the feedback. A foresight run names" _n
file write `fh' "  this file. Rebuild it after rebuilding the folder or after a change to SimPaths' labour supply." _n _n
file write `fh' "The workbook and " `bq' "ramsey_migration.csv" `bq' " come from one run of " `bq' "input_processing/scenarios/build_migration_scenario.do" `bq' ". Rebuild them together," _n
file write `fh' "by rerunning the do-file, whenever the baseline workbook, the Eurostat extract or a parameter changes: the CSV is" _n
file write `fh' "computed from this workbook." _n _n
file write `fh' "Every cell before `first_year' equals the baseline, so a run that starts before `first_year' shares the cached starting" _n
file write `fh' "population with the baseline runs, and " `bq' "N" `bq' " and " `bq' "P" `bq' " are exactly 0 up to `=`first_year' - 1'." _n _n
file write `fh' "## Parameters" _n _n
file write `fh' "| Parameter | Value |" _n
file write `fh' "|---|---|" _n
file write `fh' "| Country | `cc' |" _n
file write `fh' "| First arrival year | `first_year' |" _n
if `stops' file write `fh' "| Last arrival year | `last_arrival' |" _n
file write `fh' "| Arrivals a year | `arrivals' |" _n
file write `fh' "| Ages at arrival | `age_lo'-`age_hi', uniform |" _n
file write `fh' "| Share of women | `share_female' |" _n _n
file write `fh' "## Method" _n _n
file write `fh' "- Arrivals of year t count in column t. Each gender and age gets arrivals x share of the gender / number of ages," _n
file write `fh' "  spread over regions in proportion to the baseline population of that gender-age-region cell in t." _n
file write `fh' "- The migrant stock (arrivals and their descendants) ages one year a year. Survival from age a in t to a+1 in" _n
file write `fh' "  t+1 is min(1, pop(g, a+1, t+1) / pop(g, a, t)) from the baseline workbook summed over regions, and 1 below age" _n
file write `fh' "  50, where these ratios mostly reflect the baseline's own migration. The open age group `maxage' keeps 0.7 of itself" _n
file write `fh' "  plus the survivors from `=`maxage' - 1'." _n
if `last_wb' > `ext_last' local rates_note "the rates of `ext_last' for later years"
else local rates_note "the extract runs to `ext_last'"
file write `fh' "- Births during t: migrant women of each age 15-49 have Eurostat's projected age-specific fertility rate of year t" _n
file write `fh' "  (baseline variant; `rates_note'). Half of the births are boys; they enter age 0 in t+1 in the mother's" _n
file write `fh' "  region." _n
file write `fh' "- Scenario workbook = baseline + migrant stock, cell by cell." _n
file write `fh' "- " `bq' "N = WAP_scenario / WAP_baseline - 1" `bq' " (ages 15-64) and " `bq' "P = TOT_scenario / TOT_baseline - 1" `bq' " (all ages)," _n
file write `fh' "  summed over genders and regions: the definitions of " `bq' "input_processing/macromodel/build_population_projection.m" `bq' "," _n
file write `fh' "  so the planner's scenario paths are the ones a re-export with this workbook would build." _n
* the fertility target: written when the arrivals add women aged 18-49 in the first arrival year
quietly summarize fert_pct if year == `first_year'
local fert_gap1 = r(mean)
if `fert_gap1' < 0 {
    local s_gap1 = strtrim(string(-`fert_gap1', "%5.2f"))
    file write `fh' _n "## Fertility target" _n _n
    file write `fh' "SimPaths' fertility alignment compares the births of the women present at its fertility step with a target from" _n
    file write `fh' "this workbook: the age-0 count of both genders over women aged 18-49" _n
    file write `fh' "(" `bq' "Parameters.calculateFertilityRatesFromProjections" `bq' "). Column t counts the arrivals of year t among those women," _n
    file write `fh' "but SimPaths adds them only in its population alignment, which runs after the fertility step of year t" _n
    file write `fh' "(" `bq' "SimPathsModel.buildSchedule" `bq' "). The target's denominator therefore holds each year's arrivals, whom SimPaths" _n
    file write `fh' "does not have at the fertility step, and the target lies below the one that would leave SimPaths' age-specific" _n
    file write `fh' "fertility unchanged." _n _n
    file write `fh' "- Size: in `first_year' the target is `s_gap1'% below that consistent target. This value is exact: no migrant has" _n
    file write `fh' "  given birth yet, so the consistent target is the baseline's." _n
    if "`cc'" == "PL" & `first_year' == 2030 & `arrivals' == 200000 & `age_lo' == 20 & `age_hi' == 34 & `share_female' == 0.5 & !`stops' {
        file write `fh' "  In the later years it is about 1.3-1.6% below up to the late 2030s and about 0.75% below in 2040. These values" _n
        file write `fh' "  are estimates: from the second year on, the consistent target depends on the births of earlier arrivals in" _n
        file write `fh' "  SimPaths, which the workbook does not fix exactly." _n
    }
    else {
        file write `fh' "  Its size in the later years is not estimated for these parameters." _n
    }
    file write `fh' "- Fertility alignment runs to " `bq' "Parameters.FERTILITY_ALIGNMENT_END_YEAR" `bq' " (2040) and keeps that year's adjustment" _n
    file write `fh' "  afterwards, so the bias of 2040 carries forward to every later year." _n
    file write `fh' "- Population alignment brings every age-0 cell to the workbook's count, so age-0 totals still follow the workbook:" _n
    file write `fh' "  the bias moves only how the births split between the fertility of SimPaths' women, natives included, and the" _n
    file write `fh' "  age-0 persons the population alignment adds." _n
    file write `fh' "- Counting the migrants' births in their own year would bias the target upward by a similar amount. The births" _n
    file write `fh' "  enter age 0 in t+1 because SimPaths adds the arrivals of year t at the end of t, so their first births in" _n
    file write `fh' "  SimPaths fall in t+1. The bias comes from the target formula, not from this timing." _n
}
file write `fh' _n "## Sources" _n _n
file write `fh' "- Baseline population: " `bq' "input/`cc'/align_popProjections.xlsx" `bq' ", sheet " `bq' "Population_projections" `bq' "." _n
file write `fh' "- Fertility: Eurostat " `bq' "proj_23naasfr" `bq' ", projection " `bq' "BSL" `bq' ", single ages 15-49, years `ext_first'-`ext_last'; local copy" _n
file write `fh' "  " `bq' "input_processing/scenarios/eurostat_proj_23naasfr_`cc'.csv" `bq' ", described in " `bq' "input_processing/scenarios/eurostat_extracts.md" `bq' "." _n _n
file write `fh' "## Checks passed when this folder was built" _n _n
file write `fh' "- Every cell before `first_year' equals the baseline; " `bq' "N" `bq' " and " `bq' "P" `bq' " are exactly 0 there." _n
file write `fh' "- " `bq' "N" `bq' " and " `bq' "P" `bq' " recomputed from the written workbook equal the CSV within 1e-12." _n
if `arrivals' == 0 {
    file write `fh' "- Arrivals are 0: every cell equals the baseline, and every " `bq' "N" `bq' " and " `bq' "P" `bq' " is 0." _n
}
file write `fh' _n "## Selected years" _n _n
file write `fh' "`migrant_line'." _n _n
file write `fh' "| Year | N | P | Total / 15-64, baseline | Total / 15-64, scenario | Fertility target, baseline | Fertility target, scenario |" _n
file write `fh' "|---|---|---|---|---|---|---|" _n
forvalues i = 1/`=_N' {
    local y = year[`i']
    local in_table : list y in tyears
    if `in_table' {
        file write `fh' "| `y' | " %7.4f (N[`i']) " | " %7.4f (P[`i']) " | " %6.4f (dep_b[`i']) " | " %6.4f (dep_s[`i']) " | " %7.5f (fert_b[`i']) " | " %7.5f (fert_s[`i']) " |" _n
    }
}
file write `fh' _n "Built on `today' from the repository root with" _n _n
file write `fh' "    Start-Process StataMP-64.exe -ArgumentList '/e','do','input_processing/scenarios/build_migration_scenario.do','`cc'','`name'','`first_year'','`arrivals'','`age_lo'','`age_hi'','`share_female''`stop_arg' -Wait" _n
file close `fh'

di as result _n "Scenario `name' built in `outdir'"
