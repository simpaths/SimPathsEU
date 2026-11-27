******************************************************************************************
* PROJECT:  		SimPaths PL
* SECTION:			Attrition analysis
* OBJECT: 			Final Probit  
* AUTHORS:			Aleksandra Kolndrekaj
* LAST UPDATE:		24.11.2026
* COUNTRY: 			PL  
* 
* NOTES: 			variables of interest for attrition analysis educational levels,  
*					partnership rate, activity status, ethnicity, gender                   
*                    
*********************************************************************************


clear all
set more off
set mem 200m
set type double
set maxvar 30000

* Set off log 
cap log close 
log using "$dir_log/attrition.log", replace

* Load data 
use "$dir_input_data/${country}_pooled_ipop.dta", clear

cd "$dir_work\attrition"
* Set data 
xtset idperson swv
sort idperson swv 
*==================================================
* Time transformations
*==================================================

replace stm = stm - 2000

foreach y of numlist 11/25 {
    gen y20`y' = (stm == `y')
}

foreach y of numlist 2011/2025 {
    gen Y`y' = y`y'
}

* Adjust variables 
*do "${dir_do}/variable_update_ak.do"

gen Dag_16_30=1 if dag >=16 & dag<=30
replace Dag_16_30=0 if Dag_16_30==.

gen Dag_31_40=1 if dag >=31 & dag<=40
replace Dag_31_40=0 if Dag_31_40==.

gen Dag_41_65=1 if dag >=41 & dag<=65
replace Dag_41_65=0 if Dag_41_65==.

gen Dag_66_plus=1 if dag >=66 
replace Dag_66_plus=0 if Dag_66_plus==.

gen Dgn = dgn 
tab Dgn, gen (Dgn_)

rename Dgn_1 Dgn_Women
rename Dgn_2 Dgn_Men



gen Dag = dag  

gen Dag_sq = dagsq 

tab drgn1, gen(${country}) 
rename PL5 PL10 
rename PL4 PL6
rename PL3 PL5 
rename PL2 PL4
rename PL1 PL2

global regions "i.PL4 i.PL5 i.PL6 i.PL10"

tab ydses_c5 , gen(Ydses_c5_Q)


tab deh_c3, gen(Deh_c3_)
rename Deh_c3_1 Deh_c3_High
rename Deh_c3_2 Deh_c3_Medium

rename Deh_c3_3 Deh_c3_Low

tab deh_c4, gen(Deh_c4_)
rename Deh_c4_1 Deh_c4_Na
rename Deh_c4_2 Deh_c4_High
rename Deh_c4_3 Deh_c4_Medium
rename Deh_c4_4 Deh_c4_Low

tab dcpst, gen(Dcpst_)
rename Dcpst_1 Dcpst_Partnered
rename Dcpst_2 Dcpst_Single

tab les_c3, gen(Les_c3_)
rename Les_c3_1 Les_c3_Employed
rename Les_c3_2 Les_c3_Student
rename Les_c3_3 Les_c3_NotEmployed

tab les_c4, gen(Les_c4_)
rename Les_c4_1 Les_c4_Employed
rename Les_c4_2 Les_c4_Student
rename Les_c4_3 Les_c4_NotEmployed
rename Les_c4_4 Les_c4_Retired 


*==================================================
* Household type and relationship dynamics
*==================================================

tab dhhtp_c4, gen(Dhhtp_c4_)
rename Dhhtp_c4_1 Dhhtp_c4_CoupleNoChildren
rename Dhhtp_c4_2 Dhhtp_c4_CoupleChildren
rename Dhhtp_c4_3 Dhhtp_c4_SingleNoChildren
rename Dhhtp_c4_4 Dhhtp_c4_SingleChildren

tab dhhtp_c8, gen(Dhhtp_c8_)

gen New_rel = new_rel



*==================================================
* Working hour categories
*==================================================

gen lhw_c5=.
replace lhw_c5=0 if (lhw<=5)
replace lhw_c5=10 if (lhw>=6 & lhw<=15)
replace lhw_c5=20 if (lhw>=16 & lhw<=25)
replace lhw_c5=30 if (lhw>=26 & lhw<=35)
replace lhw_c5=40 if (lhw>=36 & lhw!=.)

gen lhw_c5_1=.
replace lhw_c5_1=1 if (lhw>0 & lhw<=15)
replace lhw_c5_1=2 if (lhw>=16 & lhw<=30)
replace lhw_c5_1=3 if (lhw>=31 & lhw<=48)
replace lhw_c5_1=4 if (lhw>=49)


label define lhwsp 0 "Zero" 10 "Ten" 20 "Twenty" 30 "Thirty" 40 "Forty"
label value lhw_c5 lhwsp
la var lhw_c5 "Hours worked per week (category)"

tab lhw_c5, gen (Lhw_c5_)

rename Lhw_c5_1 Lhw_c5_Zero
rename Lhw_c5_2 Lhw_c5_Ten
rename Lhw_c5_3 Lhw_c5_Twenty
rename Lhw_c5_4 Lhw_c5_Thirty
rename Lhw_c5_5 Lhw_c5_Forty

replace dhe=. if dhe==-9
tab dhe, gen(Dhe_)
rename Dhe_1 Dhe_Poor
rename Dhe_2 Dhe_Fair
rename Dhe_3 Dhe_Good
rename Dhe_4 Dhe_VeryGood
rename Dhe_5 Dhe_Excellent

gen Dlltsd = dlltsd
tab Dlltsd, gen (Dlltsd_)
rename Dlltsd_1 Dlltsd_able
rename Dlltsd_2 Dlltsd_disable

  * Create the interaction variables before collapsing

  *gen Men_Partnered    = (Dcpst_Partnered == 1 & Dgn_Men == 1)

  *gen Men_Single       = (Dcpst_Single == 1    & Dgn_Men == 1)

  *gen Women_Partnered  = (Dcpst_Partnered == 1 & Dgn_Women == 1)

  *gen Women_Single     = (Dcpst_Single == 1    & Dgn_Women == 1)


********************************************************************************
*1 create variables for analysis
********************************************************************************
*individuals by wave

bysort idperson: gen total_waves = _N
*bysort idperson: gen total_waves2=1 if total_waves==1
*replace total_waves2=2 if total_waves>=2 & total_waves<=5
*replace total_waves2=3 if total_waves>=6 & total_waves<=10
*replace total_waves2=4 if total_waves>=11 & total_waves<=13
*replace total_waves2=5 if total_waves==14

egen max_waves = max(swv)




* Generate the running count of appearances
bysort idperson (swv): gen waves_until_now = _n
tabulate total_waves
egen tag = tag(idperson)

xtset idperson swv

gen entrant = (L.swv == .)
gen exiter  = (F.swv == .)
*replace exiter=. if swv==15
*replace entrant=. if swv==2


**identify who has been consecutively in the panel

* 1. Find the first and last wave for each person
bysort idperson (swv): gen first_w = swv[1]
bysort idperson (swv): gen last_w  = swv[_N]

* 2. Calculate the expected number of waves if they were consecutive
gen expected_n = last_w - first_w + 1

* 3. Create the dummy: 1 if total rows equal expected rows (Consecutive)
* _N is the actual number of times they appear in the data
bysort idperson: gen consecutive = (_N == expected_n)
replace consecutive=. if total_waves==1

* Label for clarity
label define con 1 "Consecutive" 0 "Gaps in Participation"
label values consecutive con


