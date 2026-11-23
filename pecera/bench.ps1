# pecera-engine speed and sanity bench. Starts one llama-server build on port 9313, measures it, stops it.
# Run it detached (it starts a server, so never pipe or wait on it from a parent shell):
#   powershell -NoProfile -ExecutionPolicy Bypass -File pecera\bench.ps1 -Exe <llama-server.exe> -Tag <name>
# Output: pecera\results\<Tag>.txt, last line DONE.
param(
  [Parameter(Mandatory = $true)][string]$Exe,
  [string]$Tag = 'bench',
  [string]$Model = 'C:\Llama\inkling-fast\models\Inkling-2-Mini-mixB.gguf',
  [int]$Ctx = 65536,
  [string]$Kv = 'q4_0',
  [string]$Ot = 'blk\.(22|23)\.ffn_.*_exps=CPU',
  [string]$Extra = '',
  [int]$Port = 9313
)
$ProgressPreference = 'SilentlyContinue'
$root = Split-Path -Parent $PSScriptRoot
$res = Join-Path $PSScriptRoot 'results'; New-Item -ItemType Directory -Force $res | Out-Null
$out = Join-Path $res "$Tag.txt"; $log = Join-Path $res "$Tag.server.log"
function Gpu { [int](nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits).Trim() }
$exeDir = Split-Path -Parent $Exe
Get-Process llama-server -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe } | Stop-Process -Force
$before = Gpu
$a = @('-m', "`"$Model`"", '-ngl', '99', '-fa', 'on', '--jinja', '-c', "$Ctx", '-b', '512', '-ub', '512', '-ctk', $Kv, '-ctv', $Kv,
  '-t', '8', '-np', '1', '--no-context-shift', '--reasoning-budget', '2000', '--reasoning-format', 'auto',
  '--temp', '1.0', '--top-p', '1.0', '--top-k', '0', '--min-p', '0.0', '--host', '127.0.0.1', '--port', "$Port")
if ($Ot) { $a += @('-ot', "`"$Ot`"") }
if ($Extra) { $a += ($Extra -split ' ') }
"tag=$Tag exe=$Exe ctx=$Ctx kv=$Kv ot=$Ot extra=$Extra gpu_before=$before MiB $(Get-Date -Format s)" | Set-Content $out -Encoding ascii
$p = Start-Process -FilePath $Exe -ArgumentList $a -WindowStyle Hidden -PassThru -RedirectStandardError $log -RedirectStandardOutput "$log.out"
$sw = [Diagnostics.Stopwatch]::StartNew(); $up = $false
while ($sw.Elapsed.TotalSeconds -lt 300 -and -not $p.HasExited) {
  try { if ((Invoke-WebRequest -UseBasicParsing -TimeoutSec 4 "http://127.0.0.1:$Port/health").StatusCode -eq 200) { $up = $true; break } } catch {}
  Start-Sleep 2
}
"up=$up load_s=$([math]::Round($sw.Elapsed.TotalSeconds)) gpu_loaded=$(Gpu) MiB" | Add-Content $out -Encoding ascii
if ($up) {
  try {
    # 1. greedy raw completion, short context. Same prompt and seed for every build so the text can be compared.
    $g = @{ prompt = 'The three laws of thermodynamics, stated plainly, are as follows. First,'; n_predict = 200; temperature = 0; seed = 1; cache_prompt = $false } | ConvertTo-Json
    foreach ($i in 1, 2, 3) {
      $x = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/completion" -Method Post -Body $g -ContentType 'application/json' -TimeoutSec 300
      "greedy run $i n=$($x.timings.predicted_n) eval=$([math]::Round($x.timings.predicted_per_second,1)) t/s" | Add-Content $out -Encoding ascii
    }
    "greedy_text: " + (($x.content -replace '\s+', ' ').Trim()) | Add-Content $out -Encoding ascii
    # 2. chat request with a 6.4k-token prompt: prefill speed and decode speed at that depth
    $long = ('The quick brown fox jumps over the lazy dog near the river bank. ' * 400)
    foreach ($i in 1, 2) {
      $b = @{ messages = @(@{ role = 'user'; content = "$long`nRun $i. Write a 150-word note about tide pools." }); max_tokens = 400 } | ConvertTo-Json -Depth 6
      $x = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/v1/chat/completions" -Method Post -Body $b -ContentType 'application/json' -TimeoutSec 300
      "chat run $i prompt_n=$($x.timings.prompt_n) prefill=$([math]::Round($x.timings.prompt_per_second)) t/s eval=$([math]::Round($x.timings.predicted_per_second,1)) t/s" | Add-Content $out -Encoding ascii
    }
    "gpu_after=$(Gpu) MiB ram_free_gb=$([math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB,1))" | Add-Content $out -Encoding ascii
  } catch { "request error: $($_.Exception.Message) $($_.ErrorDetails.Message)" | Add-Content $out -Encoding ascii }
} else { Get-Content $log -Tail 8 | Add-Content $out -Encoding ascii }
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
'DONE' | Add-Content $out -Encoding ascii
