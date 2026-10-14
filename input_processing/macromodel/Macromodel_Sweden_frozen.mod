// =========================================================================
// FROZEN MODEL - AUTO-GENERATED
// Generated: 2026-10-13 14:43:59
// Source: Macromodel_Sweden (estimation results)
// DO NOT EDIT MANUALLY - regenerate with generate_frozen_model.m
// =========================================================================

// =========================================================================
// DSGE Model - SWEDEN
// =========================================================================
// Thin wrapper: defines country and includes shared template.
// All structural equations are in Macromodel_template.mod.
// Country-specific parameters are in country_params/Sweden_*.mod.
//
// Usage:  >> dynare Macromodel_Sweden use_dll
// =========================================================================

// =========================================================================
// DSGE Model for Microsimulation Coupling - FROZEN (estimated parameters) — COUNTRY-AGNOSTIC TEMPLATE
// Based on Search & Matching Framework with Production
// =========================================================================
//
// This is the shared template. Country-specific parameters, priors, and
// shock calibrations are loaded via @#include from country_params/.
//
// USAGE:
//   Do NOT run this file directly. Use the country wrapper instead:
//     >> dynare Macromodel_Germany use_dll
//     >> dynare Macromodel_Poland use_dll
//
//   Each wrapper defines @#define country = "..." and includes this template.
//
// ADDING A NEW COUNTRY:
//   1. Create country_params/{Country}_calibration.mod  (parameter values)
//   2. Create country_params/{Country}_estimation.mod   (shocks, priors, data)
//   3. Create Macromodel_{Country}.mod  (2-line wrapper)
// =========================================================================

// =========================================================================
// USER SWITCHES (Dynare macro preprocessor)
// =========================================================================
@#define do_parameter_estimation = false  // FROZEN: estimation disabled
@#define use_real_data = true
@#define use_custom_irfs = false   // FROZEN: use standard IRFs for export


// =========================================================================
// SIMPATHS INTEGRATION SWITCH
// =========================================================================
// Set to true when exporting policy functions for SimPaths Java integration.
// When true, rho_L and rho_h are set to ZERO so that:
//   - L = eps_L (labor force directly equals SimPaths input)
//   - h = eps_h (hours directly equals SimPaths input)
//
// RATIONALE: During estimation, rho_L=0.95 and rho_h=0.85 capture the observed
// persistence in the estimation sample. But for SimPaths coupling, SimPaths sends LEVELS
// (deviation from baseline), not innovations. Setting rho=0 ensures the DSGE
// interprets SimPaths inputs as levels, not as innovations that accumulate.
//
// UNITS: eps_L/eps_h are PERCENT log-deviations (100*ln ratio), matching the
// 100x-log-deviation data the model is estimated on. +5% labour force = eps_L ~= 4.879.
//
// Without this switch: SimPaths input eps_L=5 would cause L to grow to
// 5/(1-0.95) = 100 (i.e. +100%) due to AR(1) accumulation.
// With this switch: L = eps_L = 5 directly (5%), as intended.
@#define for_simpaths_export = true

//
// PURPOSE:
// This model serves as "economic guardrails" for a dynamic microsimulation.
// It provides general equilibrium wage responses to labor supply changes
// from a discrete choice microsimulation model.
//
// INTERFACE WITH MICROSIMULATION:
// ┌─────────────────┐                    ┌─────────────────┐
// │  Microsim       │  ── L (labor) ──►  │  DSGE           │
// │  (Java)         │  ── h (hours) ──►  │  (Dynare→Java)  │
// │                 │  ◄── w (wage) ───  │                 │
// │                 │  ◄── pi (infl) ──  │                 │
// └─────────────────┘                    └─────────────────┘
//
// INPUT:  L  = labor force change (extensive margin: participation)
//         h  = hours per worker change (intensive margin: hours choice)
// OUTPUT: w  = real wage change (equilibrium response)
//         pi = inflation (equilibrium response)
//
// FREQUENCY: Quarterly (for estimation), convert to annual for microsim
// =========================================================================

