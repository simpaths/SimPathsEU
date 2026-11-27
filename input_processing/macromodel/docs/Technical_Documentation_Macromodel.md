# Ramsey and DSGE Macro Model: Technical Reference

This document describes the macro model behind SimPaths' macro layer as it is implemented: the Ramsey growth
model that provides the trend, the estimated New-Keynesian DSGE model that provides the cycle, how the trend
detrends the DSGE data, and what the MATLAB/Dynare side exports. It quotes no estimated value, moment or impulse
response; section 1.3 says which file holds each number. Companion documents: `../README.md` (toolchains,
running and verifying the workflow, country status), `SimPaths_Coupling.md` (the Java runtime: switches, the
yearly sequence of events, the planner's feedback), `Integration_Contracts.md` (the numbered contracts between
the stages and between MATLAB and Java, cited here as "contract N"), `MULTI_COUNTRY_WORKFLOW.md` (adding a
country, data sources and currency conventions), `Estimation_Guide.md` (priors, diagnostics, troubleshooting),
and the LaTeX model documentation `SimPaths_Macro_Model_Documentation.tex` in the Overleaf project
(`WELLSIM_SVEC_Overleaf`), whose tables are rendered from the post-estimation summaries in
`output/documentation_data/`.

## Document History

| Version | Date | Changes |
|---------|------|----------|
| v1 | Dec 2024 | Initial model with flexible Nash wages |
| v2 | Dec 23, 2025 | Added demand-supply gap structure |
| v3 | Dec 29, 2025 | Implemented Gertler-Trigari (2009) staggered wage bargaining |
| v4 | Jan 2, 2026 | Added demand shock (eps_d), calibration for positive y-π correlation, real data estimation |
| v5 | Jan 2, 2026 | Bayesian estimation completed, identification fixes, posterior results |
| v6 | Jan 10, 2026 | Switched to ILO unemployment for data consistency, re-estimated model |
| v7 | Jan 11, 2026 | Added intensive margin (hours h), 6 observables, new estimation |
| v8 | Jan 26, 2026 | Added direct L→w channel (ψ_wL), increased κ, re-estimated, improved marginal likelihood |
| v9 | Feb 3, 2026 | Option B: Observe L instead of u_rate, hours pure AR(1), ρ_h/ρ_L calibrated to resolve collinearity |
| v9.1 | Feb 6, 2026 | Fixed Java shock conventions: eps_L/eps_h raw, others σ-normalized |
| v10 | Feb 10, 2026 | Capital extension (Phase 2): added k, inv with reduced-form investment rule; inv as 7th observable |
| v11 | Feb 13, 2026 | Estimated investment rule parameters (rho_inv, phi_inv_y, phi_inv_r); 11 params, 8 shocks |
| v11b | Feb 13, 2026 | Dropped phi_inv_y (collinearity 0.9989 with rho_inv); 10 estimated params; log ML = −905.0 |
| **v12** | **Feb 16, 2026** | **Option C: Smets-Wouters C/I decomposition (consumption Euler + demand aggregation); cost-push shock eps_p; sigma=2.0 calibrated; 8 observables, 9 shocks, 10 params; log MDD = −1042.6** |
| **v13** | **Feb 17, 2026** | **Dropped eps_match/match_shock (no explanatory power in VD); matching equation simplified; 8 observables, 8 shocks, 9 estimated params** |
| **v14** | **Feb 17, 2026** | **Added external habit persistence in consumption (hab=0.5 calibrated) and explicit AR(1) demand state `d_shock`; activated ρ_d propagation; state-space now includes c and d_shock as states (22 endogenous, 12 states, 10 jumps)** |
| **v15** | **Feb 18, 2026** | **Inflation indexation (iota_p=0.35, hybrid NKPC with pi(-1)); restored investment accelerator (phi_inv_y=0.3 calibrated); log ML improved +20.7 (−920.25 → −899.51); σ_p dropped 37% (2.26 → 1.43); investment VD reshaped (95.7% own → 72.4% own + 13.6% cost-push + 9.2% monetary)** |
| **v16** | **Feb 26, 2026** | **Dual-layer macro architecture: Long-run trend component (Ramsey growth model) + business cycle component (DSGE)** |
| **v17** | **Mar 09, 2026** | **Ramsey Model: Endogenous labor supply implementation; `ramsey_labor_supply` switch (defaults to exogenous). Dynare files template-based structure (`Macromodel_[COUNTRY].mod`).** |
| **v18** | **Oct 20, 2026** | **Ramsey Model: endogenous labour supply removed (JuergenWiemers/SimPathsEU#28). The Ramsey layer solves exogenous labour only; SimPaths' realized labour reaches the planner through the yearly re-solve (`mm_ramseyFeedbackMargins`, `SimPaths_Coupling.md` §8.1).** |
| **v19** | **Nov 6, 2026** | **The DSGE is one-way: it takes no input from SimPaths and runs on scenario shocks only (contract 38). SimPaths' employment and hours reach the planner alone, counted once a year after the labour market; the feedback is always on with one persistence `mm_ramseyFeedbackPersistence` (`mm_ramseyFeedbackMargins` and `mm_ramseyFeedbackHoursPersistence` removed). The labour-force and hours shocks are ordinary shocks: the frozen models and bundles carry the calibrated ρ_L, ρ_h (the `for_simpaths_export` switch is gone), every shock is in σ-units, and the bundle declares `deviation_scale` (contracts 1, 37).** |
| v20 | Nov 7, 2026 | Rewritten as a current-state reference; estimates, moments and IRFs are read from their sources (frozen model files, bundle, post-estimation output) instead of being copied here. |
| v21 | Nov 7, 2026 | The wage SimPaths applies is the trend wage's level times the cycle's factor, $(1 + w^{trend}/100)\exp(w^{cycle}/100)$, instead of the sum of the two percentages, and the cycle is the DSGE's wage per hour $w - h$ instead of its wage per employee $w$ (contract 40). The `*_total` columns of `MacroPaths.csv` follow the same rule. |
| v22 | Nov 8, 2026 | The planner's consumers are the resident population $P_t$: utility is weighted by $P_t$ and consumption is per head, $C_t = P_t c_t$, instead of employees and consumption per employee. Its workers $N_t$ are all persons in employment, employees and self-employed, with hours per person employed, in the data stage, the calibration, the DSGE observables `n` and `h` and the feedback (contract 16 closed). The data stage adds the resident population with census breaks spliced; in sample the planner's population is its HP trend, as employment is that of total employment, and after the sample end both grow with the SimPaths workbook; `demographic_P_{country}.csv` carries the trend and the workbook's growth, the bundle's population projection carries `time,N,P` and the reference CSV a column `P`, and beyond the projection the dependency ratio is frozen. SimPaths' population is fed back to the planner with its own level factor $\lambda_P$, latched with $\lambda$ (contracts 41-43; `p_ramsey`, `p_realized_gap` in `MacroPaths.csv`). |
| v23 | Nov 9, 2026 | All five countries enable `terminal_growth` with a common long-run TFP growth of 0.5% and a common `rho_quarterly` of 0.966 (half-life 5 years); before, only Poland converged (half-life 11.5 years) and the others kept their in-sample rate for ever. Poland's in-sample TFP growth is 1.9% (was 1.5%) and its `K_override` the PWT capital-output ratio 2.21 (was 2.50); Germany's in-sample rate is 0.53% (was 0.5%) and it gains a `K_override` at its balanced-growth K/Y (3.19, instead of the perpetual-inventory 3.58). Both follow the rule $g_A = (1-\alpha)\,g_{Y/(Nh)}$ on total employment, which PR #40 had left at the employee-based values; Poland's output gap no longer drifts. All five countries re-estimated. |
| v24 | Nov 10, 2026 | The year against which the planner measures SimPaths' workers, hours and population is a setting, `mm_ramseyFeedbackReferenceYear` (default: the first simulated year after the start year, as before); the feedback starts the year after it (contract 46). |

---

## 1. Architecture

### 1.1 Trend and cycle

The macro layer splits the macroeconomy into two components:

- **Trend: a Ramsey growth model.** A deterministic planner chooses consumption and capital along a
  perfect-foresight path, given exogenous paths for TFP, persons in employment, hours per person employed, the
  resident population and the government and net-export shares of output. Its consumers are the resident
  population: utility is weighted by it and consumption is per head. It provides the secular path of output,
  consumption, investment, capital, the return on capital and the hourly wage. MATLAB (`ramsey_trend.m`) solves
  it over the estimation sample, where it detrends the DSGE data, and forward from the SimPaths handoff quarter,
  which fixes the starting state; Java (`RamseyTrendModel`) solves the same forward problem at runtime, where it
  provides the trend wage.
- **Cycle: an estimated linear DSGE model.** A New-Keynesian search-and-matching model with staggered wage
  bargaining, capital and an hours margin, estimated by Bayesian methods on the data's deviations from the trend.
  It provides the cyclical deviation of the real wage (and of inflation) from the trend.

**Moving steady state.** The DSGE is estimated on deviations of the observables from the Ramsey trend (output,
consumption, investment) and from the labour, inflation and interest-rate trends built in the same step
(section 2.5). Its steady state is therefore the trend path itself: a zero DSGE state means the economy is on
the trend, and the cycle wage is a 100 × log deviation around the trend wage of the same year. SimPaths applies
their product as a wage multiplier, $1 + w^{total}_t/100 = (1 + w^{trend}_t/100)\,\exp(w^{cycle}_t/100)$, so a
cycle keeps its size however far the trend has moved (contract 40). Both are wages per hour: the trend wage is
$(1-\alpha)Y/(Nh)$, and the cycle is $w^{cycle}_t = w_t - h_t$, because the model's $w$ is the bargained wage per
worker (section 3.5; `SimPaths_Coupling.md` §3.2).

**The DSGE is one-way.** It takes no input from SimPaths: its shocks come from a scenario file only, all zero
without one, and it hands SimPaths the cycle wage (contract 38). SimPaths' labour supply reaches the macro side
through the planner alone. The reason is that nothing SimPaths produces is a business-cycle movement: its
workers move with ageing, reforms, alignment and sampling noise, and counting those movements in the cycle wage
as well as in the trend wage would count them twice (`SimPaths_Coupling.md` §3.1).

**The planner re-solves once a year.** After SimPaths' labour market and population alignment, the realized
number of workers, their mean hours and SimPaths' population are compared with the planner's assumed paths, and
the planner re-solves its remaining path from the predetermined capital stock (extended path, persistence
`mm_ramseyFeedbackPersistence`). The comparison takes one year as its reference, the first simulated year after
the start year unless `mm_ramseyFeedbackReferenceYear` names a later one, and starts the year after it.
The wage of year $t$ comes from the path solved at the end of year $t-1$.
The mechanism, the persistence semantics and the treatment of hours and population are in
`SimPaths_Coupling.md` §8.1.

### 1.2 Information flow

```
align_popProjections.xlsx --(growth of the population aged 15-64 and of all ages)--> Ramsey planner (N and P paths)
SimPaths realized workers, hours and population (end of year) --> Ramsey re-solve of the remaining path
Ramsey planner --> w_trend: % change of the hourly wage since the handoff quarter, annual mean
Scenario shocks (sigma-units) --> DSGE: 4 quarterly steps, annual mean --> w_cycle = w - h (per hour), pi_cycle
SimPaths wages x (1 + w_total/100) = (1 + w_trend/100) exp(w_cycle/100)
                                                    (pi_cycle is recorded in MacroPaths.csv, applied to no agent)
```

Which layers run is set by `mm_macroModel` (`off | ramsey | dsge | ramsey_dsge`, default `off`;
`SimPaths_Coupling.md` §6).

### 1.3 Where the numbers are

| Quantity | File |
|---|---|
| Calibrated DSGE parameters, steady-state labour-market shares | `country_params/{Country}_calibration.mod` |
| Priors, starting values, calibrated std devs (`eps_sep`, measurement errors), datafile | `country_params/{Country}_estimation.mod` |
| Posterior modes of the estimated parameters and shock std devs | `Macromodel_{Country}_frozen.mod`, lines marked `// ESTIMATED` |
| σ per shock as SimPaths applies it, and the persistence parameter of the equation each shock enters | `input/{CC}/MacroModel/shock_params.csv` |
| Policy matrices, variable layout, units | `policy_A.csv`, `policy_Bs.csv`, `policy_C.csv`, `policy_D.csv`, `model_info.json` (bundle) |
| Impulse responses to one-σ innovations at the posterior mode | `irfs_eps_*.csv` (bundle) |
| Posterior means and 90% HPD intervals, marginal data density, identification, moments, variance decompositions | `Macromodel_{Country}/Output/postestimation_summary.txt` and `DSGE_Estimation_Report.pdf`; `output/documentation_data/dsge/dsge_postestimation_{Country}.json`; the tables of the LaTeX documentation |
| Ramsey structural parameters, inflation target, solver settings, terminal growth | `country_params/{Country}_growth_params.json` (source template) |
| Calibrated base-year levels, expenditure shares, BGP K/Y and r* | `input/{CC}/MacroModel/growth_params_{Country}.json` (`base_year_values`, `expenditure_shares`, `derived`); `output/documentation_data/ramsey/ramsey_summary_{Country}.json` |
| Trend paths over the sample | `output/ramsey_trends_{country}.csv`; through the handoff quarter, `growth_model_reference_{country}.csv` (bundle) |
| Handoff state and forward paths | `growth_terminal_state.json`, `population_projection_{Country}.csv`, `hours_projection_{Country}.csv` (bundle) |

`Macromodel_{Country}/`, `output/`, `logs/` and `params_{Country}_estimated.txt` are not tracked;
`run_full_workflow` regenerates them. The frozen models, the `data/` files, the country parameter files and the
bundles are tracked.

---

## 2. Ramsey Trend Layer

### 2.1 The planner's problem

$$\max_{\{c_t,\,K_{t+1}\}} \sum_t \beta^t P_t\, \frac{c_t^{1-\sigma}-1}{1-\sigma}$$

subject to

$$K_{t+1} = (1-\delta)K_t + Y_t - P_t c_t - (g_{Y,t} + nx_{Y,t})\,Y_t, \qquad Y_t = A_t K_t^{\alpha}(N_t h_t)^{1-\alpha}.$$

$P_t$ is the resident population of all ages, the planner's consumers, each person with weight one; $N_t$ the
number of persons in employment, employees and self-employed (national concept); $h_t$ hours per person
employed per quarter; $c_t$ private consumption per head; and $g_{Y,t}$, $nx_{Y,t}$ the exogenous
government-consumption and net-export shares of output. The objective is total utility (Benthamite), so the
population weight cancels from the first-order conditions, and the shares enter the resource constraint only;
the Euler equation is the closed-economy one:

$$\frac{c_{t+1}}{c_t} = \left[\beta(1+r_{t+1})\right]^{1/\sigma}, \qquad r_t = \alpha\frac{Y_t}{K_t} - \delta, \qquad w_t = (1-\alpha)\frac{Y_t}{N_t h_t}.$$

Labour input and population are exogenous: the planner takes $N_t$, $h_t$ and $P_t$ as given, and SimPaths'
realized employment, hours and population reach it through the yearly re-solve (section 1.1). Aggregate
consumption is $C_t = P_t c_t$, and investment is the residual $I_t = Y_t - C_t - G_t - NX_t$. The wage $w_t$ is
the average labour income per hour of all persons in employment; the labour share $1-\alpha$ is the same
concept as the Penn World Table's `labsh`, which the country files compare `alpha_K` with and which imputes
labour income to the self-employed. The level of $P$ is a pure scale: scaling the whole $P$ path by a constant
scales $c$ by its inverse and leaves $K$, $Y$, $C$, $w$ and $r$ unchanged
(`RamseyTrendModelTest.testPopulationLevelIsPureScale`), so the population moves the allocation only through
the time shape of its path.

The model is quarterly. The JSON holds annual values, which both solvers convert:
$\beta = \beta_a^{1/4}$, $\delta = 1-(1-\delta_a)^{1/4}$, $g_A = (1+g_{A,a})^{1/4}-1$.

**Terminal condition.** The transversality condition is approximated by requiring capital-output to reach its
balanced-growth value at the end of a long terminal tail:

$$\frac{K_T}{Y_T} = \kappa^{BGP} = \frac{\alpha}{r^* + \delta}, \qquad 1 + r^* = \frac{(1+g_c)^{\sigma}}{\beta}, \qquad g_c = \frac{g_A^{BGP}}{1-\alpha},$$

with $g_A^{BGP}$ the terminal TFP growth rate when terminal growth is enabled (section 2.3), and
`tfp_growth_annual` otherwise. On the balanced path $N/P$ and $h$ are constant, so consumption per head grows at
the rate of output per worker; the tails of section 2.3 make both hold where the condition acts.

### 2.2 Calibration (`calibrate_growth_model.m`)

The structural parameters (`alpha_K`, `delta_annual`, `beta_annual`, `sigma`, `tfp_growth_annual`, the
optional `K_override`, `base_year`, the `inflation_target` block, the `solver` block and the optional
`terminal_growth` block) are set by hand in `country_params/{Country}_growth_params.json`, whose `x_comments`
give the reasons. `calibrate_growth_model` reads that template and the levels file
`data/data_for_dynare_levels_{Country}.csv`, and writes the calibrated copy
`input/{CC}/MacroModel/growth_params_{Country}.json` that both the MATLAB solve and Java read:

1. Drop trailing quarters without production data; take the base year's four quarters (all four must exist).
2. Base-year levels: annual GDP, consumption, investment, government consumption and net exports (sums of the
   four quarters); persons in employment $N_0$, the labour force $L_0$, hours per person employed $h_0$ and the
   resident population $P_0$ (averages). A levels file without `pop_level` stops the calibration. Check the
   expenditure shares $C/Y$ and $I/Y$ for unit errors.
3. Capital by perpetual inventory, $K_0 = I_0/(\delta_a + g_Y)$, with $g_Y$ the average annual GDP growth
   between the first and last four-quarter windows of the sample. A positive `K_override` replaces it.
4. Compare the PIM (or override) $K/Y$ with the balanced-growth $K/Y$ of section 2.1 and warn if they differ by
   more than 20%. With an override, the override's ratio is the operative check.
5. Implied TFP from the production function in quarterly terms,
   $A_0 = Y_{q,0} / \left(K_0^{\alpha}(N_0 h_0)^{1-\alpha}\right)$ with $Y_{q,0}$ a quarter of base-year GDP and
   $N_0 h_0$ the hours worked by all persons in employment.
6. Write the trend files where missing or stale (a row count that does not fit the sample; the demographic
   files may run past it): `data/nawru_{country}.csv` (placeholder: HP
   trend, $\lambda = 160{,}000$, of the ILO unemployment rate; diagnostics only),
   `data/demographic_L_{country}.csv` (placeholder: HP trend of the log labour force, same $\lambda$) and
   `data/demographic_P_{country}.csv` (`time,P_demo`: HP trend, same $\lambda$, of the log resident population,
   the in-sample path of the planner's consumers; the census breaks are spliced before, in the data stage,
   section 5.4).
7. Write `base_year_values` (including `P`), `expenditure_shares`, `derived` (quarterly β and δ, terminal TFP
   growth, BGP $K/Y$ and $r^*$) and the normalised `solver` block into the calibrated JSON, and mark the bundle
   unverified until the next export verifies it (contract 36). A summary goes to
   `output/documentation_data/ramsey/ramsey_summary_{Country}.json`; its `base_year_values` include `P0` and
   the base-year population per person in employment, `dependency_ratio0` $= P_0/N_0$.

$K_0$ and $A_0$ are anchored at the first row of the data file, which must be the base year's first quarter
(contract 13). The Ramsey depreciation rate and the DSGE's `delta_k` differ on purpose: the Ramsey rate applies
to total gross fixed capital formation, structures included, and sets the long-run $K/Y$; `delta_k` governs
the cyclical capital law of motion only. Parameters of the same name in the two layers (σ, the capital share,
depreciation) are set separately, in their own files.

### 2.3 Exogenous paths

| Path | Construction (`ramsey_trend.m`) |
|---|---|
| Employment $N_t$ | HP trend ($\lambda = 160{,}000$) of log persons in employment (`n_level`, national concept), the concept $A_0$ is calibrated on |
| Population $P_t$ | HP trend ($\lambda = 160{,}000$) of the log resident population (`pop_level`, census breaks spliced in the data stage), computed in `ramsey_trend` as the employment trend is |
| Demographic labour force $L^{demo}_t$ | `data/demographic_L_{country}.csv`: through the handoff quarter, the HP trend of the log labour force; after it, the growth of the projected population aged 15-64 (section 2.6) |
| Hours per person employed $h_t$ | Log-linear trend fitted to log hours per person employed |
| $g_{Y,t}$, $nx_{Y,t}$ | HP trends ($\lambda = 160{,}000$) of the observed shares, with 2020Q1-2021Q2 interpolated first; constant at the last value beyond the sample |
| TFP $A_t$ | $A_0$ grown at `tfp_growth_annual` in sample |

**Terminal TFP growth.** With `terminal_growth.enabled`, annual TFP growth converges quarter by quarter towards
`g_A_terminal_annual`: $g_t = g^{term} + \rho_q\,(g_{t-1} - g^{term})$, with $\rho_q$ = `rho_quarterly`
(0.99 when absent) and quarterly growth $(1+g_t)^{1/4}-1$. In the in-sample solve the convergence starts after
the last data quarter; in the forward solve SimPaths uses (section 2.7) it starts at the handoff quarter, and a
re-solve continues the same convergence phase. The balanced-growth target uses $g^{term}$.

All five countries enable it with the same $g^{term}$ = 0.5% and $\rho_q$ = 0.966, a half-life of 5 years: the
in-sample rate `tfp_growth_annual` is measured per country, by the rule $g_A = (1-\alpha)\,g_{Y/(Nh)}$ with
$g_{Y/(Nh)}$ the growth of GDP per hour worked, unless the template's comment says why the rule value fits worse,
while the long-run rate and the speed of convergence are a common assumption. The rule holds only for a trend
that starts on its balanced path; where the perpetual-inventory capital stock is far from it, `K_override` sets
$K_0$ near the balanced-growth $K/Y$ at the in-sample rate (Germany, Poland, UK).

**Beyond the sample.** $N$ follows the growth of $L^{demo}$, chained at the last data quarter, for as long as
the population projection runs; without a projection it continues at its trailing 20-quarter growth. After the
end of the projection, and for hours after the end of the data, the growth rate tapers geometrically to zero
with a half-life of 20 quarters. The tail is a device for the terminal condition, not a forecast: on a balanced
growth path labour input per worker must settle, and an undamped decline would contradict the condition the
solve imposes. Java builds the tail with the same rule (`RamseyTrendModel.extendWithTaperedGrowth`).

$P$ follows the growth of `data/demographic_P_{country}.csv`, the projected population of all ages (section
2.6), chained at the last data quarter as $N$ is on $L^{demo}$, for as long as that file runs. It has no tail rule
of its own. Beyond the last quarter its source covers, the dependency ratio is held at its last value,
$P_t = (P/N)_{last}\,N_t$, whatever $N$'s tail rule, so $N/P$ is constant wherever the terminal condition acts: in both MATLAB solves (`extend_population_frozen_ratio` in `ramsey_trend.m`) and in Java, at the
end of the bundle's projection (`MacroModelManager.applyFrozenDependencyRatio`) and over the solver's terminal
tail (`RamseyTrendModel.extendWithFrozenRatio`). Germany and Sweden have no population workbook, so their
`demographic_P` ends with the sample and $P$ follows employment at the ratio of the last sample quarter.

### 2.4 Solution method

The Euler equation and the resource constraint of every quarter, with $K_1 = K_0$ fixed and the terminal
condition of section 2.1, form one stacked system in the unknowns $(c_1, K_2, c_2, \dots, c_T)$. A damped
Newton iteration solves it (stacked-time, LBJ): the finite-difference Jacobian is tridiagonal because each
residual couples adjacent quarters only, it is factorised as a sparse matrix, and an Armijo backtracking line
search keeps every iterate feasible. Tolerance, iteration limit and the length of the terminal tail are in the
JSON's `solver` block. On the first iteration the solver probes the off-band derivatives and fails if a
residual depends on an unknown outside the band (contract 14). Because the solve is global, anticipated and
delayed permanent changes need no saddle-path shooting. `RamseyTrendModel.java` implements the same algorithm;
`RamseyTrendModelTest` checks MATLAB-Java parity at a relative tolerance of $10^{-9}$ against fixtures refreshed
only by `refresh_java_parity_fixtures` (contract 19).

### 2.5 Detrending the DSGE observables

`ramsey_trend.m` turns the levels file into the Dynare datafile `data/data_for_dynare_{Country}.csv`, its only
writer (contract 12):

| Observable | Gap |
|---|---|
| `y` | $100(\ln Y^{obs} - \ln Y^{trend})$, Ramsey output |
| `c` | $100(\ln C^{obs} - \ln C^{trend})$, Ramsey private consumption $C_t = P_t c_t$ |
| `inv` | $100(\ln I^{obs} - \ln I^{trend})$, Ramsey residual investment |
| `pi` | $\pi^{obs} - \pi^*_t$, with $\pi^*$ converging from the mean of the first five quarters to the inflation target: $\pi^*_t = \rho\,\pi^*_{t-1} + (1-\rho)\,\pi^{target}$ (`inflation_target` block) |
| `R` | $R^{obs} - (r^{smooth}_t + \pi^*_t)$, with $r^{smooth}$ the HP trend ($\lambda = 160{,}000$) of the ex-ante real rate $R - \bar\pi^{(4)}$, $\bar\pi^{(4)}$ the backward four-quarter mean of inflation |
| `n` | $100(\ln N^{obs} - \ln N^{trend})$, persons in employment (total employment) |
| `L` | $100(\ln L^{obs} - \ln L^{demo})$, labour force |
| `h` | $100(\ln h^{obs} - \ln h^{trend})$, hours per person employed |

The interest-rate trend uses a smoothed ex-ante real rate rather than the Ramsey return on capital so that slow
movements in the policy-rate environment do not appear as a persistent monetary shock. Missing values of
$R - \bar\pi^{(4)}$ inside the sample are interpolated; missing values at either end are extrapolated with a
warning, because the HP trend follows the extrapolation across the whole sample. Each series is demeaned, and
2020Q1-2021Q2 is set to missing for every observable except `R` (the Kalman filter skips missing values). The
real gaps are 100 × log deviations, the scale the bundle declares (`deviation_scale = 100`, section 4).

`ramsey_trend` also writes `output/ramsey_trends_{country}.csv` (all trend paths), the reference
`output/growth_model_reference_{country}.csv` (section 2.7), the workspace `output/ramsey_trend_{country}.mat`
the exporters read, a diagnostic figure, and a sanity check of the investment trend and the expenditure shares
that warns loudly on failure. Its console report prints two further diagnostics that gate nothing: the
employment identity at the first quarter, $L^{demo}(1-\text{NAWRU})$ against $N^{trend}$, and the dependency
ratio $P/N$ of the forward solve at the handoff quarter and 37 years later.

### 2.6 Population and hours projections

`build_population_projection.m` reads `input/{CC}/align_popProjections.xlsx`, the projection SimPaths'
population alignment uses (sheet `Population_projections`, or the sheet named by the country code), sums the
population aged 15-64 and the population of all ages over genders and regions for each year, and spreads each
year's growth evenly over its quarters. It writes three files from those two growth paths:

1. `population_projection_{Country}.csv` (`time,N,P`), from the handoff quarter on: persons in employment,
   grown with the population aged 15-64 and anchored at $N$ in the last row of the reference CSV, and the
   resident population, grown with the population of all ages and anchored at $P$ in that row. Java reads both
   columns as the planner's forward $N$ and $P$, located by date (contract 21), and refuses a file without `P`
   (contract 42).
2. The rows of `data/demographic_L_{country}.csv` after the handoff quarter, anchored at $L^{demo}$ at the
   handoff, from the growth of the population aged 15-64.
3. The rows of `data/demographic_P_{country}.csv` after the handoff quarter, anchored at its value at the
   handoff, from the growth of the population of all ages.

`ramsey_trend` reads the two demographic files: `demographic_L` for the in-sample labour-force trend
$L^{demo}$, the growth of both after the last data quarter for the in-sample solve's $N$ and $P$, and both from
the handoff quarter on for the forward solve. Each pair, $N$ with `demographic_L` and $P$ with `demographic_P`,
must imply the same log growth after the handoff; `verify_export_bundle` checks both (contract 41). In sample,
$N$ and $P$ are HP trends of the data (section 2.3), so the workbook's growth between the handoff and the end of
the sample enters only $L^{demo}$ and the `L` observable. Because the stacked solve is global, the paths of $N$
and $P$ after the sample end still reach the in-sample trend and the detrended data: the planner of the first
sample quarter knows the projected dependency ratio and saves for it, which shapes the in-sample capital and
consumption trends and the `c` observable. `run_full_workflow` therefore runs `ramsey_trend` a second time when
step 0c changed either demographic file, and reports how far the anchor moved (`MULTI_COUNTRY_WORKFLOW.md`,
"The population workbook's growth reaches the estimation sample"). Without a workbook (Germany, Sweden) step 0c
does not run (section 2.3).

The dependency ratio the planner sees is the population per person in employment, $P/N$. On the Poland bundle
it is 2.13 at 2023q1 and 2.55 by 2060q4; on the UK bundle 2.05 at 2023q1 and 2.39 by 2100q4, the last quarter
of the projection: the UK workbook runs to 2120, and `build_population_projection` reads its year columns up to
2100. Its growth is that of the workbook's ratio of all ages to ages 15-64 (Poland: 1.55 in 2023, 1.84
in 2060). The planner sees the rise in advance and saves for it: on the Poland fixture a ratio rising by 19% to
2060 raises the trend wage by about 1.6% by 2060 against a constant ratio
(`RamseyTrendModelTest.testRisingDependencyRatioRaisesTheTransitionWage`).

