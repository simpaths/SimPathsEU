# Bayesian Estimation Guide for the DSGE Model

## Overview

This guide explains how the DSGE cycle layer is estimated, how to run an estimation and how to judge its
result. The model is `Macromodel_template.mod`, run through the country wrapper `Macromodel_{Country}.mod`; the
country files under `country_params/` hold everything country-specific. The estimation file
`country_params/{Country}_estimation.mod` is the authority for priors, shocks and the datafile; this guide does
not copy its values.

---

## 1. Why Bayesian Estimation?

- **Incorporates prior knowledge** from the literature (e.g. Taylor rule coefficients, matching elasticities)
- **Handles weak identification** better than maximum likelihood: weak data do not overpower sensible priors
- **Quantifies uncertainty** through posterior distributions
- **Standard in the DSGE literature**, which keeps the results comparable

Prior beliefs and data combine into the posterior:

$$p(\theta | \text{data}) \propto p(\text{data} | \theta) \times p(\theta)$$

---

## 2. What Is Estimated

Only a few parameters are estimated; every other structural parameter is fixed at its calibrated value in
`country_params/{Country}_calibration.mod`, because its identification problem is structural rather than
data-specific (the estimation file lists them in its comments):

| Estimated | Prior family | Role |
|---|---|---|
| `omega_h` | Beta | Hours weight in production |
| `phi_inv_r` | Gamma | Cost-of-capital sensitivity of investment |
| `stderr eps_a`, `eps_d`, `eps_r`, `eps_p`, `eps_h`, `eps_L`, `eps_inv` | Inverse gamma | Standard deviations of the technology, demand, monetary, cost-push, hours, labour-force and investment shocks |

Fixed at calibrated values include the search-and-matching and pricing parameters (`kappa`, `eta`, `lambda_p`,
`phi_mc`, `phi_v_y`, `lambda_w`), preferences and policy (`sigma`, `phi_pi`, `phi_y`, `rho_r`), every shock
persistence (`rho_a`, `rho_L`, `rho_h`, `rho_inv` and the others) and the separation shock's standard
deviation. `docs/MULTI_COUNTRY_WORKFLOW.md` explains how the calibrated values are set.

### Prior distribution choice

| Distribution | Use case | Example here |
|---|---|---|
| **beta(μ, σ)** | Parameters bounded in [0, 1] | `omega_h` |
| **gamma(μ, σ)** | Positive parameters | `phi_inv_r` |
| **inv_gamma(μ, σ)** | Shock standard deviations | every `stderr` |
| **normal(μ, σ)** | Unbounded parameters | not used |

---

## 3. Data

The eight observables are declared in `Macromodel_template.mod`: `varobs y inv c pi R n L h` (output,
investment, consumption, inflation, the short-term rate, persons in employment, the labour force, hours per
person employed).

- The datafile is `data/data_for_dynare_{Country}.csv`, written by `ramsey_trend.m`: the real variables are
  **Ramsey-detrended** 100×log deviations, so the DSGE fluctuates around the Ramsey path; `pi` and `R` enter as
  demeaned percent. The HP-filtered `data/data_for_dynare_hp_{Country}.csv` is a benchmark only.
- The sample is set by the data stage (`stata/make_datasets.do`) and the estimation file; the per-country start
  dates are in `docs/MULTI_COUNTRY_WORKFLOW.md`. In the COVID quarters (2020q1-2021q2) every observable except
  the interest rate is missing in the datafile, and Dynare's Kalman filter handles the gap.

---

## 4. Running an Estimation

The estimation runs as step 1 of `run_full_workflow('{Country}')`, or on its own from `input_processing/macromodel/`:

```matlab
>> dynare Macromodel_Poland.mod use_dll
```

The template first runs `identification(advanced=1, max_dim_cova_group=3)`, then:

```
estimation(datafile=..., first_obs=1, prefilter=1,
           mode_compute=4, mode_check,
           diffuse_filter, fast_kalman_filter, lyapunov=doubling,
           mh_replic=20000, mh_nblocks=2, mh_drop=0.5,
           bayesian_irf, smoother, moments_varendo)
```

that is, a posterior mode by `csminwel` (`mode_compute=4`), then two Metropolis-Hastings chains of 20,000 draws
with half discarded as burn-in. For Poland this takes about three minutes. Afterwards `generate_frozen_model`
writes the posterior modes into `Macromodel_{Country}_frozen.mod`, the model the export uses (step 2), and
`postestimation_analysis` produces the diagnostics and the summary report (step 4).

---

## 5. Judging the Result

| Check | What to look for |
|---|---|
| Mode finding | the optimiser converges; the `mode_check` plots peak at the mode, not at a prior bound |
| Acceptance rate | 20–30% per chain |
| Convergence | Brooks-Gelman statistics near 1; trace plots that mix well |
| Prior vs posterior | the posterior differs from the prior where the data are informative |
| Log data density | the Laplace and the modified harmonic mean values agree closely |
| IRF signs | the patterns in `docs/MULTI_COUNTRY_WORKFLOW.md` ("Policy-Matrix Sign Verification") hold |

A new machine or Dynare version re-estimates within `rel_tol = 1e-3` of the committed bundle
(`smoke_test.ps1 -Estimate`, see `../README.md`); a larger difference needs explaining.

---

## 6. Troubleshooting

### "Blanchard-Kahn conditions not satisfied"

Some parameter values make the model indeterminate or explosive.
1. Check that the Taylor rule satisfies the Taylor principle (`phi_pi > 1`)
2. Check that persistence parameters stay below 1
3. Look for a typo in the calibration file

### "Cannot find mode"

1. Try a different optimiser: `mode_compute=6` (Monte Carlo based) or `9` (CMA-ES)
2. Check whether a prior is too tight (posterior mode at a prior bound)
3. Estimate fewer parameters first

### Acceptance rate far below 20%

The jump scale is too large: lower `mh_jscale` (e.g. 0.1) or let Dynare tune it (`mh_tune_jscale=0.3`).

### Posterior identical to the prior

The data carry no information on the parameter: check that it affects an observable, and calibrate it if it
does not.

---

## 7. Frequency

The model is quarterly and stays quarterly in SimPaths: Java steps the quarterly policy matrices four times per
simulated year on the scenario's shocks and averages the quarters into the annual cycle values
(`DSGEModel.stepAnnual`). No parameter is converted to annual frequency.

---

## 8. References

### Bayesian estimation methodology
- **An & Schorfheide (2007)** "Bayesian Analysis of DSGE Models", *Econometric Reviews*
- **Herbst & Schorfheide (2015)** "Bayesian Estimation of DSGE Models", Princeton University Press

### Search and matching estimation
- **Lubik (2009)** "Estimating a Search and Matching Model of the Aggregate Labor Market", *Economic Quarterly*
- **Christoffel, Kuester & Linzert (2009)** "The Role of Labor Markets for Euro Area Monetary Policy",
  *European Economic Review*

### Dynare
- **Dynare Manual:** https://www.dynare.org/manual/
- **Forum:** https://forum.dynare.org
