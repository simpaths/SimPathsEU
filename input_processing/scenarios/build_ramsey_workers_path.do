/*******************************************************************************
* PROJECT:        SimPaths EU
* SECTION:        INPUT SCENARIOS
*
* COUNTRY:        any country with a scenario folder built by
*                 build_migration_scenario.do
*
* DATA:           csv/Person.csv of two collected SimPaths runs with the macro
*                 layer off (mm_macroModel: off), same seeds, same years:
*                 one on the baseline inputs, one with inputScenario: <name>
*                 input/<CC>/scenarios/<name>/ramsey_migration.csv (for P)
*
* DESCRIPTION:    Writes input/<CC>/scenarios/<name>/ramsey_migration_workers.csv,
*                 a Ramsey scenario file whose N is the deviation of SimPaths'
*                 workers that the scenario produces, in place of the deviation
*                 of the population aged 15-64 that ramsey_migration.csv holds.
*                 P is copied from ramsey_migration.csv.
*
*                 Why: the planner's N is workers. ramsey_migration.csv scales
*                 it with the headcount aged 15-64, which is all that is known
*                 without running SimPaths. Arrivals who work more or less
*                 often than the average person aged 15-64 then reach the
*                 planner only through the yearly feedback, as a surprise. How
*                 an inflow turns into workers is decided inside SimPaths, so
*                 the only way to tell the planner in advance is to run SimPaths
*                 without the macro layer first and read the workers off.
*
*                 Method:
*                  - Workers of a run and year: persons aged 15-64 with positive
*                    weekly hours at the end of the year, the count the planner's
*                    feedback uses (LaborSupplyAggregator), summed over the
*                    seeds of the run folder.
*                  - N(t) = workers_scenario(t) / workers_baseline(t) - 1.
*                  - Years in which ramsey_migration.csv has N = 0 and P = 0
*                    (before the first arrivals) get N = 0. The two runs must
*                    agree exactly there, which holds for runs with the same
*                    seeds, since their inputs are identical up to that year;
*                    the do-file stops otherwise.
*                  - Years before the runs' first year get N = 0; the last
*                    simulated year's N persists in the planner beyond the file.
*
* USAGE:          From the repository root, in PowerShell (Git Bash mangles /e):
*                   Start-Process <Stata>\StataMP-64.exe -ArgumentList '/e','do',
*                     'input_processing/scenarios/build_ramsey_workers_path.do',
*                     'PL','migration_200k','<baseline run>','<scenario run>' -Wait
*                 Arguments: cc name baseline_run scenario_run, the last two the
*                 collected output folders (holding csv/Person.csv). The batch
*                 log lands in the working directory under the name of the
*                 scenario run's folder.
*
* OUTPUT:         input/<CC>/scenarios/<name>/ramsey_migration_workers.csv
*                 Rebuild it whenever the scenario folder is rebuilt or SimPaths'
*                 labour supply changes: it describes one model version.
*
*******************************************************************************/

version 18
clear all
set type double
set more off

args cc name base_run scen_run

capture program drop fail
program define fail
    di as error `"build_ramsey_workers_path: `0'"'
    exit 198
end

foreach a in cc name base_run scen_run {
    if `"``a''"' == "" fail argument `a' is missing. Arguments: cc name baseline_run scenario_run
}
if !ustrregexm("`cc'", "^[A-Z]{2}$") fail cc must be a two-letter country code such as PL, got `cc'
local outdir "input/`cc'/scenarios/`name'"
local src    "`outdir'/ramsey_migration.csv"
local csv    "`outdir'/ramsey_migration_workers.csv"
capture confirm file "`src'"
if _rc fail `src' not found; build the scenario folder with build_migration_scenario.do first and run this do-file from the repository root
foreach r in base scen {
    local `r'_run = subinstr(`"``r'_run'"', "\", "/", .)
    capture confirm file `"``r'_run'/csv/Person.csv"'
    if _rc fail ``r'_run'/csv/Person.csv not found
}
local today : display %tdCCYY-NN-DD date(c(current_date), "DMY")


* --- 1. WORKERS OF THE TWO RUNS ---------------------------------------------- *

tempfile wk
foreach r in base scen {
    di as text _n "Reading ``r'_run'/csv/Person.csv ..."
    quietly import delimited using `"``r'_run'/csv/Person.csv"', clear varnames(1) case(preserve)
    confirm variable run time demAge labHrsWorkWeek
    keep run time demAge labHrsWorkWeek
    foreach v in demAge labHrsWorkWeek {
        capture confirm string variable `v'
        if !_rc quietly destring `v', replace force
    }
    gen int year = round(time)
    gen double workers_`r' = inrange(demAge, 15, 64) & labHrsWorkWeek > 0 & !missing(labHrsWorkWeek)
    quietly levelsof run
    local seeds_`r' : word count `r(levels)'
    collapse (sum) workers_`r', by(year)
    if "`r'" == "base" {
        quietly save `wk'
    }
    else {
        quietly merge 1:1 year using `wk'
        capture assert _merge == 3
        if _rc fail the two runs do not cover the same years
        drop _merge
        quietly save `wk', replace
    }
}
if `seeds_base' != `seeds_scen' fail the baseline run holds `seeds_base' seeds, the scenario run `seeds_scen'
sort year
local run_first = year[1]
local run_last = year[_N]
assert year == `run_first' + _n - 1
gen double N_runs = workers_scen / workers_base - 1
quietly save `wk', replace
di as text "Runs cover `run_first'-`run_last', `seeds_base' seed(s) each"


