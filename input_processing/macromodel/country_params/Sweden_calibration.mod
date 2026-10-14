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
rho_L    = 0.95;    // labor force persistence (calibrated, same identification logic)
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
rho_h    = 0.85;    // hours persistence (as Germany, above Poland/Spain's 0.80)
omega_h  = 0.35;    // hours weight in production (same starting point; ESTIMATED)

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
phi_inv_r = 0.1;    // investment sensitivity to interest rate

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
