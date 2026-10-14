<#
.SYNOPSIS
Prove that this checkout can rebuild a country's macro bundle from its tracked inputs.

.DESCRIPTION
Runs, in one MATLAB batch process: check_dependencies (strict), run_all_tests,
run_full_workflow for the country with estimation, frozen-model generation and
post-estimation skipped (those need estimation output that is not tracked), then
compare_bundles between the committed bundle (snapshot taken before the run) and
the regenerated one at a relative tolerance. Before the run every exporter output
is deleted from the bundle folder, so a file the run fails to write shows up as
"only in" the snapshot instead of comparing equal to itself; the tracked
_macroScenario_*.csv files, which no exporter writes, stay and are not compared.
Refuses to start when the bundle folder or input_processing/macromodel/data has uncommitted
changes. Afterwards, also on failure or Ctrl+C, the bundle folder is restored
from the snapshot and input_processing/macromodel/data from git, so a passing run leaves
`git status` clean. About five minutes.

.EXAMPLE
.\smoke_test.ps1                      # Poland, matlab from PATH
.\smoke_test.ps1 -MatlabExe 'C:\Program Files\MATLAB\R2025b\bin\matlab.exe' -RelTol 1e-6
#>
param(
    [string]$Country = 'Poland',
    [string]$MatlabExe = '',
    [double]$RelTol = 1e-6
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent (Split-Path -Parent $here)

if (-not $MatlabExe) {
    $cmd = Get-Command matlab -ErrorAction SilentlyContinue
    if (-not $cmd) { throw 'matlab is not on PATH; pass -MatlabExe <path to matlab.exe>' }
    $MatlabExe = $cmd.Source
}
$codes = @{ Poland = 'PL'; Germany = 'DE'; Spain = 'ES'; Sweden = 'SE' }
if (-not $codes.ContainsKey($Country)) { throw "unknown country '$Country'; one of: $($codes.Keys -join ', ')" }
$cc = $codes[$Country]
$bundle = Join-Path $root "input\$cc\MacroModel"
if (-not (Test-Path (Join-Path $bundle 'policy_A.csv'))) { throw "no committed bundle at $bundle" }

# The restore below overwrites the bundle folder and input_processing/macromodel/data.
$dirty = @(git -C $root status --porcelain -- "input/$cc/MacroModel" input_processing/macromodel/data)
if ($LASTEXITCODE -ne 0) { throw "git status failed in $root" }
if ($dirty.Count -gt 0) {
    throw ("commit or stash your bundle/data changes first; the smoke test compares against the committed bundle:`n" + ($dirty -join "`n"))
}

$snapshot = Join-Path ([IO.Path]::GetTempPath()) ('macromodel_smoke_' + [guid]::NewGuid().ToString('N'))
$log = Join-Path $here "logs\smoke_test_$Country.log"
New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null
$scenarios = '_macroScenario_*.csv'

$matlabCode = @"
cd('$here');
setup_path();
check_dependencies('strict', true);
f = run_all_tests();
assert(f == 0, '%d MATLAB check(s) failed', f);
run_full_workflow('$Country', 'skip_estimation', true, 'skip_frozen', true, 'skip_postestimation', true, 'skip_projection_plot', true);
r = compare_bundles('$snapshot', artifact_path('bundle', '', 'country', '$Country'), 'rel_tol', $RelTol, 'exclude', '$scenarios', 'fail', true);
fprintf('compare_bundles: %d exporter files agree within rel_tol %g\n', r.files_compared, $RelTol);
"@

$exit = 1
$snapshotTaken = $false
try {
    Copy-Item $bundle $snapshot -Recurse
    $snapshotTaken = $true
    Get-ChildItem $bundle -File | Where-Object { $_.Name -notlike $scenarios } | Remove-Item -Force
    & $MatlabExe -batch $matlabCode -logfile $log
    $exit = $LASTEXITCODE
}
finally {
    # Copying the snapshot back, rather than git checkout, also removes files the
    # run added, such as an untracked BUNDLE_NOT_VERIFIED.txt.
    if ($snapshotTaken) {
        Get-ChildItem $bundle -File | Remove-Item -Force
        Copy-Item (Join-Path $snapshot '*') $bundle -Force
    }
    git -C $root checkout -- input_processing/macromodel/data
    if (Test-Path $snapshot) { Remove-Item $snapshot -Recurse -Force }
}

if ($exit -ne 0) {
    Write-Host "SMOKE TEST FAILED (MATLAB exit $exit). Log: $log"
    exit $exit
}
Write-Host "SMOKE TEST PASSED: $Country bundle rebuilt from tracked inputs within rel_tol=$RelTol. Log: $log"
