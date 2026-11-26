# Chat at 6.4k depth with temperature 0, with and without the draft, to separate temperature from chat depth.
$ProgressPreference = 'SilentlyContinue'
$log = 'C:\Llama\tbench\ab-draft-t0.log'
function L($m) { "$(Get-Date -Format 'HH:mm:ss') $m" | Out-File $log -Append -Encoding ascii }
$exe = 'C:\Llama\pecera-pr33063\build\bin\llama-server.exe'; $mixC = 'C:\Llama\inkling-fast\models\Inkling-2-Mini-mixC.gguf'; $dd = 'C:\Llama\inkling-fast\models\draft'
$long = (Get-Content 'C:\Llama\pecera-engine\pecera\bench.ps1' -Raw)  # any long text; repeated to about 6k tokens
$long = ($long * 6).Substring(0, 24000)
foreach ($cfg in @(@('nodraft', @()), @('draft-n7', @('--spec-draft-model', "$dd\Inkling-2-Mini-DFlash2-Draft-Q8_0-embnorm.gguf", '--spec-type', 'draft-dflash2', '--spec-draft-n-max', '7', '--spec-draft-n-min', '0')))) {
  Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2
  $a = @('-m', "`"$mixC`"", '-ngl', '99', '-fa', 'on', '--jinja', '-c', '65536', '-b', '512', '-ub', '512', '-ctk', 'q4_0', '-ctv', 'q4_0', '-t', '8', '-np', '1',
    '-ot', '"blk\.(19|20|21|22|23)\.ffn_.*_exps=CPU"', '--no-context-shift', '--reasoning-budget', '2000', '--host', '127.0.0.1', '--port', '9313') + $cfg[1]
  $p = Start-Process -FilePath $exe -ArgumentList $a -WindowStyle Hidden -PassThru -RedirectStandardError "C:\Llama\tbench\t0-$($cfg[0]).log" -RedirectStandardOutput "C:\Llama\tbench\t0-$($cfg[0]).out.log"
  $sw = [Diagnostics.Stopwatch]::StartNew(); $up = $false
  while ($sw.Elapsed.TotalSeconds -lt 120 -and -not $up) { try { $up = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 4 http://127.0.0.1:9313/health).StatusCode -eq 200 } catch { Start-Sleep 2 } }
  foreach ($q in @('Explain in about 150 words what the script above measures.', 'Write a Python function that parses lines like "greedy run 2 n=200 eval=70.7 t/s" into a dict, with two unit tests.')) {
    $b = @{ messages = @(@{ role = 'user'; content = "$long`n`n$q" }); max_tokens = 500; temperature = 0 } | ConvertTo-Json -Depth 6
    $x = Invoke-RestMethod -Uri http://127.0.0.1:9313/v1/chat/completions -Method Post -Body $b -ContentType 'application/json' -TimeoutSec 300
    L "$($cfg[0]) prompt_n=$($x.timings.prompt_n) eval=$([math]::Round($x.timings.predicted_per_second,1)) t/s n=$($x.timings.predicted_n) draft_n=$($x.timings.draft_n) accepted=$($x.timings.draft_n_accepted)"
  }
  Stop-Process -Id $p.Id -Force
}
L 'DONE'
