---
name: terminal-task-protocol
description: "Step-by-step method for a task that must be finished in a Linux terminal and is graded by hidden checks on the final machine state."
version: 1.0.0
author: pecera-engine
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [terminal, shell, benchmark, autonomous, checklist, verification]
    related_skills: [verify-before-done, try-to-break-it, protect-the-inputs, shell-discipline, unblock-and-debug, environment-recon]
---

# Terminal task protocol

Use this when you are given one task to complete alone in a terminal, nobody will answer questions, and something else will check the result afterwards.

## The grader sees only the final state

Tests run after you stop. They look at files, command output, running services and exit codes. They do not read your explanation. A correct idea that is not on disk scores zero. A file at the wrong path scores zero.

## Order of work

1. **Requirements.** Read the task twice. Write `/tmp/NOTES.md` with one checklist line per requirement, in the task's own words: every path, file name, format, column, value, port, command, user, permission and limit. Words like "exactly", "only", "must", "do not" each get a line.
2. **Recon.** Look at the machine before changing it. See the `environment-recon` skill. Keep it to a handful of commands.
3. **Plan.** Three to six lines in NOTES.md. Name the simplest approach that meets every checklist line. If the task gives an example of input and output, the plan must reproduce that example.
4. **Smallest working version first.** Get something that satisfies the checklist end to end, even if slow or plain. Save it at the required path. Then improve.
5. **Test like the checker.** Run the result from a fresh shell with the exact command the task names. Read output files back. Compare against the task's examples character by character.
6. **Audit.** Use the `verify-before-done` skill. Every checklist line needs evidence from a command you ran after your last change.
7. **Stop.** No summary is needed beyond one or two lines. Do not keep editing after the audit passes.

## Time

- You have a fixed wall-clock limit. Assume it is short.
- By the halfway point there must be a result on disk at the required path, even if incomplete.
- Do not start a long build, download or training run without checking how long it takes. Try a small version first and time it.
- If an approach has cost a third of the time with no working output, switch to the simpler approach.

## Reading the task literally

- Use the paths and names given. `/app/out.txt` is not `./out.txt` unless you are in `/app`.
- If the task says "print", write to stdout. If it says "write to a file", write the file. Do both only if asked.
- Do not add headers, comments, logging, blank lines or extra files that were not requested.
- When two readings are possible, take the more literal one and note the assumption in NOTES.md.
- Tests often use inputs you have not seen. Solve the general case the task describes, not only its example.

## Things that lose points for no reason

- Leaving the solution in `/tmp` or the home directory when a path was specified.
- A script that works only from one working directory. Use absolute paths inside it or `cd` to its own directory.
- A missing shebang or execute bit on a file that will be run directly.
- A service started in the foreground of a shell that then exits. Start it so it survives, and check it answers.
- Editing or deleting test files, fixtures or data the task told you to leave alone.
- Stopping to ask a question or to report progress.