*gen UKEn=1 if UKC==1| UKD==1| UKE==1| UKF==1| UKG==1| UKH==1| UKJ==1| UKK==1
*replace UKEn=0 if UKI==1| UKL==1| UKM==1| UKN==1 global regions "i.PL4 i.PL5 i.PL6 i.PL10"


global wave Y2011 Y2012 Y2013 Y2014 Y2015 Y2016 Y2017 Y2018 Y2019 Y2020 Y2021 Y2022 Y2023 Y2024 Y2025
global demography Deh_c4_Na Deh_c4_High Deh_c4_Medium Deh_c4_Low Dag_16_30 Dag_31_40 Dag_41_65 Dag_66_plus Dgn_Women Dgn_Men PL4 PL5 PL6 PL10
global partnership Dcpst_Partnered Dcpst_Single
global health Dhe_Poor Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent Dlltsd_able Dlltsd_disable
global activity Les_c4_Employed Les_c4_Student Les_c4_NotEmployed Les_c4_Retired Ydses_c5_Q1 Ydses_c5_Q2 Ydses_c5_Q3 Ydses_c5_Q4 Ydses_c5_Q5 Lhw_c5_Zero Lhw_c5_Ten Lhw_c5_Twenty Lhw_c5_Thirty Lhw_c5_Forty
global part_gender Men_Partnered Men_Single Women_Partnered Women_Single

* 3. Nest them all into one master global

* 1. Redefine your master global (WITHOUT $wave)
global allvars $demography $partnership $activity $part_gender $health

/*foreach var in $allvars {
    
    * 1. Flag individuals who belong to the subgroup at baseline (Wave 2)
    gen temp_base = (`var' == 1 & swv == 2)
    bysort idperson: egen in_subgroup_at_baseline = max(temp_base)
    
    * 2. Total baseline size for this specific subgroup (Fixed denominator)
    egen base_count_`var' = total(in_subgroup_at_baseline == 1 & swv == 2)
    
    * 3. Count how many of those baseline members are present in each wave (Numerator)
    * (Using total() on the dummy variable acts as a conditional count per wave)
    bysort swv: egen active_total_`var' = total(in_subgroup_at_baseline == 1)
    
    * 4. Calculate the true response rate per wave
    gen rr_`var' = (active_total_`var' / base_count_`var') * 100
    
    * Clean up all temporary/intermediate variables for the next loop iteration
    drop temp_base in_subgroup_at_baseline active_total_`var' base_count_`var'
}

* Collapse and export safely
preserve
    collapse (mean) rr_*, by(swv)
    export excel using "Unconditional_Wave_Response_Rates2.xlsx", firstrow(variables) replace
restore

* 1. Flag individuals who were present at baseline (Wave 2)
gen temp_base = (swv == 2)
bysort idperson: egen present_at_baseline = max(temp_base)

* 2. Calculate the fixed denominator (Total unique people present in Wave 2)
egen base_count_total = total(present_at_baseline == 1 & swv == 2)

* 3. Calculate the numerator (How many baseline members are present in each wave)
bysort swv: egen active_total_by_wave = total(present_at_baseline == 1)

* 4. Calculate the overall response rate per wave
gen rr_overall = (active_total_by_wave / base_count_total) * 100

* Clean up temporary counting variables
drop temp_base present_at_baseline active_total_by_wave */

*************************************************************************************************************************
*2 Descriptive statistics by sociodemographic characteristics
************************************************************************************************************************

preserve
    * Create the interaction variables before collapsing
   gen Men_Partnered    = (Dcpst_Partnered == 1 & Dgn_Men == 1)
    gen Men_Single       = (Dcpst_Single == 1    & Dgn_Men == 1)
    gen Women_Partnered  = (Dcpst_Partnered == 1 & Dgn_Women == 1)
    gen Women_Single     = (Dcpst_Single == 1    & Dgn_Women == 1)

    * Collapse using the master global
    collapse (mean) $allvars [aw=dwt], by(total_waves)
    
    foreach var of varlist $allvars {
        replace `var' = `var' * 100
    }

    * Label the new variables for Excel
    label var Men_Partnered "Partnered Men"
    label var Men_Single "Single Men"
    label var Women_Partnered "Partnered Women"
    label var Women_Single "Single Women"

    * Exporting
    export excel total_waves $demography using "$dir_work/attrition/Results_Attrition_all.xlsx", sheet("Demography") sheetreplace firstrow(variables)
    export excel total_waves $partnership using "$dir_work/attrition/Results_Attrition_all.xlsx", sheet("Partnership") sheetreplace firstrow(variables)
    export excel total_waves $activity using "$dir_work/attrition/Results_Attrition_all.xlsx", sheet("Activity") sheetreplace firstrow(variables)
     export excel total_waves $health using "$dir_work/attrition/Results_Attrition_all.xlsx", sheet("Health") sheetreplace firstrow(variables)
    
    * Export the new sub-group sheet
    export excel total_waves $part_gender using "$dir_work/attrition/Results_Attrition_all.xlsx", ///
        sheet("Partnership_by_Gender") sheetreplace firstrow(varlabels)
restore

/*preserve
    * Create the interaction variables before collapsing
    gen Men_Partnered    = (Dcpst_Partnered == 1 & Dgn_Men == 1)
    gen Men_Single       = (Dcpst_Single == 1    & Dgn_Men == 1)
    gen Women_Partnered  = (Dcpst_Partnered == 1 & Dgn_Women == 1)
    gen Women_Single     = (Dcpst_Single == 1    & Dgn_Women == 1)

    * Collapse using the master global
    collapse (mean) $allvars [aw=dwt], by(total_waves2)
    
    foreach var of varlist $allvars {
        replace `var' = `var' * 100
    }

    * Label the new variables for Excel
    label var Men_Partnered "Partnered Men"
    label var Men_Single "Single Men"
    label var Women_Partnered "Partnered Women"
    label var Women_Single "Single Women"

    * Exporting
    export excel total_waves2 $demography using "$dir_results/Results_Attrition_all2.xlsx", sheet("Demography") sheetreplace firstrow(variables)
    export excel total_waves2 $partnership using "$dir_results/Results_Attrition_all2.xlsx", sheet("Partnership") sheetreplace firstrow(variables)
    export excel total_waves2 $activity using "$dir_results/Results_Attrition_all2.xlsx", sheet("Activity") sheetreplace firstrow(variables)
    
    * Export the new sub-group sheet
    export excel total_waves2 $part_gender using "$dir_results/Results_Attrition_all2.xlsx", ///
        sheet("Partnership_by_Gender") sheetreplace firstrow(varlabels)
restore */
* Iterate through both groups

    preserve
        * 1. Create the interaction variables
        gen Men_Partnered    = (Dcpst_Partnered == 1 & Dgn_Men == 1)
        gen Men_Single       = (Dcpst_Single == 1    & Dgn_Men == 1)
        gen Women_Partnered  = (Dcpst_Partnered == 1 & Dgn_Women == 1)
        gen Women_Single     = (Dcpst_Single == 1    & Dgn_Women == 1)

        * 2. Collapse by wave, filtering for the specific group (entrant or exiter)
        * Note: This assumes you have a variable named 'entrant' and 'exiter' that are binary (1/0)
        collapse (mean) $allvars [aw=dwt], by(swv)
        
        * 3. Convert to percentages
        foreach var of varlist $allvars {
            replace `var' = `var' * 100
        }

        * 4. Apply labels for Excel headers
        label var Men_Partnered "Partnered Men"
        label var Men_Single "Single Men"
        label var Women_Partnered "Partnered Women"
        label var Women_Single "Single Women"

        * 5. Export to separate files based on the group name (`n')
        export excel swv $demography using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Demography") sheetreplace firstrow(variables)
            
        export excel swv $partnership using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Partnership") sheetreplace firstrow(variables)
            
        export excel swv $activity using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Activity") sheetreplace firstrow(variables)
        
        export excel swv $part_gender using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Partnership_by_Gender") sheetreplace firstrow(varlabels)
		
		export excel swv $health using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Health") sheetreplace firstrow(varlabels)
    restore


 preserve
        * 1. Create the interaction variables
        gen Men_Partnered    = (Dcpst_Partnered == 1 & Dgn_Men == 1)
        gen Men_Single       = (Dcpst_Single == 1    & Dgn_Men == 1)
        gen Women_Partnered  = (Dcpst_Partnered == 1 & Dgn_Women == 1)
        gen Women_Single     = (Dcpst_Single == 1    & Dgn_Women == 1)

        * 2. Collapse by wave, filtering for the specific group (entrant or exiter)
        * Note: This assumes you have a variable named 'entrant' and 'exiter' that are binary (1/0)
        collapse (mean) $allvars [aw=dwt], by(exiter)
        
        * 3. Convert to percentages
        foreach var of varlist $allvars {
            replace `var' = `var' * 100
        }

        * 4. Apply labels for Excel headers
        label var Men_Partnered "Partnered Men"
        label var Men_Single "Single Men"
        label var Women_Partnered "Partnered Women"
        label var Women_Single "Single Women"

  
			
			* exiter
			 export excel exiter $demography using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Exiter Demography") sheetreplace firstrow(variables)
            
        export excel exiter $partnership using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Exiter Partnership") sheetreplace firstrow(variables)
            
        export excel exiter $activity using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet(" Exiter Activity") sheetreplace firstrow(variables)
        
        export excel exiter $part_gender using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Exiter Partnership_by_Gender") sheetreplace firstrow(varlabels)
			
			export excel exiter $health using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Health") sheetreplace firstrow(varlabels)
    restore
   

