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
rho_L    = 0.95;    // labor force persistence (calibrated, same identification logic as Germany)
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
rho_h    = 0.80;    // hours persistence (calibrated; shorter than Germany due to
                    // less institutional hours adjustment)
omega_h  = 0.35;    // hours weight in production (same starting point)

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
phi_inv_r = 0.1;    // investment sensitivity to interest rate

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
