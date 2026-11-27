# Runs inside a throwaway Docker container (no network). Grades HumanEval answers recorded by evalrun.py.
# usage (in container): python he_grade_in_container.py /data/a.jsonl [/data/b.jsonl ...]
import json, subprocess, sys, tempfile, os

for path in sys.argv[1:]:
    recs = [json.loads(l) for l in open(path, encoding="utf-8") if l.strip()]
    ok, fails = 0, []
    for r in recs:
        code = r.get("pred") or ""
        prog = code + "\n\n" + r["test"] + "\n\ncheck(" + r["entry_point"] + ")\n"
        with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as f:
            f.write(prog)
        try:
            p = subprocess.run([sys.executable, f.name], capture_output=True, timeout=20)
            passed = p.returncode == 0
        except subprocess.TimeoutExpired:
            passed = False
        os.unlink(f.name)
        ok += passed
        if not passed:
            fails.append(r["id"])
    print(json.dumps({"file": path, "n": len(recs), "passed": ok, "failed": fails}))