preserve
        * 1. Create the interaction variables
        gen Men_Partnered    = (Dcpst_Partnered == 1 & Dgn_Men == 1)
        gen Men_Single       = (Dcpst_Single == 1    & Dgn_Men == 1)
        gen Women_Partnered  = (Dcpst_Partnered == 1 & Dgn_Women == 1)
        gen Women_Single     = (Dcpst_Single == 1    & Dgn_Women == 1)

        * 2. Collapse by wave, filtering for the specific group (entrant or exiter)
        * Note: This assumes you have a variable named 'entrant' and 'exiter' that are binary (1/0)
        collapse (mean) $allvars [aw=dwt], by(entrant)
        
        * 3. Convert to percentages
        foreach var of varlist $allvars {
            replace `var' = `var' * 100
        }

        * 4. Apply labels for Excel headers
        label var Men_Partnered "Partnered Men"
        label var Men_Single "Single Men"
        label var Women_Partnered "Partnered Women"
        label var Women_Single "Single Women"

  
			* Entrant
			 export excel entrant $demography using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Entrant Demography") sheetreplace firstrow(variables)
            
        export excel entrant $partnership using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Entrant Partnership") sheetreplace firstrow(variables)
            
        export excel entrant $activity using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Entrant Activity") sheetreplace firstrow(variables)
        
        export excel entrant $part_gender using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Entrant Partnership_by_Gender") sheetreplace firstrow(varlabels)
			
			 export excel entrant $health using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("health") sheetreplace firstrow(varlabels)
    restore

	
	preserve
        * 1. Create the interaction variables
        gen Men_Partnered    = (Dcpst_Partnered == 1 & Dgn_Men == 1)
        gen Men_Single       = (Dcpst_Single == 1    & Dgn_Men == 1)
        gen Women_Partnered  = (Dcpst_Partnered == 1 & Dgn_Women == 1)
        gen Women_Single     = (Dcpst_Single == 1    & Dgn_Women == 1)

        * 2. Collapse by wave, filtering for the specific group (entrant or exiter)
        * Note: This assumes you have a variable named 'entrant' and 'exiter' that are binary (1/0)
        collapse (mean) $allvars [aw=dwt], by(swv exiter)
        
        * 3. Convert to percentages
        foreach var of varlist $allvars {
            replace `var' = `var' * 100
        }

        * 4. Apply labels for Excel headers
        label var Men_Partnered "Partnered Men"
        label var Men_Single "Single Men"
        label var Women_Partnered "Partnered Women"
        label var Women_Single "Single Women"

  
			* exiter
			 export excel swv exiter $demography if exiter==1 using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Exiter swv Demography") sheetreplace firstrow(variables)
            
        export excel swv exiter $partnership if exiter==1 using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Exiter swv Partnership") sheetreplace firstrow(variables)
            
        export excel swv exiter $activity if exiter==1 using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Exiter swv Activity") sheetreplace firstrow(variables)
        
        export excel exiter $part_gender if exiter==1 using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Exiter swv Partnership Gender") sheetreplace firstrow(varlabels)
			
			export excel exiter $health if exiter==1 using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Health") sheetreplace firstrow(varlabels)
    restore

preserve
        * 1. Create the interaction variables
        gen Men_Partnered    = (Dcpst_Partnered == 1 & Dgn_Men == 1)
        gen Men_Single       = (Dcpst_Single == 1    & Dgn_Men == 1)
        gen Women_Partnered  = (Dcpst_Partnered == 1 & Dgn_Women == 1)
        gen Women_Single     = (Dcpst_Single == 1    & Dgn_Women == 1)

        * 2. Collapse by wave, filtering for the specific group (entrant or exiter)
        * Note: This assumes you have a variable named 'entrant' and 'exiter' that are binary (1/0)
        collapse (mean) $allvars [aw=dwt], by(swv entrant)
        
        * 3. Convert to percentages
        foreach var of varlist $allvars {
            replace `var' = `var' * 100
        }

        * 4. Apply labels for Excel headers
        label var Men_Partnered "Partnered Men"
        label var Men_Single "Single Men"
        label var Women_Partnered "Partnered Women"
        label var Women_Single "Single Women"


			* Entrant
			 export excel swv entrant $demography if entrant==1 using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Entrant swv Demography") sheetreplace firstrow(variables)
            
        export excel swv entrant $partnership if entrant==1 using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Entrant swv Partnership") sheetreplace firstrow(variables)
            
        export excel swv entrant $activity if entrant==1 using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Entrant swv Activity") sheetreplace firstrow(variables)
        
        export excel swv entrant $part_gender if entrant==1 using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Entrant swv Partnership Gender") sheetreplace firstrow(varlabels)
			
			export excel swv entrant $health if entrant==1 using "$dir_work/attrition/Results_Attrition_wave_all.xlsx", ///
            sheet("Entrant swv Health") sheetreplace firstrow(varlabels)
    restore
