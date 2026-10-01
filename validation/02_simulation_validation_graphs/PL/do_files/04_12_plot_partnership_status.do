********************************************************************************
* PROJECT:  		SimPaths EU
* SECTION:			Validation
* OBJECT: 			Partnership
* AUTHORS:			Ashley Burdett 
* LAST UPDATE:		Jan 2026
* COUNTRY: 			PL
********************************************************************************
* NOTES: 			
********************************************************************************

********************************************************************************
* 1 : Mean values over time
********************************************************************************

********************************************************************************
* 1.1 : Mean values over time - ages 18-65
********************************************************************************

* Prepare validation data
use year demAge dwt valid_partnered valid_single  using ///
	"$dir_data/${country}-eusilc_validation_sample.dta", clear

keep if inrange(demAge,18,65)	
	
* Compute shares	
collapse (mean) valid_partnered valid_single [aw = dwt], by(year)

save "$dir_data/temp_valid_stats.dta", replace


* Prepare SimPaths data
use run year demAge sim_partnered sim_single using ///
	"$dir_data/simulation_sample.dta", clear

keep if inrange(demAge,18,65)	
	
* Compute shares and sd
collapse (mean) sim_partnered sim_single    ///
	, by(run year)
	
collapse (mean) sim_partnered sim_single  ///
		 (sd) sim_partnered_sd = sim_partnered ///
		 sim_single_sd = sim_single ///
		 , by(year)
	
* Approx 95% confidence interval 	
foreach varname in sim_partnered sim_single  {
	
	gen `varname'_high = `varname' + 1.96*`varname'_sd
	gen `varname'_low = `varname' - 1.96*`varname'_sd

}

* Combine datasets
merge 1:1 year using "$dir_data/temp_valid_stats.dta", keep(3) nogen


* Plot figures 
* Share partnered
twoway (rarea sim_partnered_high sim_partnered_low year, sort color(green%20) ///
	legend(label(1 "SimPaths"))) ///
(line valid_partnered year, sort color(green) ///
	legend(label(2 "SILC "))), ///
	title("Partnered") ///
	subtitle("Ages 18-65") ///
	xtitle("Year", size(small)) ///
	ytitle("Share", size(small)) ///
	xlabel(,labsize(small)) ///
	ylabel(0[0.1]0.9, labsize(small)) ///
	legend(size(small)) ///	
	graphregion(color(white)) ///
	note("Notes: ", size(vsmall))	

* Save figure
graph export ///
"$dir_output_files/partnership/validation_${country}_partnered_ts_18_65_both.jpg", ///
	replace width(2400) height(1350) quality(100)

* Partnership status shares	
twoway (rarea sim_partnered_high sim_partnered_low year, sort color(green%20) ///
	legend(label(1 "Partnered, SimPaths"))) ///
(line valid_partnered year, sort color(green) ///
	legend(label(2 "Partnered, SILC "))) ///
(rarea sim_single_high sim_single_low year, sort color(red%20) ///
	legend(label(3 "Single, SimPaths"))) ///
(line valid_single year, sort color(red) ///
	legend(label(4 "Single, SILC "))), ///
	title("Partnership status") ///
	subtitle("Ages 18-65") ///
	xtitle("Year", size(small)) ///
	ytitle("Share", size(small)) ///
	xlabel(,labsize(small)) ///
	ylabel(0[0.1]0.8, labsize(small)) ///
	legend(size(small)) ///	
	graphregion(color(white)) ///
	note("Notes: ", size(vsmall))	

graph export ///
"$dir_output_files/partnership/validation_${country}_partnership_ts_18_65_both.jpg", ///
	replace width(2400) height(1350) quality(100)	
	
	
********************************************************************************
* 1.2 : Mean values over time - by age group 
********************************************************************************

* Define the groupings using a semi-colon or a specific delimiter
local age_cond1 "ageGroup == 2 | ageGroup == 3"
local age_sub1  "Ages 20-29"
local age_suff1 "20_29"

local age_cond2 "ageGroup == 4 | ageGroup == 5"
local age_sub2  "Ages 30-39"
local age_suff2 "30_39"

local age_cond3 "ageGroup == 6"
local age_sub3  "Ages 40-59"
local age_suff3 "40_59"

