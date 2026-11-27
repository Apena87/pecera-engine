# Roadmap item 1: quality check of the new base (branch next) against the current daily build, same model and placement.
# Waits for -WaitFor (a log file) to contain "EXIT" so it does not share the GPU with another job.
param([string]$WaitFor = '')
$ProgressPreference = 'SilentlyContinue'
if ($WaitFor) { while (-not ((Test-Path $WaitFor) -and (Select-String -Path $WaitFor -Pattern '^EXIT' -Quiet))) { Start-Sleep 20 } }
$qc = Join-Path $PSScriptRoot '..\quality-check.ps1'
$ot = 'blk\.(20|21|22|23)\.ffn_.*_exps=CPU'
$m = 'C:\Llama\inkling-fast\models\Inkling-2-Mini-mixC.gguf'
& $qc -Exe 'C:\Llama\pecera-pr33063\build\bin\llama-server.exe' -Tag 'item1_next' -Model $m -Ot $ot -Benches 'he:40,quiz,quiz_long,mmlu:70'
& $qc -Exe 'C:\Llama\pecera-engine\build\bin\llama-server.exe' -Tag 'item1_old' -Model $m -Ot $ot -Benches 'he:40,quiz,mmlu:70'
"ITEM1_DONE $(Get-Date -Format s)" | Set-Content (Join-Path $PSScriptRoot '..\results\item1.done') -Encoding ascii
