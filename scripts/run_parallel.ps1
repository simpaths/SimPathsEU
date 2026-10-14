# run_ramsey_feedback_experiment_parallel.ps1 — Ramsey feedback arms, run concurrently
#
# Each arm needs its own copy of the project because the H2 input database is
# locked by the running JVM: two multirun processes cannot share one input/
# folder. So this script clones the project once per JVM, runs everything in
# parallel, then collects the outputs back into the base output/ folder.
#
# Seeds can be split across several clones per arm (-ClonesPerArm). Seeds run
# SEQUENTIALLY inside one JVM, so splitting them is what buys wall-clock time.
#
# HOW MANY JVMs. Fewer than you would expect. SimPaths is itself partly threaded,
# so JVMs compete for cores rather than filling idle ones. Measured on a 32-logical-
# processor machine:
#     4 JVMs, 8 seeds each  -> ~5.9 min per seed  (0.68 seeds/min overall)
#     8 JVMs, 20 seeds each -> ~10.5 min per seed (0.76 seeds/min overall)
# Doubling the JVMs bought about 12% of throughput and nearly doubled per-seed time.
# Four to six concurrent JVMs looks like the sweet spot here; beyond that the extra
# clones mostly cost disk and memory. Prefer more seeds per JVM over more JVMs.
#
# Clone c of an arm gets
#   randomSeed      = BaseSeed + c * (SeedsPerArm / ClonesPerArm)
#   maxNumberOfRuns = SeedsPerArm / ClonesPerArm
# and the arm's MacroPaths.csv files are concatenated afterwards with the `run`
# column renumbered, so run index and seed stay in lockstep across every arm.
# That correspondence is the whole basis of the paired-seed design: pairing by
# run index would otherwise silently pair seed 42 of one arm with seed 62 of
# another.
#
# The clones live OUTSIDE the project directory. Putting them inside would make
# the copy recurse into itself.
#
# Copying is only safe while nothing holds the input database. The preflight
# refuses to start if a SimPaths JVM is running or a stale H2 lock is present.
#
# Failure detection: exit code alone is NOT sufficient. A config that fails to
# load prints to stderr and returns from main at exit code 0, so a typo'd config
# name would otherwise pass as a successful run of the defaults. Every clone is
# additionally checked for the known failure strings, for having produced an
# output directory, and for a MacroPaths.csv of the expected length.
#
# Usage:
#   .\run_ramsey_feedback_experiment_parallel.ps1                       # 1 seeds, N JVMs (corresponding to the number of configs)
#   .\run_ramsey_feedback_experiment_parallel.ps1 -SeedsPerArm 40 -ClonesPerArm 2 -JavaHeap 5g
#   .\run_ramsey_feedback_experiment_parallel.ps1 -CollectOnly          # salvage finished runs
#   .\run_ramsey_feedback_experiment_parallel.ps1 -CleanupWorkers

[CmdletBinding()]
param(
    [string[]] $Configs = @(
        "baseline-2023-2060.yml",
        "alternative-2023-2060.yml"
    ),
    [int]      $SeedsPerArm  = 1,
    [int]      $ClonesPerArm = 1,
    [int]      $BaseSeed     = 42,
    [string]   $WorkRoot     = "",
    [string]   $JavaHeap     = "8g",
    [switch]   $SkipCopy,
    [switch]   $CollectOnly,
    [switch]   $CleanupWorkers
)

$ErrorActionPreference = "Stop"

$baseDir   = $PSScriptRoot
$configDir = Join-Path $baseDir "config"
$outputDir = Join-Path $baseDir "output"
$jarName   = "multirun.jar"
$jarPath   = Join-Path $baseDir $jarName

if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
    $WorkRoot = Join-Path (Split-Path $baseDir -Parent) "SimPathsEU_parallel"
}

function Write-Section($text) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

# ---------------------------------------------------------------- preflight --
Write-Section "Preflight"

if ($SeedsPerArm % $ClonesPerArm -ne 0) {
    Write-Error "SeedsPerArm ($SeedsPerArm) must divide evenly by ClonesPerArm ($ClonesPerArm)."
    exit 1
}
$seedsPerClone = $SeedsPerArm / $ClonesPerArm
$jvmCount = $Configs.Count * $ClonesPerArm
Write-Host "  $($Configs.Count) arms x $ClonesPerArm clone(s) = $jvmCount JVMs, $seedsPerClone seeds each, $SeedsPerArm seeds per arm"

foreach ($cfg in $Configs) {
    if (-not (Test-Path (Join-Path $configDir $cfg))) {
        Write-Error "Config not found: $(Join-Path $configDir $cfg)"
        exit 1
    }
}
Write-Host "  [OK] $($Configs.Count) config(s) present"

