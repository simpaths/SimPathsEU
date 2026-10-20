<#
.SYNOPSIS
Prove that this checkout can rebuild a country's macro bundle from its tracked inputs.

.DESCRIPTION
Runs, in one MATLAB batch process: check_dependencies (strict), run_all_tests,
run_full_workflow for the country with estimation, frozen-model generation and
post-estimation skipped (those need estimation output that is not tracked), then
compare_bundles at a relative tolerance twice: the regenerated
input_processing/macromodel/data folder against a snapshot taken before the run
(the detrended datafile the bundle is built from), and the regenerated bundle
against the committed one. Before the run every exporter output is deleted from
the bundle folder, so a file the run fails to write shows up as "only in" the
snapshot instead of comparing equal to itself; the tracked _macroScenario_*.csv
files, which no exporter writes, stay and are not compared.
Refuses to start when the bundle folder or input_processing/macromodel/data has
uncommitted changes. Afterwards, also on failure or Ctrl+C, a MATLAB process still
running is stopped, the bundle folder is restored from the snapshot and
input_processing/macromodel/data from git, so a passing run leaves `git status`
clean. A restore that fails says so, keeps the snapshot and fails the run.
About five minutes. Tested on Windows PowerShell 5.1.

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
$onWindows = ($env:OS -eq 'Windows_NT')

# Paths go into single-quoted MATLAB strings, where a quote is written twice.
function ConvertTo-MatlabText([string]$text) { return $text.Replace("'", "''") }

if (-not $MatlabExe) {
    $cmd = Get-Command matlab -ErrorAction SilentlyContinue
    if (-not $cmd) { throw 'matlab is not on PATH; pass -MatlabExe <path to matlab.exe>' }
    $MatlabExe = $cmd.Source
}
$codes = @{ Poland = 'PL'; Germany = 'DE'; Spain = 'ES'; Sweden = 'SE' }
if (-not $codes.ContainsKey($Country)) { throw "unknown country '$Country'; one of: $($codes.Keys -join ', ')" }
$cc = $codes[$Country]
$bundle = Join-Path (Join-Path (Join-Path $root 'input') $cc) 'MacroModel'
$data = Join-Path $here 'data'
if (-not (Test-Path (Join-Path $bundle 'policy_A.csv'))) { throw "no committed bundle at $bundle" }

# The restore below overwrites the bundle folder and input_processing/macromodel/data.
$dirty = @(git -C $root status --porcelain -- "input/$cc/MacroModel" input_processing/macromodel/data)
if ($LASTEXITCODE -ne 0) { throw "git status failed in $root" }
if ($dirty.Count -gt 0) {
    throw ("commit or stash your bundle/data changes first; the smoke test compares against the committed bundle:`n" + ($dirty -join "`n"))
}

$token = [guid]::NewGuid().ToString('N')
$snapshot = Join-Path ([IO.Path]::GetTempPath()) ('macromodel_smoke_' + $token)
$bundleSnapshot = Join-Path $snapshot 'bundle'
$dataSnapshot = Join-Path $snapshot 'data'
# A MATLAB script name must be a valid identifier: letters, digits, underscores.
$script = Join-Path ([IO.Path]::GetTempPath()) ('macromodel_smoke_' + $token + '.m')
$log = Join-Path (Join-Path $here 'logs') "smoke_test_$Country.log"
New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null
$scenarios = '_macroScenario_*.csv'

$matlabCode = @"
cd('$(ConvertTo-MatlabText $here)');
setup_path();
check_dependencies('strict', true);
f = run_all_tests();
assert(f == 0, '%d MATLAB check(s) failed', f);
run_full_workflow('$Country', 'skip_estimation', true, 'skip_frozen', true, 'skip_postestimation', true, 'skip_projection_plot', true);
r = compare_bundles('$(ConvertTo-MatlabText $dataSnapshot)', artifact_path('data', ''), 'rel_tol', $RelTol, 'fail', true);
fprintf('compare_bundles: %d data files agree within rel_tol %g\n', r.files_compared, $RelTol);
r = compare_bundles('$(ConvertTo-MatlabText $bundleSnapshot)', artifact_path('bundle', '', 'country', '$Country'), 'rel_tol', $RelTol, 'exclude', '$scenarios', 'fail', true);
fprintf('compare_bundles: %d exporter files agree within rel_tol %g\n', r.files_compared, $RelTol);
"@

