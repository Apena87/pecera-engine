---
name: protect-the-inputs
description: "Keep the files a task gives you intact while you work on them: back up first, open data read-only, never delete inputs. Use before touching any database, log, image, dataset or repo the task provides."
version: 1.0.0
author: pecera-engine
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [data-recovery, sqlite, backup, safety, terminal]
    related_skills: [terminal-task-protocol, verify-before-done]
---

# Protect the inputs

Many tasks hand you broken or partial data and ask you to recover, convert or analyse it. The data on disk is the only copy. If a command changes it, the answer is gone and no amount of later work brings it back.

This happened in a benchmark run: the task gave a SQLite database with a WAL file. An early command opened the database normally, SQLite checkpointed and removed the WAL, and only 5 of 11 records could be recovered after that.

## Before the first command that reads the data

1. Copy everything the task names, plus files that sit beside it, to a backup folder:
   `mkdir -p /tmp/orig && cp -a <dir-or-files> /tmp/orig/`
2. Record checksums: `sha256sum <files> > /tmp/orig/SHA256SUMS`
3. Work on copies in `/tmp/work`, not on the originals, until you know what you are doing.

Files that look like leftovers are often the data: `*-wal`, `*-shm`, `*-journal`, `*.bak`, `*.tmp`, `*.swp`, `*.orig`, `.git/` folders, lock files, partial downloads. Copy them too and keep them next to their main file in the copy.

## Opening data without changing it

| Kind | Safe way to read it |
|---|---|
| SQLite | Work on a copy of the db together with its `-wal` and `-shm`. To read the original in place use `sqlite3 'file:/path/db?mode=ro&immutable=1'` or Python `sqlite3.connect('file:...?mode=ro', uri=True)`. Never run `VACUUM`, `.recover` into the same file, or a write, on the original |
| WAL or journal recovery | Parse the WAL bytes directly (frame headers, page images) from the copy. Opening the db normally may checkpoint and delete the WAL |
| Git repos | `git stash list`, `git reflog`, `git fsck --lost-found` before any reset, checkout or gc. Never run `git gc`, `git prune` or `git reset --hard` until the lost data is found |
| Disk or filesystem images | Mount read-only (`-o ro,loop`) or use tools that read the image file without mounting |
| Archives | List first (`tar tf`, `7z l`, `unzip -l`). Extract into a new empty folder |
| Logs and datasets | Read with `head`, `grep`, `python`. Never edit in place with `sed -i` unless the task says to |

## Rules

- Never `rm`, `mv` or truncate a file the task gave you unless the task tells you to.
- If you must change an input in place, the task will say so. Even then, back it up first.
- When a recovery attempt fails, restore from `/tmp/orig` before trying the next method, so every attempt starts from the original state.
- Before you stop, run `sha256sum -c /tmp/orig/SHA256SUMS` for any input the task said to leave alone, and restore anything that changed.
