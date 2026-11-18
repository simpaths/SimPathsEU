// =========================================================================
// SHOCKS, PRIORS & ESTIMATION SETUP - GERMANY
// =========================================================================

// Data file for estimation (set as Dynare macro for template)
@#define datafile = "data/data_for_dynare_Germany.csv"

// =========================================================================
// CALIBRATED SHOCK STANDARD DEVIATIONS
// =========================================================================
// Starting values. The estimation replaces the standard deviations it
// estimates (estimated_params below); eps_sep, which is not estimated, keeps
// the value set here.
//
shocks;
    var eps_a;      stderr 0.25;    // technology
    var eps_d;      stderr 4.50;    // demand: main driver for y-pi
    var eps_r;      stderr 0.60;    // monetary
    var eps_L;      stderr 0.04;    // labor force
    var eps_sep;    stderr 0.08;    // separation (not estimated)
    var eps_h;      stderr 0.35;    // hours shock (Kurzarbeit): calibrated to σ(h) ≈ 0.8%
                                    // German data: σ(h) = 0.81%, σ(h)/σ(n) = 1.22
    var eps_p;      stderr 0.50;    // cost-push / price markup shock
    var eps_inv;    stderr 0.50;    // investment shock [CAPITAL EXTENSION]
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
