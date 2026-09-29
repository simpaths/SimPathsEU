# SimPaths simulation output

Country: **PL**  
Written: 2026-09-29 13:01:57

This folder holds the CSV output of a simulation experiment. The settings below
are those it was executed under; they are recorded here because output folders
are kept long after the configuration that produced them has moved on.

## Run configuration

| Setting | Value |
|---|---|
| Runs in this experiment | 2 |
| Population size | 20000 |
| Start year | 2019 |
| End year | 2022 |
| Random seeds | 100 to 101 (run *k* uses 100 + *k* - 1) |
| Base price year | 2015 |
| Training data | yes |

**This run used the training-data subset.** Results are for development only and
should not be interpreted as estimates for this country.

## Model options

| Option | State |
|---|---|
| Bootstrap all regression coefficients | on |
| Intertemporal optimisations | off |
| Project mortality | on |
| Alignment: population | off |
| Alignment: fertility | off |
| Alignment: cohabitation | off |
| Alignment: in school | off |
| Alignment: employment | off |
| Alignment: retirement | off |
| Alignment: disability | off |
| Alignment: education | off |

Diagnostics for the alignment routines that ran are in `AlignmentStatistics.csv`,
which reports the adjustment factor, the simulated share and the target share each year.

## Files in this folder

Age bands used by the annual statistics are 18-29, 30-54 and 55-74.

### `WealthIncomeStatistics.csv`

*one row per year*

Income and wealth. Gini coefficients for market and equivalised disposable income, income percentiles, median equivalised disposable income and the S-Index, plus labour, investment and pension income, investment losses, disposable income gross of losses, and wealth by age band.

### `DemographicStatistics.csv`

*one row per year*

Demographics by age band: share cohabiting, average dependent children, and population counts. The population counts are the denominator for the age-band statistics reported in the other files.

### `HealthStatistics.csv`

*one row per year*

Population health by age band: average self-rated health and the share reporting a long-term disability.

### `LabourStatistics.csv`

*one row per year*

Labour market outcomes. Employment and unemployment shares for ages 16-64 and the transition rates between them, plus full-time and part-time shares by age band.

### `AlignmentStatistics.csv`

*one row per year*

Alignment diagnostics: adjustment factors together with the simulated and target shares for each aligned process.

### `HealthByGender.csv`

*three rows per year*

Self-rated health and disability for ages 16-64: the share in each self-rated health category (poor, fair, good, very good, excellent), the share long-term sick or disabled, and the observation counts each is based on. Written once per gender group each year - Total, Male and Female - identified by the `demSex` column.


## Reading the files

- Every file opens with `run`, `time` and an `id_<name>` column. `run` identifies the
  simulation run - where several runs share an output folder they all appear in the same
  file - `time` is the simulated year, and the id column is a constant for the annual
  statistics.
- Remaining columns are ordered alphabetically by variable name, not by topic.
- Financial variables are in real prices of the base price year given above,
  and are monthly and equivalised unless the variable name says otherwise.
- Variables carrying `WeeklyPerWorker` are weekly, averaged over workers rather than
  over the population, and are not equivalised.

