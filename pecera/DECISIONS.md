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
