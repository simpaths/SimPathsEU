# Macro model: Ramsey trend and DSGE cycle for SimPaths

This folder produces the macro bundle SimPaths reads from `input/{CC}/MacroModel/`:
a Ramsey growth model for the long-run path of capital, output, consumption and
the real wage, and an estimated New-Keynesian DSGE model for cyclical deviations
around it. SimPaths applies `w_total = w_trend + w_cycle` to wages and, once per
simulated year, feeds its realized employment and hours back into a re-solve of
the Ramsey path. Nothing here affects a SimPaths run unless `mm_macroModel` is
switched on in the YAML config (default `off`). Poland is the shipped country.

The committed bundle is enough to run SimPaths with the macro layer on. You only
need the toolchains below to **rebuild** a bundle: after a data refresh, a
re-estimation, a model change, or for a new country.

## Three stages, three toolchains

| Stage | Tool | Reads | Writes | Who runs it |
|---|---|---|---|---|
| 1 Data | Stata 19 + `dbnomics`; EViews 13 only for HICP seasonal adjustment | Eurostat/ECB/OECD via DBnomics; `stata/hicp_q_sa.dta` | `data/data_for_dynare_levels_{Country}.csv`, `data/PROVENANCE_{Country}.txt` | Whoever refreshes the data vintage. The CSVs are tracked, so stages 2 and 3 run without Stata. |
| 2 Trend | MATLAB + Dynare | `data/*.csv`, `country_params/`, `../../input/{CC}/align_popProjections.xlsx` | `output/` (ignored), Ramsey files in the bundle, `data/data_for_dynare_{Country}.csv` (the Dynare datafile) | Anyone rebuilding a bundle |
| 3 Cycle | MATLAB + Dynare | the datafile, `Macromodel_{Country}.mod` | `Macromodel_{Country}_frozen.mod` (tracked), policy matrices in the bundle | Anyone re-estimating |

The bundle lands in `../../input/{CC}/MacroModel/` directly. There is no copy step.

## Dependencies

Exact versions used for the committed Poland bundle; newer patch releases should
work, nothing older has been tried.

- **MATLAB R2025b** with the **Statistics and Machine Learning Toolbox**. That is the
  complete product list reported by `matlab.codetools.requiredFilesAndProducts` on
  the entry points. Tested on R2025b; at least R2020a is needed (`arguments` blocks,
  `readtable(..., 'VariableNamingRule', ...)`, `exportgraphics`).
- **Dynare 6.5**, with `<dynare>/matlab` on the MATLAB path. Estimation runs
  `dynare ... use_dll`, which needs a C compiler; the Windows Dynare installer
  bundles MinGW for this. On Linux/macOS use the system compiler (`mex -setup C`).
- **Stata 19** with `ssc install dbnomics`, stage 1 only.
- **EViews 13**, stage 1 only, only when `do_HICP_seasonal_adjustment = 1` in
  `stata/make_datasets.do`. The method is TRAMO/SEATS. The tracked
  `stata/hicp_q_sa.dta` is the cached result, so EViews is optional.
- **Java 19 and Maven**, for the bundle tests (`BundleProvenanceTest`,
  `RamseyTrendModelTest`, `DSGEBundleContractTest`), already required by SimPaths.

**Octave is not supported.** 25 of the 56 MATLAB files use `arguments` blocks and
12 use `table`/`readtable`; Octave has neither. Dynare itself runs under Octave,
the orchestration here does not, and no port is planned.

Run `check_dependencies` in MATLAB (from this folder) to see what your machine has.

## Running it

The working directory must be this folder: data is found by `pwd`-relative paths
and Dynare writes its output into `pwd`. From MATLAB:

```matlab
>> cd input_processing/macromodel
>> check_dependencies
>> run_full_workflow('Poland')
```

That runs: `calibrate_growth_model`, `ramsey_trend`, `build_population_projection`
(reads `../../input/PL/align_popProjections.xlsx`), the Ramsey diagnostic plot,
`dynare Macromodel_Poland.mod use_dll` (estimation, about 3 minutes),
`generate_frozen_model`, `dynare Macromodel_Poland_frozen.mod` and
`export_dynamic_for_simpaths`, then `postestimation_analysis`. About 5 minutes in
all on a 2025 laptop. The same steps one by one:

