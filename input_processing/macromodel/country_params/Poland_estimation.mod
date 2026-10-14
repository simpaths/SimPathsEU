// =========================================================================
// SHOCKS, PRIORS & ESTIMATION SETUP - POLAND
// =========================================================================

// Data file for estimation (set as Dynare macro for template)
@#define datafile = "data/data_for_dynare_Poland.csv"

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
    var eps_a;      stderr 0.40;    // technology: higher for catch-up economy
    var eps_d;      stderr 5.00;    // demand: higher volatility (trade/FDI cycles)
    var eps_r;      stderr 0.80;    // monetary: NBP rate changes more volatile than ECB
    var eps_L;      stderr 0.06;    // labor force: EU migration creates larger L shocks
    var eps_sep;    stderr 0.10;    // separation: more flexible labor market
    var eps_h;      stderr 0.30;    // hours shock (less institutional adjustment than Germany)
    var eps_p;      stderr 0.70;    // cost-push: higher due to energy import dependence + PLN
    var eps_inv;    stderr 0.60;    // investment: more volatile (EU funds, FDI cycles)
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
