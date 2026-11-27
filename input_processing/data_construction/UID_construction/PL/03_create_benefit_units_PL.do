/*******************************************************************************
* PROJECT:              SimPaths EU
* DO-FILE NAME:         03_create_benefit_units.do
* DESCRIPTION:          Constructs benefit units and screens observations
*                       for consistency with SimPaths assumptions.
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
*   This do-file constructs benefit units from the EU-SILC household
*   structure, applying the household formation and family relationship
*   assumptions used in SimPaths. It also identifies and screens
*   observations that cannot be consistently represented in the model.
*
*   -----------------------------------------------------------------------
*    Household formation rules and assumptions
*   -----------------------------------------------------------------------
*   SimPaths distinguishes between responsible adults, dependent children
*   and other household members. Individuals are assigned household roles
*   according to their family relationships and circumstances.
*
*   The following rules govern household formation in the simulation:
*
*   1. A household is headed by a responsible adult or couple. Additional
*      couples form separate households, including couples where one or
*      both partners are below the usual age of leaving home (18).
*
*   2. Individuals below age 18 are generally treated as dependent
*      children, unless they are partnered or have dependent children
*      of their own. These individuals are treated as responsible adults.
*
*   3. Adult children living with their parents are assumed to leave
*      the parental household and form their own households.
*
*   4. Dependent children are assumed to live with their mother where
*      she is identified, otherwise with their father. Children without
*      identified parents are treated as orphans for the purposes of
*      benefit-unit construction.
*
*   -----------------------------------------------------------------------
*    Benefit unit construction
*   -----------------------------------------------------------------------
*   Benefit units are identified within observed EU-SILC households using
*   partnership and parent-child relationships.
*
*   - Couples form a benefit unit, together with their dependent children.
*   - Single adults form separate benefit units, including adults living
*     with their parents.
*   - Multiple benefit units may therefore exist within one household,
*     particularly in multigenerational households.
*   - Children are assigned to their mother's benefit unit where possible,
*     otherwise to their father's benefit unit.
*
*   Before benefit-unit construction, children in households containing
*   no adults are reassigned to an identified parent's household where
*   that parent can be located in the same survey wave.
*
*   -----------------------------------------------------------------------
*    Treatment of orphans
*   -----------------------------------------------------------------------
*   Children without identified mother or father IDs cannot be assigned
*   to a parental benefit unit using the observed family relationships.
*
*   Where possible, a surrogate parent is selected from the adults in
*   the child's household, subject to the following assumptions:
*
*   - The adult must be between 15 and 50 years older than the child.
*   - Among eligible adults, the individual whose age difference is
*     closest to 20 years is selected.
*   - The selected adult is recorded as the surrogate mother or father
*     according to their sex.
*   - The child is assigned to the selected adult's benefit unit.
*   - Where the selected surrogate mother has a partner, that partner
*     is also assigned as the child's surrogate father.
*
*   Children for whom no eligible surrogate parent can be identified
*   and who remain without a benefit unit are excluded.
*
*   -----------------------------------------------------------------------
*    Sample screening and consistency checks
*   -----------------------------------------------------------------------
*   The file identifies and excludes observations or benefit units that
*   cannot be represented consistently within the SimPaths structure,
*   including cases involving:
*
*   - Missing information required for benefit-unit construction.
*   - Orphans who cannot be assigned to a valid benefit unit.
*   - Underage partnerships or parent-child relationships that cannot
*     be reconciled with the model's household formation assumptions.
*
*   Where possible, benefit-unit relationships are adjusted to retain
*   households containing teenage parents and their children.
*
*   -----------------------------------------------------------------------
*    Benefit unit variables and output
*   -----------------------------------------------------------------------
*   The file constructs benefit-unit identifiers, partner and family
*   relationships, and benefit-unit-level home ownership information.
*
*   Final checks assess the consistency of benefit-unit membership and
*   family relationships before saving the dataset for subsequent
*   initial-population construction.
*
* TO DO:
*******************************************************************************/

cap log close 
//log using "$dir_log/03_drop_hholds_create_benefit_units.log", replace

* Load data 
use "$dir_data/${country}-SILC_pooled_all_obs_02.dta", clear 

fre swv 


/************** STANDARDISE RELATIONSHIPS AND IDENTIFY ADULTS *****************/

* Recode same sex couples as singles
replace idpartner = -9 if (ssscp == 1)
replace dcpst = 2 if (ssscp == 1)

