$ProgressPreference = 'SilentlyContinue'
$log = 'C:\Llama\tbench\ab-draft2.log'
function L($m) { "$(Get-Date -Format 'HH:mm:ss') $m" | Out-File $log -Append -Encoding ascii }
$p = 'C:\Llama\pecera-engine\pecera'; $exe = 'C:\Llama\pecera-pr33063\build\bin\llama-server.exe'
$mixC = 'C:\Llama\inkling-fast\models\Inkling-2-Mini-mixC.gguf'; $dd = 'C:\Llama\inkling-fast\models\draft'
$cpu5 = 'blk\.(19|20|21|22|23)\.ffn_.*_exps=CPU'
$base = "--spec-draft-model $dd\Inkling-2-Mini-DFlash2-Draft-Q8_0-embnorm.gguf --spec-type draft-dflash2 --spec-draft-n-min 0 --metrics"
function Run($ps, $a) { Start-Process powershell -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ps) + $a) -WindowStyle Hidden -Wait }
$tests = @(
  @('nodraft-cpu5', ''),
  @('q8emb-n7-prob-cpu5', "$base --spec-draft-n-max 7 --spec-draft-sampling probabilistic"),
  @('q8emb-n4-prob-cpu5', "$base --spec-draft-n-max 4 --spec-draft-sampling probabilistic"),
  @('q8emb-n3-cpu5', "$base --spec-draft-n-max 3")
)
foreach ($t in $tests) {
  L "bench $($t[0])"
  $ea = @('-Exe', $exe, '-Tag', "draft-$($t[0])", '-Model', $mixC, '-Ot', $cpu5); if ($t[1]) { $ea += @('-Extra', "`"$($t[1])`"") }
  Run "$p\bench.ps1" $ea
  $f = "$p\results\draft-$($t[0]).txt"; if (Test-Path $f) { (Get-Content $f | Select-String 'gpu_loaded|greedy run|chat run') | ForEach-Object { L "   $($_.Line)" } }
  $s = "$p\results\draft-$($t[0]).server.log"; if (Test-Path $s) { (Get-Content $s | Select-String 'draft acceptance' | Select-Object -Last 2) | ForEach-Object { L "   $($_.Line.Substring($_.Line.IndexOf('draft')))" } }
}
L 'DONE'
