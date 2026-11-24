# Decisions

Newest at the bottom. Each entry gives the choice and the reason.

## 2026-11-23

**Patched fork, not a new engine.** Angel approved rebasing and patching. llama-server already provides the chat templates, tool-call parsing, reasoning budget, vision projector and OpenAI API that Hermes uses. Custom CUDA code goes in only where the profiler shows time.

**Private repo, GitHub Actions disabled.** His other repos are private. Upstream's CI workflows would run on every push and use Actions minutes.

**Base is upstream master plus realugbun's fused kernels, not the hridaya fork.** Measured on this PC with mixB: the hridaya build launches 3,029 CUDA kernels per token, upstream plus realugbun launches 1,565. Upstream also carries the loop fix (#32704) and the compact attention bias (#32740). Individual hridaya commits are cherry-picked when they still add something.

**nahcmon's fork is used for ideas, not code.** It is built on the older Unsloth Inkling tree with a different graph and its own file format, so its commits do not apply here.

**Only the load side of `--pad-exps` is ported.** Upstream rewrote `llama-quant.cpp` two days ago (#15550), and the quantize side conflicts with it. mixB loads and runs. The old build in `C:\Llama\inkling-fast\build\bin` can still produce padded quants until the option is ported by hand.

**DSpark drafting is not carried over.** It sits in an open upstream PR (#32218). The hridaya notes report no gain from it on a 4070 Ti, and nahcmon measured it slower on a 12 GB card. It can be added later as a switch for coding work.

**Third-party code is read before it is built.** The realugbun diff was scanned for process, file and network calls before the first build. It contains CUDA kernels, graph changes and tests only.

**First comparison ran with 12 expert layers on the CPU.** Desktop apps held 4 to 5 GB of VRAM, including two OrcaSlicer windows with unsaved work that were left open. The standard config needs about 10.4 GB free. The constrained test puts the same load on both builds, so the relative result is valid. The absolute numbers are lower than the standard config.

**Lively Wallpaper no longer starts with Windows.** Angel asked for this. The startup task is disabled and Lively's own setting is off. A backup of its settings file is next to the original with the suffix `.bak-pecera`.

**Attention bias from capybaraonchain, not from hridaya.** Without a fused bias the server needs a 6.5 GB compute buffer at 64k and fails to start. capybaraonchain's commit was written on top of the realugbun branch, so it applied with three small conflicts against upstream's own bias API (#32740). Both APIs are kept. They share two source slots of the attention op, so the CPU path now picks one by upstream's flag. hridaya's in-kernel version may be faster for prefill and stays a candidate.

**`pecera\run.bat` is a separate launcher.** It uses port 9300 and the same sampling, effort and thinking cap as `C:\Llama\inkling2-mini-fast.bat`, which is left unchanged. It puts every expert on the GPU when 11,250 MiB or more is free and otherwise keeps blocks 22 and 23 on the CPU. The threshold comes from the measured 10.9 GB peak plus a margin.

**OrcaSlicer was not closed.** Angel asked for the two projects to be saved and the app closed. The PC was locked at that point, so the windows could not be operated. Locking also dropped desktop VRAM use to about 1.2 GB, which made the full-speed runs possible without closing anything. A third, empty OrcaSlicer window that the attempt opened was closed again.

## 2026-11-23, evening

**VRAM is measured per process, with shared memory, from now on.** The claim of 0.9 GB of new headroom was a measurement error. See the correction at the top of RESULTS.md. `vram-probe.ps1` is the tool for any statement about fit.

**mixC is the default file in `pecera\run.bat`, mixB is kept.** Angel asked for a stronger quant. mixC has 19% lower KL divergence against Q8_0 at the same speed in the same placement. It needs 540 MiB more, so the launcher moves one or two more expert blocks to the CPU when VRAM is short: 75, 72 or 69 t/s depending on room. All three are faster than the old build's 65 t/s on mixB. `set QUANT=mixB` in the bat gives the smaller file at 76 t/s.

**mixS is not used.** Same memory cost as mixC with less gain. The file is still on disk until Angel says to delete it.

**The all-GPU placement is manual only.** It needs the desktop under about 600 MiB. `set PLACE=gpu` with `QUANT=mixB` still works for a locked or idle PC.

**BF16 source, imatrix, Q8_0 reference and its logits are kept in `C:\Llama\inkling-fast\bf16`** (about 80 GB). They are needed for the dense-weight experiments in roadmap item 3 and for any further KLD comparison.
