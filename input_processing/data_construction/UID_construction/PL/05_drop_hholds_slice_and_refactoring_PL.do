/*******************************************************************************
* PROJECT:              SimPaths EU
* DO-FILE NAME:         05_drop_hhold_an_slice.do
* DESCRIPTION:          Creates the UID and nitial population files
* COUNTRY:              PL
* DATA:                 EU-SILC panel dataset
* AUTHORS:              Daria Popova, Ashley Burdett
* LAST UPDATE:          24 November 2026
********************************************************************************
* NOTES:
*
*   -----------------------------------------------------------------------
*    What this file does
*   -----------------------------------------------------------------------
*   This do-file performs the final processing required to create the initial
*   population file for import into SimPaths.
*
*   -----------------------------------------------------------------------
*    Sample selection
*   -----------------------------------------------------------------------
*   - Drops households identified for exclusion during the preceding data
*     construction and screening steps
*   - Selects the required cross-sectional year from the SILC panel
*
*   -----------------------------------------------------------------------
*    Final processing & save
*   -----------------------------------------------------------------------
*   - Retains and orders the variables required by SimPaths
*   - Recodes missing values to -9 where required
* 	- Renmaes variable to SimPaths naming convention 
*   - Saves the final initial population dataset for import into SimPaths
*
* TO DO:
*******************************************************************************/

cap log close 
//log using "${dir_log}/05_finalise_input_data.log", replace

use "$dir_data/${country}-SILC_pooled_all_obs_04.dta", clear


/****************************** LIMIT SAMPLE **********************************/

* If any person in the household has missing values, drop the whole household:
drop if dropHH == 1  	// 22,225 obs deleted 

drop dropObs dropHH 
	
* Drop if hh weight = 0:
count if dwt == 0 
drop if dwt == 0 // 19,271 obs

* Final check for same sex households
assert ssscp != 1 
assert dgn != dgnsp if idpartner > 0

* Final check for number of adults 
drop adult child  //drop old vars 
gen child = dag < ${age_becomes_responsible} 
gen adult = 1 - child 
bys stm idhh: egen adult_count = sum(adult)
bys stm idbenefitunit: egen adult_count2 = sum(adult)

/* 
There is one child that is in their mothers benefit unit but not their home for 
one year. Adjust here. This is not a general fix and should be updated for 
different countries. 
*/

bysort swv idbenefitunit (child): replace idhh = idhh[_n-1] if adult_count == 0 
drop adult_count adult_count2 adult child 
gen child = dag < ${age_becomes_responsible} 
gen adult = 1 - child 
bys stm idhh: egen adult_count = sum(adult)
bys stm idbenefitunit: egen adult_count2 = sum(adult)

assert adult_count >= 1 
assert adult_count2 >= 1 

* Final check for orphans 
assert (idfather > 0 | idmother > 0) if ///
	(dag > 0 & dag < ${age_becomes_responsible} )

* Check for duplicates in terms of stm and idperson
cap drop duplicate 
duplicates tag stm idperson , generate(duplicate)
assert duplicate == 0 

cap drop duplicate 
duplicates tag swv idperson , generate(duplicate)
assert duplicate == 0 

sort idperson swv 

//cf _all using "$dir_data/${country}_pooled_ipop_pre.dta"

save "$dir_data/${country}_pooled_ipop_pre.dta", replace 


/*************************** GENERATE FREQUENCY WEIGHTS ***********************/
/*
Total population figures for Poland from 2011 to 2024:
https://ec.europa.eu/eurostat/databrowser/view/demo_pjan/default/...
	table?lang=en&category=demo.demo_pop
*/
cap gen ${country}_pop = 0 
replace ${country}_pop = 38095352 if stm == 2010 
replace ${country}_pop = 38062718 if stm == 2011 
replace ${country}_pop = 38063792 if stm == 2012
replace ${country}_pop = 38062535 if stm == 2013
replace ${country}_pop = 38017856 if stm == 2014
replace ${country}_pop = 38005614 if stm == 2015
replace ${country}_pop = 37967209 if stm == 2016
replace ${country}_pop = 37972964 if stm == 2017 
replace ${country}_pop = 37976687 if stm == 2018
replace ${country}_pop = 37972812 if stm == 2019
replace ${country}_pop = 37958138 if stm == 2020
replace ${country}_pop = 37073357 if stm == 2021
replace ${country}_pop = 37073357 if stm == 2022
replace ${country}_pop = 36753736 if stm == 2023
replace ${country}_pop = 367620970 if stm == 2024


cap drop surv_pop
bys stm: egen surv_pop = total(dwt_adjusted)
bys stm: sum surv_pop

cap drop multiplier
gen multiplier = ${country}_pop / surv_pop 

