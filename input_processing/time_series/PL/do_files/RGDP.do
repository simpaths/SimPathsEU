/*******************************************************************************
* PROJECT:        SimPaths EU
* SECTION:        Additional series
* OBJECT:         Real GDP (RGDP)
* AUTHORS:        Ashley Burdett
* LAST UPDATE:    3/11/2026
* COUNTRY:        PL
********************************************************************************
* NOTES:          Constructs the real GDP alignment series for Poland using
*                 Eurostat national accounts data.
*
*                 Uses GDP at market prices (B1GQ) measured in chain-linked
*                 volumes (CLV15_MEUR), converted to an index with 2015 = 100.
*
*                 Eurostat observation flags (e.g. "p") are removed prior to
*                 converting the series to numeric values.
*
*                 https://ec.europa.eu/eurostat/cache/metadata/en/nama10_esms.htm
* 				https://ec.europa.eu/eurostat/databrowser/explore/all/economy?sort=category&lang=en&subtheme=na10.nama10.nama_10_ma&display=list
*******************************************************************************/
clear all
set more off
capture log close 


* Import data 
import delimited using "$dir_input_data/estat_nama_10_gdp.tsv", ///
	delimiters(tab) clear
	
* Organize dataset	
forvalues i = 1/83 {
	
	local y = 1973 + `i'
	capture rename v`i' y`y'
	
}

rename y1974 freq_unit_na_item_geo
	
drop if y1975 == "1975 "	
		
* Select country of interest 
keep if substr(freq, -2, 2) ==  "${country}" 	

* Select total GDP
keep if substr(freq, -7, 4) == "B1GQ" 	

* Select chain-linked volumnes series for RGDP
keep if substr(freq, 3, 10) == "CLV15_MEUR" 	

* Prep formatting 
drop freq


* Remove Eurostat flags from year values
foreach var of varlist y* {
	
    replace `var' = word(`var', 1)
    replace `var' = "" if `var' == ":"

}

* Convert year values to numeric
destring y*, replace

* Only keep relevant years 
drop y1975-y1994

* Transpose 
xpose, clear 

gen Year = 1995
replace Year = Year[_n-1] + 1 if Year[_n-1] != . 

rename v1 RGDP

order Year RGDP

* Create RGDP index with base in 2015
summ RGDP if Year == 2015, meanonly
local base = r(mean)

gen Value = RGDP / `base' * 100


******************************* EXPORT TO EXCEL ********************************

* Info sheet 

putexcel set "$dir_work/time_series_factor${country}.xlsx", ///
    sheet("Info") replace 

putexcel A1 = "Purpose:" ///
    B1 = "This file stores the macroeconomic uprating index series used by SimPaths to revalue monetary amounts and wage-related inputs across years."

putexcel A2 = "Developers:" ///
    B2 = "Poland series prepared by Ashley Burdett (AB)."

putexcel A3 = "First version:" ///
    B3 = "2025"

putexcel A4 = "Last version:" ///
    B4 = "3/11/2026 (AB)"

putexcel A5 = "Created using:" ///
    B5 = "Do-files RGDP.do, inflation.do, wages.do contained in time_series/do_files."

putexcel A6 = "Sheets used by model:" ///
    B6 = "gdp, inflation, wage_growth."

putexcel A7 = "Source - gdp:" ///
    B7 = "Eurostat National Accounts (nama_10_gdp). GDP at market prices (B1GQ), measured in chain-linked volumes with reference year 2015 (CLV15_MEUR), is used to construct the real GDP series for Poland. The series is converted to an index with 2015 = 100."

putexcel A8 = "Source - inflation:" ///
    B8 = "Eurostat Harmonised Index of Consumer Prices (HICP), annual data (prc_hicp_aind). The annual average all-items HICP index (INX_A_AVG, CP00) is used for Poland."

putexcel A9 = "Source - wage_growth:" ///
    B9 = "Eurostat annual Labour Cost Index (lc_lci_r2_a). The wages and salaries component (D11) for industry, construction and services (B-S) is used. The nominal LCI is rebased to 2015 = 100 and deflated using the all-items HICP index to construct a real wage index. The annual percentage growth rate of this real wage index is also provided."

putexcel A10 = "Units / interpretation:" ///
    B10 = "The gdp and inflation sheets store index values. In the wage_growth sheet, Value is the real wage index (2015 = 100) constructed from the deflated Labour Cost Index, while Growth is its year-on-year percentage change. The model treats the index series as relative series and rebases them to BASE_PRICE_YEAR (currently 2015) after loading."

putexcel A11 = "Coverage in current workbook:" ///
    B11 = "gdp: 1995-2025; inflation: 1996-2025; wage_growth: 2000-2025."

putexcel A12 = "How gdp is used:" ///
    B12 = "Mapped to UpratingCase.Capital, ModelInitialise, and Pension. After rebasing, it is used where the model needs a GDP-based uprating factor for capital-like or model-initialisation terms."

putexcel A13 = "How inflation is used:" ///
    B13 = "Mapped to UpratingCase.TaxDonor. After rebasing, it is used to normalise donor-tax-system monetary values between policy-system years and the model base-price year."

putexcel A14 = "How wage_growth is used:" ///
    B14 = "Mapped to UpratingCase.Earnings and passed into the person-level wage regressions through the RealWageGrowth regressor. The wage_growth sheet contains both the real wage index (Value) and its annual percentage growth rate (Growth) so that alternative specifications can be explored."

putexcel A15 = "Date produced / maintenance note:" ///
    B15 = "Workbook first prepared for Poland in 2025. Oragnized and standardardized in 3/11/26."

putexcel A16 = "NOTE:" ///
    B16 = "All cells read by the model should contain plain numeric data only. The wage_growth sheet contains Year, Value (real wage index), and Growth (annual percentage change in the real wage index). Remove formulas, merged headers, and non-numeric values from active sheets."

putexcel A1:A16, bold


* Add data	
export excel Year Value using "$dir_work/time_series_factor${country}.xlsx", ///
    sheet("gdp") sheetmodify firstrow(variables)
