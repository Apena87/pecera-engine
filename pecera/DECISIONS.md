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

## 2026-11-23, night

**The daily launcher now starts this engine.** Angel approved the switch. `C:\Llama\inkling2-mini-fast.bat` is a two-line wrapper that calls `pecera\run.bat`. The previous launcher is kept as `C:\Llama\inkling2-mini-fast-oldbuild.bat`. Before switching, the 40k-token long-context item was rerun on the new engine with mixC and scored 5 of 5.

**mixS deleted** on Angel's instruction. It can be rebuilt from the BF16 file in about five minutes with `quant\compare-quants.ps1`.

**Terminal-Bench 2.0, not 4.1.** The current release is 4.1, and its documentation says some tasks need a sandbox with GPU access. This PC's GPU is occupied by the model. Version 2.0 has 89 tasks that run in local Docker containers, and it is the version most published local-model scores use.

**Harness and agent.** Harbor, installed with `uv tool install harbor`, runs natively on Windows. The agent is Terminus 2, the benchmark's own reference agent. It runs on the host and drives each container, so it reaches llama-server on 127.0.0.1:9300 and the server does not have to listen on the network. Model name `hosted_vllm/inkling-2-mini` with `api_base` and a `model_info` block, because LiteLLM rejects unknown model names otherwise. One task at a time, one attempt per task, default timeouts. Scripts are in `pecera\tbench\`.

**Server settings for the run are the daily ones.** mixC, 64k context, reasoning effort high, thinking cap 10,000 tokens. Free VRAM at launch put four expert blocks on the CPU, so the run decodes at about 64 t/s.

**Docker Desktop needs a workaround on this Windows build.** On build 26300, AF_UNIX socket files cannot be deleted by any program (`del` fails with "The file cannot be accessed by the system"). Docker Desktop crashes at startup when it finds its own leftover sockets. `tbench\start-docker.ps1` (also `C:\Llama\start-docker.bat`) renames the two folders that hold them before starting Docker. The set-aside folders are named `*.stale-<time>` under `%LOCALAPPDATA%\Docker` and `%LOCALAPPDATA%` and can be removed once Windows allows it.

## 2026-11-23, late night: Hermes harness

**Angel asked for the Hermes harness to be pushed as far as it will go on Terminal-Bench, with strict self-checks.** He stopped the first baseline run because he needed the PC, and asked that no model be loaded while he plays. Everything below was built and checked with Docker and a fake model endpoint (`tbench\mock_llm.py`).

**The baseline run stopped at 4 of 89 tasks: 1 passed, 3 hit the time limit.** The server log shows why. Over 85 model calls, 95% of the time went to generation and 5% to reading prompts. Nine calls produced more than 3,000 tokens each and took 66% of all model time. The median call was 250 tokens. So long thinking bursts under the 10,000-token cap were using up 15-minute task limits.

**Thinking cap of 3,000 tokens for benchmark runs.** That follows from the numbers above. `run.bat` now reads `PECERA_BUDGET`, `PECERA_EFFORT`, `PECERA_QUANT`, `PECERA_PLACE` and `PECERA_VISION` from the environment, and `tbench\tonight.ps1` sets the cap and turns vision off. Daily use keeps 10,000.

**Hermes sends `reasoning_effort: medium` with every request unless its config says otherwise.** Seen in the dry run. Whether llama-server applies it over the launcher's `high` has not been tested with the real model.

**Harness contents.** Five general skills, a task prompt with a five-step work order, a container SOUL.md, a per-task time budget read from the task's own limit (first session gets 72%), and an audit session with a fresh context that checks the first session's work and fixes only what fails. Toolsets are limited to terminal, file, todo, skills and code execution, which keeps the fixed prompt near 7,500 tokens. No task names, answers or test contents are in any of it.

**Hermes is installed once, not per task.** Harbor's stock adapter installs Hermes in every container, which it documents as 6 to 10 minutes each, about 12 hours over 89 tasks. It also calls `hermes version`, which current Hermes no longer has. `tbench\build-hermes-volume.ps1` and `hermes-runtime.ps1` build one install into the Docker volume `pecera-hermes`. The adapter mounts it read-only and copies a prepared 481 MB data folder. Setup took 1 to 2 seconds in Debian 12, Ubuntu 20.04 and Debian 13 test containers. If the mount cannot be used in some image, the adapter falls back to the normal installer.

**Dry run result.** One task (`fix-git`) through the whole chain with the fake endpoint: prebuilt install used, SOUL.md and all five skills present in the system prompt, task text and time limit in the user message, 12 tools offered, audit session started with the remaining time, Harbor's tests ran, results written.

**`tbench\tonight.ps1` is the one-step launcher**, also as `C:\Llama\run-terminal-bench-tonight.bat`. It starts Docker and the server, runs one task as a check, then runs or resumes the full job. If the check fails for a harness reason it runs the Terminus 2 baseline instead and logs why.

**Daily Hermes.** The five skills are installed, SOUL.md has a short section pointing to them, and the model name in `config.yaml` is now the alias `inkling-2-mini`, which the server reports from its next start. Backups: `SOUL.md.bak-pecera-20261123` and `config.yaml.bak-pecera-20261123`.

