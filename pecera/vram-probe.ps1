# Measures what one server config really needs: dedicated AND shared GPU memory of the llama-server process.
# nvidia-smi reports dedicated memory only, so a config that spills into system RAM looks like it fits.
# Run detached. Output: pecera\results\vram-<Tag>.txt, last line DONE.
param(
  [Parameter(Mandatory = $true)][string]$Exe,
  [string]$Tag = 'probe',
  [string]$Model = 'C:\Llama\inkling-fast\models\Inkling-2-Mini-mixB.gguf',
  [int]$Ctx = 65536,
  [string]$Ot = 'blk\.(22|23)\.ffn_.*_exps=CPU',
  [string]$Extra = '',
  [int]$Port = 9313
)
$ProgressPreference = 'SilentlyContinue'
$res = Join-Path $PSScriptRoot 'results'; $out = Join-Path $res "vram-$Tag.txt"; $log = Join-Path $res "vram-$Tag.server.log"
function Mem($procId) {
  $d = 0; $s = 0
  foreach ($c in (Get-Counter '\GPU Process Memory(*)\Dedicated Usage', '\GPU Process Memory(*)\Shared Usage' -ErrorAction SilentlyContinue).CounterSamples) {
    if ($c.InstanceName -like "pid_$($procId)_*") { if ($c.Path -like '*dedicated usage') { $d += $c.CookedValue } else { $s += $c.CookedValue } }
  }
  "server dedicated=$([math]::Round($d/1MB)) MiB shared=$([math]::Round($s/1MB)) MiB | card used=$((nvidia-smi --query-gpu=memory.used --format=csv,noheader) -join '')"
}
$a = @('-m', "`"$Model`"", '-ngl', '99', '-fa', 'on', '--jinja', '-c', "$Ctx", '-b', '512', '-ub', '512', '-ctk', 'q4_0', '-ctv', 'q4_0',
  '-t', '8', '-np', '1', '--no-context-shift', '--reasoning-budget', '2000', '--host', '127.0.0.1', '--port', "$Port")
if ($Ot) { $a += @('-ot', "`"$Ot`"") }
if ($Extra) { $a += ($Extra -split ' ') }
"tag=$Tag model=$(Split-Path -Leaf $Model) ctx=$Ctx ot=$Ot extra=$Extra card_before=$((nvidia-smi --query-gpu=memory.used --format=csv,noheader) -join '')" | Set-Content $out -Encoding ascii
$p = Start-Process -FilePath $Exe -ArgumentList $a -WindowStyle Hidden -PassThru -RedirectStandardError $log -RedirectStandardOutput "$log.out"
$sw = [Diagnostics.Stopwatch]::StartNew(); $up = $false
while ($sw.Elapsed.TotalSeconds -lt 180 -and -not $p.HasExited) {
  try { if ((Invoke-WebRequest -UseBasicParsing -TimeoutSec 4 "http://127.0.0.1:$Port/health").StatusCode -eq 200) { $up = $true; break } } catch {}
  Start-Sleep 2
}
"up=$up | after load: $(Mem $p.Id)" | Add-Content $out -Encoding ascii
if ($up) {
  try {
    $long = ('The quick brown fox jumps over the lazy dog near the river bank. ' * 400)
    $b = @{ messages = @(@{ role = 'user'; content = "$long`nWrite a 150-word note about tide pools." }); max_tokens = 300 } | ConvertTo-Json -Depth 6
    $x = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/v1/chat/completions" -Method Post -Body $b -ContentType 'application/json' -TimeoutSec 300
    "after a 6.4k request (prefill $([math]::Round($x.timings.prompt_per_second)) t/s, eval $([math]::Round($x.timings.predicted_per_second,1)) t/s): $(Mem $p.Id)" | Add-Content $out -Encoding ascii
  } catch { "request error: $($_.Exception.Message)" | Add-Content $out -Encoding ascii }
}
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
'DONE' | Add-Content $out -Encoding ascii