```matlab
>> calibrate_growth_model('Poland')
>> ramsey_trend('Poland')
>> build_population_projection('Poland')
>> dynare Macromodel_Poland.mod use_dll
>> generate_frozen_model('Poland')
>> dynare Macromodel_Poland_frozen.mod noclearall nograph
>> export_dynamic_for_simpaths
>> postestimation_analysis
```

`run_full_workflow` takes `skip_growth_calibration`, `skip_detrending`,
`skip_estimation`, `skip_frozen`, `skip_dynamic_export`, `skip_postestimation`,
`skip_population_projection`, `skip_projection_plot`, `use_parallel`,
`simpaths_pop_file` and `projection_start` as name-value options. Unattended:

```powershell
matlab -batch "cd('<repo>\input_processing\macromodel'); run_full_workflow('Poland')" -logfile run.log
```

Stage 1, when the data vintage should move (Stata's working directory must be
`stata/`; set `global country` at the top of the do-file):

```powershell
cd input_processing\macromodel\stata
StataMP-64.exe /e do make_datasets.do
```

## Verifying it

- `setup_path` and then `run_all_tests` from this folder runs the MATLAB checks
  (`setup_path` puts `tests/` on the MATLAB path). Exit by its return value: `0`
  failures. None of the checks solves the model; they and `smoke_test.ps1` are the
  merge gates.
