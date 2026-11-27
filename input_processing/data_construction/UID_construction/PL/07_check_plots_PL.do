/*******************************************************************************
* PROJECT:              SimPaths EU
* DO-FILE NAME:         07_check_PL.do
* DESCRIPTION:          Visual checks of selected SimPaths output series
* COUNTRY:              PL
* DATA:                 SimPaths simulation outputs
* AUTHORS:              Daria Popova, Ashley Burdett
* LAST UPDATE:          23 October 2026
********************************************************************************
* NOTES:
*
*   -----------------------------------------------------------------------
*    What this file does
*   -----------------------------------------------------------------------
*   This do-file produces plots of selected time series from the Italian
*   SimPaths model to visually inspect the simulation outputs.
*
*   The plots are used as preliminary sense checks to identify unexpected
*   trends, discontinuities, or implausible patterns that may warrant
*   further investigation.
*
*   These checks are intended for exploratory purposes and do not
*   constitute a formal validation exercise.
*
*******************************************************************************/
* Load data 
use "$dir_data/${country}_pooled_ipop.dta", clear


* Economic activity 
preserve 

keep if dag >= 18 & dag <= 65

gen valid_employed = (les_c4 == 1)
gen valid_student = (les_c4 == 2)
gen valid_inactive = (les_c4 == 3)
gen valid_retired = (les_c4 == 4)

replace valid_employed = . if les_c4 == -9 | les_c4 == . 
replace valid_student = . if les_c4 == -9 | les_c4 == . 
replace valid_inactive = . if les_c4 == -9 | les_c4 == . 
replace valid_retired = . if les_c4 == -9 | les_c4 == . 

collapse (mean) valid_employed valid_student valid_inactive valid_retired ///
	[aw = dwt], by(stm)
	
twoway ///
(line valid_employed stm, sort color(green) legend(label(1 "Employed, observed"))) ///
(line valid_student stm, sort color(blue) legend(label(2 "Students, observed"))) ///
(line valid_inactive stm, sort color(red) legend(label(3 "Inactive, observed"))) ///
(line valid_retired stm, sort color(grey) legend(label(4 "Retired, observed"))) ///
, title("Activity status") xtitle("stm") ytitle("Share") ///
legend(position(6))
	
restore	
	
* Partnership 
preserve 
	
keep if dag >= 18 & dag <= 65
	
gen valid_partnered = (dcpst == 1)	
	
collapse (mean) valid_partnered [aw = dwt], by(stm)

twoway ///
(line valid_partnered stm, sort color(green) legend(label(1 "Employed, observed"))) ///
, title("Partnership share") xtitle("stm") ytitle("Share") ylabel(0.5[0.1]0.7) ///
legend(position(6))
	
restore 

* Educational attainment 
preserve 	

keep if dag >= 18 & dag <= 65

gen valid_edu_high = (deh_c4 == 1)
gen valid_edu_med = (deh_c4 == 2)
gen valid_edu_low = (deh_c4 == 3)
gen valid_edu_na = (deh_c4 == 0)

replace valid_edu_high = . if deh_c4 == -9 
replace valid_edu_med = . if deh_c4 == -9 
replace valid_edu_low = . if deh_c4 == -9 
replace valid_edu_na = . if deh_c4 == -9 

collapse (mean) valid_edu_high valid_edu_med valid_edu_low valid_edu_na  ///
	[aw = dwt], by(stm)

twoway ///
(line valid_edu_high stm, sort color(green) legend(label(1 "High , observed"))) ///
(line valid_edu_med stm, sort color(blue) legend(label(2 "Medium, observed"))) ///
(line valid_edu_low stm, sort color(red) legend(label(3 "Low, observed"))) ///
(line valid_edu_na stm, sort color(orange) legend(label(4 "Na, observed"))) ///
, title("Educational attainment") xtitle("stm") ytitle("Share") ///
legend(position(6))
		
restore 
	
* Hours worked 
preserve 

keep if dag >= 18 & dag <= 65
keep if les_c3 == 1 

replace lhw = . if lhw == -9 

collapse (mean) lhw [aw = dwt], by(stm)

twoway ///
(line lhw stm, sort color(green) legend(label(1 "Observed"))), ///
	title("Hours worked") xtitle("stm") ytitle("Hours per week") ///
	ylabel(34 [2] 44) ///
	note("Note: Statistics calculated on sample of employed individuals")
	
restore 	

preserve

keep if dag >= 18 & dag <= 65
keep if les_c3 == 1 

replace lhw = . if lhw == -9 

twoway /// 
(hist lhw, color(red%20) ///
	legend(label(2 "Observed"))), ///
	title("Weekly hours worked") xtitle("Hours") ///
	ytitle("Density") ///
	note("Note: Statistics calculated on sample of employed individuals") 
	
restore 


* Hourly wage 
preserve 

keep if dag >= 18 & dag <= 65
keep if les_c3 == 1 

replace obs_earnings_hourly = . if obs_earnings_hourly == -9 

* Trim outliers 
sum obs_earnings_hourly, d
replace obs_earnings_hourly = . if ///
	obs_earnings_hourly < r(p1) | obs_earnings_hourly > r(p99)
	
collapse (mean) obs_earnings_hourly [aw = dwt], by(stm)
	
twoway ///
(line obs_earnings_hourly stm, sort color(green) ///
	legend(label(2 "Observed"))), ///
title("Mean hourly wages") xtitle("stm") ytitle("€ per hour (2015 prices)") ///
	note("Note: Statistics calculated on sample of employed individuals, trimmed")
		
restore 	


preserve 

keep if dag >= 18 & dag <= 65
keep if les_c3 == 1 

replace obs_earnings_hourly = . if obs_earnings_hourly == -9 

sum obs_earnings_hourly, d
replace obs_earnings_hourly = . if ///
	obs_earnings_hourly < r(p1) | obs_earnings_hourly > r(p99)

twoway /// 
(hist obs_earnings_hourly if obs_earnings_hourly, color(red%20) ///
	legend(label(2 "Observed"))), ///
	title("Hourly wages") xtitle("Wages") ///
	ytitle("Density") ///
	note("Note: Statistics calculated on sample of employed individuals, trimmed") 	
	
restore	


graph drop _all 
