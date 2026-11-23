# Results

All runs on la-pecera (i9-13900KF, RTX 4070 Ti 12 GB) with `Inkling-2-Mini-mixB.gguf`, q4_0 KV cache, flash attention on, 8 threads, one slot. Raw output is in `pecera/results/`.

"Old build" is hridaya423 `inkling-fast` at 273fae8, the build the PC used before this project.

## 2026-11-23: first engine build (commit e082a46)

### Speed, 64k context, run back to back with the PC locked

| Build and expert placement | Decode, short context | Decode at 6.4k depth | Prefill, 6.4k prompt | VRAM used by the server |
|---|---|---|---|---|
| Old build, blocks 22-23 on CPU | 67 to 68 t/s | 62 t/s | 1,848 t/s | 10.3 GB |
| pecera, blocks 22-23 on CPU | 76 to 79 t/s | 70 t/s | 1,447 t/s | 9.4 GB |
| pecera, all experts on GPU | 86 to 87 t/s | 78 t/s | 2,064 t/s | 10.6 GB, peak 10.9 |

Decode is 15% faster in the same placement and 28% faster with all experts on the GPU. The new build needs 0.9 GB less VRAM in the same placement, which is what lets all experts fit at 64k when the desktop holds about 1.3 GB or less.

Prefill is 22% slower when blocks 22 and 23 sit on the CPU. With all experts on the GPU it is 12% faster than the old build. The slow case involves copying CPU-resident expert weights for large batches. This is item 2 on the roadmap.

### CUDA kernel launches per token

| Build | Launches per token | GPU op time per token under the profiler |
|---|---|---|
| Old build | 3,029 | 40.3 ms |
| upstream + realugbun fused kernels | 1,565 | 24.4 ms |
| + fused top-k weight normalization | 1,373 | 22.7 ms |

Measured with 12 expert layers on the CPU, so the 36 loop-core visits are the only expert matmuls counted.

### Correctness and quality

- Greedy completion text is identical before and after the top-k fusion.
- GSM8K, 40 questions, same seed as the earlier comparisons: 40 of 40 on the build before the attention-bias change (12 expert layers on CPU). The old build scored 39 of 40.
- GSM8K 40 and MMLU-Pro 70 on the final build in the standard placement: see the entry below when the run finishes.

### What did not work on the first try

- Upstream plus realugbun alone could not start at 64k. The dense relative-position bias needs a 6.5 GB compute buffer. Upstream's compact bias (#32740) has no CUDA path yet. capybaraonchain's commit that computes the bias inside flash attention fixed it.
- Upstream master does not build with MSVC from VS 2026 because of one `constexpr` in `llama-quant.cpp`. Patched locally.

### Earlier constrained runs (desktop apps holding 4 to 5 GB of VRAM)

| Placement | Old build | pecera |
|---|---|---|
| 12 expert layers on CPU, 8k context, decode | 49 t/s | 54 t/s |
| same, decode at 6.4k depth | 45 t/s | 50 t/s |
