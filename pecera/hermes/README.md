# Hermes harness for terminal tasks

Goal: get the highest Terminal-Bench 2.0 score this PC's model can reach when Hermes Agent drives it, and make the same habits available in daily Hermes use.

## What is here

| Piece | File | What it does |
|---|---|---|
| Skills | `skills/terminal-ops/*/SKILL.md` | Five skills: `terminal-task-protocol`, `verify-before-done`, `shell-discipline`, `unblock-and-debug`, `environment-recon` |
| Task prompt | `prompt_main.txt` | Wraps every task with the time limit, a five-step work order and the rules that cost points when ignored |
| Audit prompt | `prompt_audit.txt` | Used by a second, fresh Hermes session that checks the first one's work against the task and fixes only what fails |
| Persona | `soul.md` | SOUL.md for the container: Angel's own SOUL.md cut down to what applies when nobody is there to answer |
| Harbor agent | `pecera_hermes.py` | Subclass of Harbor's Hermes adapter that applies all of the above |
| Runner | `..\tbench\run-tb-hermes.ps1` | Starts a Terminal-Bench run with this harness |

## How a task runs

1. Harbor starts the task's container and installs Hermes in it.
2. The adapter writes `SOUL.md`, the skills and a small config: toolsets `terminal, file, todo, skills, code_execution`, context compression at 60%, tool output capped at 20 KB, 300 s command timeout.
3. It reads the task's own time limit from Harbor's task cache. The first session gets 72% of it as `run_budget_seconds`, so Hermes receives its wrap-up notice before the harness would cut it off.
4. If at least 150 s remain afterwards, the audit session runs with the remaining time as its budget.
5. Harbor's hidden tests grade the final state.

Options: `--ak audit=false` turns the audit session off, `--ak main_fraction=0.8` changes the split, `--ak toolsets=...` changes the tools.

## Rules for this harness

- Nothing in it is specific to a benchmark task. No task names, no solutions, no test contents. The skills are general terminal practice.
- Changes are kept only when a run shows they help. Each run goes into `..\RESULTS.md` with its settings.
- Failure analysis of finished runs may add general advice (for example "commands hung on a pager"), never task answers.

## In daily Hermes

The five skills are also installed in `%LOCALAPPDATA%\hermes\skills\terminal-ops`, and a short section at the end of `SOUL.md` points to them. The original SOUL.md is saved beside it as `SOUL.md.bak-pecera-20261123`.

## Plan

1. Baseline: Terminus 2 with mixC at daily settings (running since 2026-11-23 20:41).
2. Hermes with this harness, same model and server settings, full 89 tasks.
3. Compare task by task. Where Hermes loses a task the baseline solved, read both logs and fix the general cause.
4. Then test one change at a time on a fixed 20-task subset: audit on or off, thinking cap 4,000 against 10,000, sampling temperature, budget split.
