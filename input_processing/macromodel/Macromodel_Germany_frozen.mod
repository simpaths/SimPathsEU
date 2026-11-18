// =========================================================================
// FROZEN MODEL - AUTO-GENERATED
// Generated: 2026-11-09 14:11:54
// Source: Macromodel_Germany (estimation results)
// DO NOT EDIT MANUALLY - regenerate with generate_frozen_model.m
// =========================================================================

// =========================================================================
// DSGE Model - GERMANY
// =========================================================================
// Thin wrapper: defines country and includes shared template.
// All structural equations are in Macromodel_template.mod.
// Country-specific parameters are in country_params/Germany_*.mod.
//
// Usage:  >> dynare Macromodel_Germany use_dll
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

//
// PURPOSE:
// This model is the business-cycle layer of the macro model that serves as
// "economic guardrails" for the SimPaths dynamic microsimulation: it gives
// the cyclical deviation of the real wage around the Ramsey trend.
//
// INTERFACE WITH SIMPATHS (one-way):
//   scenario shocks (sigma-units) --> DSGE --> w (cycle wage) --> SimPaths
//   pi is computed and recorded but reaches no agent. The DSGE takes no
//   input from SimPaths: L and h are exogenous AR(1) processes, observed
//   in estimation.
//
// FREQUENCY: Quarterly; SimPaths averages four quarterly steps per year
// =========================================================================

// Variable declarations
// Endogenous variables (all in log-deviations from steady state)
var 
    y       // output (production function)    [SUPPLY-DETERMINED]
    d       // aggregate demand (Euler equation) [DEMAND-DETERMINED]
    c       // consumption (Euler equation)          [OBSERVED]
    gap     // demand-supply gap (d - y)
    R       // nominal interest rate
    pi      // inflation                        [recorded only]
    w       // real wage (aggregate)            [OUTPUT TO SIMPATHS]
    w_star  // reset wage (newly negotiated)    [Gertler-Trigari]
    u       // unemployment level (log-deviation, for internal dynamics)
    u_rate  // unemployment RATE gap (pp, for observation)
    v       // vacancies
    n       // employment
    h       // hours per worker (intensive margin) [exogenous AR(1)]
    m       // matches
    mc      // marginal cost
    x       // technology (TFP)
    theta   // labor market tightness (v/u)
    L       // labor force (participation)     [exogenous AR(1)]
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
    eps_L       // labor force shock
    eps_sep     // separation rate shock
    eps_h       // hours shock (e.g. short-time work)
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
    // CAPITAL PARAMETERS
    alpha_k     // capital share in production (Cobb-Douglas)
    delta_k     // quarterly capital depreciation rate
    rho_inv     // investment persistence
    phi_inv_y   // investment sensitivity to output gap
    phi_inv_r   // investment sensitivity to interest rate
    // HABIT PERSISTENCE
    hab         // external habit formation parameter (0 = no habits, 1 = full)
    // INFLATION INDEXATION
    iota_p;     // backward-looking inflation indexation (0 = no indexation, 1 = full)

// =========================================================================
// COUNTRY-SPECIFIC PARAMETER CALIBRATION
// =========================================================================
// Loaded from country_params/{country}_calibration.mod
// Contains: all parameter values, steady-state labor market ratios
// =========================================================================
// PARAMETER CALIBRATION (Quarterly Frequency) - GERMANY
// =========================================================================
// Data sources:
//   - Labor market: Destatis, IAB, Eurostat (2023-2024 averages)
//   - National accounts: Destatis VGR
//   - Monetary policy: ECB, Bundesbank
//
// The model is quarterly; SimPaths steps it four quarters per simulated year,
// so no parameter is converted to annual frequency.
// =========================================================================

// ----- PREFERENCES & TECHNOLOGY -----
beta     = 0.99;    // quarterly discount factor → ~4% annual real rate
sigma    = 2.0;     // IES = 1/sigma = 0.5 (halves R→c sensitivity vs sigma=1)
                    // Motivation: sigma=1 (log utility) gives a 49% monetary share
                    // because 1/sigma=1.0 makes R→c channel too potent.
                    // Estimates for Germany: Pytlarczyk (2005) ~1.4, Smets-Wouters
                    // (2003, Euro area) ~1.6, Christiano et al. (2005) ~1.4-2.0.
                    // sigma=2 is conservative; reduces IES to 0.5, standard range.
                    // Effect: halves monetary shock impact on consumption.
alpha_n  = 0.65;    // labor share in Germany (Destatis VGR: ~60-65%)