foreach vv in dgnsp dagsp dehsp_c3 dhesp lessp_c3 lessp_c4 {
	
	replace `vv' = -9 if (ssscp == 1)
	
}
replace ssscp = 0 if idpartner == -9   
//fre ssscp


* Establish Adult/Child status
/*
Individuals below the age of responsibility are classified as children unless 
they are in a partnership or have their own dependent children

Use flag here to capture the individuals < 18 who are in a partnership.
*/
count if dag == -9

gen child = dag < ${age_becomes_responsible} & flag_young_partnership == 0 ///
	& dnc == 0 	

gen adult = 1 - child 

sum child adult // 82% adults 
tab adult child, col

gen partnered = (idpartner > 0) 

tab child partnered 

* Check if there are hhlds without adult(s)
assert child == 1 - adult 
cap drop num_adults  

bys swv idhh: egen num_adults = total(adult)

fre num_adults // 12 households don't contain any adults

fre idhh if num_adults == 0 
/*
--------------------------------------------------------------------
                       |      Freq.    Percent      Valid       Cum.
-----------------------+--------------------------------------------
Valid   220142378001   |          1       8.33       8.33       8.33
        220142482401   |          1       8.33       8.33      16.67
        320117060501   |          1       8.33       8.33      25.00
        320117065902   |          1       8.33       8.33      33.33
        320117468301   |          1       8.33       8.33      41.67
        320153025101   |          1       8.33       8.33      50.00
        420128104401   |          1       8.33       8.33      58.33
        12022118890201 |          1       8.33       8.33      66.67
        12022120440001 |          1       8.33       8.33      75.00
        22023263590000 |          1       8.33       8.33      83.33
        32020742660001 |          1       8.33       8.33      91.67
        32024306900101 |          1       8.33       8.33     100.00
        Total          |         12     100.00     100.00           
--------------------------------------------------------------------

Some children of these children have the same idhh as their parents. 
Address before constructing the benefit units. 
Automated fix: look up the parent's idhh by idmother / idfather and assign it 
to the child. Children with no parent in the samplefall through as true 
leftovers and are handled in the orphan section below.
*/

* Preserve original household identifier
clonevar idhh_original = idhh

* Save lookup: swv + idperson => idhh (assume error is on the child's side only)
preserve

	keep swv idperson idhh

	duplicates drop swv idperson, force
	rename idperson lookup_id
	rename idhh idhh_parent
	
	save "$dir_data/temp_hh_lookup.dta", replace

restore

* Identify children needing fix 
gen needs_hh_fix = (child == 1 & num_adults == 0)
count if needs_hh_fix

* Assign to mother's household
gen double lookup_id = idmother if needs_hh_fix == 1 & idmother > 0

merge m:1 swv lookup_id using "$dir_data/temp_hh_lookup.dta", ///
	keep(master match) nogen
	
replace idhh = idhh_parent if needs_hh_fix & !mi(idhh_parent)

drop idhh_parent lookup_id

* Recheck 
drop num_adults

bys swv idhh: egen num_adults = total(adult)
replace needs_hh_fix = (child == 1 & num_adults == 0)
count if needs_hh_fix

* Assign remaining to father's household
gen double lookup_id = idfather if needs_hh_fix & idfather > 0

merge m:1 swv lookup_id using "$dir_data/temp_hh_lookup.dta", ///
	keep(master match) nogen
	
replace idhh = idhh_parent if needs_hh_fix & !mi(idhh_parent)

drop idhh_parent lookup_id

* Recheck 
drop num_adults
bys swv idhh: egen num_adults = total(adult)

* Identify reassigned observations
gen byte flag_hh_reassigned = ///
    idhh != idhh_original & ///
    !missing(idhh, idhh_original)

tab flag_hh_reassigned

* Report leftovers: children with no parent found in sample
count if child == 1 & num_adults == 0
fre idhh if child == 1 & num_adults == 0

/*
Leftovers: 1 child < 18 in adult-less hholds with no parent in the sample.
*/

drop needs_hh_fix idhh_original


/************************** CREATE BENEFIT UNIT IDS ***************************/
* Set benefit units
cap drop idbenefitunit
cap drop idbupartner 

cap gen long idbenefitunit = .
cap gen long idbupartner = .

format idbenefitunit %19.0g
format idbupartner %19.0g

lab var idbenefitunit "ID: Unique cross wave identifier of benefit unit"

* Assign first couples 
/*
Logic of code here is to populate all in the hh and remove if not in the 
same benefit unit. 
*/ 
order swv idhh idbenefitunit idbupartner idperson idpartner idmother ///
	idfather dag dnc partnered
	
gsort swv idhh -partnered -dag idperson 
/*
Sort hh members in descending order by partnership status and then age 
(this ensures that partnered adults go first) 
*/

bys swv idhh: replace idbenefitunit = idperson[1] 
	//oldest person becomes head of first benefit unit 

bys swv idhh: replace idbupartner = idpartner[1] 
	//partner of oldest person becomes first benefit unit partner 

replace idbupartner = . if idbupartner == -9

* Remove those who do not belong to first benefit unit  
* Adults 
replace idbupartner = . if (adult == 1 & idperson != idbenefitunit & ///
	idpartner != idbenefitunit) 
	//remove partner id for other adults in hh who are not head or partner 

replace idbenefitunit = . if (adult == 1 & idperson != idbenefitunit & ///
	idpartner != idbenefitunit) 
	//remove bu id for other adults in hh who are not head or partner 

* Children
replace idbupartner = . if (child == 1 & idfather != idbenefitunit & ///
	idmother != idbenefitunit & ((idfather != idbupartner & ///
	idmother != idbupartner) | idbupartner < 0)) 
	//remove partner id for kids that are not head's or partner's

replace idbenefitunit = . if (child == 1 & idfather != idbenefitunit & ///
	idmother != idbenefitunit & ((idfather != idbupartner & ///
	idmother != idbupartner) & idbupartner > 0)) 
	//remove bu id for kids that are not head's or partner's

//count if idhh == idhh[_n-1] & partnered == 0 & partner[_n-1] == 1 & ///
//	idbenefitunit[_n-1] == . 

* Assign single adults living with parents to their own ben unit 
/* 
Their children are assigned to them later.
*/	

replace idbenefitunit = idperson if (missing(idbenefitunit) & adult == 1 & ///
	(missing(idpartner) | idpartner < 0)) 	
				
/* 
Create new ben unit for adults in hh who are partnered but not in the first 
ben unit 
*/
// Loop over number of couples in a hh that constitute an additional ben unit 
forvalues i = 1/3 {
		
	gsort swv idhh partnered idbenefitunit -dag idperson 
		/* 
		Sort so those without a partner go before those with and partnered
		individual who have been assigned a ben unit come before those who 
		haven't. Have children and single adults before the partnered so that 
		they are not impacted by the fill down. 
		*/
			
	* Create next benefit unit id 		
	bys swv idhh: replace idbenefitunit = idperson if ///
		(missing(idbenefitunit) & adult == 1 & partnered == 1 & ///
		!missing(idbenefitunit[_n-1]) & !missing(idbupartner[_n-1]))
		
	* Assign ben unit partner id 
	replace idbupartner = idpartner if (missing(idbupartner) & ///
		idbenefitunit == idperson & !missing(idpartner) & idpartner > 0)  

	* Fill down idbu to the rest of the unassigned couples in the hh 
	replace idbenefitunit = idbenefitunit[_n-1] if idhh == idhh[_n-1] & ///
		swv == swv[_n-1] & idbenefitunit == .  & partnered == 1 
	
	* Only keep benefit unit id for the partner 
	replace idbenefitunit = . if idbenefitunit != idpartner & ///
		idbupartner == . & partnered == 1 	
	
	* Assign ben unit partner id to the partner 
	replace idbupartner = idperson if idbenefitunit != . & ///
		idbupartner == . & partnered == 1 
	
} 

* Done? Any unassigned couples? 
count if adult == 1 & idbenefitunit == . & partnered == 1  
	// 0 partnered adults still have no benefit unit
recode idbupartner (. = -9) 

* Check if all adults are assigned to ben units 
count  if adult == 1 & idbenefitunit == .  // 0 obs
assert idbenefitunit != . if adult == 1 

gsort swv idhh -partnered idbenefitunit -dag idperson 

** Assign remaining children to benefit units
* Assign children to their mothers' benefit unit (where they are head or prtnr) 
gen count = 1 
bysort swv idhh: gen ttl_hh = sum(count)
replace ttl_hh = . if idbenefitunit == . 

gsort swv idhh -partnered idbenefitunit -dag idperson 

sum ttl_hh 
local max_n_bu = r(max)

forvalues i = 1/`max_n_bu' {
	
	replace idbenefitunit = idbenefitunit[_n-`i'] if idmother > 0 & ///
		missing(idbenefitunit) & child == 1 & ///
		(idmother == idbenefitunit[_n-`i'] | idmother == idbupartner[_n-`i'])
		
	replace idbupartner = idbupartner[_n-`i'] if idmother > 0 & ///
		idbupartner == -9 & child == 1 & ///
		(idmother == idbenefitunit[_n-`i'] | idmother == idbupartner[_n-`i'])	
	
} 

* Assign remaining kids to their father's ben unit 
forvalues i = 1/`max_n_bu' {
	
	replace idbenefitunit = idbenefitunit[_n-`i'] if idfather > 0 & ///
		missing(idbenefitunit) & child == 1 & ///
		(idfather == idbenefitunit[_n-`i'] | idfather == idbupartner[_n-`i']) 
		
	replace idbupartner = idbupartner[_n-`i'] if idfather > 0 & ///
		idbupartner == -9 & child == 1 & ///
		(idfather == idbenefitunit[_n-`i'] | idfather == idbupartner[_n-`i'])	
	
} 

drop ttl_hh count 

gsort swv idhh -partnered idbenefitunit -dag idperson 

* Check if all kids are assigned 
count if child == 1 & idbenefitunit == . 	// 1,854 children not assigned 

cap gen orphan = (idfather < 0 & idmother < 0 & child == 1)
fre orphan if idbenefitunit == . 	// 1,854 obs 
/*
=> all remaining are orphans i.e. don't have any information in the dataset 
about the mother or the father. 
*/

gen flag_orphan = (orphan == 1)
lab var flag_orphan ///
"FLAG: =1 if number of children in dataset that don't report mother or father id"

