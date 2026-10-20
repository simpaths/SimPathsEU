# Integration Contracts

Every serious defect found in the 2026-08 audit had the same shape: **two components
that must agree, agreeing by assumption, with nothing that fails when they diverge.**
Not one was caused by too much code or too little documentation. Each was an
unenforced contract.

This file inventories those contracts and records, for each, what enforces it. A
contract with no enforcement is a defect waiting to happen — the FOC disagreement
(contracts 5 and 6, since retired) ran for three months while every run reported success.

## The rule

> When two components must agree, the agreement is a contract. Write down what it
> is, and make something fail loudly when it breaks. A comment saying "must stay
> aligned with X" is not enforcement.

Three enforcement patterns cover almost everything here:

- **Round-trip** — when one operation inverts another, compose them and assert
  identity. Catches drift between any number of sites at once.
- **Shared fixture** — when the same computation exists in two runtimes, generate a
  table of inputs/outputs from one and assert it from both.
- **Declared, not duplicated** — when both sides need a constant, have the producer
  write it into the artifact and the consumer read it, instead of each holding a copy.

## Inventory

| # | Contract | Between | Enforced by | Status |
|---|---|---|---|---|
| 1 | `eps_L`/`eps_h` are PERCENT log-deviations (100·ln) | SimPaths boundary ↔ DSGE estimation units | `LaborSupplyAggregatorTest`; `PERCENT_PER_LOG_DEV` constant | enforced |
| 2 | π is read from whichever vector declares it | exporter `model_info.json` ↔ `DSGEState.VarIndices` | throws if neither map declares `pi`; `DSGEStateTest` | enforced |
| 3 | Non-`eps_L/h` shocks are σ-scaled exactly once | scenario CSVs ↔ `stepQuarterly` | `DSGEShockScenarioTest`, `DSGEModelTest` | enforced |
| 4 | χ_u = χ_L − χ_n, and the implied U/L rate matches the estimation sample | calibration ↔ template eq. 10 ↔ data | `test_calibration_identities.m` (identity **and** sample rate) | enforced |
| 5 | Intratemporal FOC and ψ backout are exact inverses | the FOC solver ↔ its ψ back-out (MATLAB) | — | retired 2026-10-20 with the endogenous-labour variant (JuergenWiemers/SimPathsEU#28); number kept |
| 6 | MATLAB and Java solve the same FOC | the MATLAB FOC solver ↔ its Java mirror | — | retired 2026-10-20 with the endogenous-labour variant (JuergenWiemers/SimPathsEU#28); number kept |
| 7 | Frozen-model substitutions actually matched | template text ↔ `generate_frozen_model.m` patterns | `subst_verified` (match count), `test_frozen_model_generator.m` | enforced |
| 8 | Export bundle layout matches its own `model_info.json` | `export_dynamic_for_simpaths.m` ↔ `DSGEModel` loaders | row/column name validation on load; `DSGEIntegrationTest` | enforced |
| 9 | Forward horizon is the same on both sides | `ramsey_trend.m` `projection_quarters` ↔ `MacroModelManager` | exported in `growth_terminal_state.json`, read by Java | enforced |
| 10 | Handoff quarter matches the simulation start year | `growth_terminal_state.json` ↔ `simulationStartYear` | `validateRamseyHandoffTime` throws | enforced |
| 11 | The population projection belongs to this bundle's country | bundle ↔ `MacroModelManager` | country-tagged filename required, no fallback | enforced |
| 12 | `data_for_dynare_{C}.csv` has exactly one writer | `make_datasets.do` ↔ `ramsey_trend.m` | Stata export removed; single owner | enforced by construction |
| 13 | K₀/A₀ are anchored at the first data row | growth params `base_year` ↔ data file start | assert in `ramsey_trend.m` | enforced |
| 14 | LBJ Jacobian bandwidth kl=ku=1 is valid | residual structure ↔ banded solver | runtime off-band probe, throws | enforced |
| 15 | Exported ψ describes the exported path | ψ fixed point ↔ `growth_terminal_state.json` | exports the solved-at ψ; warns with residual | enforced |
| 16 | `n` and the planner's `N` are employees; χ_n is total employment, and SimPaths' `L_sim` counts all workers | DSGE observable ↔ calibration; Ramsey `N` ↔ `L_sim` through the feedback's `lambda` | **documented assumption only**: self-employment moves proportionally with employees | ⚠ unenforced |
| 17 | Scenario shocks are applied from the year they declare | scenario CSV ↔ `updateEquilibrium` | `MacroModelManagerTest.testScenarioShocksApplyInBaselinePendingYears` | enforced |
| 18 | Committed bundle is built from the tracked inputs beside it | `input_processing/macromodel/` inputs and the bundle's own files ↔ `input/{CC}/MacroModel/BUNDLE_PROVENANCE.txt` | exporter writes SHA-256 per input (`write_bundle_provenance`); `BundleProvenanceTest` recomputes them in CI; exporter writes into `input/` directly, no copy step; the Ramsey-only export carries the DSGE-half input lines forward from the previous file | enforced |
| 19 | MATLAB↔Java exogenous parity is machine-precision | `ramsey_trend.m` ↔ `RamseyTrendModel` | `RELATIVE_TOLERANCE = 1e-9` (measured worst 4.4e-11) | enforced |
| 20 | Reference-CSV `l` is participation, not the labour-force level | exporter column naming ↔ `loadReferenceCSV` | case-sensitive header match | enforced |
| 21 | Macro CSVs are merged by DATE, never by row position | `population_projection_*.csv`, `growth_model_reference_*.csv` ↔ the forward splice | splice locates the handoff quarter; reference terminal row verified against `handoff_time`; `MacroModelManagerTest` alignment tests | enforced |
| 22 | The documented shock order is the `varexo` declaration order | `Macromodel_template.mod` ↔ the tex ↔ the exporter header | `\DsgeShockOrder` generated from the varexo block; an unlabelled new shock fails the docs refresh | enforced |
| 23 | Every JSON reader in the macro package parses the same way | `DSGEModel` ↔ `RamseyTrendModel` ↔ `MacroModelManager` ↔ both MATLAB writers | one `MacroJson`; `MacroJsonTest` asserts compact and pretty-printed input read identically | enforced |
| 24 | A JSON artefact Java reads is never partially written | MATLAB writers ↔ Java string-scan readers | `write_text_atomic` (temp file + re-decode before move) | enforced |
| 25 | Scenario CSVs reject non-finite values and keep trailing fields | `RamseyScenario` ↔ `DSGEShockScenario` | one `MacroCsv`; `ScenarioLoaderParityTest` | enforced |
| 26 | The alignment diagnostic counts the population the alignment used | `ActivityAlignmentV2.matchesSubgroup` ↔ `AlignmentAdjustmentFactors.classifyBenefitUnit` | one `BenefitUnitSubgroup` | enforced by construction |
| 27 | `growth_terminal_state.json` has exactly one writer | `export_dynamic_for_simpaths.m` ↔ `export_ramsey_for_simpaths.m` | both call `write_growth_terminal_state.m` | enforced by construction |
| 28 | The forward FOC/HP smoother exists once per runtime | `calibrate_growth_model.m` ↔ `ramsey_trend.m` | `hp_filter_trend.m` is the single implementation | enforced by construction |
| 29 | Sibling macro scenario configs differ only in their declared treatment | `config/phi-*.yml`, `config/batch-*.yml` | `MacroScenarioConfigTest` — any undeclared difference fails, including keys the test does not enumerate | enforced |
| 30 | Macro scenario configs run on a stock SimPaths build | `config/*.yml` ↔ `SimPathsMultiRun`'s reflective loader | `MacroScenarioConfigTest` rejects any top-level key that is not a `SimPathsMultiRun` field or a known argument map | enforced |
| 31 | Every artefact is written where its readers look for it | writers ↔ readers across `data/`, `output/`, `logs/`, `figures/` | paths built by `internal/artifact_path.m`; `tests/test_artifact_layout.m` fails on any pipeline artefact left in the model root | enforced |
| 32 | The pipeline runs from the model root | every pwd-relative path ↔ Dynare's `pwd`-bound output and `datafile` | `artifact_path` asserts the root and names the folder you are actually in | enforced |
| 33 | The frozen posterior belongs to the committed data vintage | `data/data_for_dynare_{C}.csv` ↔ `Macromodel_{C}_frozen.mod` ↔ `input/{CC}/MacroModel/` | all three tracked; a dirty `data/data_for_dynare_levels_{C}.csv` or `data/PROVENANCE_{C}.txt` after a run means the vintage moved and the downstream artefacts must move with it, while a dirty `data/data_for_dynare_{C}.csv` alone may be floating-point solver noise from another machine | ⚠ partial (visible, not blocked) |
| 34 | No file assigns a variable named like one of our functions | any `.m` ↔ the function files we own | `tests/test_name_collisions.m` | enforced |
| 35 | The export bundle is complete and one vintage | the bundle's Ramsey half ↔ its DSGE half ↔ `output/` | `verify_export_bundle` at the end of both exporters: every file present, and each copied Ramsey artefact byte-identical to its `output/` source | enforced |
| 36 | A refused bundle says so inside the bundle | `verify_export_bundle`'s verdict ↔ whoever commits or runs SimPaths on `input/{CC}/MacroModel/` later | `BUNDLE_NOT_VERIFIED.txt`, written by both exporters before their first file, by `calibrate_growth_model` and `ramsey_trend` before they rewrite the bundle's growth-params JSON, and removed only by a passing verification (`mark_bundle_unverified.m`, `test_export_bundle_marker.m`); `MacroModelManager.initialize` refuses a bundle that carries it (`MacroModelManagerTest.testBundleWithNotVerifiedMarkerIsRefused`) | enforced |
| 37 | The frozen model records the persistence it was estimated with | `{Country}_calibration.mod` `rho_L`/`rho_h` ↔ the estimation-mode branch of `Macromodel_{C}_frozen.mod` | `read_calibrated_value` in `generate_frozen_model.m`; `test_frozen_model_generator.m` compares every tracked frozen model with its calibration | enforced |
| 38 | `eps_L` is the labour force net of the projection it was estimated against, and the first pre-labour-market snapshot after the post-labour-market latch is not a shock | `ramsey_trend.m` (`detrended.L` against `L_demo`) ↔ `MacroModelManager.projectedLaborGrowthPct` ↔ `LaborSupplyAggregator.aggregate` | `LaborShockProjectionTest` (a workforce following the projection gives the DSGE a zero shock, end to end through `updateEquilibrium`; `mm_macroModel: dsge` loads the projection too), `LaborSupplyAggregatorTest` (the snapshot roll) | enforced |

## Open items

**#16 — the `n` definition.** The unemployment identity needs N = total employment,
but the observable feeding `n` is employees excluding self-employed (Poland: 0.541 of
WAP vs 0.677). Using the total-employment share for χ_n assumes self-employment moves
proportionally with employees. In Poland self-employment is 20% of employment, so this
is load-bearing. There is no natural check because the assumption is about what the
data *means*, not about two numbers agreeing — the honest enforcement is that it stays
written down where the calibration is.

The Ramsey feedback rests on the same assumption. The planner's `N` is employees, while
SimPaths' `L_sim` counts all workers with positive hours, employees and self-employed
alike, because SimPaths carries no status in employment. The level factor `lambda`,
latched once in `startYear+1`, therefore holds the employee share of workers at its
latch-year value for the rest of the run: `n_realized_gap` includes any shift in that
share, and the planner prices it like any other employment surprise. Accepted and
written down in `SimPaths_Coupling.md` §8.1 ("Employees versus all workers"). Removing
it needs a projected employee-share path in the bundle or a status-in-employment
variable in SimPaths.

**#33 — the data vintage.** `input_processing/macromodel/data/` is tracked, so the estimation input is
versioned alongside the frozen posterior and the export bundle it produced. Nothing
*blocks* committing a new data vintage without regenerating them, though: the
enforcement is that `git status` shows the CSVs dirty after a run, and
`data/PROVENANCE_{C}.txt` records which vintage a commit holds. Contract #18 now
catches two cases: a regenerated `data/data_for_dynare_{C}.csv` or a changed
`data/data_for_dynare_levels_{C}.csv` committed without a re-export turns
`BundleProvenanceTest` red. It does not notice a new vintage that was re-exported
without re-estimating the frozen model. Closing it properly would mean stamping the
vintage into `growth_terminal_state.json` and having the export refuse to run against
a different one — worth doing if the data starts moving often.

## What the maintainability pass found

The 2026-08 audit's §9 listed sixteen duplications as "none of these change results
today". Working through them, two did:

**`growth_terminal_state.json` had two writers, and the second omitted
`projection_quarters`.** Java falls back to the legacy 320-quarter horizon when the
key is absent. So the documented "Refresh Ramsey Files Only For SimPaths" recipe in
`input_processing/macromodel/README.md` produced a bundle that reopened contract #9 — the run continued on
a different forward horizon than the trend was solved over, with a log warning as
the only signal. Contract #27 closes it.

**The macro package's three JSON parsers disagreed about whitespace after the
colon.** `RamseyTrendModel` skipped it; `DSGEModel` and `MacroModelManager` matched
the literal `"key":` and returned their default otherwise. The two MATLAB writers
disagree the same way — `jsonencode(..., 'PrettyPrint', true)` emits a space, the
exporter's own pretty-printer does not. Each reader was therefore locked to whichever
writer it grew up against, and a change of writer would have zeroed a parameter with
nothing failing. Contract #23 closes it, and the test was verified reproducing the
failure: with the literal-colon behaviour restored, `"tol": 1.0E-10` reads as `0.0`.

That is the same shape as everything in the table above, and it is the argument for
treating "harmless duplication" as unenforced-contract debt rather than style.

## Where the macro layer stops

Not every duplication in the SimPaths repository is the macro layer's to fix. The
`validation/` do-files and the `config/alignment_*.yml` ladder belong to the SimPaths
head maintainers; the macro work stays inside `src/main/java/simpaths/model/macro`
(plus its test mirror) and the macro scenario configs.

A first attempt at contract #29 added an `extends:` mechanism to `SimPathsMultiRun`.
It was reverted, and the reason generalises. The upstream config loader reflects each
top-level key onto a field and, on `NoSuchFieldException`, prints a stack trace and
**continues** — so an unrecognised key does not stop a run, it silently drops whatever
it carried. A config using `extends:` would therefore run on a stock build with only
its own override line: no seed, no horizon, no alignment switches, no error. Sharing a
config file would have shipped that.

The rule this leaves: **a macro artefact must remain readable by an unmodified
SimPaths build.** Enforcement belongs in a test, not in a change to the shared
runtime. Contract #30 is that rule made into a check.

## Consequences of closing #17

Scenario shocks now land in the year they declare, including the first two
simulation years. Two things follow.

**Existing scenario results change.** Any run whose scenario declared shocks in
`startYear` or `startYear+1` was previously losing them. The shipped
`_macroScenario_energy_shock_1_5sd_60_quarters.csv` starts 2023q1 against a 2023
start year, so it was losing its eight largest quarters and beginning in 2025 at
already-decayed magnitude. Comparisons drawn from those runs understate and
phase-shift the treatment.

**Some scenarios may now hit the stability bound.** That same 1.5σ/60-quarter
energy shock, applied from the start year as declared, drives the DSGE state past
the default ±10 bound and throws. That is the guard doing its job — the shock really
is that large once it is not silently truncated — but it means a scenario that
"worked" before may now need `mm_maxBounds` raised or its magnitude reconsidered.
Failing loudly is the point; the previous silence was the defect.

**MATLAB-only parameters.** `inflation_target.pi_star_annual` is read by
`ramsey_trend.m` when building the inflation trend, but has no Java reader. Editing
it in a *deployed bundle* therefore does nothing; editing it in the source JSON and
re-running the workflow does. `var_indices_java` was genuinely unread and is no
longer exported.

## The start-year footgun

Changing a simulation's start year requires re-running the MATLAB workflow with the
matching handoff date. Before 2026-08 forgetting that produced a silently wrong run,
and `validateRamseyHandoffTime` only half-covered it: it checked a *scalar* in
`growth_terminal_state.json` against the start year, which says nothing about whether
the CSVs were regenerated for the same quarter.

The CSVs were merged **positionally**. `growth_model_reference_*.csv` and
`population_projection_*.csv` both carry a `time` column; both were consumed by row
index. The splice assumed row 0 of the projection was the handoff quarter and that
the last reference row was too. Regenerate one artifact and not the other and the
whole demographic path shifts, with every check still passing.

Both merges now align on the date and fail loudly when they cannot:

- the splice **finds** the handoff quarter in the projection instead of assuming row
  0 — so a projection that legitimately starts earlier now works rather than shifting;
- a projection that does not contain the handoff quarter at all is a hard error naming
  the handoff, the file's actual span, and the remedy;
- the reference CSV's terminal row is verified against `handoff_time`.

This does not remove the recomputation requirement — that is the longer-term fix — but
a mismatched set of artifacts can no longer be run through silently.

## Moving files: what needs an edit and what does not

The 2026-08 reorganisation split the flat model folder into roles. The two rules
are not symmetric, and getting them the wrong way round is how a "pure move"
breaks something:

- **Code is resolved by NAME, via the MATLAB path.** Moving a `.m` file between
  `internal/`, `diagnostics/`, `tests/` and the root needs no edit anywhere.
  What it does need is `setup_path`, because `addpath` is not recursive; every
  entry point calls it. The one exception is `plot_custom_irfs.m`, invoked from
  the `.mod` files at Dynare runtime behind an `exist()` guard — there only
  `pwd` is guaranteed searched, so in a subfolder it would silently degrade to
  Dynare's default IRF plots. It stays at the root.
- **Data is resolved by PATH, relative to `pwd`.** Moving a data file requires
  editing every reader and writer, including `make_datasets.do` and the Dynare
  `datafile` declared in `{Country}_estimation.mod`. Contract #31 is the guard:
  a writer left on a bare filename puts its output in the root while its reader
  looks in the subfolder, and if a stale copy happens to sit there the run
  succeeds on the wrong data.

## When adding a country, a variable, or a runtime

Ask: *what must now agree that did not have to agree before?* Add it here with its
enforcement before writing the code. The cost of a contract check is minutes; the
cost of an unenforced one was, in the two worst cases here, three months of results
computed on the wrong basis.
