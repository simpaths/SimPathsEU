// =========================================================================
// PARAMETER CALIBRATION (Quarterly Frequency) - GERMANY
// =========================================================================
// Data sources:
//   - Labor market: Destatis, IAB, Eurostat (2023-2024 averages)
//   - National accounts: Destatis VGR
//   - Monetary policy: ECB, Bundesbank
//
// To convert to ANNUAL frequency for microsim:
//   rho_annual = rho_quarterly^4
//   beta_annual = beta_quarterly^4
//   delta_annual = 1 - (1-delta_quarterly)^4
// =========================================================================

// ----- PREFERENCES & TECHNOLOGY -----
beta     = 0.99;    // quarterly discount factor → ~4% annual real rate
sigma    = 2.0;     // IES = 1/sigma = 0.5 (halves R→c sensitivity vs sigma=1)
                    // Motivation: sigma=1 (log utility) gave 49% monetary share
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
                    // (Perplexity fix: rho_L and SE_eps_L were perfectly collinear)
rho_v    = 0.9;     // vacancy persistence (Germany: slow hiring adjustment)
rho_sep  = 0.8;     // separation shock persistence
rho_d    = 0.8;     // preference/demand shock persistence (confidence cycles)

// ----- HABIT PERSISTENCE (V14) -----
hab      = 0.5;     // external habit formation (Smets-Wouters: 0.5-0.7 for Euro area)

// ----- NEW KEYNESIAN PARAMETERS -----
lambda_p = 0.02;    // Phillips curve slope (Pytlarczyk 2005, Hristov 2016 for Germany)
phi_mc   = 1.0;     // output gap effect on marginal cost (increased for demand→inflation)
phi_v_y  = 5.0;     // vacancy response to demand conditions (ITERATION 9: high to amplify demand→n channel)

// ----- INFLATION INDEXATION (V15: Smets-Wouters style) -----
// Firms that cannot re-optimize prices index to lagged inflation.
// iota_p = 0: purely forward-looking NKPC (V14 baseline)
// iota_p = 1: full indexation (Christiano et al. 2005)
// Smets-Wouters (2003) Euro area posterior: ~0.2-0.5
// Effect: reduces impact of cost-push shocks by factor 1/(1+iota_p*beta),
// adds inflation persistence, dampens the R→c→gap→v amplification chain.
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
                    // (Perplexity fix: rho_h and SE_eps_h were perfectly collinear)
                    // Kurzarbeit contracts average ~6 months (quarterly ρ ≈ 0.85)
omega_h  = 0.35;    // hours weight in production: total labor = n + omega_h * h
                    // < 1.0 because headcount matters more than marginal hours
                    // Matches production function literature (Chetty et al. 2012)
// NOTE (Option B): psi_hy and psi_hw REMOVED - h is now pure AR(1)
// Rationale: h comes from SimPaths (household discrete choice), not from
// macro demand conditions. The gap→h channel was a business cycle mechanism
// inappropriate for annual policy analysis.

// ----- DIRECT LABOR FORCE → WAGE EFFECT (CALIBRATED) -----
// Rationale: Reduced-form "wage drift" capturing competitive pressure from
// labor supply on effective wages. This bypasses the slow Gertler-Trigari
// θ→w channel which produces near-zero response with realistic parameters.
// Economic interpretation: When labor force expands, workers accept lower
// wages due to increased competition, independent of formal bargaining.
// Calibration target: Long-run wage elasticity to labor supply ~ -0.2 to -0.4
// (Borjas 2003, Dustmann et al. 2017 for Germany)
// NOTE (Option B): L is now OBSERVED, so this effect could potentially be
// estimated. However, we keep it calibrated for stability.
psi_wL   = -0.05;     // direct L→w elasticity (negative: ↑L → ↓w)

// ----- DEMAND COMPOSITION (Option C: Smets-Wouters-style) -----
// GDP expenditure decomposition: Y = C + I + G + NX
// In log-deviations: d = (1-s_inv)*c + s_inv*inv
// Government + net exports (~30% of GDP) lumped with consumption behavior.
// Sources: Destatis VGR 2023-2024 expenditure shares
s_inv    = 0.20;    // investment share of GDP (Destatis VGR: ~20% for Germany)
                    // Residual (1-s_inv)=0.80 captures C + G + NX

// ----- CAPITAL EXTENSION (Phase 2: Approach B) -----
// Capital stock with reduced-form investment rule.
// Captures capital deepening: as L declines, K/L rises, boosting MPL and wages.
// Sources: Destatis VGR, Smets & Wouters (2003), Merz (1995), Andolfatto (1996)
alpha_k  = 0.35;    // capital share (Destatis VGR: ~35% for Germany)
                    // Note: alpha_k + alpha_n = 0.35 + 0.65 = 1.0 (CRS)
delta_k  = 0.025;   // quarterly depreciation ≈ 10% annual (standard)
rho_inv  = 0.85;    // investment persistence - CALIBRATED at v11b posterior mode (0.848)
                    // Perplexity Chat 087: cosn(rho_inv, phi_inv_r) = 0.9973 → fix to resolve
                    // Option C hit unit root (0.9888) → singular Hessian
phi_inv_y = 0.3;    // V15: Restored to small positive value as structural floor.
                    // Estimation rejected accelerator (posterior 0.085 vs prior 1.5),
                    // but setting exactly 0 produces absurd conditional responses:
                    // negative demand shock → R↓ → inv↑ (investment rises in recessions).
                    // 0.3 ensures weak demand co-movement without dominating unconditional VD.
                    // cosn(rho_inv, phi_inv_y) = 0.9989 → keep calibrated, do NOT estimate.
phi_inv_r = 0.1;    // investment sensitivity to interest rate (cost of capital)
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