cap drop n_orphan
bys stm idhh: egen n_orphan = sum(orphan)  
fre n_orphan	
/* 
-----------------------------------------------------------
              |      Freq.    Percent      Valid       Cum.
--------------+--------------------------------------------
Valid   0     |     580889      98.92      98.92      98.92
        1     |       4421       0.75       0.75      99.67
        2     |       1390       0.24       0.24      99.91
        3     |        320       0.05       0.05      99.96
        4     |         94       0.02       0.02      99.98
        5     |         96       0.02       0.02      99.99
        6     |         10       0.00       0.00      99.99
        8     |         22       0.00       0.00     100.00
        9     |         13       0.00       0.00     100.00
        Total |     587255     100.00     100.00           
-----------------------------------------------------------
*/
order stm idhh idperson idpartner idfather idmother dag dgn adult orphan ///
	n_orphan 


/***************************** ADDRESS ORPHANS ********************************/
/*
Some children have not been linked to parents during benefit unit construction. 

Assign these "orphans" to adults in the household who are most likely to be 
their parents based on age.

In this iteration restrict potential parents to adults who are between 15 and 50
years older than the orphan. Among eligible adults, select the individual whose 
age is closest to the orphan's age plus 20 years.

If no eligible adult is identified, leave the orphan without an assigned
surrogate parent for subsequent screening.
*/
	
* Create variables storing ages for all orphans in hh 
preserve 

	keep if n_orphan > 0 
	keep swv idhh idperson idpartner idfather idmother dag dgn adult orphan ///
		n_orphan
	keep if orphan == 1

	bys swv idhh: gen orphan_number = _n if orphan == 1  

	sum n_orphan
	local max_orphan = r(max)

	// Loop over each orphan in hh and create corresponding age variables
	forvalues i = 1/`max_orphan' {  
		
		bys swv idhh: egen temp_dag_orphan`i' = sum(dag) if orphan_number == `i'  
		
		//bys swv idhh: egen dag_orphan`i' = sum(temp_dag_orphan`i')
		bys swv idhh: egen dag_orphan`i' = ///
			max(cond(orphan_number == `i', dag, .))
		
		drop temp_dag_orphan`i'
		
	}

	save "$dir_data/temp_orphans.dta", replace 

restore 

count 

* Add info on orphan's age to the main dataset 
merge 1:1 swv idhh idperson using "$dir_data/temp_orphans.dta",	///
	keepusing(dag_orphan* orphan_number)

keep if _merge == 1 | _merge == 3 

drop _merge 

count 

sum n_orphan
local max_orphan = r(max)

// Loop over the number of orphans in hh 
forvalues i = 1/`max_orphan' {
	
	* Create age difference between them and each adult in the hh 
	//gen temp_target_age`i' = dag_orphan`i' + 20 if dag_orphan`i' > 0
	gen temp_target_age`i' = dag_orphan`i' + 20 ///
		if !missing(dag_orphan`i')
		
	bys swv idhh: egen target_age`i' = mean(temp_target_age`i')
	
	/*
	gen agediff`i' = abs(dag - target_age`i') if adult == 1	
	
	* Select new parent for each orphan who's age is closest to target age
	sort stm idhh agediff`i' idperson 
	by stm idhh: gen newparent`i' = _n 
	by stm idhh: replace newparent`i' = 0 if _n > 1 
	replace newparent`i' = . if n_orphan == 0
	*/
	
	* Identify plausible parent candidates based on age difference
	gen parent_agegap`i' = dag - target_age`i' + 20 if adult == 1

	gen agediff`i' = abs(dag - target_age`i') if ///
		adult == 1 & inrange(parent_agegap`i', 15, 50)

	* Select the eligible adult closest to the target age difference
	sort swv idhh agediff`i' idperson

	by swv idhh: gen byte newparent`i' = ///
		(_n == 1 & !missing(agediff`i')) if n_orphan > 0	
	
	//drop dag_orphan`i' temp_target_age`i' target_age`i' agediff`i'

	* Assign this parent's idperson as orphan's idmother or idfather 
	cap drop temp_idmother_orphan`i' 
	gen double temp_idmother_orphan`i' = idperson if newparent`i' == 1 & ///
		dgn == 0
	bys stm idhh: egen double idmother_orphan`i' = max(temp_idmother_orphan`i')
	format idmother_orphan`i' %19.0g
	replace idmother_orphan`i' = 0 if orphan == 0 
	//drop temp_idmother_orphan`i'

	cap drop temp_idfather_orphan`i'
	gen double temp_idfather_orphan`i' = idperson if newparent`i' == 1 & ///
		dgn == 1
	bys stm idhh: egen double idfather_orphan`i' = max(temp_idfather_orphan`i')
	format idfather_orphan`i' %19.0g
	replace idfather_orphan`i' = 0 if orphan == 0 
	//drop temp_idfather_orphan`i' 

}


* Verify surrogate-parent selection
forvalues i = 1/`max_orphan' {

    * Selected parents must satisfy the age restrictions
    assert inrange(parent_agegap`i', 15, 50) if newparent`i' == 1

    * Selected parents must be closest to the target age
    bysort swv idhh: egen min_agediff`i' = min(agediff`i')

    assert agediff`i' == min_agediff`i' if newparent`i' == 1

    drop min_agediff`i'

}

* Checks 
* Count original orphans
count if orphan == 1

* Count orphans with no eligible surrogate parent
gen byte unmatched_orphan = 0

forvalues i = 1/`max_orphan' {
	
    bysort swv idhh: egen byte hh_match`i' = max(newparent`i')
    
	replace unmatched_orphan = 1 if ///
        orphan_number == `i' & hh_match`i' == 0

}

count if orphan == 1 & unmatched_orphan == 1
tab dag if orphan == 1 & unmatched_orphan == 1


/*
Diagnostic: Age differences for unmatched orphans.

Identify the adult closest to the target 20-year age difference,
without imposing the 15–50-year restriction.
*/

gen closest_agegap = .

forvalues i = 1/`max_orphan' {

    * Age gap between each adult and orphan i
    gen temp_gap`i' = dag - target_age`i' + 20 if ///
        adult == 1 & !missing(target_age`i')

    * Absolute distance from the target age difference
    gen temp_distance`i' = abs(temp_gap`i' - 20)

    * Find the closest adult within each household
    bysort swv idhh: egen min_distance`i' = ///
        min(temp_distance`i')

    * Retrieve the age gap of the closest adult
    bysort swv idhh: egen closest_gap`i' = ///
        min(cond(temp_distance`i' == min_distance`i', ///
        temp_gap`i', .))

    * Store the result for the corresponding unmatched orphan
    replace closest_agegap = closest_gap`i' if ///
        orphan == 1 & orphan_number == `i' & unmatched_orphan == 1

    drop temp_gap`i' temp_distance`i' min_distance`i' closest_gap`i'
}


* Distribution of age differences
tabstat closest_agegap if orphan == 1 & unmatched_orphan == 1, ///
    statistics(n min p1 p5 p25 p50 p75 p95 max)

* Frequency distribution, including missing values
tab closest_agegap if orphan == 1 & unmatched_orphan == 1, missing

* Classify the reasons for non-assignment
gen byte unmatched_reason = . if orphan == 1 & unmatched_orphan == 1

replace unmatched_reason = 1 if unmatched_orphan == 1 & ///
    closest_agegap < 15

replace unmatched_reason = 2 if unmatched_orphan == 1 & ///
    closest_agegap > 50 & !missing(closest_agegap)

replace unmatched_reason = 3 if unmatched_orphan == 1 & ///
    missing(closest_agegap)

label define unmatched_reason_lbl ///
    1 "Closest adult less than 15 years older" ///
    2 "Closest adult more than 50 years older" ///
    3 "No adult candidate available"