* Loop through the 3 groups
forvalues i = 1/3 {
    
   * Validation data 
    use year demAge dwt valid_partnered valid_single ageGroup using ///
        "$dir_data/${country}-eusilc_validation_sample.dta", clear
	
	* Select sample 
    keep if `age_cond`i''
    
    collapse (mean) valid_partnered valid_single [aw = dwt], by(year)
    tempfile valid_stats
    save `valid_stats'

    * Simuated data 
    use run year demAge sim_partnered sim_single ageGroup using ///
        "$dir_data/simulation_sample.dta", clear

	* Select sample	
    keep if `age_cond`i''
    
    collapse (mean) sim_partnered sim_single, by(run year)
    
    collapse (mean) sim_partnered sim_single ///
             (sd)   sim_partnered_sd = sim_partnered ///
                    sim_single_sd    = sim_single, by(year)
            
    foreach varname in sim_partnered sim_single {
	
        gen `varname'_high = `varname' + 1.96*`varname'_sd
        gen `varname'_low  = `varname' - 1.96*`varname'_sd
    
	}

    * Combine
    merge 1:1 year using `valid_stats', keep(3) nogen

    twoway (rarea sim_partnered_high sim_partnered_low year, sort color(green%20) ///
        legend(label(1 "Partnered, SimPaths"))) ///
    (line valid_partnered year, sort color(green) ///
        legend(label(2 "Partnered, SILC"))) ///
    (rarea sim_single_high sim_single_low year, sort color(red%20) ///
        legend(label(3 "Single, SimPaths"))) ///
    (line valid_single year, sort color(red) ///
        legend(label(4 "Single, SILC"))), ///
        title("Partnership status") ///
        subtitle("`age_sub`i''") ///
        xtitle("Year", size(small)) ///
        ytitle("Share", size(small)) ///
        xlabel(, labsize(small)) ///
        ylabel(0(0.2)1, labsize(small)) ///
        legend(size(small)) ///    
        graphregion(color(white)) ///
        note("Notes: ", size(vsmall))    
        
    graph export ///
    "$dir_output_files/partnership/validation_${country}_partnership_ts_`age_suff`i''_both.jpg", ///
        replace width(2400) height(1350) quality(100)    
		
}

graph drop _all 


********************************************************************************
* 1.3 : Mean values over time - by children 
********************************************************************************	

* Load validation data
use year demAge dwt valid_partnered_children_0 valid_partnered_children_1 ///
	valid_partnered_children_2 valid_partnered_children_3plus ///
	valid_single_children_0 valid_single_children_1 ///
	valid_single_children_2 valid_single_children_3plus  using ///
	"$dir_data/${country}-eusilc_validation_sample.dta", clear

collapse (mean) valid_partnered_children_0 valid_partnered_children_1 ///
	 valid_partnered_children_2 valid_partnered_children_3plus ///
	 valid_single_children_0 valid_single_children_1 ///
	 valid_single_children_2 valid_single_children_3plus ///
	 [aw = dwt], by(year)

save "$dir_data/temp_valid_stats.dta", replace

* Load SimPaths data
use run year demAge sim_partnered_children_0 sim_partnered_children_1 ///
	sim_partnered_children_2 sim_partnered_children_3plus ///
	sim_single_children_0 sim_single_children_1 sim_single_children_2 ///
	sim_single_children_3plus ///
	using "$dir_data/simulation_sample.dta", clear

* Compute shares and sd	
collapse (mean) sim_partnered_children_0 sim_partnered_children_1 ///
	sim_partnered_children_2 sim_partnered_children_3plus ///
	sim_single_children_0 sim_single_children_1 ///
	sim_single_children_2 sim_single_children_3plus, ///
	by(run year)
	
collapse (mean) sim_partnered_children_0 sim_partnered_children_1 ///
	 sim_partnered_children_2 sim_partnered_children_3plus ///
	 sim_single_children_0 sim_single_children_1 sim_single_children_2 ///
	 sim_single_children_3plus ///
	(sd) sim_partnered_children_0_sd = sim_partnered_children_0 ///
		sim_partnered_children_1_sd = sim_partnered_children_1 ///
		sim_partnered_children_2_sd = sim_partnered_children_2 ///
		sim_partnered_children_3plus_sd = sim_partnered_children_3plus ///
		sim_single_children_0_sd = sim_single_children_0 ///
		sim_single_children_1_sd = sim_single_children_1 ///
		sim_single_children_2_sd = sim_single_children_2 ///
		sim_single_children_3plus_sd = sim_single_children_3plus ///
		, by(year)
		 
