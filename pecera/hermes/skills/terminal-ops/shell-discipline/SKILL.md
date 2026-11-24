---
name: shell-discipline
description: "Rules for running shell commands as an unattended agent: no interactive prompts, bounded output, timeouts, background jobs, safe file writes."
version: 1.0.0
author: pecera-engine
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [shell, bash, terminal, non-interactive, timeouts, background]
    related_skills: [terminal-task-protocol, unblock-and-debug]
---

# Shell discipline

A command that waits for input, opens a pager or prints a megabyte of output can cost the whole task. These rules prevent that.

## Never block on input

- Package managers: `apt-get install -y`, `DEBIAN_FRONTEND=noninteractive`, `pip install -q`, `npm install --no-audit --no-fund`, `conda install -y`.
- Pagers and editors: `git --no-pager log`, `GIT_PAGER=cat`, `PAGER=cat`, `systemctl --no-pager`. Never open `vi`, `nano`, `less`, `more`, `top`, `man` without piping. Use `man cmd | col -b | head -80` or `cmd --help | head -60`.
- Prompts: `ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new`, `rm -f`, `cp -f`, `unzip -o`, `git commit -m "..."`, `git merge --no-edit`, `git rebase` with `GIT_EDITOR=true`.
- REPLs: do not start `python`, `node`, `psql`, `mysql`, `sqlite3`, `gdb` bare. Pass the code: `python3 - <<'EOF'`, `sqlite3 db "select ..."`, `psql -c`, `gdb -batch -ex`.

## Bound every command

- Unknown duration: `timeout 120 cmd`. Raise the number on purpose, not by default.
- Unknown output size: add `| head -50`, `| tail -30`, or redirect to a file and look at `wc -l` first.
- Search with limits: `grep -rn --include='*.py' pattern . | head -40`, `find . -maxdepth 3 -name '*.c' | head -50`. Skip `.git`, `node_modules`, `venv`.
- Large files: `wc -c file` before reading. Use `sed -n '100,160p' file`, not `cat`.
- Binary files: `file x`, `xxd x | head`, `strings x | head -40`.

## Long jobs

Run them in the background with a log, then poll.

```
nohup make -j"$(nproc)" > /tmp/build.log 2>&1 &
echo $! > /tmp/build.pid
sleep 30; tail -5 /tmp/build.log; kill -0 "$(cat /tmp/build.pid)" 2>/dev/null && echo running || echo finished
```

- Check the log for the first error, not the last line: `grep -n -m5 -iE 'error|fatal|undefined' /tmp/build.log`.
- Before a long run, time a small version of it and estimate. If the estimate exceeds the time left, reduce the work.
- Services: start with `nohup ... &` or the service manager, wait, then test the port. A server started in a command that returns will die with that shell unless detached.

## Writing files

- Use a quoted heredoc so nothing is expanded: `cat > /path/file <<'EOF' ... EOF`. Unquoted `EOF` expands `$vars` and backticks.
- For code longer than a screen, use the file-writing tool instead of `echo` chains.
- After writing, read back the first and last lines and run a syntax check: `python3 -m py_compile f.py`, `bash -n f.sh`, `node --check f.js`, `gcc -fsyntax-only f.c`.
- `chmod +x` anything meant to be executed, and give it a shebang.
- Edit in place with care: `sed -i` on a pattern you have just confirmed with `grep -n`. Keep a copy first when the file is not under git.

## State does not carry over the way you expect

- Each tool call may be a new shell. `cd`, `export` and `source venv/bin/activate` may not persist. Put them in the same command: `cd /app && . venv/bin/activate && pytest -q`.
- Put environment a deliverable needs inside the deliverable (script, config or profile), not in your session.
- Check the exit status that matters: `cmd; echo "exit=$?"`. With pipes use `set -o pipefail`.

## Quoting

- Single quotes for literal text, double quotes when a variable must expand, and always quote paths with spaces.
- Passing code to `python3 -c` or `bash -c` through several layers breaks easily. Write a file and run the file.