label values unmatched_reason unmatched_reason_lbl

tab unmatched_reason, missing
tab dag if unmatched_reason == 3


/*
Assign the selected surrogate parent(s) to each orphan.

The previous loop created separate mother/father ID variables for each
orphan position within the household (e.g. idmother_orphan1,
idfather_orphan1). These variables contain the ID of the adult selected
for that orphan, according to the adult's sex.

Consolidate these into a single pair of parental ID variables for each
orphan, using orphan_number to identify the relevant match.
*/ 
cap drop newidmother
cap drop newidfather

gen double newidmother = .
gen double newidfather = .

// Loop over the number of orphan in a hh 
forvalues i = 1/`max_orphan' {
	
	replace newidmother = idmother_orphan`i' if orphan_number == `i'
	replace newidfather = idfather_orphan`i' if orphan_number == `i'
	
}

format newidmother %19.0g
format newidfather %19.0g

* Update parental IDs for orphans using the selected surrogate parent.
* Where no eligible adult was identified, the new parental IDs remain missing.
replace idmother = newidmother if orphan == 1 
replace idfather = newidfather if orphan == 1 

drop newparent* idmother_orphan* idfather_orphan*

* Assign orphans to their new mother's ben unit (they are heads or partners) 
gsort swv idhh -dag -partnered -idperson

forvalues i = 1/6 {

	replace idbenefitunit = idbenefitunit[_n-`i'] if idmother > 0 & ///
		missing(idbenefitunit) & orphan == 1 & ///
		(idmother == idbenefitunit[_n-`i'] | idmother == idbupartner[_n-`i'])

}

* If some orphans are still not assigned - assign them to father's ben unit
forvalues i = 1/6 {
	
	replace idbenefitunit = idbenefitunit[_n-`i'] if idfather > 0 & ///
		missing(idbenefitunit) & orphan == 1 & ///
		(idfather == idbenefitunit[_n-`i'] | idfather == idbupartner[_n-`i'])  
		
} 

* Fill in benefit unit partner info for newly assigned orphans
bys swv idhh idbenefitunit (idperson): egen temp_idbupartner = max(idbupartner) 
fre temp_idbupartner if orphan == 1 
replace idbupartner = temp_idbupartner if orphan == 1 
	
* Assign newly assigned orphans a second parent if first parent partnered
replace idfather = idbenefitunit if idmother == idbupartner & orphan == 1 
replace idfather = idbupartner if idmother == idbenefitunit & orphan == 1 

* Restore the dataset's missing-value convention for parental IDs
* Orphans without an eligible surrogate parent retain missing parent IDs
replace idfather = -9 if idfather == . 
replace idmother = -9 if idmother == . 


* Checks
* Any remaining orphans?
count if idbenefitunit == . // 230 obs
count if child == 1 & idbenefitunit == . // 230 obs
count if child == 1 & idbenefitunit == . & orphan == 1 // 230 orphan obs 

* Check whether unmatched orphans remain without benefit units
count if orphan == 1 & unmatched_orphan == 1 & missing(idbenefitunit) // 211 obs

tab dag if idbenefitunit == .
tab stm if idbenefitunit == .

* Confirm due to no adult in age range
tab unmatched_reason if idbenefitunit == . 	

* Verify unmatched orphans have no assigned surrogate parents	
count if unmatched_orphan == 1 & ///
    (idmother > 0 | idfather > 0)

fre adult child orphan dag if idbenefitunit == . 
fre idperson if orphan == 1 & missing(idbenefitunit) 
fre idhh if orphan == 1 & missing(idbenefitunit) 


* Drop remaining unassigned children 
drop if orphan == 1 & idbenefitunit == . 

/* Alternatively could make the eldest an adult? */
/*
* Recode the first child in ben unit as adult
bys swv idhh: replace child = 0 if child == 1 & idperson == idperson[1] & ///
	orphan == 1 & num_adults == 0  
bys swv idhh: replace adult = 1 if idperson == idperson[1] & orphan == 1 & ///
	num_adults == 0 
*/

* Check if everyone is assigned to ben units 
count if idbenefitunit == .  // 0 obs unassigned
assert idbenefitunit != . 

* Check that everyone in ben unit has the same benunit partner id assigned 
//AB: idbupartner added as a secondary sorting variable to ensure replicability   
assert idbupartner != . 

replace idbupartner = . if idbupartner == -9
bys swv idbenefitunit (idbupartner): replace idbupartner = idbupartner[1] if ///
	idbupartner != idbupartner[1] // 0 changes

replace idbupartner = -9 if idbupartner == .

assert idbupartner != idbenefitunit


/************ IDENTIFY REMAINING NON-STANDARD BENEFIT UNITS *******************/
/*
Identify and address family and benefit-unit structures that are inconsistent
with the household formation and partnership assumptions used in SimPaths.

The section makes three types of adjustments:

1. Children without identified parents
   Children below the minimum age for leaving the parental home who have
   neither parent identified are flagged for exclusion.

2. Teenage parents
   Individuals below the minimum age for benefit-unit responsibility who
   head their own benefit unit and have dependent children are identified.

   Where their parents can be identified in the same household, the teenage
   parent and their children are reassigned to the grandparents' benefit
   unit. The children's parental identifiers are also replaced with those
   of the grandparents, so that the teenage parent and their children are
   treated as siblings for simulation purposes.

   These adjustments apply only to the relevant household-year and do not
   permanently change family relationships in subsequent observations.

   Following reassignment, benefit-unit partner identifiers are harmonised
   to ensure consistency within the receiving benefit unit.

3. Partnership inconsistencies
   Individuals reporting partnered status while being the only adult in
   their benefit unit are recoded as single. Associated partnership and
   spouse variables are updated, including transitions in subsequent waves
   and partnership durations.

   Remaining inconsistencies involving underage partnerships are identified
   and flagged for exclusion.

The purpose is to retain as many observations as possible while ensuring
that family relationships, benefit-unit membership and partnership status
are consistent with the simulation assumptions.

Observations flagged through dropObs are excluded at a later stage.
*/

* Check for benefit units with multiple adults of same sex
gen adultMan = adult * (dgn == 1)
gen adultWoman = adult * (dgn == 0)

gsort swv idbenefitunit

bys swv idbenefitunit: egen sumMen = sum(adultMan)
bys swv idbenefitunit: egen sumWomen = sum(adultWoman)
tab swv sumMen
tab swv sumWomen

assert sumMen < 2 & sumWomen < 2 

* Check that each individual appears only once in each survey year
duplicates report swv idperson 
duplicates report swv idperson // no cases 

sort swv idbenefitunit idperson 


* Initialise the exclusion indicator
/*
Observations that cannot be reconciled with the simulation assumptions
are flagged through dropObs. They are not removed at this stage.
*/
cap drop dropObs
gen dropObs = . 


* Identify children without an identified parent
/*
Children below the minimum age for leaving the parental home must be
assigned to a parental benefit unit in SimPaths.

Where neither parent can be identified, the child cannot be assigned
consistently and is therefore flagged for exclusion.

NOTE: This may also identify underage partners who are living away
from their parents.
*/

gen orphan_check = 1 if (idfather < 0 & idmother < 0) & ///
	(inrange(dag, 0, ${age_leave_parental_home} - 1)) 
	
gen flag_orphan_drop = (orphan_check == 1)

lab var flag_orphan_drop "FLAG: =1 if number of orphan obs unassigned to parent"	
	
fre dag if orphan_check == 1 

replace dropObs = 1 if orphan_check == 1 

drop orphan_check 


