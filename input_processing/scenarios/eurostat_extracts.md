# Eurostat extracts used by the scenario builders

## `eurostat_proj_23naasfr_PL.csv`

| | |
|---|---|
| Dataset | `proj_23naasfr`, EUROPOP2023: assumptions for fertility rates by age and type of projection |
| Selection | annual (`A`), projection `BSL` (baseline), all ages, unit `NR`, geo `PL` |
| Query | `https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/proj_23naasfr/A.BSL..NR.PL?format=SDMX-CSV` |
| Downloaded | 2026-11-09 (Eurostat's `LAST UPDATE` of the data: 24/05/23) |
| Access | public, no account or licence step needed |

Content: header `DATAFLOW,LAST UPDATE,freq,projection,age,unit,geo,TIME_PERIOD,OBS_VALUE,OBS_FLAG,CONF_STATUS`,
3,002 rows: the years 2022-2100 for each of the ages `TOTAL` (total fertility rate), `Y_LT15`, `Y15` to `Y49`
and `Y_GE50`. The values are live births per woman of that age in that year. For 2030 the rate at age 29 is
0.10812 and the total fertility rate is 1.45404.

Use: `build_migration_scenario.do` gives migrant women of each age 15-49 the rate of the year (`Y15` to
`Y49`; the rates of the extract's last year for any later year) and computes their births from it. `TOTAL`,
`Y_LT15` and `Y_GE50` are not used (the two open-ended ages are 0.00001 or 0.00002 in every year). The
do-file reads this local copy and never fetches from the web.

Download, from the repository root (Bash; for another country replace `PL` in the query and the file name):

```bash
curl -s -m 120 "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/proj_23naasfr/A.BSL..NR.PL?format=SDMX-CSV" -o input_processing/scenarios/eurostat_proj_23naasfr_PL.csv
```

A new download replaces the rates of a scenario only when its builder is rerun; rerun it for every scenario
folder built from the extract.