if (-not (Test-Path $jarPath)) {
    Write-Error "$jarName not found in $baseDir. Build it with: mvn package"
    exit 1
}

# A stale jar is the quietest way to run the wrong code: the arms would execute
# whatever was built last, not what is in src/. Compare against the newest source.
$jarTime = (Get-Item $jarPath).LastWriteTime
$srcDir  = Join-Path $baseDir "src\main\java"
if (Test-Path $srcDir) {
    $newestSrc = Get-ChildItem -Path $srcDir -Recurse -Filter *.java |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -ne $newestSrc -and $newestSrc.LastWriteTime -gt $jarTime) {
        Write-Error ("$jarName ($($jarTime.ToString('yyyy-MM-dd HH:mm:ss'))) is OLDER than " +
                     "$($newestSrc.Name) ($($newestSrc.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))). " +
                     "Rebuild with 'mvn package' before running, or the arms silently use stale code.")
        exit 1
    }
}
Write-Host "  [OK] $jarName is newer than the newest source file"

# Match on the command line rather than on the process name: an IDE Java language
# server is almost always running (VS Code's redhat.java) and has nothing to do
# with SimPaths, so a bare "any java.exe" check would never pass.
$ourJvms = @(Get-CimInstance Win32_Process -Filter "Name='java.exe'" -ErrorAction SilentlyContinue |
             Where-Object {
                 $_.CommandLine -and
                 ($_.CommandLine -match 'multirun\.jar|singlerun\.jar' -or
                  $_.CommandLine -like "*$baseDir*" -or
                  $_.CommandLine -like "*$WorkRoot*")
             })
if ($ourJvms.Count -gt 0 -and -not $CollectOnly) {
    Write-Error ("$($ourJvms.Count) SimPaths JVM(s) are running (PIDs: $($ourJvms.ProcessId -join ', ')). " +
                 "Copying input/ while the H2 database is open produces a corrupt clone. Stop them and retry.")
    exit 1
}
$lockFiles = @(Get-ChildItem -Path (Join-Path $baseDir "input") -Filter "*.lock.db" -ErrorAction SilentlyContinue)
if ($lockFiles.Count -gt 0 -and -not $CollectOnly) {
    Write-Error ("H2 lock file(s) present: $($lockFiles.Name -join ', '). A previous run may have died. " +
                 "Remove them once you are sure no JVM is running, then retry.")
    exit 1
}
Write-Host "  [OK] no SimPaths JVM running and no H2 lock file"

$baseSizeGb = [math]::Round(((Get-ChildItem -Path $baseDir -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notlike (Join-Path $outputDir '*') } |
                Measure-Object -Property Length -Sum).Sum / 1GB), 1)
