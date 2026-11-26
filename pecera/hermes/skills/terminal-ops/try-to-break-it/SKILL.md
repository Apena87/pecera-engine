---
name: try-to-break-it
description: "Write tests from the task text the way a hidden grader would, then try to make your own solution fail. Use after a first working version exists and before declaring any graded task done."
version: 1.0.0
author: pecera-engine
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [testing, verification, edge-cases, grader, terminal]
    related_skills: [verify-before-done, terminal-task-protocol]
---

# Try to break it

Self-checks pass when the tests share the author's blind spots. In a benchmark run, 15 tasks ended with the agent reporting "all requirements verified" while a hidden test failed. The misses were rarely deep bugs. They were things the agent never tested:

- an extra file left in a folder that had to contain only the deliverable (a compiled binary next to the source)
- a cleanup step that only runs on cancellation, never exercised because the agent's test let tasks finish normally
- output that matched the example but used a different shape for other inputs (a list of lists where a list was expected)
- a server whose test script needed something the agent's manual `curl` did not exercise

## Method

1. **Read the task as the grader.** For every sentence, ask: "what assertion would I write for this?" Write that assertion as a real check in `/tmp/grader_check.sh` or `/tmp/grader_check.py`. Base it on the task text only, not on how your code works.
2. **Test the conditions the task names, not just the happy path.** If the task mentions any of these words, there is a test for it:

| Word in the task | What to run |
|---|---|
| cancel, interrupt, Ctrl-C, SIGINT, timeout | Start it, send the signal or cancel mid-run, and check the cleanup output and exit code |
| concurrent, parallel, at most N | Run with more work than the limit and check the limit holds |
| only, exactly, nothing else | `ls -la` the folder and confirm no extra files, no build outputs, no backups |
| any input, arbitrary, general | Run on at least three inputs you made up, including empty, one item and a large one |
| format, schema, type | Load the output with a strict parser and check types, not just values |
| fast, efficient, under N seconds | Time it on an input as large as the task allows |
| service, server, port | Restart it from a fresh shell, then hit it the way a client script would |
| must still, do not change, preserve | Compare checksums or `git diff` against the original |

3. **Check against a second method.** For algorithmic or numeric tasks write a slow brute-force or reference version and compare outputs on random inputs. For data recovery, count the records you expect from the source structure and compare with what you produced.
4. **Name three ways it could fail.** Write them in `/tmp/NOTES.md`, then run a check for each.
5. **Clean the deliverable area.** Remove scratch files, compiled objects, caches and backups you created inside the output folders. Keep them in `/tmp` instead.

## Rules

- A check you did not run does not count.
- If a check fails, fix the code, then rerun all checks, not only the one that failed.
- Do not weaken or delete a check to make it pass. Change the check only if you can quote the task sentence that shows it was wrong.