* --- 2. THE HEADCOUNT FILE: YEARS AND P -------------------------------------- *

import delimited using "`src'", clear varnames(nonames) stringcols(_all) delimiters(",") bindquote(nobind)
quietly drop if substr(strtrim(v1), 1, 1) == "#"
assert v1 == "year" & v2 == "N" & v3 == "P" in 1
quietly drop in 1
gen int year = real(v1)
gen double N_wap = real(v2)
rename v3 strP
gen double P = real(strP)
assert !missing(year, N_wap, P)
keep year N_wap P strP
quietly merge 1:1 year using `wk', keepusing(workers_base workers_scen N_runs)
capture assert _merge != 2
if _rc fail the runs cover years that `src' does not have
sort year
quietly summarize year if N_wap != 0 | P != 0
if r(N) == 0 fail `src' has no non-zero N or P
local first_dev = r(min)
if `run_last' < `first_dev' fail the runs end in `run_last', before the scenario's first deviation in `first_dev'

* before the first arrivals the two runs are one and the same
quietly summarize N_runs if year < `first_dev' & _merge == 3
if r(N) > 0 {
    if max(abs(r(min)), abs(r(max))) > 1e-12 {
        fail the runs differ before `first_dev', the scenario's first deviation (N between `r(min)' and `r(max)'): they must share seeds and all inputs up to that year
    }
}
gen double N = cond(year < `first_dev' | _merge == 1, 0, N_runs)
* years of the file after the runs' last year are left out: the last row persists in the planner
quietly drop if year > `run_last'
drop _merge


* --- 3. THE WORKERS FILE ------------------------------------------------------ *

gen str40 strN = strtrim(string(N, "%24.0g"))
quietly replace strN = "0" + strN if substr(strN, 1, 1) == "."
quietly replace strN = "-0" + substr(strN, 2, .) if substr(strN, 1, 2) == "-."
tempname fh
file open `fh' using "`csv'", write text replace
file write `fh' "# Ramsey scenario `name' (`cc'), workers version: relative deviations of the planner's workers N and population P (all ages) from the baseline" _n
file write `fh' "# N = SimPaths' workers (persons aged 15-64 with positive hours) in a run with inputScenario: `name' over a run on the baseline inputs, minus 1; both runs with the macro layer off, `seeds_base' seed(s), `run_first'-`run_last'" _n
file write `fh' "# P is copied from ramsey_migration.csv of this folder, whose N is the deviation of the population aged 15-64" _n
file write `fh' "# Built by input_processing/scenarios/build_ramsey_workers_path.do on `today'" _n
file write `fh' "# Rebuild after rebuilding this folder or after a change to SimPaths' labour supply: N describes one model version" _n
file write `fh' "year,N,P" _n
forvalues i = 1/`=_N' {
    local line = string(year[`i']) + "," + strN[`i'] + "," + strP[`i']
    file write `fh' "`line'" _n
}
file close `fh'

format N N_wap P %9.5f
format workers_base workers_scen %12.0fc
di as text _n "Workers and the two versions of N (N_wap: population aged 15-64, ramsey_migration.csv; N: SimPaths' workers)"
list year workers_base workers_scen N_wap N P if year >= `first_dev' - 1, noobs sep(0) abbreviate(14)
di as result _n "Wrote `csv'"
