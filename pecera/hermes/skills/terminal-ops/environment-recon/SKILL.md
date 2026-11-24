---
name: environment-recon
description: "A short, fixed set of commands to learn an unfamiliar Linux machine or container before starting a task there."
version: 1.0.0
author: pecera-engine
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [recon, environment, container, linux, terminal]
    related_skills: [terminal-task-protocol, shell-discipline]
---

# Environment recon

Spend two or three commands on this before the first change. Skip anything the task makes irrelevant.

## One command for the basics

```
pwd; id -un; cat /etc/os-release 2>/dev/null | head -2; nproc; free -m 2>/dev/null | sed -n 2p; df -h . | tail -1; ls -la
```

## Tools

```
for t in python3 pip3 gcc g++ make cmake git curl wget node npm go rustc cargo java sqlite3 jq tmux docker R; do command -v $t >/dev/null && printf '%s ' "$t"; done; echo
python3 --version 2>&1; pip3 list 2>/dev/null | wc -l
```

Check for a network connection only if you will need one: `curl -sI -m 6 https://pypi.org | head -1`.

## The project

- `ls -la` the directory the task names, and one level down: `find . -maxdepth 2 -not -path './.git/*' | head -60`.
- Read what explains the project before reading code: `README*`, `Makefile`, `pyproject.toml`, `requirements*.txt`, `package.json`, `Cargo.toml`, `CMakeLists.txt`, `Dockerfile`, `.env.example`.
- Tests show what "correct" means: `ls tests test 2>/dev/null`, then read the test that matches the task.
- In a git repository: `git --no-pager status --short | head -20; git --no-pager log --oneline -8; git branch -a | head -20; git stash list | head`.
- Data files: `file x`, `wc -lc x`, `head -5 x`. Check the delimiter, header and encoding before writing a parser.
- Running services: `ss -ltnp 2>/dev/null | head -20`, `ps aux --sort=-%mem | head -12`.

## What to write down

Three lines in your notes: where the work happens, which tools exist, and anything surprising (no network, read-only directory, an old Python, a missing compiler). The surprise is what changes the plan.

## Limits

- No broad `find /` or `grep -r /` without `-maxdepth`, a name filter and `| head`.
- Do not read whole large files during recon.
- Do not install anything yet. First learn what is already there.
