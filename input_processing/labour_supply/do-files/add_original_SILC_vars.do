***************************************************************************************
* PROJECT: ESPON: construct a cross-sectional panel dataset deom EU-SILC database 
* **************************************************************************************
version 14 
clear
set logtype smcl
set more off
set mem 200m
set type double

*open original SILC dataset in Stata 
insheet using "D:\Dasha\ESSEX\_SimPaths\_SimPaths_EU\PL\labour_supply\data\EU-SILC-2019-orig\UDB_cPL19P.csv", clear 
//save "D:\Dasha\ESSEX\ESPON 2024\PL\labour_supply\data\UDB_cPL19P.dta", replace

/*add additional variables from original EU-SILC */
//use "D:\Dasha\ESSEX\ESPON 2024\PL\labour_supply\data\UDB_cPL19P.dta", clear 
/*rename idperson_e idperson 
rename idhh_e idhh 
rename dgn_e dgn 
rename dag_e dag 
rename drgn1_e drgn1
*/
gen double idhh = px030
gen double idperson = pb030
qui count
display in y "P-FILE - number of observations: " r(N)
sort idhh idperson 

/**********************************Health status*******************************/
/*fre PH010
PH010 -- PH010
				
Freq.	Percent	Valid	Cum.
				
Valid 
1            1543	10.28	11.92	11.92
2            4769	31.79	36.84	48.76
3            4503	30.01	34.79	83.55
4            1582	10.54	12.22	95.77
5             547	3.65	4.23	100.00
Total       12944	86.28	100.00	          
Missing .            2059	13.72		          
Total               15003	100.00		          
	
code negative values to missing, reverse code so 5 = excellent and higher number means better health
*/

recode ph010 (5 = 1 "Poor") ///
	(4 = 2 "Fair") ///
	(3 = 3 "Good") ///
	(2 = 4 "Very good") ///
	(1 = 5 "Excellent") ///
	, into(dhe)
la var dhe "Health status"
fre dhe 

keep idperson idhh dhe 
sort idhh idperson

save "D:\Dasha\ESSEX\_SimPaths\_SimPaths_EU\PL\labour_supply\data\temp_dhe.dta", replace

