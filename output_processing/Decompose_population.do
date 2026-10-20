/*******************************************************************************
 * Decompose_population.do
 *
 * Purpose: Decompose the cumulative change in labor force (L) into four
 *          demographic components along the chain:
 *
 *          Total Population → WAP (15-64) → At-Risk → Workers (L)
 *
 *          L = Pop × (WAP/Pop) × (atRisk/WAP) × (L/atRisk)
 *
 *          In additive log terms:
 *          ln(L_t/L_0) = ln(Pop_t/Pop_0)
 *                      + ln[(WAP/Pop)_t / (WAP/Pop)_0]
 *                      + ln[(atRisk/WAP)_t / (atRisk/WAP)_0]
 *                      + ln[(L/atRisk)_t / (L/atRisk)_0]
 *
 *          Components:
 *            (1) Total population change      — demographic shrinkage/growth
 *            (2) Working-age share change      — age-composition within population
 *            (3) At-risk share change          — student/retirement transitions
 *            (4) Employment decision change    — labor supply discrete choice
 *
 *          Displayed as % change from the start year (matching l_level units).
 *
 * Requirements:
 *   The script points to a MacroPaths.csv from a SimPaths run.
 *   NEW FORMAT (recommended): CSV must contain columns
 *     l_level, total_population, wap_level, atrisk_level
 *   OLD FORMAT (fallback): CSV contains only
 *     l_level, participation_rate, workers_over_atriskpool
 *   In old format, WAP and atRisk level indices are reconstructed from rates.
 *
 * Usage:
 *   global macro_csv "C:/path/to/output/TIMESTAMP/csv/MacroPaths.csv"
 *   do "output_processing/Decompose_population.do"
 *
 * Output:
 *   - decomposition_L.png  : Stacked area chart + line overlay
 *   - decomposition_L.dta  : Dataset with decomposition variables
 *   - Console table with key years
 *
 ******************************************************************************/

clear all
set more off

// Maximum number of x-axis labels on quarterly graphs.
local max_x_labels = 10

local axis_helper_candidates "_quarterly_axis_helper.do output_processing/_quarterly_axis_helper.do ../output_processing/_quarterly_axis_helper.do ../../output_processing/_quarterly_axis_helper.do ../../../output_processing/_quarterly_axis_helper.do"
local axis_helper ""
foreach candidate of local axis_helper_candidates {
    cap confirm file "`candidate'"
    if _rc == 0 {
        local axis_helper "`candidate'"
        continue, break
    }
}
if "`axis_helper'" == "" {
    display as error "ERROR: Could not find output_processing/_quarterly_axis_helper.do"
    exit 601
}
quietly do "`axis_helper'"

local annual_axis_helper = subinstr("`axis_helper'", "_quarterly_axis_helper.do", "_annual_axis_helper.do", .)
cap confirm file "`annual_axis_helper'"
if _rc != 0 {
    display as error "ERROR: Could not find output_processing/_annual_axis_helper.do"
    exit 601
}
quietly do "`annual_axis_helper'"

// ============================================================================
// 0. CONFIGURATION
// ============================================================================

// Set this before running, or define it externally:
// global macro_csv "c:\Users\PC\_IAB\Projekte\SimPathsEU\output\20260302163908_42_0_baseline_noMacro\csv\MacroPaths.csv"
global macro_csv "c:\Users\PC\_IAB\Projekte\SimPathsEU\output\20260517124108_42_0\csv\MacroPaths.csv"

// Select which simulation run to use when MacroPaths.csv contains multiple runs.
local plot_run = 1


