---
name: unblock-and-debug
description: "What to do when a command, build, test or install fails during an unattended terminal task: read the real error, change one thing, fall back in a fixed order."
version: 1.0.0
author: pecera-engine
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [debugging, errors, build, install, fallback, terminal]
    related_skills: [shell-discipline, terminal-task-protocol, systematic-debugging]
---

# Unblock and debug

## The loop

1. **Read the first error.** Later errors are usually consequences. `grep -n -m3 -iE 'error|fatal|traceback|undefined|not found|denied' log`.
2. **State the cause in one sentence** in your notes before changing anything. If you cannot, you need more information, not another attempt.
3. **Change one thing.** Re-run the smallest command that reproduces the failure, not the whole pipeline.
4. **Compare.** Same error means the diagnosis was wrong. A new error means progress. Write down which.
5. **Two failures of the same approach is the limit.** On the third try, do something different in kind, not a variation.

## Get information instead of guessing

- Missing command: `which x || command -v x`, then `apt-cache policy x`, `pip index versions x`, or look for it under `/usr/local`, `/opt`, `~/.local/bin`.
- Missing module or header: the error names it. Find the package that provides it (`apt-file search`, `pip download --no-deps`, `dpkg -S`), or search the disk: `find / -name 'name*' -not -path '*/proc/*' 2>/dev/null | head`.
- Unknown flags or API: `cmd --help | head -60`, `python3 -c "import m; help(m.f)" | head -40`, read the source file. Do not invent a flag.
- Wrong output: print the intermediate values. Reduce the input to the smallest case that is still wrong.
- Hangs: it is waiting for input, for the network or for a lock. Re-run with `timeout 20` and `</dev/null`, check `ps aux | head -30`.
- Permission denied: `id`, `ls -la` the path and its parent. Try `sudo -n true` to see whether sudo exists without a password.
- Network failures: `curl -sI -m 8 https://pypi.org | head -1`. If there is no network, stop trying to download and use what is installed.

## Fallback order for installs and builds

1. What is already on the machine (`python3 -c "import x"`, `ls /usr/lib`, vendored copies in the repo).
2. The system package manager, non-interactive.
3. The language package manager into a user or virtual environment (`pip install --user`, `python3 -m venv`).
4. A prebuilt binary or wheel.
5. Building from source. Check the time it needs first.
6. Writing the small piece you need yourself with the standard library.

Version conflicts: read which version the task or the project files pin (`requirements.txt`, `pyproject.toml`, `package.json`, `Makefile`, `CMakeLists.txt`) and install that one. Do not upgrade unrelated packages.

## When the task itself seems impossible

- Re-read it. The usual cause is a missed sentence or a file in the working directory you did not open.
- Look for provided material: `ls -la`, README, tests, sample data, a `Makefile`, hidden files.
- If part of the task cannot be done in the time left, finish the parts that can and leave them in a valid state. Partial credit needs a result that runs.

## Do not

- Repeat the same failing command hoping for a different result.
- Hide an error with `|| true`, `2>/dev/null`, a bare `except: pass`, or by deleting the failing test.
- Change many things at once. You will not know which one mattered.
- Fix a symptom in the output by hard-coding the expected answer. Hidden tests use other inputs.
