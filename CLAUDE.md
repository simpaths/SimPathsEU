# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SimPaths is a JAS-mine-based microsimulation model that projects individual and household life course events (career, family, health, finances) for EU countries. This repository covers Greece (EL), Italy (IT), Spain (ES), Hungary (HU), and Poland (PL). It integrates with EUROMOD for tax/benefit policy simulation.

**Country status.** PL and ES are the maintained countries. Their inputs follow the current layout, they ship training data, and each has an integration test. EL, HU and IT are stale: they are not maintained in the current release, and bringing them up to date is planned for a later one. Their inputs are in an older layout. Each lacks `alignment_adjustment_factors.xlsx` (its adjustment sheets still sit in `time_series_factor.xlsx`), `alignment_targets_{disability,inSchool,partnered_share,retirement}.xlsx` and `reg_leave_parental_home.xlsx` (it has `reg_leaveParentalHome.xlsx` instead). `Parameters` loads all of these unconditionally, so `-c EL|HU|IT` does not run at present. EL, HU and IT have no training subset either. This is a known gap, not a bug: changes for PL and ES don't need to keep these three countries running or update their inputs.

**A missing workbook fails late.** JAS-mine's `ExcelAssistant.loadCoefficientMap` catches `FileNotFoundException`, prints the stack trace and returns `null`. The failure then surfaces as a `NullPointerException` far from its cause, so look for a `FileNotFoundException` earlier in the console first.

**`input/<CC>/parameters.xlsx` overrides Java defaults.** `Parameters.loadParameters` reads its `Parameters` sheet and sets the static field of the same name (`ParametersLoader.setParametersFromMap`), so the workbook value wins over the default in `Parameters.java`. Change both together. Setup (`Parameters.databaseSetup`) runs before `loadParameters`, so it reads the sheet itself through the same method, `loadCountrySpecificParameters`, and uses the same values as the simulation: for example `MIN_HOURS_EMPLOYED` in the starting-population recode and the `KEY_FUNCTION_HU2_*` thresholds of the donor keys. Keys used at setup take effect when the input DB is built, so rebuild the DB after changing them.

### Spain (ES)

ES is a first-class country in the Java code: `Country.ES("Spain", 13)`, `Region.ES1`–`ES7` (NUTS-1), `Person.Regressors.ES1`–`ES7`, an ES block in `BenefitUnit.getRegressionValue`, and Spanish state-pension rules in `Parameters.getStatePensionAge` (statutory ages given in years and months).

**Labour choice.** No work plus five gender-specific hour bands, `Labour.CATEGORY_ES_1`–`5` (ids 51–55): women 6–25 / 26–34 / 35–39 / 40 / 41+, men 6–34 / 35–39 / 40 / 41–55 / 56+. The lower bound of `ES_1` is ES's `MIN_HOURS_EMPLOYED` (6 in `parameters.xlsx`), and fewer hours convert to `Labour.ZERO`. At setup, `DataParser.marginalEmploymentRecode` recodes anyone reported as employed on fewer than `MIN_HOURS_EMPLOYED` hours, together with their lagged status, to not employed. It does so for every country, but with PL's value of 1 it only reaches anyone employed on zero hours, and PL's training populations have none. The choice is scored at each band's representative hours (for every country, `Parameters.useRepresentativeHoursInUtility`). Realised hours: with `Parameters.USE_SILC_LHW_DISTRIBUTION = true` (the default) every positive band draws from the EU-SILC within-band distribution of observed hours for the person's gender and sample type — `Couple`, `Single_dep` (partner not flexible), `Adult_child`, `Single_indep` — read from `input/ES/silc_lhw_distribution.xlsx`, the top band running to `MAX_LABOUR_HOURS_IN_WEEK` (84). With the flag off, only the 35–39 band (`ES_3` for women, `ES_2` for men) spreads realised hours uniformly and every other band realises at its representative hours. The flag applies to PL as well (`Parameters.SILC_LHW_DISTRIBUTION_COUNTRIES`; other countries ignore it): PL draws within its bands 1–39 / 40 / 41–80 from `input/PL/silc_lhw_distribution.xlsx` (EU-SILC PL_2019_b3, built from `hours_distributions_PL.xlsx` by the steps listed on its `Info` sheet). It differs from the ES file in two ways: its rows stop at 80 hours, where PL's data top out, and it keeps hours 1–5, because PL's estimation and initial population count them as employed in the 1–39 band (PL's `MIN_HOURS_EMPLOYED` is 1). With the flag off, PL hours spread uniformly within each band. PL's choice is scored at 20 / 40 / 50 hours for both genders, the hours the PL labour-supply estimation assigns to its bands (`temp_lhw_dobs_*` in `input_processing/labour_supply/PL/do-files/std singles and couples data preparation/1-input and output data-std model.do`, reused for adult children).

