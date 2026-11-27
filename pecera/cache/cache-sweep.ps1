# Roadmap item 6: agent-loop cache settings. Replays three recorded Hermes sessions (89 requests) against the next
# build at daily settings (mixC, blocks 20-23 on the CPU, 64k, q4_0 KV) once per server setting.
# Waits until -WaitLog contains DONE so it has the GPU to itself. Output: pecera\results\cache-sweep.log
param([string]$WaitLog = '')
$ProgressPreference = 'SilentlyContinue'
if ($WaitLog) { while (-not ((Test-Path $WaitLog) -and (Select-String -Path $WaitLog -Pattern '^DONE' -Quiet))) { Start-Sleep 30 } }
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot); $res = "$root\pecera\results"; $log = "$res\cache-sweep.log"
$exe = "$root\build\bin\llama-server.exe"; $py = "$env:USERPROFILE\anaconda3\python.exe"; $port = 9313
$j = 'C:\Llama\tbench\jobs\tb2-hermes-run1'
$sessions = @("$j\build-pmars__rt363mN\agent\hermes-session.jsonl", "$j\headless-terminal__g6qUBLR\agent\hermes-session.jsonl",
  'C:\Llama\tbench\jobs\tb2-hermes-run1-retry\crack-7z-hash__Npua353\agent\hermes-session.jsonl')
function L($m) { "$(Get-Date -Format T) $m" | Add-Content $log -Encoding ascii }
"started $(Get-Date -Format s)" | Set-Content $log -Encoding ascii
$configs = [ordered]@{
  'default'  = @()
  'cms1024'  = @('--checkpoint-min-step', '1024')
  'cms0'     = @('--checkpoint-min-step', '0')
  'noram'    = @('--cache-ram', '0')
  'nocp'     = @('--ctx-checkpoints', '0')
}
foreach ($name in $configs.Keys) {
  $a = @('-m', '"C:\Llama\inkling-fast\models\Inkling-2-Mini-mixC.gguf"', '-ngl', '99', '-fa', 'on', '--jinja', '-c', '65536',
    '-b', '512', '-ub', '512', '-ctk', 'q4_0', '-ctv', 'q4_0', '-t', '8', '-np', '1', '--no-context-shift',
    '-ot', '"blk\.(20|21|22|23)\.ffn_.*_exps=CPU"', '--reasoning-format', 'auto', '--host', '127.0.0.1', '--port', "$port") + $configs[$name]
  $slog = "$res\cache-$name.server.log"
  $p = Start-Process -FilePath $exe -ArgumentList $a -WindowStyle Hidden -PassThru -RedirectStandardError $slog -RedirectStandardOutput "$slog.out"
  $up = $false; $sw = [Diagnostics.Stopwatch]::StartNew()
  while (-not $up -and $sw.Elapsed.TotalSeconds -lt 300 -and -not $p.HasExited) {
    try { $up = ((Invoke-WebRequest -UseBasicParsing -TimeoutSec 4 "http://127.0.0.1:$port/health").StatusCode -eq 200) } catch {}
    if (-not $up) { Start-Sleep 2 }
  }
  if ($up) {
    & $py -X utf8 "$PSScriptRoot\replay.py" --base "http://127.0.0.1:$port" --sessions @sessions --out "$res\cache-$name.json" 2>&1 |
      Select-String '^SUMMARY' | ForEach-Object { L "$name | $($_.Line)" }
  } else { L "$name | server did not start" }
  if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
  Start-Sleep 5
}
'DONE' | Add-Content $log -Encoding ascii
