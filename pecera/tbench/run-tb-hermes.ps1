# Runs Terminal-Bench 2.0 through Harbor with Hermes Agent and the pecera harness (pecera\hermes\).
# Hermes is installed inside each task container and talks to llama-server on the host through host.docker.internal:9300.
# Run detached. Log: C:\Llama\tbench\<Job>.log, finished marker: <Job>.done
# Resume an interrupted job with the same environment variables set and: harbor jobs resume -p C:\Llama\tbench\jobs\<Job>
param([string]$Job = 'hermes-trial', [string]$Extra = '', [string]$Audit = 'true')
$ErrorActionPreference = 'SilentlyContinue'
$hx = 'C:\Llama\pecera-engine\pecera\hermes'
$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"; $env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; $env:PYTHONWARNINGS='ignore'
$env:PYTHONPATH = $hx
if (-not $env:OPENAI_API_KEY) { $env:OPENAI_API_KEY = 'no-key-required' }
cd C:\Llama\tbench
$a = @('run','-d','terminal-bench@2.0','--agent-import-path','pecera_hermes:PeceraHermes','-m','openai/inkling-2-mini',
       '--base-url','http://host.docker.internal:9300/v1','--api-format','openai_chat_completions',
       '--skills',"$hx\skills",'--ak',"audit=$Audit",'-n','1','-k','1','-o','C:\Llama\tbench\jobs','--job-name',$Job,'-y')
if ($Extra) { $a += ($Extra -split ' ') }
"started $(Get-Date -Format s) harbor $($a -join ' ')" | Out-File "C:\Llama\tbench\$Job.log" -Encoding ascii
& harbor @a 2>&1 | ForEach-Object { "$_" } | Out-File "C:\Llama\tbench\$Job.log" -Append -Encoding ascii
"exit $LASTEXITCODE $(Get-Date -Format s)" | Out-File "C:\Llama\tbench\$Job.done" -Encoding ascii
