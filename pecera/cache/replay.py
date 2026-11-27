# Replays recorded Hermes sessions against a running llama-server to measure prompt reprocessing in an agent loop.
# For every assistant turn in a session it sends the conversation up to that turn (system prompt, earlier messages
# exactly as recorded) with max_tokens=1, the way Hermes sends a growing conversation.
# The server's timings (prompt_n = tokens it had to process, cache_n = tokens reused) show how much prefix it kept.
# usage: python replay.py --base http://127.0.0.1:9313 --sessions a.jsonl b.jsonl --out result.json [--max-turns 60]
import argparse, json, time, urllib.request

ap = argparse.ArgumentParser()
ap.add_argument("--base", default="http://127.0.0.1:9313")
ap.add_argument("--sessions", nargs="+", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--max-turns", type=int, default=60)
a = ap.parse_args()


def clean(m):
    r = {"role": m["role"], "content": m.get("content") or ""}
    if isinstance(r["content"], list):
        r["content"] = "\n".join(x.get("text", "") for x in r["content"] if isinstance(x, dict))
    if m.get("tool_calls"):
        r["tool_calls"] = m["tool_calls"]
    if m.get("tool_call_id"):
        r["tool_call_id"] = m["tool_call_id"]
    if m.get("reasoning_content"):
        r["reasoning_content"] = m["reasoning_content"]
    return r


def post(body):
    req = urllib.request.Request(a.base + "/v1/chat/completions", data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=1800) as r:
        return json.loads(r.read())


rows = []
for path in a.sessions:
    s = json.loads(open(path, encoding="utf-8").readline())
    msgs = [{"role": "system", "content": s.get("system_prompt") or ""}] + [clean(m) for m in s["messages"] if m.get("role") in ("user", "assistant", "tool")]
    turns = [i for i, m in enumerate(msgs) if m["role"] == "assistant"][: a.max_turns]
    for t in turns:
        body = {"messages": msgs[:t], "max_tokens": 1, "temperature": 0, "cache_prompt": True}
        t0 = time.time()
        try:
            r = post(body)
            tm = r.get("timings", {})
            rows.append({"session": path, "turn": t, "prompt_n": tm.get("prompt_n"), "cache_n": tm.get("cache_n"),
                         "prompt_ms": tm.get("prompt_ms"), "wall_s": round(time.time() - t0, 2)})
        except Exception as e:  # keep going, record the failure
            rows.append({"session": path, "turn": t, "error": str(e)[:300]})
        print(json.dumps(rows[-1]), flush=True)

ok = [r for r in rows if "error" not in r]
summ = {"requests": len(rows), "errors": len(rows) - len(ok),
        "prompt_tokens_processed": sum(r["prompt_n"] or 0 for r in ok),
        "prompt_tokens_reused": sum(r["cache_n"] or 0 for r in ok),
        "prompt_s": round(sum(r["prompt_ms"] or 0 for r in ok) / 1000, 1),
        "wall_s": round(sum(r["wall_s"] for r in ok), 1)}
json.dump({"summary": summ, "rows": rows}, open(a.out, "w"), indent=1)
print("SUMMARY " + json.dumps(summ))
