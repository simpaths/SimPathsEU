// =========================================================================
// FROZEN MODEL - AUTO-GENERATED
// Generated: 2026-10-20 17:55:32
// Source: Macromodel_Poland (estimation results)
// DO NOT EDIT MANUALLY - regenerate with generate_frozen_model.m
// =========================================================================

// =========================================================================
// DSGE Model - POLAND
// =========================================================================
// Thin wrapper: defines country and includes shared template.
// All structural equations are in Macromodel_template.mod.
// Country-specific parameters are in country_params/Poland_*.mod.
//
// Usage:  >> dynare Macromodel_Poland use_dll
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
// RATIONALE: During estimation, rho_L=0.95 and rho_h=0.80 capture the observed
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
// PARAMETER CALIBRATION (Quarterly Frequency) - POLAND
// =========================================================================
// Data sources:
//   - Labor market: GUS (Statistics Poland), Eurostat LFS (2018-2023 avg)
//   - National accounts: GUS, Eurostat
//   - Monetary policy: NBP (National Bank of Poland)
//
// NOTE: Polish sample starts 2005Q1 (dropping early-2000s recession/EU
// accession volatility). Ramsey calibration: α_K=0.33, δ=0.065 annual,
// K/Y=2.7 (via K_override in Poland_growth_params.json; PIM alone gives 2.0,
// PWT 11.0 cross-validates at 2.21).
// =========================================================================

// ----- PREFERENCES & TECHNOLOGY -----
beta     = 0.99;    // quarterly discount factor → ~4% annual real rate
sigma    = 2.0;     // IES = 1/sigma = 0.5 (same as Germany baseline)
alpha_n  = 0.67;    // labor share in Poland (PWT 11.0 labsh avg ~0.59 → alpha_n≈0.67)
                    // Slightly higher than Germany (0.65) reflecting less capital-intensive economy

// ----- LABOR MARKET STRUCTURE -----
alpha_m  = 0.5;     // matching function elasticity (structural, same across countries)
eta      = 0.5;     // symmetric Nash bargaining (Hosios condition)
kappa    = 0.20;    // vacancy posting cost (Shimer 2005 range, same starting point)
delta    = 0.035;   // quarterly separation rate ~3.5% (Poland: higher turnover than Germany)
                    // Poland has more flexible labor market with more fixed-term contracts
                    // OECD EPL index: Poland ~2.1 vs Germany ~2.7 (stricter)

// ----- MONETARY POLICY (NBP) -----
phi_pi   = 1.5;     // Taylor principle (standard, NBP is conventional)
phi_y    = 0.125;   // output response (standard)
rho_r    = 0.80;    // interest rate smoothing (NBP slightly less persistent than ECB)

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
rho_v    = 0.85;    // vacancy persistence (Poland: somewhat faster hiring adjustment)
rho_sep  = 0.8;     // separation shock persistence
rho_d    = 0.8;     // preference/demand shock persistence

// ----- HABIT PERSISTENCE (V14) -----
hab      = 0.5;     // external habit formation (standard Euro area range)

// ----- NEW KEYNESIAN PARAMETERS -----
lambda_p = 0.03;    // Phillips curve slope (slightly steeper than Germany)
                    // Polish inflation more responsive to real marginal cost
                    // Consistent with less anchored expectations in transition economy
phi_mc   = 1.0;     // output gap effect on marginal cost (same structural mechanism)
phi_v_y  = 5.0;     // vacancy response to demand conditions (same mechanism)

// ----- INFLATION INDEXATION (V15: Smets-Wouters style) -----
// Poland has more backward-looking inflation behavior than the Euro area
// due to indexation clauses in contracts and administered prices.
iota_p   = 0.45;    // partial indexation (higher than Germany's 0.35)
                    // Reflects stronger inflation persistence in Polish data

// ----- WAGE RIGIDITY (Gertler-Trigari 2009) -----
// Polish labor market is more flexible than German:
// - Less collective bargaining coverage (~15% vs ~50% in Germany)
// - More fixed-term contracts (especially for younger workers)
// - Shorter average contract duration
// lambda_w = 0.65 → average wage duration ≈ 2.9 quarters (~9 months)
lambda_w = 0.65;    // baseline: shorter average wage duration than Germany

// ----- INTENSIVE MARGIN (HOURS) PARAMETERS -----
// Poland has less formalized short-time work (no equivalent to Germany's Kurzarbeit)
// Hours adjustment margin weaker than in Germany
// Hours persistence: CONDITIONAL on SimPaths export switch
@#if for_simpaths_export
    rho_h    = 0;       // SimPaths mode: h = eps_h directly (no accumulation)
                        // SimPaths sends LEVELS, not innovations
