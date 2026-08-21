/*******************************************************************************
 * compare_feedback.do
 *
 * Purpose: Demonstrate what the recursive Ramsey feedback channel does, against
 *          the pure top-down coupling, from a 2x2 x N-seed experiment:
 *
 *              {baseline, reform} x {feedback off, feedback persistent (rho=1)}
 *
 *          Companion to
 *          docs/superpowers/plans/2026-08-17-ramsey-recursive-feedback-RESULTS.md
 *
 * Why several seeds and not one run: the per-seed difference-in-differences
 * flips sign across seeds (participation at 2060 runs from -0.72 to +0.92 pp),
 * so a single-run comparison shows RNG noise, not the channel. Only w_trend
 * under feedback OFF is seed-invariant, and the script verifies that rather
 * than assuming it.
 *
 * Workflow:
 *   1. Run all four arms with maxNumberOfRuns: N (seeds land in the same order
 *      in every arm, so the arms are paired seed by seed)
 *   2. Set the four directories below
 *   3. Run this script
 *
 * Output (written to $fb_outdir):
 *   - feedback_channel_live.png/.pdf    : Figure 1, the loop and its two halves
 *   - feedback_scenario_effect.png/.pdf : Figure 2, what it changes in a scenario
 *   - feedback_tile_*.png               : individual tiles (if export_individual)
 *   - feedback_comparison.txt           : all statistics behind the figures
 *   - feedback_merged.dta               : the (run x year) wide dataset
 *
 ******************************************************************************/

clear all
set more off

// ============================================================================
// 0. CONFIGURATION -- set these before running
// ============================================================================

global fb_root "c:/Users/PC/_IAB/Projekte/SimPathsEU/output"

global fb_base_off   "$fb_root/ramsey-feedback-off_20seeds_20260819151020/csv"
global fb_reform_off "$fb_root/ramsey-feedback-off-TFP_20seeds_20260819151020/csv"
global fb_base_on    "$fb_root/ramsey-feedback-persistent_20seeds_20260819151020/csv"
global fb_reform_on  "$fb_root/ramsey-feedback-persistent-TFP_20seeds_20260819151020/csv"

global fb_reform_label "Higher TFP growth (+0.5 pp gA)"

// The planner's own hours path, as handed to SimPaths in the input bundle. Read here so the
// note can quantify what measuring delta_h against that path rather than against SimPaths'
// latch-year hours would cost, without any number being retyped.
global fb_hoursproj "c:/Users/PC/_IAB/Projekte/SimPathsEU/input/PL/MacroModel/hours_projection_Poland.csv"

// Leave empty to write next to the baseline feedback-on run.
global fb_outdir ""

// Overleaf note. Leave either empty to skip that export.
global fb_figdir "c:/Users/PC/_IAB/Projekte/WELLSIM_SVEC_Overleaf/Notes/Figures_Ramsey_feedback_channel"
global fb_texdir "c:/Users/PC/_IAB/Projekte/WELLSIM_SVEC_Overleaf/Notes/Tables_Ramsey_feedback_channel"

// Maximum number of x-axis labels on annual graphs.
local max_x_labels = 10

// Also export every tile as its own PNG (useful for slides).
local export_individual = 1

// Drop the overall title, subtitle and note from the two combined figures. The
// LaTeX caption and figure note carry that text in the Overleaf version.
local publication_mode = 1

// First year in which the channel is active. The first re-solve lands in 2025:
// 2023 and 2024 carry structural zeros for the gap and the revision.
local first_active = 2025

// Wage response to a controlled +2% persistent employment surprise, in percent
// of wage level per percent of employment. NOT identifiable from these CSVs:
// it comes from the RamseyTrendModel unit test (-0.5612% / 2%), and is the
// planner-side half of the loop gain reported in section 9.4 of the RESULTS doc.
local dwdl_unittest = -0.2806

// ============================================================================
// 1. GUARDS AND HELPERS
// ============================================================================

if "$fb_outdir" == "" {
    global fb_outdir "$fb_base_on"
}

cap confirm file "$fb_hoursproj"
if _rc != 0 {
    display as error "ERROR: hours projection not found at $fb_hoursproj"
    exit 601
}

local armdirs "$fb_base_off $fb_reform_off $fb_base_on $fb_reform_on"
local armnames "base_off reform_off base_on reform_on"
local i = 1
foreach d of local armdirs {
    local nm : word `i' of `armnames'
    cap confirm file "`d'/MacroPaths.csv"
    if _rc != 0 {
        display as error "ERROR: MacroPaths.csv not found for arm `nm' in `d'"
        exit 601
    }
    local ++i
}

local axis_helper_candidates "$fb_root/../output_processing/_annual_axis_helper.do output_processing/_annual_axis_helper.do _annual_axis_helper.do ../output_processing/_annual_axis_helper.do ../../output_processing/_annual_axis_helper.do ../../../output_processing/_annual_axis_helper.do"
local annual_axis_helper ""
foreach candidate of local axis_helper_candidates {
    cap confirm file "`candidate'"
    if _rc == 0 {
        local annual_axis_helper "`candidate'"
        continue, break
    }
}
if "`annual_axis_helper'" == "" {
    display as error "ERROR: Could not find output_processing/_annual_axis_helper.do"
    exit 601
}
quietly do "`annual_axis_helper'"

capture program drop _fb_load_arm
program define _fb_load_arm
    syntax , DIRectory(string) ARM(string)

    import delimited "`directory'/MacroPaths.csv", clear varnames(1)

    cap confirm variable run
    if _rc != 0 {
        display as error "ERROR: `directory'/MacroPaths.csv has no run column; this script needs a multi-seed export (maxNumberOfRuns > 1)"
        exit 111
    }

    // Annual series repeat across the four quarters of a year.
    keep if quarter == 1

    keep run year w_trend participation_rate l_level h_level wage_realized ///
         n_ramsey n_realized_gap h_realized_gap w_trend_revision total_population

    // Short, mutually non-prefixing stubs: reshape matches stubs by prefix, so
    // w_trend and w_trend_revision cannot both survive as-is.
    rename w_trend            wt
    rename participation_rate part
    rename l_level            llev
    rename h_level            hlev
    rename wage_realized      wreal
    rename n_ramsey           nram
    rename n_realized_gap     ngap
    rename h_realized_gap     hgap
    rename w_trend_revision   wrev
    rename total_population   pop

    gen str4 arm = "`arm'"
end

// ============================================================================
// 2. LOAD THE FOUR ARMS
// ============================================================================

tempfile a_boff a_roff a_bon a_ron

_fb_load_arm, directory("$fb_base_off")   arm("boff")
quietly save `a_boff'
_fb_load_arm, directory("$fb_reform_off") arm("roff")
quietly save `a_roff'
_fb_load_arm, directory("$fb_base_on")    arm("bon")
quietly save `a_bon'
_fb_load_arm, directory("$fb_reform_on")  arm("ron")
quietly save `a_ron'