// Variable declarations
// Endogenous variables (all in log-deviations from steady state)
var 
    y       // output (production function)    [SUPPLY-DETERMINED]
    d       // aggregate demand (Euler equation) [DEMAND-DETERMINED]
    c       // consumption (Euler equation)          [OBSERVED]
    gap     // demand-supply gap (d - y)
    R       // nominal interest rate
    pi      // inflation                        [OUTPUT TO MICROSIM]
    w       // real wage (aggregate)            [OUTPUT TO MICROSIM]
    w_star  // reset wage (newly negotiated)    [Gertler-Trigari]
    u       // unemployment level (log-deviation, for internal dynamics)
    u_rate  // unemployment RATE gap (pp, for observation)
    v       // vacancies
    n       // employment
    h       // hours per worker (intensive margin) [INPUT FROM MICROSIM]
    m       // matches
    mc      // marginal cost
    x       // technology (TFP)
    theta   // labor market tightness (v/u)
    L       // labor force (participation)     [INPUT FROM MICROSIM]
    k       // capital stock (predetermined)    [CAPITAL EXTENSION]
    inv     // investment (reduced-form rule)    [CAPITAL EXTENSION]
    sep_shock    // separation shock process
    d_shock;     // demand/preference shock AR(1) state

// Exogenous shocks
varexo 
    eps_a       // technology shock
    eps_r       // monetary policy shock
    eps_d       // PREFERENCE/DEMAND shock (confidence, fiscal, exports)
    eps_p       // cost-push / price markup shock (energy, imports, markup)
    eps_L       // labor force shock (FROM MICROSIM)
    eps_sep     // separation rate shock
    eps_h       // hours shock (FROM MICROSIM or Kurzarbeit policy)
    eps_inv;    // investment shock [CAPITAL EXTENSION]

// Parameters
parameters 
    beta        // discount factor
    sigma       // inverse IES (risk aversion)
    alpha_m     // elasticity of matching w.r.t. unemployment
    alpha_n     // labor elasticity of output (production function)
    eta         // worker bargaining power
    kappa       // vacancy posting cost parameter
    delta       // separation rate (steady state)
    phi_pi      // Taylor rule: inflation response
    phi_y       // Taylor rule: output response
    rho_a       // persistence of technology shock
    rho_r       // interest rate smoothing
    rho_v       // vacancy persistence
    rho_L       // persistence of labor force changes
    rho_sep     // persistence of separation shock
    rho_d       // persistence of preference/demand shock
    lambda_p    // slope of Phillips curve (prices)
    lambda_w    // Calvo wage stickiness (Gertler-Trigari)
    phi_mc      // output gap sensitivity of marginal cost
    phi_v_y     // vacancy sensitivity to output gap (demand conditions)
    chi_n       // steady state employment rate (N/pop)
    chi_u       // steady state unemployment SHARE (U/pop) = chi_L - chi_n
                // NOT the U/L unemployment rate - see eq. 10 below
    chi_L       // steady state labor force rate (L/pop)
    // INTENSIVE MARGIN (hours) parameters
    rho_h       // hours persistence (Kurzarbeit/contract duration)
    omega_h     // hours weight in production function
    // DIRECT LABOR FORCE EFFECT ON WAGES (reduced-form wage drift)
    psi_wL      // wage response to labor force (bypasses slow θ channel)
    // DEMAND COMPOSITION
    s_inv       // steady-state investment share of GDP (I_ss/Y_ss)
    // CAPITAL EXTENSION PARAMETERS (Phase 2: Approach B)
    alpha_k     // capital share in production (Cobb-Douglas)
    delta_k     // quarterly capital depreciation rate
    rho_inv     // investment persistence
    phi_inv_y   // investment sensitivity to output gap
    phi_inv_r   // investment sensitivity to interest rate
    // HABIT PERSISTENCE (V14)
    hab         // external habit formation parameter (0 = no habits, 1 = full)
    // INFLATION INDEXATION (V15)
    iota_p;     // backward-looking inflation indexation (0 = no indexation, 1 = full)

