/*******************************************************************************
* PROJECT:              SimPaths EU
* DO-FILE NAME:         06_check_yearly_data_ES.do
* DESCRIPTION:          Checks the new initial population against the previous
*                       version.
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
*   This do-file checks the newly constructed initial population against the
*   previous version for the same year. It is used to identify unexpected
*   changes in the distributions of variables following updates to the
*   initial population construction.
*
*   -----------------------------------------------------------------------
*    Comparison checks
*   -----------------------------------------------------------------------
*   - Compares the new and previous initial population datasets
*   - Checks the distributions of key variables for unexpected differences
*   - Compares regional distributions
*
*   -----------------------------------------------------------------------
*    Changes that need to be made for a new country
*   -----------------------------------------------------------------------
*   - Update the number of regions specified in the relevant locals
*
* TO DO:
*   - Update checks to reflect current variable names. Outstanding issue since 
* 		the predrop still uses the old names. 
*******************************************************************************/

cap log close 
log using "${dir_log}/06_check_yearly_data.log", replace

* All variables 
#delimit ;
local varlist 
idHh
idBu
idPers
idPartner
idMother
idFather
statCollectionWave
demMaleFlag
demAge
demPartnerStatus
demNChild0to2
demNChild
eduSpellFlag
eduHighestC3
eduHighestC4
eduExitSampleFlag
healthDsblLongtermFlag
healthSelfRated
yHhQuintilesMonthC5
yEmpPersGrossMonth
yNonBenPersGrossMonth
yMiscPersGrossMonth
//demCompHhC8
demPartnerSameSexFlag
demEnterPartnerFlag
demPartnerNYear
demExitPartnerFlag
demAgePartnerDiff
yPersAndPartnerGrossDiffMonth
eduReturnFlag
demAgeEduRangeFlag
demFertFlag
demAgePartner
eduHighestPartnerC3
healthPartnerSelfRated
labStatusPartnerC3
statInterviewYear
labStatusPartnerAndOwnC4
wealthPrptyFlag
labHrsWorkWeek
demRgn
demCountry
dwt_sampling
labC4
labStatusPartnerC4
demAdultChildFlag
wgtCrossMainSurvey
labWageHrly
labWageHrlyL1
yCapitalPersMonth
yPensPersGrossMonth
labC4L1
;
#delimit cr // cr stands for carriage return

*varlist for categorical variables 
#delimit ;
local varlist_cat 
demPartnerStatus
eduHighestC3
eduHighestC4
healthSelfRated
yHhQuintilesMonthC5
demCompHhC8
eduHighestPartnerC3
healthPartnerSelfRated
labStatusPartnerC3
labStatusPartnerAndOwnC4
labC4
labStatusPartnerC4
demRgn
labC4L1   
;
#delimit cr // cr stands for carriage return 