use `a_boff', clear
append using `a_roff' `a_bon' `a_ron'

// Every arm must carry the same seeds and the same horizon, or the seed pairing
// the whole design rests on is not there.
quietly levelsof run, local(runlist)
local nruns : word count `runlist'
quietly summarize year, meanonly
local yrmin = r(min)
local yrmax = r(max)
local nyears = `yrmax' - `yrmin' + 1

if `nruns' < 2 {
    display as error "ERROR: found only `nruns' seed(s). The cross-seed standard errors this script reports are undefined at one seed; rerun the arms with maxNumberOfRuns > 1."
    exit 459
}

foreach a in boff roff bon ron {
    quietly count if arm == "`a'"
    local nobs = r(N)
    if `nobs' != `nruns' * `nyears' {
        display as error "ERROR: arm `a' has `nobs' annual observations; expected `nruns' seeds x `nyears' years"
        exit 459
    }
}

display as text "Arms loaded: `nruns' seeds, years `yrmin'-`yrmax'"

// ============================================================================
// 3. RESHAPE AND DERIVE
// ============================================================================

reshape wide wt part llev hlev wreal nram ngap hgap wrev pop, i(run year) j(arm) string

sort run year

// ---- Is the top-down path really seed-invariant? --------------------------
// Demeaning by the cross-seed mean of the OFF arm makes this visible rather
// than assumed: the OFF lines collapse onto zero only if they truly coincide.
bysort year: egen double mwt_off = mean(wtboff)
gen double dev_off = wtboff - mwt_off
gen double dev_on  = wtbon  - mwt_off

// ---- Feedback-on minus feedback-off, within the baseline scenario ---------
gen double gap_w    = wtbon   - wtboff
gen double gap_part = partbon - partboff
gen double gap_l    = llevbon - llevboff
gen double gap_wr   = wrealbon - wrealboff

// Same gaps in elasticity-ready units: percent of level, not index points.
// w_trend is a percent deviation from the first year, so the level factor is
// (1 + w_trend/100); taking the ratio removes the index-point/level ambiguity
// that would otherwise force an arbitrary evaluation point.
gen double gap_w_pct    = 100 * ((1 + wtbon/100) / (1 + wtboff/100) - 1)
gen double gap_part_pct = 100 * (partbon / partboff - 1)
gen double gap_wr_pct   = 100 * ((1 + wrealbon/100) / (1 + wrealboff/100) - 1)

// Intensive margin. h_level is a percent index, so the level ratio needs the
// (1 + x/100) form, unlike participation_rate which is already a level.
gen double gap_h_pct = 100 * ((1 + hlevbon/100) / (1 + hlevboff/100) - 1)

// The hours gap the channel WOULD feed back if mm_ramseyFeedbackHours were on.
// h_realized_gap is exactly zero in these runs because the hours channel is off,
// but delta_h is defined against SimPaths' own latch-year hours, so it can be
// reconstructed here: delta_h,t = h_sim(t) / h_sim(latch). Showing it answers
// whether switching the channel on would give the planner anything to react to.
quietly generate double _hlatch = hlevbon if year == `first_active' - 1
bysort run (year): egen double hlatch = max(_hlatch)
quietly drop _hlatch
gen double hgap_would = 100 * ((1 + hlevbon/100) / (1 + hlatch/100) - 1)

// With the hours channel on, the model records the same object in h_realized_gap. The
// two must agree, or the panel and the regressor below describe different quantities.
quietly generate double _hchk = abs(hgap_would - hgapbon) if hgapbon != 0
quietly summarize _hchk, meanonly
if r(N) > 0 & r(max) > 1e-6 {
    display as error "ERROR: reconstructed hours gap differs from the recorded h_realized_gap by up to " r(max)
    exit 459
}
quietly drop _hchk

// ---- The planner's forecast error and its response ------------------------
// n_realized_gap is only computed when the channel is on; it is logged as an
// exact zero in the feedback-off arms.
bysort run (year): gen double d_gap  = ngapbon - ngapbon[_n-1]
bysort run (year): gen double d_hgap = hgapbon - hgapbon[_n-1]

// The planner's labour input is N*h, so the surprise it re-solves on is the sum of the
// two gap changes. Regressing the revision on d_gap alone omits the hours half and turns
// a deterministic transfer function into a scatter.
gen double d_lab = d_gap + d_hgap

// ---- Reform effect, and the difference-in-differences ---------------------
gen double eff_off = wtroff - wtboff
gen double eff_on  = wtron  - wtbon

gen double did_w    = eff_on - eff_off
gen double did_part = (partron - partbon)   - (partroff - partboff)
gen double did_l    = (llevron - llevbon)   - (llevroff - llevboff)
gen double did_h    = (hlevron - hlevbon)   - (hlevroff - hlevboff)
gen double did_wr   = (wrealron - wrealbon) - (wrealroff - wrealboff)
gen double did_pop  = (popron - popbon)     - (poproff - popboff)

label var gap_w    "w_trend, feedback on - top-down (index points)"
label var did_w    "DiD: reform effect on w_trend, feedback on - off"
label var did_part "DiD: reform effect on participation rate, feedback on - off"
label var did_wr   "DiD: reform effect on realized wage, feedback on - off"

// ---- Cross-seed mean and +/-2 SE band, by year ----------------------------
foreach v in did_w did_part did_l did_h did_wr did_pop eff_on eff_off {
    bysort year: egen double m_`v'  = mean(`v')
    bysort year: egen double sd_`v' = sd(`v')
    bysort year: egen double n_`v'  = count(`v')
    gen double se_`v' = sd_`v' / sqrt(n_`v')
    gen double lo_`v' = m_`v' - 2*se_`v'
    gen double hi_`v' = m_`v' + 2*se_`v'
}

// Cross-seed envelope for the planner's forecast error.
bysort year: egen double gapmean = mean(ngapbon)
bysort year: egen double gapmin  = min(ngapbon)
bysort year: egen double gapmax  = max(ngapbon)

bysort year: egen double hgapmean = mean(hgap_would)
bysort year: egen double hgapmin  = min(hgap_would)
bysort year: egen double hgapmax  = max(hgap_would)

