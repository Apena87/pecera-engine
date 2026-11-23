# pecera-engine

A llama.cpp fork tuned for one PC and one model.

- PC ("la-pecera"): i9-13900KF, RTX 4070 Ti 12 GB, 32 GB DDR5, Windows 11
- Model: Inkling-2-Mini, the 10.3 GiB mixB quant (`C:\Llama\inkling-fast\models\Inkling-2-Mini-mixB.gguf`)
- Client: Hermes Agent on an OpenAI-compatible endpoint, 64k context or more

Everything specific to this project lives in this `pecera/` folder. The rest of the tree is llama.cpp.

## What the `main` branch is

Upstream llama.cpp master (23 Nov 2026) with these commits on top:

| Source | What it adds |
|---|---|
| realugbun/llama.cpp `inkling2-speed` (4 commits) | Fused CUDA kernels for the Inkling 2 glue op chains, depth states normalized once per block |
| hridaya423/llama.cpp `inkling-fast` (efe6a22) | Per-op CUDA timing with `GGML_CUDA_OP_PROFILE=1` |
| hridaya423/llama.cpp `inkling-fast` (a69577c, load side only) | Loads expert down tensors that are zero-padded to the quant block size. mixB needs this |
| hridaya423/llama.cpp `inkling-fast` (c1ebdae) | Top-k MoE weight normalization fused into the top-k kernel |
| capybaraonchain/llama.cpp `inkling2-12gb` (eeed997) | Relative-position bias computed inside flash attention. Without it the server cannot allocate its compute buffer at 64k |
| this repo | MSVC build fix in `llama-quant.cpp`, merge of the two attention-bias APIs, build, bench and launch scripts |

The branch `baseline/hridaya` and the tag `baseline-hridaya-273fae8` keep the fork that the PC ran before this project. That build stays installed in `C:\Llama\inkling-fast` as the fallback.

## Build

```
pecera\build.bat build
```

It uses the VS 2026 Build Tools and the private CUDA 13.4 toolkit in `C:\Llama\inkling-fast\cuda`. The target is `sm_89` only. After the first build, copy `cublas64_13.dll`, `cublasLt64_13.dll` and `cudart64_13.dll` into `build\bin`.

## Measure

- `pecera\bench.ps1 -Exe <llama-server.exe> -Tag <name>` starts a server on port 9313, runs a fixed greedy completion and a 6.4k-token chat request, records speed and VRAM, then stops the server.
- `pecera\quality-check.ps1 -Exe <llama-server.exe> -Tag <name> -Benches gsm:40` runs part of the established eval with the same seed and questions as the earlier model comparisons.
- `GGML_CUDA_OP_PROFILE=1` with `llama-bench` prints time and launch count per op type.

Both scripts start a server, so run them detached and poll the result file. Results are in `pecera/results/`.

## Status

See `RESULTS.md` for numbers, `ROADMAP.md` for what comes next and `DECISIONS.md` for the choices made so far.

## Run

`pecera\run.bat` starts the server on port 9300 with the same settings as the daily launcher. It puts every expert on the GPU when enough VRAM is free.

The daily launcher `C:\Llama\inkling2-mini-fast.bat` still points at the old build. It moves to this engine once the remaining quality checks in `ROADMAP.md` pass.
