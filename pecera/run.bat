@echo off
setlocal

REM ============================================================
REM pecera-engine launcher: Inkling-2-Mini on the pecera-engine build (trial, 2026-11-23)
REM Same sampling, effort and thinking cap as C:\Llama\inkling2-mini-fast.bat, which is unchanged.
REM
REM QUANT picks the model file:
REM   mixC  every GPU-side expert at 3 bits. KL divergence to Q8_0 0.038, top token matches 91.7%
REM   mixB  the earlier file, 0.5 GB smaller. KL divergence 0.047, top token matches 91.1%
REM PLACE says which expert blocks run on the CPU. auto picks from free VRAM:
REM   cpu2 = blocks 22-23, cpu3 = 21-23, cpu4 = 20-23, gpu = none
REM
REM measured on this PC at 64k context, q4_0 KV, server memory after a 6.4k request (pecera\RESULTS.md):
REM   mixB cpu2  10515 MiB  76 t/s        mixC cpu2  11055 MiB  75 t/s
REM   mixB gpu   11480 MiB  81-87 t/s     mixC cpu3  10667 MiB  72 t/s
REM                                       mixC cpu4  10281 MiB  69 t/s
REM   the old build with mixB cpu2: 10433 MiB, 65 t/s
REM gpu placement only fits with under 600 MiB of desktop VRAM in use, so auto never picks it.
REM Vision checked: test image read correctly in 2.5 s, no extra VRAM. Not checked: contexts above 64k.
REM ============================================================

set "PORT_ARG=%1"
if "%PORT_ARG%"=="" set "PORT_ARG=9300"

set "QUANT=mixC"
set "PLACE=auto"
set "CTX=65536"
set "KV=q4_0"
set "EFFORT=high"
set "BUDGET=10000"
set "VISION=1"

set "ROOT=%~dp0.."
set "MODELS=C:\Llama\inkling-fast\models"
set "MODEL=%MODELS%\Inkling-2-Mini-%QUANT%.gguf"
if not exist "%MODEL%" set "QUANT=mixB"
set "MODEL=%MODELS%\Inkling-2-Mini-%QUANT%.gguf"
set "RT=%ROOT%\build\bin"
if not exist "%RT%\llama-server.exe" set "RT=%ROOT%\build-ugbun\bin"
if not exist "%MODEL%" goto model_missing
if not exist "%RT%\llama-server.exe" goto runtime_missing
set "MMPROJ=%MODELS%\mmproj-Inkling-2-Mini-BF16.gguf"
set "VIS="
if "%VISION%"=="1" if exist "%MMPROJ%" set VIS=--mmproj "%MMPROJ%" --no-mmproj-offload

set "FREE=0"
for /f %%A in ('nvidia-smi "--query-gpu=memory.free" "--format=csv,noheader,nounits"') do set "FREE=%%A"
set "WARN=10750"
if /i not "%PLACE%"=="auto" goto place_set
set "PLACE=cpu2"
if /i not "%QUANT%"=="mixC" goto place_set
set "WARN=10500"
set "PLACE=cpu4"
if %FREE% GEQ 10950 set "PLACE=cpu3"
if %FREE% GEQ 11350 set "PLACE=cpu2"
:place_set
set "OTPAT=22|23"
if /i "%PLACE%"=="cpu3" set "OTPAT=21|22|23"
if /i "%PLACE%"=="cpu4" set "OTPAT=20|21|22|23"
set OT=-ot "blk\.(%OTPAT%)\.ffn_.*_exps=CPU"
if /i "%PLACE%"=="gpu" set "OT="
echo Free VRAM %FREE% MiB, model %QUANT%, expert placement %PLACE%
if %FREE% LSS %WARN% echo WARNING: under %WARN% MiB of VRAM free. The model may spill into system RAM and run slowly. Close GPU-heavy apps and relaunch.

cd /d "%RT%"

echo ============================================================
echo Inkling-2-Mini %QUANT% (pecera-engine)   port %PORT_ARG%
echo ctx %CTX%   KV %KV%   effort %EFFORT%   budget %BUDGET%   vision %VISION%   experts %PLACE%
echo ============================================================

"%RT%\llama-server.exe" ^
  -m "%MODEL%" %VIS% ^
  --alias inkling-2-mini ^
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