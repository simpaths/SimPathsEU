// 91_plot_targets_from_xlsx.do
// Plot ES alignment targets from Excel workbooks
//
// Authors:        Mariia Vartuzova (MV)
// Last update:    18/08/2026 (MV)
// Country:        ES (Spain)
//
// Reads disability, inSchool, partnered, retirement, and employment targets
// from the ES Excel target workbooks, plots them across time, and exports
// the graphs to the TargetsPlots directory.
//
// The workbooks read here are the ones produced by 01-05 in this folder and
// then copied to the country root.
//
// Inputs:
//   input/ES/alignment_targets_disability.xlsx
//   input/ES/alignment_targets_employment.xlsx
//   input/ES/alignment_targets_inSchool.xlsx
//   input/ES/alignment_targets_partnered_share.xlsx
//   input/ES/alignment_targets_retirement.xlsx
//
// Outputs:
//   input/ES/DoFilesTargets/TargetsPlots/*.png
//   input/ES/DoFilesTargets/TargetsPlots/*.gph

clear all
set more off

// Directories
global dir_w   "~/IdeaProjects/SimPathsEU_AUG"
global dir_in  "${dir_w}/input/ES"
global dir_out "${dir_w}/input/ES/DoFilesTargets/TargetsPlots"

capture mkdir "${dir_out}"

set scheme s1color


// ============================================================================
// 1. DISABILITY
// ============================================================================

import excel using "${dir_in}/alignment_targets_disability.xlsx", ///
    sheet("disability") firstrow clear

destring year disabled_share, replace force
keep year disabled_share
sort year
gen pct = 100 * disabled_share

twoway (connected pct year, sort ///
        lcolor(navy) mcolor(navy) lwidth(medthick) msymbol(O) msize(small)), ///
    title("Disability Targets - ES") xtitle("Year") ytitle("Share (%)") ///
    ylabel(, angle(horizontal)) xlabel(, angle(45)) ///
    legend(off) graphregion(color(white))

graph export "${dir_out}/alignment_targets_disability_ts.png", as(png) replace
graph save   "${dir_out}/alignment_targets_disability_ts.gph", replace


// ============================================================================
// 2. IN-SCHOOL
// ============================================================================

import excel using "${dir_in}/alignment_targets_inSchool.xlsx", ///
    sheet("students") firstrow clear

destring year student_share, replace force
keep year student_share
sort year
gen pct = 100 * student_share

twoway (connected pct year, sort ///
        lcolor(teal) mcolor(teal) lwidth(medthick) msymbol(O) msize(small)), ///
    title("In-School Targets - ES") xtitle("Year") ytitle("Share (%)") ///
    ylabel(, angle(horizontal)) xlabel(, angle(45)) ///
    legend(off) graphregion(color(white))

graph export "${dir_out}/alignment_targets_inSchool_ts.png", as(png) replace
graph save   "${dir_out}/alignment_targets_inSchool_ts.gph", replace


// ============================================================================
// 3. PARTNERSHIP
// ============================================================================

import excel using "${dir_in}/alignment_targets_partnered_share.xlsx", ///
    sheet("partnered") firstrow clear

destring year partnered_share, replace force
keep year partnered_share
sort year
gen pct = 100 * partnered_share

twoway (connected pct year, sort ///
        lcolor(green) mcolor(green) lwidth(medthick) msymbol(O) msize(small)), ///
    title("Partnership Targets (BU Logic) - ES") xtitle("Year") ytitle("Share (%)") ///
    ylabel(, angle(horizontal)) xlabel(, angle(45)) ///
    legend(off) graphregion(color(white))

graph export "${dir_out}/alignment_targets_partnered_share_ts.png", as(png) replace
graph save   "${dir_out}/alignment_targets_partnered_share_ts.gph", replace


// ============================================================================
// 4. RETIREMENT
// ============================================================================

import excel using "${dir_in}/alignment_targets_retirement.xlsx", ///
    sheet("retirement") firstrow clear

destring year retired_share, replace force
keep year retired_share
sort year
gen pct = 100 * retired_share

