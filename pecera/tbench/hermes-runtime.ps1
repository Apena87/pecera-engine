$log='C:\Llama\tbench\hermes-runtime.log'; "start $(Get-Date -Format T)" | Out-File $log -Encoding ascii
Get-Content C:\Llama\tbench\hermes-runtime-build.sh -Raw | docker run --rm -i -v pecera-hermes:/opt/pecera-hermes ubuntu:22.04 bash -s 2>&1 | ForEach-Object { "$_" } | Out-File $log -Append -Encoding ascii
foreach ($img in 'debian:12','ubuntu:20.04','python:3.13-slim') {
  "=== verify in $img (volume read-only)" | Out-File $log -Append -Encoding ascii
  Get-Content C:\Llama\tbench\hermes-runtime-verify.sh -Raw | docker run --rm -i -v pecera-hermes:/opt/pecera-hermes:ro $img bash -s 2>&1 | ForEach-Object { "$_" } | Out-File $log -Append -Encoding ascii
}
"DONE $(Get-Date -Format T)" | Out-File $log -Append -Encoding ascii