With the same projection on both sides, the planner's assumed $N$ and $P$ and SimPaths' workers and population
are comparable, and the yearly feedback measures genuine gaps. The planner's $N$ and SimPaths' workers are the
same concept, all persons in employment, and so are the planner's $P$ and SimPaths' population; the feedback's
level factors `lambda` and `lambda_P` convert units (`SimPaths_Coupling.md` §8.1).

`hours_projection_{Country}.csv` (`time,h`, `projection_quarters + 1` rows from the handoff) is the forward
solve's hours path, the log-linear trend, written by `internal/write_hours_projection.m` for both export paths.
Java reads it and does not extend hours itself; a missing file fails the run.

### 2.7 The SimPaths handoff

SimPaths does not continue the in-sample solve. `ramsey_trend` solves a second, forward problem from the
handoff quarter `projection_start` (default `2023q1`, `internal/resolve_projection_start.m`), which must be a
quarter of the data file: capital and TFP at the handoff come from the in-sample solve, $N$ from its trend
through the handoff and the population projection's growth after it, $P$ from `demographic_P` through its last
row and at the frozen dependency ratio beyond it, hours from the log-linear trend, the shares are held at their
handoff values, and TFP growth converges from the handoff on. The horizon is `projection_quarters` (320,
exported, contract 9) plus the terminal tail. The last row of `growth_model_reference_{country}.csv`, whose last
column is `P`, is replaced by quarter 0 of this forward solve, so the reference ends exactly where Java's
projection starts, and `growth_terminal_state.json` carries capital and TFP at the handoff, `handoff_time` and
`projection_quarters`. Java solves the same forward problem from that state; the simulation
start year must match the handoff quarter (contract 10).