// ----- LABOR MARKET STRUCTURE -----
alpha_m  = 0.5;     // matching function elasticity (Petrongolo & Pissarides 2001)
eta      = 0.5;     // symmetric Nash bargaining (Hosios condition)
kappa    = 0.20;    // vacancy posting cost (Shimer 2005 range: 0.20-0.50; estimation inconclusive)
delta    = 0.025;   // quarterly separation rate ~2.5% (Germany has LOW turnover)
                    // Note: US would be ~0.10; Germany much more stable

// ----- MONETARY POLICY (ECB) -----
phi_pi   = 1.5;     // Taylor principle (standard)
phi_y    = 0.125;   // output response (standard)
rho_r    = 0.85;    // interest rate smoothing (ECB is quite persistent)

// ----- SHOCK PERSISTENCE -----
rho_a    = 0.95;    // technology persistence (annual: 0.81)
rho_L    = 0.95;    // labor force persistence - CALIBRATED to resolve collinearity
                    // (rho_L and SE_eps_L are collinear when both are estimated)
rho_v    = 0.9;     // vacancy persistence (Germany: slow hiring adjustment)
rho_sep  = 0.8;     // separation shock persistence
rho_d    = 0.8;     // preference/demand shock persistence (confidence cycles)

// ----- HABIT PERSISTENCE -----
hab      = 0.5;     // external habit formation (Smets-Wouters: 0.5-0.7 for Euro area)

// ----- NEW KEYNESIAN PARAMETERS -----
lambda_p = 0.02;    // Phillips curve slope (Pytlarczyk 2005, Hristov 2016 for Germany)
phi_mc   = 1.0;     // output gap effect on marginal cost (increased for demand→inflation)
phi_v_y  = 5.0;     // vacancy response to demand conditions (high, to amplify the demand→n channel)

// ----- INFLATION INDEXATION (Smets-Wouters style) -----
// Firms that cannot re-optimize prices index to lagged inflation.
// iota_p = 0: purely forward-looking NKPC
// iota_p = 1: full indexation (Christiano et al. 2005)
// Smets-Wouters (2003) Euro area posterior: ~0.2-0.5
// Effect: scales the marginal-cost term by 1/(1+iota_p*beta) (eps_p enters
// unscaled), adds inflation persistence, dampens the R→c→gap→v amplification chain.
iota_p   = 0.35;    // partial indexation (SW2003 range for Euro area)

// ----- WAGE RIGIDITY (Gertler-Trigari 2009) -----
// Calvo-style staggered wage bargaining: each period, fraction (1-lambda_w)
// of worker-firm pairs renegotiate wages. German collective agreements
// typically last 1-2 years.
// lambda_w = 0.75 → average wage duration = 1/(1-0.75) = 4 quarters (1 year)
// lambda_w = 0.85 → average duration ≈ 6.7 quarters (~1.7 years)
lambda_w = 0.75;    // baseline: 1-year average wage duration

// ----- INTENSIVE MARGIN (HOURS) PARAMETERS -----
// Germany adjusts 70-90% of labor input via hours (not employment) in recessions
// Sources: IAB, Möller (2010), Burda & Hunt (2011)
rho_h    = 0.85;    // hours persistence - CALIBRATED to resolve collinearity
                    // (rho_h and SE_eps_h are collinear when both are estimated)
                    // Kurzarbeit contracts average ~6 months (quarterly ρ ≈ 0.85)
omega_h  = 0.418474;  // ESTIMATED (posterior mode)    // hours weight in production: total labor = n + omega_h * h
                    // < 1.0 because headcount matters more than marginal hours
                    // Matches production function literature (Chetty et al. 2012)
// h is a pure AR(1): no output-gap or wage term moves hours. The DSGE has no
// hours choice; on the micro side SimPaths' household choice sets hours.

// ----- DIRECT LABOR FORCE → WAGE EFFECT (CALIBRATED) -----
// Rationale: Reduced-form "wage drift" capturing competitive pressure from
// labor supply on effective wages. This bypasses the slow Gertler-Trigari
// θ→w channel which produces near-zero response with realistic parameters.
// Economic interpretation: When labor force expands, workers accept lower
// wages due to increased competition, independent of formal bargaining.
// Calibration target: Long-run wage elasticity to labor supply ~ -0.2 to -0.4
// (Borjas 2003, Dustmann et al. 2017 for Germany)
// L is observed, so psi_wL could be estimated; it is calibrated for stability.
psi_wL   = -0.05;     // direct L→w elasticity (negative: ↑L → ↓w)