@#else
    rho_h    = 0.80;    // Estimation mode: AR(1) captures observed persistence
                        // (calibrated in country_params/Poland_calibration.mod)
@#endif
omega_h  = 0.319455;  // ESTIMATED (posterior mode)    // hours weight in production (same starting point)

// ----- DIRECT LABOR FORCE → WAGE EFFECT (CALIBRATED) -----
// Polish labor market shows stronger wage response to supply shifts
// (more elastic labor market, especially with EU migration flows)
psi_wL   = -0.08;     // direct L→w elasticity (somewhat stronger than Germany's -0.05)

// ----- DEMAND COMPOSITION -----
// Poland: investment share of GDP from GUS/Eurostat national accounts
// Polish investment share is lower than Germany (~18-20% vs ~20-22%)
s_inv    = 0.18;    // investment share of GDP (GUS: ~18% for Poland)

// ----- CAPITAL EXTENSION -----
alpha_k  = 0.33;    // capital share (matching Ramsey calibration α_K=0.33)
                    // Note: alpha_k + alpha_n = 0.33 + 0.67 = 1.0 (CRS)
delta_k  = 0.025;   // quarterly depreciation ≈ 9.6% annual
                    // Deliberately differs from the Ramsey layer (6.5% annual,
                    // ≈1.7% quarterly), which sets the long-run BGP K/Y. This
                    // delta_k governs the cyclical capital law of motion only.
rho_inv  = 0.85;    // investment persistence (same starting point)
phi_inv_y = 0.3;    // investment sensitivity to output gap (structural floor)
phi_inv_r = 0.135773;  // ESTIMATED (posterior mode)    // investment sensitivity to interest rate

// =========================================================================
// STEADY STATE LABOR MARKET (Poland, 2018-2023 averages)
// =========================================================================
// Sources: GUS (Statistics Poland), Eurostat LFS
// Working-age population: 15-64
// =========================================================================

// The identity u = (chi_L/chi_u)L - (chi_n/chi_u)n (template eq. 10) requires
// chi_u = chi_L - chi_n, all three measured as shares of working-age population.
//
// Do NOT derive chi_u as chi_L - chi_n: those are two large, similar numbers, so
// the difference is violently leveraged. Rounding chi_n from 0.6777 to 0.70 turns
// chi_u from 0.052 into 0.030 - a 43% error in the coefficient that scales the
// entire latent u -> theta -> bargaining chain, and worth ~140 log points of
// marginal likelihood. Calibrate the two well-measured quantities instead
// (participation and the unemployment rate) and derive chi_n from them, so any
// error propagates one-for-one rather than being amplified.
//
// The rate MUST be the estimation-sample mean, not a recent window: the model is
// linearised around the sample it is estimated on. Poland 2005q1-2025q3 averages
// 7.16% (range 2.73-18.29%); the 2018-2023 window alone would give 4.1%.

chi_L    = 0.73;    // labor force participation rate, L/WAP (73%)
                    // Eurostat: Poland ~72-74% for 15-64 age group

chi_u    = 0.0523;  // unemployment SHARE of WAP, U/WAP = chi_L * 0.0716
                    // NOT the U/L unemployment rate (that is 7.16%)

chi_n    = chi_L - chi_u;   // = 0.6777 -> TOTAL employment / WAP
                            // Note: the observable feeding n is employees excl.
                            // self-employed (0.5412 of WAP). Using the total
                            // employment share here assumes self-employment moves
                            // proportionally with employees, which keeps the
                            // identity's coefficient difference at exactly 1.


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
// SHOCKS, PRIORS & ESTIMATION SETUP - POLAND
// =========================================================================

// Data file for estimation (set as Dynare macro for template)

// =========================================================================
// CALIBRATED SHOCK STANDARD DEVIATIONS
// =========================================================================
// Initial calibration for Poland.
// Polish data (2005Q1-2025Q1) likely shows higher volatility than Germany
// due to EU accession effects, stronger catch-up growth, and more volatile
// exchange rate pass-through (PLN/EUR).
//
// These are STARTING values; Bayesian estimation will update them.
shocks;
    var eps_a;      stderr 1.0536;  // ESTIMATED    // technology: higher for catch-up economy
    var eps_d;      stderr 0.4391;  // ESTIMATED    // demand: higher volatility (trade/FDI cycles)
    var eps_r;      stderr 0.7505;  // ESTIMATED    // monetary: NBP rate changes more volatile than ECB
    var eps_L;      stderr 0.7495;  // ESTIMATED    // labor force: EU migration creates larger L shocks
    var eps_sep;    stderr 0.10;    // separation: more flexible labor market
    var eps_h;      stderr 0.3574;  // ESTIMATED    // hours shock (less institutional adjustment than Germany)
    var eps_p;      stderr 2.4068;  // ESTIMATED    // cost-push: higher due to energy import dependence + PLN
    var eps_inv;    stderr 3.4871;  // ESTIMATED    // investment: more volatile (EU funds, FDI cycles)
