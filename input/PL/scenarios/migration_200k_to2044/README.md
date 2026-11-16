# Input scenario `migration_200k_to2044` (PL)

A population in which PL receives 200000 immigrants a year more than in the baseline projection, from 2030 to 2044,
aged 20-34 (uniform), share of women 0.5. The folder holds:

- `align_popProjections.xlsx`: the scenario population (sheet `Population_projections`, same rows and years as
  `input/PL/align_popProjections.xlsx`). With the model argument `inputScenario: migration_200k_to2044` SimPaths reads it in place
  of the baseline workbook: the population alignment follows it, and so does the fertility alignment, whose target
  is the age-0 count of both genders over women aged 18-49.
- `ramsey_migration.csv`: the relative deviations `N` and `P` of the Ramsey planner's workers (ages 15-64)
  and population (all ages) from the baseline, one row per workbook year. Named in `mm_ramseyScenario`,
  it gives the planner the scenario's paths from the start year on (foresight); without it the planner sees the
  arrivals only through the feedback from SimPaths (surprise). In a foresight run the feedback's reference year
  (`mm_ramseyFeedbackReferenceYear`, by default the year after the start year) must be 2028 at the latest, two years
  before the first arrivals, so with the default the run must start in 2027 at the latest: the planner refuses a
  non-zero `N` or `P` from the start year through the year after the reference year.
- `ramsey_migration_workers.csv`, when present: the same file with `N` replaced by the deviation of SimPaths' workers,
  built by `input_processing/scenarios/build_ramsey_workers_path.do` from two runs with the macro layer off, one on
  the baseline inputs and one with this scenario. The planner's `N` is workers; the population aged 15-64 stands in
  for them in `ramsey_migration.csv`, which needs no SimPaths run, and arrivals who work more or less often than
  the average person aged 15-64 then reach the planner as a surprise through the feedback. A foresight run names
  this file. Rebuild it after rebuilding the folder or after a change to SimPaths' labour supply.

The workbook and `ramsey_migration.csv` come from one run of `input_processing/scenarios/build_migration_scenario.do`. Rebuild them together,
by rerunning the do-file, whenever the baseline workbook, the Eurostat extract or a parameter changes: the CSV is
computed from this workbook.

Every cell before 2030 equals the baseline, so a run that starts before 2030 shares the cached starting
population with the baseline runs, and `N` and `P` are exactly 0 up to 2029.

## Parameters

| Parameter | Value |
|---|---|
| Country | PL |
| First arrival year | 2030 |
| Last arrival year | 2044 |
| Arrivals a year | 200000 |
| Ages at arrival | 20-34, uniform |
| Share of women | 0.5 |

## Method

- Arrivals of year t count in column t. Each gender and age gets arrivals x share of the gender / number of ages,
  spread over regions in proportion to the baseline population of that gender-age-region cell in t.
- The migrant stock (arrivals and their descendants) ages one year a year. Survival from age a in t to a+1 in
  t+1 is min(1, pop(g, a+1, t+1) / pop(g, a, t)) from the baseline workbook summed over regions, and 1 below age
  50, where these ratios mostly reflect the baseline's own migration. The open age group 100 keeps 0.7 of itself
  plus the survivors from 99.
- Births during t: migrant women of each age 15-49 have Eurostat's projected age-specific fertility rate of year t
  (baseline variant; the extract runs to 2100). Half of the births are boys; they enter age 0 in t+1 in the mother's
  region.
- Scenario workbook = baseline + migrant stock, cell by cell.
- `N = WAP_scenario / WAP_baseline - 1` (ages 15-64) and `P = TOT_scenario / TOT_baseline - 1` (all ages),
  summed over genders and regions: the definitions of `input_processing/macromodel/build_population_projection.m`,
  so the planner's scenario paths are the ones a re-export with this workbook would build.

## Fertility target

SimPaths' fertility alignment compares the births of the women present at its fertility step with a target from
this workbook: the age-0 count of both genders over women aged 18-49
(`Parameters.calculateFertilityRatesFromProjections`). Column t counts the arrivals of year t among those women,
but SimPaths adds them only in its population alignment, which runs after the fertility step of year t
(`SimPathsModel.buildSchedule`). The target's denominator therefore holds each year's arrivals, whom SimPaths
does not have at the fertility step, and the target lies below the one that would leave SimPaths' age-specific
fertility unchanged.

- Size: in 2030 the target is 1.33% below that consistent target. This value is exact: no migrant has
  given birth yet, so the consistent target is the baseline's.
  Its size in the later years is not estimated for these parameters.
- Fertility alignment runs to `Parameters.FERTILITY_ALIGNMENT_END_YEAR` (2040) and keeps that year's adjustment
  afterwards, so the bias of 2040 carries forward to every later year.
- Population alignment brings every age-0 cell to the workbook's count, so age-0 totals still follow the workbook:
  the bias moves only how the births split between the fertility of SimPaths' women, natives included, and the
  age-0 persons the population alignment adds.
- Counting the migrants' births in their own year would bias the target upward by a similar amount. The births
  enter age 0 in t+1 because SimPaths adds the arrivals of year t at the end of t, so their first births in
  SimPaths fall in t+1. The bias comes from the target formula, not from this timing.

## Sources

- Baseline population: `input/PL/align_popProjections.xlsx`, sheet `Population_projections`.
- Fertility: Eurostat `proj_23naasfr`, projection `BSL`, single ages 15-49, years 2022-2100; local copy
  `input_processing/scenarios/eurostat_proj_23naasfr_PL.csv`, described in `input_processing/scenarios/eurostat_extracts.md`.

## Checks passed when this folder was built

- Every cell before 2030 equals the baseline; `N` and `P` are exactly 0 there.
- `N` and `P` recomputed from the written workbook equal the CSV within 1e-12.

## Selected years

Arrivals 2030-2044: 3,000,000; migrants and descendants in 2060: 4,576,275 (12.3% of the population).

| Year | N | P | Total / 15-64, baseline | Total / 15-64, scenario | Fertility target, baseline | Fertility target, scenario |
|---|---|---|---|---|---|---|
| 2030 |  0.0085 |  0.0054 | 1.5678 | 1.5630 | 0.03781 | 0.03731 |
| 2040 |  0.0982 |  0.0738 | 1.5923 | 1.5569 | 0.04347 | 0.04726 |
| 2050 |  0.1586 |  0.1252 | 1.7345 | 1.6846 | 0.04624 | 0.04600 |
| 2060 |  0.2192 |  0.1407 | 1.8444 | 1.7257 | 0.04406 | 0.04001 |

Built on 2026-11-10 from the repository root with

    Start-Process StataMP-64.exe -ArgumentList '/e','do','input_processing/scenarios/build_migration_scenario.do','PL','migration_200k_to2044','2030','200000','20','34','0.5','2044' -Wait
