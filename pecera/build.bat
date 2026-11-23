@echo off
REM pecera-engine build for la-pecera: i9-13900KF + RTX 4070 Ti (sm_89), Windows, CUDA 13.4
REM usage: pecera\build.bat [build-dir-name]   default: build
REM CUDA toolkit: the private conda install made for the inkling-fast build (override with PECERA_CUDA)
set "ROOT=%~dp0.."
set "BDIR=%~1"
if "%BDIR%"=="" set "BDIR=build"
if "%PECERA_CUDA%"=="" set "PECERA_CUDA=C:\Llama\inkling-fast\cuda\Library"
set "VS=C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools"
call "%VS%\VC\Auxiliary\Build\vcvars64.bat" >nul
set "CUDA_PATH=%PECERA_CUDA%"
set "PATH=%PECERA_CUDA%\bin;%VS%\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;%VS%\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%"
cmake -S "%ROOT%" -B "%ROOT%\%BDIR%" -G Ninja -DCMAKE_BUILD_TYPE=Release ^
  -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89 ^
  -DCUDAToolkit_ROOT="%PECERA_CUDA%" -DCMAKE_CUDA_COMPILER="%PECERA_CUDA%\bin\nvcc.exe" ^
  -DCMAKE_CUDA_FLAGS="-allow-unsupported-compiler" ^
  -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF -DGGML_NATIVE=ON
if errorlevel 1 exit /b 1
cmake --build "%ROOT%\%BDIR%" --config Release -j 24 --target llama-server llama-bench llama-cli
if errorlevel 1 exit /b 1
echo BUILD_OK