# DSGE Integration Plan for SimPaths (Dynamic-Only)

**Document Version:** 4.0  
**Date:** March 2026  
**Status:** Implemented and aligned with current code

---

## 1. Executive Summary

This document describes the current SimPaths macro-coupling architecture.

The macro stack has two orthogonal layers:
- **Ramsey growth model (trend layer):** long-run structural path, top-down only
- **DSGE state-space model (cycle layer):** quarterly cycle dynamics with annual two-way coupling to SimPaths

```
SimPaths population scenario --------> Ramsey trend model (top-down, no feedback)
SimPaths labor shocks (eps_L, eps_h) -> DSGE cycle model (quarterly state-space)
SimPaths receives: delta_w_total = delta_w_cycle + delta_w_trend, delta_pi = delta_pi_cycle
```

### Current design principles

1. Opt-in macro feedback via `mm_macroModel` (default `off`)  
2. Macro model provides trend (Ramsey growth model) and cycle (DSGE) decomposition; the two layers are selected together by `mm_macroModel`: `off | ramsey | dsge | ramsey_dsge`
3. SimPaths wage application uses total wage effect (trend + cycle changes)
4. Rolling labor baseline for DSGE, i.e., DSGE sees wage _changes_ only (DSGE cannot handle arbitrary wage drift)
5. Path recording is completely decoupled from the macro model usage (controlled via `mm_useMacroPathRecorder`, default `true`).
6. Realized labour supply is fed back into the Ramsey re-solve by default, per margin, via `mm_ramseyFeedbackMargins` (default `employment_and_hours`).

---

## 2. Current Architecture

### 2.1 Entry and orchestration

- Main integration orchestration: `simpaths.model.macro.MacroModelManager`
- Simulation manager bridge: `simpaths.model.SimPathsModel`
- Dynamic policy evaluator: `simpaths.model.macro.DSGEModel`
- Micro-to-macro shock aggregation: `simpaths.model.macro.LaborSupplyAggregator`

### 2.2 DSGE files consumed

Under `input/{COUNTRY}/MacroModel/`:

- `policy_A.csv`
- `policy_Bs.csv`
- `policy_C.csv`
- `policy_D.csv`
- `steady_state.csv`
- `shock_params.csv`
- `model_info.json`

Optional scenario/trend inputs:

- DSGE shock scenario CSV (configured via `mm_dsgeShockScenario`)
- Ramsey files (`growth_params_*.json`, `growth_terminal_state.json`, `growth_model_reference_*.csv`, optional Ramsey scenario CSV)
- Optional population bridge: `population_projection_[COUNTRY].csv` (overrides forward `N` path with SimPaths-consistent demographics)

### 2.3 Ramsey growth input contract

The Ramsey trend layer reads country-specific growth inputs from `growth_params_*.json` together with
`growth_terminal_state.json` and `growth_model_reference_*.csv`.

For TFP growth, the runtime supports two baseline contracts:

- Legacy contract: `tfp_growth_annual` only. In this case SimPaths uses a constant baseline TFP growth rate.
- Current contract: `tfp_growth_annual` plus an optional `terminal_growth` object. When present and enabled,
	SimPaths treats `tfp_growth_annual` as the in-sample calibration growth rate and lets it converge quarter by
	quarter toward `terminal_growth.g_A_terminal_annual` using `terminal_growth.rho_quarterly`.

Example:

```json
"terminal_growth": {
	"enabled": true,
	"g_A_terminal_annual": 0.008,
	"rho_quarterly": 0.99
}
```

This behaviour is backward compatible: if the `terminal_growth` block is absent, SimPaths falls back to the
legacy constant-growth interpretation.

---

## 3. Coupling Contract

### 3.1 SimPaths -> DSGE inputs

- `epsilon_L`: labor-force/positive-hours shock (raw log-deviation)
- `epsilon_h`: hours shock (raw log-deviation)

Both are computed by `LaborSupplyAggregator` as log deviations from baseline.

### 3.2 DSGE -> SimPaths outputs

- `delta_w_cycle`: cyclical wage deviation (%) from DSGE annual aggregation
- `delta_w_trend`: secular wage trend (%) from Ramsey projection
- `delta_w_total = delta_w_cycle + delta_w_trend`
- `delta_pi`: inflation deviation (%) (cycle component)

In SimPaths wage equations, macro feedback is applied as:

`wageMultiplier = 1 + (delta_w_total / 100)`

---

## 4. Yearly Runtime Flow (Dynamic-Only)

