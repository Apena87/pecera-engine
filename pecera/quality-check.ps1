# Runs part of the established quality eval (C:\Llama\unsloth-b12572\tune\eval\evalrun.py) against one build.
# Same seed, same questions and the same 4000-token thinking cap as the earlier model comparisons.
# Run detached. Output: pecera\results\<Tag>.quality.log, last line DONE. Answers land in the eval folder under out_<Tag>.
param(
  [Parameter(Mandatory = $true)][string]$Exe,
  [string]$Tag = 'quality',
  [string]$Model = 'C:\Llama\inkling-fast\models\Inkling-2-Mini-mixB.gguf',
  [int]$Ctx = 65536,
  [string]$Ot = 'blk\.(22|23)\.ffn_.*_exps=CPU',
  [string]$Benches = 'gsm:40',
  [int]$Port = 9313
)
$ProgressPreference = 'SilentlyContinue'
$res = Join-Path $PSScriptRoot 'results'; New-Item -ItemType Directory -Force $res | Out-Null
$log = Join-Path $res "$Tag.quality.log"; $slog = Join-Path $res "$Tag.quality.server.log"
$py = "$env:USERPROFILE\anaconda3\python.exe"; $ev = 'C:\Llama\unsloth-b12572\tune\eval'
"started $(Get-Date -Format s) exe=$Exe ctx=$Ctx ot=$Ot benches=$Benches" | Set-Content $log -Encoding ascii
$a = @('-m', "`"$Model`"", '-ngl', '99', '-fa', 'on', '--jinja', '-c', "$Ctx", '-b', '512', '-ub', '512', '-ctk', 'q4_0', '-ctv', 'q4_0',
  '-t', '8', '-np', '1', '-ot', "`"$Ot`"", '--no-context-shift',
  '--chat-template-kwargs', '"{\"reasoning_effort\":\"high\"}"', '--reasoning-budget', '4000',
  '--reasoning-budget-message', '"Planning is done. Proceed with the answer now."', '--reasoning-format', 'auto',
  '--temp', '1.0', '--top-p', '1.0', '--top-k', '0', '--min-p', '0.0', '--host', '127.0.0.1', '--port', "$Port")
$p = Start-Process -FilePath $Exe -ArgumentList $a -WindowStyle Hidden -PassThru -RedirectStandardError $slog -RedirectStandardOutput "$slog.out"
$sw = [Diagnostics.Stopwatch]::StartNew(); $up = $false
while ($sw.Elapsed.TotalSeconds -lt 300 -and -not $p.HasExited) {
  try { if ((Invoke-WebRequest -UseBasicParsing -TimeoutSec 4 "http://127.0.0.1:$Port/health").StatusCode -eq 200) { $up = $true; break } } catch {}
  Start-Sleep 2
}
"up=$up gpu=$((nvidia-smi --query-gpu=memory.used --format=csv,noheader) -join '')" | Add-Content $log -Encoding ascii
if ($up) {
  foreach ($b in ($Benches -split ',')) {
    $name, $n = $b -split ':'
    $args2 = @('-X', 'utf8', "$ev\evalrun.py", '--bench', $name, '--base', "http://127.0.0.1:$Port", '--outdir', "out_$Tag", '--workers', '1')
    if ($n) { $args2 += @('--n', $n) }
    Push-Location $ev
    & $py @args2 2>&1 | Out-File $log -Append -Encoding ascii
    Pop-Location
  }
}
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
"DONE $(Get-Date -Format s)" | Add-Content $log -Encoding ascii