// =========================================================================
// COUNTRY-SPECIFIC PARAMETER CALIBRATION
// =========================================================================
// Loaded from country_params/{country}_calibration.mod
// Contains: all parameter values, steady-state labor market ratios
// =========================================================================
// PARAMETER CALIBRATION (Quarterly Frequency) - SWEDEN
// =========================================================================
// Data sources:
//   - Labor market: SCB (Statistics Sweden) via Eurostat LFS, OECD LFS
//   - National accounts: SCB via Eurostat (namq_10_gdp, namq_10_pe)
//   - Monetary policy: Riksbank (Sweden is OUTSIDE the euro area)
//
// NOTE: Swedish sample is 2001q1-2025q1 (97 obs). The start is a DATA
// constraint - the OECD LFS stocks begin 2001q1 - not a regime choice; it
// sits well inside the inflation-targeting regime Sweden adopted in 1993,
// so the whole sample is one monetary regime. Ramsey calibration:
// alpha_K=0.33, delta=0.055 annual, g_A=0.65% annual (derived from this
// sample; see Sweden_growth_params.json).
//
// Two features distinguish Sweden from the three countries already in the
// repo: an INDEPENDENT central bank (so the Taylor rule is a genuine
// national rule, not an imported area-wide one), and centralised multi-year
// wage bargaining (so wages are the stickiest of the four).
// =========================================================================

// ----- PREFERENCES & TECHNOLOGY -----
beta     = 0.99;    // quarterly discount factor -> ~4% annual real rate
sigma    = 2.0;     // IES = 1/sigma = 0.5 (same as the other three)
alpha_n  = 0.67;    // labor share; set to 1 - alpha_k so the production block is CRS
                    // (see alpha_k below, which matches the Ramsey alpha_K=0.33)

// ----- LABOR MARKET STRUCTURE -----
alpha_m  = 0.5;     // matching function elasticity (structural, same across countries)
eta      = 0.5;     // symmetric Nash bargaining (Hosios condition)
kappa    = 0.20;    // vacancy posting cost (Shimer 2005 range, same starting point)
delta    = 0.030;   // quarterly separation rate ~3.0%, between Germany (2.5%) and
                    // Poland (3.5%), well below Spain (4.0%). Sweden pairs moderate
                    // employment protection with active labour market policy and
                    // high job-to-job mobility, but has nothing like Spain's
                    // temporary-contract segment driving churn.

// ----- MONETARY POLICY (RIKSBANK) -----
phi_pi   = 1.5;     // Taylor principle (standard)
phi_y    = 0.125;   // output response (standard)
rho_r    = 0.85;    // interest rate smoothing - the Riksbank is a persistent,
                    // forecast-based inflation targeter (it held the repo rate at or
                    // below zero from 2015 to 2019).
                    // NOTE: unlike Spain, this is a GENUINE national policy rule.
                    // Sweden has its own currency and central bank, so the rule
                    // responds to Swedish output and inflation. The area-wide
                    // approximation that the German and Spanish files have to carry
                    // simply does not apply here - this is the better-specified of
                    // the two situations, not a special case.

// ----- SHOCK PERSISTENCE -----
rho_a    = 0.95;    // technology persistence (standard)
// Labor force persistence: CONDITIONAL on SimPaths export switch
@#if for_simpaths_export
    rho_L    = 0;       // SimPaths mode: L = eps_L directly (no accumulation)
                        // SimPaths sends LEVELS, not innovations
@#else
    rho_L    = 0.95;    // Estimation mode: AR(1) captures observed persistence
                        // (Perplexity fix: rho_L and SE_eps_L were perfectly collinear)
@#endif
rho_v    = 0.9;     // vacancy persistence (as Germany; advanced-economy hiring)
rho_sep  = 0.8;     // separation shock persistence
rho_d    = 0.8;     // preference/demand shock persistence

// ----- HABIT PERSISTENCE (V14) -----
hab      = 0.5;     // external habit formation (standard advanced-economy range)

// ----- NEW KEYNESIAN PARAMETERS -----
lambda_p = 0.02;    // Phillips curve slope (as Germany and Spain)
phi_mc   = 1.0;     // output gap effect on marginal cost (same structural mechanism)
phi_v_y  = 5.0;     // vacancy response to demand conditions (same mechanism)

// ----- INFLATION INDEXATION (V15: Smets-Wouters style) -----
// The LOWEST of the four. Sweden has run a credible inflation target since 1993,
// inflation expectations are tightly anchored at 2%, and there is no formal
// price or wage indexation of the kind that keeps Poland's iota_p at 0.45.
iota_p   = 0.30;    // partial indexation (below Germany/Spain 0.35, Poland 0.45)