- `smoke_test.ps1` is the fresh-clone test: dependency check, `run_all_tests`, the
  workflow from tracked inputs with estimation, frozen-model generation,
  post-estimation and the projection plot skipped, and `compare_bundles` of the
  regenerated bundle against the committed one at `rel_tol = 1e-6` (byte identity is
  not expected: generation stamps and SHA-256 digests differ, and the regenerated
  datafile carries floating-point solver noise). It restores the committed bundle
  afterwards. About 5 minutes. A tolerance this tight works because estimation is
  skipped, so the Dynare solve of the tracked frozen model and the Ramsey solve are
  deterministic up to that noise; the fourth-digit differences seen across machines
  come from re-estimation, which the smoke test does not do. The comparison blanks the
  SHA-256 digests in `BUNDLE_PROVENANCE.txt` (`BundleProvenanceTest` owns those) and
  compares the numbers inside text files at the same tolerance. It refuses to start
  if `input/{CC}/MacroModel/` or `input_processing/macromodel/data/` has uncommitted changes. Run
  it from the repository root (the script finds its own folders):

  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File input_processing\macromodel\smoke_test.ps1 [-MatlabExe <path>]
  ```
- `mvn -q test -Dtest='simpaths.model.macro.*Test'` runs the Java side.
  `BundleProvenanceTest` recomputes the SHA-256 hashes in
  `input/PL/MacroModel/BUNDLE_PROVENANCE.txt` from the tracked frozen model, the
  Dynare datafile and the Stata levels CSV, the growth-params template,
  `Macromodel_template.mod` and the calibration file, and
  `input/{CC}/align_popProjections.xlsx`, and it also recomputes the hashes of the
  bundle's own exporter files, so a change to any of them without a re-export fails
  CI. It checks every `input/*/MacroModel/` folder, requires `policy_A.csv` in each
  and fails on a committed `BUNDLE_NOT_VERIFIED.txt`. `RamseyTrendModelTest` checks
  MATLAB-Java parity of the Ramsey solve at `1e-9` against the fixtures in
  `src/test/resources/macro/exogenous/`, refreshed only by
  `refresh_java_parity_fixtures`.
- Editing any hashed input (`input/PL/align_popProjections.xlsx`, the datafile
  `data/data_for_dynare_Poland.csv`, the levels CSV
  `data/data_for_dynare_levels_Poland.csv`, the growth-params template
  `country_params/Poland_growth_params.json`, `Macromodel_template.mod`,
  `country_params/Poland_calibration.mod`, `Macromodel_Poland_frozen.mod`) or any
  exporter file in the bundle folder turns `BundleProvenanceTest` red until the
  bundle is re-exported and committed together with the edit. Which re-export fits
  depends on what failed, and the test prints the one that does. A changed bundle
  file alone (nothing upstream moved) needs the re-export that skips estimation
  (MATLAB + Dynare, about five minutes):

  ```matlab
  >> run_full_workflow('Poland', 'skip_estimation', true, 'skip_frozen', true, 'skip_postestimation', true)
  ```

  A changed input needs the full workflow with estimation, `run_full_workflow('Poland')`
  (about five minutes for Poland): the frozen model and the Dynare datafile are built
  from the inputs, so the skip-estimation re-export would re-hash the edit around an
  unchanged posterior. Commit `Macromodel_Poland_frozen.mod` and
  `data/data_for_dynare_Poland.csv` together with the bundle.
  `export_ramsey_for_simpaths('Poland')` refreshes only the Ramsey half; it carries
  the three DSGE-half lines (the frozen model, `Macromodel_template.mod` and
  `country_params/Poland_calibration.mod`) forward from the bundle's existing
  `BUNDLE_PROVENANCE.txt`.
- After a run, `git status` is rarely clean, and most of what it shows is not a
  change: generation stamps alone dirty the frozen model (`// Generated:`),
  `SIMPATHS_INTERFACE.md` and `BUNDLE_PROVENANCE.txt`, and on another machine the
  solver's floating-point noise dirties `data/data_for_dynare_*.csv`. A run with no
  changed input is discarded with `git checkout -- input_processing/macromodel input/PL/MacroModel`
  followed by `git clean -f -- input/PL/MacroModel/BUNDLE_NOT_VERIFIED.txt`: a run that
  stopped before its export leaves that marker behind, and SimPaths refuses the bundle
  while it is there.
  The data vintage moved only when `data/data_for_dynare_levels_*.csv` or
  `data/PROVENANCE_*.txt` changed; then the frozen model and the bundle must be
  regenerated (full `run_full_workflow`, with estimation) and committed with it.
- A bundle folder containing `BUNDLE_NOT_VERIFIED.txt` was refused by
  `verify_export_bundle` (incomplete or mixed vintages), or the export never reached
  verification, or `calibrate_growth_model` or `ramsey_trend` rewrote its growth-params
  JSON after the last export. It is never
  committed, the layout test fails if one is tracked, and SimPaths refuses to start
  the macro layer on it. The next export that verifies removes the file.

## Country status

| Country | Code | Estimated | Bundle shipped | Why not |
|---|---|---|---|---|
| Poland | PL | yes | yes | |
| Germany | DE | yes | no | not exported into this repository; the last export predates the units contract (`simpaths_input_scale`), so re-export before any DE run |
| Spain | ES | yes | no | no `input/ES/align_popProjections.xlsx` yet; employment is extrapolated mechanically, bundle refused |
| Sweden | SE | yes | no | same as Spain, and SimPathsEU has no Sweden inputs |

## Adding a country

Four files: `country_params/{Country}_calibration.mod`,
`country_params/{Country}_estimation.mod`, the Ramsey parameter template
`country_params/{Country}_growth_params.json`, and the two-line wrapper
`Macromodel_{Country}.mod`; plus the country's row in `stata/make_datasets.do` and
`internal/get_country_config.m`. `docs/MULTI_COUNTRY_WORKFLOW.md` walks through it,
including the data sources that bite.

## Contracts and documents

- `docs/Integration_Contracts.md`: the numbered contracts between the stages and
  between MATLAB and Java, each with what enforces it. Two bind Java changes: never
  re-derive downstream what upstream computes (carry it in the bundle, fail if it is
  missing), and treat parity fixtures as snapshots that are refreshed, never edited.
- `docs/Technical_Documentation_Macromodel.md` (v17): the model.
- `docs/SimPaths_Coupling.md`: the Java side: the `mm_*` switches, which bundle files
  SimPaths reads, and the yearly Ramsey re-solve against realized labour supply.
- `docs/Estimation_Guide.md`: priors, shocks, diagnostics.
- `docs/MULTI_COUNTRY_WORKFLOW.md`: adding a country.