**`parameters.xlsx` differences from PL.** `MIN_HOURS_EMPLOYED` 6 (PL 1, the Java default) and `MAX_LABOUR_HOURS_IN_WEEK` 84 (PL 80, the Java default). `Labour` holds the same numbers as the lower limit of the country's first positive band and the upper limit of its top band, and `Parameters.checkLabourBandLimits` fails at load if they differ. ES also differs in `MIN_HOURS_FULL_TIME_EMPLOYED` 36 (PL 25) and `MAX_HOURLY_WAGE_RATE` 80 (PL 75). ES also sets `MIN_AGE_LEAVE_PH` 18 and `MAX_AGE_ADULT_CHILD` 45, which PL leaves at the equal Java defaults.

**Inputs (`input/ES/`).** All Spanish data, except where listed under "Still outstanding":

- `InitialPopulations/population_initial_ES_2011..2024.csv` — 44-column camelCase schema, `demRgn ∈ {1…7}`; the committed training subset (same years) is in `InitialPopulations/training/`. Start years stop at 2023 (`MAX_START_YEAR`), so the 2024 file is never a starting population.
- `EUROMODoutput/es_2005..2025_std.txt` — EUROMOD ES output (`dct = 13`; the column set varies by system year); tax-unit identifier `tu_nucfam_HeadID`, mapped in `input/system_bu_names.xlsx`. Training subset in `EUROMODoutput/training/`.
- Region terms in the `reg_*.xlsx`: eight workbooks (`education` E1a/E1b, `fertility`, `health` H2, `home_ownership`, `income`, `leave_parental_home`, `partnership`, `retirement`) use `ES1`–`ES6` dummies with `ES7` (Canarias) omitted. `reg_wages` and `reg_employmentSelection` use `ES2`–`ES7` with `ES1` omitted. The multinomial sheets (E2a, H1) carry outcome-specific terms such as `ES1_Medium` and `ES1_Good`. `reg_labourSupplyUtility` and `reg_RMSE` have no region terms.
- Some ES workbooks use shortened regressor names: `Lesdf_c4_{EmpSpouseNotEmp,NotEmpSpouseEmp,BothNotEmp}_L1` (U2), `Reached_Retirement_Age_Les_L1` (R1b) and `InvMillsRatio` (W1*). `Person.DoublesVariables` accepts them as aliases of the longer names the other countries use, and `PersonTest.esRegressorNamesMatchOriginals` checks that each pair agrees. Don't rename them in the workbooks.
- The `reg_*.xlsx`, `reg_RMSE.xlsx` and `scenario_parametricMatching.xlsx` are estimated by the do-files in `input_processing/regression_estimates/ES/with_time_trend/` (master `00_master_regression_estimates_ES.do`, steps `01`–`11`, shared programs in `programs.do`). They save the workbooks to `$dir_work`, a CeMPA Box folder set in the master, and `90_cleaning_excel_inputs.do` then cleans them in place there, keeping only `Info`, `Gof` and the model sheets. Nothing copies them into `input/ES/`.
- `align_popProjections.xlsx` is keyed on `ES1`–`ES7`; `time_series_factor.xlsx` is Spain's uprating series.
- `scenario_retirementAgeFixed.xlsx` follows `Parameters.getStatePensionAge` case `"ES"`: 65 to 2017, 66 for 2018–2023, 67 from 2024, gender-neutral.
- There is no `social_care_parameters.xlsx`. It is optional and read only when `projectSocialCare` is on (off by default); turning it on for ES fails with an explicit error.
- `alignment_adjustment_factors.xlsx` is byte-identical to PL's on purpose, so don't flag it as a copy. All 13 data sheets are zero-filled: zero is the neutral cold start for a fresh calibration. Aligned runs search for the adjustment path and overwrite only the in-memory map. The workbook is never written back, so to reuse calibrated values, copy them in by hand (see the file's own `Info` sheet).
- `src/main/resources/images/ES.png` supplies the GUI flag.

**Labour-supply estimates (`reg_labourSupplyUtility.xlsx`).** Do-files are in `input_processing/labour_supply/ES/do-files/` (master `ES master-elast.do`; PL's counterpart is under `labour_supply/PL/`). The observed choice comes from EUROMOD `lhw`, with hours and earnings set to zero for anyone not currently employed (`les` ∉ {2, 3}). Leisure is in hours in every sheet. Choice-specific regressors are evaluated by `BenefitUnit.EsLabourChoiceRegressor`. They are `Liwwh_k`, `HealthSelfRatedGood_k`, `HealthSelfRatedVeryGoodExcel_k`, `eduDehC4{Medium,High}_k` (adult children) and `eduDehC4High_{Male,Female}_k` (couples; there are no Medium terms). Each codes the alternative `k` as 10 × male band + female band. The income coefficients are in **2023 prices** (EU-SILC 2024 through EUROMOD 2023 systems, not deflated), while the model holds income in 2015 prices. The workbook is left as estimated. Instead, `BenefitUnit` multiplies income in every labour-supply regressor by `Parameters.getLabourSupplyIncomePriceFactor()`, the 2023/2015 inflation ratio from `time_series_factor.xlsx` (ES 1.199; EL 1.158, HU 1.606, IT 1.209, PL 1.435). The price year is set per country by the key `LABOUR_SUPPLY_ESTIMATION_PRICE_YEAR` in `input/<CC>/parameters.xlsx`. The Java field of that name defaults to 2023 and is non-final so the loader can overwrite it.

**Education (`reg_education.xlsx`; estimated by `regression_estimates/ES/with_time_trend/01_reg_education_ES.do`).** E1a uses `Parents_ypnb_Q2..Q5_L1`, the quintile of co-resident parents' lagged summed `ypnbihs_dv`. E1b uses `Parents_known_L1` and `Parents_known_Ydses_Q2..Q5_L1`. `Person.getCoresidentParents()` finds parents among household members only. It matches on simulation ids and, for initial-population adults (whose `idMother`/`idFather` the clone constructor does not copy), on the survey ids in `idMother/FatherImmutable`. `SimPathsModel.updateParentsIncomeQuintiles()` recomputes the quintile cut-offs each year (as Stata `xtile` does, over persons 15+ with a co-resident parent) and is scheduled before `InSchoolAlignment`.

**Still outstanding before `-c ES` is trustworthy:**

- `align_educLevel.xlsx` is still byte-identical to PL's and needs Spanish values.
- The labour-supply estimation sums income over the whole household (`bysort idhh: egen sim_hhcon`), while the model uses benefit-unit income.
- `Parents_known_Ydses_Q*_L1`, like every Ydses lag, reads the lag from the person's *current* benefit unit (`Person.getYdses_c5_lag1()`), whereas Stata lags it per person. It is therefore missing for anyone who has just moved to a new benefit unit. A fix changes PL results too, so it belongs in a separate commit.
- The `Region.ES1`–`ES7` code↔name mapping has not been checked against the EUROMOD ES country report (TODO at `Region.java:22`).

**Data access**: The input data is not freely shareable. Training data is provided for development (PL and ES only), but results from training data should not be interpreted beyond development purposes. Contact maintainers via GitHub issues for real data access.

## Build and Run

Requires **Java 19** and **Maven**.

```bash
# Build both JARs (output: singlerun.jar, multirun.jar in project root)
mvn clean package

# Setup only: build input/input.mv.db for a country and record it in input/DatabaseCountryYear.xlsx
java -jar singlerun.jar -c ES -s 2019 -g false -Setup

# Multi-run simulation (country from the YAML config or DatabaseCountryYear.xlsx; see below)
java -jar multirun.jar -r 100 -p 50000 -n 20 -s 2019 -e 2022 -g false -f

# Run tests
mvn test

# Run a single test class
mvn test -Dtest=SimPathsStartTest
```

CLI help: `java -jar singlerun.jar -h` or `java -jar multirun.jar -h`

### Key CLI flags

- Both jars: `-s` start year, `-e` end year, `-p` population size, `-g true|false` show GUI.
- `singlerun.jar`: `-c <CC>` country code (`EL`, `IT`, `ES`, `HU`, `PL`); `-Setup` setup phase only (build the H2 input DB, no simulation); `--reuse-existing-db` / `--rebuild-db` when running headless. Its `-r` is `--rewrite-policy-schedule`, **not** a seed.
- `multirun.jar`: `-r <seed>` random seed, `-n <N>` max runs, `-f` output to file, `-config <file.yml>` custom config (default `config/default.yml`: 5 runs, 2011–2023, 50,000 persons, seed 1821), `-DBSetup` setup only.
- **`multirun.jar` has no `-c`.** At start-up it reads `input/DatabaseCountryYear.xlsx` for its default country and start year, and fails if that file is missing or names an unknown country. A YAML `countryString` (the English name, e.g. `"Spain"`) or `startYear` overrides them, and `-s` overrides both. `multirun -DBSetup` builds `input/input.mv.db` but does **not** update `DatabaseCountryYear.xlsx`, which only `singlerun.jar` setup writes.
- `-t true|false` (`--training`) — use the training-data subset under `input/<CC>/InitialPopulations/training/` and `EUROMODoutput/training/` (uses `TaxDonorParserTraining`). On `multirun.jar` this **overrides** `parameter_args.trainingFlag` from the YAML config.
- **Training auto-detect**: if `-t` is omitted and `input/<CC>/InitialPopulations/*.csv` is empty, `Parameters.trainingFlag` is flipped to `true` automatically and a notice is printed to stdout (both the headless setup path and the GUI start-up path in `SimPathsStart`). To diagnose which mode is active at runtime, look for either `Training-data flag set explicitly via CLI: -t ...` or `auto-switching to training data` in the console output.
- **Start-year check**: `Parameters.validateStartYear` rejects a start year outside `[MIN_START_YEAR, MAX_START_YEAR]` (the `_TRAINING` pair with `-t true`). It runs before `parameters.xlsx` is loaded, so it checks the Java defaults (2011–2023 in both modes), not the workbook values (`MAX_START_YEAR` 2023 for PL and ES, 2020 for EL/HU/IT; training 2019–2019 for every country). Once loaded, the workbook value decides what happens: a start year above it starts from the population of that last year, with monetary values uprated (`SimPathsModel`, `uprateInitialPopulation`). Keep `MAX_START_YEAR` in step with the newest `population_initial_<CC>_<year>.csv`: a lower value passes the check but silently starts later years from an older population.
- **What the input DB holds, and when to rebuild it**: setup loads the initial population of every start year from `MIN_START_YEAR` to `MAX_START_YEAR`, as set in the workbook (`DataParser`, tables `PERSON_<CC>_<year>` etc.; with `-t true` the `_TRAINING` pair, 2019–2019 in every workbook, so a training DB holds 2019 only) plus the tax-donor tables, so the DB is specific to the country and to training vs actual data, not to the start year. The first run for a given country, start year, population size and `ignoreTargetsAtPopulationLoad` saves its prepared starting population to the DB (`Processed`, `SimPathsModel.getProcessed`), and later runs with the same key reuse it. Rebuild (`-Setup`, `--rebuild-db`, `-DBSetup`) after changing the initial-population or EUROMOD files, after switching `-t`, or after changing how the starting population is prepared; otherwise the cached version is used.

## Architecture

### Entity Hierarchy

**Household → BenefitUnit → Person** (all JPA entities persisted in H2 at `input/input.mv.db`)

- `Person` — individual agent; tracks age, gender, education, employment, health, wages, disability, family links
- `BenefitUnit` — tax/benefit assessment unit; tracks wealth, income, childcare costs, poverty status
- `Household` — container grouping benefit units from the same origin household

### Key Packages

| Package | Role |
|---------|------|
| `simpaths.experiment` | Entry points: `SimPathsStart` (single run), `SimPathsMultiRun` (batch), `SimPathsCollector` (output), `SimPathsObserver` (GUI), `OutputReadme` (run README) |
| `simpaths.model` | Core agents (`Person`, `BenefitUnit`, `Household`), simulation manager `SimPathsModel`, the `*Alignment` classes, `TaxEvaluation` |
| `simpaths.model.decisions` | Dynamic stochastic optimization — consumption/labour/savings via CES utility, grids, expectations |
| `simpaths.model.taxes` | EUROMOD donor population matching for tax/benefit imputation (`DonorPerson`, `DonorTaxImputation`; `database/` holds `MatchIndices`) |
| `simpaths.model.enums` | All enumerations (`Country`, `Region`, `Gender`, `Education`, `Labour`, etc.) |
| `simpaths.data` | Global parameters (`Parameters` static config), regression managers, `RootSearch` (alignment), Mahalanobis distance matching |
| `simpaths.data.startingpop` | Parses and persists the initial EU-SILC population (`DataParser`) |
| `simpaths.data.filters` | Alignment target filters for demographics and economics |
| `simpaths.data.statistics` | Output statistics collection (Gini, poverty, employment rates) |

### Simulation Flow

1. **Setup**: `singlerun.jar -Setup` or `multirun.jar -DBSetup` parses the initial-population CSVs and EUROMOD output into the H2 database `input/input.mv.db`
2. **Build**: `SimPathsModel.buildObjects()` instantiates agents from DB
3. **Annual event loop** (`SimPathsModel.buildSchedule()`; the full order is in `documentation/SimPathsEU_Schedule.xlsx`): ageing → retirement → education (parents' income quintiles, in-school, leaving school) → leaving the parental home → home ownership → disability and health → potential wages → cohabitation, partnership dissolution and union matching → fertility and births → labour market and incomes, including tax/benefit imputation → benefits, consumption, change in EDI → mortality → population alignment → output
4. **Alignment**: each aligned process uses `RootSearch`/`RootSearch2` to find the shift to a probit intercept or labour-supply utility that hits its target share (`alignment_targets_*.xlsx`); population alignment adjusts the population to `align_popProjections.xlsx`. The switches are the `align*` fields of `SimPathsModel`: `alignPopulation` and `alignCohabitation` default to `true`, the rest to `false`. `config/alignment_*.yml` set them through `model_args`.
5. **Collection**: `SimPathsCollector` exports CSV statistics and optional DB snapshots to timestamped `output/` subdirectories

### Statistics output files

Six domain CSVs are written to `output/<run>/csv/`, one row per simulated year unless noted:

| File | Cols | Contents | Toggle |
|------|------|----------|--------|
| `WealthIncomeStatistics.csv` | 31 | Gini, income percentiles, median EDI, S-Index, plus income and wealth by age band | `persistWealthIncomeStatistics` |
| `DemographicStatistics.csv` | 9 | Partnership rates, dependent children, population counts by age band | `persistDemographicStatistics` |
| `HealthStatistics.csv` | 6 | Mean self-rated health and disability shares by age band | `persistHealthStatistics` |
| `LabourStatistics.csv` | 10 | Transitions and participation (16–64), full-time / part-time shares by age band | `persistLabourStatistics` |
| `AlignmentStatistics.csv` | 36 | Alignment adjustment factors, simulated shares, target shares | `persistAlignmentStatistics` |
| `HealthByGender.csv` | 10 | Self-rated health and disability, ages 16–64, Total / Male / Female — **3 rows per year** | `persistHealthByGender` |

Column counts exclude the leading `run`, `time` and `id_<ClassName>` columns. Age bands throughout are 18–29, 30–54 and 55–74. `DemographicStatistics.csv` carries the
population counts that are the denominator for the age-band statistics in the other three
wide files, so keep it enabled when interpreting them.

The microdata files `Person.csv`, `BenefitUnit.csv` and `Household.csv` are written when
`persistPersons`, `persistBenefitUnits` and `persistHouseholds` are on (the default in
`SimPathsCollector`; the integration-test configs switch them off). The validation do-files need
them. `OutputReadme` writes a `README.md` beside the CSVs recording the run configuration. In a
multi-run, `ExportCSV` fixes its directory once per JVM, so every run's CSVs land in the first
run's `output/<timestamp>/csv/`, told apart by the `run` column. The per-run
`output/<timestamp>_<seed>_<n>/` folders hold only `database/`.

Two rules in JAS-mine's `microsim.data.ExportCSV` (verified against 4.3.24) govern all of this:

1. **The filename is the runtime type handed to `DataExport`.** For a `Collection` it is
   `getSimpleName()`; for a bare object it is `getSimpleName() + <PanelEntityKey id>`. That
   trailing `1` is why these files used to be `Statistics1.csv`, `Statistics21.csv`,
   `EmploymentStatistics1.csv`, `HealthStatistics1.csv` and
   `AlignmentAdjustmentFactors1.csv`. They are now wrapped in `List.of(...)` in
   `SimPathsCollector.buildObjects()` so they take the collection branch. Renaming an output
   therefore means renaming its class.
2. **CSV columns are Java field names, sorted alphabetically** (a `TreeSet` over non-`@Transient`
   fields). The `@Column` annotation names only the H2 database column — renaming it changes
   nothing in the CSV, while renaming a field renames *and reorders* the CSV column.

The four wide outputs are fed from one shared traversal of the population,
`AgeBandAggregates`, cached per simulated year in `SimPathsCollector.ageBands()`. Each output
has an independent toggle and its own dump event, so none may assume another has run.

Twelve columns of the former `Statistics21.csv` were calibration loss-function terms, not
statistics: a hard-coded pooled-2019-UKHLS target was subtracted from the simulated value
invisibly, so shares were reported negative and expenditure below zero. Nothing read them and
the targets were meaningless for the EU countries, so they were deleted —
`labNoWork*Share` (recoverable as 1 − full-time − part-time), `x*Avg`, `xToLeisureRatio` and
`statYDisp*Avg`. `statYDispGrossOfLosses*Avg` is a level and survives. `statYLab*Avg` was
renamed `statYLabWeeklyPerWorker*Avg` because, unlike every income column beside it, it is
weekly, unequivalised and per worker rather than monthly, equivalised and per capita.

**When renaming an exported entity**, an IDE rename does not reach everything: the class in
`data/statistics/`, the `SimPathsCollector` fields / `Processes` constants / `onEvent` cases /
`buildObjects` / `buildSchedule` / `@GUIparameter` toggles and accessors, the
`persistence.xml` entity list, the `persist*` **YAML config keys** (resolved via
`getDeclaredField`, so a stale key is silently ignored rather than an error), the integration
test paths and method names, the golden CSVs (including the `id_<ClassName>` header label),
the file descriptions in `OutputReadme`, the Stata validation do-files under `validation/`,
and this file.

### Data Inputs

- `input/input.mv.db` — H2 database with processed EU-SILC starting population
- `input/[COUNTRY]/InitialPopulations/` — actual starting-population CSVs; `…/training/` holds the shipped training subset
- `input/[COUNTRY]/EUROMODoutput/` — EUROMOD donor CSVs; `…/training/` holds the training subset
- `input/[COUNTRY]/` — country-specific Excel parameter files (e.g. `parameters.xlsx`, `EUROMODpolicySchedule.xlsx`, `reg_*.xlsx`, `alignment_targets_*.xlsx`)
- `input/DatabaseCountryYear.xlsx` — the country and start year of the last `singlerun.jar` setup. It is tracked in git but rewritten by every such setup, and `multirun.jar` reads its defaults from it (see Key CLI flags)
- `input/system_bu_names.xlsx` — EUROMOD benefit-unit identifier per country
- `config/default.yml` — Default multi-run parameters (population size, year range, run count)
- `config/alignment_*.yml` — Staged alignment scenarios (`00` population alignment off … `05` population + fertility + cohabitation + in-school + employment). They set no `countryString`, so they run the country recorded in `DatabaseCountryYear.xlsx`
- `config/test_create_database_<CC>.yml`, `config/test_run_<CC>.yml` — Configs used by that country's integration test (`PL`, `ES`)

### Repository layout (beyond `src/`)

- `scripts/run_alignment_multiruns.sh` — runs the alignment scenarios `00`–`04` (not `05`) through `multirun.jar` and moves each one's CSV folder to `output/<scenario>/`, the layout the validation do-files expect
- `input_processing/` — Stata do-files that prepare model inputs upstream of the Java pipeline:
  - `data_construction/` — EU-SILC panel construction (`SILC_panel_construction/2005_2023_panel/`) and the unique input dataset (UID) behind the initial populations, for ES and PL (`UID_construction/<CC>/`, master `00_master_data_set_construction_<CC>.do`)
  - `regression_estimates/<CC>/` — estimation do-files (PL: `00_master_regression_estimates_PL.do`, `01`–`10`; ES: in `ES/with_time_trend/`, `00_master_regression_estimates_ES.do`, `01`–`11` and `90_cleaning_excel_inputs.do`). The masters point their paths at the CeMPA Box share, not at this repository
  - `labour_supply/<CC>/do-files/` — labour-supply estimation (ES, PL)
  - `alignment_targets/<CC>/` — build the alignment-target workbooks from the initial populations (`01`–`05` for retirement, in-school, disability, partnership and employment; `91_plot_targets_from_xlsx.do` for plots) for ES and PL. EL/HU/IT keep older versions in `input/<CC>/DoFilesTargets/`
  - `time_series/ES/do_files/` — Spain's time series (inflation, GDP, wage growth, fertility, mortality, population projections; master `00_master.do`)
  - `key_function_thresholds/` — income thresholds for the tax-donor key function (`KEY_FUNCTION_HU2_*` in `parameters.xlsx`)
  - `00_master_conditions_{ES,PL}.do` (sample conditions), `93_generate_lag_structure.do` (writes `documentation/SimPaths_lag_structure_<CC>.xlsx`)
- `documentation/` — `SimPathsEU_Variable_Codebook.xlsx` (variable codebook), `SimPathsEU_Schedule.xlsx` (yearly process order), `SimPaths_Stata_Parameters.xlsx`, `SimPaths_lag_structure_{ES,PL}.xlsx`
- `validation/` — Stata validation (see Validation below)
- `output/` — timestamped simulation outputs (created at runtime)

### Tax/Benefit Imputation

Uses a donor population approach: simulated persons are matched to EUROMOD-processed donors using Mahalanobis distance. Key classes: `DonorTaxImputation`, `TaxEvaluation`, `MatchIndices`.

### Decisions Module

Solves dynamic stochastic problems over a discretised state space (`Grid`, `Grids`, `States`, `Axis`). `ExpectationsFactory` constructs transition expectations; `CESUtility` evaluates utility. Results are stored in grid files loaded at startup.

## Testing

JUnit 5 + Mockito. Tests in `src/test/java/simpaths/`:

- `experiment/SimPathsStartTest` — CLI argument parsing, country validation
- `experiment/SimPathsMultiRunTest` — Multi-run configuration
- `experiment/PersonTest` — Person entity logic (including the ES regressor-name aliases)
- `data/MahalanobisDistanceTest` — Statistical matching
- `integrationtest/SimPathsIntegrationTestBase` — the shared, country-agnostic machinery; a country test is a subclass naming only its two configs
- `integrationtest/RunSimPathsPLIntegrationTest` — end-to-end run for **Poland**, `config/test_create_database_PL.yml` + `config/test_run_PL.yml` (`trainingFlag: true`)
- `integrationtest/RunSimPathsESIntegrationTest` — the same run for **Spain**, `config/test_create_database_ES.yml` + `config/test_run_ES.yml` (`trainingFlag: true`)

The integration tests are excluded from `mvn test` (surefire) and run under failsafe:

```bash
mvn clean package -DskipTests                       # the tests shell out to multirun.jar, so build it first
mvn verify -Dit.test=RunSimPathsPLIntegrationTest   # Poland only
mvn verify -Dit.test=RunSimPathsESIntegrationTest   # Spain only
mvn verify                                          # both, sequentially
```

Output folders and golden-file folders are both derived from the country code and `parameter_args.trainingFlag`, so adding a country needs no path wiring:

```
output/INTEGRATION_TESTS[_TRAINING]_<CC>/csv/                    # produced by the run
src/test/java/simpaths/integrationtest/expected[_training]_<CC>/ # diffed against
```

Both countries default to `trainingFlag: true`, so both baselines are **committed** and CI-checked; the real-data baselines are gitignored and captured locally per developer (see `expected_<CC>/INTEGRATION_TEST_REGENERATION.md`). The flag lives only in the run config — the test passes it to the `-DBSetup` step as `-t`, so the `test_create_database_<CC>.yml` files do not repeat it.

Five CSVs are diffed: `WealthIncomeStatistics`, `DemographicStatistics`, `HealthStatistics`, `HealthByGender` and `LabourStatistics`. `AlignmentStatistics.csv` is only checked for existence. The test configs set no `model_args`, so the runs use `SimPathsModel`'s defaults: changing a default moves both baselines, as switching `alignCohabitation` to `true` did. To regenerate a baseline after an intentional behaviour change, run the test, then copy those five CSVs from `output/INTEGRATION_TESTS_TRAINING_<CC>/csv/` into `expected_training_<CC>/` (full steps in that folder's `INTEGRATION_TEST_REGENERATION.md`). Copy only the CSVs. The instructions file is deliberately not called `README.md`, because each run writes its own `README.md` beside the CSVs and copying a whole output folder once overwrote the instructions; don't rename it back.

Because each country has its own folders, either test can be run on its own, in any order. They do share `input/input.mv.db`, which each test rebuilds in its own `-DBSetup` step, so never run them concurrently. Both configs name their country (`countryString`), so `input/DatabaseCountryYear.xlsx` only needs to exist.

## Branch Conventions

- `main` — stable release; `develop` — integration. PRs target `develop` on `simpaths/SimPathsEU`, and `develop` is merged into `main` by PR.
- Working branches carry the author's initials or the workstream rather than a type prefix, e.g. `AB_ES_and_PL_validation_plot_files`, `MV-organise-output-csv`, `ES-extension-*`, `JW/pr/...`. Some work reaches `develop` through PRs from the fork `Mariia-Var/SimPathsEU`.

## Validation

Stata do-files in `validation/` compare model estimates and simulated output against EU-SILC and EUROMOD targets:

- `01_estimate_validation/do_files/` — validation of the regression estimates (PL only; master `00_master_estimate_validation_PL.do`).
- `02_simulation_validation_graphs/<CC>/do_files/` (ES, PL) — plots of multi-run output against EU-SILC targets, by alignment scenario (master `00_master_<CC>.do`, whose scenario list runs `00`–`04`). They read `Person.csv`, `BenefitUnit.csv`, `Household.csv` and `AlignmentStatistics.csv` from `<dir_sim_output>/<alignment_scenario>/csv/`, so keep the microdata toggles on, and they do not work on single-run output.