// ----- DEMAND COMPOSITION (Smets-Wouters-style) -----
// GDP expenditure decomposition: Y = C + I + G + NX
// In log-deviations: d = (1-s_inv)*c + s_inv*inv
// Government + net exports (~30% of GDP) lumped with consumption behavior.
// Sources: Destatis VGR 2023-2024 expenditure shares
s_inv    = 0.20;    // investment share of GDP (Destatis VGR: ~20% for Germany)
                    // Residual (1-s_inv)=0.80 captures C + G + NX

// ----- CAPITAL -----
// Capital stock with reduced-form investment rule.
// Captures capital deepening: as L declines, K/L rises, boosting MPL and wages.
// Sources: Destatis VGR, Smets & Wouters (2003), Merz (1995), Andolfatto (1996)
alpha_k  = 0.35;    // capital share (Destatis VGR: ~35% for Germany)
                    // Note: alpha_k + alpha_n = 0.35 + 0.65 = 1.0 (CRS)
delta_k  = 0.025;   // quarterly depreciation ≈ 10% annual (standard)
rho_inv  = 0.85;    // investment persistence - CALIBRATED near its estimated mode (0.848)
                    // Estimated with phi_inv_r it is collinear (cosn 0.9973) and runs to
                    // a unit root (0.9888) with a singular Hessian.
phi_inv_y = 0.3;    // small positive value as a structural floor.
                    // Estimated, the accelerator is rejected (posterior 0.085 vs prior 1.5),
                    // but setting exactly 0 produces absurd conditional responses:
                    // negative demand shock → R↓ → inv↑ (investment rises in recessions).
                    // 0.3 ensures weak demand co-movement without dominating unconditional VD.
                    // cosn(rho_inv, phi_inv_y) = 0.9989 → keep calibrated, do NOT estimate.
phi_inv_r = 0.296918;  // ESTIMATED (posterior mode)    // investment sensitivity to interest rate (cost of capital)
                    // Grid search: determinacy boundary at ~0.5 for phi_inv_y=2.0

// =========================================================================
// STEADY STATE LABOR MARKET (Germany, 2023-2024)
// =========================================================================
// Sources: Destatis, Eurostat LFS, IAB
// Working-age population: 15-64 (or 15-74 depending on definition)
// =========================================================================

// The identity u = (chi_L/chi_u)L - (chi_n/chi_u)n (template eq. 10) requires
// chi_u = chi_L - chi_n, all three as shares of working-age population.
//
// chi_u is calibrated directly rather than derived as chi_L - chi_n: those are two
// large, similar numbers, so their difference amplifies any rounding in chi_n by
// more than an order of magnitude. Deriving chi_n from chi_u instead keeps errors
// proportional. See Poland_calibration.mod for what that leverage cost there.
//
// The rate is the estimation-sample mean, not a recent window: Germany
// 2000q1-2026q1 averages 5.44% (range 2.63-10.32%).

chi_L    = 0.77;    // labor force participation rate, L/WAP (77%)
                    // Destatis: ~77-78% for 15-64 age group

chi_u    = 0.0419;  // unemployment SHARE of WAP, U/WAP = chi_L * 0.0544
                    // NOT the U/L unemployment rate (that is 5.44%)

chi_n    = chi_L - chi_u;   // = 0.7281 -> TOTAL employment / WAP
                            // The observable feeding n is total employment, the same concept as this share.


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
    // INTENSIVE MARGIN: HOURS EQUATION (pure AR(1))
    // -----------------------------------------------------------------------
    
    // 2. Hours per worker - exogenous AR(1), observed in estimation
    h = rho_h * h(-1) + eps_h;
    
    // -----------------------------------------------------------------------
    // DEMAND SIDE: Smets-Wouters-style C/I decomposition
    // -----------------------------------------------------------------------
    
    // 2a. Consumption Euler equation with EXTERNAL HABITS
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
    
    // 5. New Keynesian Phillips Curve with INFLATION INDEXATION
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
    
    // 14. Labor force (AR(1)) - observed in estimation
    L = rho_L * L(-1) + eps_L;
    
    // 14b. Demand/preference shock AR(1) state
    d_shock = rho_d * d_shock(-1) + eps_d;
    
    // 15. Separation shock (AR(1))
    sep_shock = rho_sep * sep_shock(-1) + eps_sep;

    // -----------------------------------------------------------------------
    // CAPITAL: explicit K with an investment rule
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
// SHOCKS, PRIORS & ESTIMATION SETUP - GERMANY
// =========================================================================

