# parallel ranged download with resume, for one large Hugging Face file. Writes <out>.chunks.json as it goes.
# usage: python pdl.py <url> <out> [workers]
import sys, os, json, time, threading, queue, hashlib, requests

url, out = sys.argv[1], sys.argv[2]
workers = int(sys.argv[3]) if len(sys.argv) > 3 else 8
CH = 32 * 1024 * 1024
state_path = out + ".chunks.json"
log_path = out + ".pdl.log"

def log(msg):
    with open(log_path, "a", encoding="ascii", errors="replace") as f:
        f.write(time.strftime("%H:%M:%S ") + msg + "\n")

h = requests.head(url, allow_redirects=False, timeout=30)
size = int(h.headers.get("X-Linked-Size") or 0)
etag = (h.headers.get("X-Linked-ETag") or "").strip('"')
if not size:
    h2 = requests.head(url, allow_redirects=True, timeout=30)
    size = int(h2.headers["Content-Length"])
n = (size + CH - 1) // CH

if os.path.exists(state_path):
    done = set(json.load(open(state_path)))
else:
    have = os.path.getsize(out) if os.path.exists(out) else 0
    done = set(range(have // CH))  # keep the prefix an earlier sequential download wrote
if not os.path.exists(out):
    open(out, "wb").close()
f = open(out, "r+b")
f.truncate(size)
lock = threading.Lock()
q = queue.Queue()
for i in range(n):
    if i not in done:
        q.put(i)
log("size %d chunks %d todo %d etag %s" % (size, n, q.qsize(), etag))

def save():
    tmp = state_path + ".tmp"
    json.dump(sorted(done), open(tmp, "w"))
    os.replace(tmp, state_path)

def work():
    s = requests.Session()
    while True:
        try:
            i = q.get_nowait()
        except queue.Empty:
            return
        start = i * CH
        end = min(size, start + CH) - 1
        ok = False
        for attempt in range(30):
            try:
                t0 = time.time(); buf = bytearray()
                with s.get(url, headers={"Range": "bytes=%d-%d" % (start, end)}, stream=True, timeout=(15, 30)) as r:
                    if r.status_code != 206:
                        raise RuntimeError("status %d" % r.status_code)
                    for part in r.iter_content(1024 * 1024):
                        buf += part
                        el = time.time() - t0
                        if el > 15 and len(buf) / el < 1.5e6:
                            raise RuntimeError("slow connection, retry")
                if len(buf) != end - start + 1:
                    raise RuntimeError("short read")
                with lock:
                    f.seek(start); f.write(buf); done.add(i)
                    if len(done) % 16 == 0:
                        f.flush(); save()
                ok = True
                break
            except Exception as e:
                s = requests.Session()
                time.sleep(1 + attempt % 5)
        if not ok:
            log("chunk %d failed" % i)

ts = [threading.Thread(target=work, daemon=True) for _ in range(workers)]
for t in ts: t.start()
last = len(done)
while any(t.is_alive() for t in ts):
    time.sleep(30)
    with lock:
        d = len(done)
    log("chunks %d/%d  %.1f MB/s" % (d, n, (d - last) * CH / 30 / 1e6)); last = d
with lock:
    f.flush(); save()
f.close()
missing = n - len(done)
result = "missing %d" % missing
if missing == 0 and etag and len(etag) == 64:
    hsh = hashlib.sha256()
    with open(out, "rb") as g:
        while True:
            b = g.read(64 * 1024 * 1024)
            if not b: break
            hsh.update(b)
    result += " sha256 %s" % ("OK" if hsh.hexdigest() == etag else "MISMATCH " + hsh.hexdigest())
log("finished " + result)
open(os.path.join(os.path.dirname(out), "download.done"), "w").write("%s %s\n" % (result, time.strftime("%H:%M:%S")))
