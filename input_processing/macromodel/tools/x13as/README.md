# X-13ARIMA-SEATS (not tracked)

Stage 1 seasonally adjusts the price level with the U.S. Census Bureau's
X-13ARIMA-SEATS, called from Stata by `stata/x13_seats.ado` with the settings in
`stata/x13_settings.do`: `stata/make_datasets_hicp.do` for the Eurostat HICP of every
country, `stata/make_datasets_hicp_uk.do` for the UK's ONS CPI (D7BT). It expects the
Windows ASCII-output build here, as `x13as_ascii.exe`. The binary is not in git
(`.gitignore`): the tracked `stata/hicp_q_sa.dta` and `stata/hicp_q_sa_uk.dta` are the
cached results, so X-13 is needed only to regenerate those files.

| | |
|---|---|
| Version | 1.1 Build 62 |
| Source | https://www2.census.gov/software/x-13arima-seats/x13as/windows/program-archives/x13as_ascii-v1-1-b62.zip |
| Archive SHA-256 | `C6BD65132A3219555D00ABF794649E75C133F23C0DB066ED03C0B5CA30E694C2` |
| `x13as_ascii.exe` SHA-256 | `2E43194361EE096797F0431765193C316196EA6776F11535E76281A413D49669` |

Unzip `x13as_ascii.exe` into this folder and check its SHA-256 (`certutil -hashfile
x13as_ascii.exe SHA256` on Windows) before running.

Replacing the binary changes the seasonally adjusted HICP, and with it every country's
DSGE inflation observable. Treat an upgrade like any other data-vintage change:
regenerate both `.dta` files, re-run the pipeline with estimation for every committed
bundle, and update the version above and in `stata/x13_settings.do`.