* Identify teenage parents who head their own benefit unit
/*
SimPaths does not allow individuals below the minimum age of responsibility
to head an independent benefit unit. However, teenage parents may be
recorded as benefit-unit heads in the observed data.

Identify these individuals using their age, benefit-unit head status
and number of dependent children. Where possible, they will subsequently
be reassigned to their parents' benefit unit, together with their children.

If a teenage parent lives with their parents.
	==> Assign the new child to their grandparents (idmother & idfather) thus 
	treat the teenage parent and their child as siblings in the code. 
	
NOTE: Drops partner if they live with the family. Very rare, tyically if 
partnership between two children.
If leave household let and take children let them for now. 
*/
   
gen childhead = (idperson == idbenefitunit & ///
	dag < ${age_becomes_responsible} & dnc > 0)
	
fre childhead // 30 obs 

tab idpartner if childhead == 1
	// none partnered 

gen flag_child_parent = (childhead == 1)	

lab var flag_child_parent "FLAG: =1 if child parent"


* Identify other members of the benefit units of teenage parents
bys swv idbenefitunit: egen childhead_bu = max(childhead) 

* Exclude non-head members aged over 12 from benefit units headed by teenage 
* parents 
drop if childhead_bu == 1 & childhead == 0 & dag > 12

* remove partner information 
replace idpartner = -9 if childhead == 1 
replace dagsp = -9 if childhead == 1

* Check subsequent household transitions of teenage parents
/*
If leave parental home in future with child allow them to take the child as 
do in data. 
*/
sort idperson swv

by idperson: gen byte moved_hh = ///
    _n > 1 & idhh != idhh[_n-1] & swv == swv[_n-1] + 1

by idperson: gen byte previously_childhead = ///
    _n > 1 & childhead[_n-1] == 1 & swv == swv[_n-1] + 1

count if moved_hh == 1 & previously_childhead == 1
	// one leaves and takes their child with them 

drop moved_hh previously_childhead


* Identify the grandparent's benefit unit and reassign teenage parents
/*
Teenage parents identified above cannot remain responsible for their own
benefit unit under the SimPaths assumptions.

Where their parents can be identified within the same household, the
teenage parent and their children are reassigned to the grandparents'
benefit unit.

The reassignment involves two changes:
    1. Assigning the teenage parent and their children to the grandparents'
       benefit unit.
    2. Replacing the children's parental identifiers with those of the
       grandparents, so that the teenage parent and their children are
       treated as siblings for simulation purposes.

These adjustments are specific to the household-year. They do not change
the recorded family relationships in subsequent years.
*/

* Identify households containing a teenage parent
gen childhead_hh = (childhead == 1)
bysort idhh swv (childhead_hh): replace childhead_hh = childhead_hh[_N] 

sort idperson swv 

* Identify the teenage parent and their parents
/*
Record the teenage parent's individual ID and the IDs of their mother
and father. These are subsequently used to identify the receiving
benefit unit and reconstruct parental relationships.
*/
gen double idchildhead = 0 
gen double idnewmum = 0 
gen double idnewdad = 0 

replace idchildhead = idperson if childhead == 1 
replace idnewmum = idmother if childhead == 1 
replace idnewdad = idfather if childhead == 1 

* Propagate across the household-year
bysort idhh swv (idchildhead): replace idchildhead = idchildhead[_N]
bysort idhh swv (idnewmum): replace idnewmum = idnewmum[_N]
bysort idhh swv (idnewdad): replace idnewdad = idnewdad[_N]

* Identify the receiving benefit unit
gen double idnewbu = 0 

replace idnewbu = idbenefitunit if childhead_hh == 1 & idperson == idnewmum

bysort idhh swv (idnewbu): replace idnewbu = idnewbu[_N]

* Check how many teenage parents cannot be assigned to a valid
* grandparents' benefit unit.
count if childhead == 1 & (idnewbu <= 0 | missing(idnewbu))

format idchildhead %18.0g
format idnewmum %18.0g
format idnewdad %18.0g
format idnewbu %18.0g

sort idperson swv 

* Reclassify teenage parents as dependent children
replace adult = 0 if idperson == idchildhead
replace child = 1 if idperson == idchildhead

* Reassign benefit-unit membership
replace idbenefitunit = idnewbu if childhead == 1 
replace idbenefitunit = idnewbu if childhead_hh == 1 & idmother == idchildhead
replace idbenefitunit = idnewbu if childhead_hh == 1 & idfather == idchildhead

* Reconstruct parental relationships for simulation purposes
replace idfather = idnewdad if childhead_hh == 1 & idfather == idchildhead
replace idmother = idnewmum if childhead_hh == 1 & idmother == idchildhead
 
* Harmonise benefit-unit partner IDs after teenage-parent reassignment

* Check that existing positive partner IDs agree within affected benefit units
bysort swv idbenefitunit: egen double min_valid_partner = ///
    min(cond(idbupartner > 0 & !missing(idbupartner), idbupartner, .))

bysort swv idbenefitunit: egen double max_valid_partner = ///
    max(cond(idbupartner > 0 & !missing(idbupartner), idbupartner, .))

assert min_valid_partner == max_valid_partner if ///
    childhead_hh == 1 & !missing(min_valid_partner)

* Propagate the existing benefit-unit partner ID to reassigned individuals
replace idbupartner = max_valid_partner if ///
    childhead_hh == 1 & ///
    idbenefitunit == idnewbu & ///
    idnewbu > 0 & !missing(max_valid_partner)

* Check consistency after harmonisation
bysort swv idbenefitunit: egen double temp_min_partner = min(idbupartner)
bysort swv idbenefitunit: egen double temp_max_partner = max(idbupartner)

assert temp_min_partner == temp_max_partner if ///
    childhead_hh == 1 & !missing(temp_min_partner)

* Tidy up
drop min_valid_partner max_valid_partner ///
    temp_min_partner temp_max_partner

drop childhead childhead_bu childhead_hh idchildhead idnewmum idnewdad idnewbu 
 
 
* Partnernership inconsistencies 
* Reports being partnered but one adult in ben unit
/*
Some individuals who report being partnered but are the only adult
in their benefit unit.

To retain these observations, recode the individual as single and update
the associated partnership and spouse characteristics.
*/

* Identify partnered individuals who are the only adult in their benefit unit
bys swv idbenefitunit : egen num_adult = sum(adult)

gen partner1 = (num_adult == 1 & dcpst == 1 & adult == 1) 

bys swv idbenefitunit : egen partner1_bu = max(partner1)

fre partner1 // 168 obs 
fre partner1_bu // 227 obs 

gen flag_1partner = (partner1_bu)

lab var flag_1partner ///
	"FLAG: =1 if partnered individual recoded as single (only adult in BU)"

* Update partnership related variables
xtset idperson swv 
sort idperson swv

replace dcpst = 2 if partner1 == 1

replace idpartner = -9 if partner1 == 1

replace dcpen = -9 if l.dcpst != 2 & partner1 == 1 
replace dcpen = 0 if l.dcpst == 2 & partner1 == 1 
replace dcpen = -9 if partner1 == 1 & dag < ${age_form_partnership}

replace dcpex = -9 if partner1 == 1 
replace dcpex = 1 if l.dcpst == 1 & partner1 == 1 
replace dcpex = -9 if partner1 == 1 & dag < ${age_form_partnership}

replace dcpagdf = -9 if partner1 == 1

replace lesdf_c4 = -9 if partner1 == 1

replace ssscp = 0 if partner1 == 1

replace dcpyy = -9 if partner1 == 1
replace dcpyy_st = -9 if partner1 == 1

