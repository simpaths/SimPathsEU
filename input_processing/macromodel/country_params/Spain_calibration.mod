// =========================================================================
// PARAMETER CALIBRATION (Quarterly Frequency) - SPAIN
// =========================================================================
// Data sources:
//   - Labor market: INE (Spanish Statistical Office) via Eurostat LFS, OECD LFS
//   - National accounts: INE via Eurostat (namq_10_gdp, namq_10_pe)
//   - Monetary policy: ECB (Spain is a euro founder member)
//
// NOTE: Spanish sample is 2000q1-2025q1 (101 obs), matching Germany's start
// rather than Spain's 1999 euro entry so that the OECD LFS stocks have a year
// of burn-in. Ramsey calibration: alpha_K=0.33, delta=0.05 annual,
// g_A=0.4% annual (derived from this sample; see Spain_growth_params.json).
//
// The dominant Spanish feature this calibration has to carry is the DUAL
// LABOUR MARKET: a very high share of temporary contracts drives both a high
// separation rate and a mean unemployment rate roughly double Germany's.
// =========================================================================

// ----- PREFERENCES & TECHNOLOGY -----
beta     = 0.99;    // quarterly discount factor -> ~4% annual real rate
sigma    = 2.0;     // IES = 1/sigma = 0.5 (same as Germany and Poland baseline)
alpha_n  = 0.67;    // labor share; set to 1 - alpha_k so the production block is CRS
                    // (see alpha_k below, which matches the Ramsey alpha_K=0.33)

// ----- LABOR MARKET STRUCTURE -----
alpha_m  = 0.5;     // matching function elasticity (structural, same across countries)
eta      = 0.5;     // symmetric Nash bargaining (Hosios condition)
kappa    = 0.20;    // vacancy posting cost (Shimer 2005 range, same starting point)
delta    = 0.040;   // quarterly separation rate ~4.0% - the HIGHEST of the three
                    // implemented countries (Germany 2.5%, Poland 3.5%).
                    // Spain runs a temporary-contract share around 25% (long the
                    // highest in the EU), and those contracts churn at a far higher
                    // rate than permanent ones. OECD EPL for temporary contracts is
                    // correspondingly low.

// ----- MONETARY POLICY (ECB) -----
phi_pi   = 1.5;     // Taylor principle (standard)
phi_y    = 0.125;   // output response (standard)
rho_r    = 0.85;    // interest rate smoothing - ECB, so same as Germany, not Poland
                    // NOTE: Spain is one member of the currency union, so the policy
                    // rule is the AREA-WIDE rule and does not respond to Spanish
                    // output. This approximation is shared with the German model but
                    // it does more work here, because Spanish and euro-area cycles
                    // diverged sharply in 2008-2013.

// ----- SHOCK PERSISTENCE -----
rho_a    = 0.95;    // technology persistence (standard)
rho_L    = 0.95;    // labor force persistence (calibrated, same identification logic)
rho_v    = 0.9;     // vacancy persistence (as Germany; euro-area hiring adjustment)
rho_sep  = 0.8;     // separation shock persistence
rho_d    = 0.8;     // preference/demand shock persistence

// ----- HABIT PERSISTENCE (V14) -----
hab      = 0.5;     // external habit formation (standard Euro area range)

// ----- NEW KEYNESIAN PARAMETERS -----
lambda_p = 0.02;    // Phillips curve slope (euro-area value, as Germany)
phi_mc   = 1.0;     // output gap effect on marginal cost (same structural mechanism)
phi_v_y  = 5.0;     // vacancy response to demand conditions (same mechanism)

// ----- INFLATION INDEXATION (V15: Smets-Wouters style) -----
iota_p   = 0.35;    // partial indexation (SW2003 euro-area range, as Germany)

// ----- WAGE RIGIDITY (Gertler-Trigari 2009) -----
// Spain sits BETWEEN Germany and Poland. Collective bargaining coverage is high
// (~80%, via automatic extension of sectoral agreements), which argues for German-
// style stickiness; but the 2012 labour reform gave firm-level agreements primacy
// and shortened effective durations, and the large temporary segment renegotiates
// at each contract. lambda_w = 0.70 -> average wage duration ~3.3 quarters.
lambda_w = 0.70;

// ----- INTENSIVE MARGIN (HOURS) PARAMETERS -----
// Spain is the mirror image of Germany here: it adjusts on the EXTENSIVE margin.
// Spain has no Kurzarbeit equivalent of comparable reach, and the 2008-2013 bust
// was absorbed almost entirely through job destruction rather than hours cuts.
// So the hours channel is weaker and less persistent than in Germany.
rho_h    = 0.80;    // hours persistence (as Poland, below Germany's 0.85)
omega_h  = 0.35;    // hours weight in production (same starting point; ESTIMATED)

// ----- DIRECT LABOR FORCE -> WAGE EFFECT (CALIBRATED) -----
psi_wL   = -0.05;   // direct L->w elasticity (negative: more L -> lower w)
                    // PROVISIONAL: carried over from Germany as the euro-area
                    // default. Spain's high-unemployment equilibrium could plausibly
                    // support a stronger (more negative) response, but nothing in
                    // this sample identifies it separately, so it is not invented here.

// ----- DEMAND COMPOSITION -----
// Investment share computed from this sample: mean(inv_level/y_level) = 0.2109
// over 2000q1-2025q1. Higher than Germany (0.20) and Poland (0.18), reflecting
// the construction boom that dominates the first third of the sample.
s_inv    = 0.21;    // investment share of GDP (Eurostat P51G / B1GQ, sample mean)

// ----- CAPITAL EXTENSION -----
alpha_k  = 0.33;    // capital share (matching Ramsey calibration alpha_K=0.33)
                    // Note: alpha_k + alpha_n = 0.33 + 0.67 = 1.0 (CRS)
delta_k  = 0.025;   // quarterly depreciation ~9.6% annual
                    // Deliberately differs from the Ramsey layer (5% annual,
                    // ~1.3% quarterly), which sets the long-run BGP K/Y. This
                    // delta_k governs the cyclical capital law of motion only.
rho_inv  = 0.85;    // investment persistence (same starting point)
phi_inv_y = 0.3;    // investment sensitivity to output gap (structural floor)
phi_inv_r = 0.1;    // investment sensitivity to interest rate

// =========================================================================
// STEADY STATE LABOR MARKET (Spain, 2000q1-2025q1 sample)
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
// The rate MUST be the estimation-sample mean, not a recent window. This matters
// MORE for Spain than for any other country in this repo: the sample mean is
// 15.37% but the range is 7.98% (2007q2) to 26.35% (2013q1). A recent window
// would give ~12% and the boom alone ~9%, either of which linearises the model
// around a point the sample as a whole never occupies.

chi_L    = 0.74;    // labor force participation rate, L/WAP (74%)
                    // Eurostat lfsi_emp_a activity rate 15-64, 2000-2025 mean
                    // = 73.89% (range 72.2-74.6), rounded to 0.74

chi_u    = 0.1137;  // unemployment SHARE of WAP, U/WAP = chi_L * 0.15369
                    // NOT the U/L unemployment rate (that is 15.37%)
                    // Implied U/L = chi_u/chi_L = 15.36%, vs sample mean 15.37%

chi_n    = chi_L - chi_u;   // = 0.6263 -> TOTAL employment / WAP
                            // Note: the observable feeding n is employees excl.
                            // self-employed. Using the total employment share here
                            // assumes self-employment moves proportionally with
                            // employees, which keeps the identity's coefficient
                            // difference at exactly 1.