// ----- WAGE RIGIDITY (Gertler-Trigari 2009) -----
// The HIGHEST of the four, and for a concrete institutional reason: Swedish wage
// setting runs through centrally coordinated agreements (the "Industriavtalet"
// benchmark), collective bargaining coverage is ~88%, and the agreements
// typically run TWO TO THREE YEARS. That is a longer contract length than the
// German sectoral round, so if anything 0.75 is conservative.
// lambda_w = 0.75 -> average wage duration = 4 quarters.
lambda_w = 0.75;

// ----- INTENSIVE MARGIN (HOURS) PARAMETERS -----
// Sweden sits with Germany rather than Spain here: hours are a real adjustment
// margin. Sweden legislated a short-time work scheme (korttidsarbete) that was
// used heavily in 2020, and working-time accounts are common in the industrial
// agreements.
// Hours persistence: CONDITIONAL on SimPaths export switch
@#if for_simpaths_export
    rho_h    = 0;       // SimPaths mode: h = eps_h directly (no accumulation)
                        // SimPaths sends LEVELS, not innovations
@#else
    rho_h    = 0.85;    // Estimation mode: AR(1) captures observed persistence
                        // (calibrated in country_params/Sweden_calibration.mod)
@#endif
omega_h  = 0.324567;  // ESTIMATED (posterior mode)    // hours weight in production (same starting point; ESTIMATED)

// ----- DIRECT LABOR FORCE -> WAGE EFFECT (CALIBRATED) -----
psi_wL   = -0.05;   // direct L->w elasticity (negative: more L -> lower w)
                    // PROVISIONAL: carried over from Germany as the advanced-economy
                    // default, as for Spain. Centralised bargaining could plausibly
                    // mute the response, but nothing in this sample identifies it
                    // separately, so it is not invented here.

// ----- DEMAND COMPOSITION -----
// Investment share computed from this sample: mean(inv_level/y_level) = 0.2299
// over 2001q1-2025q1. The HIGHEST of the four (Germany 0.20, Poland 0.18,
// Spain 0.21), reflecting Sweden's large ICT, R&D and housing investment.
s_inv    = 0.23;    // investment share of GDP (Eurostat P51G / B1GQ, sample mean)

// ----- CAPITAL EXTENSION -----
alpha_k  = 0.33;    // capital share (matching Ramsey calibration alpha_K=0.33)
                    // Note: alpha_k + alpha_n = 0.33 + 0.67 = 1.0 (CRS)
delta_k  = 0.025;   // quarterly depreciation ~9.6% annual
                    // Deliberately differs from the Ramsey layer (5.5% annual,
                    // ~1.4% quarterly), which sets the long-run BGP K/Y. This
                    // delta_k governs the cyclical capital law of motion only.
rho_inv  = 0.85;    // investment persistence (same starting point)
phi_inv_y = 0.3;    // investment sensitivity to output gap (structural floor)
phi_inv_r = 0.140110;  // ESTIMATED (posterior mode)    // investment sensitivity to interest rate

// =========================================================================
// STEADY STATE LABOR MARKET (Sweden, 2001q1-2025q1 sample)
// =========================================================================
// Sources: Eurostat lfsi_emp_a (activity rate), this sample's u_level column
// Working-age population: 15-64
// =========================================================================

// The identity u = (chi_L/chi_u)L - (chi_n/chi_u)n (template eq. 10) requires
// chi_u = chi_L - chi_n, all three measured as shares of working-age population.
//
// Do NOT derive chi_u as chi_L - chi_n: those are two large, similar numbers, so
// the difference is violently leveraged. Calibrate the two well-measured
// quantities (participation and the unemployment rate) and derive chi_n from
// them, so any error propagates one-for-one rather than being amplified.
//
// The rate MUST be the estimation-sample mean, not a recent window. Sweden is
// the mildest of the four on this point - the sample range is only 4.78% to
// 9.32%, against Spain's 7.98-26.35% - but the rule still applies.

chi_L    = 0.81;    // labor force participation rate, L/WAP (81%)
                    // Eurostat lfsi_emp_a activity rate 15-64, 2001-2025 mean
                    // = 81.02% (range 78.4-84.0), rounded to 0.81.
                    // The highest participation rate of the four countries.

