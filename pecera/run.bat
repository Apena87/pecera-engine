@echo off
setlocal

REM ============================================================
REM pecera-engine launcher: Inkling-2-Mini mixB on the pecera-engine build (trial, 2026-11-23)
REM Same model file, sampling, effort and thinking cap as C:\Llama\inkling2-mini-fast.bat.
REM That bat is unchanged and stays the fallback until the full eval passes on this build.
REM
REM measured on this PC at 64k context, q4_0 KV (pecera\RESULTS.md):
REM  - blocks 22-23 on the CPU: 78 t/s short context, 70 t/s at 6.4k depth, about 9.6 GB VRAM
REM  - all experts on the GPU:  87 t/s short context, 78 t/s at 6.4k depth, about 10.9 GB VRAM
REM  - the old build in the same minute: 68 and 62 t/s
REM PLACE=auto puts every expert on the GPU when enough VRAM is free (11250 MiB, or 11650 with vision).
REM Vision checked 2026-11-23: test image read correctly in 2.5 s. Not checked yet: contexts above 64k.
REM ============================================================

set "PORT_ARG=%1"
if "%PORT_ARG%"=="" set "PORT_ARG=9300"

set "CTX=65536"
set "KV=q4_0"
set "EFFORT=high"
set "BUDGET=10000"
set "VISION=1"
set "PLACE=auto"

set "ROOT=%~dp0.."
set "MODELS=C:\Llama\inkling-fast\models"
set "MODEL=%MODELS%\Inkling-2-Mini-mixB.gguf"
set "RT=%ROOT%\build\bin"
if not exist "%RT%\llama-server.exe" set "RT=%ROOT%\build-ugbun\bin"
if not exist "%MODEL%" goto model_missing
if not exist "%RT%\llama-server.exe" goto runtime_missing
set "MMPROJ=%MODELS%\mmproj-Inkling-2-Mini-BF16.gguf"
set "VIS="
if "%VISION%"=="1" if exist "%MMPROJ%" set VIS=--mmproj "%MMPROJ%" --no-mmproj-offload

set "FREE=0"
for /f %%A in ('nvidia-smi "--query-gpu=memory.free" "--format=csv,noheader,nounits"') do set "FREE=%%A"
REM all experts on the GPU: the server held 10.6 GB without vision and 11.2 GB with it (measured 2026-11-23)
set "NEED=11250"
if defined VIS set "NEED=11650"
if /i "%PLACE%"=="auto" (
  set "PLACE=cpu2"
  if %FREE% GEQ %NEED% set "PLACE=gpu"
)
set OT=-ot "blk\.(22|23)\.ffn_.*_exps=CPU"
if /i "%PLACE%"=="gpu" set "OT="
echo Free VRAM %FREE% MiB, expert placement %PLACE%
if %FREE% LSS 9900 echo WARNING: under 9900 MiB of VRAM free. The model may spill into system RAM and run slowly. Close GPU-heavy apps and relaunch.

cd /d "%RT%"

echo ============================================================
echo Inkling-2-Mini mixB (pecera-engine)   port %PORT_ARG%
echo ctx %CTX%   KV %KV%   effort %EFFORT%   budget %BUDGET%   vision %VISION%   experts %PLACE%
echo ============================================================

"%RT%\llama-server.exe" ^
  -m "%MODEL%" %VIS% ^
  -ngl 99 ^
  %OT% ^
  -c %CTX% ^
  --parallel 1 ^
  -b 512 -ub 512 ^
  -fa on ^
  -ctk %KV% -ctv %KV% ^
  --no-context-shift ^
  -t 8 ^
  --jinja ^
  --chat-template-kwargs "{\"reasoning_effort\":\"%EFFORT%\"}" ^
  --reasoning-budget %BUDGET% ^
  --reasoning-budget-message "Planning is done. Proceed with the answer now." ^
  --reasoning-format auto ^
  --temp 1.0 --top-p 1.0 --top-k 0 --min-p 0.0 ^
  --host 127.0.0.1 --port %PORT_ARG%

echo.
echo llama-server exited with code %ERRORLEVEL%
if "%1"=="" pause
exit /b %ERRORLEVEL%

:model_missing
echo Model file not found: %MODEL%
if "%1"=="" pause
exit /b 1

:runtime_missing
echo The pecera-engine build is missing. Run pecera\build.bat build
if "%1"=="" pause
exit /b 1