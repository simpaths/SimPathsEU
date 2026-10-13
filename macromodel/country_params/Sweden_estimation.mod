// =========================================================================
// SHOCKS, PRIORS & ESTIMATION SETUP - SWEDEN
// =========================================================================

// Data file for estimation (set as Dynare macro for template)
@#define datafile = "data/data_for_dynare_Sweden.csv"

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
    var eps_a;      stderr 0.40;    // technology
    var eps_d;      stderr 5.00;    // demand
    var eps_r;      stderr 0.50;    // monetary: active, independent Riksbank
    var eps_L;      stderr 0.20;    // labor force: migration-driven swings
    var eps_sep;    stderr 0.10;    // separation: moderate turnover
    var eps_h;      stderr 0.30;    // hours: a real margin here (korttidsarbete)
    var eps_p;      stderr 0.80;    // cost-push: floating SEK pass-through
    var eps_inv;    stderr 1.00;    // investment: ICT/R&D-heavy, volatile
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