chi_u    = 0.0589;  // unemployment SHARE of WAP, U/WAP = chi_L * 0.072685
                    // NOT the U/L unemployment rate (that is 7.27%)
                    // Implied U/L = chi_u/chi_L = 7.27%, vs sample mean 7.27%

chi_n    = chi_L - chi_u;   // = 0.7511 -> TOTAL employment / WAP
                            // Note: the observable feeding n is employees excl.
                            // self-employed. Using the total employment share here
                            // assumes self-employment moves proportionally with
                            // employees, which keeps the identity's coefficient
                            // difference at exactly 1. Sweden has a LOW
                            // self-employment share (~10% of employment, against
                            // Poland's 20%), so this assumption does less work
                            // here than in any other country file.


// =========================================================================
// MODEL BLOCK (Linear)
// All equations are log-linearized around the deterministic steady state
// Variables are in % deviations: x_hat = (X - X_ss) / X_ss
// =========================================================================

model(linear);

    // -----------------------------------------------------------------------
    // SUPPLY SIDE: PRODUCTION FUNCTION WITH INTENSIVE MARGIN
    // -----------------------------------------------------------------------
    
    // 1. Output from production function with capital and labor (extensive + intensive)
    // Y = A * K^alpha_k * (N * H)^alpha_n
    // Log-linearized: y = x + alpha_k*k(-1) + alpha_n*(n + omega_h*h) + phi_mc*gap
    y = x + alpha_k * k(-1) + alpha_n * (n + omega_h * h) + phi_mc * gap;
    
    // -----------------------------------------------------------------------
    // INTENSIVE MARGIN: HOURS EQUATION (Option B: Pure AR(1))
    // -----------------------------------------------------------------------
    
    // 2. Hours per worker - EXOGENOUS LABOR SUPPLY FROM SIMPATHS
    h = rho_h * h(-1) + eps_h;
    
    // -----------------------------------------------------------------------
    // DEMAND SIDE: OPTION C (Smets-Wouters-style C/I decomposition)
    // -----------------------------------------------------------------------
    
    // 2a. Consumption Euler equation with EXTERNAL HABITS (V14)
    c - hab*c(-1) = (c(+1) - hab*c) - (1/sigma) * (R - pi(+1)) + d_shock;

    // 2b. Aggregate demand identity (GDP expenditure decomposition)
    d = (1 - s_inv) * c + s_inv * inv;
    
    // 3. Demand-supply gap
    gap = d - y;
    
    // -----------------------------------------------------------------------
    // SUPPLY SIDE: MARGINAL COST
    // -----------------------------------------------------------------------
    
    // 4. Marginal cost with demand-supply gap
    mc = (w - (x + alpha_k * k(-1) + (alpha_n - 1) * n + alpha_n * omega_h * h)) + phi_mc * gap;
    
    // -----------------------------------------------------------------------
    // PRICING
    // -----------------------------------------------------------------------
    
    // 5. New Keynesian Phillips Curve with INFLATION INDEXATION (V15)
    pi = (iota_p / (1 + iota_p * beta)) * pi(-1)
       + (beta / (1 + iota_p * beta)) * pi(+1)
       + (lambda_p / (1 + iota_p * beta)) * mc + eps_p;
    
    // 6. Monetary policy (Taylor rule)
    R = rho_r * R(-1) + (1 - rho_r) * (phi_pi * pi + phi_y * y) + eps_r;
    
    // -----------------------------------------------------------------------
    // LABOR MARKET: SEARCH AND MATCHING
    // -----------------------------------------------------------------------
    
    // 7. Matching function (Cobb-Douglas)
    m = alpha_m * u + (1 - alpha_m) * v;
    
    // 8. Labor market tightness
    theta = v - u;
    
    // 9. Employment law of motion
    n = (1 - delta) * n(-1) + delta * m - sep_shock;
    
    // 10. Unemployment identity
    // Exact linearisation of U = L - N: u_hat = (Lbar/Ubar)*L - (Nbar/Ubar)*n.
    // Requires chi_u = U/pop = chi_L - chi_n. Using the U/L rate instead
    // inflates chi_u and weakens the whole latent u channel proportionally.
    u = (chi_L / chi_u) * L - (chi_n / chi_u) * n;
    
    // 10b. Unemployment RATE gap (for observation)
    u_rate = (chi_n / chi_L) * (L - n);
    
    // 11. Vacancy posting rule (reduced-form with forward-looking profitability)
    v = rho_v * v(-1) + (1 - rho_v) * (((x + alpha_k * k(-1) + (alpha_n - 1) * n + alpha_n * omega_h * h) - w) + beta * lambda_w * ((x(+1) + alpha_k * k + (alpha_n - 1) * n(+1) + alpha_n * omega_h * h(+1)) - w(+1)) + phi_v_y * gap);
    
    // -----------------------------------------------------------------------
    // WAGE SETTING: Gertler-Trigari (2009) Staggered Wage Bargaining
    // -----------------------------------------------------------------------
    
    // 12a. Reset wage (forward-looking Nash bargaining)
    w_star = (1 - beta * lambda_w) * (eta * (x + alpha_k * k(-1) + (alpha_n - 1) * n + alpha_n * omega_h * h) + (1 - eta) * kappa * theta)
           + beta * lambda_w * w_star(+1);
    
    // 12b. Aggregate wage = Calvo mixture + direct labor force effect
    w = lambda_w * w(-1) + (1 - lambda_w) * w_star + psi_wL * L;
    
    // -----------------------------------------------------------------------
    // SHOCK PROCESSES
    // -----------------------------------------------------------------------
    
    // 13. Technology (AR(1))
    x = rho_a * x(-1) + eps_a;
    
    // 14. Labor force (AR(1)) - OBSERVED IN ESTIMATION, INPUT FROM SIMPATHS
    L = rho_L * L(-1) + eps_L;
    
    // 14b. Demand/preference shock AR(1) state
    d_shock = rho_d * d_shock(-1) + eps_d;
    
    // 15. Separation shock (AR(1))
    sep_shock = rho_sep * sep_shock(-1) + eps_sep;

    // -----------------------------------------------------------------------
    // CAPITAL EXTENSION (Phase 2: Explicit K with Investment Rule)
    // -----------------------------------------------------------------------

    // K1. Capital accumulation (law of motion)
    k = (1 - delta_k) * k(-1) + delta_k * inv;

    // K2. Investment rule (reduced-form)
    inv = rho_inv * inv(-1) + phi_inv_y * gap - phi_inv_r * R + eps_inv;

