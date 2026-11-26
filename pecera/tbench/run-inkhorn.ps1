# Long-horizon test: the Inkhorn Reef game task (C:\Llama\tbench\custom\inkhorn-reef), six-hour limit, Hermes + pecera harness.
# Starts Docker and the model server if needed, then runs the task. Log: C:\Llama\tbench\inkhorn.log
param([string]$Job = 'inkhorn-run1', [int]$Budget = 3000)
$ProgressPreference = 'SilentlyContinue'
$tb = 'C:\Llama\tbench'; $repo = 'C:\Llama\pecera-engine\pecera'; $log = "$tb\inkhorn.log"
function Say($m) { $line = "$(Get-Date -Format 'MM-dd HH:mm:ss') $m"; $line; $line | Out-File $log -Append -Encoding ascii }
function Health { try { (Invoke-WebRequest -UseBasicParsing -TimeoutSec 4 http://127.0.0.1:9300/health).StatusCode -eq 200 } catch { $false } }

Say "=== run-inkhorn.ps1 start, job $Job, thinking cap $Budget"
Say (& powershell -NoProfile -ExecutionPolicy Bypass -File "$repo\tbench\start-docker.ps1" | Select-Object -Last 1)
if (Health) { Say 'A model server is already answering on port 9300. Using it.' }
else {
  $env:PECERA_BUDGET = "$Budget"; $env:PECERA_VISION = '0'
  Start-Process cmd -ArgumentList '/c', 'title pecera model server (close to stop) & C:\Llama\inkling2-mini-fast.bat 9300' -WindowStyle Minimized
  $sw = [Diagnostics.Stopwatch]::StartNew(); while (-not (Health) -and $sw.Elapsed.TotalSeconds -lt 180) { Start-Sleep 3 }
  if (-not (Health)) { Say 'STOP: the model server did not come up in 3 minutes.'; return }
  Say "Model server is up after $([math]::Round($sw.Elapsed.TotalSeconds)) s."
}
$env:PECERA_TASK_DIRS = "$tb\custom"
Say "Running $Job. Stop with: taskkill /im harbor.exe /f, then close the model server window."
& powershell -NoProfile -ExecutionPolicy Bypass -File "$repo\tbench\run-tb-hermes.ps1" -Job $Job -TaskPath "$tb\custom\inkhorn-reef"
$rf = Get-ChildItem "$tb\jobs\$Job" -Directory -ErrorAction SilentlyContinue | ForEach-Object { "$($_.FullName)\result.json" } | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($rf) { $r = Get-Content $rf -Raw | ConvertFrom-Json; Say "Finished. reward=$($r.verifier_result.rewards.reward) exception=$($r.exception_info.exception_type)" } else { Say 'Finished without a result file.' }
