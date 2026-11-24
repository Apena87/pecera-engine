# Runs Terminal-Bench 2.0 through Harbor with the Terminus 2 agent against the local llama-server on port 9300.
# Tasks run in Docker containers. Run detached. Log: C:\Llama\tbench\<Job>.log, finished marker: <Job>.done
# Resume an interrupted job with: harbor jobs resume -p C:\Llama\tbench\jobs\<Job>
param([string]$Job = 'trial1', [string]$Extra = '')
$ErrorActionPreference = 'SilentlyContinue'
$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"; $env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; $env:PYTHONWARNINGS='ignore'
cd C:\Llama\tbench
$mi = 'model_info={\"max_input_tokens\":60000,\"max_output_tokens\":12000,\"input_cost_per_token\":0.0,\"output_cost_per_token\":0.0}'
$a = @('run','-d','terminal-bench@2.0','-a','terminus-2','-m','hosted_vllm/inkling-2-mini','--ak','api_base=http://127.0.0.1:9300/v1','--ak',$mi,'-n','1','-k','1','-o','C:\Llama\tbench\jobs','--job-name',$Job,'-y')
if ($Extra) { $a += ($Extra -split ' ') }
"started $(Get-Date -Format s) harbor $($a -join ' ')" | Out-File "C:\Llama\tbench\$Job.log" -Encoding ascii
& harbor @a 2>&1 | ForEach-Object { "$_" } | Out-File "C:\Llama\tbench\$Job.log" -Append -Encoding ascii
"exit $LASTEXITCODE $(Get-Date -Format s)" | Out-File "C:\Llama\tbench\$Job.done" -Encoding ascii