quietly annual_xaxis_opts year if run == 1, maxlabels(`max_x_labels')
local annual_xaxisopts `"`r(xaxisopts)'"'

// ============================================================================
// 4. STATISTICS
// ============================================================================

tempfile didfile

// Quantities the Overleaf note quotes, collected once so no number is retyped.
quietly summarize sd_did_w    // force the by-year statistics into memory before preserve games
preserve
    quietly collapse (sd) sdoff = wtboff sdon = wtbon, by(year)
    quietly summarize sdoff if year == `yrmax', meanonly
    local sd_off_last = r(mean)
    quietly summarize sdon if year == `yrmax', meanonly
    local sd_on_last = r(mean)
restore

quietly summarize gapmean, meanonly
local gap_trough = r(min)
quietly summarize year if gapmean == `gap_trough', meanonly
local gap_trough_year = r(mean)
quietly summarize gapmean if year == `yrmax', meanonly
local gap_last = r(mean)

quietly generate double _absgw = abs(gap_w_pct)
quietly summarize _absgw, meanonly
local gap_w_pct_max = r(max)
quietly drop _absgw

// The trend-wage index is a percent deviation from the first year, so a
// difference of D index points between two arms is a level difference of
// D / (1 + w_base/100) percent, not D percent.
quietly summarize wtboff if year == `yrmax', meanonly
local wt_base_last = r(mean)
quietly summarize wtroff if year == `yrmax', meanonly
local wt_reform_last = r(mean)
local eff_off_level_pct = 100 * ((1 + `wt_reform_last'/100) / (1 + `wt_base_last'/100) - 1)

// Treatment size: how large a surprise does each scenario hand the planner?
quietly generate double _absgb = abs(ngapbon)
quietly generate double _absgr = abs(ngapron)
quietly summarize _absgb, meanonly
local gap_max_base = r(max)
quietly summarize _absgr, meanonly
local gap_max_reform = r(max)

quietly summarize hgapmean if year == `yrmax', meanonly
local hgap_last = r(mean)

// What the planner assumes about hours, and what it would read as a surprise if delta_h were
// measured against that assumption. SimPaths models no hours trend, so the whole difference is
// a disagreement between two modelling assumptions rather than a labour-market surprise.
local latch_year = `first_active' - 1
preserve
    quietly import delimited "$fb_hoursproj", clear varnames(1)
    quietly generate int _y = real(substr(time, 1, 4))
    quietly summarize h if _y == `latch_year', meanonly
    local h_plan_latch = r(mean)
    quietly summarize h if _y == `yrmax', meanonly
    local h_plan_last = r(mean)
restore
local hours_ratio      = `h_plan_last' / `h_plan_latch'
local hours_trend_rate = 100 * (1 - `hours_ratio'^(1/(`yrmax' - `latch_year')))
local hours_plan_drop  = 100 * (1 - `hours_ratio')
local hours_app_gap    = 100 * ((1 + `hgap_last'/100) / `hours_ratio' - 1)
local hours_app_wage   = abs(`dwdl_unittest') * `hours_app_gap'
quietly drop _absgb _absgr

capture log close _all
log using "$fb_outdir/feedback_comparison.txt", replace text name(fblog)
set linesize 100

quietly {

noisily display as text "{hline 78}"
noisily display as text "RECURSIVE RAMSEY FEEDBACK vs PURE TOP-DOWN"
noisily display as text "{hline 78}"
noisily display as text "Seeds:        `nruns'   (paired across all four arms)"
noisily display as text "Horizon:      `yrmin'-`yrmax'"
noisily display as text "Reform arm:   $fb_reform_label"
noisily display as text "Channel active from: `first_active'"
noisily display as text ""
noisily display as text "base, feedback off   : $fb_base_off"
noisily display as text "reform, feedback off : $fb_reform_off"
noisily display as text "base, feedback on    : $fb_base_on"
noisily display as text "reform, feedback on  : $fb_reform_on"

// ---- 4a. Validity: is the top-down trend deterministic? -------------------
noisily display as text ""
noisily display as text "{hline 78}"
noisily display as text "1. SEED-INVARIANCE OF THE RAMSEY WAGE TREND"
noisily display as text "{hline 78}"
noisily display as text "   With the loop open the trend is an input and cannot depend on the seed."
noisily display as text "   Closing it makes the trend a function of what SimPaths' population did."
noisily display as text ""

preserve
    collapse (sd) sd_boff = wtboff sd_roff = wtroff sd_bon = wtbon sd_ron = wtron, by(year)
    noisily display as text %-34s "arm" %14s "max SD over years" %14s "SD at `yrmax'"
    noisily display as text "{hline 78}"
    foreach a in boff roff bon ron {
        quietly summarize sd_`a', meanonly
        local mx = r(max)
        quietly summarize sd_`a' if year == `yrmax', meanonly
        local lastsd = r(mean)
        local lbl = cond("`a'" == "boff", "baseline, feedback off", ///
                    cond("`a'" == "roff", "reform,   feedback off", ///
                    cond("`a'" == "bon",  "baseline, feedback on ", "reform,   feedback on ")))
        noisily display as result %-34s "`lbl'" %14.6f `mx' %14.6f `lastsd'
    }
restore

// Test bit-identity directly on the cross-seed range. Demeaning would fold in
// the rounding error of the mean itself (order 1e-14), which is not a finding.
preserve
    quietly bysort year: egen double _rng = max(wtboff)
    quietly bysort year: egen double _rnl = min(wtboff)
    quietly generate double _rng_off = _rng - _rnl
    quietly summarize _rng_off, meanonly
    local devoff_max = r(max)
restore

noisily display as text ""
if `devoff_max' == 0 {
    noisily display as result "   CONFIRMED: every feedback-off seed traces a bit-identical trend (cross-seed range = 0)."
}
else {
    noisily display as error "   WARNING: feedback-off trends differ across seeds (max cross-seed range = " %12.4e `devoff_max' ")."
    noisily display as error "   Figure 1's 'coincident' claim does not hold for these runs -- check the arm directories."
}

// ---- 4b. Planner side: revision as a function of the forecast error -------
noisily display as text ""
noisily display as text "{hline 78}"
noisily display as text "2. PLANNER SIDE -- wage-trend revision vs the change in the effective-labour gap"
noisily display as text "{hline 78}"

quietly regress wrevbon d_lab if year >= `first_active'
local b_rev  = _b[d_lab]
local se_rev = _se[d_lab]
local r2_rev = e(r2)
local n_rev  = e(N)
// Heads-only fit, kept as a diagnostic: the distance between the two R2s is the size of
// the hours half of the surprise, not noise.
quietly regress wrevbon d_gap if year >= `first_active'
local r2_rev_heads = e(r2)
// Entered separately the two gap changes must carry the same coefficient: the planner's
// labour input is N*h, so a 1% hours surprise and a 1% headcount surprise are the same
// surprise. This is the restriction the single d_lab regressor above imposes.
quietly regress wrevbon d_gap d_hgap if year >= `first_active'
local b_rev_n = _b[d_gap]
local b_rev_h = _b[d_hgap]
local r2_rev_sep = e(r2)

// How much the extended-path convention costs. The wage SimPaths uses for year t was
// computed before year t's labour supply was known, so the size of the following re-solve
// is exactly what anticipating that labour supply would have saved.
quietly generate double _absrev = abs(wrevbon) if year >= `first_active'
quietly summarize _absrev, meanonly
local rev_abs_mean = r(mean)
local rev_abs_max  = r(max)
quietly drop _absrev
local b_rev_f  : display %7.4f `b_rev'
local r2_rev_f : display %6.4f `r2_rev'

noisily display as text ""
noisily display as result "   revision = " %7.4f `b_rev' " x d(n_gap + h_gap)   (SE " %6.4f `se_rev' ", R2 = " %6.4f `r2_rev' ", N = " %4.0f `n_rev' ")"
noisily display as text   "   Heads-only regressor for comparison: R2 = " %6.4f `r2_rev_heads'
noisily display as text   "   Entered separately: d(n_gap) " %7.4f `b_rev_n' ", d(h_gap) " %7.4f `b_rev_h' ", R2 = " %6.4f `r2_rev_sep'
noisily display as text   "   Size of the one-year staleness: mean |revision| " %6.4f `rev_abs_mean' "%, max " %6.4f `rev_abs_max' "%"
noisily display as text "   Unit-test elasticity for comparison: " %7.4f `dwdl_unittest'
noisily display as text "   A near-deterministic transfer function, not a black box."

// ---- 4c. Micro side: labour-supply response to the trend wage -------------
noisily display as text ""
noisily display as text "{hline 78}"
noisily display as text "3. MICRO SIDE -- response to the revised trend wage (per-seed slopes)"
noisily display as text "{hline 78}"
noisily display as text "   Per seed, regress the (feedback on - off) gap in each series on the"
noisily display as text "   (feedback on - off) gap in the wage trend, then t-test across seeds."
noisily display as text ""

tempfile slopefile
tempname pf
postfile `pf' int seed double(b_part b_llev b_wreal b_elast b_hours b_net) using "`slopefile'", replace
forvalues s = 1/`nruns' {
    quietly regress gap_part gap_w if run == `s' & year >= `first_active'
    local bp = _b[gap_w]
    quietly regress gap_l gap_w if run == `s' & year >= `first_active'
    local bl = _b[gap_w]
    quietly regress gap_wr_pct gap_w_pct if run == `s' & year >= `first_active'
    local bw = _b[gap_w_pct]
    quietly regress gap_part_pct gap_w_pct if run == `s' & year >= `first_active'
    local be = _b[gap_w_pct]
    quietly regress gap_h_pct gap_w_pct if run == `s' & year >= `first_active'
    local bh = _b[gap_w_pct]
    local bn = `be' + `bh'
    post `pf' (`s') (`bp') (`bl') (`bw') (`be') (`bh') (`bn')
}
postclose `pf'

preserve
    use "`slopefile'", clear
    noisily display as text %-46s "quantity" %10s "mean" %10s "SE" %8s "t"
    noisily display as text "{hline 78}"

    quietly ttest b_part == 0
    local el_part_m = r(mu_1)
    local el_part_se = r(se)
    local el_part_t = r(t)
    noisily display as result %-46s "participation rate, pp per w_trend index point" %10.4f r(mu_1) %10.4f r(se) %8.2f r(t)

    quietly ttest b_llev == 0
    noisily display as result %-46s "employment l_level, pp per w_trend index point" %10.4f r(mu_1) %10.4f r(se) %8.2f r(t)

    quietly ttest b_wreal == 0
    local pass_m = r(mu_1)
    local pass_se = r(se)
    noisily display as result %-46s "realized wage pass-through, % per % of wage" %10.4f r(mu_1) %10.4f r(se) %8.2f r(t)

    quietly ttest b_elast == 0
    local elast_m  = r(mu_1)
    local elast_se = r(se)
    local elast_t  = r(t)
    local elast_df = r(df_t)
    noisily display as result %-46s "extensive-margin elasticity, % per % of wage" %10.4f r(mu_1) %10.4f r(se) %8.2f r(t)

    // Intensive margin. SimPaths chooses hours from a discrete labour-supply
    // menu, so this is the response of mean hours among workers, not a smooth
    // margin, and it is expected to be far weaker than the extensive one.
    quietly ttest b_hours == 0
    local hours_m  = r(mu_1)
    local hours_se = r(se)
    local hours_t  = r(t)
    noisily display as result %-46s "intensive-margin elasticity, % per % of wage" %10.4f r(mu_1) %10.4f r(se) %8.2f r(t)

    // Both margins feed back since 2026-08-19, so the micro half of the loop is the
    // response of the labour input N*h. Formed per seed, so the SE accounts for the
    // correlation between the two slopes rather than assuming independence.
    quietly ttest b_net == 0
    local net_m  = r(mu_1)
    local net_se = r(se)
    local net_t  = r(t)
    noisily display as result %-46s "net N*h elasticity, % per % of wage" %10.4f r(mu_1) %10.4f r(se) %8.2f r(t)
restore

noisily display as text ""
noisily display as text "   Pass-through of 1 means the trend wage reaches individual wages one for one,"
noisily display as text "   which is what the multiplicative overlay implies by construction."
noisily display as text ""
noisily display as text "   The first row is the RESULTS doc's units (pp of participation per index point)."
noisily display as text "   The last row converts both sides to percent of level before regressing, which"
noisily display as text "   avoids picking an evaluation point for the index-to-level factor."
noisily display as text ""
noisily display as text "   SAMPLE SIZE. The planner-side transfer function above needs no seeds at all:"
noisily display as text "   the Ramsey solve is deterministic once the labour path is given. The micro slopes"
noisily display as text "   do, and their cross-seed SD is several times their mean, so read them as magnitudes"
noisily display as text "   with a standard error rather than as precisely estimated parameters."

// ---- 4d. Loop gain --------------------------------------------------------
noisily display as text ""
noisily display as text "{hline 78}"
noisily display as text "4. LOOP GAIN"
noisily display as text "{hline 78}"

local loopgain = `dwdl_unittest' * `net_m'
local atten    = 1 / (1 - `loopgain')
local damping  = 100 * (1 - `atten')

// Propagate only the estimated half's uncertainty; dw/dL is taken as given.
local lg_lo = `dwdl_unittest' * (`net_m' + 2*`net_se')
local lg_hi = `dwdl_unittest' * (`net_m' - 2*`net_se')
local damp_lo = 100 * (1 - 1/(1 - `lg_lo'))
local damp_hi = 100 * (1 - 1/(1 - `lg_hi'))

noisily display as text ""
noisily display as result "   dw/dL (planner, unit test)     = " %8.4f `dwdl_unittest'
noisily display as result "   d(Nh)/dw (micro, `nruns' seeds)   = " %8.4f `net_m' "   (SE " %6.4f `net_se' ", t = " %5.2f `net_t' ", df = " %2.0f `elast_df' ")"
noisily display as result "   loop gain g                    = " %8.4f `loopgain'
noisily display as result "   attenuation 1/(1-g)            = " %8.4f `atten'
noisily display as result "   damping of a persistent labour-supply shock = " %5.2f `damping' " %"
noisily display as result "   approx. 95% range from the micro half       = " %5.2f min(`damp_lo',`damp_hi') " to " %5.2f max(`damp_lo',`damp_hi') " %"
noisily display as text ""
noisily display as text "   dw/dL is the impact (next-year) response; as capital accumulates the wage"
noisily display as text "   partly recovers, so this is closer to an upper bound than a long-run figure."

// ---- 4e. Difference-in-differences at the horizon -------------------------
noisily display as text ""
noisily display as text "{hline 78}"
noisily display as text "5. DIFFERENCE-IN-DIFFERENCES AT `yrmax'"
noisily display as text "{hline 78}"
noisily display as text "   (reform - baseline | feedback on) - (reform - baseline | feedback off),"
noisily display as text "   computed per seed and t-tested across seeds."
noisily display as text ""

tempname pd
postfile `pd' str24 series double(eoff eon did se tstat) using "`didfile'", replace

preserve
    quietly keep if year == `yrmax'
    noisily display as text %-30s "series" %12s "effect OFF" %12s "effect ON" %10s "DiD" %8s "SE" %7s "t"
    noisily display as text "{hline 78}"

    quietly summarize eff_off, meanonly
    local eo = r(mean)
    local eff_off_last = `eo'
    quietly summarize eff_on, meanonly
    local en = r(mean)
    quietly ttest did_w == 0
    local did_w_m = r(mu_1)
    local did_w_se = r(se)
    local did_w_t = r(t)
    noisily display as result %-30s "w_trend (index points)" %12.3f `eo' %12.3f `en' %10.3f r(mu_1) %8.3f r(se) %7.2f r(t)
    post `pd' ("Wage trend") (`eo') (`en') (r(mu_1)) (r(se)) (r(t))

    foreach v in part l h wr pop {
        local lbl = cond("`v'" == "part", "participation rate (pp)", ///
                    cond("`v'" == "l",    "employment l_level (pp)", ///
                    cond("`v'" == "h",    "hours per worker (index)", ///
                    cond("`v'" == "wr",   "realized wage (index)  ", "total population (index)  "))))
        local tex = cond("`v'" == "part", "Participation rate", ///
                    cond("`v'" == "l",    "Employment", ///
                    cond("`v'" == "h",    "Hours per worker", ///
                    cond("`v'" == "wr",   "Realized wage", "Total population"))))
        local onvar = cond("`v'" == "part", "part", cond("`v'" == "l", "llev", ///
                      cond("`v'" == "h", "hlev", cond("`v'" == "wr", "wreal", "pop"))))
        quietly generate double _eoff = `onvar'roff - `onvar'boff
        quietly generate double _eon  = `onvar'ron  - `onvar'bon
        quietly summarize _eoff, meanonly
        local eo = r(mean)
        quietly summarize _eon, meanonly
        local en = r(mean)
        quietly ttest did_`v' == 0
        noisily display as result %-30s "`lbl'" %12.3f `eo' %12.3f `en' %10.3f r(mu_1) %8.3f r(se) %7.2f r(t)
        post `pd' ("`tex'") (`eo') (`en') (r(mu_1)) (r(se)) (r(t))
        drop _eoff _eon
    }
    noisily display as text "{hline 78}"
restore

postclose `pd'

noisily display as text ""
noisily display as text "   The wage trend moves and it is measurable. Realized wages, participation and"
noisily display as text "   employment do not move outside cross-seed noise. Total population is the"
noisily display as text "   calibration for that claim: the channel cannot touch it, yet its DiD wanders"
noisily display as text "   around zero just as visibly -- that is what a true zero looks like here."
noisily display as text "   Correct, cheap, small."

// ---- 4f. Per-seed DiD, to show why one run is not enough ------------------
noisily display as text ""
noisily display as text "{hline 78}"
noisily display as text "6. PER-SEED DiD AT `yrmax' -- why a single run cannot carry this"
noisily display as text "{hline 78}"
noisily display as text ""

preserve
    quietly keep if year == `yrmax'
    noisily display as text %-8s "seed" %14s "DiD w_trend" %14s "DiD particip." %14s "DiD real. wage"
    noisily display as text "{hline 78}"
    forvalues s = 1/`nruns' {
        quietly summarize did_w if run == `s', meanonly
        local d1 = r(mean)
        quietly summarize did_part if run == `s', meanonly
        local d2 = r(mean)
        quietly summarize did_wr if run == `s', meanonly
        local d3 = r(mean)
        noisily display as result %-8.0f `s' %14.4f `d1' %14.4f `d2' %14.4f `d3'
    }
    noisily display as text "{hline 78}"
