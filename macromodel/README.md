# DSGE Workflow

This folder contains the macro workflow used to produce SimPaths-ready exports and the generated artefacts consumed by the model documentation in `WELLSIM_SVEC_Overleaf`.

## TL;DR

If you want to recreate everything for one country from a fresh model run through to refreshed documentation outputs, do this from MATLAB with the working directory set to `WELLSIM_SVEC/DSGE`:

```matlab
run_full_workflow('Poland')
```

That runs the Ramsey calibration and detrending steps, builds the population projection if the SimPaths file is available, renders the annual Ramsey forward-projection diagnostic plot, estimates the DSGE, generates the frozen model, exports the SimPaths policy files, writes documentation summary JSON files, and refreshes the generated Overleaf tables and figures.

Then compile the documentation from `WELLSIM_SVEC_Overleaf`:

```powershell
latexmk -pdf -g SimPaths_Macro_Model_Documentation.tex
```

If you already have the JSON summaries under `documentation_data/`, you can skip re-estimation and just rebuild the generated documentation artefacts:

```matlab
refresh_documentation_tables('Poland')
```

## What This Folder Produces

There are three distinct output layers:

1. Model outputs for SimPaths under `simpaths_export/{COUNTRY}/`
2. Intermediate documentation summaries under `documentation_data/`
3. Generated Overleaf artefacts under `../WELLSIM_SVEC_Overleaf/Tables/generated/` and `../WELLSIM_SVEC_Overleaf/Figures/generated/`

The key design point is that the documentation layer is summary-driven. Model code writes compact JSON summaries first, and the documentation refresh step renders those summaries into LaTeX tables, inline macros, and PDF figures.

## Full Workflow

### 1. Inputs And Preconditions

Before running the workflow, make sure these inputs exist:

1. `Macromodel_{COUNTRY}.mod`
2. `data_for_dynare_levels_{COUNTRY}.csv` for the Ramsey stages
3. `data_for_dynare_{COUNTRY}.csv` or the ability for `ramsey_trend` to regenerate it
4. Country parameter files under `country_params/`
5. Optionally, `../SimPathsEU/input/{CC}/align_popProjections.xlsx` for the population projection bridge

The default documentation handoff expects the sibling repository `../WELLSIM_SVEC_Overleaf` to exist.

### 2. Main End-To-End Entry Point

The canonical orchestration entry point is:

```matlab
run_full_workflow('Poland')
```

`run_full_workflow` executes the following stages:

1. Step 0a: `calibrate_growth_model`
2. Step 0b: `ramsey_trend`
3. Step 0c: `build_population_projection`
4. Step 0d: `ramsey_projection_plot`
5. Step 1: Dynare estimation of `Macromodel_{COUNTRY}.mod`
6. Step 2: `generate_frozen_model`
7. Step 3: `export_dynamic_for_simpaths`
8. Step 4: `postestimation_analysis`
9. Step 5: `refresh_documentation_tables`

This is the simplest way to recreate both the model outputs and the documentation artefacts in one pass.

### 3. How The Documentation Pipeline Works

The documentation pipeline has two stages.

### Stage A: Write Summary JSON Files

The model stages export stable, documentation-facing JSON summaries under `documentation_data/`.

Ramsey summaries:

1. `calibrate_growth_model` builds a summary with `build_ramsey_documentation_summary` and writes `documentation_data/ramsey/ramsey_summary_{Country}.json`
2. `ramsey_trend` writes the same summary type again, usually with richer validation diagnostics attached

DSGE summaries:

1. `postestimation_analysis` builds and writes `documentation_data/dsge/dsge_postestimation_{Country}.json`

Optional comparison summaries:

1. `run_detrending_benchmark` writes `documentation_data/comparisons/detrending_benchmark_{Country}.json`

### Stage B: Render Overleaf Artefacts From Summaries

`refresh_documentation_tables` reads those JSON files and regenerates the files consumed by the LaTeX document.

It creates or refreshes:

1. Ramsey cross-country tables in `../WELLSIM_SVEC_Overleaf/Tables/generated/ramsey/`
2. DSGE posterior tables in `../WELLSIM_SVEC_Overleaf/Tables/generated/dsge/`
3. DSGE moments and variance-decomposition tables in `../WELLSIM_SVEC_Overleaf/Tables/generated/dsge/`
4. The DSGE parameter classification table in `../WELLSIM_SVEC_Overleaf/Tables/generated/dsge/`
5. The detrending comparison table in `../WELLSIM_SVEC_Overleaf/Tables/generated/comparisons/` if benchmark summaries exist
6. `../WELLSIM_SVEC_Overleaf/Tables/generated/inline_values.tex` for inline numeric macros
7. Ramsey diagnostic figures in `../WELLSIM_SVEC_Overleaf/Figures/generated/`
8. DSGE variance-decomposition figures in `../WELLSIM_SVEC_Overleaf/Figures/generated/`

The main document `SimPaths_Macro_Model_Documentation.tex` includes these generated fragments directly.

### 4. Typical Usage Patterns

### Recreate Everything For One Country

Use this when you want fresh model outputs and fresh documentation artefacts.

```matlab
run_full_workflow('Poland')
```

