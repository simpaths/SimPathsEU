/*******************************************************************************
* PROJECT:             	SimPaths EU
* DO-FILE NAME:        	00_master_conditions.do
* DESCRIPTION:         	Sets out the assumptions and conditions imposed in the 
* 						creation of the unique dataset and the if conditions 
* 						imposed when estimating the processes for SimPaths.  
********************************************************************************
* COUNTRY:              ES
* AUTHORS: 				Ashley Burdett
* LAST UPDATE:          April 2026 AB
********************************************************************************
*   -----------------------------------------------------------------------
*    Assumptions imposed to align the SILC data with simulation rules:
*   -----------------------------------------------------------------------
*
*   - Retirement:
*       - Treated as an absorbing state
*       - Must retire by a specified maximum age
*       - Cannot retire before a specified minimum age
*
*   - Education:
*       - Leave education no earlier than a specified minimum age
*       - Must leave the initial education spell by a specified maximum age
*       - Cannot return to education after retirement
*
*   - Work:
*       - Can work from a specified minimum age
*       - Activity status and hours of work populated consistently:
*           → Assume not working if report hours = 0 
*           → Assume hours = 0 if not working
* 		- If missing partial information, don't assume the missing is 0 and 
* 			impute (hot-deck)
*
*   - Leaving the parental home:
*       - Can leave from a specified minimum age
* 		- Become the effective head of hh even when living with parents when 
* 			paretns retire or reach state retirment age
*
*   - Home ownership:
*       - Can own a home from a specified minimum age
*
*   - Partnership formation:
*       - Can form a partnership from a specified minimum age
*
*   - Disability:
*       - Treated as a subsample of the not-employed population
*
*   The relevant age thresholds are defined in globals defined in "DEFINE 
* 	PARAMETERS" section below. 
* 	Throughout also construct relevant flags and produce a log file 
* 	"flag_descriptives.xlsx" to see the extent of the adjustments to the raw 
* 	data. 
*
*   -----------------------------------------------------------------------
*    Additional notes on implementation: 
*   -----------------------------------------------------------------------
*
*   - Impute health score (generalized ordered logit model).
*   - Constructing age is not straight forward as not directly reported in the 
* 	  data, therefore: 
*       → Use interview age (RX010) where available
*       → Otherwise use age at end of interview year (PX020). This results in 
* 			upward bias of age.
*   - Set education = 0 (na) while in initial education spell. 
*
*   -----------------------------------------------------------------------
*   Remaining disparities between initial populations and simulation rules:
*   -----------------------------------------------------------------------
*
*   - Ages at which females can have a child. [Be informed by the sample?]
*	  Permit teenage mothers in this script (deal with in 03_ )
*   - A few higher/older education spells (30+) that last multiple years 
*     in the simulation can only return to education for single year spells. 
* 	- Number of children vars (all ages or 0-2) don't account for feasibility 
* 		of age at birth of the mother. 
*
*******************************************************************************/


/*******************************************************************************
* DEFINTE PARAMETERS
*******************************************************************************/

global country "ES"

global first_sim_year "2011"

global last_sim_year "2024"


* Define threshold ages
/*
The thresholds defined below ensure consistency between the assumptions 
applied in the simulation and the structure of the initial population data. 
They specify the ages at which certain life-course transitions are permitted 
or enforced within the model. These limits reflect both modelling conventions 
and empirical considerations drawn from observed data.
*/
 	
* Age become an adult in various dimensions	
global age_becomes_responsible 18 

global age_becomes_semi_responsible 16 

global age_seek_employment 16 
	
global age_leave_school 16 

global age_form_partnership 18 

global age_have_child_min 18 	

global age_leave_parental_home 18

global age_max_leave_parental_home 45

global age_own_home 18

global age_can_retire 50

global age_force_retire 75             

global age_force_leave_spell1_edu 30   

global age_have_child_max 49  	
	// allow this to be informed by the data  

global age_cannot_separate 79

global age_max_dep_child 17   
	// used for defining BU and number of dependent children variables in data construction   

global age_adult 18 
	// used when slicing up hh level income information in data construction

/*******************************************************************************
* PROCESS IF CONDITIONS 
*******************************************************************************/

* Education 
global e1a_if_condition "dag >= ${age_leave_school} & dag < ${age_force_leave_spell1_edu} & l.les_c4 == 2 & flag_deceased != 1"

global e1b_if_condition "dag >= ${age_leave_school} & l.les_c4 != 4 & l.les_c4 != 2 & flag_deceased != 1"

global e2_if_condition "dag >= ${age_leave_school} & l.les_c4 == 2 & les_c4 != 2 & flag_deceased != 1"

* Leave the parental home 
global p1_if_condition "ded == 0 & dag >= ${age_leave_parental_home} & dag <= ${age_max_leave_parental_home} & flag_deceased != 1"

* Partnership 
global u1_if_condition "dag >= ${age_form_partnership} & ssscp != 1 & flag_deceased != 1"

global u2_if_condition "dgn == 0 & dag >= ${age_form_partnership} & l.ssscp != 1 & dag < ${age_cannot_separate} & flag_deceased != 1 & flag_deceased != 1"

* Fertility 
global f1_if_condition "dag >= ${age_have_child_min} & dag <= ${age_have_child_max} & dgn == 0 & flag_deceased != 1"

* Health 
global h1_if_condition "dag >= ${age_becomes_semi_responsible} & flag_dhe_imp == 0 & flag_deceased != 1"

global h2_if_condition "dag >= ${age_becomes_semi_responsible} & ded == 0 & les_c4 != 4 & les_c4 != 2 & flag_deceased != 1"

* Home ownership
global ho1_if_condition "dag >= ${age_own_home} & flag_deceased != 1"

* Retirement 
global r1a_if_condition "dcpst == 2 & dag >= ${age_can_retire} & flag_deceased != 1"

global r1b_if_condition "ssscp != 1 & dcpst == 1 & dag >= ${age_can_retire} & flag_deceased != 1"

* Wages
global W1fa_if_condition "dgn == 0 & dag >= ${age_seek_employment} & dag <= ${age_force_retire} & deh_c4 != 0 & flag_deceased != 1"

global W1ma_if_condition "dgn == 1 & dag >= ${age_seek_employment} & dag <= ${age_force_retire} & deh_c4 != 0 & flag_deceased != 1"

global W1fb_if_condition "dgn == 0 & dag >= ${age_seek_employment} & dag <= ${age_force_retire} & deh_c4 != 0 & previouslyWorking == 1 & flag_deceased != 1"

global W1mb_if_condition "dgn == 1 & dag >= ${age_seek_employment} & dag <= ${age_force_retire} & deh_c4 != 0 & previouslyWorking == 1 & flag_deceased != 1"

* Capital income 
global i1a_if_condition "dag >= ${age_becomes_semi_responsible} & flag_deceased != 1" 

global i1b_if_condition "dag >= ${age_becomes_semi_responsible} & receives_ypncp == 1 & flag_deceased != 1" 

* Labour supply
//??