1. Aggregate current labor outcomes in SimPaths
2. Advance Ramsey trend by one year (deterministic top-down trend)
3. Build `epsilon_L` and `epsilon_h` relative to baseline
4. Advance DSGE quarterly state internally and aggregate annual cycle feedback
5. Compose total wage effect (`cycle + trend`) and apply macro feedback
6. Advance rolling baseline for next year

No static equilibrium iteration is performed.

---

## 5. Shock Conventions (Critical)

Dynare-exported policy matrices (`Bs`, `D`) contain raw `ghu` derivatives.  
Therefore input handling must be:

- `epsilon_L`, `epsilon_h` from SimPaths: raw log-deviations, no scaling
- Other scenario shocks (`eps_a`, `eps_r`, `eps_d`, `eps_p`, `eps_sep`, `eps_inv`): interpreted as sigma-units and converted to raw innovations by multiplying by sigma

Formula for non-`epsilon_L/epsilon_h` shocks:

`rawInnovation_j = shockInSigmaUnits_j * sigma_j`

This matches Dynare:

`IRF(y, eps_j, t=0) = ghu(y, eps_j) * sigma_j`

---

## 6. Configuration Surface (Current)

### 6.1 Supported macro switches

All under `model_args`:

- `mm_macroModel` (`off | ramsey | dsge | ramsey_dsge`, default `off`; which layers run. `dsge`
  alone is diagnostic: the cycle was estimated on Ramsey-detrended observables, so without the
  trend layer it deviates around SimPaths' own wage trend instead)
- `mm_useMacroPathRecorder` (boolean, default `true`; records path regardless of `mm_macroModel`)
- `mm_dsgeShockScenario` (string; ignored unless `mm_macroModel` runs the DSGE)
- `mm_ramseyScenario` (string; ignored unless `mm_macroModel` runs the Ramsey layer)
- `mm_dsgeMaxStateDeviation` (double, default `10.0`; DSGE stability bound in log-deviation units)
- `mm_macroLogging` (`off | state | verbose`, default `off`; `verbose` implies `state`)
- `mm_ramseyFeedbackMargins` (`none | employment | hours | employment_and_hours`, default
  `employment_and_hours`; which realized margins enter the yearly Ramsey re-solve — see §8.1.
  Inert without the Ramsey layer)
- `mm_ramseyFeedbackPersistence` (double, default `1.0`; persistence of the realized employment gap in the feedback belief, range `[0,1]` — see §8.1)
- `mm_ramseyFeedbackHoursPersistence` (double, default `1.0`; persistence of the realized hours gap, range `[0,1]`)

Unquoted `off` is a YAML 1.1 boolean, so SnakeYAML delivers `Boolean.FALSE`; the enum parser
maps it to the disabled constant, which is why `mm_macroModel: off` works without quotes.

### 6.2 Removed legacy switches

The following are removed from active code/config:

- `mm_staticIntegration`
- `mm_maxIterations`
- `mm_convergenceTolerance`
- `mm_shockRelaxation`
- `mm_dampingFactor`
- `mm_capitalShareAlphaK`
- `mm_capitalPartialAdjustment`

---

## 7. Baseline Strategy

### 7.1 Rolling baseline

Shocks are always year-over-year:

- `epsilon_L,t = ln(L_t / L_{t-1})`
- `epsilon_h,t = ln(h_t / h_{t-1})`

This keeps shocks in the local-linear range and avoids secular drift overwhelming the DSGE approximation.

### 7.2 Anchor-year asymmetry: L/N lag the demographic indices by one year

The recorded level indices do **not** all share the same base year, and `l_level`
(and `n_ramsey`) are exactly zero for the first **two** recorded years, not one.
This is by design, not a bug, and consumers (plots, `compare_scenarios.do`) must
account for it.

Cause — two latches at different schedule phases:

- **Demographic anchors** (`startTotalPop`, `startWAP`, `startAtRisk`) are latched
  *eagerly, pre-labour-market, in the first simulation year* (`latchDemographicAnchors`).
  They are labour-market-invariant head counts, so this is safe and makes
  `total_population` / `wap_level` / `atrisk_level` correct from year 1
  (start year = 0, first real move in year 2).
- **L/h anchors** (`startL`, `startH`) are deliberately latched *post-labour-market*,
  and only in the **second** simulation year (`latchBaselineFromPostLaborMarket`),
  because `L_0`/`h_0` must use SimPaths' model-assigned hours, not the input-DB
  hours present before the first labour-market update. This is the same
  correctness constraint that protects `eps_L` and the MATLAB↔Java
  `growth_model_reference` parity, so it must not be moved earlier.

Because the recorder samples at the pre-labour-market macro event, the year-2
sample is taken before `startL` is set that tick, so `l_level` is skipped (0) in
years 1 and 2; the first non-zero `l_level` is year 3. Net effect for a
2023-start run:

- `Pop`/`WAP`/`atRisk` are indexed to **2023** (first move 2024).
- `L`/`N` are indexed to **2024** (first non-zero 2025); 2023 and 2024 are both
  exactly 0.

Implications:

- The "% from first year" axis means a *different base year* for the two groups;
  do not read the 2024 `l_level=0` as "labour supply did not respond" — it is a
  placeholder before L's baseline exists.
- In `compare_scenarios.do` the macro-impact panel is a scenario−baseline
  *difference*, so the lag cancels provided both arms use identical code and
  seed (the standard requirement); the asymmetry only matters for level plots.
- If this ever needs to change, re-sampling L for the recorder after the
  labour market is parity-sensitive (eps_L, cumulative trend,
  `growth_model_reference`) and requires full parity re-validation.

---

## 8. Trend Handling

- Preferred path: Ramsey trend via `mm_macroModel: ramsey`
- If `growth_params_*.json` contains `terminal_growth.enabled=true`, the forward Ramsey baseline no longer assumes
	permanently constant TFP growth. Instead, annual TFP growth converges from the calibrated in-sample rate
	(`tfp_growth_annual`) toward the long-run anchor (`g_A_terminal_annual`) at the quarterly persistence
	`rho_quarterly`.
- The terminal balanced-growth-path target in Java is computed from the terminal TFP growth anchor, not from a
	zero-growth shortcut. This keeps SimPaths aligned with the MATLAB export contract used to generate the Ramsey
	inputs.
- The Ramsey trend output varies depending on whether it was calibrated with exogenous or endogenous labour supply in the macro repository. For endogenous labour supply, adjustments are sensitive to the flexible/time-varying disutility parameter `psi`.
- If Ramsey trend is unavailable, secular wage trend fallback is currently `0` (no reduced-form alpha/gamma fallback)
- Information flow is strictly top-down for trend, unless `mm_ramseyFeedbackMargins` is not `none`: by default SimPaths does not feed back into Ramsey path construction

### 8.1 Recursive trend feedback (extended path)

With `mm_ramseyFeedbackMargins` set to a margin, SimPaths' realized labour supply is fed back into the
Ramsey trend once per simulated year, using the standard extended-path convention (re-solve the
remaining horizon from the predetermined capital state each time new information arrives).

**Yearly mechanism.** At `MacroEndYearCapture` — after mortality and population alignment, the
only point in the year where employment is final — realized labour force
`L_sim,t` is aggregated by `LaborSupplyAggregator.computeRawAggregates`. In the first year with a
post-labour-market observation (`startYear + 1`; the labour market does not run in `startYear`), a
level factor `lambda = meanN_assumed / L_sim` is latched once and no re-solve happens that year
(`delta ≡ 1` by construction) — this mirrors the `startL` latch timing described in §7.2. In every
later year, `delta_t = lambda * L_sim,t / meanN_assumed(t)`, where `meanN_assumed(t)` is always
read from the *original* projection retained at startup, not from any previously revised path —
this is what prevents re-solve errors from compounding across years. The remaining-horizon labour
path is then rebuilt from the original projection with quarter `j` scaled by
`1 + (delta_t - 1) * rho^floor(j/4)` (`rho = mm_ramseyFeedbackPersistence`), and the model is
re-solved from `K` and `A` at the start of year `t` (predetermined, never revised), re-anchored to
the same scenario and TFP convergence phase so the terminal balanced-growth-path target keeps
converging instead of restarting. One `stepYear()` then consumes the realized year, leaving the
solved path positioned at `t + 1`.

**One-period-stale wages.** The wage SimPaths used for year `t` was set by `advanceRamseyTrend()`
*before* this feedback step runs — it reflects the path as solved at the end of year `t-1`, not
year `t`'s own realized labour. Only `advanceRamseyTrend()` for year `t+1` steps into the revised
path. This one-period lag is the standard extended-path convention, not a defect to be closed.

**Mutual exclusions.** The feedback requires an exogenous-labour Ramsey bundle, and is fatal
(rather than silently self-disabling) if the Ramsey trend fails to solve. The endogenous-labour FOC
bundle already approximates the realized labour response ex ante, so combining it with this
channel's own realized-employment revision would count that response twice.

A DSGE mode was also fatal until 2026-08-18; it now only warns. The two channels do not
measure the same object: `eps_L` is a *year-over-year* log change against a rolling baseline
(`LaborSupplyAggregator.advanceBaseline`), while `delta_t` is a *cumulative level* ratio against the
fixed original projection. A permanent labour-supply shift therefore gives `eps_L` once and zero
thereafter, the DSGE response decays back to the trend (the DSGE steady state *is* the Ramsey path),
and only the Ramsey revision persists — the overlap is a transitional overshoot while the cycle
decays, not a permanent double count. Its size is bounded by the measured loop gain of about -0.04,
i.e. a few percent of the labour response. What does remain is a different problem: at `rho=1` the
planner extrapolates *every* realized deviation as permanent, and with the DSGE on part of that
deviation is cyclical by construction. Prefer `rho < 1` when running both, and note that the
combination has not yet been measured end to end.

**Hours feedback (`mm_ramseyFeedbackHours`, added 2026-08-18).** On by default since 2026-08-19; it
was off in the four arms behind the recursive-feedback note, which therefore report a heads-only
loop. Heads-only feedback shows the planner `delta_n` while the labour input is `N*h`, so it gets
the capital-dilution response wrong whenever the two margins move in opposite directions. When on, realized
mean hours per worker are fed back alongside headcount, with their own persistence
`mm_ramseyFeedbackHoursPersistence`. The Ramsey labour input is `N*h` (`RamseyTrendModel` line
~1060), so an x% hours gap dilutes capital exactly as an x% headcount gap does. Diagnostic column:
`h_realized_gap`.

**The two gaps use different references, and this is the subtle part.** `delta_n` is measured
against the planner's projected `N`, which is legitimate only because `extDemographic` is
overwritten at startup with the same population projection SimPaths aligns to — realized and
projected employment are then comparable and `delta_n` isolates genuine labour-market surprises.
No equivalent reconciliation exists for hours. `projH` (since 2026-08-18 read from
`hours_projection_*.csv` rather than extrapolated locally) is a log-linear trend fitted to observed
hours (`hours_trend_method` in the growth params; for PL, -0.203%/yr, and the `h` column of
`growth_model_reference_poland.csv` is a pure exponential at that one rate, not a data series).
SimPaths models no hours trend at all, so measuring `delta_h` against `projH` would compare two
different modelling assumptions: by 2060 the planner assumes hours 7.0% below their 2024 level
while SimPaths delivers 1.3% above, i.e. a spurious `delta_h` near +9% that grows monotonically
instead of mean-reverting, worth roughly -2.5% of the trend wage at `rho_h=1`.

`delta_h` is therefore measured against **SimPaths' own latch-year hours** (`ramseyFeedbackHoursBase`),
not against `projH`: the planner keeps its fitted trend as a maintained assumption and SimPaths
feeds back only its own hours movements on top of it. Flat SimPaths hours give `delta_h = 1` and no
revision, which is correct, because SimPaths carries no information about the hours trend. Pinned by
`RamseyRecursiveFeedbackTest.testFlatSimPathsHoursLeaveTheDecliningProjectionAlone`, which also
asserts the fixture's hours projection really does decline so the test cannot go vacuous. Revisit
the reference if SimPaths ever gains an exogenous hours projection, e.g. an hours alignment.

**Handoff contract (2026-08-18).** The forward hours path is no longer derived on both sides. MATLAB
writes `hours_projection_{COUNTRY}.csv` (single writer `internal/write_hours_projection.m`, called by
both export paths, listed in `verify_export_bundle.m`) and `MacroModelManager.loadProjectedHours`
reads it, failing loudly if it is absent — no local fallback, because the fallback is what allowed
the two sides to use different trailing-growth windows unnoticed. The terminal tail is still built
independently on both sides; its windows are pinned by `RamseyTrendModel.TAIL_DEMOGRAPHIC_WINDOW` /
`TAIL_HOURS_WINDOW` and the tripwire in `MacroModelManagerTest`.

**Open defect, separable from the feedback channel.** `RamseyTrendModel.solveForPath` extends hours
into the 600-quarter terminal tail with `extendExogenous(h, totalQ, TAIL_HOURS_WINDOW)`, undamped, so the fitted
-0.2%/yr decline runs for another 150 years and hours reach ~68.6% of their 2024 level (~26h/week).
Demographics get `applySmoothTerminalDemographicClosure`, which tapers the growth rate to zero so
the path converges to a constant; hours get no such treatment. The terminal condition
`K/(kyBgp*Y) = 1` is a balanced-growth relation, and on a BGP hours per worker must be constant.
Fixing this needs MATLAB and Java changed together (MATLAB uses `extend_level_path(..., 1)`, so the
two currently agree) and moves the baseline trend, hence a pipeline re-run.

**Persistence (`rho`) semantics.** `rho` is the assumed persistence of a realized employment
surprise, applied as a per-year geometric decay on the tail: `rho=1` treats the whole gap as
permanent (a random-walk belief in the surprise), `rho=0` replaces only the realized year and
leaves every future quarter at the originally assumed path. **`rho=0` is a near-zero-feedback
setting by construction, not a "weak feedback" setting**: with only the current year replaced, the
planner still expects labour to revert next period, so the announced wage for `t+1` is essentially
the marginal product of labour at *assumed* labour, and a persistent labour-supply shift never
produces the capital-dilution wage response the channel exists to deliver. Measured on this
branch, a +2% persistent employment surprise revises the next year's trend wage by **-0.5612%**
under `rho=1` (capital dilution, of the order `alpha * 2%`) versus **-0.0102%** under `rho=0` —
i.e. `rho=0` delivers essentially no feedback. This is why the default is `rho=1.0`; `rho=0` is
kept available only as a demonstration/comparison arm (`config/ramsey-feedback-transitory.yml`),
not as a milder version of the feature.

**Diagnostics.** Two columns are appended to all four quarterly rows of year `t` in
`MacroPaths.csv`:
`n_realized_gap` — `(delta_t - 1) * 100`, the realized employment gap in percent — and
`w_trend_revision` — the percent change in the year-`t+1` trend wage caused by the re-solve. Both
default to `0` for any year with no re-solve: the latch year (`n_realized_gap` is legitimately `0`
there, since `delta ≡ 1`; `w_trend_revision` is `0` because no re-solve happens to produce a
revision) and every year of a run where the feedback is disabled.

**`n_ramsey` changes meaning under feedback.** `advanceRamseyTrend` derives the `n_ramsey` column
(§7.2) from the *currently solved* trend's `ts.labor()`, so once a re-solve has happened,
`n_ramsey` tracks the fed-back, revised labour path — not the population-projection-based path
`n_ramsey` represents when the feedback is off. Analysts comparing `n_ramsey` across arms of an
experiment should treat the off arm's `n_ramsey` as the assumed path and `n_realized_gap` (not the
persistent/transitory arm's own `n_ramsey`) as the measure of how far the feedback run departed
from it.

**v1 limitations.** Only labour is fed back; the hours path (`pathH`) stays on its original
extrapolation. There is no NAIRU wedge — realized employment is fed back directly, with an
exogenous non-accelerating-wage-rate-of-unemployment adjustment left as a possible later
extension. `ramseyBaseline` (the quarter-0 anchor used for all `advanceRamseyTrend` percentage
trends) is never re-latched by this channel.

---

## 9. Outputs and Diagnostics

### 9.1 Path export

Dynamic DSGE paths export to:

- `output/{run_id}/csv/MacroPaths.csv`

### 9.2 Logging

- Year-level macro logging: `mm_macroLogging: state`
- Additional diagnostics: `mm_macroLogging: verbose`

---

## 10. Code Map (Current)

### 10.1 Main classes

`src/main/java/simpaths/model/macro/`

- `MacroModelManager.java`
- `DSGEModel.java`
- `DSGEState.java`
- `LaborSupplyAggregator.java`
- `MacroPathRecorder.java`
- `DSGEShockScenario.java`
- `RamseyTrendModel.java`
- `RamseyScenario.java`

### 10.2 Tests (current DSGE set)

`src/test/java/simpaths/model/macro/`

- `DSGEModelTest.java`
- `DSGEIntegrationTest.java`
- `DSGEModelManagerTest.java`
- `LaborSupplyAggregatorTest.java`
- `DSGEShockScenarioTest.java`

---

## 11. Migration Notes

This document supersedes older plan text that described static equilibrium components and static-only test classes. Those references are historical and intentionally removed here to match the current implementation.

If historical rationale is needed, consult repository history and archived notes under `.misc/`.

---

## 12. References

- Macro model technical documentation: `WELLSIM_SVEC/macromodel/.docs/Technical_Documentation_Macromodel_17.md`
- SimPaths project guidance: `.github/copilot-instructions.md`
- SimPaths architecture notes: `CLAUDE.md`