### Refresh Ramsey Files Only For SimPaths

Use this when you want an updated Ramsey-only bundle for SimPaths without rerunning Dynare export:

```matlab
calibrate_growth_model('Poland', 'ramsey_labor_supply', 'endogenous');
ramsey_trend('Poland', [], 'ramsey_labor_supply', 'endogenous', 'projection_start', '2023q1');
build_population_projection('Poland', '..\..\SimPathsEU\input\PL\align_popProjections.xlsx', ...
    'ramsey_labor_supply', 'endogenous', 'projection_start', '2023q1');
export_ramsey_for_simpaths('Poland');
```

This refreshes the SimPaths-facing Ramsey files in `simpaths_export/Poland/` without requiring `oo_` or `M_` from a frozen Dynare run.

### Rebuild Documentation Artefacts Only

Use this when the summaries already exist and you only want to regenerate tables, macros, and figures.

```matlab
refresh_documentation_tables('Poland')
```

### Rebuild Only After Ramsey Changes

If you changed the Ramsey pipeline and want to regenerate the Ramsey-facing outputs without refreshing DSGE tables:

```matlab
refresh_documentation_tables('Poland', ...
    'refresh_ramsey', true, ...
    'refresh_dsge', false)
```

### Rebuild Only After DSGE Postestimation Changes

If you changed postestimation output formatting or summary content and only want the DSGE-facing tables refreshed:

```matlab
refresh_documentation_tables('Poland', ...
    'refresh_ramsey', false, ...
    'refresh_dsge', true)
```

### Refresh Inline Macros Without Rebuilding Country Tables

There is a small helper script for this:

```matlab
refresh_inline_macros_only
```

Note that the inline macro generator is currently wired around the available Germany and Poland summaries.

### Recreate The Detrending Benchmark Table

The benchmark table is not part of the core estimation workflow. It is driven by a separate comparison runner:

```matlab
run_detrending_benchmark('Poland')
refresh_documentation_tables('Poland', ...
    'refresh_ramsey', false, ...
    'refresh_dsge', true)
```

`run_detrending_benchmark` compares HP- and Ramsey-detrended datasets under the same DSGE specification, writes a comparison JSON summary, and the refresh step then renders the benchmark table and updates any inline macros that depend on it.

### 5. Important Options On `run_full_workflow`

Useful switches:

1. `skip_growth_calibration`
2. `skip_detrending`
3. `skip_estimation`
4. `skip_frozen`
5. `skip_dynamic_export`
6. `skip_postestimation`
7. `skip_population_projection`
8. `skip_projection_plot`
9. `use_parallel`
10. `simpaths_pop_file`
11. `ramsey_labor_supply` with `exogenous` or `endogenous`

Examples:

```matlab
run_full_workflow('Poland', struct('skip_estimation', true, 'skip_postestimation', true))
```

```matlab
run_full_workflow('Germany', struct('ramsey_labor_supply', 'endogenous'))
```

The final documentation refresh in `run_full_workflow` is conditional on which upstream stages ran:

1. Ramsey documentation is refreshed when growth calibration was not skipped
2. DSGE documentation is refreshed when postestimation was not skipped

### 6. Where To Look For Outputs

Model and export outputs:

1. `simpaths_export/{COUNTRY}/`
2. `growth_model_reference_{country}.csv`
3. `ramsey_trends_{country}.csv`
4. `population_projection_{COUNTRY}.csv`

Documentation summaries:

1. `documentation_data/ramsey/ramsey_summary_{Country}.json`
2. `documentation_data/dsge/dsge_postestimation_{Country}.json`
3. `documentation_data/comparisons/detrending_benchmark_{Country}.json`

Generated Overleaf artefacts:

1. `../WELLSIM_SVEC_Overleaf/Tables/generated/`
2. `../WELLSIM_SVEC_Overleaf/Figures/generated/`

The documentation refresh now writes country-specific DSGE variance-decomposition PDFs as `variance_decomposition_{Country}.pdf`.

### 7. Final LaTeX Build

After refreshing the generated artefacts, compile the documentation from the Overleaf repository root:

```powershell
latexmk -pdf -g SimPaths_Macro_Model_Documentation.tex
```

If the tables or figures do not appear in the PDF, check that:

1. The expected JSON summaries exist under `documentation_data/`
2. `refresh_documentation_tables` completed without validation errors
3. The generated files exist under `../WELLSIM_SVEC_Overleaf/Tables/generated/` and `../WELLSIM_SVEC_Overleaf/Figures/generated/`
4. The LaTeX document still includes the expected generated fragments

### 8. Practical Notes

1. `calibrate_growth_model`, `ramsey_trend`, and `postestimation_analysis` all default to `refresh_documentation = true` when run directly, but `run_full_workflow` disables that per-stage refresh and instead does one consolidated documentation refresh in Step 5.
2. The Ramsey diagnostic figures require both the summary JSON and the underlying `ramsey_trends_{country}.csv` plus `data_for_dynare_levels_{Country}.csv` inputs.
3. The documentation refresh is designed to be rerunnable. If the summaries are already correct, you do not need to rerun the expensive estimation steps just to rebuild the tables.
