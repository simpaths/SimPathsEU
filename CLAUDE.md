# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SimPaths is a JAS-mine-based microsimulation model that projects individual and household life course events (career, family, health, finances) for EU countries. This repository covers Greece (EL), Italy (IT), Hungary (HU), and Poland (PL). It integrates with EUROMOD for tax/benefit policy simulation.

**Data access**: The input data is not freely shareable. Training data is provided for development, but results from training data should not be interpreted beyond development purposes. Contact maintainers via GitHub issues for real data access.

## Build and Run

Requires **Java 19** and **Maven**.

```bash
# Build both JARs (output: singlerun.jar, multirun.jar in project root)
mvn clean package

# Run setup phase (creates input population database, no simulation)
java -jar singlerun.jar -c IT -s 2017 -g false -Setup

# Run multi-run simulation
java -jar multirun.jar -r 100 -p 50000 -n 20 -s 2017 -e 2020 -g false -f

# Run tests
mvn test

# Run a single test class
mvn test -Dtest=SimPathsStartTest
```

CLI help: `java -jar singlerun.jar -h` or `java -jar multirun.jar -h`

### Key CLI flags

- `-c <CC>` country code (`EL`, `IT`, `HU`, `PL`); `-s` start year; `-e` end year; `-p` population size; `-g true|false` show GUI.
- `-t true|false` (`--training`) — use the training-data subset under `input/<CC>/InitialPopulations/training/` and `EUROMODoutput/training/` (uses `TaxDonorParserTraining`). On `multirun.jar` this **overrides** `parameter_args.trainingFlag` from the YAML config.
- `singlerun.jar -Setup` — setup phase only (build the H2 input DB, no simulation). Multi-run equivalent is `-DBSetup`.
- `multirun.jar -r <seed>` random seed, `-n <N>` max runs, `-f` output to file, `-config <file.yml>` custom config (default `config/default.yml`).
- **Training auto-detect**: if `-t` is omitted and `input/<CC>/InitialPopulations/*.csv` is empty, `Parameters.trainingFlag` is flipped to `true` automatically and a notice is printed to stdout (`SimPathsStart.java:363-368, 520-525`). To diagnose which mode is active at runtime, look for either `Training-data flag set explicitly via CLI: -t ...` or `auto-switching to training data` in the console output.

## Architecture

### Entity Hierarchy

**Household → BenefitUnit → Person** (all JPA entities persisted in H2 at `input/input.mv.db`)

- `Person` — individual agent; tracks age, gender, education, employment, health, wages, disability, family links
- `BenefitUnit` — tax/benefit assessment unit; tracks wealth, income, childcare costs, poverty status
- `Household` — container grouping benefit units from the same origin household

### Key Packages

| Package | Role |
|---------|------|
| `simpaths.experiment` | Entry points: `SimPathsStart` (single run), `SimPathsMultiRun` (batch), `SimPathsCollector` (output), `SimPathsObserver` (GUI) |
| `simpaths.model` | Core agents (`Person`, `BenefitUnit`, `Household`) and simulation manager `SimPathsModel` |
| `simpaths.model.decisions` | Dynamic stochastic optimization — consumption/labour/savings via CES utility, grids, expectations |
| `simpaths.model.taxes` | EUROMOD donor population matching for tax/benefit imputation (`DonorPerson`, `TaxEvaluation`) |
| `simpaths.model.enums` | All enumerations (`Country`, `Region`, `Gender`, `Education`, `ActivityStatus`, etc.) |
| `simpaths.data` | Global parameters (`Parameters` static config), regression managers, Mahalanobis distance matching |
| `simpaths.data.startingpop` | Parses and persists the initial EU-SILC population |
| `simpaths.data.filters` | Alignment target filters for demographics and economics |
| `simpaths.data.statistics` | Output statistics collection (Gini, poverty, employment rates) |

### Simulation Flow

1. **Setup**: `SimPathsStart` loads input population into H2 database
2. **Build**: `SimPathsModel.buildObjects()` instantiates agents from DB
3. **Annual event loop** fires transitions: demographics (partnerships, births, deaths, retirement) → labour market → tax/benefit evaluation → health/disability
4. **Alignment**: Mahalanobis-distance resampling adjusts distributions to match targets (YAML configs in `config/alignment_*.yml`)
5. **Collection**: `SimPathsCollector` exports CSV statistics and optional DB snapshots to timestamped `output/` subdirectories

### Data Inputs

- `input/input.mv.db` — H2 database with processed EU-SILC starting population
- `input/[COUNTRY]/InitialPopulations/` — actual starting-population CSVs; `…/training/` holds the shipped training subset
- `input/[COUNTRY]/EUROMODoutput/` — EUROMOD donor CSVs; `…/training/` holds the training subset
- `input/[COUNTRY]/` — country-specific Excel parameter files (e.g. `EUROMODpolicySchedule.xlsx`)
- `input/DatabaseCountryYear.xlsx` — Cross-country/year index
- `config/default.yml` — Default multi-run parameters (population size, year range, run count)
- `config/alignment_*.yml` — Staged alignment configurations
- `config/test_create_database.yml`, `config/test_run.yml` — Configs used by the integration test

### Repository layout (beyond `src/`)

- `scripts/` — shell wrappers for batch multi-runs (`run_alignment_multiruns.sh`, `run_multiruns-alignPopOFF.sh`, `run_TEST_multiruns.sh`, …)
- `input_processing/` — Stata do-files that prepare model inputs upstream of the Java pipeline (master conditions, regression-estimate cleaning, lag-structure generation)
- `tools/generate_simpaths_eu_variable_codebook.py` — variable codebook generator
- `validation/` — Stata validation against EU-SILC/EUROMOD targets
- `documentation/` — supplementary documentation
- `output/` — timestamped simulation outputs (created at runtime)

### Tax/Benefit Imputation

Uses a donor population approach: simulated persons are matched to EUROMOD-processed donors using Mahalanobis distance. Key classes: `DonorTaxImputation`, `TaxEvaluation`, `MatchIndices`.

### Decisions Module

Solves dynamic stochastic problems over a discretised state space (`Grid`, `Grids`, `States`, `Axis`). `ExpectationsFactory` constructs transition expectations; `CESUtility` evaluates utility. Results are stored in grid files loaded at startup.

## Testing

JUnit 5 + Mockito. Tests in `src/test/java/simpaths/`:

- `experiment/SimPathsStartTest` — CLI argument parsing, country validation
- `experiment/SimPathsMultiRunTest` — Multi-run configuration
- `experiment/PersonTest` — Person entity logic
- `data/MahalanobisDistanceTest` — Statistical matching
- `integrationtest/RunSimPathsIntegrationTest` — End-to-end run using `config/test_create_database.yml` + `config/test_run.yml`

## Branch Conventions

- `main` — stable release
- `develop` — integration
- `feature/name` — new features
- `bugfix/issue-number-description` — bug fixes
- `experimental/description` — exploratory work
- `docs/topic` — documentation

## Validation

Stata do-files in `validation/` compare simulated output against EU-SILC and EUROMOD targets.