replace dhhtp_c4 = 3 if dhhtp_c4 == 1 & partner1 == 1
replace dhhtp_c4 = 4 if dhhtp_c4 == 2 & partner1 == 1

replace dagsp = -9 if partner1 == 1 

replace dgnsp = -9 if partner1 == 1 

replace dhesp = -9 if partner1 == 1 

replace dlltsd_sp = -9 if partner1 == 1 

replace lessp_c3 = -9 if partner1 == 1 

replace lessp_c4 = -9 if partner1 == 1 

replace dagpns_sp = -9 if partner1 == 1  
replace dagpns_y_sp = -9 if partner1 == 1 
replace dagpns_y1_sp = -9 if partner1 == 1 

replace dehsp_c3 = -9 if partner1 == 1 
replace dehsp_c4 = -9 if partner1 == 1 

replace partnered = 0 if partner1 == 1
replace idpartner = -9 if dag < ${age_form_partnership}

tab dcpst if dag < ${age_form_partnership}


* Correct subsequent-wave transitions following recoding to single
xtset idperson swv
sort idperson swv

* Identify observations immediately following a partnership-status recode
gen byte after_partner1 = (L.partner1 == 1)

* Partnership entry: previously single
replace dcpen = 0 if after_partner1 == 1
replace dcpen = 1 if after_partner1 == 1 & dcpst == 1

* Retain minimum-age restriction
replace dcpen = -9 if after_partner1 == 1 & ///
    dag < ${age_form_partnership}

* Partnership exit: previously single, so not at risk
replace dcpex = -9 if after_partner1 == 1


* Correct partnership duration of subsequent waves 
sort idperson swv
xtset idperson swv

* Duration with the same partner
cap drop partnershipDuration 
cap drop dcpyy 
cap drop dcpyy_st

preserve

    keep idperson idpartner swv
    replace idpartner = . if idpartner < 0

    xtset idperson swv
    tsspell idpartner

    rename _seq partnershipDuration
    replace partnershipDuration = . if missing(idpartner)

    keep swv idperson partnershipDuration
    
	tempfile temp_duration
    save `temp_duration'

restore

merge 1:1 swv idperson using `temp_duration', keep(1 3) nogen

gen dcpyy = partnershipDuration if idpartner > 0

* Consecutive years observed as partnered
sort idperson swv
by idperson: gen dcpyy_st = 1 if dcpst == 1
by idperson: replace dcpyy_st = dcpyy_st[_n-1] + 1 if ///
    _n > 1 & swv == swv[_n-1] + 1 & ///
    dcpst == 1 & dcpyy_st[_n-1] != .

replace dcpyy = -9 if missing(dcpyy)
replace dcpyy_st = -9 if missing(dcpyy_st)

* Preserve minimum partnership age restriction
replace dcpyy = -9 if dag < ${age_form_partnership}

lab var dcpyy "DEMOGRAPHIC: Partnership duration (within panel)"

* Tidy up 
drop partner1 partner1_bu after_partner1 partnershipDuration


* Reports being single but more than one adult in benefit unit 
/*
Some benefit units contain two adults even though one reports being single.

In the PL data, these inconsistencies arise from the earlier processing
in file 02, where individuals below the minimum age for partnership
formation were recoded as single, while their benefit-unit membership
continued to reflect the original partnership.

These cases cannot be resolved by recoding the individual as partnered,
as this would reintroduce a partnership below the minimum permitted age.

Identify the affected individuals and flag them for exclusion rather
than modifying their partnership status or benefit-unit membership.
*/

* Identify individuals reporting single status in two-adult benefit unit
gen part1adult = (num_adult == 2 & dcpst == 2 & adult == 1) 
	
bys swv idbenefitunit : egen part1adult_bu = max(part1adult)

tab dag if part1adult == 1 

/*

        Age |      Freq.     Percent        Cum.
------------+-----------------------------------
         17 |          4      100.00      100.00
------------+-----------------------------------
      Total |          4      100.00

*/

tab dnc if part1adult == 1
	// 4 have children
	
tab dropObs if part1adult == 1	
tab idmother if part1adult == 1		
tab idfather if part1adult == 1	
	// 1 live2 with parents
	
* Create flag 	
gen flag_adult_child_rel = (part1adult == 1)

lab var flag_adult_child_rel ///
	"DEMOGRAPHIC: Number of individuals < 18 that are still in a partnership"

fre part1adult_bu // 13 obs 

replace dropObs = 1 if flag_adult_child_rel == 1 

//replace dag = 18 if part1adult == 1

drop part1adult part1adult_bu 



/****************** UPDATE HH COMPOSITION RELATED VARIABLES *******************/
* Number of children 
/*
Reconstruct the number of dependent children using benefit-unit membership,
rather than parental identifiers.

The previous construction counted children linked to an individual through
their mother/father IDs. The revised construction counts all children within
the same benefit unit, consistent with the SimPaths definition.

dnc:   Number of children aged 0 to age_max_dep_child in the benefit unit.
dnc02: Number of children aged 0-2 in the benefit unit.

Children themselves are assigned zero for both variables, consistent with
the simulation convention.

Note: The newborn identification variable is not updated here.
*/
cap drop dnc dnc02

* Identify children
gen byte temp_depChild = dag <= ${age_max_dep_child}

gen byte temp_depChild02 = inrange(dag, 0, 2)

* Count children within benefit unit
bysort swv idbenefitunit: egen dnc = total(temp_depChild)
bysort swv idbenefitunit: egen dnc02 = total(temp_depChild02)

lab var dnc ///
    "DEMOGRAPHIC: Number of children 0-${age_max_dep_child} in benefit unit"

lab var dnc02 ///
    "DEMOGRAPHIC: Number of children aged 0-2 in benefit unit"

* Children themselves are assigned zero children, consistent with SimPaths
replace dnc = 0 if dag <= ${age_max_dep_child}	
replace dnc02 = 0 if dag <= ${age_max_dep_child}
	
drop temp_depChild temp_depChild02

* Consistency checks
assert dnc >= 0 & dnc < .
assert dnc02 >= 0 & dnc02 < .

* Number aged 0-2 cannot exceed total number of children
assert dnc02 <= dnc

* Individuals classified as children should not themselves have children
assert dnc == 0 if dag <= ${age_max_dep_child}
assert dnc02 == 0 if dag <= ${age_max_dep_child}


* Household composition suammary vars 
/*
Note: For consistency with the simulation adult children and children above
age to become responsible should be assigned "no children" category, even if 
there are some children in the household 
*/
* Without economic activity 
cap drop dhhtp_c4
cap drop dhhtp_c8

gen dhhtp_c4 = -9
replace dhhtp_c4 = 1 if dcpst == 1 & dnc == 0 // Coupled, no children
replace dhhtp_c4 = 2 if dcpst == 1 & dnc > 0 // Coupled, children
replace dhhtp_c4 = 3 if dcpst == 2 & dnc == 0  // | adultchildflag == 1) 
	// Not partnered, no children 
replace dhhtp_c4 = 4 if dcpst == 2 & dnc > 0 & dhhtp_c4 != 3 
	// Not partnered, children

lab val dhhtp_c4 dhhtp_c4_lb
lab var dhhtp_c4 "DEMOGRAPHIC: Household composition"


* With economic activity 
gen dhhtp_c8 = -9 