if "$macro_csv" == "" {
    display as error "ERROR: Set global macro_csv to the path of MacroPaths.csv"
    display as error {txt}"Example: global macro_csv " `"""' "C:/path/to/output/TIMESTAMP/csv/MacroPaths.csv" `"""'
    exit 198
}

cap confirm file "$macro_csv"
if _rc != 0 {
    display as error "ERROR: File not found: $macro_csv"
    exit 601
}

// Output directory: same as where the CSV lives
local csv_dir = subinstr("$macro_csv", "\", "/", .)
local last_slash = strrpos("`csv_dir'", "/")
if `last_slash' > 0 {
    local out_dir = substr("`csv_dir'", 1, `last_slash' - 1)
}
else {
    local out_dir "."
}

display as text "Reading: $macro_csv"
display as text "Output:  `out_dir'"

// ============================================================================
// 1. LOAD DATA
// ============================================================================

import delimited "$macro_csv", clear varnames(1)

cap confirm variable run
if _rc == 0 {
    quietly count if run == `plot_run'
    if r(N) == 0 {
        display as error "ERROR: Requested run `plot_run' not found in $macro_csv"
        exit 111
    }
    keep if run == `plot_run'
    display as text "Using run `plot_run' from $macro_csv"
}
else {
    if `plot_run' != 1 {
        display as error "ERROR: $macro_csv has no run column; only plot_run = 1 is valid for legacy single-run files"
        exit 111
    }
    display as text "No run column found in $macro_csv; treating file as a legacy single-run export"
}

// Time variable
gen t = _n
gen yq = yq(year, quarter)
format yq %tq
tsset yq

// Annual demographic series are repeated within each year; plot one observation per year.
bysort year (quarter): gen byte annual_plot = _n == 1
gen ya = yofd(dofq(yq))
format ya %ty

quietly summarize yq, meanonly
quietly quarterly_xaxis_opts yq, maxlabels(`max_x_labels')
local xaxisopts `"`r(xaxisopts)'"'
quietly annual_xaxis_opts ya if annual_plot, maxlabels(`max_x_labels')
local annual_xaxisopts `"`r(xaxisopts)'"'

// ============================================================================
// 2. DETECT FORMAT AND RECONSTRUCT LEVEL INDICES
// ============================================================================

// Check for new-format columns (directly exported level indices)
local has_new_format = 0
cap confirm variable total_population wap_level atrisk_level
if _rc == 0 {
    local has_new_format = 1
    display as text "Detected NEW format: total_population, wap_level, atrisk_level present."
}
else {
    display as text "Detected OLD format: deriving WAP/atRisk from rates (less precise)."
}

// ----- Find first non-zero observation (start of recording) -----
// l_level == 0 and participation_rate == 0 in pre-recording rows
cap confirm variable l_level
if _rc != 0 {
    display as error "ERROR: l_level column not found in CSV"
    exit 111
}

// Identify rows with actual data (non-zero l_level OR non-zero participation_rate)
// The first year is typically all zeros; the second year onward has data
gen byte _has_data = (l_level != 0 | participation_rate != 0)

// Find first row with data; use the row BEFORE that as t=0 (if it exists)
// OR use the first data row and treat first non-missing as t=0
summ t if _has_data == 1, meanonly
local first_data_row = r(min)

// The base period is one row before the first data row (last zero row before data starts)
// If data starts at row 5 (year 2, q1), base is row 4 (year 1, q4)
// But often the first data row IS the base (first year with non-zero participation_rate)
// Actually: We need the first row where participation_rate is nonzero as our base
summ t if participation_rate != 0, meanonly
local base_row = r(min)
display as text "Base row: `base_row' (year " year[`base_row'] " q" quarter[`base_row'] ")"

// Keep from base row onward
keep if t >= `base_row'
sort t
replace t = _n // Re-index

// ============================================================================
// 3. COMPUTE LEVEL INDICES
// ============================================================================

// All indices as % from base (row 1): index_t = (X_t / X_0 - 1) * 100
// l_level is already in this form from Java

if `has_new_format' {
    // New format: direct level indices from Java
    // total_population, wap_level, atrisk_level are already % from start year
    // Rename for consistency
    rename total_population pop_index     // % change in total population
    rename wap_level wap_index            // % change in WAP
    rename atrisk_level atrisk_index      // % change in at-risk pool
    gen double l_index = l_level          // % change in L (workers)
}
else {
    // Old format: reconstruct from rates
    // participation_rate = (workers / WAP) * 100
    // workers_over_atriskpool = (workers / atRisk) * 100

    // At base row, grab the initial rates
    local pr0 = participation_rate[1]
    local ar0 = workers_over_atriskpool[1]

    display as text "Base participation_rate: `pr0'%"
    display as text "Base workers/atRisk:     `ar0'%"

    // L_t / L_0 = 1 + l_level/100
    gen double l_ratio = 1 + l_level / 100

    // WAP_t / WAP_0 = (L_t/L_0) * (PR_0 / PR_t)
    // Because L/WAP = PR/100, so WAP = L / (PR/100)
    // WAP_t/WAP_0 = (L_t / (PR_t/100)) / (L_0 / (PR_0/100)) = (L_t/L_0) * (PR_0/PR_t)
    gen double wap_ratio = l_ratio * (`pr0' / participation_rate) ///
        if participation_rate > 0

    // atRisk_t / atRisk_0 = (L_t/L_0) * (AR_0 / AR_t)
    // Because L/atRisk = workers_over_atriskpool/100
    gen double atrisk_ratio = l_ratio * (`ar0' / workers_over_atriskpool) ///
        if workers_over_atriskpool > 0

    // Convert to % change from base
    gen double l_index = l_level
    gen double wap_index = (wap_ratio - 1) * 100
    gen double atrisk_index = (atrisk_ratio - 1) * 100

    // Total population: NOT available in old format
    // We'll set pop_index = 0 (assume constant total population) and note the limitation
    gen double pop_index = 0
    display as text "{bf:WARNING}: Total population not available in old CSV format."
    display as text "          pop_index set to 0; 'WAP share' component absorbs total pop changes."

    drop l_ratio wap_ratio atrisk_ratio
}

// ============================================================================
// 4. DECOMPOSITION
// ============================================================================

// Convert indices to ratio form for log decomposition: ratio = 1 + index/100
gen double pop_ratio   = 1 + pop_index / 100
gen double wap_ratio   = 1 + wap_index / 100
gen double atrisk_ratio = 1 + atrisk_index / 100
gen double l_ratio     = 1 + l_index / 100

// Log decomposition (exact, additive):
// ln(L_t/L_0) = ln(Pop_t/Pop_0)
//             + ln[(WAP/Pop)_t / (WAP/Pop)_0]
//             + ln[(atRisk/WAP)_t / (atRisk/WAP)_0]
//             + ln[(L/atRisk)_t / (L/atRisk)_0]

gen double ln_pop     = ln(pop_ratio)
gen double ln_wap_pop = ln(wap_ratio) - ln(pop_ratio)       // WAP share of total pop
gen double ln_ar_wap  = ln(atrisk_ratio) - ln(wap_ratio)    // at-risk share of WAP
gen double ln_l_ar    = ln(l_ratio) - ln(atrisk_ratio)      // employment decision
gen double ln_l_total = ln(l_ratio)                          // total (should = sum of components)

// Convert to percentage points (* 100) for readability
gen double comp_pop      = ln_pop * 100       // (1) Total population
gen double comp_wap_share = ln_wap_pop * 100  // (2) WAP share (age composition)
gen double comp_ar_share  = ln_ar_wap * 100   // (3) At-risk share (student/retirement)
gen double comp_empl      = ln_l_ar * 100     // (4) Employment decision
gen double comp_total     = ln_l_total * 100  // Total (= sum of above)

// Verify decomposition sums correctly
gen double _check = comp_pop + comp_wap_share + comp_ar_share + comp_empl - comp_total
summ _check, meanonly
if abs(r(max)) > 0.01 | abs(r(min)) > 0.01 {
    display as error "WARNING: Decomposition residual exceeds 0.01 pp (max=" r(max) ", min=" r(min) ")"
}
else {
    display as text "Decomposition check passed (max residual = " %6.4f r(max) ")"
}

label variable comp_pop       "Total population"
label variable comp_wap_share "WAP share (age composition)"
label variable comp_ar_share  "At-risk share (retirement/education)"
label variable comp_empl      "Employment decision"
label variable comp_total     "Total ln(L_t/L_0) × 100"
label variable l_index        "L level index (% from start)"
label variable pop_index      "Total population index (% from start)"
label variable wap_index      "WAP index (% from start)"
label variable atrisk_index   "At-risk pool index (% from start)"

// ============================================================================
// 5. CONSOLE TABLE — KEY YEARS
// ============================================================================

display ""
display as text "{hline 90}"
display as text "Decomposition of cumulative change in L (log points × 100 ≈ %)"
display as text "{hline 90}"
display as text %8s "Year" %12s "Total L" %14s "Population" %14s "WAP share" %14s "AtRisk share" %14s "Empl. dec."
display as text "{hline 90}"

// Display for Q1 of selected years (or nearest available)
foreach yr in 2026 2027 2028 2029 2030 2035 2040 2045 2050 2055 2060 {
    // Find Q1 of this year, or Q4 if Q1 not available
    cap count if year == `yr' & quarter == 1
    if r(N) > 0 {
        summ t if year == `yr' & quarter == 1, meanonly
        local row = r(min)
        display as text %8.0f `yr' ///
            %12.1f comp_total[`row'] ///
            %14.1f comp_pop[`row'] ///
            %14.1f comp_wap_share[`row'] ///
            %14.1f comp_ar_share[`row'] ///
            %14.1f comp_empl[`row']
    }
}
display as text "{hline 90}"
display as text "Note: Components are additive (ln decomposition, × 100)."
display as text "      Total ≈ l_level for small changes; exact decomposition for large ones."
display as text ""

// ============================================================================
// 6. GRAPH: STACKED AREA DECOMPOSITION
// ============================================================================

// For the stacked area, we need cumulative sums in order.
// Since components can be negative, use a "waterfall" stacking approach.
// We build from bottom to top, stacking at each layer.

// Approach: line chart with shaded areas between cumulative layers
// Layer 0 = 0 (baseline)
// Layer 1 = comp_pop
// Layer 2 = comp_pop + comp_wap_share
// Layer 3 = comp_pop + comp_wap_share + comp_ar_share
// Layer 4 = comp_pop + comp_wap_share + comp_ar_share + comp_empl = comp_total

gen double layer0 = 0
gen double layer1 = comp_pop
gen double layer2 = comp_pop + comp_wap_share
gen double layer3 = comp_pop + comp_wap_share + comp_ar_share
gen double layer4 = comp_total

local gopts "graphregion(color(white)) plotregion(margin(small))"
local gopts "`gopts' ylabel(, angle(0) labsize(small)) `annual_xaxisopts'"
local gopts "`gopts' xtitle("") ytitle("log points × 100 (≈ %)", size(small))"

graph drop _all

// Use twoway rarea for stacked areas
#d ;
twoway
    (rarea layer0 layer1 ya if annual_plot, color("26 150 65%40") lwidth(none))
    (rarea layer1 layer2 ya if annual_plot, color("255 127 0%40") lwidth(none))
    (rarea layer2 layer3 ya if annual_plot, color("55 126 184%40") lwidth(none))
    (rarea layer3 layer4 ya if annual_plot, color("228 26 28%40") lwidth(none))
    (line comp_total ya if annual_plot, lcolor(black) lwidth(medthick) lpattern(solid))
    (line layer0 ya if annual_plot, lcolor(gs8) lwidth(thin) lpattern(dash))
    ,
    legend(order(
        1 "Total population"
        2 "WAP share (age composition)"
        3 "At-risk share (retirement/education flows)"
        4 "Employment decision (labor supply model)"
        5 "Total change in L"
        )
        size(*.65) position(6) rows(3) region(lstyle(none)) symxsize(6pt)
    )
    title("Decomposition of cumulative change in L", size(medium))
    subtitle("Log decomposition: Pop → WAP → AtRisk → Workers", size(small))
    note("Source: SimPaths MacroPaths.csv" "Components are additive in log space", size(vsmall))
    `gopts'
    name(decomposition_L, replace)
;
#d cr

graph export "`out_dir'/decomposition_L.png", replace width(1800) height(1000)
display as text "Graph saved: `out_dir'/decomposition_L.png"

// ============================================================================
// 7. GRAPH: LEVEL INDICES (Pop, WAP, AtRisk, L)
// ============================================================================

#d ;
twoway
    (line pop_index ya if annual_plot, lcolor("26 150 65") lwidth(medium))
    (line wap_index ya if annual_plot, lcolor("255 127 0") lwidth(medium))
    (line atrisk_index ya if annual_plot, lcolor("55 126 184") lwidth(medium))
    (line l_index ya if annual_plot, lcolor("228 26 28") lwidth(medthick))
    ,
    legend(order(
        1 "Total population"
        2 "WAP (15-64)"
        3 "At-risk pool (non-student/retired 15-64)"
        4 "Workers L (hours > 0)"
        )
        size(*.65) position(6) rows(2) region(lstyle(none)) symxsize(6pt)
    )
    title("Population funnel: level indices (% from start year)", size(medium))
    subtitle("Each level is a subset of the one above", size(small))
    yline(0, lcolor(gs10) lpattern(dash))
    note("Source: SimPaths MacroPaths.csv", size(vsmall))
    `gopts'
    name(decomposition_levels, replace)
;
#d cr

graph export "`out_dir'/decomposition_levels.png", replace width(1800) height(1000)
display as text "Graph saved: `out_dir'/decomposition_levels.png"

// ============================================================================
// 8. GRAPH: RATIO COMPONENTS (shares over time)
// ============================================================================

// These are the ratios: WAP/Pop, atRisk/WAP, L/atRisk (in %)
// We need to reconstruct them from the indices

// If we have the new-format indices, we can compute exact ratios from start values.
// But since we only have index form, compute shares relative to base (normalized to 100).

gen double share_wap_pop  = exp(ln_wap_pop) * 100   // WAP/Pop relative to base (base = 100)
gen double share_ar_wap   = exp(ln_ar_wap) * 100    // atRisk/WAP relative to base
gen double share_l_ar     = exp(ln_l_ar) * 100      // L/atRisk relative to base

label variable share_wap_pop "WAP / Total pop (base=100)"
label variable share_ar_wap  "At-risk / WAP (base=100)"
label variable share_l_ar    "Workers / At-risk (base=100)"

#d ;
twoway
    (line share_wap_pop ya if annual_plot, lcolor("255 127 0") lwidth(medium))
    (line share_ar_wap ya if annual_plot, lcolor("55 126 184") lwidth(medium))
    (line share_l_ar ya if annual_plot, lcolor("228 26 28") lwidth(medium))
    ,
    legend(order(
        1 "WAP / Total pop"
        2 "At-risk / WAP"
        3 "Workers / At-risk"
        )
        size(*.65) position(6) rows(1) region(lstyle(none)) symxsize(6pt)
    )
    title("Population funnel: share indices (base year = 100)", size(medium))
    subtitle("Decomposition ratios showing where participation is lost", size(small))
    yline(100, lcolor(gs10) lpattern(dash))
    note("Source: SimPaths MacroPaths.csv", size(vsmall))
    `gopts'
    name(decomposition_shares, replace)
;
#d cr

graph export "`out_dir'/decomposition_shares.png", replace width(1800) height(1000)
display as text "Graph saved: `out_dir'/decomposition_shares.png"

// ============================================================================
// 9. SAVE DATASET
// ============================================================================

keep year quarter yq t ///
     l_level l_index pop_index wap_index atrisk_index ///
     comp_pop comp_wap_share comp_ar_share comp_empl comp_total ///
     share_wap_pop share_ar_wap share_l_ar ///
     participation_rate workers_over_atriskpool

order year quarter yq t ///
      l_level pop_index wap_index atrisk_index ///
      comp_pop comp_wap_share comp_ar_share comp_empl comp_total

save "`out_dir'/decomposition_L.dta", replace
display as text "Dataset saved: `out_dir'/decomposition_L.dta"

display ""
display as text "{hline 60}"
display as text "Done. Three graphs and one dataset saved."
display as text "{hline 60}"