end;

// =========================================================================
// COUNTRY-SPECIFIC SHOCKS & ESTIMATION SETUP
// =========================================================================
// Loaded from country_params/{country}_estimation.mod
// Contains: calibrated shock stdevs, estimated_params (priors),
//           estimated_params_init, measurement errors, datafile macro
// =========================================================================
// SHOCKS, PRIORS & ESTIMATION SETUP - SWEDEN
// =========================================================================

// Data file for estimation (set as Dynare macro for template)

// =========================================================================
// CALIBRATED SHOCK STANDARD DEVIATIONS
// =========================================================================
// Initial calibration for Sweden, 2001q1-2025q1.
//
// Sweden is a small, very open economy with its own floating currency. That
// combination sets the starting values:
//   - cost-push starts HIGH, because a floating SEK passes import prices
//     through to domestic inflation (the 2022-23 SEK depreciation is in
//     sample). This is the Poland mechanism, not the Spain one.
//   - monetary starts MODERATE-HIGH: the Riksbank ran an active and at times
//     unconventional policy over this sample (negative repo rate 2015-2019,
//     then a rapid tightening from 2022).
//   - labour force starts MODERATE: Sweden took large and variable migration
//     inflows over the sample, which move the labour force.
//
// These are STARTING values; Bayesian estimation will update them.
shocks;
    var eps_a;      stderr 1.2346;  // ESTIMATED    // technology
    var eps_d;      stderr 0.3347;  // ESTIMATED    // demand
    var eps_r;      stderr 0.4795;  // ESTIMATED    // monetary: active, independent Riksbank
    var eps_L;      stderr 0.3004;  // ESTIMATED    // labor force: migration-driven swings
    var eps_sep;    stderr 0.10;    // separation: moderate turnover
    var eps_h;      stderr 0.4336;  // ESTIMATED    // hours: a real margin here (korttidsarbete)
    var eps_p;      stderr 1.4903;  // ESTIMATED    // cost-push: floating SEK pass-through
    var eps_inv;    stderr 2.8246;  // ESTIMATED    // investment: ICT/R&D-heavy, volatile