end;

// =========================================================================
// BAYESIAN ESTIMATION: PARAMETER PRIORS
// =========================================================================
// Starting from the same prior structure as Germany.
// Key differences:
//   - Wider priors on some parameters (less prior information for Poland)
//   - Same commented-out parameters (identification issues are structural,
//     not country-specific)

estimated_params;
    // -----------------------------------------------------------------------
    // TIER 1: CRITICAL PARAMETERS (same identification issues as Germany)
    // -----------------------------------------------------------------------
    
    // All Tier 1 parameters FIXED at calibrated values (identification issues
    // are structural, not data-specific):
    // kappa, eta, lambda_p, phi_mc, phi_v_y, lambda_w
    // → see calibration file for values
    
    // -----------------------------------------------------------------------
    // TIER 2: IMPORTANT PARAMETERS (same issues)
    // -----------------------------------------------------------------------
    
    // sigma, phi_pi, phi_y, rho_r, rho_a, rho_v, rho_sep
    // → all FIXED at calibrated values
    
    // -----------------------------------------------------------------------
    // ESTIMATED PARAMETERS
    // -----------------------------------------------------------------------
    
    // Hours weight in production
    omega_h,        beta_pdf,   0.35,   0.10;   // hours weight (0-1)
    
    // -----------------------------------------------------------------------
    // SHOCK STANDARD DEVIATIONS
    // -----------------------------------------------------------------------
    // Slightly wider priors for Poland (less prior information)
    
    // Technology shock
    stderr eps_a,       inv_gamma_pdf,  0.50,   0.25;   // technology shock (%)
    
    // Demand/preference shock
    stderr eps_d,       inv_gamma_pdf,  0.50,   0.25;   // demand shock (%)
    
    // Monetary shock (NBP)
    stderr eps_r,       inv_gamma_pdf,  0.40,   0.15;   // monetary shock (%) - wider than Germany
    
    // Cost-push shock (more important for Poland: energy, PLN pass-through)
    stderr eps_p,       inv_gamma_pdf,  0.70,   0.30;   // cost-push shock (%)
    
    // Hours shock
    stderr eps_h,       inv_gamma_pdf,  0.35,   0.10;   // hours shock (%)
    
    // Labor force shock (EU migration → larger shocks)
    stderr eps_L,       inv_gamma_pdf,  0.15,   0.06;   // labor force shock (%)
    
    // -----------------------------------------------------------------------
    // CAPITAL EXTENSION: INVESTMENT PARAMETERS
    // -----------------------------------------------------------------------
    
    // Cost-of-capital channel
    phi_inv_r,      gamma_pdf,      0.5,    0.25;   // cost-of-capital (positive, unbounded)
    
    // Investment shock
    stderr eps_inv,     inv_gamma_pdf,  0.60,   0.25;   // investment shock (%)
end;

// =========================================================================
// INITIAL VALUES FOR ESTIMATION
// =========================================================================

estimated_params_init(use_calibration);
    omega_h,      0.35;     // hours weight in production
    
    // Shock std devs
    stderr eps_a,     0.50;     // technology
    stderr eps_d,     0.50;     // demand/preference
    stderr eps_r,     0.40;     // monetary (NBP)
    stderr eps_p,     0.70;     // cost-push
    stderr eps_L,     0.15;     // labor force
    stderr eps_h,     0.30;     // hours shock
    
    // Capital extension
    phi_inv_r,    0.10;     // cost-of-capital
    stderr eps_inv,   0.60;     // investment shock
end;

// =========================================================================
// MEASUREMENT ERRORS
// =========================================================================
// Slightly larger measurement errors for Poland reflecting:
// - Shorter sample (2005Q1-2025Q1 = 81 obs)
// - Data revisions more common
// - Some series have reporting gaps

shocks;
    var y;      stderr 0.4;      // GDP: Polish data may have larger revisions
    var c;      stderr 0.4;      // Consumption
    var inv;    stderr 0.6;      // Investment: very volatile in Poland (EU funds)
    var pi;     stderr 0.3;      // Inflation: more volatile (PLN, energy pass-through)
    var R;      stderr 0.3;      // Interest rate: NBP more volatile than ECB
    var n;      stderr 0.3;      // Employment
    var L;      stderr 0.20;     // Labor force: migration creates measurement challenges
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

