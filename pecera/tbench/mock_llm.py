"""Fake OpenAI-compatible endpoint for dry runs of the agent harness. No model, no GPU.

Answers every chat request with one short final message and records each request, so a dry run shows
exactly what the agent sends: system prompt, tool schemas, sampling parameters, and how many calls it makes.
usage: python mock_llm.py [port] [log.jsonl]
"""
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 9301
LOG = sys.argv[2] if len(sys.argv) > 2 else r"C:\Llama\tbench\mock-requests.jsonl"
MODEL = "inkling-2-mini"
TEXT = "Dry run: no model is attached, so nothing was done. Stopping."


def rec(method, path, body):
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps({"t": time.strftime("%H:%M:%S"), "method": method, "path": path, "body": body}) + "\n")


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _json(self, obj, code=200):
        b = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        rec("GET", self.path, None)
        p = self.path.split("?")[0].rstrip("/")
        if p.endswith("/models"):
            self._json({"object": "list", "data": [{"id": MODEL, "object": "model", "owned_by": "llamacpp",
                                                    "meta": {"n_ctx_train": 1048576, "n_ctx": 65536}}]})
        elif p.endswith("/props"):
            self._json({"default_generation_settings": {"n_ctx": 65536}, "n_ctx": 65536, "model_alias": MODEL})
        elif p.endswith("/health"):
            self._json({"status": "ok"})
        else:
            self._json({"error": "not found"}, 404)

    def do_POST(self):
        n = int(self.headers.get("Content-Length", "0"))
        try:
            body = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            body = {}
        rec("POST", self.path, body)
        usage = {"prompt_tokens": 100, "completion_tokens": 12, "total_tokens": 112}
        if body.get("stream"):
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            base = {"id": "chatcmpl-mock", "object": "chat.completion.chunk", "created": int(time.time()), "model": MODEL}

            def ev(d):
                self.wfile.write(("data: " + json.dumps(d) + "\n\n").encode())
                self.wfile.flush()

            ev({**base, "choices": [{"index": 0, "delta": {"role": "assistant", "content": ""}, "finish_reason": None}]})
            ev({**base, "choices": [{"index": 0, "delta": {"content": TEXT}, "finish_reason": None}]})
            ev({**base, "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}], "usage": usage})
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()
            self.close_connection = True
        else:
            self._json({"id": "chatcmpl-mock", "object": "chat.completion", "created": int(time.time()), "model": MODEL,
                        "choices": [{"index": 0, "message": {"role": "assistant", "content": TEXT}, "finish_reason": "stop"}],
                        "usage": usage})


ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