$exit = 1
$snapshotTaken = $false
$proc = $null
try {
    New-Item -ItemType Directory -Force $snapshot | Out-Null
    Copy-Item $bundle $bundleSnapshot -Recurse
    Copy-Item $data $dataSnapshot -Recurse
    $snapshotTaken = $true
    # -cnotlike: case-sensitive, as compare_bundles' exclude is.
    Get-ChildItem $bundle -File | Where-Object { $_.Name -cnotlike $scenarios } | Remove-Item -Force
    [IO.File]::WriteAllText($script, $matlabCode, (New-Object Text.UTF8Encoding $false))
    $runArg = "run('" + (ConvertTo-MatlabText $script) + "')"
    # A process handle, not the call operator, so that cleanup can stop MATLAB after
    # Ctrl+C; the polling wait lets PowerShell act on Ctrl+C between polls.
    $proc = Start-Process -FilePath $MatlabExe -ArgumentList @('-batch', "`"$runArg`"", '-logfile', "`"$log`"") `
                          -NoNewWindow -PassThru
    $null = $proc.Handle   # Windows PowerShell reports ExitCode only if the handle was opened
    while (-not $proc.WaitForExit(500)) { }
    $exit = $proc.ExitCode
}
finally {
    $keepSnapshot = $false
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # report every cleanup failure; do not stop at the first
    try {
        if ($proc -and -not $proc.HasExited) {
            Write-Warning "stopping MATLAB (process $($proc.Id)) and its children"
            if ($onWindows) { & taskkill /T /F /PID $proc.Id 2>&1 | Out-Null }
            else { Stop-Process -Id $proc.Id -Force }
        }
        # Copying the snapshot back, rather than git checkout, also removes files the
        # run added, such as an untracked BUNDLE_NOT_VERIFIED.txt.
        if ($snapshotTaken) {
            try {
                Get-ChildItem $bundle -File | Remove-Item -Force -ErrorAction Stop
                Copy-Item (Join-Path $bundleSnapshot '*') $bundle -Force -ErrorAction Stop
            }
            catch {
                $keepSnapshot = $true
                Write-Warning "restoring the bundle failed: $($_.Exception.Message). The committed bundle is in $bundleSnapshot; copy it back into $bundle."
            }
        }
        $gitOut = & git -C $root checkout -q -- input_processing/macromodel/data 2>&1
        if ($LASTEXITCODE -ne 0) {
            $keepSnapshot = $true
            Write-Warning ("restoring input_processing/macromodel/data failed (git exit $LASTEXITCODE): " + ($gitOut -join ' ') +
                           " Restore it with: git -C `"$root`" checkout -- input_processing/macromodel/data")
        }
        if (Test-Path $script) { Remove-Item $script -Force }
        if ($keepSnapshot) {
            Write-Warning "snapshot kept: $snapshot"
            if ($exit -eq 0) { $exit = 2 }
        }
        elseif (Test-Path $snapshot) {
            Remove-Item $snapshot -Recurse -Force -ErrorAction Stop
        }
    }
    catch {
        Write-Warning "cleanup failed: $($_.Exception.Message). Snapshot, if any: $snapshot"
        if ($exit -eq 0) { $exit = 2 }
    }
    finally {
        $ErrorActionPreference = $savedPreference
    }
}

if ($exit -ne 0) {
    Write-Host "SMOKE TEST FAILED (exit $exit). Log: $log"
    exit $exit
}
Write-Host "SMOKE TEST PASSED: $Country data and bundle rebuilt from tracked inputs within rel_tol=$RelTol. Log: $log"