At runtime the trend wage of a simulated year is the percent change of the planner's annual-average hourly
wage $(1-\alpha)Y/(Nh)$ relative to quarter 0 (`MacroModelManager.advanceRamseyTrend`).

---

## 3. DSGE Cycle Layer

### 3.1 Structure

A linear (log-linearised) quarterly model with eight blocks:

| Block | Content | Variables |
|---|---|---|
| Supply | Production with capital, employment, hours and utilisation | `y`, `x`, `k`, `n`, `h` |
| Demand | Consumption Euler equation with external habits; demand as consumption plus investment (Smets-Wouters 2003 decomposition) | `c`, `d`, `d_shock` |
| Gap | Demand minus supply; enters production, marginal cost, vacancies and investment | `gap` |
| Pricing | Hybrid New-Keynesian Phillips curve with indexation and a cost-push shock | `pi`, `mc` |
| Policy | Taylor rule with smoothing | `R` |
| Labour market | Search and matching: matches, tightness, employment, unemployment, vacancy posting | `m`, `theta`, `n`, `u`, `u_rate`, `v`, `L`, `sep_shock` |
| Wages | Gertler-Trigari (2009) staggered Nash bargaining plus a direct labour-force term | `w_star`, `w` |
| Capital | Capital accumulation and a reduced-form investment rule | `k`, `inv` |