## 2026-11-24: hard time cap for Hermes sessions, retry job for tasks that ended with an exception

- Finding from tb2-hermes-run1 (first 45 tasks): 8 tasks reached the task's own time limit. Hermes treats
  `agent.run_budget_seconds` as a soft limit (wrap-up notice, shorter API timeouts), so a session can run past it.
  In 5 of the 8 the first session used the whole limit and the audit session never started.
- Fix in `hermes/pecera_hermes.py`: the `hermes chat` command is wrapped in coreutils `timeout -k 20 <cap>`.
  First session: soft budget at 72% of the limit, hard stop 30 s later. Audit session: must end by 96% of the limit.
  Checked in an ubuntu:22.04 container that the wrapper stops the command and its child processes at the cap.
  Not yet checked end to end with the model. The first trials after the next resume are that check.
- The fix takes effect when the job is resumed, so tb2-hermes-run1 is mixed: tasks finished before the pause ran
  without the hard cap, later ones with it. RESULTS.md has to say so.
- `tbench/tonight.ps1` step 5: once all 89 tasks have a result, tasks whose result has an exception run again as a
  separate job, `<Job>-retry`. First-attempt results stay untouched. Report the two scores apart.
- `C:\Llama\tbench\pause-after-current.ps1` (not in the repo): waits for the running task to finish, then stops
  Harbor and the model server and removes the leftover task container.

- 2026-11-24 23:30: qemu-alpine-ssh and qemu-startup failed before the agent started. Their Debian bullseye images list package versions the mirror no longer serves (404), so apt-get in the install step failed. The prebuilt Hermes does not need those packages, so that failure is now logged and setup continues. Both tasks are in the retry job.

## 2026-11-26: harness changes from the Terminal-Bench failure review

Failures of the 42 tasks that did not pass, after the retry, grouped by cause:
- About 15 ended with the agent reporting every requirement verified while a hidden test failed. Examples: a compiled binary left in a folder that had to hold only the source (polyglot-c-py), cancellation cleanup never exercised (cancel-async-tasks), output shape right for the example only (merge-diff-arc-agi-task). The audit session agreed with the first session in each case.
- About 20 reached the hard time cap still working, mostly tasks the field also rarely solves (cryptanalysis, MIPS, chess, regex-chess, codegolf). Several ended with no deliverable on disk (sqlite-db-truncate).
- One destroyed its own input: opening the SQLite database deleted the WAL, leaving 5 of 11 records (db-wal-recovery).
- qemu-alpine-ssh and qemu-startup cannot pass in this setup: the grader's own script needs curl, and the Debian bullseye mirror returns 404 for it. Not a model or harness problem.
Changes:
- New skills `protect-the-inputs` and `try-to-break-it`.
- `prompt_main.txt`: deliverable at every required path within the first quarter of the time, back up given data, grader-style checks, clean output folders.
- `prompt_audit.txt`: assumes something is failing, requires new checks written from the task text, other inputs, named conditions and folder listings, before it may report nothing to change.
- `soul.md`: a short list of the failure patterns above.
- Desktop Hermes: the two skills installed and the SOUL.md section points to them (backup beside it).
Not yet measured. Next step is a rerun of the failed tasks that finished inside the time limit, compared with their first result.

## 2026-11-26: upstream caught up

**Wait for #33063, then rebase onto upstream.** The A/B in RESULTS.md shows upstream master with PR #33063 matches the current build on speed, KLD, GSM8K and the long-context item. The daily launcher stays on the current build until the PR merges, because a launcher that depends on an unmerged PR would need rebuilding when the PR changes. The test branch is `test/pr33063` in a worktree at `C:\Llama\pecera-pr33063`. DSpark and DFlash2 drafting are now in upstream and are worth a separate test, since drafting could raise decode speed if a draft model for Inkling-2-Mini is available.


**DFlash2 drafting stays off for daily use.** It speeds up plain completion and short code answers by 23-35% but slows down long-context and temperature-1.0 chat, which is most Hermes traffic. It needs one more expert block on the CPU to fit. It becomes worth retesting if roadmap item 8 (VRAM cache for hot experts) or item 5 (VRAM) frees enough memory to keep the verification batch on the GPU.


## 2026-11-26: new base

**Work moves to branch `next`: upstream master after PR #33063 merged, plus our padded expert load, the MSVC eps_eig fix and the pecera folder.** The rest of the old realugbun commits are dropped because upstream now has equivalent code (fused Inkling kernels, fused top-k norm, indexed bias). `main` on GitHub still points at the old base. Replacing it needs a force-push or a default-branch change, so that waits for Angel's OK. Until then the launcher keeps using the old build and roadmap work happens on `next`.

`pecera\build.bat` now also builds llama-perplexity, llama-quantize and the new llama-expert-stats, and accepts more targets through `PECERA_EXTRA_TARGETS`.

**2026-11-27: main moved to the new base.** Angel approved. Done without a force-push: a merge commit on next takes next's tree and keeps the old main as a parent, then main fast-forwarded to it. The old build stays in build-ugbun. The daily launcher now finds build\bin and runs the new build (checked: answers on port 9399, 64 t/s with Angel's desktop apps open).
