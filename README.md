# SimPathsEU

by CeMPA (Centre for Microsimulation and Policy Analysis).

## Documentation

The entire SimPaths documentation is available on its [website](https://simpaths.github.io/SimPaths/), which includes: a detailed description of its building blocks; instructions on how to set up and run the model; and information about contributing to the model's development. The `documentation/` directory contains supplementary materials that complements this README (model specifications, variable references, etc.).

## Introduction

SimPaths is a family of models for individual and household life course events, all sharing common components. The framework is designed to project life histories through time, building up a detailed picture of career paths, family (inter)relations, health, and financial circumstances. The framework builds upon standardised assumptions and data sources, which facilitates adaptation to alternative countries. This repository, **SimPathsEU**, covers Greece (`EL`), Hungary (`HU`), Italy (`IT`), and Poland (`PL`), and integrates with EUROMOD for tax and benefit policy simulation. Careful attention is paid to model validation, and sensitivity of projections to key assumptions. The modular nature of the SimPaths framework is designed to facilitate analysis of alternative assumptions concerning the tax and benefit system, sensitivity to parameter estimates and alternative approaches for projecting labour/leisure and consumption/savings decisions. 


## License

Released under the terms in [`license.txt`](license.txt).

## Repository layout

```
SimPathsEU/
├── src/                   # Java source (main + tests)
├── input/                 # H2 DB + per-country starting populations and EUROMOD outputs
│   └── <CC>/InitialPopulations/{,training/}
│   └── <CC>/EUROMODoutput/{,training/}
├── input_processing/      # Stata do-files that prepare regression estimates and inputs
├── config/                # YAML configs (default.yml, alignment_*.yml, test_*.yml)
├── scripts/               # Bash wrappers for batch multi-run scenarios
├── validation/            # Stata validation against EU-SILC / EUROMOD targets
├── documentation/         # Supplementary documentation
├── output/                # Simulation outputs (created at runtime)
├── pom.xml
└── README.md
```

## Getting Started

To contribute to this project, you need to fork the repository and set up your development environment.

### Access to Data

We are committed to maintaining transparency and open-source principles in this project. All the code, documentation, and resources related to our project are available on GitHub for you to explore, use, and contribute to.

The data used by this project is not freely shareable. If you are interested in accessing the data necessary to run the simulation, get in touch with the repository maintainers for further instructions.

However, please note that _training_ data is provided. It allows the simulation to be run and developed, but results obtained on the basis of the training dataset should not be interpreted, except for the purpose of training and development. 


### Forking the Repository

1. Click the "Fork" button at the top-right corner of this repository.
2. Untick the `Copy only the main branch` box.
3. This will create a copy of the repository in your own GitHub account.
4. Follow [instructions here](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/syncing-a-fork) to periodically synchronize your fork with the most recent version of this ("upstream") repository. This will ensure you use an up-to-date version of the model.

### Setting up your development environment
1. **Java Development Kit (JDK):** the project targets **Java 19 or later** (see `pom.xml`, which pins `source`/`target` to 19). Install a compatible JDK, e.g. OpenJDK 19+ from [Adoptium](https://adoptium.net/).
2. **Maven:** required to build from the command line. See [installation instructions](https://maven.apache.org/install.html). (Not required if you only build via the IDE.)
3. **Download an IDE** (integrated development environment) of your choice - we recommend [IntelliJ IDEA](https://www.jetbrains.com/idea/download/); download the Community (free) or Ultimate (paid) edition, depending on your needs.
4. Clone your forked repository to your local machine. Import the cloned repository into IntelliJ as a Maven project.

### Compiling and running SimPaths with Maven from the CLI

SimPaths can also be compiled with Maven ([installation instructions here](https://maven.apache.org/install.html)) and run from the command line without an IDE. After cloning the repository and setting up the JDK, in the root directory you can run:
```
$ mvn clean package
```
... to create two runnable jars for single- and multi-run SimPaths:
```
.
SimPaths/
      ...
      |-- multirun.jar
      |-- singlerun.jar
      `-- src
```

To build without running the unit test suite (faster turnaround during development):
```
$ mvn clean package -DskipTests
```

#### Running tests

Unit tests run by default as part of the `test` / `package` phases. Integration tests (which exercise a full end-to-end simulation) are bound to the `verify` phase:
```
$ mvn verify                                          # run unit + integration tests
$ mvn verify -Dit.test=RunSimPathsIntegrationTest     # run just the integration test
```

#### Single run

`singlerun.jar` runs a single SimPaths simulation and is also the entry point used to build/rebuild the input population database. It takes the following options:

- `-c` Country (e.g. `EL`, `HU`, `IT`, `PL`) — **required for the initial setup**
- `-s` Start year
- `-e` End year
- `-p` Simulated population size
- `-g` [true/false] show/hide gui
- `-r` Re-write policy schedule from detected policy files
- `-Setup` perform the setup phase only (build the input population database, then exit)
- `--rebuild-db` Force a rebuild of `input/input.mv.db` instead of reusing it (headless mode)
- `--reuse-existing-db` Reuse `input/input.mv.db` if present, otherwise build it (headless mode)
- `-t` [true/false] use training data subset. When `true`, reads from `input/<COUNTRY>/InitialPopulations/training/` and `input/<COUNTRY>/EUROMODoutput/training/`. When `false` (default), reads from `InitialPopulations/` and `EUROMODoutput/` directly. If `-t` is omitted, an auto-detect kicks in: if `InitialPopulations/<country>/*.csv` is empty, the simulator falls back to training data and prints a console message.

**Important:** the country (`-c`) and start year (`-s`) must be specified when creating or rebuilding the input population database — the resulting `input/input.mv.db` is country- and year-specific.

**Important — switching between training and actual data:** `reuseExistingDatabase = true` (the default for headless `singlerun`) reuses `input/input.mv.db` *without* checking which mode it was built in. If you switch the `-t` flag (e.g. from `false` to `true`), you **must** also pass `--rebuild-db` (or `-Setup`) — otherwise the simulation silently runs against a stale DB built from the other dataset.

Typical workflows:
```
# 1. Build (or rebuild) input.mv.db for a given country/start year.
#    Both commands below rebuild the database identically — pick ONE,
#    based on what you want to happen after the rebuild finishes:
#
#    Option 1 — rebuild the database and exit (no simulation).
#               Use this to prep the DB ahead of a multirun.
$ java -jar singlerun.jar -c PL -s 2011 -g false -Setup
#
#    Option 2 — rebuild the database and then run a single-run simulation
#               straight after, using the freshly built DB.
$ java -jar singlerun.jar -c PL -s 2011 -g false -e 2013 -p 30000 --rebuild-db

# 2. Run a single-run simulation on an existing input.mv.db (reuse as-is,
#    or build it first if missing — no rebuild if it already exists)
$ java -jar singlerun.jar -c PL -s 2011 -g false -e 2013 -p 30000 --reuse-existing-db

# 3. Run a single-run simulation using the default DB-handling behaviour (no
#    flag needed): reuses input.mv.db if present, builds it first if missing
$ java -jar singlerun.jar -c PL -s 2011 -g false -e 2013 -p 30000

# 4. Switch to training data — note that --rebuild-db (or -Setup) is REQUIRED
#    when changing -t, otherwise input.mv.db from the previous mode is reused.
$ java -jar singlerun.jar -c PL -s 2019 -g false -t true --rebuild-db
$ java -jar singlerun.jar -c PL -s 2019 -g false -e 2022 -p 20000 -t true

# 5. Switch back to actual data — again, rebuild the DB when toggling -t.
$ java -jar singlerun.jar -c PL -s 2017 -g false -t false --rebuild-db
```

#### Multi run

For multiple runs, `multirun.jar` takes the following options:

- `-r` random seed for first run (incremented by +1 for subsequent runs)
- `-p` simulated population size
- `-n` number of runs
- `-s` start year of runs
- `-e` end year of runs
- `-g` [true/false] show/hide gui
- `-f` write console output and logs to file (in 'output/logs/run_[seed].txt')
- `-config <file>` use a custom YAML config from `config/` instead of `default.yml`. `<file>` is a bare
  filename resolved *relative to* `config/` (e.g. `-config ramsey-feedback-persistent.yml`) — the loader
  prepends `config/` itself, so passing a path that already includes it (`-config config/foo.yml`) looks
  for `config/config/foo.yml`, prints one "Config file ... not found" line to stderr, and returns **without
  running a simulation, exiting 0**. A script that only checks the exit code will not notice.
- `-DBSetup` build the input population database for the configured country/start year, then exit
- `-t` [true/false] use training data subset (same semantics as for `singlerun`). Overrides `parameter_args.trainingFlag` from the YAML config. The same caveat applies: if you switch `-t`, also rebuild the DB with `-DBSetup` before running the multirun.

**Note:** `multirun.jar` does **not** take a `-c` country flag — it resolves the country from `input/DatabaseCountryYear.xlsx`. Make sure that file reflects the country you intend to run.

**Before running multiruns:**
1. Ensure `input/DatabaseCountryYear.xlsx` is populated with the country/year combination you intend to run — multirun reads it to resolve the country and start year.
2. Rebuild the input database whenever it needs to be refreshed (especially when changing the start year). A different population size alone does not require a rebuild: the processed starting population is resampled to match the requested size.

Typical multirun workflow:
```
# 1. (Re)build the input database for the configured country/start year
$ java -jar multirun.jar -DBSetup -s 2011 -g false

# 2. Run N simulations over a year range
$ java -jar multirun.jar -g false -s 2011 -e 2013 -p 30000 -n 3

# 3. Training data — rebuild DB and run with -t true.
#    REQUIRED to rebuild when toggling -t (same caveat as singlerun).
$ java -jar multirun.jar -DBSetup -s 2019 -g false -t true
$ java -jar multirun.jar -s 2019 -e 2022 -p 20000 -n 2 -g false -t true
```

Example with explicit seed and logging:
```
$ java -jar multirun.jar -r 100 -p 50000 -n 20 -s 2017 -e 2020 -g false -f
```

Run `java -jar singlerun.jar -h` or `java -jar multirun.jar -h` to show these help messages.

#### Output layout

Each simulation writes a timestamped subdirectory under `output/` (named `YYYYMMDDHHMMSS`), e.g.:

```
output/
├── <YYYYMMDDHHMMSS>/            # one run's artefacts
│   ├── database/                # H2 snapshot of the simulated population
│   └── input/                   # copy of the inputs used for the run (for reproducibility)
└── logs/
    ├── run_<seed>.txt           # console log when multirun is invoked with -f
    └── run_<seed>.log           # logger output for the same run
```

Batch scripts in `scripts/` move each scenario's outputs into `output/<scenario-name>/` after the runs finish.


### Batch scenario scripts

Helper Bash scripts in `scripts/` run `multirun.jar` across multiple alignment configs in sequence and move each scenario's output into `output/<scenario-name>/`:
- `run_alignment_multiruns.sh` — full set of alignment scenarios


Defaults (start/end year, population size, runs per scenario, JVM heap, random seed) are set at the top of each script and can be overridden via environment variables, e.g.:
```
$ POP_SIZE=10000 RUNS_PER_SCENARIO=2 ./scripts/run_alignment_multiruns.sh
```

### Contributing

1. Create a new branch for your contributions. This will likely be based on either the `main` branch of this repository (if you seek to modify the stable version of the model) or `develop` (if you seek to modify the most recent version of the model).
2. Make your changes, add your code, and write tests if applicable.
3. Commit your changes.
4. Push your changes to your fork.
5. Open a Pull Request (PR) on this repository from your fork. Be sure to provide a detailed description of your changes in the PR.