preserve
    * 1. Sum up the weights for each year where the dummy == 1
    * This gives us the weighted population count per year/group
    collapse (sum) $wave [pw=dwt], by(total_waves)

    * 2. Calculate the Column Totals (Total weighted pop per year)
    * We need this to turn the counts into percentages
    foreach v of varlist $wave {
        egen total_`v' = total(`v')
        replace `v' = (`v' / total_`v') * 100
        drop total_`v'
    }

    * 3. Export to your existing Excel file
    export excel total_waves $waves using "$dir_work/attrition/Results_Attrition_all.xlsx", ///
        sheet("Wave_Participation") sheetreplace firstrow(variables)
restore

ssc install winsor2

preserve
    * 1. Create the winsorized variable ONLY for les_c4 == 1
    * This ensures the 5th and 95th percentiles are calculated based ONLY on this sub-group
    winsor2 obs_earnings_hourly if les_c4 == 1, cuts(5 95) suffix(_w)

    * 2. Collapse by total_waves, filtered for les_c4 == 1
    collapse (mean) mean_raw = obs_earnings_hourly ///
             (mean) mean_winsor = obs_earnings_hourly_w ///
             (p50) median_raw = obs_earnings_hourly ///
             (p50) median_winsor = obs_earnings_hourly_w [aw=dwt] ///
             if les_c4 == 1, by(total_waves)

    * 3. Label for the Excel Header
    label var total_waves "Total Waves"
    label var mean_raw "Original Mean"
    label var mean_winsor "Winsorized Mean (5%)"
    label var median_raw "Original Median"
    label var median_winsor "Winsorized Median (5%)"

    * 4. Export to Excel
    sort total_waves
    export excel total_waves mean_raw mean_winsor median_raw median_winsor ///
        using "$dir_work/attrition/Results_Attrition_all.xlsx", ///
        sheet("Earnings_by_Total_Waves") sheetreplace firstrow(varlabels)
restore


* Run the probit and store them


********************************************************************************
*3 Probit estimations
********************************************************************************	
* Probability model estimation models


probit entrant Dag Dgn_Women  Deh_c4_Na Deh_c4_Medium Deh_c4_Low ///
        Dcpst_Single  Les_c4_Student ///
       Les_c4_NotEmployed Les_c4_Retired  Ydses_c5_Q2 ///
       Ydses_c5_Q3 Ydses_c5_Q4 Ydses_c5_Q5  PL4 PL5 PL6 PL10 [pw= dwt]
estimates store m1

* 2. Run and store the Exiter model
probit exiter Dag Dgn_Women  Deh_c4_Na Deh_c4_Medium Deh_c4_Low ///
        Dcpst_Single  Les_c4_Student ///
       Les_c4_NotEmployed Les_c4_Retired  Ydses_c5_Q2 ///
       Ydses_c5_Q3 Ydses_c5_Q4 Ydses_c5_Q5  PL4 PL5 PL6 PL10 waves_until_now if waves_until_now>1  [pw= dwt]
estimates store m2

	
probit entrant Dag Dgn_Women  Deh_c4_Na Deh_c4_Medium Deh_c4_Low ///
        Dcpst_Single  Les_c4_Student ///
       Les_c4_NotEmployed Les_c4_Retired  Ydses_c5_Q2 ///
       Ydses_c5_Q3 Ydses_c5_Q4 Ydses_c5_Q5  PL4 PL5 PL6 PL10  [pw= dimlwt]
estimates store m3

* 2. Run and store the Exiter model
probit exiter Dag Dgn_Women  Deh_c4_Na Deh_c4_Medium Deh_c4_Low ///
        Dcpst_Single  Les_c4_Student ///
       Les_c4_NotEmployed Les_c4_Retired  Ydses_c5_Q2 ///
       Ydses_c5_Q3 Ydses_c5_Q4 Ydses_c5_Q5 PL4 PL5 PL6 PL10 waves_until_now if waves_until_now>1 [pw= dimlwt]
estimates store m4

* 3. Export 

esttab m1 m2 m3 m4 using final_results_all.rtf, replace ///
    b(3) se(3) r2 label ///
    mtitles("Entrants, cross" "Exiters, cross" "Entrants, long" "Exiters, long") ///
    title("Probit Analysis of Panel Dynamics")
	
	
	
*Compute average marginal effects
	

* Model 1: Entrants, cross-sectional weights

probit entrant Dag Dgn_Women  Deh_c4_Na Deh_c4_Medium Deh_c4_Low ///
        Dcpst_Single  Les_c4_Student ///
       Les_c4_NotEmployed Les_c4_Retired  Ydses_c5_Q2 ///
       Ydses_c5_Q3 Ydses_c5_Q4 Ydses_c5_Q5 PL4 PL5 PL6 PL10  [pw=dwt]

margins, dydx(*) post
estimates store m1_ame

* Model 2: Exiters, cross-sectional weights

probit exiter Dag Dgn_Women  Deh_c4_Na Deh_c4_Medium Deh_c4_Low ///
        Dcpst_Single  Les_c4_Student ///
       Les_c4_NotEmployed Les_c4_Retired  Ydses_c5_Q2 ///
       Ydses_c5_Q3 Ydses_c5_Q4 Ydses_c5_Q5 PL4 PL5 PL6 PL10 waves_until_now ///
       if waves_until_now>1 [pw=dwt]

margins, dydx(*) post
estimates store m2_ame



* Model 3: Entrants, longitudinal weights

probit entrant Dag Dgn_Women  Deh_c4_Na Deh_c4_Medium Deh_c4_Low ///
        Dcpst_Single  Les_c4_Student ///
       Les_c4_NotEmployed Les_c4_Retired  Ydses_c5_Q2 ///
       Ydses_c5_Q3 Ydses_c5_Q4 Ydses_c5_Q5 PL4 PL5 PL6 PL10  [pw=dimlwt]

margins, dydx(*) post
estimates store m3_ame



* Model 4: Exiters, longitudinal weights

probit exiter Dag Dgn_Women  Deh_c4_Na Deh_c4_Medium Deh_c4_Low ///
        Dcpst_Single  Les_c4_Student ///
       Les_c4_NotEmployed Les_c4_Retired  Ydses_c5_Q2 ///
       Ydses_c5_Q3 Ydses_c5_Q4 Ydses_c5_Q5 PL4 PL5 PL6 PL10 waves_until_now if waves_until_now>1 [pw= dimlwt]
	   
margins, dydx(*) post
estimates store m4_ame


* =========================
* Export AMEs
* =========================
esttab m1_ame m2_ame m3_ame m4_ame using final_results_ame.rtf, ///
    replace ///
    b(3) se(3) ///
    label ///
    mtitles("Entrants, cross" "Exiters, cross" ///
            "Entrants, long" "Exiters, long") ///
    title("Average Marginal Effects from Probit Models")
	
			 
cap log close


********************************************************************************
* ATTRITION GRAPHS: Distribution of total waves by wave and characteristics
********************************************************************************

local graphdir "$dir_work/attrition/Graphs"
cap mkdir "`graphdir'"


    * Create gender-partnership interactions
    capture drop Men_Partnered Men_Single Women_Partnered Women_Single

    gen Men_Partnered   = (Dcpst_Partnered == 1 & Dgn_Men == 1)
    gen Men_Single      = (Dcpst_Single == 1 & Dgn_Men == 1)
    gen Women_Partnered = (Dcpst_Partnered == 1 & Dgn_Women == 1)
    gen Women_Single    = (Dcpst_Single == 1 & Dgn_Women == 1)

    ************************************************************************
    * 1. Overall distribution of total_waves
    ************************************************************************
	
local graphdir "$dir_work/attrition/Graphs"
preserve

    collapse (sum) weighted_n=dwt, by(total_waves)

    * Calculate share of total weighted population
    egen double total_weight = total(weighted_n)
    gen double share = 100 * weighted_n / total_weight

    * Graph percentage shares
    graph bar share, ///
        over(total_waves, label(angle(0) labsize(vsmall))) ///
        blabel(bar, format(%3.0f) size(vsmall)) ///
        title("Distribution of total panel participation", size(medium)) ///
        b1title("Number of waves per individual", size(small)) ///
        ytitle("Share of individuals (%)", size(small)) ///
        ylabel(0(10)100, labsize(vsmall) format(%3.0f)) ///
        graphregion(color(white)) ///
        name(g_total_waves, replace)

    * Ensure the output directory exists
    cap mkdir "`graphdir'"

    * Export graph
    graph export "`graphdir'/01_distribution_total_waves.png", ///
        replace width(2000)