replace dhhtp_c8 = 1 if dhhtp_c4 == 1 & lessp_c3 == 1
replace dhhtp_c8 = 2 if dhhtp_c4 == 1 & lessp_c3 == 2
replace dhhtp_c8 = 3 if dhhtp_c4 == 1 & lessp_c3 == 3	
replace dhhtp_c8 = 4 if dhhtp_c4 == 2 & lessp_c3 == 1
replace dhhtp_c8 = 5 if dhhtp_c4 == 2 & lessp_c3 == 2
replace dhhtp_c8 = 6 if dhhtp_c4 == 2 & lessp_c3 == 3	
replace dhhtp_c8 = 7 if dhhtp_c4 == 3
replace dhhtp_c8 = 8 if dhhtp_c4 == 4

lab val dhhtp_c8 dhhtp_c8	

lab var dhhtp_c8 ///
	"DEMOGRAPHIC: Household composition with economic activity info"


* OECD Equivalence Scale  
/*
Construct a household-level modified OECD equivalence scale using the
updated household-composition classification and counts of children
aged 0-13 and 14-18 with identified parental relationships.

The child counts are calculated at the household level (idhh), rather
than the benefit-unit level (idbenefitunit).

Note: The household-composition classification uses benefit-unit child
counts, whereas the equivalence-scale calculation uses household-level
child counts.
*/
cap drop depChild_013
cap drop depChild_1418
cap drop dnc013
cap drop dnc1418
cap drop moecd_eq

gen depChild_013 = 1 if (dag >= 0 & dag <= 13) & (idmother > 0 | idfather > 0) 

gen depChild_1418 = 1 if (dag >= 14 & dag <= 18) & (idmother > 0 | idfather > 0) 

bys swv idhh: egen dnc013 = sum(depChild_013)
bys swv idhh: egen dnc1418 = sum(depChild_1418)
drop depChild_013 depChild_1418

gen moecd_eq = . //Modified OECD equivalence scale
replace moecd_eq = 1.5 if dhhtp_c4 == 1
replace moecd_eq = 0.3*dnc013 + 0.5*dnc1418 + 1.5 if dhhtp_c4 == 2
replace moecd_eq = 1 if dhhtp_c4 == 3
replace moecd_eq = 0.3*dnc013 + 0.5*dnc1418 + 1 if dhhtp_c4 == 4

lab var moecd_eq "DEMOGRAPHIC: Modified OECD equivalence scale"

drop dnc013 dnc1418


* Home ownership variable 
/*
Construct a benefit-unit-level home ownership indicator.

Select one representative individual per benefit unit and wave, prioritising:
    1. Highest non-benefit income
    2. Highest age
    3. Lowest person ID

Use this individual's household ownership indicator to construct
dhh_owned_ind, then propagate the value to all members of the benefit unit
as dhh_owned.

Verify that exactly one representative is selected for each benefit-unit
and wave combination.
*/
preserve

	egen tag_bu_wave = tag(idbenefitunit swv)
	count if tag_bu_wave
	local n_bu_before = r(N)
	display ///
	"Number of benefit unit–wave combinations BEFORE selecting head: `n_bu_before'"

	* Select one representative per benefit unit and wave
	* Prioritise highest non-benefit income, then age, then lowest person ID
	gsort idbenefitunit swv -ypnbihs_dv -dag idperson 

	* Tag the first person (the "head") per benefit unit and wave
	by idbenefitunit swv: gen benunit_head = (_n == 1)

	* Keep only benefit unit heads
	keep if benunit_head == 1

	* Count unique benefit-unit–wave combinations AFTER head selection
	drop tag_bu_wave
	egen tag_bu_wave = tag(idbenefitunit swv)
	count if tag_bu_wave
	local n_bu_after = r(N)
	display ///
	"Number of benefit unit–wave combinations AFTER selecting head: `n_bu_after'"

	* Ensure benefit unit–wave counts match before and after head selection
	assert `n_bu_before' == `n_bu_after'

	* Verify only one head per benefit unit per wave
	by idbenefitunit swv, sort: gen n = _N
	assert n == 1

	keep idperson swv dhh_owned 

	save "$dir_data/temp_dhh_owned", replace 

restore 

rename dhh_owned dhh_owned_orig

merge 1:1 idperson swv using "$dir_data/temp_dhh_owned"
drop _m 

replace dhh_owned = 0 if dhh_owned == . 

rename dhh_owned dhh_owned_ind
lab var dhh_owned_ind ///
	"WEALTH: Home ownership flag, only =1 for benefit unit head"

gen dhh_owned = dhh_owned_ind

bysort idbenefitunit swv (dhh_owned): replace dhh_owned = dhh_owned[_N]
	
lab var dhh_owned "WEALTH: Home ownership flag, =1 for all benefit unit members"

sort idperson swv 


/*
Update income quintiles for children reassigned to their parents' households, 
using the final household identifiers.

Retain the original income quintile classifications for all other individuals 
and reproduce the original household assignment rule.
*/

* Preserve original values for comparison
clonevar ydses_c5_orig = ydses_c5

* Identify the highest quintile among non-dependent household members
bysort stm idhh: egen temp_ydses_max = ///
    max(cond(dag > ${age_max_dep_child} & ///
    inrange(ydses_c5, 1, 5), ydses_c5, .))

* Update reassigned children
replace ydses_c5 = temp_ydses_max ///
    if flag_hh_reassigned == 1 & ///
    dag <= ${age_max_dep_child} & ///
    !missing(temp_ydses_max)

* Examine changes
tab ydses_c5_orig ydses_c5 if flag_hh_reassigned == 1, missing

drop flag_hh_reassigned temp_ydses_max


/********** FULLY POPULATE DROP DUMMY IF HAVE MISSING INFORMATION *************/

* Identify benefit units to drop due to missing values 
/*
Variables that are maintianed in the UID. 
Exclude:
	- transition variables: dcpen dcpex der sedex
	- age summaries: sprfm, sedeg
	- lhw and obs_earnings_hourly aligned with les_c3
	- dcpagdf covered by age variables and -9 is meaningful 
	- not used in model: dehm_c4, dehf_c4, ypnoab
	- ynbcpdf_dv covered by missing income 
	- lagged economic activity variables
	
NOTE: Income amounts assumed not to be missing, treated as zero instead. The 
only exception is employment income which is missing because derived from 
working hours and wages. 
*/

* Region 
count if drgn1 == -9 // 0 obs 
replace dropObs = 1 if drgn1 == -9


* Age 
count if dag == -9 // 13 obs 
replace dropObs = 1 if dag == -9

* Age of partner (but has a partner)
count if dagsp == -9 & idpartner != -9 // 0 obs 
replace dropObs = 1 if dagsp == -9 & idpartner != -9

* Missing gender
count if dgn == -9  // 13 obs 
replace dropObs = 1 if dgn == -9

* Partnership status 
count if dcpst == -9 // 0 obs  
replace dropObs = 1 if dcpst == -9 

* Same sex partnership 
replace dropObs = 1 if ssscp == -9

* Years in partnership 
replace dropObs = 1 if dcpyy == -9 & dcpst == 1

* Number of children 
count if dnc == -9  // 0 obs 
replace dropObs = 1 if dnc == -9

* Number of children age 0-2
count if dnc02 == -9  // 0 obs 
replace dropObs = 1 if dnc02 == -9

* Household composition 
count if dhhtp_c4 == -9 & dag >= ${age_becomes_semi_responsible} // 0 obs 
replace dropObs = 1 if dhhtp_c4 == -9 & dag >= ${age_becomes_semi_responsible}

count if dhhtp_c8 == -9 & dag >= ${age_becomes_semi_responsible} // 1,656 obs 
replace dropObs = 1 if dhhtp_c8 == -9 & dag >= ${age_becomes_semi_responsible}

