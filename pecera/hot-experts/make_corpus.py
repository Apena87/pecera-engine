# Builds a text corpus from recorded Hermes sessions (Terminal-Bench and Inkhorn jobs) for llama-expert-stats.
# Each session becomes one document: system prompt, then every message as "role: content", tool calls as JSON.
# Documents are separated by a blank line and cut at --max-chars each so no single long session dominates.
import argparse, glob, json, random

ap = argparse.ArgumentParser()
ap.add_argument("--jobs", default=r"C:\Llama\tbench\jobs")
ap.add_argument("--out", required=True)
ap.add_argument("--max-chars", type=int, default=24000)
ap.add_argument("--total-chars", type=int, default=1_400_000)
ap.add_argument("--seed", type=int, default=7)
a = ap.parse_args()

docs = []
for path in sorted(glob.glob(a.jobs + r"\**\hermes-session*.jsonl", recursive=True)):
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        s = json.loads(line)
        parts = []
        if s.get("system_prompt"):
            parts.append("system: " + s["system_prompt"])
        for m in s.get("messages") or []:
            c = m.get("content")
            if isinstance(c, list):
                c = "\n".join(x.get("text", "") for x in c if isinstance(x, dict))
            text = f"{m.get('role','?')}: {c or ''}"
            if m.get("tool_calls"):
                text += "\n" + json.dumps(m["tool_calls"], ensure_ascii=False)
            parts.append(text)
        d = "\n\n".join(parts)
        if len(d) > 2000:
            docs.append(d[: a.max_chars])

random.Random(a.seed).shuffle(docs)
out, n = [], 0
for d in docs:
    if n + len(d) > a.total_chars:
        break
    out.append(d)
    n += len(d)
open(a.out, "w", encoding="utf-8").write("\n\n".join(out))
print(f"sessions usable {len(docs)}, used {len(out)}, chars {n}")