restore

********************************************************************************
* Weighted distribution of total_waves by unique individual
********************************************************************************

local graphdir "$dir_work/attrition/Graphs"
capture mkdir "`graphdir'"

preserve

    * Keep one observation per individual
    egen byte person_tag = tag(idperson)
    keep if person_tag == 1

    * Exclude missing values and invalid weights
    keep if !missing(total_waves, dwt) & dwt > 0

    * Calculate weighted population by total_waves
    collapse (sum) weighted_n=dwt, by(total_waves)

    * Calculate share of total weighted population
    egen double total_weight = total(weighted_n)
    gen double share = 100 * weighted_n / total_weight

    * Graph percentage shares
    graph bar share, ///
        over(total_waves, label(angle(0) labsize(vsmall))) ///
        blabel(bar, format(%3.0f) size(vsmall)) ///
        title("Distribution of total panel participation", size(medium)) ///
        b1title("Number of waves per individual", size(small)) ///
        ytitle("Share of individuals (%)", size(small)) ///
        ylabel(0(10)100, labsize(vsmall) format(%3.0f)) ///
        graphregion(color(white)) ///
        name(g_total_waves_unique, replace)

    * Export graph
    graph export ///
        "`graphdir'/01_distribution_total_waves_unique.png", ///
        replace width(2000)

restore


************************************************************************
* 3A. Weighted distribution by survey wave: FULL SAMPLE
* Retains all person-wave observations
************************************************************************
local graphdir "$dir_work/attrition/Graphs"
cap mkdir "`graphdir'"
preserve

    keep if !missing(total_waves, swv, dwt) & dwt > 0

    * Sum weights across all observations
    collapse (sum) weighted_n=dwt, by(swv total_waves)

    * Calculate percentages within each survey wave
    bysort swv: egen double wave_total = total(weighted_n)
    gen double percentage = 100 * weighted_n / wave_total

    label variable percentage "Weighted share (%)"

    * Graph
    graph bar percentage, ///
    over(total_waves, label(angle(45) labsize(vsmall))) ///
    over(swv, label(angle(0) labsize(vsmall))) ///
    asyvars stack ///
    title("Panel participation by survey wave: Full sample") ///
    b1title("Survey wave") ///
    ytitle("Weighted share (%)") ///
    ylabel(0(20)100, format(%3.0f) labsize(vsmall)) ///
    yscale(range(0 100)) ///
    graphregion(color(white)) ///
    legend(position(6) rows(2) size(vsmall)) ///
    name(g_wave_full, replace)

    graph export ///
        "`graphdir'/03a_total_waves_by_survey_wave_full.png", ///
        replace width(2400)


restore


************************************************************************
* 3B. Weighted distribution by survey wave: UNIQUE PERSON-WAVE
* Keeps one observation per idperson and swv
************************************************************************

preserve

    egen byte person_wave_tag = tag(idperson swv)

    keep if person_wave_tag == 1 ///
        & !missing(total_waves, swv, dwt) ///
        & dwt > 0

    * Sum weights for each wave and participation duration
    collapse (sum) weighted_n=dwt, by(swv total_waves)

    * Calculate percentages within each survey wave
    bysort swv: egen double wave_total = total(weighted_n)
    gen double percentage = 100 * weighted_n / wave_total

    label variable percentage "Weighted share (%)"

    * Graph
    graph bar percentage, ///
    over(total_waves, label(angle(45) labsize(vsmall))) ///
    over(swv, label(angle(0) labsize(vsmall))) ///
    asyvars stack ///
    title("Panel participation by survey wave: Unique person-wave") ///
    b1title("Survey wave") ///
    ytitle("Weighted share (%)") ///
    ylabel(0(20)100, format(%3.0f) labsize(vsmall)) ///
    yscale(range(0 100)) ///
    graphregion(color(white)) ///
    legend(position(6) rows(2) size(vsmall)) ///
    name(g_wave_unique, replace)

    graph export ///
        "`graphdir'/03b_total_waves_by_survey_wave_unique.png", ///
        replace width(2400)


restore


********************************************************************************
* Weighted distribution of total_waves by characteristic
* Assumes the globals have already been defined
********************************************************************************

local graphdir "$dir_work/attrition/Graphs"
capture mkdir "`graphdir'"

confirm variable idperson
confirm variable total_waves
confirm variable dwt

* Save original dataset
tempfile original
save "`original'", replace

********************************************************************************
* Loop over globals
********************************************************************************

global education Deh_c4_Na Deh_c4_High Deh_c4_Medium Deh_c4_Low

global age Dag_16_30 Dag_31_40 Dag_41_65 Dag_66_plus

global region IT1 IT2 IT3 IT4 IT5

global partnership Dcpst_Partnered Dcpst_Single

global activity Les_c4_Employed Les_c4_Student Les_c4_NotEmployed Les_c4_Retired

global income Ydses_c5_Q1 Ydses_c5_Q2 Ydses_c5_Q3 Ydses_c5_Q4 Ydses_c5_Q5

global hours Lhw_c5_Zero Lhw_c5_Ten Lhw_c5_Twenty Lhw_c5_Thirty Lhw_c5_Forty

global part_gender Men_Partnered Men_Single Women_Partnered Women_Single

global health Dhe_Poor Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent Dlltsd_able Dlltsd_disable


********************************************************************************
* Weighted distribution of total_waves by survey wave
* One combined graph per sociodemographic dimension

*Among respondents with high education who are observed in survey wave xx
*what percentage participated in 1 wave, 2 waves, 3 waves, and so on over the entire panel?

* Weighted distribution of total_waves by survey wave across all dimensions
********************************************************************************

local graphdir "$dir_work/attrition/Graphs"
cap mkdir "`graphdir'"
 
* Ensure the required baseline variables exist
confirm variable idperson
confirm variable swv
confirm variable total_waves
confirm variable dwt

* Define all dimensions and their corresponding categories using a local of locals (or parallel lists)
* Alternatively, we can run them sequentially in a clean outer loop over dimensions:

local dims gender_partnership education age region partnership activity income hours gender_partnership2

* Or even simpler, loop directly through each dimension's block using clear sub-loops:

