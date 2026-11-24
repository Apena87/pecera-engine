"""Live view of what Hermes is thinking and doing in the running Terminal-Bench task.

Every few seconds it copies Hermes's session database out of the task container with `docker cp` and prints
the new steps: the model's reasoning, the command or tool call it chose, and the start of the result.
Nothing runs inside the container, so the task is not disturbed. Steps appear when they finish, not token by token.

usage: python peek.py [--full] [--every SECONDS]
  --full    print whole reasoning and results instead of the first part
"""
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import textwrap
import time

FULL = "--full" in sys.argv
EVERY = int(sys.argv[sys.argv.index("--every") + 1]) if "--every" in sys.argv else 8
R_MAX, O_MAX = (10**9, 10**9) if FULL else (1800, 500)
TMP = os.path.join(tempfile.gettempdir(), "pecera-peek")


def sh(*a):
    return subprocess.run(a, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=40)


def container():
    out = sh("docker", "ps", "--format", "{{.ID}}\t{{.Names}}").stdout
    for line in out.splitlines():
        cid, name = line.split("\t", 1)
        if "__env-main" in name:
            return cid, name.split("__")[0]
    return None, None


def snapshot(cid):
    shutil.rmtree(TMP, ignore_errors=True)
    os.makedirs(TMP, exist_ok=True)
    for f in ("state.db", "state.db-wal", "state.db-shm"):
        sh("docker", "cp", f"{cid}:/tmp/hermes/{f}", os.path.join(TMP, f))
    return os.path.join(TMP, "state.db")


def wrap(text, limit, indent="    "):
    text = (text or "").strip()
    cut = len(text) > limit
    text = text[:limit]
    lines = []
    for para in text.splitlines():
        lines += textwrap.wrap(para, 110, initial_indent=indent, subsequent_indent=indent) or [""]
    return "\n".join(lines) + ("\n" + indent + "[... cut, run with --full to see all]" if cut else "")


def show(row):
    role, content, tool_calls, tool_name, ts, reasoning = row
    stamp = time.strftime("%H:%M:%S", time.localtime(ts))
    if role == "assistant":
        if reasoning:
            print(f"\n[{stamp}] THINKING\n{wrap(reasoning, R_MAX)}")
        for call in json.loads(tool_calls or "[]"):
            fn = call.get("function", {})
            try:
                args = json.loads(fn.get("arguments") or "{}")
            except Exception:
                args = {"raw": fn.get("arguments")}
            main = args.get("command") or args.get("code") or args.get("path") or args.get("name") or json.dumps(args)[:300]
            print(f"\n[{stamp}] DOES  {fn.get('name')}\n{wrap(str(main), O_MAX * 2)}")
        if content and content.strip():
            print(f"\n[{stamp}] SAYS\n{wrap(content, R_MAX)}")
    elif role == "tool":
        text = content or ""
        try:
            j = json.loads(text)
            text = (j.get("output") or j.get("error") or text) if isinstance(j, dict) else text
            if isinstance(j, dict) and j.get("exit_code") not in (None, 0):
                text = f"(exit code {j['exit_code']}) {text}"
        except Exception:
            pass
        print(f"[{stamp}] RESULT {tool_name or ''}\n{wrap(str(text), O_MAX)}")


def main():
    seen = {}  # container id -> last message id shown
    last_task = None
    print("Watching for a running Terminal-Bench task. Ctrl+C to stop watching. The run itself keeps going.")
    while True:
        try:
            cid, task = container()
            if not cid:
                if last_task != "":
                    print("\n(no task container right now: between tasks, or the run is not active)")
                    last_task = ""
                time.sleep(EVERY)
                continue
            if task != last_task:
                print("\n" + "=" * 100 + f"\nTASK  {task}\n" + "=" * 100)
                last_task = task
            con = sqlite3.connect(snapshot(cid))
            rows = con.execute(
                "select id, role, content, tool_calls, tool_name, timestamp, reasoning from messages "
                "where id > ? and role in ('assistant','tool') order by id", (seen.get(cid, 0),)).fetchall()
            con.close()
            for r in rows:
                show(r[1:])
                seen[cid] = r[0]
            sys.stdout.flush()
        except KeyboardInterrupt:
            return
        except Exception:
            pass  # a copy taken mid-write can be unreadable. The next one will work.
        time.sleep(EVERY)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
