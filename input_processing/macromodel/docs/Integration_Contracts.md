# Integration Contracts

When two components must agree and nothing fails when they diverge, every run reports success on a wrong
basis. Each such agreement is a contract. This file lists the contracts between the components of the macro
layer and, for each, what enforces it.

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

Duplication counts too: two copies that agree today are a contract nothing checks, so "harmless" duplication is
unenforced-contract debt, not style. Contracts 23 and 27 are examples: two JSON parsers that treated whitespace
differently, and two writers of one file.

## Inventory

Numbers are stable identifiers, cited in code and tests; a missing number is not reused.

| # | Contract | Between | Enforced by | Status |
|---|---|---|---|---|
| 1 | The bundle is in percent log-deviation units (`deviation_scale = 100`), so the DSGE's wage deviation is a percent | export datafile check ↔ `DSGEModel.loadModelInfo` | `DSGEBundleContractTest` (a bundle that lacks `deviation_scale`, or declares another value, is refused with a message to re-export); `DSGEModel.PERCENT_PER_LOG_DEV` | enforced |
| 2 | π is read from whichever vector declares it | exporter `model_info.json` ↔ `DSGEState.VarIndices` | throws if neither map declares `pi`; `DSGEStateTest` | enforced |
| 3 | Every shock, `eps_L` and `eps_h` included, is σ-scaled exactly once | scenario CSVs ↔ `stepQuarterly` | `DSGEShockScenarioTest`, `DSGEModelTest` | enforced |
| 4 | χ_u = χ_L − χ_n, and the implied U/L rate matches the estimation sample | calibration ↔ template eq. 10 ↔ data | `test_calibration_identities.m` (identity **and** sample rate) | enforced |
| 7 | Frozen-model substitutions actually matched | template text ↔ `generate_frozen_model.m` patterns | `subst_verified` (match count), `test_frozen_model_generator.m` | enforced |
| 8 | Export bundle layout matches its own `model_info.json` | `export_dynamic_for_simpaths.m` ↔ `DSGEModel` loaders | row/column name validation on load; `DSGEIntegrationTest` | enforced |
| 9 | Forward horizon is the same on both sides | `ramsey_trend.m` `projection_quarters` ↔ `MacroModelManager` | exported in `growth_terminal_state.json`, read by Java | enforced |
| 10 | Handoff quarter matches the simulation start year | `growth_terminal_state.json` ↔ `simulationStartYear` | `validateRamseyHandoffTime` throws | enforced |
| 11 | The population projection belongs to this bundle's country | bundle ↔ `MacroModelManager` | country-tagged filename required, no fallback | enforced |
| 12 | `data_for_dynare_{C}.csv` has exactly one writer | `make_datasets.do` ↔ `ramsey_trend.m` | only `ramsey_trend.m` writes it; `make_datasets.do` writes the levels and HP files and deliberately not this one | enforced by construction |
| 13 | K₀/A₀ are anchored at the first data row | growth params `base_year` ↔ data file start | assert in `ramsey_trend.m` | enforced |
| 14 | LBJ Jacobian bandwidth kl=ku=1 is valid | residual structure ↔ banded solver | runtime off-band probe, throws | enforced |
| 16 | `n`, the planner's `N` and SimPaths' workers are all persons in employment | DSGE observable ↔ calibration ↔ Ramsey `N` ↔ `L_sim` | `make_datasets.do` fetches total employment for every country (its UNITS and identity checks); χ_n is the same concept; `lambda` is a units conversion | enforced by construction |
| 17 | Scenario shocks are applied from the year they declare | scenario CSV ↔ `updateEquilibrium` | `MacroModelManagerTest.testScenarioShocksApplyFromTheStartYear` | enforced |
| 18 | Committed bundle is built from the tracked inputs beside it | `input_processing/macromodel/` inputs and the bundle's own files ↔ `input/{CC}/MacroModel/BUNDLE_PROVENANCE.txt` | exporter writes SHA-256 per input (`write_bundle_provenance`); `BundleProvenanceTest` recomputes them in CI; exporter writes into `input/` directly, no copy step; the Ramsey-only export carries the DSGE-half input lines forward from the previous file | enforced |
| 19 | MATLAB↔Java Ramsey parity is machine-precision | `ramsey_trend.m` ↔ `RamseyTrendModel` | `RamseyTrendModelTest`, `RELATIVE_TOLERANCE = 1e-9` (measured worst 7.2e-12 on the 2026-11 fixture) | enforced |
| 20 | Reference-CSV `l` is participation, not the labour-force level | exporter column naming ↔ `loadReferenceCSV` | case-sensitive header match | enforced |
| 21 | Macro CSVs are merged by DATE, never by row position | `population_projection_*.csv`, `growth_model_reference_*.csv` ↔ the forward splice | splice locates the handoff quarter; reference terminal row verified against `handoff_time`; `MacroModelManagerTest` alignment tests | enforced |
| 22 | The documented shock order is the `varexo` declaration order | `Macromodel_template.mod` ↔ the tex ↔ the exporter header | `\DsgeShockOrder` generated from the varexo block; an unlabelled new shock fails the docs refresh | enforced |
| 23 | Every JSON reader in the macro package parses the same way | `DSGEModel` ↔ `RamseyTrendModel` ↔ `MacroModelManager` ↔ both MATLAB writers | one `MacroJson`; `MacroJsonTest` asserts compact and pretty-printed input read identically | enforced |
| 24 | A JSON artefact Java reads is never partially written | MATLAB writers ↔ Java string-scan readers | `write_text_atomic` (temp file + re-decode before move) | enforced |
| 25 | Scenario CSVs reject non-finite values and keep trailing fields | `RamseyScenario` ↔ `DSGEShockScenario` | one `MacroCsv`; `ScenarioLoaderParityTest` | enforced |
| 26 | The alignment diagnostic counts the population the alignment used | `ActivityAlignmentV2.matchesSubgroup` ↔ `AlignmentStatistics.classifyBenefitUnit` | one `BenefitUnitSubgroup` | enforced by construction |
| 27 | `growth_terminal_state.json` has exactly one writer | `export_dynamic_for_simpaths.m` ↔ `export_ramsey_for_simpaths.m` | both call `write_growth_terminal_state.m` | enforced by construction |
| 28 | The forward FOC/HP smoother exists once per runtime | `calibrate_growth_model.m` ↔ `ramsey_trend.m` | `hp_filter_trend.m` is the single implementation | enforced by construction |
| 29 | Sibling macro scenario configs differ only in their declared treatment | `config/batch-*.yml` | `MacroScenarioConfigTest` — any undeclared difference fails, including keys the test does not enumerate | enforced |
| 30 | Macro scenario configs run on a stock SimPaths build | `config/*.yml` ↔ `SimPathsMultiRun`'s reflective loader | `MacroScenarioConfigTest` rejects any top-level key that is not a `SimPathsMultiRun` field or a known argument map | enforced |
| 31 | Every artefact is written where its readers look for it | writers ↔ readers across `data/`, `output/`, `logs/`, `figures/` | paths built by `internal/artifact_path.m`; `tests/test_artifact_layout.m` fails on any pipeline artefact left in the model root | enforced |
| 32 | The pipeline runs from the model root | every pwd-relative path ↔ Dynare's `pwd`-bound output and `datafile` | `artifact_path` asserts the root and names the folder you are actually in | enforced |
| 33 | The frozen posterior belongs to the committed data vintage | `data/data_for_dynare_{C}.csv` ↔ `Macromodel_{C}_frozen.mod` ↔ `input/{CC}/MacroModel/` | all three tracked; a dirty `data/data_for_dynare_levels_{C}.csv` or `data/PROVENANCE_{C}.txt` after a run means the vintage moved and the downstream artefacts must move with it, while a dirty `data/data_for_dynare_{C}.csv` alone may be floating-point solver noise from another machine | ⚠ partial (visible, not blocked) |
| 34 | No file assigns a variable named like one of our functions | any `.m` ↔ the function files we own | `tests/test_name_collisions.m` | enforced |
| 35 | The export bundle is complete and one vintage | the bundle's Ramsey half ↔ its DSGE half ↔ `output/` | `verify_export_bundle` at the end of both exporters: every file present, and `growth_model_reference_*.csv` and `population_projection_*.csv` byte-identical to their `output/` sources; a source that is absent from `output/` is skipped, so the bundle keeps the Ramsey file it already holds | ⚠ partial (a missing source passes) |
| 36 | A refused bundle says so inside the bundle | `verify_export_bundle`'s verdict ↔ whoever commits or runs SimPaths on `input/{CC}/MacroModel/` later | `BUNDLE_NOT_VERIFIED.txt`, written by both exporters before their first file, by `calibrate_growth_model` and `ramsey_trend` before they rewrite the bundle's growth-params JSON, and removed only by a passing verification (`mark_bundle_unverified.m`, `test_export_bundle_marker.m`); `MacroModelManager.initialize` refuses a bundle that carries it (`MacroModelManagerTest.testBundleWithNotVerifiedMarkerIsRefused`) | enforced |
| 37 | The frozen model and the bundle carry the calibrated persistence of the labour force and hours | `{Country}_calibration.mod` ↔ `Macromodel_{C}_frozen.mod` ↔ `shock_params.csv` | `test_frozen_model_generator.m` (no `for_simpaths_export`, `rho_L`/`rho_h` assigned once with the calibration's value in every tracked frozen model), `DSGEModelTest.testLabourForceInnovationDecaysAtTheBundlesPersistence` | enforced |
| 38 | The DSGE takes no input from SimPaths; with no scenario its cycle wage is zero | `MacroModelManager.runDsgePass` ↔ `DSGEModel.stepAnnual` | `DsgeOneWayTest` (driven through the schedule: a Ramsey+DSGE run has the Ramsey-only wage index and a zero DSGE state whatever the workers do; DSGE-only has a zero cycle wage and still refuses a start year off the bundle's handoff) | enforced |
| 39 | The UK's ONS and OECD series carry the concepts the other countries' Eurostat series carry: volumes in `CLV15_MEUR`, wages converted at the fixed 2015 rate, persons in employment of the national concept, hours per person employed per quarter | UK series block of `make_datasets.do` ↔ the units `calibrate_growth_model`, `ramsey_trend` and the DSGE observables assume | `make_datasets.do` stops if the ONS-based GDP is more than 5% from Eurostat's own UK `CLV15_MEUR` series where both exist (2026-10: -0.3% to +3.3%), if Eurostat's UK GDP pair does not give a constant rate, or if any country's hours per person employed leave [200, 700] per quarter | enforced |
| 40 | The wage SimPaths applies is the trend wage's level times the cycle's factor, `1 + w_total/100 = (1 + w_trend/100) exp(w_cycle/100)`, and both are wages per hour: the trend is the planner's `(1-alpha) Y / (N h)`, the cycle the DSGE's `w - h` (its `w` is a wage per worker) | `RamseyTrendModel` trend wage ↔ DSGE `w`, `h` ↔ `Person.updateFullTimeHourlyEarnings` (hourly wages) ↔ the `*_total` columns of `MacroPaths.csv` | `TrendCycle.totalPct`, `DSGEState.getHourlyWageDeviation`; `MacroWageCompositionTest` (expected values from the bundle's impulse responses: Ramsey+DSGE against Ramsey-only and DSGE-only, a technology and an hours shock), `MacroPathRecorderTest` | enforced |
| 41 | `N` and `P` of `population_projection_{C}.csv` come from one workbook and one handoff, and imply the same log growth after the handoff as `demographic_L_{c}.csv` and `demographic_P_{c}.csv` respectively | `build_population_projection.m` ↔ the bundle's projection (Java) ↔ the two demographic files (`ramsey_trend.m`) | `verify_export_bundle` calls `check_demographic_pair_coherence` twice, `('N', demographic_L_{c}.csv, 'L_demo')` and `('P', demographic_P_{c}.csv, 'P_demo')`: a missing column or file, a missing forward tail or a growth difference above 1e-6 in any post-handoff quarter refuses the bundle; `test_demographic_pair_coherence` | enforced |
| 42 | The bundle carries the planner's population path: Java reads `P` and never derives it | `population_projection_{C}.csv`, `growth_model_reference_{c}.csv` ↔ `MacroModelManager.loadPopulationProjection`, `RamseyTrendModel.loadReferenceCSV` | both loaders refuse a file without a `P` column with a message to re-export the macro files; `MacroModelManagerTest.testProjectionWithoutPopulationColumnIsRefused`, `RamseyTrendModelTest.testReferenceCsvWithoutPopulationColumnIsRefused` | enforced |
| 43 | Workers, hours and population reach the planner from one `computeRawAggregates` call per year | `LaborSupplyAggregator` ↔ the planner's feedback | `MacroModelManager.applyRamseyRecursiveFeedback` passes `laborForce`, `avgHoursPerWorker` and `totalPopulation` of one aggregate; `RamseyRecursiveFeedbackTest.testPublicWrapperLatchesPopulationFromTheSameAggregates`, `testPopulationSurpriseRevisesThePlannerPopulationPath` | enforced by construction |
| 44 | A Ramsey scenario whose `N` and `P` are zero leaves the planner bit-identical; non-zero values are refused from the start year through the year after the feedback's reference year (`mm_ramseyFeedbackReferenceYear`; `startYear + 2` by default), the years whose factors enter the handoff quarter or the feedback's latch quarters, so the gaps measure SimPaths against the scenario paths | `RamseyScenario` ↔ `MacroModelManager.initializeRamseyTrend` ↔ the feedback latch | `MacroModelManager.requireNoPathDeviationBeforeFirstAllowedYear`; `MacroModelManagerTest.testZeroPathDeviationsLeaveThePlannerBitIdentical`, `testNonZeroPathDeviationInTheStartYearIsRefused`, `testFirstAllowedPathDeviationYearIsThreeYearsAfterTheStart`, `testFirstAllowedPathDeviationYearFollowsTheReferenceYear`; `RamseyRecursiveFeedbackTest.testFeedbackLatchesAgainstTheScenarioPaths` | enforced |
| 45 | An input scenario folder holding the baseline's workbooks gives a run byte-identical to one without it; a scenario may not change the start year's population | `InputScenario`/`Parameters.resolveCountryFile` ↔ the cached starting population (`Processed`) | the same bytes are read: a file in the folder is read in place of the country's file of the same name, and nothing else changes; `InputScenarioTest`; the `Parameters` checks of a replaced population workbook (same years, same last age, unchanged start year) and of the other cached inputs. Checked end to end on real PL data on 2026-11-09: ten output CSVs byte-identical in a macro-off pair and in a Ramsey pair | enforced by construction |
| 46 | The feedback measures SimPaths' workers, hours and population against one reference year: `startYear + 1`, or the later year `mm_ramseyFeedbackReferenceYear` names. Before it the feedback does nothing and the planner keeps the path of its first solve; the zero rule of contract 44 moves with it | `SimPathsModel.mm_ramseyFeedbackReferenceYear` ↔ `MacroModelManager.applyRamseyFeedbackWithRealized` ↔ `requireNoPathDeviationBeforeFirstAllowedYear` | `MacroModelManager.feedbackReferenceYear`; `requireFeedbackReferenceYearInsideRun` fails the run at startup unless the key is `0` or a year after the start year and before the end year; `RamseyRecursiveFeedbackTest.testYearsBeforeTheReferenceYearLeaveThePlannerOnItsProjection`, `testReferenceYearLatchesAndLaterGapsAreMeasuredAgainstIt`; `MacroModelManagerTest.testFeedbackReferenceYearMustLieInsideTheRun`, `testFeedbackReferenceYearIsInertWithoutRamseyTrend` | enforced |

## Open items

**Contract 33: the data vintage.** `input_processing/macromodel/data/` is tracked, so the estimation input is
versioned alongside the frozen posterior and the export bundle it produced. Nothing
*blocks* committing a new data vintage without regenerating them, though: the
enforcement is that `git status` shows the CSVs dirty after a run, and
`data/PROVENANCE_{C}.txt` records which vintage a commit holds. Contract 18 catches
two cases: a regenerated `data/data_for_dynare_{C}.csv` or a changed
`data/data_for_dynare_levels_{C}.csv` committed without a re-export turns
`BundleProvenanceTest` red. It does not notice a new vintage that was re-exported
without re-estimating the frozen model. Closing it properly would mean stamping the
vintage into `growth_terminal_state.json` and having the export refuse to run against
a different one — worth doing if the data starts moving often.

**Contract 35: a missing `output/` source.** A skip-estimation re-export on a machine whose `output/` folder lacks
the Ramsey artefacts keeps the bundle's existing Ramsey files, which is what a DSGE-only change wants; but the
same path lets a bundle combine a new DSGE half with a Ramsey half from another vintage without the check
noticing. `BUNDLE_PROVENANCE.txt` still records the inputs of both halves.

## Where the macro layer stops

Not every duplication in the SimPaths repository is the macro layer's to fix. The
`validation/` do-files and the `config/alignment_*.yml` ladder belong to the SimPaths
head maintainers; the macro work stays inside `src/main/java/simpaths/model/macro`
(plus its test mirror) and the macro scenario configs.

**A macro artefact must remain readable by an unmodified SimPaths build.** The upstream config loader reflects
each top-level key onto a field and, on `NoSuchFieldException`, prints a stack trace and **continues**, so an
unrecognised key does not stop a run: it drops whatever it carried. A config built on a mechanism the stock
loader lacks, such as an `extends:` key that inherits another file, would run on a stock build with only its own
lines: no seed, no horizon, no alignment switches, no error. Enforcement therefore belongs in a test, not in a
change to the shared runtime; contract 30 is that check.

## Scenario shocks and the stability bound

Scenario shocks land in the year they declare, the start year included (contract 17). A large scenario applied
in full can drive the DSGE state past the stability bound `mm_dsgeMaxStateDeviation` (default 10) and stop the
run. That is the guard doing its job: raise the bound or reconsider the scenario's magnitude, never truncate the
scenario.

## MATLAB-only parameters

`inflation_target.pi_star_annual` is read by `ramsey_trend.m` when building the inflation trend, but has no Java
reader. Editing it in a *deployed bundle* therefore does nothing; editing it in the source JSON and re-running
the workflow does.

## Changing the start year

A start year needs a bundle exported for the matching handoff date, so changing it means re-running the MATLAB
workflow. Three checks make a mismatch fail rather than run:

- `validateRamseyHandoffTime` compares the handoff in `growth_terminal_state.json` with the start year
  (contract 10);
- the splice **finds** the handoff quarter in `population_projection_*.csv` by date: a projection that starts
  earlier works, and one that does not contain the handoff quarter is a hard error naming the handoff, the
  file's actual span and the remedy (contract 21);
- the reference CSV's terminal row is verified against `handoff_time` (contract 21).

The CSVs are merged by date, never by row position, because the projection and the reference CSV are
regenerated separately: merged by position, regenerating one and not the other would shift the whole
demographic path with every check still passing.

## Moving files: what needs an edit and what does not

The model folder is organised by role: code in the root, `internal/`, `diagnostics/` and `tests/`; artefacts in
`data/`, `output/`, `logs/` and `figures/` (contract 31). The two rules for moving a file are not symmetric, and
getting them the wrong way round is how a "pure move" breaks something:

- **Code is resolved by NAME, via the MATLAB path.** Moving a `.m` file between
  `internal/`, `diagnostics/`, `tests/` and the root needs no edit anywhere.
  What it does need is `setup_path`, because `addpath` is not recursive; every
  entry point calls it. The one exception is `plot_custom_irfs.m`, invoked from
  the `.mod` files at Dynare runtime behind an `exist()` guard — there only
  `pwd` is guaranteed searched, so in a subfolder it would silently degrade to
  Dynare's default IRF plots. It stays at the root.
- **Data is resolved by PATH, relative to `pwd`.** Moving a data file requires
  editing every reader and writer, including `make_datasets.do` and the Dynare
  `datafile` declared in `{Country}_estimation.mod`. Contract 31 is the guard:
  a writer left on a bare filename puts its output in the root while its reader
  looks in the subfolder, and if a stale copy happens to sit there the run
  succeeds on the wrong data.

## When adding a country, a variable, or a runtime

Ask: *what must now agree that did not have to agree before?* Add it here with its
enforcement before writing the code. A contract check costs minutes; an unenforced contract can carry wrong
results through months of runs that all report success.
