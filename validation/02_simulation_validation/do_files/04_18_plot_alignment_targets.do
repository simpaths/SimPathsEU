/*******************************************************************************
* PROJECT:  		SimPaths EU
* SECTION:			Validation
* OBJECT: 			Alignment targets (refactored variable names)
* AUTHORS:			Ashley Burdett
* LAST UPDATE:		05/2026 (refactor)
* COUNTRY: 			Poland
********************************************************************************
* NOTES: 			Refactored to use the new SimPaths EU variable names from
*					AlignmentStatistics.csv (align* prefix).
*******************************************************************************/

* Ensure output folder exists
capture mkdir "$dir_output_files/alignment_targets"

/*******************************************************************************
* IMPORT & PREPARE DATA
*******************************************************************************/

import delimited "$dir_simulated_data/AlignmentStatistics.csv", ///
	clear varnames(1) case(preserve)

* Restrict sample years
keep if time <= ${max_year}

rename time year

* Drop row id (not needed)
capture drop id_AlignmentStatistics

save "$dir_data/alignment_targets_raw.dta", replace


********************************************************************************
* 1 : Simulated vs Target pairs
********************************************************************************

* Parallel lists: simulated var, target var, title, filename suffix
local sim_vars "alignDsblSimShare alignFertRateSim alignInSchoolSimShare alignRtrdSimShare alignPartnerSimShare alignEmpSimACFShare alignEmpSimACMShare alignEmpSimCouplesShare alignEmpSimFWithDepShare alignEmpSimMWithDepShare alignEmpSimSingleFShare alignEmpSimSingleMShare"

local tgt_vars "alignDsblTgtShare alignFertRateTarget alignInSchoolTgtShare alignRtrdTgtShare alignPartnerTargetShare alignEmpTgtACFShare alignEmpTgtACMShare alignEmpTgtCouplesShare alignEmpTgtFWithDepShare alignEmpTgtMWithDepShare alignEmpTgtSingleFShare alignEmpTgtSingleMShare"

local titles `" "Disability share" "Fertility rate" "In school share" "Retirement share" "Share cohabiting" "Employed share - adult children (female)" "Employed share - adult children (male)" "Employed share - couples" "Employed share - female with dependants" "Employed share - male with dependants" "Employed share - single females" "Employed share - single males" "'

local filenames "disability_share fertility_rate inschool_share retirement_share share_cohabiting employed_ACFemale employed_ACMale employed_couples employed_femaleWithDep employed_maleWithDep employed_singleFemales employed_singleMales"

local n : word count `sim_vars'

forvalues i = 1/`n' {

	local sim  : word `i' of `sim_vars'
	local tgt  : word `i' of `tgt_vars'
	local ttl  : word `i' of `titles'
	local fn   : word `i' of `filenames'

	use "$dir_data/alignment_targets_raw.dta", clear
	keep run year `sim' `tgt'

	* Collapse across runs: mean and sd for simulated and target
	collapse (mean) m_sim = `sim' m_tgt = `tgt' ///
			 (sd)   sd_sim = `sim' sd_tgt = `tgt' ///
			 , by(year)

	* Replace missing sd (single-run years) with 0 so bands still plot
	replace sd_sim = 0 if missing(sd_sim)
	replace sd_tgt = 0 if missing(sd_tgt)

	* Build 95% bands
	gen sim_h = m_sim + 1.96*sd_sim
	gen sim_l = m_sim - 1.96*sd_sim
	gen tgt_h = m_tgt + 1.96*sd_tgt
	gen tgt_l = m_tgt - 1.96*sd_tgt

	twoway (rarea sim_h sim_l year, ///
		sort color(green%20)) ///
	(line m_sim year, sort color(green) lpattern(solid)) ///
	(line m_tgt year, sort color(red) lpattern(dash)), ///
		title("`ttl'") ///
		xtitle("Year", size(small)) ///
		ytitle("Value", size(small)) ///
		graphregion(color(white)) ///
		xlabel(, labsize(small)) ///
		ylabel(, labsize(small)) ///
		legend(order(1 "Simulated" 3 "Target") ///
			position(6) rows(1) size(small)) ///
		note("Notes: Shaded area = mean +/- 1.96*sd across simulation runs.", ///
			size(vsmall))

	graph export ///
		"$dir_output_files/alignment_targets/validation_${country}_alignment_`fn'.jpg", ///
		replace width(2400) height(1350) quality(100)
}


********************************************************************************
* 2 : Adjustment factors (no target)
********************************************************************************

local adj_vars "alignDsblAdj alignFertAdj alignInSchoolAdj alignPartnerAdj alignRtrdAdj alignUtilAdjACF alignUtilAdjACM alignUtilAdjCouple alignUtilAdjFWithDep alignUtilAdjMWithDep alignUtilAdjSingleF alignUtilAdjSingleM"

local adj_titles `" "Disability adjustment factor" "Fertility adjustment factor" "In school adjustment factor" "Partnership adjustment factor" "Retirement adjustment factor" "Utility adjustment factor - adult children (female)" "Utility adjustment factor - adult children (male)" "Utility adjustment factor - couples" "Utility adjustment factor - female with dependants" "Utility adjustment factor - male with dependants" "Utility adjustment factor - single females" "Utility adjustment factor - single males" "'

local adj_filenames "adj_disability adj_fertility adj_inschool adj_partnership adj_retirement adj_utility_ACFemale adj_utility_ACMale adj_utility_couples adj_utility_femaleWithDep adj_utility_maleWithDep adj_utility_singleFemales adj_utility_singleMales"

local na : word count `adj_vars'

forvalues i = 1/`na' {

	local v   : word `i' of `adj_vars'
	local ttl : word `i' of `adj_titles'
	local fn  : word `i' of `adj_filenames'

	use "$dir_data/alignment_targets_raw.dta", clear
	capture confirm variable `v'
	if _rc {
		display as txt "Variable `v' not found in data - skipping."
		continue
	}

	keep run year `v'

	collapse (mean) m_adj = `v' ///
			 (sd)   sd_adj = `v' ///
			 , by(year)

	replace sd_adj = 0 if missing(sd_adj)

	gen adj_h = m_adj + 1.96*sd_adj
	gen adj_l = m_adj - 1.96*sd_adj

	twoway (rarea adj_h adj_l year, ///
		sort color(blue%20)) ///
	(line m_adj year, sort color(blue) lpattern(solid)), ///
		yline(0, lcolor(black) lpattern(dot)) ///
		title("`ttl'") ///
		xtitle("Year", size(small)) ///
		ytitle("Adjustment factor", size(small)) ///
		graphregion(color(white)) ///
		xlabel(, labsize(small)) ///
		ylabel(, labsize(small)) ///
		legend(order(1 "Simulated") ///
			position(6) rows(1) size(small)) ///
		note("Notes: Shaded area = mean +/- 1.96*sd across simulation runs.", ///
			size(vsmall))

	graph export ///
		"$dir_output_files/alignment_targets/validation_${country}_`fn'.jpg", ///
		replace width(2400) height(1350) quality(100)
}

* Clean up
capture erase "$dir_data/alignment_targets_raw.dta"

graph drop _all
