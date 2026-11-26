---
name: verify-before-done
description: "Final audit before declaring a terminal task finished: evidence for every requirement, checked against the real machine state."
version: 1.0.0
author: pecera-engine
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [verification, audit, checklist, terminal, self-check]
    related_skills: [terminal-task-protocol, try-to-break-it, protect-the-inputs, shell-discipline]
---

# Verify before done

Run this audit as the last step of any task that will be checked by tests or by another person. It takes a few minutes and catches most avoidable failures.

## Rule

A requirement is done only when a command you ran after your last change shows it. Memory of having done it does not count. "It should work" does not count.

## Audit steps

1. Re-read the original task text from the top. Do not rely on your notes for this step.
2. Open the checklist in `/tmp/NOTES.md`. Add any requirement you find in the task that is missing from it.
3. For each line, run the check and paste the short result next to the line:

| Requirement type | Evidence to collect |
|---|---|
| A file must exist | `ls -la <exact path>` and `head` or `wc -c` on it. Zero bytes is a failure unless empty is correct |
| File content or format | Read it back. For JSON `python3 -m json.tool < f`. For CSV check header, delimiter, row count. For YAML or TOML load it with a parser |
| A program or script | Run it from `cd /` with the exact command line in the task. Check stdout, stderr and `echo $?` |
| An example in the task | Feed the example input, diff the output against the example output |
| Numeric answer | Recompute by a second route, or check units, rounding and precision asked for |
| A service or port | `curl -s -m 5 localhost:<port>/...` or `ss -ltnp`. Confirm it still runs after your shell command returns |
| A git state | `git status`, `git log --oneline -5`, `git branch -a`. Confirm the commit, branch and working tree the task asked for |
| Build or install | Run the built binary or import the package from a fresh shell |
| Tests in the repo | Run them. All of the ones the task mentions must pass. Do not edit tests to make them pass |
| Permissions or ownership | `stat -c '%a %U:%G %n' <path>` |
| "Do not change X" | `git diff --stat` or checksums show X is untouched |

4. Check the things tasks rarely say but tests often assume:
   - The final file ends with a newline when it is a text file, and has no trailing spaces or Windows line endings unless requested.
   - No debug prints, temp files or backup copies sit beside the deliverable.
   - Relative paths in your script still resolve when it is run from another directory.
   - The result does not depend on a variable, virtualenv or background job that exists only in your current shell.
5. If any line fails, fix it, then repeat the checks for that line and for anything the fix touched.
6. Stop when every line has passing evidence. Do not make further changes after that.

## When time is almost out

Do the cheapest checks first: the deliverable exists at the exact path, it is not empty, and the main command runs without an error. A result that exists and runs is worth more than an unfinished improvement. Never leave a file half-edited. If an edit is in progress with a minute left, revert to the last version that ran.