All variables are deviations from the trend (section 1.1). `y`, `c`, `inv`, `n`, `L`, `h` and the model-implied
`w` are percent deviations; `pi` and `R` are annualised rates, in percentage points from their trends. The
real wage is not an observable: `w` is what the model infers.

**States and jumps.** Dynare classifies a variable as a state when it appears with a lag. For the current
template the states are `c`, `R`, `pi`, `w`, `v`, `n`, `h`, `x`, `L`, `k`, `inv`, `sep_shock`, `d_shock`, and the
jumps `y`, `d`, `gap`, `w_star`, `u`, `u_rate`, `m`, `mc`, `theta` (`state_names` and `jump_names` in
`model_info.json` are authoritative). Habits make `c` a state, indexation `pi`, wage stickiness `w`.

### 3.2 Equations

As in `Macromodel_template.mod`, with its equation labels. Define the log marginal product of labour (written
out in full in the model file wherever it appears)

$$mpl_t \equiv x_t + \alpha_k k_{t-1} + (\alpha_n - 1)\,n_t + \alpha_n\omega_h h_t .$$

Supply and hours:

$$(1)\quad y_t = x_t + \alpha_k k_{t-1} + \alpha_n (n_t + \omega_h h_t) + \phi_{mc}\,gap_t$$