* Approx 95% confidence interval 		 
foreach varname in sim_partnered_children_0 sim_partnered_children_1 ///
	sim_partnered_children_2 sim_partnered_children_3plus sim_single_children_0 ///
	sim_single_children_1 sim_single_children_2 sim_single_children_3plus  {
	
	gen `varname'_h = `varname' + 1.96*`varname'_sd
	gen `varname'_l = `varname' - 1.96*`varname'_sd
	
}

* Combine datasets
merge 1:1 year using "$dir_data/temp_valid_stats.dta", keep(3) nogen

* Label variables
label var sim_partnered_children_0 "No children"
label var sim_partnered_children_1 "1 child"
label var sim_partnered_children_2 "2 children"
label var sim_partnered_children_3plus "3+ children"
label var sim_single_children_0 "No children"
label var sim_single_children_1 "1 child"
label var sim_single_children_2 "2 children"
label var sim_single_children_3plus "3+ children"

* Plot figures

* Partnered 
foreach varname in partnered_children_0 partnered_children_1 ///
	partnered_children_2 partnered_children_3plus {
	
	local vtext : variable label sim_`varname'
	if `"`vtext'"' == "" local vtext "sim_`varname'" 
	twoway (rarea sim_`varname'_h sim_`varname'_l year, sort color(red%20) ///
		legend(label(1 "SimPaths") position(6) rows(1))) ///
	(line valid_`varname' year, sort color(red) ///
		legend(label(2 "SILC"))), ///
		subtitle("`vtext'") ///
		name(`varname', replace) ///
		ytitle("Share", size(small)) ///
		xtitle("") ///
		ylabel(0[0.1]0.5,labsize(vsmall)) ///
		xlabel(,labsize(vsmall)) ///
		legend(size(small)) ///
		graphregion(color(white)) 

}

* Combine plots
grc1leg partnered_children_0 partnered_children_1 partnered_children_2 ///
	partnered_children_3plus , ///
	title("Share Partnered and Number of Children") ///
	legendfrom(partnered_children_0) ///
	rows(2) ///
	graphregion(color(white)) ///
	ycomm ///
	note("Notes: Samples contains all individual ages 18-65. ", size(vsmall)) 
	
graph export ///
"$dir_output_files/partnership/validation_${country}_partnership_children_ts_18_65_partnered.jpg", ///
	replace width(2400) height(1350) quality(100)
	
	
* Single	
foreach varname in single_children_0 single_children_1 single_children_2 ///
	single_children_3plus {
	
	local vtext : variable label sim_`varname'
	if `"`vtext'"' == "" local vtext "sim_`varname'" 
	twoway (rarea sim_`varname'_h sim_`varname'_l year, sort color(red%20) ///
		legend(label(1 "SimPaths") position(6) rows(1))) ///
	(line valid_`varname' year, sort color(red) ///
		legend(label(2 "SILC"))), ///
		subtitle("`vtext'") ///
		name(`varname', replace) ///
		ytitle("Share", size(small)) ///
		xtitle("") ///
		ylabel(0[0.1]0.5,labsize(vsmall)) ///
		xlabel(,labsize(vsmall)) ///
		legend(size(small)) ///
		graphregion(color(white)) 

}

* Combine plots
grc1leg single_children_0 single_children_1 single_children_2 ///
	single_children_3plus , ///
	title("Share Single and Number of Children") ///
	legendfrom(single_children_0) ///
	rows(2) ///
	graphregion(color(white)) ///
	ycomm ///
	note("Notes: Samples contains all individual ages 18-65. ", size(vsmall)) 
	
graph export ///
"$dir_output_files/partnership/validation_${country}_partnership_children_ts_18_65_single.jpg", ///
	replace width(2400) height(1350) quality(100)	
	
	

	
*** Investigate transitions 

** At risk 
* Into partnership 

use idPers year dwt valid_partnered valid_single demAge using ///
	"$dir_data/${country}-eusilc_validation_sample.dta", clear
	
keep if demAge > 17 	
keep if demAge < 66 	

sort idPers year 
gen form_rel = 0 if valid_partnered[_n-1] == 0 & idPers == idPers[_n-1]
replace form_rel = 1 if valid_partnered == 1  & form_rel == 0 
 
drop if form_rel == . 
	
collapse (mean) form_rel  [aw = dwt], by(year)

save "$dir_data/temp_valid_stats.dta", replace

* Prepare simulated data
use idPers run year demAge sim_partnered sim_single using ///
	"$dir_data/simulation_sample.dta", clear
	
keep if demAge > 17 
keep if demAge < 66 	

sort run idPers year 

gen sim_form_rel = 0 if sim_partnered[_n-1] == 0 & idPers == idPers[_n-1]
replace sim_form_rel = 1 if sim_partnered == 1 & sim_form_rel == 0 
 
drop if sim_form_rel == . 
	

collapse (mean) sim_form_rel, by(run year)
	
collapse (mean) sim_form_rel ///
		 (sd) sim_form_rel_sd = sim_form_rel ///
		 , by(year)
		 
foreach varname in sim_form_rel {
	
	gen `varname'_high = `varname' + 1.96*`varname'_sd
	gen `varname'_low = `varname' - 1.96*`varname'_sd

}

merge 1:1 year using "$dir_data/temp_valid_stats.dta", keep(3) nogen

drop if year < 2012

* Plot figure
twoway (rarea sim_form_rel_high sim_form_rel_low year, sort color(green%20) ///
	legend(label(1 "Simulated"))) ///
(line form_rel year, sort color(green) ///
	legend(label(2 "SILC "))), ///
	title("Share of singles that form partnership") ///
	xtitle("Year", size(small)) ///
	ytitle("Share", size(small)) ///
	ylabel(, labsize(small)) ///
	xlabel(,labsize(small)) ///
	graphregion(color(white)) ///
	note("Notes: Sample contains all individual ages 18-65.", size(vsmall))	

graph export ///
"$dir_output_files/partnership/validation_${country}_into_partnership_ts_18_65_at_risk.jpg", ///
	replace width(2400) height(1350) quality(100)		
	
	
* Out of parnership 
use idPers year dwt valid_partnered valid_single demAge using ///
	"$dir_data/${country}-eusilc_validation_sample.dta", clear
	
keep if demAge > 17 	
keep if demAge < 66 	

sort idPers year 
gen exit_rel = 0 if valid_partnered[_n-1] == 1 & idPers == idPers[_n-1]
replace exit_rel = 1 if valid_partnered == 0  & exit_rel == 0 
 
drop if exit_rel == . 
	
collapse (mean) exit_rel  [aw = dwt], by(year)

save "$dir_data/temp_valid_stats.dta", replace

* Prepare simulated data
use idPers run year demAge sim_partnered sim_single using ///
	"$dir_data/simulation_sample.dta", clear
	
keep if demAge > 17 
keep if demAge < 66 

sort run idPers year 

gen sim_exit_rel = 0 if sim_partnered[_n-1] == 1 & idPers == idPers[_n-1]
replace sim_exit_rel = 1 if sim_partnered == 0 & sim_exit_rel == 0 
 
drop if sim_exit_rel == . 
	
collapse (mean) sim_exit_rel, by(run year)
	
collapse (mean) sim_exit_rel ///
		 (sd) sim_exit_rel_sd = sim_exit_rel ///
		 , by(year)
		 
foreach varname in sim_exit_rel {
	
	gen `varname'_high = `varname' + 1.96*`varname'_sd
	gen `varname'_low = `varname' - 1.96*`varname'_sd

}

merge 1:1 year using "$dir_data/temp_valid_stats.dta", keep(3) nogen

drop if year < 2012

* Plot figure
twoway (rarea sim_exit_rel_high sim_exit_rel_low year, sort color(green%20) ///
	legend(label(1 "Simulated"))) ///
(line exit_rel year, sort color(green) ///
	legend(label(2 "SILC "))), ///
	title("Share of partnered that exit partnership") ///
	xtitle("Year", size(small)) ///
	ytitle("Share", size(small)) ///
	ylabel(, labsize(small)) ///
	xlabel(,labsize(small)) ///
	graphregion(color(white)) ///
	note("Notes: Sample contains all individual ages 18-65.", size(vsmall))	
	
graph export ///
"$dir_output_files/partnership/validation_${country}_exit_partnership_ts_18_65_at_risk.jpg", ///
	replace width(2400) height(1350) quality(100)	

	
** Whole pop 
* Into partnership 

use idPers year dwt valid_partnered valid_single demAge using ///
	"$dir_data/${country}-eusilc_validation_sample.dta", clear
	
keep if demAge > 17 	
keep if demAge < 66 	

sort idPers year 

gen form_rel = 0 if valid_partnered[_n-1] == 0 & idPers == idPers[_n-1]
replace form_rel = 1 if valid_partnered == 1  & form_rel == 0 
replace form_rel = 0 if form_rel == . 

drop if idPers != idPers[_n-1] 
	
collapse (mean) form_rel  [aw = dwt], by(year)

save "$dir_data/temp_valid_stats.dta", replace

* Prepare simulated data
use idPers run year demAge sim_partnered sim_single using ///
	"$dir_data/simulation_sample.dta", clear
	
keep if demAge > 17 	
keep if demAge < 66 	

sort run idPers year 

gen sim_form_rel = 0 if sim_partnered[_n-1] == 0 & idPers == idPers[_n-1]
replace sim_form_rel = 1 if sim_partnered == 1 & sim_form_rel == 0 
replace sim_form_rel = 0 if sim_form_rel == . 

drop if idPers != idPers[_n-1] 

collapse (mean) sim_form_rel, by(run year)
	
collapse (mean) sim_form_rel ///
		 (sd) sim_form_rel_sd = sim_form_rel ///
		 , by(year)
		 
foreach varname in sim_form_rel {
	
	gen `varname'_high = `varname' + 1.96*`varname'_sd
	gen `varname'_low = `varname' - 1.96*`varname'_sd

}

merge 1:1 year using "$dir_data/temp_valid_stats.dta", keep(3) nogen

drop if year < 2012

* Plot figure
twoway (rarea sim_form_rel_high sim_form_rel_low year, sort color(green%20) ///
	legend(label(1 "Simulated"))) ///
(line form_rel year, sort color(green) ///
	legend(label(2 "SILC "))), ///
	title("Share of population that form partnership") ///
	xtitle("Year", size(small)) ///
	ytitle("Share", size(small)) ///
	ylabel(, labsize(small)) ///
	xlabel(,labsize(small)) ///
	graphregion(color(white)) ///
	note("Notes: Sample contains all individual ages 18-65.", size(vsmall))	

graph export ///
"$dir_output_files/partnership/validation_${country}_into_partnership_ts_18_65_all.jpg", ///
	replace width(2400) height(1350) quality(100)		
	
	
* Out of parnership 
use idPers year dwt valid_partnered valid_single demAge using ///
	"$dir_data/${country}-eusilc_validation_sample.dta", clear
	
keep if demAge > 17 	
keep if demAge < 66 	

sort idPers year 

gen exit_rel = 0 if valid_partnered[_n-1] == 1 & idPers == idPers[_n-1]
replace exit_rel = 1 if valid_partnered == 0  & exit_rel == 0 
replace exit_rel = 0 if exit_rel == . 
	
drop if idPers != idPers[_n-1] 	
	
collapse (mean) exit_rel  [aw = dwt], by(year)

save "$dir_data/temp_valid_stats.dta", replace

* Prepare simulated data
use idPers run year demAge sim_partnered sim_single using ///
	"$dir_data/simulation_sample.dta", clear
	
keep if demAge > 17 	
keep if demAge < 66 

sort run idPers year 

gen sim_exit_rel = 0 if sim_partnered[_n-1] == 1 & idPers == idPers[_n-1]
replace sim_exit_rel = 1 if sim_partnered == 0 & sim_exit_rel == 0 
replace sim_exit_rel = 0 if sim_exit_rel == . 
	
drop if idPers != idPers[_n-1] 	
	
collapse (mean) sim_exit_rel, by(run year)
	
collapse (mean) sim_exit_rel ///
		 (sd) sim_exit_rel_sd = sim_exit_rel ///
		 , by(year)
		 
foreach varname in sim_exit_rel {
	
	gen `varname'_high = `varname' + 1.96*`varname'_sd
	gen `varname'_low = `varname' - 1.96*`varname'_sd

}

merge 1:1 year using "$dir_data/temp_valid_stats.dta", keep(3) nogen

drop if year < 2012

* Plot figure
twoway (rarea sim_exit_rel_high sim_exit_rel_low year, sort color(green%20) ///
	legend(label(1 "Simulated"))) ///
(line exit_rel year, sort color(green) ///
	legend(label(2 "SILC "))), ///
	title("Share of population that exit partnership") ///
	xtitle("Year", size(small)) ///
	ytitle("Share", size(small)) ///
	ylabel(, labsize(small)) ///
	xlabel(,labsize(small)) ///
	graphregion(color(white)) ///
	note("Notes: Sample contains all individual ages 18-65.", size(vsmall))	
	
graph export ///
"$dir_output_files/partnership/validation_${country}_exit_partnership_ts_18_65_all.jpg", ///
	replace width(2400) height(1350) quality(100)	

	
graph drop _all	
		
	
	
	
	