* Adult child 
count if adultchildflag == -9 & dag >= ${age_becomes_semi_responsible} 
replace dropObs = 1 if adultchildflag == -9 & ///
	dag >= ${age_becomes_semi_responsible} 


* Education - remove household if missing education level for 16+
count if deh_c4 == -9 & dag >= ${age_becomes_semi_responsible} & ded == 0 
replace dropObs = 1 if deh_c4 == -9 & ///
	dag >= ${age_becomes_semi_responsible} & ded == 0

* Education of spouse - remove household if missing but individual has a spouse 
count if dehsp_c4 == -9 & idpartner != -9 	// 0 obs 
replace dropObs = 1 if dehsp_c3 == -9 & idpartner != -9

* Initial education spell 
count if ded == -9  // 0 obs 
replace dropObs = 1 if ded == -9


* Activity status 
count if les_c3 == -9 & dag >= ${age_becomes_semi_responsible} 	// 5,969 obs
replace dropObs = 1 if les_c3 == -9 & dag >= ${age_becomes_semi_responsible}

* Activity status with retirement as a separate category 
count if les_c4 == -9 & dag >= ${age_becomes_semi_responsible}  // 5,969 obs 
replace dropObs = 1 if les_c4 == -9 & dag >= ${age_becomes_semi_responsible}

* Disabled/long-term sick 
count if dlltsd == -9 & dag >= ${age_becomes_semi_responsible} 
replace dropObs = 1 if dlltsd == -9 & dag >= ${age_becomes_semi_responsible} 

* Partner's activity status 
count if lessp_c3 == -9 & idpartner != -9 // 0 obs 
replace dropObs = 1 if lessp_c3 == -9 & idpartner != -9

* Partner's activity status 
count if lessp_c4 == -9 & idpartner != -9 // 0 obs 
replace dropObs = 1 if lessp_c4 == -9 & idpartner != -9

* Own and spousal activity status 
count if lesdf_c4 == -9 & idpartner != -9 // 0 obs
replace dropObs = 1 if lesdf_c4 == -9 & idpartner != -9


* Health status - remove household if missing for those 16+ 
count if dhe == -9 & dag > ${age_becomes_semi_responsible} 
	// 0 obs due to imputation  
replace dropObs = 1 if (dhe == -9) & dag > ${age_becomes_semi_responsible}

* Health status of spouse - remove household if missing but ind has a spouse 
count if dhesp == -9 & idpartner != -9 // 0 obs
replace dropObs = 1 if (dhesp == -9) & idpartner != -9


* Income 
* Gross personal non-benefit income 
//==> no missing values by construction, theoretically can be zero 
count if ypnbihs_dv == . & dag >= ${age_becomes_semi_responsible} 
count if ypnbihs_dv < 0 & dag >= ${age_becomes_semi_responsible} 
count if ypnbihs_dv == 0 & dag >= ${age_becomes_semi_responsible} 
count if ypnbihs_dv > 0 & dag >= ${age_becomes_semi_responsible} 

* Gross personal employment income 
count if yplgrs_dv == . & dag >= ${age_becomes_semi_responsible}  // 5,969 obs
count if yplgrs_dv < 0 & dag >= ${age_becomes_semi_responsible}  
count if yplgrs_dv == 0 & dag >= ${age_becomes_semi_responsible}  
count if yplgrs_dv > 0 & dag >= ${age_becomes_semi_responsible}  

* Gross personal non-employment capital income 
//==> no missing values by construction 
count if ypncp == . & dag >= ${age_becomes_semi_responsible} 
count if ypncp < 0 & dag >= ${age_becomes_semi_responsible} 
count if ypncp == 0 & dag >= ${age_becomes_semi_responsible} 
count if ypncp > 0 & dag >= ${age_becomes_semi_responsible} 

replace dropObs = 1 if ypnbihs_dv == . & dag >= ${age_becomes_semi_responsible}
replace dropObs = 1 if yplgrs_dv == . & dag >= ${age_becomes_semi_responsible} 
replace dropObs = 1 if ypncp == . & dag >= ${age_becomes_semi_responsible}
replace dropObs = 1 if ydisp == . & dag >= ${age_becomes_semi_responsible}

replace dropObs = 1 if yplgrs_dv < 0  & dag >= ${age_becomes_semi_responsible} 
replace dropObs = 1 if ypncp < 0 & dag >= ${age_becomes_semi_responsible}
replace dropObs = 1 if ypnbihs_dv < 0 & dag >= ${age_becomes_semi_responsible}

* Household income quintile
//==> a few missing values for kids who live w/t other adults
count if ydses_c5 == -9 & dag >= ${age_becomes_semi_responsible}  // 0 obs 

replace dropObs = 1 if ydses_c5 == -9 
	
	
* Home ownership 
count if dhh_owned == -9 
replace dropObs = 1 if dhh_owned == -9 	
	
	
* Indicator for households with missing values 
// drops hhs containing individuals age < 18 that don't have a parent 
cap drop dropHH
bys swv idhh: egen dropHH = max(dropObs)
tab dropHH, mis

gen flag_drop_obs = (dropHH == 1)

lab var flag_drop_obs ///
	"FLAG: Number of observations dropped in data construction"
	

* Clean up 
replace idfather = -9 if idfather == 0 	
	
sort idperson swv 


/*************************** UPDATE FLAG EXCEL FILE ***************************/

* Orphans before assigning to adults
tab flag_orphan if dag < ${age_becomes_responsible}, matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A72 = ("Number of orphans in dataset")
putexcel A73 = matrix(names) B73 = matrix(freq) C73 = matrix(percent) 
putexcel D73 = ("Children")


* Orphans dropped
tab flag_orphan_drop if dag < ${age_becomes_responsible}, matcell(freq) ///
	matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A75 = ("Number of orphans dropped")
putexcel A76 = matrix(names) B76 = matrix(freq) C76 = matrix(percent) 
putexcel D76 = ("Children")


* Individuals that report a partnership that is not recognized 
tab flag_1partner if dag >= ${age_becomes_responsible}, matcell(freq) ///
	matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A78 = ("Number of individuals that report a partnership that is not recognized by the other partner")
putexcel A79 = matrix(names) B79 = matrix(freq) C79 = matrix(percent) 
putexcel D79 = ("Adults")


* Adults in a partnership with someone below the age of responsibility
tab flag_adult_child_rel if dag >= ${age_becomes_responsible}, matcell(freq) ///
	matrow(names)	

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A81 = ("Number of adults in a partnership with someone below the age of responsibility")
putexcel A82 = matrix(names) B82 = matrix(freq) C82 = matrix(percent) 
putexcel D82 = ("Adults")


* Dropped obs 
tab flag_drop_obs, matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A84 = ("Number of dropped observations (dropped at hh level)")
putexcel A85 = matrix(names) B85 = matrix(freq) C85 = matrix(percent) 
putexcel D85 = ("All")


/*********************************** SAVE *************************************/

sort idperson swv 
 
save "$dir_data/${country}-SILC_pooled_all_obs_03.dta", replace  

//cf _all using "$dir_data/${country}-SILC_pooled_all_obs_03.dta"


/***************************** CLEAN UP AND EXIT ******************************/
cap log close 

#delimit ;
local files_to_drop 
	temp_orphans.dta
	temp_dhh_owned.dta
	;
#delimit cr // cr stands for carriage return

foreach file of local files_to_drop  { 
	
	erase "$dir_data/`file'"

}
