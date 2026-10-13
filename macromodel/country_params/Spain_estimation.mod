// =========================================================================
// SHOCKS, PRIORS & ESTIMATION SETUP - SPAIN
// =========================================================================

// Data file for estimation (set as Dynare macro for template)
@#define datafile = "data/data_for_dynare_Spain.csv"

// =========================================================================
// CALIBRATED SHOCK STANDARD DEVIATIONS
// =========================================================================
// Initial calibration for Spain, 2000q1-2025q1.
//
// The defining feature of this sample is amplitude, not persistence: Spain ran
// a construction boom to 2007, a double-dip bust to 2013 that took unemployment
// from 8% to 26%, and then a recovery. So the real-side shocks (investment,
// demand, labour force) start WIDER than Germany's, while the nominal-side
// shocks (monetary, cost-push) start at German values, because Spain imports
// euro-area monetary policy and has no independent exchange-rate pass-through
// channel of the kind that drives Poland's cost-push volatility.
//
// These are STARTING values; Bayesian estimation will update them.
shocks;
    var eps_a;      stderr 0.40;    // technology
    var eps_d;      stderr 5.00;    // demand: large boom-bust swings
    var eps_r;      stderr 0.40;    // monetary: ECB, so as Germany (not Poland's 0.80)
    var eps_L;      stderr 0.08;    // labor force: huge migration swings both ways
                                    // (net inflows to 2008, net outflows 2011-2015)
    var eps_sep;    stderr 0.12;    // separation: dual labour market, high churn
    var eps_h;      stderr 0.25;    // hours: WEAKER than Germany - Spain adjusts on
                                    // the extensive margin, so less hours action
    var eps_p;      stderr 0.50;    // cost-push: euro member, no FX pass-through
    var eps_inv;    stderr 0.80;    // investment: the most volatile series in the
                                    // sample (construction collapse)
end;

// =========================================================================
// BAYESIAN ESTIMATION: PARAMETER PRIORS
// =========================================================================
// Same prior STRUCTURE as Germany and Poland. Every structural parameter stays
// fixed at its calibrated value: the identification problems are structural,
// not country-specific, so adding Spain does not make them tractable.

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
    // SHOCK STANDARD DEVIATIONS
    // -----------------------------------------------------------------------

    // Technology shock
    stderr eps_a,       inv_gamma_pdf,  0.50,   0.25;   // technology shock (%)

    // Demand/preference shock
    stderr eps_d,       inv_gamma_pdf,  0.50,   0.25;   // demand shock (%)

    // Monetary shock (ECB)
    stderr eps_r,       inv_gamma_pdf,  0.30,   0.15;   // monetary shock (%)

    // Cost-push shock
    stderr eps_p,       inv_gamma_pdf,  0.50,   0.25;   // cost-push shock (%)

    // Hours shock
    stderr eps_h,       inv_gamma_pdf,  0.30,   0.12;   // hours shock (%)

    // Labor force shock (migration swings in both directions)
    stderr eps_L,       inv_gamma_pdf,  0.15,   0.08;   // labor force shock (%)

    // -----------------------------------------------------------------------
    // CAPITAL EXTENSION: INVESTMENT PARAMETERS
    // -----------------------------------------------------------------------

    // Cost-of-capital channel
    phi_inv_r,      gamma_pdf,      0.5,    0.25;   // cost-of-capital (positive, unbounded)

    // Investment shock (widest prior of the three countries)
    stderr eps_inv,     inv_gamma_pdf,  0.80,   0.35;   // investment shock (%)
end;

// =========================================================================
// INITIAL VALUES FOR ESTIMATION
// =========================================================================

estimated_params_init(use_calibration);
    omega_h,      0.35;     // hours weight in production

    // Shock std devs
    stderr eps_a,     0.50;     // technology
    stderr eps_d,     0.50;     // demand/preference
    stderr eps_r,     0.30;     // monetary (ECB)
    stderr eps_p,     0.50;     // cost-push
    stderr eps_L,     0.15;     // labor force
    stderr eps_h,     0.25;     // hours shock

    // Capital extension
    phi_inv_r,    0.10;     // cost-of-capital
    stderr eps_inv,   0.80;     // investment shock
end;

// =========================================================================
// MEASUREMENT ERRORS
// =========================================================================
// Spanish national accounts are of euro-area quality, so these sit closer to
// Germany's than Poland's. The exceptions are investment and employment:
//   - investment because the construction series carries genuine definitional
//     churn across the boom/bust
//   - employment because the temporary-contract segment makes the employees
//     vs. total-employment gap move over the cycle, which the observable does
//     not resolve (see the chi_n caveat in Spain_calibration.mod)

shocks;
    var y;      stderr 0.3;      // GDP
    var c;      stderr 0.3;      // Consumption
    var inv;    stderr 0.6;      // Investment: construction boom/bust
    var pi;     stderr 0.2;      // Inflation: HICP, euro area
    var R;      stderr 0.2;      // Interest rate: ECB (area-wide, as Germany)
    var n;      stderr 0.35;     // Employment: dual labour market composition
    var L;      stderr 0.20;     // Labor force: migration swings
    var h;      stderr 0.3;      // Hours per employee
end;