end;

// =========================================================================
// BAYESIAN ESTIMATION: PARAMETER PRIORS
// =========================================================================
// Same prior STRUCTURE as the other three countries. Every structural
// parameter stays fixed at its calibrated value: the identification problems
// are structural, not country-specific.
//
// PRIOR WIDTHS: these are deliberately WIDER than the Spanish file's were on
// first pass. Spain was estimated with tight priors (eps_L 0.15+/-0.08,
// eps_inv 0.80+/-0.35) and the posterior landed far outside them (0.55, 2.49)
// - the likelihood won, but the priors were plainly misspecified and had to be
// reported as such. Since there is no strong independent prior information
// about Swedish shock volatilities either, the priors here start diffuse so
// the data can speak without a fight.
//
// OUTCOME (2026-10): the posterior still lands well above the prior MEAN for
// eps_inv (2.9 vs 1.0), eps_a (1.25 vs 0.5) and eps_p (1.5 vs 0.8), as it does
// in every country. That is not a prior that binds: re-estimating with
// infinite-variance inverse-gamma priors on all seven shock stds moves no
// posterior mode by more than 1.2% (Spain 2.7%, Poland 3.1%). The priors were
// therefore left as they are. Do not re-centre them on the posterior
// (double-dipping); widen only if that check starts to move the modes.

estimated_params;
    // -----------------------------------------------------------------------
    // TIER 1: CRITICAL PARAMETERS
    // -----------------------------------------------------------------------
    // All Tier 1 parameters FIXED at calibrated values (identification issues
    // are structural, not data-specific):
    // kappa, eta, lambda_p, phi_mc, phi_v_y, lambda_w
    // -> see calibration file for values

    // -----------------------------------------------------------------------
    // TIER 2: IMPORTANT PARAMETERS (same issues)
    // -----------------------------------------------------------------------
    // sigma, phi_pi, phi_y, rho_r, rho_a, rho_v, rho_sep
    // -> all FIXED at calibrated values

    // -----------------------------------------------------------------------
    // ESTIMATED PARAMETERS
    // -----------------------------------------------------------------------

    // Hours weight in production
    omega_h,        beta_pdf,   0.35,   0.10;   // hours weight (0-1)

    // -----------------------------------------------------------------------
    // SHOCK STANDARD DEVIATIONS (diffuse; see note above)
    // -----------------------------------------------------------------------

    // Technology shock
    stderr eps_a,       inv_gamma_pdf,  0.50,   0.30;   // technology shock (%)

    // Demand/preference shock
    stderr eps_d,       inv_gamma_pdf,  0.50,   0.30;   // demand shock (%)

    // Monetary shock (Riksbank)
    stderr eps_r,       inv_gamma_pdf,  0.40,   0.25;   // monetary shock (%)

    // Cost-push shock (floating SEK pass-through)
    stderr eps_p,       inv_gamma_pdf,  0.80,   0.40;   // cost-push shock (%)

    // Hours shock
    stderr eps_h,       inv_gamma_pdf,  0.35,   0.20;   // hours shock (%)

    // Labor force shock (migration swings)
    stderr eps_L,       inv_gamma_pdf,  0.30,   0.20;   // labor force shock (%)

    // -----------------------------------------------------------------------
    // CAPITAL EXTENSION: INVESTMENT PARAMETERS
    // -----------------------------------------------------------------------

    // Cost-of-capital channel. Centred well below the 0.5 used for Spain and
    // Poland: Spain's posterior mean came in at 0.12, so 0.5 was a poor centre.
    phi_inv_r,      gamma_pdf,      0.30,   0.20;   // cost-of-capital (positive, unbounded)

    // Investment shock
    stderr eps_inv,     inv_gamma_pdf,  1.00,   0.50;   // investment shock (%)
end;

// =========================================================================
// INITIAL VALUES FOR ESTIMATION
// =========================================================================