twoway (connected pct year, sort ///
        lcolor(maroon) mcolor(maroon) lwidth(medthick) msymbol(O) msize(small)), ///
    title("Retirement Targets - ES") xtitle("Year") ytitle("Share (%)") ///
    ylabel(, angle(horizontal)) xlabel(, angle(45)) ///
    legend(off) graphregion(color(white))

graph export "${dir_out}/alignment_targets_retirement_ts.png", as(png) replace
graph save   "${dir_out}/alignment_targets_retirement_ts.gph", replace


// ============================================================================
// 5. EMPLOYMENT (all subgroups on one plot)
// ============================================================================

// Initialise the tempfile from the first sheet (Couples) — no emptyok
import excel using "${dir_in}/alignment_targets_employment.xlsx", ///
    sheet("Couples") firstrow clear
destring year empl_share, replace force
keep year empl_share
gen subgroup = "Couples"
tempfile empl_all
save `empl_all', replace

// Append SingleAC_Females
import excel using "${dir_in}/alignment_targets_employment.xlsx", ///
    sheet("SingleAC_Females") firstrow clear
destring year empl_share, replace force
keep year empl_share
gen subgroup = "SingleAC_Females"
append using `empl_all'
save `empl_all', replace

// Append SingleAC_Males
import excel using "${dir_in}/alignment_targets_employment.xlsx", ///
    sheet("SingleAC_Males") firstrow clear
destring year empl_share, replace force
keep year empl_share
gen subgroup = "SingleAC_Males"
append using `empl_all'
save `empl_all', replace

// Append SingleDep_Females
import excel using "${dir_in}/alignment_targets_employment.xlsx", ///
    sheet("SingleDep_Females") firstrow clear
destring year empl_share, replace force
keep year empl_share
gen subgroup = "SingleDep_Females"
append using `empl_all'
save `empl_all', replace

// Append SingleDep_Males
import excel using "${dir_in}/alignment_targets_employment.xlsx", ///
    sheet("SingleDep_Males") firstrow clear
destring year empl_share, replace force
keep year empl_share
gen subgroup = "SingleDep_Males"
append using `empl_all'
save `empl_all', replace

// Append Single_female
import excel using "${dir_in}/alignment_targets_employment.xlsx", ///
    sheet("Single_female") firstrow clear
destring year empl_share, replace force
keep year empl_share
gen subgroup = "Single_female"
append using `empl_all'
save `empl_all', replace

// Append Single_male
import excel using "${dir_in}/alignment_targets_employment.xlsx", ///
    sheet("Single_male") firstrow clear
destring year empl_share, replace force
keep year empl_share
gen subgroup = "Single_male"
append using `empl_all'
save `empl_all', replace

// Load combined dataset and convert to percentage
use `empl_all', clear
replace empl_share = 100 * empl_share
sort subgroup year

twoway ///
    (line empl_share year if subgroup == "Couples",          sort lcolor(navy)   lwidth(medthick)) ///
    (line empl_share year if subgroup == "SingleAC_Females", sort lcolor(maroon) lwidth(medthick)) ///
    (line empl_share year if subgroup == "SingleAC_Males",   sort lcolor(green)  lwidth(medthick)) ///
    (line empl_share year if subgroup == "SingleDep_Females",sort lcolor(red)    lwidth(medthick)) ///
    (line empl_share year if subgroup == "SingleDep_Males",  sort lcolor(orange) lwidth(medthick)) ///
    (line empl_share year if subgroup == "Single_female",    sort lcolor(teal)   lwidth(medthick)) ///
    (line empl_share year if subgroup == "Single_male",      sort lcolor(gs6)    lwidth(medthick)), ///
    title("Employment Targets - ES") xtitle("Year") ytitle("Employment share (%)") ///
    ylabel(, angle(horizontal)) xlabel(, angle(45)) ///
    legend(order(1 "Couples" 2 "SingleAC_Females" 3 "SingleAC_Males" ///
                 4 "SingleDep_Females" 5 "SingleDep_Males" ///
                 6 "Single_female" 7 "Single_male") cols(2) size(small)) ///
    graphregion(color(white))

graph export "${dir_out}/alignment_targets_employment_ts.png", as(png) replace
graph save   "${dir_out}/alignment_targets_employment_ts.gph", replace

display "All target plots saved to: ${dir_out}"
