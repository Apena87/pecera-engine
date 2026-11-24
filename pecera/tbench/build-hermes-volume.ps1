docker volume create pecera-hermes | Out-Null
Get-Content C:\Llama\tbench\build-hermes-volume.sh -Raw | docker run --rm -i -v pecera-hermes:/opt/pecera-hermes ubuntu:22.04 bash -s 2>&1 | ForEach-Object { "$_" } | Out-File C:\Llama\tbench\build-hermes-volume.log -Encoding ascii
"exit $LASTEXITCODE $(Get-Date -Format T)" | Out-File C:\Llama\tbench\build-hermes-volume.done -Encoding ascii

