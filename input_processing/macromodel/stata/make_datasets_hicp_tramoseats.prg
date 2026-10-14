'Script for TRAMO/SEATS seasonal adjustment of the HICP series.
'Method note: this uses EViews' tramoseats(seats=2, ...), NOT Census X-13.
'The file was named "..._x13.prg" until 2026-08; the name was wrong, the method
'was always TRAMO/SEATS. Writes hicp_q_sa.dta, consumed by make_datasets.do.
%path = @runpath
exec {%path}_capture.prg "wfclose HICPm"
exec {%path}_capture.prg "wfclose HICPq"

wfcreate(wf="HICPm") m 1996.1 2025.12
string path = %path
cd {path}

import(mode=o) HICP.dta

hicp_germany.tramoseats(opt="seats=2 mq=12 lam=-1 inic=3 idif=3 ieast=0 itrad=0 iatip=1 aio=0", save="sa") hicp_germany
hicp_poland.tramoseats(opt="seats=2 mq=12 lam=-1 inic=3 idif=3 ieast=0 itrad=0 iatip=1 aio=0", save="sa") hicp_poland
hicp_sweden.tramoseats(opt="seats=2 mq=12 lam=-1 inic=3 idif=3 ieast=0 itrad=0 iatip=1 aio=0", save="sa") hicp_sweden
hicp_spain.tramoseats(opt="seats=2 mq=12 lam=-1 inic=3 idif=3 ieast=0 itrad=0 iatip=1 aio=0", save="sa") hicp_spain

smpl 1996m1 2020m11
hicp_uk.tramoseats(opt="seats=2 mq=12 lam=-1 inic=3 idif=3 ieast=0 itrad=0 iatip=1 aio=0", save="sa") hicp_uk

smpl @all

wfcreate(wf="HICPq") q 1996q1 2025q4

wfselect HICPq
copy(c=a) HICPM::Untitled\HICP_GERMANY_SA *
copy(c=a) HICPM::Untitled\HICP_POLAND_SA *
copy(c=a) HICPM::Untitled\HICP_SWEDEN_SA *
copy(c=a) HICPM::Untitled\HICP_SPAIN_SA *
copy(c=a) HICPM::Untitled\HICP_UK_SA *

wfsave hicp_q_sa.dta

wfselect HICPq
wfsave HICPq

wfselect HICPm
wfsave HICPm

exit


