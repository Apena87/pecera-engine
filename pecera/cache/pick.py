# Lists recorded Hermes main sessions with their size, to pick replay candidates that fit in 64k context.
import glob, json
rows = []
for p in glob.glob(r"C:\Llama\tbench\jobs\tb2-*\**\hermes-session.jsonl", recursive=True):
    line = open(p, encoding="utf-8").readline().strip()
    if not line:
        continue
    s = json.loads(line)
    m = s.get("messages") or []
    chars = len(s.get("system_prompt") or "") + sum(len(json.dumps(x)) for x in m)
    na = sum(1 for x in m if x.get("role") == "assistant")
    rc = sum(1 for x in m if x.get("reasoning_content"))
    rows.append((chars, na, rc, p))
rows.sort()
for r in rows:
    if 60000 < r[0] < 160000 and r[1] >= 15:
        print(r)
print(len(rows), "sessions;", "keys:", sorted({k for x in (json.loads(open(rows[0][3], encoding="utf-8").readline())["messages"] or [{}])[:3] for k in x}))
