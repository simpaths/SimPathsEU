# run_batch_scenarios.ps1 — Run the five macro-coupling scenarios in sequence.
#
# Scenarios:
#   1. No-macro baseline
#   2. Ramsey baseline (trend only)
#   3. Ramsey counterfactual (high g_A +0.5pp from start)
#   4. Ramsey perfect-foresight (high g_A +0.5pp from 2040)
#   5. Ramsey counterfactual + DSGE energy shock (1.5sd, 60q)
#
# Each run writes a timestamped folder under .\output\, with the active
# Ramsey/DSGE scenario CSV names automatically appended to the folder name
# (see SimPathsMultiRun.buildRunLabel).

$ErrorActionPreference = "Stop"

$jarPath   = Join-Path $PSScriptRoot "multirun.jar"
$configDir = Join-Path $PSScriptRoot "config"
$logDir    = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

$batchStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$batchLog   = Join-Path $logDir "batch_${batchStamp}.log"

$configs = @(
    "batch-1-no-macro.yml",
    "batch-2-ramsey-baseline.yml",
    "batch-3-ramsey-counterfactual.yml",
    "batch-4-ramsey-perfect-foresight.yml",
    "batch-5-ramsey-plus-dsge.yml"
)

# Pre-flight: ensure jar and all configs exist before starting any run.
if (-not (Test-Path $jarPath)) {
    Write-Error "multirun.jar not found at $jarPath"
    exit 1
}
foreach ($cfg in $configs) {
    $cfgPath = Join-Path $configDir $cfg
    if (-not (Test-Path $cfgPath)) {
        Write-Error "Config not found: $cfgPath"
        exit 1
    }
}

$batchStart = Get-Date
"Batch started: $batchStart" | Tee-Object -FilePath $batchLog -Append | Out-Null

$idx = 0
foreach ($cfg in $configs) {
    $idx++
    $runStart = Get-Date

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  [$idx/$($configs.Count)] $cfg"        -ForegroundColor Cyan
    Write-Host "  Started: $($runStart.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    "[$idx/$($configs.Count)] $cfg started $runStart" | Out-File -FilePath $batchLog -Append -Encoding utf8

    # multirun resolves -config relative to .\config\, so pass just the file name.
    $runOutput = & java -jar $jarPath -f -config $cfg 2>&1
    $runOutput | ForEach-Object { Write-Host $_ }
    $runOutput | Out-File -FilePath $batchLog -Append -Encoding utf8

    $joined = ($runOutput -join "`n")
    if ($LASTEXITCODE -ne 0 -or $joined -match "Error parsing command line arguments") {
        $msg = "FAILED: $cfg (exit code $LASTEXITCODE)"
        Write-Error $msg
        $msg | Out-File -FilePath $batchLog -Append -Encoding utf8
        exit $LASTEXITCODE
    }

    $runEnd      = Get-Date
    $elapsed     = $runEnd - $runStart
    $elapsedStr  = "{0:hh\:mm\:ss}" -f $elapsed
    Write-Host ""
    Write-Host "  Completed: $cfg in $elapsedStr" -ForegroundColor Green
    "  Completed: $cfg in $elapsedStr at $runEnd" | Out-File -FilePath $batchLog -Append -Encoding utf8
}

$batchEnd  = Get-Date
$totalStr  = "{0:hh\:mm\:ss}" -f ($batchEnd - $batchStart)

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  All 5 scenarios complete in $totalStr"  -ForegroundColor Green
Write-Host "  Batch log: $batchLog"                    -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
"Batch finished: $batchEnd (total $totalStr)" | Out-File -FilePath $batchLog -Append -Encoding utf8