cap gen dwtfq = round(dwt * multiplier)  
	// rounding causes some slight difference across runs
	
//cap drop dwt_sampling
//rename dwt dwt_sampling
replace dwt = dwtfq 
bys stm: sum dwt*

preserve 
	
	collapse (sum) dwt, by(stm)

restore

sort idperson swv 
	
	
/********************** UPDATE SAMPLE LEVEL VARIABLES *************************/

* Benefit unit income quintiles
/*
Income quintiles are constructed separately by survey year using the weighted
distribution of equivalised benefit unit gross non-benefit income among 
non-dependent individuals.

A common random jitter is assigned to all members of each benefit unit to break 
income ties without separating partners across quintiles.

Dependent children are assigned the income quintile of their benefit unit but 
do not contribute to the reference distribution.

Note: The reference distribution is individual-weighted rather than
benefit-unit-weighted. Will be reviewed in future development.
*/

* Add spouse's gross real monthly personal non-benefit income
preserve

	keep swv idperson idhh ypnb
	rename ypnb ypnbsp
	rename idperson idpartner
	
	save "$dir_data/temp_ypnb", replace

restore

merge m:1 swv idpartner idhh using "$dir_data/temp_ypnb"
keep if _merge == 1 | _merge == 3
drop _merge


* Create bu equivalized gross real monthly personal non-benefit income
egen yhhnb = rowtotal(ypnb ypnbsp) if dhhtp_c4 == 1 | dhhtp_c4 == 2 

replace yhhnb = ypnb if dhhtp_c4 == 3 | dhhtp_c4 == 4 

replace yhhnb = (yhhnb/moecd_eq)


* Add jitter at the BU level 
sort idperson swv
set seed 9876

gen double jitter = runiform() * 1e-5

assert jitter >= 0 & jitter < 1e-5

bysort idbenefitunit stm (idperson): replace jitter = jitter[1]

bysort stm idbenefitunit: assert jitter == jitter[1]

sort idperson swv


* Update jittered equivalised BU gross non-benefit income quintiles
gen double yhhnb_jittered = yhhnb + jitter

count if yhhnb_jittered == yhhnb & jitter > 0 & !missing(yhhnb)

assert yhhnb_jittered > yhhnb if jitter > 0 & !missing(yhhnb)

rename ydses_c5 ydses_c5_orig2

* Omit dependent children from relevant sample 
gen depChild = 1 if dag <= ${age_max_dep_child} & (idfather > 0 | idmother > 0)

bysort swv idbenefitunit: egen double min_inc = min(yhhnb) if depChild != 1
bysort swv idbenefitunit: egen double max_inc = max(yhhnb) if depChild != 1

assert min_inc == max_inc if depChild != 1

drop min_inc max_inc