$$(2)\quad h_t = \rho_h h_{t-1} + \varepsilon^h_t$$

Demand:

$$(2a)\quad c_t - hab\cdot c_{t-1} = (E_t c_{t+1} - hab\cdot c_t) - \frac{1}{\sigma}(R_t - E_t\pi_{t+1}) + d^{shock}_t$$

$$(2b)\quad d_t = (1-s_{inv})\,c_t + s_{inv}\, inv_t \qquad (3)\quad gap_t = d_t - y_t$$

Pricing and policy:

$$(4)\quad mc_t = (w_t - mpl_t) + \phi_{mc}\,gap_t$$

$$(5)\quad \pi_t = \frac{\iota_p}{1+\iota_p\beta}\pi_{t-1} + \frac{\beta}{1+\iota_p\beta}E_t\pi_{t+1} + \frac{\lambda_p}{1+\iota_p\beta}\,mc_t + \varepsilon^p_t$$

$$(6)\quad R_t = \rho_r R_{t-1} + (1-\rho_r)(\phi_\pi\pi_t + \phi_y y_t) + \varepsilon^r_t$$

Labour market:

$$(7)\quad m_t = \alpha_m u_t + (1-\alpha_m)\,v_t \qquad (8)\quad \theta_t = v_t - u_t$$

$$(9)\quad n_t = (1-\delta)\,n_{t-1} + \delta\, m_t - sep_t$$

$$(10)\quad u_t = \frac{\chi_L}{\chi_u}L_t - \frac{\chi_n}{\chi_u}n_t \qquad (10b)\quad u^{rate}_t = \frac{\chi_n}{\chi_L}(L_t - n_t)$$

$$(11)\quad v_t = \rho_v v_{t-1} + (1-\rho_v)\left[(mpl_t - w_t) + \beta\lambda_w E_t(mpl_{t+1} - w_{t+1}) + \phi_{v,y}\,gap_t\right]$$

Wages:

$$(12a)\quad w^*_t = (1-\beta\lambda_w)\left[\eta\, mpl_t + (1-\eta)\,\kappa\,\theta_t\right] + \beta\lambda_w E_t w^*_{t+1}$$