// Data file for estimation (set as Dynare macro for template)

// =========================================================================
// CALIBRATED SHOCK STANDARD DEVIATIONS
// =========================================================================
// Starting values. The estimation replaces the standard deviations it
// estimates (estimated_params below); eps_sep, which is not estimated, keeps
// the value set here.
//
shocks;
    var eps_a;      stderr 1.0995;  // ESTIMATED    // technology
    var eps_d;      stderr 0.3513;  // ESTIMATED    // demand: main driver for y-pi
    var eps_r;      stderr 0.4549;  // ESTIMATED    // monetary
    var eps_L;      stderr 0.1409;  // ESTIMATED    // labor force
    var eps_sep;    stderr 0.08;    // separation (not estimated)
    var eps_h;      stderr 0.3840;  // ESTIMATED    // hours shock (Kurzarbeit): calibrated to σ(h) ≈ 0.8%
                                    // German data: σ(h) = 0.81%, σ(h)/σ(n) = 1.22
    var eps_p;      stderr 1.4648;  // ESTIMATED    // cost-push / price markup shock
    var eps_inv;    stderr 1.8677;  // ESTIMATED    // investment shock [CAPITAL EXTENSION]
end;

// =========================================================================
// BAYESIAN ESTIMATION: PARAMETER PRIORS
// =========================================================================

estimated_params;
    // -----------------------------------------------------------------------
    // TIER 1: CRITICAL PARAMETERS (model-specific, hard to calibrate)
    // -----------------------------------------------------------------------
    
    // Vacancy posting cost (affects labor market tightness)
    // FIXED: poorly identified; estimated, the mode moves between 0.02 and 0.14
    // Calibrated at 0.20 (Shimer 2005 literature lower bound)
    // kappa,          gamma_pdf,  0.20,   0.05;  // COMMENTED OUT - not identified
    
    // Worker bargaining power (Hosios efficiency: eta = alpha_m ≈ 0.5)
    // FIXED: mode at 0.047 (near zero), clearly not identified
    // eta,            beta_pdf,   0.5,    0.1;  // COMMENTED OUT - fix at 0.5
    
    // Phillips curve slope (flatter in Europe than US)
    // FIXED: mode at 0.35 when estimated (7x prior), suggests model-data mismatch
    // lambda_p,       gamma_pdf,  0.05,   0.025;  // COMMENTED OUT - fix at 0.05
    
    // Marginal cost sensitivity to output gap
    // FIXED at calibrated value - phi_mc and lambda_p are NOT separately identified
    // Both affect Phillips curve slope, causing Hessian singularity
    // phi_mc,         gamma_pdf,  0.2,    0.05;  // COMMENTED OUT
    
    // Vacancy demand sensitivity
    // FIXED: estimated, it hits the boundary (0.07); poorly identified from data
    // phi_v_y,        gamma_pdf,  1.0,    0.5;  // COMMENTED OUT - fix at 1.0
    
    // Calvo wage stickiness (Gertler-Trigari 2009)
    // FIXED: estimated, it hits the upper boundary (0.9787), almost full stickiness
    // Fix at 0.75 = 4 quarter average duration (German collective agreements)
    // lambda_w,       beta_pdf,   0.75,   0.1;  // COMMENTED OUT - fix at 0.75
    
    // -----------------------------------------------------------------------
    // TIER 2: IMPORTANT PARAMETERS (standard but uncertain)
    // -----------------------------------------------------------------------
    
    // Inverse IES (risk aversion)
    // NOT IDENTIFIED: mode drifts to boundary (3.48 with prior 1.0; 6.97 with prior 2.0)
    // sigma,          gamma_pdf,  2.0,    0.5;   // COMMENTED OUT - fix at 2.0
    
    // Taylor rule: inflation response (Taylor principle > 1)
    // FIXED: estimated, the mode hits ~1.0, violating the Taylor principle
    // phi_pi,         gamma_pdf,  1.5,    0.15;  // COMMENTED OUT - fix at 1.5
    
    // Taylor rule: output response
    // FIXED: estimated, it hits the boundary; not well identified jointly with phi_pi
    // phi_y,          gamma_pdf,  0.125,  0.03;  // COMMENTED OUT - fix at 0.125
    
    // Interest rate smoothing (ECB is persistent)
    // FIXED: mode at 0.44 (way off), poorly identified
    // rho_r,          beta_pdf,   0.85,   0.05;  // COMMENTED OUT - fix at 0.85
    
    // Technology shock persistence
    // FIXED: estimated, it hits the upper boundary (0.9999), near a unit root
    // rho_a,          beta_pdf,   0.95,   0.03;  // COMMENTED OUT - fix at 0.95
    
    // Vacancy persistence (Germany: slow adjustment)
    // FIXED: estimated, it hits the upper boundary (0.999)
    // rho_v,          beta_pdf,   0.9,    0.05;  // COMMENTED OUT - fix at 0.9
    
    // Separation shock persistence
    // FIXED: estimated, it hits the upper boundary (0.983) and makes the Hessian singular
    // rho_sep,        beta_pdf,   0.8,    0.05;  // COMMENTED OUT - fix at 0.8
    
    // -----------------------------------------------------------------------
    // ESTIMATED PARAMETERS
    // -----------------------------------------------------------------------
    
    // Hours weight in production: contribution of intensive vs extensive margin
    omega_h,        beta_pdf,   0.35,   0.10;   // hours weight (0-1)
    
    // -----------------------------------------------------------------------
    // SHOCK STANDARD DEVIATIONS
    // -----------------------------------------------------------------------
    
    // Technology shock
    stderr eps_a,       inv_gamma_pdf,  0.50,   0.2;    // technology shock (%)
    
    // Demand/preference shock: drives positive y-pi comovement
    stderr eps_d,       inv_gamma_pdf,  0.50,   0.2;    // demand shock (%)
    
    // Monetary shock: small - only captures ECB policy errors
    stderr eps_r,       inv_gamma_pdf,  0.25,   0.1;    // monetary shock (%)
    
    // Cost-push / price markup shock
    stderr eps_p,       inv_gamma_pdf,  0.50,   0.2;    // cost-push shock (%)
    
    // Hours shock
    stderr eps_h,       inv_gamma_pdf,  0.35,   0.10;   // hours shock (%)
    
    // Labor force shock (L is observed)
    stderr eps_L,       inv_gamma_pdf,  0.12,   0.05;   // labor force shock (%)
    
    // -----------------------------------------------------------------------
    // CAPITAL EXTENSION: INVESTMENT PARAMETERS
    // -----------------------------------------------------------------------
    
    // Cost-of-capital channel
    phi_inv_r,      gamma_pdf,      0.5,    0.25;   // cost-of-capital (positive, unbounded)
    
    // Investment shock
    stderr eps_inv,     inv_gamma_pdf,  0.50,   0.2;    // investment shock (%)
