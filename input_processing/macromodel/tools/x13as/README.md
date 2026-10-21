# X-13ARIMA-SEATS (not tracked)

`stata/make_datasets_hicp_uk.do` seasonally adjusts the UK price level (ONS CPI, D7BT)
with the U.S. Census Bureau's X-13ARIMA-SEATS, called from Stata by `stata/x13_seats.ado`.
It expects the Windows ASCII-output build here, as `x13as_ascii.exe`. The binary is not
in git (`.gitignore`): the tracked `stata/hicp_q_sa_uk.dta` is the cached result, so
X-13 is needed only to regenerate that file, the same status EViews has for
`stata/hicp_q_sa.dta`. X-13 is to replace EViews for every country (see "Next step"
in `../../README.md`), which leaves it the only seasonal-adjustment tool in stage 1.

| | |
|---|---|
| Version | 1.1 Build 62 |
| Source | https://www2.census.gov/software/x-13arima-seats/x13as/windows/program-archives/x13as_ascii-v1-1-b62.zip |
| Archive SHA-256 | `C6BD65132A3219555D00ABF794649E75C133F23C0DB066ED03C0B5CA30E694C2` |
| `x13as_ascii.exe` SHA-256 | `2E43194361EE096797F0431765193C316196EA6776F11535E76281A413D49669` |

Unzip `x13as_ascii.exe` into this folder and check its SHA-256 (`certutil -hashfile
x13as_ascii.exe SHA256` on Windows) before running.

Replacing the binary changes the seasonally adjusted CPI, and with it the UK's DSGE
inflation observable. Treat an upgrade like any other data-vintage change: regenerate
`hicp_q_sa_uk.dta`, re-run the pipeline with estimation, and update the version above
and in `make_datasets_hicp_uk.do`.