foreach dim in gender_partnership education age region partnership activity income hours {

    * 1. Define categories and graph layout settings based on the dimension
    if "`dim'" == "gender_partnership" {
        local categories Men_Partnered Men_Single Women_Partnered Women_Single
        local cols 2
        local title "Panel participation by gender and partnership"
        local filename "part_gender_combined"
    }
    else if "`dim'" == "education" {
        local categories Deh_c4_Na Deh_c4_High Deh_c4_Medium Deh_c4_Low
        local cols 2
        local title "Panel participation by education"
        local filename "education_combined"
    }
    else if "`dim'" == "age" {
        local categories Dag_16_30 Dag_31_40 Dag_41_65 Dag_66_plus
        local cols 2
        local title "Panel participation by age"
        local filename "age_combined"
    }
    else if "`dim'" == "region" {
        local categories PL4 PL5 PL6 PL10
        local cols 3
        local title "Panel participation by region"
        local filename "region_combined"
    }
	
    else if "`dim'" == "partnership" {
        local categories Dcpst_Partnered Dcpst_Single
        local cols 2
        local title "Panel participation by partnership status"
        local filename "partnership_combined"
    }
    else if "`dim'" == "activity" {
        local categories Les_c4_Employed Les_c4_Student Les_c4_NotEmployed Les_c4_Retired
        local cols 2
        local title "Panel participation by activity status"
        local filename "activity_combined"
    }
    else if "`dim'" == "income" {
        local categories Ydses_c5_Q1 Ydses_c5_Q2 Ydses_c5_Q3 Ydses_c5_Q4 Ydses_c5_Q5
        local cols 3
        local title "Panel participation by income quintile"
        local filename "income_combined"
    }
    else if "`dim'" == "hours" {
        local categories Lhw_c5_Zero Lhw_c5_Ten Lhw_c5_Twenty Lhw_c5_Thirty Lhw_c5_Forty
        local cols 3
        local title "Panel participation by working hours"
        local filename "hours_combined"
    }


	else if "`dim'" == "health" {
        local categories Dhe_Poor Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent Dlltsd_able Dlltsd_disable
        local cols 3
        local title "Panel participation by Health"
        local filename "Health combined"
    }

    * 2. Process each category within the dimension
    local graphs ""
    foreach var of local categories {
        preserve

            keep if `var' == 1
            keep if !missing(total_waves, swv, dwt) & dwt > 0

            collapse (sum) weighted_n=dwt, by(swv total_waves)

            bysort swv: egen double wave_total = total(weighted_n)
            gen double percentage = 100 * weighted_n / wave_total

            graph bar percentage, ///
                over(total_waves, label(angle(45) labsize(vsmall))) ///
                over(swv, label(angle(0) labsize(vsmall))) ///
                asyvars stack ///
                title("`var'", size(small)) ///
                b1title("Survey wave") ///
                ytitle("Weighted share (%)") ///
                ylabel(0(20)100, format(%3.0f) labsize(vsmall)) ///
                yscale(range(0 100)) ///
                legend(position(6) rows(2) size(vsmall)) ///
                graphregion(color(white)) ///
                name(g_`var', replace)

            local graphs `graphs' g_`var'


        restore
    }

    * 3. Combine and export the graphs for this dimension
    graph combine `graphs', ///
        cols(`cols') ///
        title("`title'") ///
        graphregion(color(white)) ///
        name(g_`dim'_combined, replace)

    graph export "`graphdir'/`filename'.png", ///
        replace width(3000)
}


*** ----------------------------------------------------------------------------
*** Setup Output Directories and Globals
*** ----------------------------------------------------------------------------
local graphdir "$dir_work/attrition/Graphs"
cap mkdir "`graphdir'"



* Define variable groups and their corresponding legend labels & graph titles
global educ          Deh_c4_High Deh_c4_Medium Deh_c4_Low Deh_c4_Na
global educ_labels   1 "High" 2 "Medium" 3 "Low" 4 "Na"
global educ_title    "Education Composition"

global age          Dag_16_30 Dag_31_40 Dag_41_65 Dag_66_plus
global age_labels   1 "16-30" 2 "31-40" 3 "41-65" 4 "66+"
global age_title    "Age Group Composition"

global region       PL4 PL5 PL6 PL10
global region_labels 1 "PL4" 2 "PL5" 3 "PL6" 4 "PL10"
global region_title "Regional Composition"

global partnership  Dcpst_Partnered Dcpst_Single
global partnership_labels 1 "Partnered" 2 "Single"
global partnership_title "Partnership Status Composition"

global activity     Les_c4_Employed Les_c4_Student Les_c4_NotEmployed Les_c4_Retired
global activity_labels 1 "Employed" 2 "Student" 3 "Not Employed" 4 "Retired"
global activity_title "Activity Status Composition"

global income       Ydses_c5_Q1 Ydses_c5_Q2 Ydses_c5_Q3 Ydses_c5_Q4 Ydses_c5_Q5
global income_labels 1 "Q1" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5"
global income_title "Income Quintile Composition"

global hours        Lhw_c5_Zero Lhw_c5_Ten Lhw_c5_Twenty Lhw_c5_Thirty Lhw_c5_Forty
global hours_labels 1 "0 hrs" 2 "1-10 hrs" 3 "11-20 hrs" 4 "21-30 hrs" 5 "31+ hrs"
global hours_title  "Working Hours Composition"

global part_gender  Men_Partnered Men_Single Women_Partnered Women_Single
global part_gender_labels 1 "Men: Partnered" 2 "Men: Single" 3 "Women: Partnered" 4 "Women: Single"
global part_gender_title "Gender & Partnership Composition"


global health          Dhe_Poor Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent Dlltsd_able Dlltsd_disabl
global health_labels   1 "Poor" 2 "Fair" 3 "Good" 4 "Very Good" 5 "Excellent" 6 "Able" 7 "Disable"
global health_title    "Health Composition"

*** List of all demographic group names to iterate over
local group_list age region partnership activity income hours part_gender health

*** ----------------------------------------------------------------------------
*** Execution Loop
*** ----------------------------------------------------------------------------
confirm variable idperson swv total_waves dwt

foreach grp in `group_list' {

    preserve

        * 1. Keep valid complete cases
        keep if !missing(total_waves, swv, dwt) & dwt > 0

        * 2. Dynamically create weighted variables and collapse list
        local var_list   ${`grp'}
        local legend_lbl ${`grp'_labels}
        local grp_title  ${`grp'_title}

        local collapse_cmd ""
        local pct_vars     ""
        local replace_cmds ""
        local k = 1

        foreach v of local var_list {
            * Generate weighted variable for category v
            gen double wt_`k' = dwt if `v' == 1
            
            * Build collapse syntax: (sum) w_1 = wt_1 (sum) w_2 = wt_2 ...
            local collapse_cmd `collapse_cmd' (sum) w_`k' = wt_`k'
            
            * Keep track of percentage variables to create
            local pct_vars `pct_vars' pct_`k'
            
            local ++k
        }

        * 3. Collapse weighted counts by total waves
        collapse `collapse_cmd', by(total_waves)

        * 4. Replace missing sums with 0
        local num_cats : word count `var_list'
        forval i = 1/`num_cats' {
            replace w_`i' = 0 if missing(w_`i')
        }

        * 5. Calculate row total weighted count
        egen double total_n = rowtotal(w_1 - w_`num_cats')

        * 6. Calculate percentage shares within total_waves
        forval i = 1/`num_cats' {
            gen double pct_`i' = cond(total_n > 0, 100 * w_`i' / total_n, 0)
            replace pct_`i' = 0 if missing(pct_`i')
        }

        * 7. Generate Stacked Bar Graph
        graph bar `pct_vars', ///
            over(total_waves, label(angle(0) labsize(small))) ///
            asyvars stack ///
            title("`grp_title' by total waves participated", size(medium)) ///
            b1title("Total waves participated") ///
            ytitle("Share (%)") ///
            ylabel(0(20)100, format(%3.0f) labsize(vsmall)) ///
            yscale(range(0 100)) ///
            legend(order(`legend_lbl') position(6) rows(1) size(vsmall)) ///
            graphregion(color(white)) ///
            name(g_`grp'_share, replace)

        * 8. Export Graph
        graph export "`graphdir'/`grp'_shares_by_waves.png", replace width(3000)



    restore
}

*** ----------------------------------------------------------------------------
*** Setup Output Directories and Globals
*** ----------------------------------------------------------------------------
local graphdir "$dir_work/attrition/Graphs"
cap mkdir "`graphdir'"
global educ          Deh_c4_High Deh_c4_Medium Deh_c4_Low Deh_c4_Na
global educ_labels   1 "High" 2 "Medium" 3 "Low" 4 "Na"
global educ_title    "Education Composition"
* Define variable groups, custom legend labels, and graph titles
global age          Dag_16_30 Dag_31_40 Dag_41_65 Dag_66_plus
global age_labels   1 "16-30" 2 "31-40" 3 "41-65" 4 "66+"
global age_title    "Age Group Composition"

global region       PL4 PL5 PL6 PL10
global region_labels 1 "PL4" 2 "PL5" 3 "PL6" 4 "PL10"
global region_title "Regional Composition"

global partnership  Dcpst_Partnered Dcpst_Single
global partnership_labels 1 "Partnered" 2 "Single"
global partnership_title "Partnership Status Composition"

global activity     Les_c4_Employed Les_c4_Student Les_c4_NotEmployed Les_c4_Retired
global activity_labels 1 "Employed" 2 "Student" 3 "Not Employed" 4 "Retired"
global activity_title "Activity Status Composition"

global income       Ydses_c5_Q1 Ydses_c5_Q2 Ydses_c5_Q3 Ydses_c5_Q4 Ydses_c5_Q5
global income_labels 1 "Q1" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5"
global income_title "Income Quintile Composition"

global hours        Lhw_c5_Zero Lhw_c5_Ten Lhw_c5_Twenty Lhw_c5_Thirty Lhw_c5_Forty
global hours_labels 1 "0 hrs" 2 "1-10 hrs" 3 "11-20 hrs" 4 "21-30 hrs" 5 "31+ hrs"
global hours_title  "Working Hours Composition"

global part_gender  Men_Partnered Men_Single Women_Partnered Women_Single
global part_gender_labels 1 "Men: Partnered" 2 "Men: Single" 3 "Women: Partnered" 4 "Women: Single"
global part_gender_title "Gender & Partnership Composition"

global health          Dhe_Poor Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent Dlltsd_able Dlltsd_disabl
global health_labels   1 "Poor" 2 "Fair" 3 "Good" 4 "Very Good" 5 "Excellent" 6 "Able" 7 "Disable"
global health_title    "Health Composition"

*** List of demographic groups to process
local group_list age region partnership activity income hours part_gender health

*** ----------------------------------------------------------------------------
*** Execution Loop (Grouped by swv and total_waves)
*** ----------------------------------------------------------------------------
confirm variable idperson swv total_waves dwt

foreach grp in `group_list' {

    preserve

        * 1. Filter complete cases
        keep if !missing(total_waves, swv, dwt) & dwt > 0

        * 2. Prepare dynamic variable lists
        local var_list   ${`grp'}
        local legend_lbl ${`grp'_labels}
        local grp_title  ${`grp'_title}

        local collapse_cmd ""
        local pct_vars     ""
        local k = 1

        foreach v of local var_list {
            gen double wt_`k' = dwt if `v' == 1
            local collapse_cmd `collapse_cmd' (sum) w_`k' = wt_`k'
            local pct_vars `pct_vars' pct_`k'
            local ++k
        }

        * 3. Collapse weighted counts by BOTH swv AND total_waves
        collapse `collapse_cmd', by(swv total_waves)

        * 4. Replace missing counts with 0
        local num_cats : word count `var_list'
        forval i = 1/`num_cats' {
            replace w_`i' = 0 if missing(w_`i')
        }

        * 5. Calculate row total weighted count within (swv, total_waves) cell
        egen double total_n = rowtotal(w_1 - w_`num_cats')

        * 6. Calculate percentage shares within each cell
        forval i = 1/`num_cats' {
            gen double pct_`i' = cond(total_n > 0, 100 * w_`i' / total_n, 0)
            replace pct_`i' = 0 if missing(pct_`i')
        }

        * 7. Graph stacked bars across total_waves grouped inside each swv year
        graph bar `pct_vars', ///
            over(total_waves, label(labsize(tiny))) ///
            over(swv, label(labsize(vsmall) angle(0))) ///
            asyvars stack ///
            title("`grp_title' by Total Waves and Survey Wave", size(medium)) ///
            b1title("Total Waves Participated (nested in Survey Wave)") ///
            ytitle("Share (%)") ///
            ylabel(0(20)100, format(%3.0f) labsize(vsmall)) ///
            yscale(range(0 100)) ///
            legend(order(`legend_lbl') position(6) rows(1) size(vsmall)) ///
            graphregion(color(white)) ///
            name(g_`grp'_swv_share, replace)

        * 8. Export Graph
        graph export "`graphdir'/`grp'_shares_by_swv_waves.png", replace width(3600)

   
  
    restore
}


*** ----------------------------------------------------------------------------
*** Setup Output Directories and Globals
*** ----------------------------------------------------------------------------
local graphdir "$dir_work/attrition/Graphs/Entrants_Exiters"
cap mkdir "`graphdir'"

global educ         Deh_c4_High Deh_c4_Medium Deh_c4_Low Deh_c4_Na
global educ_labels   1 "High" 2 "Medium" 3 "Low" 4 "Na"
global educ_title    "Education Composition"

global age          Dag_16_30 Dag_31_40 Dag_41_65 Dag_66_plus
global age_labels   1 "16-30" 2 "31-40" 3 "41-65" 4 "66+"
global age_title    "Age Group Composition"

global region       PL4 PL5 PL6 PL10
global region_labels 1 "PL4" 2 "PL5" 3 "PL6" 4 "PL10"
global region_title "Regional Composition"

global partnership  Dcpst_Partnered Dcpst_Single
global partnership_labels 1 "Partnered" 2 "Single"
global partnership_title "Partnership Status Composition"

global activity     Les_c4_Employed Les_c4_Student Les_c4_NotEmployed Les_c4_Retired
global activity_labels 1 "Employed" 2 "Student" 3 "Not Employed" 4 "Retired"
global activity_title "Activity Status Composition"

global income       Ydses_c5_Q1 Ydses_c5_Q2 Ydses_c5_Q3 Ydses_c5_Q4 Ydses_c5_Q5
global income_labels 1 "Q1" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5"
global income_title "Income Quintile Composition"

global hours        Lhw_c5_Zero Lhw_c5_Ten Lhw_c5_Twenty Lhw_c5_Thirty Lhw_c5_Forty
global hours_labels 1 "0 hrs" 2 "1-10 hrs" 3 "11-20 hrs" 4 "21-30 hrs" 5 "31+ hrs"
global hours_title  "Working Hours Composition"

global part_gender  Men_Partnered Men_Single Women_Partnered Women_Single
global part_gender_labels 1 "Men: Partnered" 2 "Men: Single" 3 "Women: Partnered" 4 "Women: Single"
global part_gender_title "Gender & Partnership Composition"

global health          Dhe_Poor Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent Dlltsd_able Dlltsd_disabl
global health_labels   1 "Poor" 2 "Fair" 3 "Good" 4 "Very Good" 5 "Excellent" 6 "Able" 7 "Disable"
global health_title    "Health Composition"

*** List of demographic groups to process
local group_list educ age region partnership activity income hours part_gender health

*** ----------------------------------------------------------------------------
*** Execution Loop (Entrants vs. Exiters by swv)
*** ----------------------------------------------------------------------------
confirm variable idperson swv dwt entrant exiter

foreach grp in `group_list' {

    preserve

        * 1. Keep valid complete cases for either entrants or exiters
        keep if !missing(swv, dwt) & dwt > 0 & (entrant == 1 | exiter == 1)

        * 2. Prepare dynamic variable lists
        local var_list   ${`grp'}
        local legend_lbl ${`grp'_labels}
        local grp_title  ${`grp'_title}

        * Create an indicator for status category
        gen byte status = .
        replace status = 1 if entrant == 1
        replace status = 2 if exiter == 1
        label define status_lbl 1 "Ent." 2 "Exi."
        label values status status_lbl

        local collapse_cmd ""
        local pct_vars     ""
        local k = 1

        foreach v of local var_list {
            gen double wt_`k' = dwt if `v' == 1
            local collapse_cmd `collapse_cmd' (sum) w_`k' = wt_`k'
            local pct_vars `pct_vars' pct_`k'
            local ++k
        }

        * 3. Collapse weighted counts by swv AND status (Entrant vs Exiter)
        collapse `collapse_cmd', by(swv status)

        * 4. Replace missing counts with 0
        local num_cats : word count `var_list'
        forval i = 1/`num_cats' {
            replace w_`i' = 0 if missing(w_`i')
        }

        * 5. Calculate row total weighted count within (swv, status) cell
        egen double total_n = rowtotal(w_1 - w_`num_cats')

        * 6. Calculate percentage shares within each cell
        forval i = 1/`num_cats' {
            gen double pct_`i' = cond(total_n > 0, 100 * w_`i' / total_n, 0)
            replace pct_`i' = 0 if missing(pct_`i')
        }

        * 7. Stacked bar graph comparing Entrants vs Exiters clustered under swv
        graph bar `pct_vars', ///
            over(status, label(labsize(vsmall))) ///
            over(swv, label(labsize(vsmall) angle(0))) ///
            asyvars stack ///
            title("`grp_title': Entrants vs. Exiters by Survey Wave", size(medium)) ///
            b1title("Survey Wave (nested: Entrants | Exiters)") ///
            ytitle("Share (%)") ///
            ylabel(0(20)100, format(%3.0f) labsize(vsmall)) ///
            yscale(range(0 100)) ///
            legend(order(`legend_lbl') position(6) rows(1) size(vsmall)) ///
            graphregion(color(white)) ///
            name(g_`grp'_ent_ext, replace)

        * 8. Export Graph
        graph export "`graphdir'/`grp'_entrants_exiters_by_swv.png", replace width(3600)

        * 9. Rename percentage variables for clean Excel export
        local k = 1
        foreach v of local var_list {
            rename pct_`k' pct_`v'
            local ++k
        }

        * 10. Export to Excel
   

    restore
}


*** ----------------------------------------------------------------------------
*** Setup Output Directories and Globals
*** ----------------------------------------------------------------------------
local graphdir "$dir_work/attrition/Graphs/Entrants_Exiters"
cap mkdir "`graphdir'"

global educ          Deh_c4_High Deh_c4_Medium Deh_c4_Low Deh_c4_Na
global educ_labels   1 "High" 2 "Medium" 3 "Low" 4 "Na"
global educ_title    "Education Composition"

global age          Dag_16_30 Dag_31_40 Dag_41_65 Dag_66_plus
global age_labels   1 "16-30" 2 "31-40" 3 "41-65" 4 "66+"
global age_title    "Age Group Composition"

global region       PL4 PL5 PL6 PL10
global region_labels 1 "PL4" 2 "PL5" 3 "PL6" 4 "PL10"
global region_title "Regional Composition"

global partnership  Dcpst_Partnered Dcpst_Single
global partnership_labels 1 "Partnered" 2 "Single"
global partnership_title "Partnership Status Composition"

global activity     Les_c4_Employed Les_c4_Student Les_c4_NotEmployed Les_c4_Retired
global activity_labels 1 "Employed" 2 "Student" 3 "Not Employed" 4 "Retired"
global activity_title "Activity Status Composition"

global income       Ydses_c5_Q1 Ydses_c5_Q2 Ydses_c5_Q3 Ydses_c5_Q4 Ydses_c5_Q5
global income_labels 1 "Q1" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5"
global income_title "Income Quintile Composition"

global hours        Lhw_c5_Zero Lhw_c5_Ten Lhw_c5_Twenty Lhw_c5_Thirty Lhw_c5_Forty
global hours_labels 1 "0 hrs" 2 "1-10 hrs" 3 "11-20 hrs" 4 "21-30 hrs" 5 "31+ hrs"
global hours_title  "Working Hours Composition"

global part_gender  Men_Partnered Men_Single Women_Partnered Women_Single
global part_gender_labels 1 "Men: Partnered" 2 "Men: Single" 3 "Women: Partnered" 4 "Women: Single"
global part_gender_title "Gender & Partnership Composition"


global health          Dhe_Poor Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent Dlltsd_able Dlltsd_disabl
global health_labels   1 "Poor" 2 "Fair" 3 "Good" 4 "Very Good" 5 "Excellent" 6 "Able" 7 "Disable"
global health_title    "Health Composition"
*** List of demographic groups to process
local group_list educ age region partnership activity income hours part_gender health

*** ----------------------------------------------------------------------------
*** Execution Loop (Entrants vs. Exiters - Pooled / Overall)
*** ----------------------------------------------------------------------------
confirm variable idperson dwt entrant exiter

foreach grp in `group_list' {

    preserve

        * 1. Keep valid complete cases for either entrants or exiters
        keep if !missing(dwt) & dwt > 0 & (entrant == 1 | exiter == 1)

        * 2. Prepare dynamic variable lists
        local var_list   ${`grp'}
        local legend_lbl ${`grp'_labels}
        local grp_title  ${`grp'_title}

        * Create an indicator for status category
        gen byte status = .
        replace status = 1 if entrant == 1
        replace status = 2 if exiter == 1
        label define status_lbl 1 "Entrants" 2 "Exiters"
        label values status status_lbl

        local collapse_cmd ""
        local pct_vars     ""
        local k = 1

        foreach v of local var_list {
            gen double wt_`k' = dwt if `v' == 1
            local collapse_cmd `collapse_cmd' (sum) w_`k' = wt_`k'
            local pct_vars `pct_vars' pct_`k'
            local ++k
        }

        * 3. Collapse weighted counts by status only (Entrant vs Exiter)
        collapse `collapse_cmd', by(status)

        * 4. Replace missing counts with 0
        local num_cats : word count `var_list'
        forval i = 1/`num_cats' {
            replace w_`i' = 0 if missing(w_`i')
        }

        * 5. Calculate row total weighted count within status cell
        egen double total_n = rowtotal(w_1 - w_`num_cats')

        * 6. Calculate percentage shares within each status
        forval i = 1/`num_cats' {
            gen double pct_`i' = cond(total_n > 0, 100 * w_`i' / total_n, 0)
            replace pct_`i' = 0 if missing(pct_`i')
        }

        * 7. Stacked bar graph with integer bar labels (no decimals, tiny size)
        graph bar `pct_vars', ///
            over(status, label(labsize(small))) ///
            asyvars stack ///
            blabel(bar, pos(center) format(%3.0f) size(vsmall) color(white)) ///
            title("`grp_title': Entrants vs. Exiters", size(medium)) ///
            b1title("Status") ///
            ytitle("Share (%)") ///
            ylabel(0(20)100, format(%3.0f) labsize(vsmall)) ///
            yscale(range(0 100)) ///
            legend(order(`legend_lbl') position(6) rows(1) size(vsmall)) ///
            graphregion(color(white)) ///
            name(g_`grp'_ent_ext, replace)

        * 8. Export Graph
        graph export "`graphdir'/`grp'_entrants_exiters_nowave.png", replace width(3000)

        * 9. Rename percentage variables for clean Excel export
        local k = 1
        foreach v of local var_list {
            rename pct_`k' pct_`v'
            local ++k
        }

        * 10. Export to Excel
        

    restore
}

graph close _all