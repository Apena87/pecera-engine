# Runs Terminal-Bench 2.0 through Harbor with Hermes Agent and the pecera harness (pecera\hermes\).
# Hermes runs inside each task container and talks to the model server on the host through host.docker.internal.
# Run detached. Log: C:\Llama\tbench\<Job>.log, finished marker: <Job>.done
# -Port 9301 with tbench\mock_llm.py running gives a dry run with no model.
param([string]$Job = 'hermes-trial', [string]$Extra = '', [string]$Audit = 'true', [int]$Port = 9300)
$ErrorActionPreference = 'SilentlyContinue'
$hx = 'C:\Llama\pecera-engine\pecera\hermes'; $tb = 'C:\Llama\pecera-engine\pecera\tbench'
$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"; $env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; $env:PYTHONWARNINGS='ignore'
$env:PYTHONPATH = $hx
if (-not $env:OPENAI_API_KEY) { $env:OPENAI_API_KEY = 'no-key-required' }
cd C:\Llama\tbench
$mounts = '[{\"type\":\"volume\",\"source\":\"pecera-hermes\",\"target\":\"/opt/pecera-hermes\",\"read_only\":true}]'
$a = @('run','-d','terminal-bench@2.0','--agent','pecera_hermes:PeceraHermes','-m','openai/inkling-2-mini',
       '--base-url',"http://host.docker.internal:$Port/v1",'--api-format','openai_chat_completions',
       '--skills',"$hx\skills\terminal-ops",'--ak',"audit=$Audit",
       '--mounts',$mounts,'--extra-docker-compose',"$tb\hermes-volume.compose.yaml",
       '-n','1','-k','1','-o','C:\Llama\tbench\jobs','--job-name',$Job,'-y')
if ($Extra) { $a += ($Extra -split ' ') }
"started $(Get-Date -Format s) harbor $($a -join ' ')" | Out-File "C:\Llama\tbench\$Job.log" -Encoding ascii
& harbor @a 2>&1 | ForEach-Object { "$_" } | Out-File "C:\Llama\tbench\$Job.log" -Append -Encoding ascii
"exit $LASTEXITCODE $(Get-Date -Format s)" | Out-File "C:\Llama\tbench\$Job.done" -Encoding ascii
