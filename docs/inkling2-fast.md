# Inkling 2 Mini on a 12 GB GPU

This branch (`inkling-fast`) makes [Inkling 2 Mini](https://huggingface.co/thinkingmachines/Inkling-2-Mini) fast on a single 12 GB card. On an RTX 4070 Ti with 64K context, it decodes at 51-64 tok/s and processes prompts at about 1500 tok/s. Upstream llama.cpp with the IQ4_NL GGUF and part of the experts on the CPU gives 29-34 tok/s decode and 88 tok/s prompt processing at the same context.

The ready-made GGUF is at [hridya423/Inkling-2-Mini-12GB-GGUF](https://huggingface.co/hridya423/Inkling-2-Mini-12GB-GGUF). The short setup guide is at [hridaya423/inkling-2-mini-12gb](https://github.com/hridaya423/inkling-2-mini-12gb).

The speedup has two parts. A new quant puts every expert that the GPU runs at 2-3 bits, so the model fits in VRAM. Graph changes then cut the CUDA kernels per token from about 5000 to about 3500.

## Results

Hardware: RTX 4070 Ti 12 GB, i9-13900K, Windows, CUDA 12.4. Quality is measured against Q8_0 on 50 chunks of 512 tokens of wikitext-2 (`llama-perplexity --kl-divergence`). "Top-1" is the share of tokens where the quant and Q8_0 pick the same top token.

| Model | Size | KLD | Top-1 | Decode, 22K prompt | Decode, short prompt | Prompt processing, 22K |
|---|---|---|---|---|---|---|
| upstream IQ4_NL, part of the experts on the CPU | 16.4 GiB | 0.009 | 95.7% | 29-34 tok/s | 29-34 tok/s | 88 tok/s |
| **mixB, this branch** | 10.3 GiB | 0.048 | 90.9% | 51-53 tok/s | 61-64 tok/s | ~1500 tok/s |

PPL(mixB) / PPL(Q8_0) is 1.034. With `llama-bench` (pp512, tg128, 6 runs), mixB on this branch does pp 2183-2191 and tg 63.5-63.8. The same file on the branch before the graph changes does pp 1673-1686 and tg 54.1-54.5.

## Changes

- `llama-quantize --pad-exps`. The expert down rows of Inkling 2 are 1152 wide, which is not a multiple of 256. Without this flag every IQ2 and IQ3 type falls back to IQ4_NL. The flag zero-pads the rows to the block size, and the graph pads the activation to match.
- Fused relative-position bias in CUDA flash attention. Upstream builds a dense per-head bias mask, so the compute buffer at 64K was 6.5 GB. It is now about 1 GB, so large ubatches work.
- New ops `GGML_OP_DEPTH_MIX` and `GGML_OP_TANH_GATE_MIX` (CPU and CUDA) for the block attention residuals and the loop controllers.
- CUDA fusions: `ssm_conv` with the residual add and scale, and top-k MoE weight normalization with an epsilon.
- Graph caching: normalized block stacks, controller inputs, zero sinks and the scaled bias table are built once per graph.

`test-backend-ops` covers the new ops and fusions (`DEPTH_MIX`, `TANH_GATE_MIX`, `SSM_CONV_RESIDUAL_SCALE`, `TOPK_MOE`).

## Build

Build as usual with CUDA:

```sh
git clone -b inkling-fast https://github.com/hridaya423/llama.cpp
cd llama.cpp
cmake -B build -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

## Make the mixB quant

Get the BF16 GGUF, the imatrix and the vision projector from [ggml-org/Inkling-2-Mini-GGUF](https://huggingface.co/ggml-org/Inkling-2-Mini-GGUF):

```sh
hf download ggml-org/Inkling-2-Mini-GGUF Inkling-2-Mini-BF16.gguf imatrix.gguf mmproj-Inkling-2-Mini-BF16.gguf --local-dir src
```

Then quantize. Keep the `--tensor-type` patterns in this order, most specific first:

```sh
LOOPS='6|7|8|9|10|11|12|13|14|15|16|17'
./build/bin/llama-quantize --pad-exps --imatrix src/imatrix.gguf \
  --token-embedding-type q8_0 --output-tensor-type q6_k \
  --tensor-type "blk\.(22|23)\.ffn_.*_exps=iq4_nl" \
  --tensor-type "blk\.($LOOPS)\.ffn_.*_exps=iq3_xxs" \
  --tensor-type "blk\.(18|19|20|21)\.ffn_down_exps=iq3_xxs" \
  --tensor-type "ffn_.*_exps=iq2_s" \
  src/Inkling-2-Mini-BF16.gguf Inkling-2-Mini-mixB.gguf Q6_K
```

The result has these expert types:

- Layers 6-17 (the loop core, run three times per token): IQ3_XXS.
- Layers 18-21: IQ3_XXS down, IQ2_S gate and up.
- Layers 22-23: IQ4_NL. These run on the CPU.
- All other layers: IQ2_S.

The non-expert tensors are Q6_K. The file needs this branch, because the padded down tensors do not load upstream.

## Run

```sh
./build/bin/llama-server -m Inkling-2-Mini-mixB.gguf \
  --mmproj src/mmproj-Inkling-2-Mini-BF16.gguf --no-mmproj-offload \
  -ngl 99 -fa on --jinja -c 65536 -b 512 -ub 512 -ctk q8_0 -ctv q8_0 -t 8 -np 1 \
  -ot "blk\.(22|23)\.ffn_.*_exps=CPU"
```

This uses 11.6 GB of VRAM, including the Windows desktop. Chat, tool calls, vision and prompt caching work.

## Notes

- Close to the 12 GB limit, the Windows driver moves memory to system RAM without an error, and speed drops. `-ub 1024` at 64K does this. Watch `nvidia-smi` if you change the context or the ubatch.
- Decode speed depends on kernel launches, not on memory bandwidth. All-IQ2_XXS and all-IQ2_S quants decode at the same speed. Lower bits only help the model fit.
- Each expert layer on the CPU costs about 5 tok/s. Mixes with more CPU layers and IQ3_XXS for all GPU experts reach 91.8% top-1, but they decode at 45-48 tok/s on a 22K prompt.
- Upstream bug: if the experts of a loop-core layer (6-17) are on the CPU, op-offload gives NaN. Use `--no-op-offload` for such configurations.
- Things that did not help on this card: DSpark speculative decoding (k=2 equals the baseline, other k are slower), f16 KV cache (+0.6 GB at 32K), and `--moe-cache-mib` (12-15 tok/s).
- If you quantize the DSpark draft to Q8_0, add `--tensor-type dspark_fuse=f32`. Otherwise the [4,4] fuse tensor becomes F16 and `softmax.cu` asserts.
