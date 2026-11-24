# Results

All runs on la-pecera (i9-13900KF, RTX 4070 Ti 12 GB), 64k context unless stated, q4_0 KV cache, flash attention on, 8 threads, one slot. Raw output is in `pecera/results/`.

"Old build" is hridaya423 `inkling-fast` at 273fae8, the build the PC used before this project.

## Correction, 2026-11-23 evening

The first version of this file said the new build needs 0.9 GB less VRAM than the old one and that all experts fit on the GPU with a normal desktop. Both statements were wrong. The numbers came from `nvidia-smi`, which reports dedicated memory only. In those runs the card was full, so the reading stopped near 11.5 GB while the rest sat in shared system memory. `pecera\vram-probe.ps1` now reads the server process's dedicated and shared memory from the Windows GPU counters. Measured that way, the two builds need the same memory. The statement that the vision projector adds 0.56 GB was wrong for the same reason. It adds nothing.

## Memory and speed by file and placement

Server process memory after one 6.4k-token request, desktop holding 0.4 to 0.7 GB. Decode speed is at 6.4k depth in the same run.

| Build, file, expert blocks on CPU | Dedicated VRAM | Decode | Prefill, 6.4k prompt |
|---|---|---|---|
| Old build, mixB, 22-23 | 10,433 MiB | 65 t/s | 1,816 t/s |
| pecera, mixB, 22-23 | 10,515 MiB | 76 t/s | 1,417 t/s |
| pecera, mixB, none | 11,480 MiB | 81 t/s | 1,398 t/s |
| pecera, mixC, 22-23 | 11,055 MiB | 75 t/s | 1,399 t/s |
| pecera, mixC, 21-23 | 10,667 MiB | 72 t/s | 1,369 t/s |
| pecera, mixC, 20-23 | 10,281 MiB | 69 t/s | 1,239 t/s |

The card has 12,282 MiB. A config fits when its number plus the desktop's use stays under that. All experts on the GPU needs the desktop under about 600 MiB, which only happens with the PC locked or idle.

Short-context decode from `bench.ps1`, run back to back: old build 67 to 68 t/s, pecera 76 to 80 t/s with mixB in the same placement. An earlier all-GPU run measured 86 to 87 t/s and 2,064 t/s prefill while part of its memory was in shared RAM. Treat that as an upper reading, not as a usable mode.

Prefill is about 22% slower than the old build in every placement measured here. Roadmap item 2.

## Quant comparison

KL divergence against the Q8_0 file on 50 chunks of 512 tokens of wikitext-2 test, `llama-perplexity --kl-divergence`, old build's binary, blocks 22-23 on CPU. Q8_0 perplexity on this text: 6.914. The mixB value reproduces the 0.048 on its model card.

| File | Recipe for GPU-side experts | Size | Mean KLD | 99% KLD | Top token matches Q8_0 | PPL against Q8_0 |
|---|---|---|---|---|---|---|
| mixB | blocks 0-5 IQ2_S, loop core IQ3_XXS, 18-21 mixed | 10.29 GiB | 0.0471 ± 0.0009 | 0.423 | 91.11 ± 0.25% | +3.15% |
| mixC | all IQ3_XXS | 10.81 GiB | 0.0381 ± 0.0008 | 0.321 | 91.72 ± 0.24% | +2.06% |
| mixS | mixB with the loop core at IQ3_S | 10.84 GiB | 0.0424 ± 0.0010 | 0.415 | 91.92 ± 0.24% | +3.45% |

mixC is the better use of the extra half gigabyte: mean KLD drops 19%, the tail drops 24%, and the perplexity gap shrinks by a third. mixS improves the top-token match by a similar amount but leaves perplexity where it was. In all three files blocks 22-23 are IQ4_NL and non-expert tensors are Q6_K.

Speed is the same for all three in the same placement (78 to 80 t/s short context, 70 to 71 t/s at 6.4k depth in `bench.ps1`). mixC costs 540 MiB of VRAM, so it either needs a light desktop or one or two more expert blocks on the CPU, as in the table above.

Whether a KLD of 0.038 against 0.047 changes task results is not shown. The 40-question and 70-question tests cannot resolve a difference this small.

## CUDA kernel launches per token

| Build | Launches per token | GPU op time per token under the profiler |
|---|---|---|
| Old build | 3,029 | 40.3 ms |
| upstream + realugbun fused kernels | 1,565 | 24.4 ms |
| + fused top-k weight normalization | 1,373 | 22.7 ms |

Measured with 12 expert layers on the CPU, so the 36 loop-core visits are the only expert matmuls counted.

## Correctness and quality of the engine (mixB, same seed and questions as the earlier comparisons)

| Test | Old build | pecera | Run time, old | Run time, pecera |
|---|---|---|---|---|
| GSM8K, 40 questions | 39 | 40 | 394 s | 395 s (longer answers, 72 t/s against 63) |
| MMLU-Pro, 70 questions | 55 | 56 | 2,097 s | 1,703 s (70 t/s) |

A one-question difference on either test is inside run-to-run variation at temperature 1.0. The result is that scores held.

- Greedy completion text is identical before and after the top-k fusion.
- `pecera\run.bat` test launches: server up in 9 s, text answered, and the test image (text plus a red circle) read correctly in 2.5 s.
- Long-context item (40,331-token log, five questions) on this engine with mixC, four expert blocks on the CPU: 5 of 5, the same answers as mixB on the old build. The prompt was read at 1,156 t/s against 1,685 on the old build, and the answer was written at 58 t/s at that depth. Total 45 s against 33 s. The slower prefill is roadmap item 2.
- Terminal-Bench 2.0 pipeline check: Harbor's oracle agent solved 2 of 2 sample tasks, and Terminus 2 with this engine and mixC solved `fix-git` in 2 minutes 10 seconds over 15 model calls. The full 89-task run started 2026-11-23 20:41. Results will be added here.
- Not rerun on this engine yet: HumanEval, the quiz, contexts above 64k.

## What did not work on the first try

- Upstream plus realugbun alone could not start at 64k. The dense relative-position bias needs a 6.5 GB compute buffer. Upstream's compact bias (#32740) has no CUDA path yet. capybaraonchain's commit that computes the bias inside flash attention fixed it.
- Upstream master does not build with MSVC from VS 2026 because of one `constexpr` in `llama-quant.cpp`. Patched locally.
- A single download connection to Hugging Face ran at 2 MB/s. `bf16\pdl.py` pulls the file over 8 ranged connections and checks the SHA-256.
