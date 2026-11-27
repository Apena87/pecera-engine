# Roadmap run, state at 2026-11-26 21:05

Running unattended, in this order (each waits for the one before it):
1. `pecera\quality\item1.ps1`: HumanEval 40, quiz, quiz_long, MMLU 70 on the next build, then HumanEval, quiz, MMLU on the old build. Logs: `results\item1_next.quality.log`, `results\item1_old.quality.log`. Answers: `C:\Llama\unsloth-b12572\tune\eval\out_item1_*`. Writes `results\item1.done`.
2. `pecera\quant\dense-sweep.ps1`: quantizes mixC-d5 (Q5_K_M dense), mixC-d4 (Q4_K_M), mixC-d4o5 (Q4_K_M, Q5_K head), then KLD and speed for those and mixC. Log: `results\dense-sweep.log`.
3. `pecera\cache\cache-sweep.ps1`: replays 3 recorded Hermes sessions (89 requests) under 5 cache settings. Log: `results\cache-sweep.log`, details `results\cache-*.json`.

Done:
- Item 8 step 1 (hot-expert gate). Top-32 coverage in blocks 20-23 over 460k tokens of Hermes sessions: 54.1, 58.7, 52.0, 57.2% (gate was about 60%). Top-64: 78.8, 82.7, 76.8, 80.5%. Files: `results\hot-experts\`. Gate missed narrowly, so step 2 is not started. A 32-slot static cache would use about 385 MiB of VRAM, the same as moving one block back to the GPU (cpu3), and the estimate is about +3 t/s over cpu3.
- Token embedding: upstream already keeps it in system RAM (input layer is CPU), so that half of item 5 needs no work.
- `GGML_CUDA_OP_PROFILE` commit cherry-picked (uncommitted) and built in `build-prof`, for items 2 and 4.

Not started: item 2/4 profiling, item 5 q4_0 FA copy, item 7 (context above 64k, P-core pinning), DFlash2 retest, Terminal-Bench follow-ups.
