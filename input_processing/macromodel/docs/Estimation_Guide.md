# Bayesian Estimation Guide for DSGE Model

## Overview

This document explains the Bayesian estimation strategy for the hybrid New Keynesian Search-and-Matching model in `lubik_germany.mod`.

---

## 1. Why Bayesian Estimation?

### Advantages
- **Incorporates prior knowledge** from literature (e.g., Taylor rule coefficients)
- **Handles identification issues** better than ML (weak data doesn't overpower sensible priors)
- **Quantifies uncertainty** via posterior distributions
- **Standard in DSGE literature** (comparability with other studies)

### Key Concept
Combine **prior beliefs** (from theory/literature) with **data** to get **posterior distributions**:

$$p(\theta | \text{data}) \propto p(\text{data} | \theta) \times p(\theta)$$

- $p(\theta)$ = prior (what you believe before seeing data)
- $p(\text{data} | \theta)$ = likelihood (how well model fits data)
- $p(\theta | \text{data})$ = posterior (updated beliefs)

---

## 2. Parameter Prioritization

### **Tier 1: MUST ESTIMATE** (Model-Specific, Hard to Calibrate)

| Parameter | Description | Why Estimate | Prior |
|-----------|-------------|--------------|-------|
| **kappa** | Vacancy posting cost | Model-specific, affects hiring dynamics | gamma(0.05, 0.02) |
| **eta** | Worker bargaining power | Critical for wage feedback to microsim | beta(0.5, 0.1) |
| **lambda_p** | Phillips curve slope | Core inflation mechanism | gamma(0.05, 0.02) |
| **phi_mc** | Output gap → marginal cost | Your hybrid model innovation | gamma(0.2, 0.1) |
| **gamma_y** | Output convergence speed | Your hybrid model innovation | beta(0.5, 0.2) |
| **phi_v_y** | Vacancy demand sensitivity | Novel channel, needs validation | gamma(1.0, 0.5) |

**Rationale:** These parameters define your model's unique mechanisms. Literature doesn't provide clear guidance, so let German data speak.

### **Tier 2: SHOULD ESTIMATE** (Standard But Uncertain)

| Parameter | Description | Prior | Literature Range |
|-----------|-------------|-------|------------------|
| **sigma** | Inverse IES (risk aversion) | gamma(1.0, 0.25) | 0.5–2.0 |
| **phi_pi** | Taylor rule: inflation | normal(1.5, 0.25) | 1.2–2.0 |
| **phi_y** | Taylor rule: output | gamma(0.125, 0.05) | 0.05–0.25 |
| **rho_r** | Interest rate smoothing | beta(0.85, 0.05) | 0.7–0.95 |
| **rho_a** | Technology persistence | beta(0.95, 0.03) | 0.85–0.99 |
| **rho_v** | Vacancy persistence | beta(0.9, 0.05) | 0.7–0.95 |
| **rho_sep** | Separation shock persistence | beta(0.8, 0.1) | 0.6–0.9 |
| **rho_match** | Matching shock persistence | beta(0.8, 0.1) | 0.6–0.9 |

**Rationale:** Literature provides ranges, but German-specific values uncertain. Priors are informative but allow data to update beliefs.

### **Tier 3: KEEP CALIBRATED** (Well-Established)

| Parameter | Value | Source | Why Not Estimate |
|-----------|-------|--------|------------------|
| **beta** | 0.99 | Steady-state real interest rate | Pins down long-run level |
| **alpha_m** | 0.5 | Petrongolo & Pissarides (2001) | Robust cross-country finding |
| **alpha_n** | 0.65 | Destatis VGR (labor share) | Directly observed in national accounts |
| **delta** | 0.025 | IAB labor flow data | Directly observed (low German turnover) |
| **chi_L** | 0.77 | Destatis (L/pop share) | Population data (not estimated) |
| **chi_n** | 0.73 | Destatis (N/pop share) | Population data |
| **chi_u** | 0.04 | Derived as `chi_L - chi_n` (U/pop share) | Identity, not the U/L rate |

**Rationale:** Either pinned by steady-state targets or well-established in literature. Estimating would waste degrees of freedom.

---

## 3. Prior Selection Rationale

### 3.1 Distribution Choice

| Distribution | Use Case | Example |
|--------------|----------|---------|
| **beta(μ, σ)** | Bounded [0,1] parameters | Persistence (rho), probabilities |
| **gamma(μ, σ)** | Positive parameters | Standard deviations, slopes |
| **normal(μ, σ)** | Unbounded parameters | Policy coefficients (can be >1) |
| **inv_gamma(s, ν)** | Shock std deviations | Standard in DSGE literature |

### 3.2 Specific Priors

**kappa = gamma(0.05, 0.02)**
- Literature range: 0.01–0.10 (Hagedorn & Manovskii 2008: ~0.01; Shimer 2005: ~0.05)
- Loose prior → let data decide

**eta = beta(0.5, 0.1)**
- Hosios efficiency: eta = alpha_m ≈ 0.5 (symmetric bargaining)
- But German institutions (strong unions) might push eta higher
- Prior centered at 0.5, std 0.1 → 95% interval [0.3, 0.7]

**lambda_p = gamma(0.05, 0.02)**
- Europe: flatter Phillips curve than US (more rigid prices)
- Galí et al. (2012): euro area slope ~0.02–0.08

**phi_pi = normal(1.5, 0.25)**
- Taylor principle: must be > 1 for determinacy
- Literature: 1.2–2.0 (Clarida, Galí & Gertler 2000)
- Normal allows values > 1 without hard bound

**Shock std devs = inv_gamma(0.01, Inf)**
- Standard uninformative prior in Dynare
- Equivalent to diffuse prior (let data fully determine)

---

## 4. Data Preparation

### 4.1 Required Variables

The model needs **5 observables** (matching `varobs` in .mod file):

| Variable | Model | Data Source | Notes |
|----------|-------|-------------|-------|
| **y** | Output | Destatis VGR (BIP) | Real GDP, chain-linked |
| **pi** | Inflation | Eurostat HICP or Destatis VPI | Quarter-on-quarter, annualized |
| **R** | Interest rate | ECB or Bundesbank | 3-month Euribor or MRO rate |
| **w** | Real wage | Destatis (real wage index) | Or compensation per employee |
| **n** | Employment | Destatis LFS (15-64) | Or total employment |

### 4.2 Sample Period

**Recommended: 1999Q1–2024Q4** (EMU period)

| Period | Include? | Reason |
|--------|----------|--------|
| Pre-1999 | No | Different monetary regime (Bundesbank) |
| 1999-2007 | Yes | Normal EMU period |
| 2008-2009 | Yes | Financial crisis (keep, it's a shock) |
| 2010-2019 | Yes | Recovery + euro crisis |
| 2020-2021 | **Careful** | COVID-19 outlier (consider dummies) |
| 2022-2024 | Yes | Energy crisis + inflation spike |

**Handling COVID:** Either:
1. **Exclude** 2020Q2-2021Q2 (safest)
2. **Include with dummies** (captures structural info)

### 4.3 Data Transformation

**Model is in log-deviations from steady state**, so transform data:

**Option A: Manual HP-Filter (Recommended)**
```matlab
% In MATLAB
lambda = 1600;  % Standard for quarterly data
y_hp = hpfilter(log(y_level), lambda);
pi = 400 * log(CPI(2:end) ./ CPI(1:end-1));  % QoQ annualized
R = nominal_rate;  % Already in % (no transformation)
w_hp = hpfilter(log(real_wage), lambda);
n_hp = hpfilter(log(employment), lambda);
```

**Option B: Let Dynare Prefilter**
- Set `prefilter=1` in `estimation()` command
- Dynare will demean each series
- Simpler but less control

**Option C: First Differences** (if series are I(1))
```matlab
dy = 100 * diff(log(y_level));  % Growth rate
```

### 4.4 Creating Data File

**MATLAB format (.mat):**
```matlab
% Assumes you have T x 1 vectors: y, pi, R, w, n
% All same length (e.g., 100 quarters)

data_germany = [y, pi, R, w, n];  % T x 5 matrix
save('data_germany_quarterly.mat', 'data_germany');
```

**Excel format (.xlsx):**
- Column headers: `y`, `pi`, `R`, `w`, `n`
- Rows: observations (one per quarter)
- No date column needed (Dynare assumes consecutive periods)

---

## 5. Estimation Workflow

### Step 1: Quick Test (Mode Finding Only)

```matlab
% In lubik_germany.mod, set:
estimation(
    datafile=data_germany_quarterly,
    mode_compute=4,
    mode_check,
    mh_replic=0        % Skip MCMC
) y pi R w n;
```

**What it does:**
- Finds posterior mode (maximizes posterior density)
- Takes ~5–10 minutes
- Creates `mode_check` plots (are parameters identified?)

**Check:**
1. Did optimization converge? (Look for "Optimal value found")
2. Are mode_check plots bell-shaped? (Identification)
3. Are posterior modes "reasonable"? (Not at prior bounds)

### Step 2: Full Bayesian Estimation

If Step 1 succeeds, run MCMC:

```matlab
estimation(
    datafile=data_germany_quarterly,
    mode_compute=4,
    mode_check,
    mh_replic=20000,    % 20k draws per chain
    mh_nblocks=2,       % 2 chains
    mh_jscale=0.2,      % Jump scale
    mh_drop=0.5,        % 50% burn-in
    bayesian_irf,       % IRFs with uncertainty
    smoother            % Historical shocks
) y pi R w n;
```

**Runtime:** 2–6 hours (depends on hardware)

### Step 3: Convergence Diagnostics

After estimation completes, check:

| Diagnostic | File | What to Look For |
|------------|------|------------------|
| **Brooks-Gelman** | `graphs/BrooksGelman.pdf` | < 1.1 (preferably < 1.05) |
| **Acceptance rate** | Terminal output | 20–30% |
| **Trace plots** | `graphs/MH_chains/*.pdf` | "Hairy caterpillar" (good mixing) |
| **Prior-posterior plots** | `graphs/priors_posteriors.pdf` | Posteriors differ from priors (learning) |

**If convergence fails:**
- Increase `mh_replic` (e.g., 50000)
- Adjust `mh_jscale` (lower if acceptance < 20%)
- Use adaptive MCMC: `mh_tune_jscale=0.5`

---

## 6. Interpreting Results

### 6.1 Parameter Estimates

Dynare produces LaTeX table: `Output/lubik_germany_TeX_binder.pdf`

**Key columns:**
- **Prior Mean** vs. **Posterior Mean**: Did data update beliefs?
- **Posterior Std Dev**: Uncertainty (tight = well-identified)
- **90% Interval**: Credible interval

**Example interpretation:**

| Parameter | Prior Mean | Posterior Mean | Posterior 90% |
|-----------|------------|----------------|---------------|
| kappa | 0.05 | 0.032 | [0.018, 0.045] |
| eta | 0.50 | 0.62 | [0.51, 0.73] |

**Interpretation:**
- **kappa:** Data suggests lower vacancy costs than prior (easier hiring)
- **eta:** Workers have MORE bargaining power than symmetric (0.5) → strong German unions?

### 6.2 Model Fit

**Marginal Data Density (MDD):**
- Used to compare models (higher is better)
- Penalizes complexity (Bayesian Occam's razor)
- Reported in terminal: `Log data density is XXX`

**Variance Decomposition:**
- Which shocks explain most variation in observables?
- Look for: Technology dominant in output? Monetary in inflation?

### 6.3 Bayesian IRFs

Unlike calibrated model (point estimates), now you get **uncertainty bands**:

- **Dark line:** Median response
- **Shaded area:** 90% credible interval

**What to check:**
1. Are responses qualitatively similar to calibrated version?
2. Are uncertainty bands narrow (good identification) or wide?
3. Do key mechanisms (e.g., wage response to L shock) remain?

---

## 7. Troubleshooting

### Problem: "Blanchard-Kahn conditions not satisfied"

**Cause:** Some parameter draws create indeterminacy (model has infinite solutions)

**Fix:**
1. Tighten prior on `phi_pi` (ensure > 1): `normal(1.5, 0.15)` instead of 0.25
2. Check `rho_r` not too high (if > 1, non-stationary)
3. Use `mode_check_neighbourhood_size=1` (wider search)

### Problem: "Cannot find mode"

**Cause:** Identification issues or bad initial values

**Fix:**
1. Try different optimizer: `mode_compute=6` (gmhmaxlik) or `9` (CMA-ES)
2. Check if priors are too tight (posterior mode at prior bound)
3. Simplify: estimate fewer parameters first (e.g., drop Tier 2)

### Problem: MCMC not mixing (acceptance rate < 10%)

**Cause:** Jump scale `mh_jscale` too large

**Fix:**
1. Lower `mh_jscale` to 0.1 (smaller steps)
2. Or use adaptive tuning: `mh_tune_jscale=0.5, mh_tune_blocks=5`

### Problem: Posteriors identical to priors

**Cause:** Data uninformative for this parameter

**Fix:**
1. Check if variable enters observables (e.g., if no `v` in data, `rho_v` hard to identify)
2. Calibrate instead of estimating
3. Tighten prior (if parameter not identifiable, use external info)

---

## 8. Next Steps After Estimation

### 8.1 Model Validation

1. **In-sample fit:** Plot actual vs. filtered variables (`filtered_vars` option)
2. **Out-of-sample forecast:** Use `forecast=20` (20 quarters ahead)
3. **Historical shock decomposition:** Which shocks drove German recessions?

### 8.2 Sensitivity Analysis

- Estimate with **different sample periods** (e.g., exclude COVID)
- Estimate with **different observables** (e.g., `u` instead of `n`)
- Estimate with **alternative priors** (e.g., tighter `eta`)

### 8.3 Model Comparison

If you have alternative specifications (e.g., fixed labor force):

```matlab
% Model 1: Variable L
estimation(...) y pi R w n;
% Log data density: -524.3

% Model 2: Fixed L (rho_L=0)
estimation(...) y pi R w n;
% Log data density: -531.8

% Model 1 wins (higher MDD by 7.5 → odds ratio ≈ 1800:1)
```

---

## 9. Frequency Conversion (Quarterly → Annual)

The model is estimated at **quarterly** frequency, but microsimulation runs **annually**.

### Convert Persistence Parameters

$$\rho_{\text{annual}} = \rho_{\text{quarterly}}^4$$

**Example:**
- `rho_a` (quarterly) = 0.95 → (annual) = 0.95^4 = 0.815
- `rho_L` (quarterly) = 0.99 → (annual) = 0.99^4 = 0.961

### Convert Discount Factor

$$\beta_{\text{annual}} = \beta_{\text{quarterly}}^4$$

- `beta` (quarterly) = 0.99 → (annual) = 0.99^4 = 0.961

### Convert Separation Rate

$$\delta_{\text{annual}} = 1 - (1 - \delta_{\text{quarterly}})^4$$

- `delta` (quarterly) = 0.025 → (annual) = 1 - (1 - 0.025)^4 = 0.096

### Policy Matrices

For Java embedding, export **annual decision rules** from estimated model:
- Extract `oo_.dr` matrices (policy functions)
- Apply frequency conversion formulas
- Embed in microsimulation loop

---

## 10. References

### Bayesian Estimation Methodology
- **An & Schorfheide (2007)** "Bayesian Analysis of DSGE Models", *Econometric Reviews*
- **Herbst & Schorfheide (2015)** "Bayesian Estimation of DSGE Models", Princeton University Press

### Search & Matching Estimation
- **Lubik (2009)** "Estimating a Search and Matching Model", *Economic Quarterly*
- **Christoffel, Kuester & Linzert (2009)** "The Role of Labor Markets", *Journal of the European Economic Association*

### Dynare Documentation
- **Dynare Manual:** https://www.dynare.org/manual/
- **Estimation Section:** Chapter 4.18–4.20
- **Forum:** https://forum.dynare.org

---

*Document created: December 23, 2025*