$$(12b)\quad w_t = \lambda_w w_{t-1} + (1-\lambda_w)\,w^*_t + \psi_{wL} L_t$$

Exogenous processes:

$$(13)\quad x_t = \rho_a x_{t-1} + \varepsilon^a_t \qquad (14)\quad L_t = \rho_L L_{t-1} + \varepsilon^L_t$$

$$(14b)\quad d^{shock}_t = \rho_d d^{shock}_{t-1} + \varepsilon^d_t \qquad (15)\quad sep_t = \rho_{sep}\, sep_{t-1} + \varepsilon^{sep}_t$$

Capital:

$$(K1)\quad k_t = (1-\delta_k)\,k_{t-1} + \delta_k\, inv_t$$

$$(K2)\quad inv_t = \rho_{inv}\, inv_{t-1} + \phi_{inv,y}\,gap_t - \phi_{inv,r} R_t + \varepsilon^{inv}_t$$

Equation (10) is the exact linearisation of $U = L - N$, whose coefficients are $\bar L/\bar U$ and
$\bar N/\bar U$. It needs $\chi_u$ to be the unemployment-to-population share, $\chi_u = \chi_L - \chi_n$, not
the U/L rate (contract 4). With $N$ all persons in employment the identity holds in concept: the labour force
is the ILO count aged 15-74 (for Germany, Destatis's persons in employment plus unemployed), employment the
national-accounts count of all ages, and the data stage prints the residual $(L - U - N)/L$ per country
(section 5.4). Equation (10b) gives the unemployment-rate gap, which is
reported but not observed.

### 3.3 Shocks

| Innovation | Enters | Persistence |
|---|---|---|
| $\varepsilon^a$ technology | TFP $x$, eq. (13) | $\rho_a$ |
| $\varepsilon^d$ demand/preference | $d^{shock}$, which shifts the Euler equation (2a) | $\rho_d$ |
| $\varepsilon^r$ monetary policy | Taylor rule (6), i.i.d. | through the smoothing $\rho_r$ |
| $\varepsilon^p$ cost-push | Phillips curve (5), i.i.d. | through indexation |
| $\varepsilon^L$ labour force | $L$, eq. (14) | $\rho_L$ |
| $\varepsilon^{sep}$ separation | $sep$, which lowers employment in (9) | $\rho_{sep}$ |
| $\varepsilon^h$ hours | $h$, eq. (2) | $\rho_h$ |
| $\varepsilon^{inv}$ investment | investment rule (K2), i.i.d. | through $\rho_{inv}$ |

The `varexo` block of the template fixes the shock order (`eps_a`, `eps_r`, `eps_d`, `eps_p`, `eps_L`,
`eps_sep`, `eps_h`, `eps_inv`); nothing downstream indexes shocks by position, Java reads
`shock_indices_java` from `model_info.json` (contract 22). In `shock_params.csv` the `rho` column holds, for
each shock, the persistence parameter of the equation it enters (`rho_r` for `eps_r`, `rho_inv` for `eps_inv`,
0 for `eps_p`); the runtime dynamics come from `policy_A.csv` alone.

### 3.4 Parameters

| Parameter | Role | Status |
|---|---|---|
| $\beta$, $\sigma$, $hab$ | Discount factor, inverse IES, external habit | calibrated |
| $\alpha_n$, $\alpha_k$ | Labour and capital elasticities of output | calibrated |
| $\omega_h$ | Weight of hours in labour input | **estimated** |
| $\phi_{mc}$ | Gap in production (utilisation) and in marginal cost | calibrated |
| $s_{inv}$ | Investment share of demand | calibrated |
| $\lambda_p$, $\iota_p$ | Phillips-curve slope, price indexation | calibrated |
| $\phi_\pi$, $\phi_y$, $\rho_r$ | Taylor rule | calibrated |
| $\alpha_m$, $\eta$, $\kappa$, $\delta$ | Matching elasticity, worker bargaining power, vacancy cost, separation rate | calibrated |
| $\rho_v$, $\phi_{v,y}$ | Vacancy persistence, vacancy response to the gap | calibrated |
| $\lambda_w$ | Share of wages not renegotiated in a quarter | calibrated |
| $\psi_{wL}$ | Direct labour-force effect on the wage | calibrated |
| $\chi_L$, $\chi_u$, $\chi_n$ | Labour-force, unemployment and employment shares of working-age population; $\chi_n = \chi_L - \chi_u$ | calibrated, $\chi_n$ derived |
| $\delta_k$, $\rho_{inv}$, $\phi_{inv,y}$ | Depreciation, investment persistence, accelerator | calibrated |
| $\phi_{inv,r}$ | Cost-of-capital effect on investment | **estimated** |
| $\rho_a$, $\rho_d$, $\rho_L$, $\rho_h$, $\rho_{sep}$ | Persistence of the exogenous processes | calibrated |
| $\sigma_a$, $\sigma_d$, $\sigma_r$, $\sigma_p$, $\sigma_L$, $\sigma_h$, $\sigma_{inv}$ | Shock standard deviations | **estimated** |
| $\sigma_{sep}$ | Separation-shock standard deviation | calibrated |

Calibrated values are in `country_params/{Country}_calibration.mod`, with the source of each value in its
comment; the estimation file also lists, next to each prior that is commented out, why that parameter is
calibrated (not identified, mode at a bound). The estimated set is the same in all five countries. Posterior
modes are in the frozen model, the shock standard deviations also in `shock_params.csv` (section 1.3).

### 3.5 Design choices

- **Staggered wages.** Each quarter only a share $1-\lambda_w$ of wages is renegotiated, at the forward-looking
  reset wage (12a), so the aggregate wage responds sluggishly to productivity and tightness and employment and
  vacancies move more: the mechanism Gertler and Trigari (2009) propose for the volatility puzzle of Shimer
  (2005).
- **Direct labour-force effect on the wage ($\psi_{wL}$).** In the search-and-matching block a change in the
  labour force reaches the wage only through $u \to \theta \to w^* \to w$, and wage stickiness slows the last
  step further. $\psi_{wL}$ gives an immediate response, read as wage drift: entry wages, bonuses and merit
  increases respond to slack outside formal bargaining. It is calibrated with the literature on the wage
  effects of labour-supply shocks in mind (Borjas 2003; Dustmann et al. 2017; see `Germany_calibration.mod`).
  Since the DSGE takes no input from SimPaths, at runtime it acts only on labour-force shocks a scenario sets.
- **Hours are a pure AR(1).** Hours respond to no other variable of the model; only $\varepsilon^h$ moves
  them, and they enter production and, through $mpl$, marginal cost, vacancy posting and bargaining. The DSGE
  has no hours choice; on the micro side SimPaths' household choice sets hours. Since $mpl$ is the marginal
  product of a worker, the bargained $w$ is a wage per worker and rises with hours; the wage per hour is
  $w - h$, which is the cycle SimPaths applies (section 1.1).
- **Calibrated persistence of the labour force and hours.** With $L$ and $h$ observed AR(1) processes,
  $\rho_L$ and $\rho_h$ are collinear with their innovation standard deviations, so the persistence is
  calibrated and the standard deviation estimated. The frozen model and the bundle carry these calibrated
  values (contract 37).
- **Investment accelerator ($\phi_{inv,y}$).** Without it, a negative demand shock lowers $R$ through the
  Taylor rule and investment rises in a downturn. A small calibrated accelerator makes investment co-move with
  demand. It is not estimated because it is collinear with $\rho_{inv}$, which is calibrated for the same
  reason with respect to $\phi_{inv,r}$.
- **Indexation and habits.** $\iota_p$ adds a backward-looking term to the Phillips curve and $hab$ to the
  Euler equation, giving inflation and consumption intrinsic persistence (Smets and Wouters 2003).
- **Unemployment shares.** $\chi_L$ and $\chi_u$ (the sample-mean ILO rate times $\chi_L$) are calibrated and
  $\chi_n$ derived, because $\chi_L$ and $\chi_n$ are two large, similar numbers whose difference amplifies
  rounding (`Poland_calibration.mod`; `test_calibration_identities.m`). $\chi_n$ is total employment, the
  concept of the observable `n`, so the search-and-matching block describes all employment (contract 16).

### 3.6 Observables and estimation

```dynare
varobs y inv c pi R n L h;
```

Eight observables (section 2.5): output, investment, private consumption, inflation, the short-term rate,
persons in employment (`n`), the labour force (`L`) and hours per person employed
(`h`), from `data/data_for_dynare_{Country}.csv`, the datafile named by `@#define datafile` in the country
estimation file. Eight structural shocks plus a measurement error on each observable,
whose standard deviations are calibrated in the estimation file.

The template's estimation setup, the same for every country: `identification(advanced=1, max_dim_cova_group=3)`
(rank tests of Iskrev 2010 and Qu and Tkachenko 2012), then `estimation` with `prefilter=1`, `mode_compute=4`,
`mode_check`, `diffuse_filter`, `lyapunov=doubling`, two Metropolis-Hastings chains of 20,000 draws with the
first half dropped, Bayesian IRFs, the smoother and `moments_varendo`. Priors: beta for $\omega_h$, gamma for
$\phi_{inv,r}$, inverse gamma for the seven shock standard deviations, with country-specific means and standard
deviations in `{Country}_estimation.mod`.

`generate_frozen_model.m` turns the estimate into `Macromodel_{Country}_frozen.mod`: it inlines the wrapper,
the template and the two country files, switches estimation off, and replaces each estimated parameter and
shock standard deviation by its posterior mode (`oo_.posterior_mode`). Every substitution must match exactly
once or the script fails (contract 7). The frozen model is generated, never edited, and is the model the bundle
is exported from.

`postestimation_analysis.m` writes posterior means and 90% HPD intervals, the marginal data density, the
identification results, variance decompositions, IRFs, simulated against observed moments and the output-
inflation correlation to `Macromodel_{Country}/Output/postestimation_summary.txt`,
`Macromodel_{Country}/Output/DSGE_Estimation_Report.pdf` and `Macromodel_{Country}/graphs/Fig*.png`, and a
summary to `output/documentation_data/dsge/dsge_postestimation_{Country}.json`, from which the LaTeX
documentation's tables are rendered.

---

## 4. Shock Units and the Annual Step

One rule for every shock (contract 3):

- A scenario sets innovations in **standard-deviation units**: 1.0 is a one-σ shock, for `eps_L` and `eps_h` as
  for the others. SimPaths sends none.
- `DSGEModel.stepQuarterly` multiplies each by its σ from `shock_params.csv` exactly once, then applies the
  policy matrices: $s_t = A s_{t-1} + B_s\varepsilon_t$, $y_t = C s_{t-1} + D\varepsilon_t$, with $s$ the
  states and $y$ the jumps.
- `policy_Bs.csv` and `policy_D.csv` hold Dynare's raw `ghu` derivatives; no σ is built into them. This
  matches Dynare's impulse responses, $IRF(y,\varepsilon_j,0) = ghu(y,\varepsilon_j)\,\sigma_j$; the exported
  `irfs_eps_*.csv` are one-σ responses, and `DSGEIrfParityTest` and `CommittedBundlesTest` replay them through
  the Java model.
- The labour force and hours follow their AR(1) at the calibrated $\rho_L$, $\rho_h$, carried in `policy_A.csv`
  like every other exogenous process. A shock repeated every quarter accumulates towards $1/(1-\rho)$ times its
  one-quarter effect and can trip the stability bound `mm_dsgeMaxStateDeviation` (default 10, in the model's
  units).
- `model_info.json` declares `deviation_scale = 100`: the model is in 100 × log-deviation units, so the wage
  deviation is a 100 × log deviation, which Java converts to a level factor with $\exp(x/100)$ (section 1.1). The exporter checks the datafile's scale before writing anything, and Java refuses a
  bundle that lacks the key or declares another value (contract 1).

**Scenario files.** `_macroScenario_*.csv` in the bundle folder, named by `mm_dsgeShockScenario`, with columns
`year`, `quarter` and any of the shock names (matched case-insensitively). Missing columns and quarters are
zero, a duplicated quarter is an error, and each row applies in its own quarter only; persistence then works
through the state dynamics. They are written by hand; no exporter writes them.

**Annual step.** In each simulated year, before SimPaths' labour market, `DSGEModel.stepAnnual` runs four
quarterly steps on that year's scenario shocks and returns the mean of the four quarterly values of every state
and jump. The state carries over from year to year and starts at zero (the steady state). The cycle wage is the
annual mean of the wage per hour, `w - h`; the inflation deviation is the annual mean of `pi`.

---

## 5. Implementation

### 5.1 Workflow

`run_full_workflow('{Country}')`, run from `input_processing/macromodel/`:

| Step | Function | Writes |
|---|---|---|
| 0a | `calibrate_growth_model` | calibrated `growth_params_{Country}.json`, placeholder trend files, the in-sample `demographic_P` |
| 0b | `ramsey_trend` | Dynare datafile, trend paths, reference CSV, `ramsey_trend_{country}.mat` |
| 0c | `build_population_projection` | `population_projection_{Country}.csv` (`time,N,P`), post-handoff `demographic_L` and `demographic_P` rows; 0b again if either changed |
| 0d | `ramsey_projection_plot` | diagnostic plot of the forward projection |
| 1 | `dynare Macromodel_{Country} use_dll` | estimation results in `Macromodel_{Country}/Output/` |
| 2 | `generate_frozen_model` | `Macromodel_{Country}_frozen.mod`, `params_{Country}_estimated.txt` |
| 3 | `dynare Macromodel_{Country}_frozen noclearall nograph`, then `export_dynamic_for_simpaths` | the bundle |
| 4 | `postestimation_analysis` | report, figures, documentation summary |

Each step can be skipped by a name-value option. `export_ramsey_for_simpaths('{Country}')` refreshes only the
Ramsey half of a bundle. Toolchains, run times, the smoke test and which re-export a changed input needs are in
`../README.md`.

### 5.2 Dynare files

```
Macromodel_{Country}.mod                        wrapper: @#define country = "{Country}" and @#include the template
  Macromodel_template.mod                       variables, parameters, the model block, varobs, estimation commands
    country_params/{Country}_calibration.mod    parameter values, steady-state labour-market shares
    country_params/{Country}_estimation.mod     datafile, calibrated shock and measurement-error std devs, priors
Macromodel_{Country}_frozen.mod                 generated: all of the above inlined, posterior modes, no estimation
```

Structural changes go into the template, parameter values into the calibration file, priors and the
estimation setup into the estimation file; a new country needs the wrapper and the two country files
(`MULTI_COUNTRY_WORKFLOW.md`). The template, the calibration file and the frozen model are hashed in
`BUNDLE_PROVENANCE.txt`, so any edit to them, a comment included, needs a re-export (contract 18,
`../README.md`).

### 5.3 The bundle (`input/{CC}/MacroModel/`)

| File | Content | Read at runtime |
|---|---|---|
| `policy_A.csv`, `policy_Bs.csv`, `policy_C.csv`, `policy_D.csv` | State transition, shock-to-state, state-to-jump, shock-to-jump matrices; rows and columns named | yes |
| `model_info.json` | Dimensions, state and jump names and indices, `shock_indices_java`, `deviation_scale` | yes |
| `shock_params.csv` | σ and persistence per shock | yes |
| `growth_params_{Country}.json` | Calibrated Ramsey parameters and solver settings | yes |
| `growth_terminal_state.json` | Capital and TFP at the handoff, `handoff_time`, `projection_quarters` | yes |
| `growth_model_reference_{country}.csv` | In-sample trend through the handoff quarter; its last column `P` is the population | yes |
| `population_projection_{Country}.csv` | `time,N,P`: forward persons in employment and resident population from the handoff | yes |
| `hours_projection_{Country}.csv` | `time,h`: forward hours per person employed from the handoff | yes |
| `irfs_eps_*.csv` | One-σ IRFs of `w`, `n`, `pi`, `u_rate`, `y`, `R`, `L`, `h`, `k`, `inv` to `eps_L`, `eps_a`, `eps_d`, `eps_r`, `eps_h`, `eps_inv`, 40 quarters | tests only |
| `policy_full_ghx.csv`, `policy_full_ghu.csv` | Dynare's full decision rules in declaration order | no (reference) |
| `steady_state.csv` | All zeros (linear model) | no |
| `SIMPATHS_INTERFACE.md` | Generated summary of the export | no |
| `BUNDLE_PROVENANCE.txt` | SHA-256 of the tracked inputs and of the bundle files, Dynare and MATLAB versions | tests only (`BundleProvenanceTest`) |
| `_macroScenario_*.csv` | Hand-written scenarios | when named in the config |

The export starts by writing `BUNDLE_NOT_VERIFIED.txt` and ends with `verify_export_bundle`, which removes it
only if every file is present, the reference CSV and the population projection are byte-identical to their
sources in `output/` (a source missing from `output/` is skipped), and the population projection agrees with
`demographic_L` in `N` and with `demographic_P` in `P` (contracts 35, 36, 41). SimPaths refuses a bundle that
carries the marker, and one whose projection or reference CSV lacks `P` (contract 42). Java checks the matrix headers against `model_info.json` on load (contract 8).

### 5.4 Data preparation

`stata/make_datasets.do` (stage 1, Stata) writes `data/data_for_dynare_levels_{Country}.csv` and
`data/PROVENANCE_{Country}.txt`. The levels file holds GDP, private consumption, gross fixed capital
formation, government consumption and net exports (chain-linked volumes), the seasonally adjusted consumer
price index and its quarter-on-quarter annualised inflation $400(\Pi_t/\Pi_{t-1}-1)$ for the price level $\Pi$,
a three-month money-market rate, the real wage per employee (`w_level`, diagnostic only: the national accounts
attach no wage to the self-employed, and no stage reads it), persons in employment (`n_level`), the ILO
unemployment rate, the labour force, hours per person employed per quarter (`h_level`) and the resident
population (`pop_level`).

Persons in employment are employees and self-employed, national concept: Eurostat `namq_10_pe` (`EMP_NC`),
Destatis `ERW060` for Germany and the OECD quarterly national accounts (table 0110, `EMP`) for the UK. Hours per
person employed are total hours worked divided by persons in employment, both domestic concept: Destatis
publishes the ratio directly for Germany (`STD007`); for Poland, Spain and Sweden it is Eurostat
`namq_10_a10_e` over `namq_10_pe`, for the UK OECD table 0111. The script stops if hours per person employed
leave [200, 700] per quarter. It prints the employment identity residual $(L - U - N)/L$ per country: zero for
Germany, whose labour force Destatis defines as persons in employment plus unemployed, about $-3.4\%$ on
average for Spain, whose national-accounts employment exceeds its labour-force-survey employment.

The resident population is in thousand persons, all ages: Eurostat's 1 January figure (`demo_pjan`) for
Poland, Spain and Sweden, Destatis's quarterly national-accounts population (`BEV020`) for Germany and the ONS
mid-year estimate (`UKPOP.A`) for the UK. A census that a source does not carry back puts a step into its
series, and an HP trend would spread the step into a bend the size of true population growth, so the script
splices the breaks before anything smooths the series (`stata/splice_breaks.ado`): it chains the series
backwards from its latest figure with its own growth, replacing the growth into each break period by the mean
of its neighbours' growth, so the levels are on the latest vintage throughout. The break periods are listed in
each country's series block from the source's own break flags: for Poland the 1 January figures of 2010 and
2021, whose growth rates of $-0.30\%$ and $-2.33\%$ become $+0.08\%$ and $-0.27\%$. Destatis and the ONS revise
their series back after each census, and Spain's and Sweden's figures are register-based, so they have none. Every replaced growth rate is written to `PROVENANCE_{Country}.txt`
(`population_source`, `population_breaks`). Annual figures are then placed on their quarter (1 January on q1,
30 June on q3) and interpolated log-linearly. `tests/test_data_loading.m` requires the largest quarterly log
step of `pop_level` to be below 0.01 in every levels file.

The HP-filtered cycles the script also writes
(`data/data_for_dynare_hp_{Country}.csv`) serve only as a benchmark (`diagnostics/run_detrending_benchmark.m`);
the Dynare datafile comes from `ramsey_trend.m`. Series codes per country and the currency conventions are in
`make_datasets.do` and `MULTI_COUNTRY_WORKFLOW.md`.

### 5.5 Frequency

Both layers are quarterly. The Ramsey JSON is annual and converted on load (section 2.1). At runtime a simulated
year is four quarters in both layers: the DSGE returns the mean of four quarterly steps (section 4), and the
planner's `stepYear` the mean of four quarters of its solved path. No other frequency conversion takes place.

---

## 6. References

- Borjas, G.J. (2003). "The Labor Demand Curve Is Downward Sloping." *Quarterly Journal of Economics*, 118(4),
  1335-1374.
- Dustmann, C., Schönberg, U. & Stuhler, J. (2017). "Labor Supply Shocks, Native Wages, and the Adjustment of
  Local Employment." *Quarterly Journal of Economics*, 132(1), 435-483.
- Gertler, M. & Trigari, A. (2009). "Unemployment Fluctuations with Staggered Nash Wage Bargaining." *Journal of
  Political Economy*, 117(1), 38-86.
- Iskrev, N. (2010). "Local Identification in DSGE Models." *Journal of Monetary Economics*, 57(2), 189-202.
- Qu, Z. & Tkachenko, D. (2012). "Identification and Frequency Domain Quasi-Maximum Likelihood Estimation of
  Linearized DSGE Models." *Quantitative Economics*, 3(1), 95-132.
- Shimer, R. (2005). "The Cyclical Behavior of Equilibrium Unemployment and Vacancies." *American Economic
  Review*, 95(1), 25-49.
- Smets, F. & Wouters, R. (2003). "An Estimated Dynamic Stochastic General Equilibrium Model of the Euro Area."
  *Journal of the European Economic Association*, 1(5), 1123-1175.
