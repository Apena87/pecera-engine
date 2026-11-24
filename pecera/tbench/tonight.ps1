# One-step Terminal-Bench 2.0 run with Hermes and the pecera harness. Start it with C:\Llama\run-terminal-bench-tonight.bat
# Safe to stop at any time by closing the window. Running it again resumes the same job.
#   1. starts Docker Desktop (with the stale-socket workaround)
#   2. starts the model server on port 9300 with a 3,000-token thinking cap and vision off, unless one is already running
#   3. runs one easy task as a check of the whole chain
#   4. runs or resumes the full 89-task job. If the check fails for a harness reason, it runs the Terminus 2 baseline
#      instead, so the night is not lost, and writes the reason to tonight.log
param([string]$Job = 'tb2-hermes-run1', [int]$Budget = 3000)
$ProgressPreference = 'SilentlyContinue'
$tb = 'C:\Llama\tbench'; $repo = 'C:\Llama\pecera-engine\pecera'; $log = "$tb\tonight.log"
function Say($m) { $line = "$(Get-Date -Format 'MM-dd HH:mm:ss') $m"; $line; $line | Out-File $log -Append -Encoding ascii }
function Health { try { (Invoke-WebRequest -UseBasicParsing -TimeoutSec 4 http://127.0.0.1:9300/health).StatusCode -eq 200 } catch { $false } }
function HarborEnv {
  $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"; $env:PYTHONIOENCODING = 'utf-8'; $env:PYTHONUTF8 = '1'; $env:PYTHONWARNINGS = 'ignore'
  $env:PYTHONPATH = "$repo\hermes"; if (-not $env:OPENAI_API_KEY) { $env:OPENAI_API_KEY = 'no-key-required' }
}
function Progress($job) {
  $d = "$tb\jobs\$job"; if (-not (Test-Path $d)) { return 'not started' }
  $done = @(Get-ChildItem $d -Directory | Where-Object { Test-Path "$($_.FullName)\result.json" }); $pass = 0
  foreach ($t in $done) { try { if ((Get-Content "$($t.FullName)\result.json" -Raw | ConvertFrom-Json).verifier_result.rewards.reward -eq 1) { $pass++ } } catch {} }
  "$($done.Count) of 89 finished, $pass passed"
}

Say "=== tonight.ps1 start, job $Job, thinking cap $Budget"
Say (& powershell -NoProfile -ExecutionPolicy Bypass -File "$repo\tbench\start-docker.ps1" | Select-Object -Last 1)

if (Health) { Say 'A model server is already answering on port 9300. Using it with whatever settings it was started with.' }
else {
  $env:PECERA_BUDGET = "$Budget"; $env:PECERA_VISION = '0'
  Start-Process cmd -ArgumentList '/c', 'title pecera model server (close to stop) & C:\Llama\inkling2-mini-fast.bat 9300' -WindowStyle Minimized
  $sw = [Diagnostics.Stopwatch]::StartNew(); while (-not (Health) -and $sw.Elapsed.TotalSeconds -lt 180) { Start-Sleep 3 }
  if (-not (Health)) { Say 'STOP: the model server did not come up in 3 minutes. Free VRAM may be too low. Close GPU-heavy apps and run this again.'; return }
  Say "Model server is up after $([math]::Round($sw.Elapsed.TotalSeconds)) s."
}

HarborEnv
$smoke = "$Job-check"
if (-not (Test-Path "$tb\jobs\$smoke\result.json")) {
  Say 'Check run: one easy task (fix-git) through the full chain. Takes a few minutes.'
  & powershell -NoProfile -ExecutionPolicy Bypass -File "$repo\tbench\run-tb-hermes.ps1" -Job $smoke -Extra '-i fix-git'
}
$ok = $false; $why = 'no result file'
try {
  $r = Get-Content "$tb\jobs\$smoke\result.json" -Raw | ConvertFrom-Json
  $ev = @($r.stats.evals.PSObject.Properties)[0].Value
  $exc = @($ev.exception_stats.PSObject.Properties | ForEach-Object { $_.Name })
  $bad = @($exc | Where-Object { $_ -ne 'AgentTimeoutError' })
  $ok = ($r.stats.n_completed_trials -ge 1) -and ($bad.Count -eq 0)
  $why = "completed=$($r.stats.n_completed_trials) score=$($ev.metrics[0].mean) exceptions=$($exc -join ',')"
} catch { $why = "could not read the check result: $($_.Exception.Message)" }
Say "Check result: $why"

if ($ok) {
  if (Test-Path "$tb\jobs\$Job") { Say "Resuming $Job ($(Progress $Job))."; $p = Start-Process harbor -ArgumentList 'jobs', 'resume', '-p', "$tb\jobs\$Job" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$tb\$Job.resume.log" -RedirectStandardError "$tb\$Job.resume.err.log" }
  else { Say "Starting the full Hermes run $Job."; $p = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$repo\tbench\run-tb-hermes.ps1", '-Job', $Job -WindowStyle Hidden -PassThru }
  $watch = $Job
} else {
  $watch = 'tb2-terminus-run2'
  Say "The Hermes check did not pass, so the Terminus 2 baseline runs instead as $watch. Logs of the failed check: $tb\jobs\$smoke"
  if (Test-Path "$tb\jobs\$watch") { $p = Start-Process harbor -ArgumentList 'jobs', 'resume', '-p', "$tb\jobs\$watch" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$tb\$watch.resume.log" -RedirectStandardError "$tb\$watch.resume.err.log" }
  else { $p = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$repo\tbench\run-tb.ps1", '-Job', $watch -WindowStyle Hidden -PassThru }
}
Say "Running. This window shows progress every 5 minutes. Closing it does not stop the run. To stop, close the model server window, then run: taskkill /im harbor.exe /f"
while (-not $p.HasExited) { Start-Sleep 300; Say "$watch`: $(Progress $watch)" }
Say "Finished. $watch`: $(Progress $watch)"

# 5. Second attempt for tasks that ended with an exception (time limit reached, container did not start). They run as a
#    separate job, <Job>-retry, so the first-attempt results stay untouched and the two scores can be reported apart.
if ($watch -eq $Job) {
  $trials = @(Get-ChildItem "$tb\jobs\$Job" -Directory)
  $done = @($trials | Where-Object { Test-Path "$($_.FullName)\result.json" })
  if ($done.Count -ge 89) {
    $retry = "$Job-retry"; $names = @()
    foreach ($t in $done) { try { $r = Get-Content "$($t.FullName)\result.json" -Raw | ConvertFrom-Json; if ($r.exception_info) { $names += ($t.Name -split '__')[0] } } catch {} }
    if ($names.Count -eq 0) { Say 'No tasks ended with an exception, so there is nothing to retry.' }
    else {
      if (Test-Path "$tb\jobs\$retry") { Say "Resuming $retry."; $p = Start-Process harbor -ArgumentList 'jobs', 'resume', '-p', "$tb\jobs\$retry" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$tb\$retry.resume.log" -RedirectStandardError "$tb\$retry.resume.err.log" }
      else { Say "Retrying $($names.Count) tasks as $retry`: $($names -join ', ')"; $extra = ($names | ForEach-Object { "-i $_" }) -join ' '; $p = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$repo\tbench\run-tb-hermes.ps1", '-Job', $retry, '-Extra', "`"$extra`"" -WindowStyle Hidden -PassThru }
      while (-not $p.HasExited) { Start-Sleep 300; Say "$retry`: $((Progress $retry) -replace 'of 89', "of $($names.Count)")" }
      Say "Finished. $retry`: $((Progress $retry) -replace 'of 89', "of $($names.Count)")"
    }
  } else { Say "$Job stopped with $($done.Count) of 89 finished. Run this again to resume." }
}