estimated_params_init(use_calibration);
    omega_h,      0.35;     // hours weight in production

    // Shock std devs
    stderr eps_a,     0.50;     // technology
    stderr eps_d,     0.50;     // demand/preference
    stderr eps_r,     0.40;     // monetary (Riksbank)
    stderr eps_p,     0.80;     // cost-push
    stderr eps_L,     0.30;     // labor force
    stderr eps_h,     0.35;     // hours shock

    // Capital extension
    phi_inv_r,    0.10;     // cost-of-capital
    stderr eps_inv,   1.00;     // investment shock
end;

// =========================================================================
// MEASUREMENT ERRORS
// =========================================================================
// Swedish national accounts and LFS are of high quality, so these sit at the
// German end rather than the Polish end. Two exceptions:
//   - L, because the Swedish LFS carries a documented 2021 redesign break
//     that shows up as a level shift in the labour force series
//   - inv, because ICT and R&D capitalisation makes the investment series
//     genuinely noisy quarter to quarter

shocks;
    var y;      stderr 0.3;      // GDP
    var c;      stderr 0.3;      // Consumption
    var inv;    stderr 0.5;      // Investment: ICT/R&D capitalisation noise
    var pi;     stderr 0.2;      // Inflation: HICP
    var R;      stderr 0.2;      // Interest rate: Riksbank policy-linked
    var n;      stderr 0.3;      // Employment
    var L;      stderr 0.25;     // Labor force: 2021 LFS redesign break
    var h;      stderr 0.3;      // Hours per employee
end;


// =========================================================================
// OBSERVABLE VARIABLES
// =========================================================================
varobs y inv c pi R n L h;
// y      = Output gap (detrended log GDP, % deviation)
// inv    = Investment gap (detrended log investment, % deviation)
// c      = Consumption gap (detrended log private consumption, % deviation)
// pi     = Inflation rate (QoQ annualized, %)
// R      = Nominal interest rate (3m interbank rate, %)
// n      = Employment gap (detrended log employment, % deviation)
// L      = Labor force gap (detrended log labor force, % deviation)
// h      = Hours per employee gap (detrended, % deviation)
//
// 8 observables, 8 shocks → just-identified

// =========================================================================
// PRE-ESTIMATION CHECKS
// =========================================================================
steady;
check;

// =========================================================================
// STOCHASTIC SIMULATION (IRFs at calibrated values)
// =========================================================================
stoch_simul(order=1, irf=40, nograph) y d c gap pi R n h u u_rate v w theta x L k inv d_shock;

// Custom IRF plotting
@#if use_custom_irfs
    if exist('plot_custom_irfs', 'file')
        plot_custom_irfs(5, 4);
    else
        disp('Note: plot_custom_irfs.m not found. Using Dynare default IRF plots.');
    end
@#else
    disp('Custom IRF plotting disabled (use_custom_irfs = false).');
@#endif

// =========================================================================
// BAYESIAN ESTIMATION (conditional on do_parameter_estimation switch)
// =========================================================================

@#if do_parameter_estimation

    identification(advanced=1, max_dim_cova_group=3);

    @#if use_real_data
        estimation(
            datafile='@{datafile}',
            first_obs=1,
            prefilter=1,
            
            mode_compute=4,
            mode_check,
            
            diffuse_filter,
            fast_kalman_filter,
            lyapunov=doubling,
            
            mh_replic=20000,
            mh_nblocks=2,
            mh_drop=0.5,
            
            bayesian_irf,
            smoother,
            moments_varendo
        ) y d c gap pi R n h u u_rate v w theta x L k inv d_shock;
        
    @#else
        estimation(
            datafile=data_synthetic,
            first_obs=1,
            prefilter=1,
        
            mode_compute=6,
            mode_check,
            
            diffuse_filter,
            fast_kalman_filter,
            lyapunov=doubling,
            
            mh_replic=20000,
            mh_nblocks=2,
            mh_drop=0.5,
            
            bayesian_irf,
            smoother,
            moments_varendo
        ) y d c gap pi R n h u u_rate v w theta x L k inv d_shock;
        
    @#endif

@#endif

// =========================================================================
// POST-ESTIMATION CHECKS
// =========================================================================
steady;
check;
model_diagnostics;

