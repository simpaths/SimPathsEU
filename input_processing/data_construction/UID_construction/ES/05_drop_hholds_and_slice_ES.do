/*******************************************************************************
* PROJECT:              SimPaths EU
* DO-FILE NAME:         05_drop_hhold_an_slice.do
* DESCRIPTION:          Creates the UID and initial population files
* COUNTRY:              ES
* DATA:                 EU-SILC panel dataset
* AUTHORS:              Daria Popova, Ashley Burdett
* LAST UPDATE:          1 October 2026
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
log using "${dir_log}/05_finalise_input_data.log", replace

* Load data
use "$dir_data/${country}-SILC_pooled_all_obs_04.dta", clear


/****************************** LIMIT SAMPLE **********************************/

* If any person in the household has missing values, drop the whole household:
drop if dropHH == 1 

drop dropObs dropHH 
	
* Drop if hh weight = 0:
count if dwt == 0 
drop if dwt == 0 

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
Total population figures for Spain from 2011 to 2024 (EUROSTAT demo_gind avg):
*/
cap gen ${country}_pop = 0 
replace ${country}_pop = 46743697 if stm == 2011 
replace ${country}_pop = 46773055 if stm == 2012
replace ${country}_pop = 46604197 if stm == 2013
replace ${country}_pop = 46460733 if stm == 2014
replace ${country}_pop = 46422303 if stm == 2015
replace ${country}_pop = 46458139 if stm == 2016
replace ${country}_pop = 46571232 if stm == 2017 
replace ${country}_pop = 46782011 if stm == 2018
replace ${country}_pop = 47118501 if stm == 2019
replace ${country}_pop = 47359424 if stm == 2020
replace ${country}_pop = 47443821 if stm == 2021
replace ${country}_pop = 47786528 if stm == 2022
replace ${country}_pop = 48352528 if stm == 2023
replace ${country}_pop = 48873996 if stm == 2024


sort stm idperson

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

* Check the populations sum correctly, allowing for rounding error
preserve 

	collapse (sum) dwt, by(stm)

restore

sort idperson swv 

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
    drop adult child adult_count adult_count2 //drop old vars 
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
	reg_birth unemp
	
	order idhh idbenefitunit idperson idpartner idmother idfather swv dgn ///
	dag dnc02 dnc ded deh_c3 deh_c4 sedex dlltsd dhe ydses_c5 yplgrs_dv ///
	ypnbihs_dv yptciihs_dv dcpyy dcpagdf ynbcpdf_dv der dehm_c4 dehf_c4 stm ///
	dhh_owned lhw drgn1 dct les_c4 adultchildflag dwt obs_earnings_hourly ///
	l1_obs_earnings_hourly ypncp ypnoab ydisp l1_les_c4 liwwh ///
	reg_birth unemp
	
	recode idhh idbenefitunit idperson idpartner idmother idfather swv dgn ///
	dag dnc02 dnc ded deh_c3 deh_c4 sedex dlltsd dhe ydses_c5 ///
	yplgrs_dv ypnbihs_dv yptciihs_dv dcpyy dcpagdf ynbcpdf_dv der ///
	dehm_c4 dehf_c4 stm dhh_owned lhw drgn1 dct les_c4 adultchildflag dwt ///
	obs_earnings_hourly l1_obs_earnings_hourly ypncp ypnoab ydisp l1_les_c4 ///
	liwwh reg_birth unemp	(missing = -9)
	
	
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
	//rename dcpst demPartnerStatus
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

	* Education 
	rename deh_c3 eduHighestC3
	rename deh_c4 eduHighestC4	
	//rename dehsp_c3 eduHighestPartnerC3
	//rename dehsp_c4 eduHighestPartnerC4
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
	//rename lessp_c4 labStatusPartnerC4
	//rename lesdf_c4 labStatusPartnerAndOwnC4	
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
	//rename dhesp healthPartnerSelfRated	
	//rename dhm healthWbScore0to36
	//rename dhm_ghq healthPsyDstrss0to12
	//rename dhe_mcs healthMentalMcs
	//rename dhe_pcs healthPhysicalPcs
	//rename dhe_mcssp healthMentalPartnerMcs
	//rename dhe_pcssp healthPhysicalPartnerPcs
	//rename dls demLifeSatScore0to10
	//rename financial_distress yFinDstrssFlag	
	
	gsort idHh idBu idPers	
	
	save "$dir_data/population_initial_${country}_${year}.dta", replace
	
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