* Construct quintiles separately by survey year
forvalues stm = 2010/2024 {
	
	* Calculate quintiles excluding dependent children
	xtile ydses_c5_`stm' = yhhnb_jittered if depChild != 1 & ///
		stm == `stm' [pw=dwt], nq(5)
		
	* Assign quintiles to dependent children within benefit unit	
	bys stm idbenefitunit: egen ydses_c5_tmp_`stm' = max(ydses_c5_`stm') if ///
		stm == `stm'
	
	replace ydses_c5_`stm' = ydses_c5_tmp_`stm' if missing(ydses_c5_`stm')
	
	drop ydses_c5_tmp_`stm'
	
} 

* Combine year-specific quintiles
egen ydses_c5 = rowtotal( ///
    ydses_c5_2010 ydses_c5_2011 ydses_c5_2012 ydses_c5_2013 ydses_c5_2014 ///
	ydses_c5_2015 ydses_c5_2016 ydses_c5_2017 ydses_c5_2018 ydses_c5_2019 ///
    ydses_c5_2020 ydses_c5_2021 ydses_c5_2022 ydses_c5_2023 ydses_c5_2024 )

recode ydses_c5 (0 = -9)

* Check consistency of income quintiles within benefit units
bysort stm idbenefitunit: egen min_q = min(ydses_c5)
bysort stm idbenefitunit: egen max_q = max(ydses_c5)

assert min_q == max_q

drop min_q max_q

* Check coverage of income quintiles
tab stm depChild if ydses_c5 == -9, missing

sort idperson swv

* Check weighted income quintile distribution among adults by year
tab stm ydses_c5 if depChild != 1 [aw=dwt], row nofreq

* Clean up
drop ydses_c5_2* yhhnb yhhnb_jittered ypnb ypnbsp jitter depChild ydses_c5_orig*

sort idperson swv
	
	
/******************************** CREATE UID **********************************/
	
* Drop unnecessary variables 
drop orphan n_orphan idbupartner partnered orphan_number dag_orphan* ///
	temp_target_age* target_age* parent_agegap* agediff* ///
	temp_idmother_orphan* temp_idfather_orphan* unmatched_orphan hh_match* ///
	closest_agegap unmatched_reason newidmother newidfather ///
	temp_idbupartner adultMan adultWoman sumMen sumWomen num_adult	///
	dwt_adjusted dwt_sampling child adult adult_count adult_count2 ///
	duplicate PL_pop surv_pop multiplier dwtfq num_adults dhh_owned_orig ///
	flag_drop_obs rb110
	
	
//cf _all using "$dir_data/${country}_pooled_ipop.dta"

save "$dir_data/${country}_pooled_ipop.dta", replace  
// This is the complete UID, ready to use to estimate the SimPaths processes :) 


/******** SLICE UP DATA INTO CROSS SECTIONS FOR INITIAL POP AND RENAME ********/
forvalues yy = $first_sim_year/$last_sim_year {
	
	* Load pooled data with missing values removed  
	use "$dir_data/${country}_pooled_ipop.dta", clear
	
	rename *, l
	
	* Limit year
	global year = `yy'
	keep if stm == $year 

	* Check for duplicates 
	duplicates report idhh idperson
	cap drop duplicate 
	duplicates tag idhh idperson , generate(duplicate)
	duplicates drop idperson, force
	assert duplicate == 0 

	duplicates report idperson
	cap drop duplicate 
	duplicates tag idperson , generate(duplicate)
	duplicates drop idperson, force
	assert duplicate == 0 

	* Check for same sex households
    assert ssscp != 1 
    assert dgn != dgnsp if idpartner > 0

    * Check for number of adults 	
    gen child = dag < ${age_becomes_responsible} 
    gen adult = 1 - child 
    bys stm idhh: egen adult_count = sum(adult)
    bys stm idbenefitunit: egen adult_count2 = sum(adult)
    assert adult_count >= 1 
    assert adult_count2 >= 1 
    
	* Check for orphans 
    assert  (idfather > 0 | idmother > 0) if ///
		(dag > 0 & dag < ${age_becomes_responsible})

	* Check weight is not zero and non-missing 
	assert dwt > 0 & dwt < . 
	//sum of weights
	cap gen one = 1
	sum one [w = dwt]

	* Limit saved variables
	keep idhh idbenefitunit idperson idpartner idmother idfather swv dgn dag ///
	dnc02 dnc ded deh_c3 deh_c4 sedex dlltsd dhe ydses_c5 yplgrs_dv ///
	ypnbihs_dv yptciihs_dv dcpyy dcpagdf ynbcpdf_dv der dehm_c4 dehf_c4 stm ///
	dhh_owned lhw drgn1 dct les_c4 adultchildflag dwt obs_earnings_hourly ///
	l1_obs_earnings_hourly ypncp ypnoab ydisp l1_les_c4 liwwh  ///
	reg_birth unemp dehsp_c4 dhesp dcpst lessp_c4 lesdf_c4 new_rel new_rel_l1
	
	order idhh idbenefitunit idperson idpartner idmother idfather swv dgn ///
	dag dnc02 dnc ded deh_c3 deh_c4 sedex dlltsd dhe ydses_c5 yplgrs_dv ///
	ypnbihs_dv yptciihs_dv dcpyy dcpagdf ynbcpdf_dv der dehm_c4 dehf_c4 stm ///
	dhh_owned lhw drgn1 dct les_c4 adultchildflag dwt obs_earnings_hourly ///
	l1_obs_earnings_hourly ypncp ypnoab ydisp l1_les_c4 liwwh ///
	reg_birth unemp dehsp_c4 dhesp dcpst lessp_c4 lesdf_c4 new_rel new_rel_l1
	
	recode idhh idbenefitunit idperson idpartner idmother idfather swv dgn ///
	dag dnc02 dnc ded deh_c3 deh_c4 sedex dlltsd dhe ydses_c5 ///
	yplgrs_dv ypnbihs_dv yptciihs_dv dcpyy dcpagdf ynbcpdf_dv der ///
	dehm_c4 dehf_c4 stm dhh_owned lhw drgn1 dct les_c4 adultchildflag dwt ///
	obs_earnings_hourly l1_obs_earnings_hourly ypncp ypnoab ydisp l1_les_c4 ///
	liwwh reg_birth unemp dehsp_c4 dhesp dcpst lessp_c4 lesdf_c4 new_rel ///
	new_rel_l1 (missing = -9)
	
	
	* Rename Variables following new Codebook
	
	* Identifiers
	rename idhh idHh
	rename idbenefitunit idBu
	rename idperson idPers
	rename idpartner idPartner
	rename idmother idMother
	rename idfather idFather

	* Time 
	rename stm statInterviewYear
	rename swv statCollectionWave

	* Location 
	rename drgn1 demRgn
	rename dct demCountry
	
	* Weights 
	rename dwt wgtCrossMainSurvey
	
	* Demographics 
	rename dgn demMaleFlag
	rename dag demAge
	rename dcpst demPartnerStatus
	rename dnc02 demNChild0to2
	rename dnc demNChild
	//rename ssscp demPartnerSameSexFlag
	//rename dcpen demEnterPartnerFlag
	rename dcpyy demPartnerNYear
	//rename dcpex demExitPartnerFlag
	rename dcpagdf demAgePartnerDiff
	//rename sedag demAgeEduRangeFlag
	//rename sprfm demFertFlag
	//rename dchpd demNChild0
	//rename dagsp demAgePartner
	rename adultchildflag demAdultChildFlag
	//rename dhhtp_c4 demCompHhC4	
	//rename dhhtp_c8 demCompHhC8
	//rename multiplier demPopSurveyShare
	//rename dot demEthnC4
	//rename dot01 demEthnC6
	rename reg_birth demRgnBirthIntl
	rename new_rel demPartnerFirstYearFlag
	rename new_rel_l1 demPartnerFirstYearFlagL1

	* Education 
	rename deh_c3 eduHighestC3
	rename deh_c4 eduHighestC4	
	rename dehsp_c4 eduHighestPartnerC4
	rename ded eduSpellFlag
	rename sedex eduExitSampleFlag
	rename der eduReturnFlag	
	rename dehm_c4 eduHighestMotherC4
	rename dehf_c4 eduHighestFatherC4
	
	* Labour market 
	//rename les_c3 labStatusC3	
	rename les_c4 labC4
	rename l1_les_c4 labC4L1
	//rename lessp_c3 labStatusPartnerC3
	rename lessp_c4 labStatusPartnerC4
	rename lesdf_c4 labStatusPartnerAndOwnC4	
	rename lhw labHrsWorkWeek
	//rename l1_lhw labHrsWorkWeekL1	
	rename unemp labUnempFlag
	
	* Income, labour, wealth 
	rename obs_earnings_hourly labWageHrly
	rename l1_obs_earnings_hourly labWageHrlyL1

	//rename liquid_wealth wealthLiq
	//rename tot_pen wealthPensValue
	//rename nvmhome wealthPrptyValue

	//rename total_wealth wealthTotValue   
	//rename mortgage_debt wealthMortgageDebtValue  
	//rename housing_wealth wealthPrptyValue 
	//rename total_pensions wealthPensValue 
	
	rename ydses_c5 yHhQuintilesMonthC5	
	rename ynbcpdf_dv yPersAndPartnerGrossDiffMonth
	rename dhh_owned wealthPrptyFlag
	
	//rename econ_benefits yBenReceivedFlag
	//rename econ_benefits_nonuc yBenNonUCReceivedFlag
	//rename econ_benefits_uc yBenUCReceivedFlag

	rename ypncp yCapitalPersMonth
	rename ypnoab yPensPersGrossMonth
	rename yplgrs_dv yEmpPersGrossMonth
	rename ypnbihs_dv yNonBenPersGrossMonth
	rename yptciihs_dv yMiscPersGrossMonth
	rename ydisp yPersDispMonth               

	//rename unemp labUnempFlag
	rename liwwh labEmpNyear

	* Health & wellbeing 
	rename dlltsd healthDsblLongtermFlag
	rename dhe healthSelfRated
	rename dhesp healthPartnerSelfRated	
	//rename dhm healthWbScore0to36
	//rename dhm_ghq healthPsyDstrss0to12
	//rename dhe_mcs healthMentalMcs
	//rename dhe_pcs healthPhysicalPcs
	//rename dhe_mcssp healthMentalPartnerMcs
	//rename dhe_pcssp healthPhysicalPartnerPcs
	//rename dls demLifeSatScore0to10
	//rename financial_distress yFinDstrssFlag	
		
	gsort idHh idBu idPers	
	
	//save "$dir_data/population_initial_${country}_${year}.dta", replace
	
	recode demMaleFlag (-9 = 0)

	export delimited using ///
		"$dir_data/population_initial_${country}_${year}.csv", nolabel replace
		
}


/***************************** CLEAN UP AND EXIT ******************************/
cap log close

#delimit ;
local files_to_drop 
	${country}_pooled_ipop_pre.dta
	;
#delimit cr // cr stands for carriage return

foreach file of local files_to_drop { 
	erase "$dir_data/`file'"
}


