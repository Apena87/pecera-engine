# Roadmap

Ordered by expected gain against effort. Each item names how it will be checked.

## Where the time goes now

`GGML_CUDA_OP_PROFILE=1`, `llama-bench -p 0 -n 128`, mixB, GPU ops only. The profiler waits after every op, so its times are higher than real decode. The shares are what matter.

| Op type | Launches per token | Share of GPU op time |
|---|---|---|
| MUL_MAT on Q6_K dense weights | 353 | 36% |
| MUL_MAT on F32 (controllers, small projections) | 240 | 16% |
| MUL_MAT_ID (expert gate/up and down, loop core) | 72 | 16% |
| SCALE | 147 | 4% |
| FLASH_ATTN_EXT | 48 | 4% |
| PAD | 84 | 4% |
| TANH | 72 | 3% |
| KV SET_ROWS (k and v) | 96 | 5% |
| everything else | about 260 | 12% |

Total: 1,373 launches per token. The hridaya build is at 3,029.

## Next steps

1. **Finish the quality check.** The full-speed test is done (see RESULTS.md). Still to run on the final build: HumanEval 40, the quiz, the long-context item, a vision request, a tool-call round trip through Hermes, and contexts above 64k. `C:\Llama\inkling2-mini-fast.bat` switches to this engine only when those hold.

2. **Prefill.** The new build reads a 6.4k prompt at about 1,400 tokens/s against 1,816 for the old build, with or without expert blocks on the CPU. Candidates: hridaya's in-kernel attention bias in place of capybaraonchain's chunked version, and capybaraonchain's "per-split copies of host weights" commit (850d436) for the CPU-resident blocks. Profile pp512 on both builds in the standard placement first.

3. **Dense weights at Q6_K.** They are the largest share of decode time and more than half of the bytes read per token. Test Q5_K, Q4_K and Q8_0 for the dense tensors and the output head, picked per tensor by KL divergence against the BF16 model. Needs the quantize side of `--pad-exps` ported and the BF16 source file.

4. **Remaining small ops.** Fold the PAD before the expert down matmul into the op that precedes it. Write k and v to the KV cache in one launch. Fuse the F32 controller matmuls that share an input. Each change gets a `test-backend-ops` case and a before/after launch count.

5. **VRAM.** This is now the item with the clearest payoff. mixB with all experts on the GPU needs 11.5 GB and mixC with blocks 22-23 on the CPU needs 11.1 GB, and neither fits beside a normal desktop. Two changes would free about 1 GB: keep the token embedding in page-locked RAM and gather rows from there, and read the q4_0 KV cache inside flash attention without an F16 copy. With that, mixC runs at 75 t/s in daily use and mixB can go all-GPU.

6. **Agent-loop cache settings.** Measure `--ctx-checkpoints`, `--checkpoint-min-step` and `--cache-ram` on a real Hermes session. Inkling keeps short-convolution state, so KV shifting does not apply and reuse depends on checkpoints.

7. **Rig launcher.** `pecera\run.bat` already picks the expert placement from free VRAM and warns when the model would spill into system RAM. Still to add: a measured context size above 64k, and a test of pinning the 8 threads to the P-cores.

## Parked

- DSpark speculative decoding. No gain reported on this card class.
- EXL3 trellis experts. Better quality per byte, but a large port.
- One CUDA graph for the whole token. This is the step that would need new engine code. Revisit after items 3 to 5, using the launch count and Nsight to see what is left.
