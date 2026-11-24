# Starts Docker Desktop on this PC. Written 2026-11-23.
# On Windows build 26300 leftover socket files cannot be deleted, and Docker Desktop crashes at startup when it
# finds its own old ones ("The file cannot be accessed by the system"). This renames the two folders that hold
# them so Docker creates fresh ones. Nothing is deleted. Old folders are kept beside the new ones as *.stale-<time>.
$L = $env:LOCALAPPDATA
if (Get-Process 'com.docker.backend' -ErrorAction SilentlyContinue) {
  $j = Start-Job { docker version --format '{{.Server.Version}}' 2>$null }
  if ((Wait-Job $j -Timeout 20) -and (Receive-Job $j)) { 'Docker is already running.'; return }
  Get-Process | Where-Object { $_.ProcessName -match '^(Docker Desktop|com\.docker\.backend|com\.docker\.build|com\.docker\.diagnose|docker)$' } | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep 4
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($p in "$L\Docker\run", "$L\docker-secrets-engine") {
  if (Test-Path $p) {
    $n = @(Get-ChildItem $p -Force -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -match 'ReparsePoint' }).Count
    if ($n -gt 0) { Rename-Item $p ((Split-Path -Leaf $p) + ".stale-$stamp"); "set aside $p ($n old socket files)" }
  }
}
Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt 180) {
  Start-Sleep 6
  $j = Start-Job { docker version --format '{{.Server.Version}}' 2>$null }
  if ((Wait-Job $j -Timeout 15)) { $v = Receive-Job $j; if ($v) { "Docker engine $v is up after $([math]::Round($sw.Elapsed.TotalSeconds)) s."; return } } else { Stop-Job $j }
}
'Docker did not come up in 3 minutes. Look at the Docker Desktop window for the error.'