*new varlist with categorical variables output by category 
#delimit ;
local varlist2 
idHh
idBu
idPers
idPartner
idMother
idFather
statCollectionWave
demMaleFlag
demAge
demPartnerStatus
demNChild0to2
demNChild
eduSpellFlag
eduExitSampleFlag
healthDsblLongtermFlag
yCapitalPersMonth
yPensPersGrossMonth
yEmpPersGrossMonth
yNonBenPersGrossMonth
yMiscPersGrossMonth
demPartnerSameSexFlag
demEnterPartnerFlag
demPartnerNYear
demExitPartnerFlag
demAgePartnerDiff
yPersAndPartnerGrossDiffMonth
eduReturnFlag
demAgeEduRangeFlag
demFertFlag
demAgePartner
statInterviewYear
labHrsWorkWeek
demCountry
dwt_sampling
demAdultChildFlag
wgtCrossMainSurvey
demPartnerStatus_1
demPartnerStatus_2
eduHighestC3_1
eduHighestC3_2
eduHighestC3_3
eduHighestC4_1
eduHighestC4_2
eduHighestC4_3
eduHighestC4_4
healthSelfRated_1
healthSelfRated_2
healthSelfRated_3
healthSelfRated_4
healthSelfRated_5
yHhQuintilesMonthC5_1
yHhQuintilesMonthC5_2
yHhQuintilesMonthC5_3
yHhQuintilesMonthC5_4
yHhQuintilesMonthC5_5
/*demCompHhC8_1
demCompHhC8_2
demCompHhC8_3
demCompHhC8_4
demCompHhC8_5
demCompHhC8_6
demCompHhC8_7
demCompHhC8_8*/
eduHighestPartnerC3_1
eduHighestPartnerC3_2
eduHighestPartnerC3_3
healthPartnerSelfRated_1
healthPartnerSelfRated_2
healthPartnerSelfRated_3
healthPartnerSelfRated_4
healthPartnerSelfRated_5
labStatusPartnerC3_1
labStatusPartnerC3_2
labStatusPartnerC3_3
labStatusPartnerAndOwnC4_1
labStatusPartnerAndOwnC4_2
labStatusPartnerAndOwnC4_3
labStatusPartnerAndOwnC4_4
labC4_1
labC4_2
labC4_3
labC4_4
labStatusPartnerC4_1
labStatusPartnerC4_2
labStatusPartnerC4_3
labStatusPartnerC4_4
demRgn_1
demRgn_2
demRgn_3
demRgn_4
demRgn_5
labWageHrly
labWageHrlyL1 
	;
#delimit cr // cr stands for carriage return 

cap erase "$dir_data/population_initial_${country}_sumstats.xls"
cap erase "$dir_data/population_initial_fs_${country}_sumstats.xls"

cap erase "$dir_data/population_initial_${country}_sumstats.txt"
cap erase "$dir_data/population_initial_fs_${country}_sumstats.txt"


/******************** SUMMARY STATA FOR FINAL INITIAL POPULATIONS *************/
forvalues year = $first_sim_year/$last_sim_year {
	
	use "$dir_data/population_initial_${country}_`year'.dta", clear  

	replace eduHighestC4 = 4 if eduHighestC4 == 0 

	foreach var of local varlist_cat {
	
		recode `var' (0=.) (-9=.) 
		cap drop `var'_*
		tab `var', gen(`var'_)
	
	}
	 
	 
	foreach var of local varlist2 {
	
	recode `var' (-9=.) 
	
	}

	order `varlist2' 
	qui sum `varlist2' , de 

	save "$dir_data/population_initial_${country}_`year'.dta", replace 
	
	outreg2 using "$dir_data/population_initial_${country}_sumstats.xls" if ///
		stm == `year', sum(log) append cttop(`year') keep (`varlist2')

}


/**************** SUMMARY STATA FOR INITIAL POPULATIONS PRE-DROP **************/

forvalues year = $first_sim_year/$last_sim_year {
	
	use "$dir_data/population_initial_fs_${country}_`year'.dta", clear

	cap gen dwt_sampling = 0
	cap gen hu_pop = 0                        
	cap gen surv_pop = 0                        
	cap gen multiplier = 0                     
	cap gen adult = dag >= ${age_become_responsible} 
	cap gen child = 1 - adult    
	
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
	
	replace eduHighestC4 = 4 if eduHighestC4 == 0 

	foreach var of local varlist_cat {
	
		recode `var' (0=.) (-9=.) 
		cap drop `var'_*
		tab `var', gen(`var'_)
	
	}
 
 
	foreach var of local varlist2 {
	
		recode `var' (-9=.) 
	
	}

	order `varlist2' 
	qui sum `varlist2' , de 

	save "$dir_data/population_initial_fs_${country}_`year'.dta", replace
	
	outreg2 using ///
		"$dir_data/population_initial_fs_${country}_sumstats.xls" if ///
		stm == `year',sum(log) append cttop(`year') keep (`varlist2')
		
}


/***************************** CLEAN UP AND EXIT ******************************/
cap log close    

cap erase "$dir_data/population_initial_${country}_sumstats.txt"
cap erase "$dir_data/population_initial_fs_${country}_sumstats.txt"

          
  