$freeGb = [math]::Round(((Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($baseDir.Substring(0,2))'").FreeSpace / 1GB), 0)
$needGb = [math]::Round($baseSizeGb * $jvmCount, 1)
Write-Host "  clone size ~$baseSizeGb GB each, $needGb GB total; $freeGb GB free"
if (-not ($SkipCopy -or $CollectOnly) -and $freeGb -lt ($needGb * 1.2)) {
    Write-Error "Not enough free disk space: need ~$needGb GB (plus room for outputs), have $freeGb GB."
    exit 1
}

$heapGb = [int]($JavaHeap -replace '[^0-9]', '')
$ramGb  = [math]::Round(((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB), 0)
if (($heapGb * $jvmCount) -gt ($ramGb * 0.8)) {
    Write-Error ("$jvmCount JVMs x $JavaHeap = $($heapGb * $jvmCount) GB of heap exceeds 80% of the " +
                 "$ramGb GB installed. Lower -JavaHeap or -ClonesPerArm.")
    exit 1
}
Write-Host "  [OK] $jvmCount x $JavaHeap = $($heapGb * $jvmCount) GB heap against $ramGb GB installed"

# ------------------------------------------------------------------- clones --
if (-not (Test-Path $WorkRoot)) { New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null }

$jobs = @()
foreach ($cfg in $Configs) {
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($cfg)
    for ($c = 0; $c -lt $ClonesPerArm; $c++) {
        $seed = $BaseSeed + ($c * $seedsPerClone)
        $tag  = if ($ClonesPerArm -eq 1) { $stem } else { "$stem`__s$seed" }
        $jobs += [PSCustomObject]@{
            Config     = $cfg
            Stem       = $stem
            CloneIndex = $c
            Seed       = $seed
            Tag        = $tag
            Worker     = Join-Path $WorkRoot $tag
            Log        = Join-Path $WorkRoot "$tag.stdout.log"
            ErrLog     = Join-Path $WorkRoot "$tag.stderr.log"
            Proc       = $null
        }
    }
}

if ($CollectOnly -or $SkipCopy) {
    Write-Section $(if ($CollectOnly) { "Reusing existing clones (-CollectOnly)" } else { "Reusing existing clones (-SkipCopy)" })
    foreach ($j in $jobs) {
        if (-not (Test-Path (Join-Path $j.Worker $jarName))) {
            Write-Error "No usable clone at $($j.Worker). Re-run without -SkipCopy/-CollectOnly."
            exit 1
        }
    }
} else {
    Write-Section "Cloning project ($($jobs.Count) copies, excluding output/)"
    foreach ($j in $jobs) {
        Write-Host "  -> $($j.Tag)  (seeds $($j.Seed)..$($j.Seed + $seedsPerClone - 1))"
        $null = robocopy $baseDir $j.Worker /E /XD $outputDir $WorkRoot /MT:16 /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
        if ($LASTEXITCODE -ge 8) {
            Write-Error "robocopy failed for $($j.Tag) with exit code $LASTEXITCODE"
            exit 1
        }
        New-Item -ItemType Directory -Path (Join-Path $j.Worker "output") -Force | Out-Null

        # Rewrite the clone's own config so each JVM covers a distinct seed block.
        $cfgFile = Join-Path $j.Worker "config\$($j.Config)"
        $yaml = Get-Content $cfgFile
        $yaml = $yaml -replace '^\s*randomSeed\s*:\s*\d+\s*$',      "randomSeed: $($j.Seed)"
        $yaml = $yaml -replace '^\s*maxNumberOfRuns\s*:\s*\d+\s*$', "maxNumberOfRuns: $seedsPerClone"
        $yaml | Set-Content -Path $cfgFile -Encoding ASCII

        $check = (Get-Content $cfgFile | Select-String -Pattern '^(randomSeed|maxNumberOfRuns)\s*:')
        if ($check.Count -ne 2) {
            Write-Error "Could not rewrite randomSeed/maxNumberOfRuns in $cfgFile (found $($check.Count) of 2)."
            exit 1
        }
    }
    Write-Host "  [OK] clones ready"
}

# --------------------------------------------------------------------- runs --
if ($CollectOnly) {
    Write-Section "Skipping the runs (-CollectOnly); collecting existing clone outputs"
}

$started = Get-Date
if (-not $CollectOnly) {
    Write-Section "Launching $($jobs.Count) JVMs in parallel (heap $JavaHeap each)"

    foreach ($j in $jobs) {
        Write-Host "  start: $($j.Tag)"
        # -config takes a BARE filename resolved against the working directory. A
        # path-qualified argument silently fails to load AND exits 0.
        $j.Proc = Start-Process -FilePath "java" `
            -ArgumentList @("-Xmx$JavaHeap", "-jar", $jarName, "-f", "-config", $j.Config) `
            -WorkingDirectory $j.Worker `
            -RedirectStandardOutput $j.Log `
            -RedirectStandardError $j.ErrLog `
            -NoNewWindow -PassThru
        # Touching .Handle caches the process handle. Without it .ExitCode reads
        # back as $null after the process ends, reporting every arm as failed.
        $null = $j.Proc.Handle
    }

    Write-Host "`n  Waiting on $($jobs.Count) JVMs. Progress: Get-Content '<log>' -Tail 20 -Wait"
    foreach ($j in $jobs) { $j.Proc.WaitForExit() }
    $elapsed = (Get-Date) - $started
    Write-Host ("`n  All JVMs exited after {0:N1} minutes" -f $elapsed.TotalMinutes) -ForegroundColor Green
}

# ---------------------------------------------------------------- collection --
Write-Section "Checking results"

$failed = @()
foreach ($j in $jobs) {
    $out = ""
    if (Test-Path $j.Log)    { $out += (Get-Content $j.Log -Raw) }
    if (Test-Path $j.ErrLog) { $out += (Get-Content $j.ErrLog -Raw) }

    $exit = $null
    if ($null -ne $j.Proc) { $exit = $j.Proc.ExitCode }
    $bad = $false; $why = ""

    if ($null -ne $exit -and $exit -ne 0) { $bad = $true; $why = "exit code $exit" }
    elseif ($out -match "Error parsing command line arguments") { $bad = $true; $why = "config not parsed" }
    elseif ($out -match "not found; please supply a valid config file") { $bad = $true; $why = "config not found" }

    $produced = @()
    $workerOut = Join-Path $j.Worker "output"
    if (Test-Path $workerOut) { $produced = @(Get-ChildItem -Path $workerOut -Directory -ErrorAction SilentlyContinue) }
    if (-not $bad -and $produced.Count -eq 0) { $bad = $true; $why = "no output directory - the run did not happen" }

    # The decisive check: MacroPaths.csv must hold every seed for the full horizon.
    # A JVM that died mid-run still leaves a directory behind.
    if (-not $bad) {
        $expected = $seedsPerClone * 152    # 38 years x 4 quarters
        foreach ($dir in $produced) {
            $mp = Join-Path $dir.FullName "csv\MacroPaths.csv"
            if (-not (Test-Path $mp)) { $bad = $true; $why = "no MacroPaths.csv - the run did not finish" }
            else {
                $rows = (Get-Content $mp | Measure-Object -Line).Lines - 1
                if ($rows -ne $expected) { $bad = $true; $why = "MacroPaths.csv has $rows rows, expected $expected" }
                else { Write-Host "  [OK] $($j.Tag): $rows rows" }
            }
        }
    }

    $j | Add-Member -NotePropertyName Produced -NotePropertyValue $produced -Force
    if ($bad) { Write-Host "  [FAIL] $($j.Tag): $why" -ForegroundColor Red; $failed += $j }
}

if ($failed.Count -gt 0) {
    Write-Host "`n  $($failed.Count) of $($jobs.Count) JVMs failed; not merging." -ForegroundColor Red
    Write-Host "  Clones kept at $WorkRoot" -ForegroundColor Yellow
    exit 1
}

Write-Section "Merging seed blocks into one directory per arm"

# One stamp for the whole batch: every arm folder and the manifest share it,
# so a batch groups together instead of splitting on a second boundary.
$runStamp = Get-Date -Format "yyyyMMddHHmmss"
$collected = @()
foreach ($cfg in $Configs) {
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($cfg)
    $armJobs = @($jobs | Where-Object { $_.Config -eq $cfg } | Sort-Object CloneIndex)

    $target = Join-Path $outputDir ("{0}_{1}_{2}seeds" -f $runStamp, $stem, $SeedsPerArm)
    New-Item -ItemType Directory -Path (Join-Path $target "csv") -Force | Out-Null

    $merged = New-Object System.Collections.Generic.List[string]
    $header = $null
    foreach ($j in $armJobs) {
        $mp = Join-Path $j.Produced[0].FullName "csv\MacroPaths.csv"
        $lines = Get-Content $mp
        if ($null -eq $header) { $header = $lines[0]; $merged.Add($header) }

        # Renumber `run` so it is unique and ordered across the arm's seed blocks.
        # Clone c covers seeds [BaseSeed + c*k, ...], and its internal run indices
        # restart at 1, so without this every arm's run 1 would mean a different
        # seed depending on which clone it came from.
        $offset = $j.CloneIndex * $seedsPerClone
        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ([string]::IsNullOrWhiteSpace($lines[$i])) { continue }
            $comma = $lines[$i].IndexOf(',')
            $runNo = [int]$lines[$i].Substring(0, $comma) + $offset
            $merged.Add(($runNo.ToString() + $lines[$i].Substring($comma)))
        }
    }
    $merged | Out-File -FilePath (Join-Path $target "csv\MacroPaths.csv") -Encoding ASCII

    $rows = $merged.Count - 1
    Write-Host ("  {0}: {1} rows from {2} block(s) -> {3}" -f $stem, $rows, $armJobs.Count, (Split-Path $target -Leaf))
    $collected += [PSCustomObject]@{ Config = $cfg; Output = $target; Rows = $rows }
}

$manifest = Join-Path $outputDir ("{0}_ramsey_feedback_parallel_manifest.txt" -f $runStamp)
$lines = @("# Ramsey feedback parallel run, $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
           "# jar built: $($jarTime.ToString('yyyy-MM-dd HH:mm:ss'))",
           "# $SeedsPerArm seeds per arm, base seed $BaseSeed, $ClonesPerArm clone(s) per arm",
           "# merged MacroPaths.csv only; per-clone full outputs remain under $WorkRoot",
           "")
foreach ($c in $collected) { $lines += ("{0,-42} {1}" -f $c.Config, (Split-Path $c.Output -Leaf)) }
$lines | Out-File -FilePath $manifest -Encoding utf8
Write-Host "`n  Manifest: $manifest" -ForegroundColor Green
Get-Content $manifest | ForEach-Object { Write-Host "    $_" }

# ------------------------------------------------------------------ cleanup --
if ($CleanupWorkers) {
    Write-Section "Removing clones"
    foreach ($j in $jobs) { Remove-Item -Path $j.Worker -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host "  [OK] clones removed"
} else {
    Write-Host "`n  Clones kept at $WorkRoot" -ForegroundColor Yellow
    Write-Host "  (they hold the run logs and the full per-clone output; delete when satisfied," -ForegroundColor Yellow
    Write-Host "   or re-run with -CleanupWorkers)" -ForegroundColor Yellow
}

Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "  All $($jobs.Count) JVMs complete, $($Configs.Count) arms merged" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

# robocopy returns 1 for "files copied successfully", which PowerShell would
# otherwise propagate as a non-zero script exit code on a fully successful run.
exit 0