restore

noisily display as text ""
noisily display as text "   Signs flip across seeds in every column. Pick one run and the picture is"
noisily display as text "   whichever one that seed happened to draw."
noisily display as text ""
noisily display as text "{hline 78}"

}

log close fblog

// ============================================================================
// 5. FIGURE 1 -- THE LOOP IS LIVE, AND ITS TWO HALVES
// ============================================================================

graph drop _all
set graph off

local gopts "ylabel(, angle(0) labsize(vsmall)) xtitle("", size(vsmall))"
local gopts "`gopts' graphregion(color(white)) plotregion(margin(small))"
local legstyle "size(*.55) position(6) rows(1) region(lstyle(none)) symxsize(5pt) rowgap(0)"

// ---- Tile A: the fan ------------------------------------------------------
local fanplots ""
forvalues s = 1/`nruns' {
    local fanplots `"`fanplots' (line dev_off year if run == `s', lcolor(cranberry) lwidth(medthick))"'
}
forvalues s = 1/`nruns' {
    local fanplots `"`fanplots' (line dev_on year if run == `s', lcolor(navy%50) lwidth(thin))"'
}
local key_off = 1
local key_on  = `nruns' + 1

twoway `fanplots', ///
    title("Ramsey wage trend by seed", size(small)) ///
    subtitle("deviation from the top-down path", size(vsmall)) ///
    ytitle("index points", size(vsmall)) ///
    `gopts' `annual_xaxisopts' ///
    legend(order(`key_off' "top-down (coincident)" `key_on' "recursive feedback") `legstyle') ///
    name(tile_fan, replace)

// ---- Tile B: what the planner reacts to -----------------------------------
twoway ///
    (rarea gapmin gapmax year if run == 1, color(navy%18) lwidth(none)) ///
    (line gapmean year if run == 1, lcolor(navy) lwidth(medthick)) ///
    (function y=0, range(year) lcolor(gs10) lpattern(dash)), ///
    title("Realized employment gap", size(small)) ///
    subtitle("realized minus projected employment", size(vsmall)) ///
    ytitle("%", size(vsmall)) ///
    `gopts' `annual_xaxisopts' ///
    legend(order(2 "cross-seed mean" 1 "min-max across seeds") `legstyle') ///
    name(tile_gap, replace)

// ---- Tile B2: the hours gap the channel would see --------------------------
twoway ///
    (rarea hgapmin hgapmax year if run == 1, color(navy%18) lwidth(none)) ///
    (line hgapmean year if run == 1, lcolor(navy) lwidth(medthick)) ///
    (function y=0, range(year) lcolor(gs10) lpattern(dash)), ///
    title("Realized hours gap", size(small)) ///
    subtitle("realized hours relative to the latch year", size(vsmall)) ///
    ytitle("%", size(vsmall)) ///
    `gopts' `annual_xaxisopts' ///
    legend(order(2 "cross-seed mean" 1 "min-max across seeds") `legstyle') ///
    name(tile_hgap, replace)

// ---- Tile C: planner response ---------------------------------------------
twoway ///
    (scatter wrevbon d_lab if year >= `first_active', ///
        msymbol(circle_hollow) msize(small) mcolor(navy%40)) ///
    (lfit wrevbon d_lab if year >= `first_active', lcolor(cranberry) lwidth(medthick)), ///
    title("Wage-trend revision", size(small)) ///
    subtitle("against the change in the effective-labour gap", size(vsmall)) ///
    ytitle("revision (index points)", size(vsmall)) ///
    xtitle("change in effective-labour gap (pp)", size(vsmall)) ///
    note("slope `b_rev_f', R{superscript:2} `r2_rev_f'", size(vsmall)) ///
    ylabel(, angle(0) labsize(vsmall)) xlabel(, labsize(vsmall)) ///
    graphregion(color(white)) plotregion(margin(small)) ///
    legend(off) ///
    name(tile_transfer, replace)

// ---- Tile D: micro response -----------------------------------------------
local elast_f  : display %6.3f `elast_m'
local elast_tf : display %5.2f `elast_t'

twoway ///
    (scatter gap_part_pct gap_w_pct if year >= `first_active', ///
        msymbol(circle_hollow) msize(small) mcolor(navy%40)) ///
    (lfit gap_part_pct gap_w_pct if year >= `first_active', lcolor(cranberry) lwidth(medthick)), ///
    title("Participation response", size(small)) ///
    subtitle("against the wage-trend gap", size(vsmall)) ///
    ytitle("participation gap (%)", size(vsmall)) ///
    xtitle("wage-trend gap (%)", size(vsmall)) ///
    note("per-seed mean elasticity `elast_f' (t `elast_tf', df `elast_df'); line is pooled OLS", size(vsmall)) ///
    ylabel(, angle(0) labsize(vsmall)) xlabel(, labsize(vsmall)) ///
    graphregion(color(white)) plotregion(margin(small)) ///
    legend(off) ///
    name(tile_elasticity, replace)

// ---- Tile D2: intensive-margin response ------------------------------------
local hours_f  : display %6.3f `hours_m'
local hours_tf : display %5.2f `hours_t'

twoway ///
    (scatter gap_h_pct gap_w_pct if year >= `first_active', ///
        msymbol(circle_hollow) msize(small) mcolor(navy%40)) ///
    (lfit gap_h_pct gap_w_pct if year >= `first_active', lcolor(cranberry) lwidth(medthick)), ///
    title("Hours response", size(small)) ///
    subtitle("against the wage-trend gap", size(vsmall)) ///
    ytitle("hours gap (%)", size(vsmall)) ///
    xtitle("wage-trend gap (%)", size(vsmall)) ///
    note("per-seed mean elasticity `hours_f' (t `hours_tf', df `elast_df'); line is pooled OLS", size(vsmall)) ///
    ylabel(, angle(0) labsize(vsmall)) xlabel(, labsize(vsmall)) ///
    graphregion(color(white)) plotregion(margin(small)) ///
    legend(off) ///
    name(tile_hours, replace)

// ============================================================================
// 6. FIGURE 2 -- WHAT IT CHANGES IN A SCENARIO
// ============================================================================

// ---- Tile E: the reform effect, both ways ---------------------------------
twoway ///
    (line m_eff_off year if run == 1, lcolor(cranberry) lwidth(medthick)) ///
    (line m_eff_on year if run == 1, lcolor(navy) lpattern(dash) lwidth(medthick)), ///
    title("Reform effect on the wage trend", size(small)) ///
    subtitle("$fb_reform_label", size(vsmall)) ///
    ytitle("index points", size(vsmall)) ///
    `gopts' `annual_xaxisopts' ///
    legend(order(1 "feedback off" 2 "feedback on") `legstyle') ///
    name(tile_reform, replace)

// ---- Tiles F-J: the DiD bands ---------------------------------------------
// Total population is dropped from the figure to keep it 2x3 with the hours
// panel in. It stays in the DiD table, where it does the same job: a series the
// channel cannot touch, so its row is the noise floor the others are read against.
local didvars   "did_w did_part did_l did_h did_wr"
local didnames  "tile_did_w tile_did_part tile_did_l tile_did_h tile_did_wr"
#d ;
local didtitles `"
    "Difference in the reform effect"
    "DiD: participation rate"
    "DiD: employment level"
    "DiD: hours per worker"
    "DiD: realized wage"
    "' ;
local didsubs `"
    "w_trend, feedback on minus off"
    "feedback on minus off"
    "extensive margin"
    "intensive margin"
    "feedback on minus off"
    "' ;
local didunits `" "index points" "pp" "pp" "index points" "index points" "' ;
#d cr

local i = 1
foreach v of local didvars {
    local nm  : word `i' of `didnames'
    local ttl : word `i' of `didtitles'
    local sub : word `i' of `didsubs'
    local unt : word `i' of `didunits'

    twoway ///
        (rarea lo_`v' hi_`v' year if run == 1, color(navy%18) lwidth(none)) ///
        (line m_`v' year if run == 1, lcolor(navy) lwidth(medthick)) ///
        (function y=0, range(year) lcolor(cranberry) lpattern(dash)), ///
        title("`ttl'", size(small)) ///
        subtitle("`sub'", size(vsmall)) ///
        ytitle("`unt'", size(vsmall)) ///
        `gopts' `annual_xaxisopts' ///
        legend(order(2 "cross-seed mean" 1 "+/- 2 SE") `legstyle') ///
        name(`nm', replace)

    local ++i
}

// ============================================================================
// 7. COMBINE AND EXPORT
// ============================================================================

set graph on

local damping_f : display %4.1f `damping'

if `publication_mode' {
    local fig1_head ""
    local fig2_head ""
}
else {
    local fig1_head `"title("The recursive Ramsey feedback channel is live", size(medsmall)) subtitle("Poland, `yrmin'-`yrmax', `nruns' paired seeds per arm", size(small))"'
    local fig2_head `"title("What the feedback changes in a scenario", size(medsmall)) subtitle("$fb_reform_label, difference-in-differences over `nruns' paired seeds", size(small))"'
}

graph combine tile_fan tile_gap tile_hgap tile_transfer tile_elasticity tile_hours, ///
    `fig1_head' ///
    rows(2) cols(3) ///
    graphregion(color(white)) ///
    name(fig_live, replace)

graph export "$fb_outdir/feedback_channel_live.png", replace width(2400)
graph export "$fb_outdir/feedback_channel_live.pdf", replace

graph combine tile_reform tile_did_w tile_did_part tile_did_l tile_did_h tile_did_wr, ///
    `fig2_head' ///
    rows(2) cols(3) ///
    graphregion(color(white)) ///
    name(fig_scenario, replace)

graph export "$fb_outdir/feedback_scenario_effect.png", replace width(2400)
graph export "$fb_outdir/feedback_scenario_effect.pdf", replace

if "$fb_figdir" != "" {
    cap mkdir "$fb_figdir"
    graph display fig_live
    graph export "$fb_figdir/feedback_channel_live.pdf", replace
    graph display fig_scenario
    graph export "$fb_figdir/feedback_scenario_effect.pdf", replace
    display as text "Overleaf figures: $fb_figdir"
}

if `export_individual' {
    foreach g in tile_fan tile_gap tile_hgap tile_transfer tile_elasticity tile_hours ///
                 tile_reform tile_did_w tile_did_part tile_did_l tile_did_h tile_did_wr {
        graph display `g'
        graph export "$fb_outdir/feedback_`g'.png", replace width(1200)
    }
}

save "$fb_outdir/feedback_merged.dta", replace

// ============================================================================
// 8. LATEX ARTEFACTS FOR THE OVERLEAF NOTE
// ============================================================================
// Every quantity the note quotes is written from here, so no result is retyped
// into the prose. Backslashes are assembled with char(92) and concatenation: a
// literal backslash placed immediately before a Stata macro reference would
// suppress that macro's expansion.

capture program drop _fb_texmacro
program define _fb_texmacro
    args name value
    local bs = char(92)
    file write texnum ("`bs'" + "newcommand{" + "`bs'" + "`name'" + "}{" + "`value'" + "}") _n
end

if "$fb_texdir" != "" {

    local damp_reform = 100 * abs(`did_w_m') / `eff_off_last'
    local damp_min = min(`damp_lo', `damp_hi')
    local damp_max = max(`damp_lo', `damp_hi')

    capture file close texnum
    file open texnum using "$fb_texdir/Ramsey_feedback_channel_numbers.tex", write replace text
    file write texnum "% Generated by output_processing/compare_feedback.do. Do not edit by hand." _n
    file write texnum "% Regenerate after any rerun of the four experiment arms." _n

    _fb_texmacro FbSeeds      "`nruns'"
    _fb_texmacro FbYearFirst  "`yrmin'"
    _fb_texmacro FbYearLast   "`yrmax'"
    _fb_texmacro FbYearActive "`first_active'"

    local v = trim(string(`b_rev', "%5.3f"))
    _fb_texmacro FbRevSlope "`v'"
    local v = trim(string(`r2_rev', "%6.4f"))
    _fb_texmacro FbRevRsq "`v'"
    local v = trim(string(`r2_rev_heads', "%6.4f"))
    _fb_texmacro FbRevRsqHeads "`v'"
    local v = trim(string(`b_rev_n', "%5.3f"))
    _fb_texmacro FbRevSlopeN "`v'"
    local v = trim(string(`b_rev_h', "%5.3f"))
    _fb_texmacro FbRevSlopeH "`v'"
    local v = trim(string(`rev_abs_mean', "%4.2f"))
    _fb_texmacro FbRevAbsMean "`v'"
    local v = trim(string(`rev_abs_max', "%4.2f"))
    _fb_texmacro FbRevAbsMax "`v'"
    local v = trim(string(`n_rev', "%4.0f"))
    _fb_texmacro FbRevN "`v'"

    local v = trim(string(`el_part_m', "%6.4f"))
    _fb_texmacro FbElastPart "`v'"
    local v = trim(string(`el_part_se', "%6.4f"))
    _fb_texmacro FbElastPartSE "`v'"
    local v = trim(string(`el_part_t', "%4.2f"))
    _fb_texmacro FbElastPartT "`v'"

    local v = trim(string(`pass_m', "%5.3f"))
    _fb_texmacro FbPassThrough "`v'"
    local v = trim(string(`pass_se', "%5.3f"))
    _fb_texmacro FbPassThroughSE "`v'"

    local v = trim(string(`elast_m', "%5.3f"))
    _fb_texmacro FbElast "`v'"
    local v = trim(string(`elast_se', "%5.3f"))
    _fb_texmacro FbElastSE "`v'"
    local v = trim(string(`elast_t', "%4.2f"))
    _fb_texmacro FbElastT "`v'"
    local v = trim(string(`elast_df', "%2.0f"))
    _fb_texmacro FbElastDF "`v'"

    local v = trim(string(`hours_m', "%6.3f"))
    _fb_texmacro FbElastHours "`v'"
    local v = trim(string(abs(`hours_m'), "%6.3f"))
    _fb_texmacro FbElastHoursAbs "`v'"
    local v = trim(string(`hours_se', "%5.3f"))
    _fb_texmacro FbElastHoursSE "`v'"
    local v = trim(string(`hours_t', "%5.2f"))
    _fb_texmacro FbElastHoursT "`v'"
    // Net response of the labour input N*h, which is what the production function
    // uses. The two margins offset, so feeding hours back as well would shrink the
    // loop gain rather than enlarge it.
    local v = trim(string(`net_m', "%6.3f"))
    _fb_texmacro FbElastNet "`v'"
    local v = trim(string(`net_se', "%5.3f"))
    _fb_texmacro FbElastNetSE "`v'"
    local v = trim(string(`net_t', "%5.2f"))
    _fb_texmacro FbElastNetT "`v'"

    local v = trim(string(`dwdl_unittest', "%6.3f"))
    _fb_texmacro FbDwdl "`v'"
    local v = trim(string(`loopgain', "%6.3f"))
    _fb_texmacro FbLoopGain "`v'"
    local v = trim(string(`atten', "%5.3f"))
    _fb_texmacro FbAtten "`v'"
    local v = trim(string(`damping', "%4.1f"))
    _fb_texmacro FbDamping "`v'"
    local v = trim(string(`damp_min', "%4.1f"))
    _fb_texmacro FbDampLo "`v'"
    local v = trim(string(`damp_max', "%4.1f"))
    _fb_texmacro FbDampHi "`v'"
    // What the damping would be if a tax-benefit reform delivered a participation
    // elasticity three times the one identified here.
    local lg3 = `dwdl_unittest' * 3 * `net_m'
    local v = trim(string(100 * (1 - 1/(1 - `lg3')), "%4.1f"))
    _fb_texmacro FbDampingTripleElast "`v'"

    local v = trim(string(`did_w_m', "%6.3f"))
    _fb_texmacro FbDidW "`v'"
    local v = trim(string(abs(`did_w_m'), "%6.3f"))
    _fb_texmacro FbDidWAbs "`v'"
    local v = trim(string(`did_w_se', "%5.3f"))
    _fb_texmacro FbDidWSE "`v'"
    local v = trim(string(`did_w_t', "%5.2f"))
    _fb_texmacro FbDidWT "`v'"
    local v = trim(string(`eff_off_last', "%5.1f"))
    _fb_texmacro FbEffOff "`v'"
    // The index is a percent deviation from the first year, so an index-point
    // difference is not a percent difference in level: convert it.
    local v = trim(string(`wt_base_last', "%5.1f"))
    _fb_texmacro FbBaseTrendLast "`v'"
    local v = trim(string(`eff_off_level_pct', "%5.1f"))
    _fb_texmacro FbEffOffLevel "`v'"
    local v = trim(string(`damp_reform', "%4.1f"))
    _fb_texmacro FbDampReform "`v'"

    local v = trim(string(`sd_off_last', "%8.6f"))
    _fb_texmacro FbSdOff "`v'"
    local v = trim(string(`sd_on_last', "%5.3f"))
    _fb_texmacro FbSdOn "`v'"

    local v = trim(string(`gap_trough', "%4.1f"))
    _fb_texmacro FbGapTrough "`v'"
    local v = trim(string(`gap_trough_year', "%4.0f"))
    _fb_texmacro FbGapTroughYear "`v'"
    local v = trim(string(`gap_last', "%4.1f"))
    _fb_texmacro FbGapLast "`v'"
    local v = trim(string(`gap_w_pct_max', "%5.2f"))
    _fb_texmacro FbWageGapMax "`v'"
    local v = trim(string(abs(`gap_trough'), "%4.1f"))
    _fb_texmacro FbGapTroughAbs "`v'"
    local v = trim(string(`gap_max_base', "%4.1f"))
    _fb_texmacro FbGapMaxBase "`v'"
    local v = trim(string(`gap_max_reform', "%4.1f"))
    _fb_texmacro FbGapMaxReform "`v'"
    local v = trim(string(`hgap_last', "%4.1f"))
    _fb_texmacro FbHoursGapLast "`v'"
    local v = trim(string(`hours_trend_rate', "%4.2f"))
    _fb_texmacro FbHoursTrendRate "`v'"
    local v = trim(string(`hours_plan_drop', "%4.1f"))
    _fb_texmacro FbHoursPlannerDrop "`v'"
    local v = trim(string(`hours_app_gap', "%4.1f"))
    _fb_texmacro FbHoursApparentGap "`v'"
    local v = trim(string(`hours_app_wage', "%4.1f"))
    _fb_texmacro FbHoursApparentWage "`v'"

    // Wage shift a permanent-wage-shift instrument would need to move the
    // realized employment gap by 10 percent at the estimated elasticity.
    local v = trim(string(5 * round(10 / `elast_m' / 5), "%4.0f"))
    _fb_texmacro FbWageShiftForTen "`v'"

    file close texnum

    // ---- The difference-in-differences table --------------------------------
    local bs = char(92)
    local eol = char(92) + char(92)

    capture file close textab
    file open textab using "$fb_texdir/Ramsey_feedback_channel_did.tex", write replace text

    file write textab "% Generated by output_processing/compare_feedback.do. Do not edit by hand." _n
    file write textab "\begin{table}[H]" _n "\centering" _n
    file write textab ("\caption{Effect of the higher TFP growth scenario in " + "`yrmax'" + ", with and without the recursive feedback}") _n
    file write textab "\label{tab:fb_did}" _n
    file write textab "\begin{tabular}{lrrrrr}" _n "\toprule" _n
    file write textab (" & \multicolumn{2}{c}{Scenario effect} & \multicolumn{3}{c}{Difference} " + "`eol'") _n
    file write textab "\cmidrule(lr){2-3} \cmidrule(lr){4-6}" _n
    file write textab ("Series & Feedback off & Feedback on & Difference & SE & t " + "`eol'") _n
    file write textab "\midrule" _n

    preserve
        use "`didfile'", clear
        local nrows = _N
        forvalues r = 1/`nrows' {
            local nm = series[`r']
            local c1 = trim(string(eoff[`r'],  "%9.3f"))
            local c2 = trim(string(eon[`r'],   "%9.3f"))
            local c3 = trim(string(did[`r'],   "%9.3f"))
            local c4 = trim(string(se[`r'],    "%8.3f"))
            local c5 = trim(string(tstat[`r'], "%7.2f"))
            file write textab ("`nm' & `c1' & `c2' & `c3' & `c4' & `c5' " + "`eol'") _n
        }
    restore

    file write textab "\bottomrule" _n "\end{tabular}" _n
    file write textab "\begin{minipage}{\textwidth}" _n
    file write textab "\vspace{2mm} \footnotesize" _n
    file write textab ("\textit{Notes:} The scenario effect is the difference between the higher TFP growth run and the baseline run in " + "`yrmax'" + ",") _n
    file write textab ("averaged over the " + "`nruns'" + " seeds. The difference is the scenario effect with the recursive feedback switched on minus") _n
    file write textab "the scenario effect with the feedback switched off, computed seed by seed and then averaged. Standard errors" _n
    file write textab ("and t statistics come from a paired t test across the " + "`nruns'" + " seeds, with " + "`=`nruns'-1'" + " degrees of freedom. The wage trend and") _n
    file write textab ("the realized wage are index points, that is, percent deviations from " + "`yrmin'" + ". Participation and employment are") _n
    file write textab "percentage points. Total population is an index and cannot respond to the feedback, so its row measures the" _n
    file write textab ("difference that arises from seed noise alone. " + "`eol'") _n
    file write textab "\textit{Source:} SimPaths runs for Poland, own calculations." _n
    file write textab "\end{minipage}" _n "\end{table}" _n
    file close textab

    display as text "LaTeX artefacts: $fb_texdir/Ramsey_feedback_channel_{numbers,did}.tex"
}

display as text ""
display as text "Figures saved to: $fb_outdir"
display as text "  feedback_channel_live.png/.pdf"
display as text "  feedback_scenario_effect.png/.pdf"
display as text "Statistics:       $fb_outdir/feedback_comparison.txt"
display as text "Merged data:      $fb_outdir/feedback_merged.dta"