end;

// =========================================================================
// INITIAL VALUES FOR ESTIMATION
// =========================================================================

estimated_params_init(use_calibration);
    omega_h,      0.35;     // hours weight in production
    
    // Shock std devs
    stderr eps_a,     0.50;     // technology
    stderr eps_d,     0.50;     // demand/preference
    stderr eps_r,     0.25;     // monetary
    stderr eps_p,     0.50;     // cost-push
    stderr eps_L,     0.12;     // labor force
    stderr eps_h,     0.35;     // hours shock (matches shocks block and prior mean)
    
    // Capital extension
    phi_inv_r,    0.10;     // cost-of-capital
    stderr eps_inv,   0.50;     // investment shock
end;

// =========================================================================
// MEASUREMENT ERRORS
// =========================================================================
// With 8 observables and 8 structural shocks (just-identified).
// Measurement errors kept small to not dominate signal.

shocks;
    var y;      stderr 0.3;      // GDP: ~1.5% std dev in data → 0.3% meas. error
    var c;      stderr 0.3;      // Consumption: ~1.0% std dev → 0.3% meas. error
    var inv;    stderr 0.5;      // Investment: ~5% std dev → 0.5% meas. error (volatile series)
    var pi;     stderr 0.2;      // Inflation: ~1% std dev → 0.2% meas. error
    var R;      stderr 0.2;      // Interest rate: ~1.5% std dev → 0.2% meas. error
    var n;      stderr 0.3;      // Employment: ~1.5% std dev → 0.3% meas. error
    var L;      stderr 0.15;     // Labor force: ~0.3% std dev → 0.15% meas. error
    var h;      stderr 0.3;      // Hours per person employed: ~1.0% std dev → 0.3% meas. error
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
// n      = Employment gap (detrended log employment, all persons in employment, % deviation)
// L      = Labor force gap (detrended log labor force, % deviation)
// h      = Hours per person employed gap (detrended, % deviation)
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

