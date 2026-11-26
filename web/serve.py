#!/usr/bin/env python3
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
PORT = int(os.environ.get("PORT", "8080"))
ROOT = os.path.dirname(os.path.abspath(__file__))
class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)
    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()
    def guess_type(self, path):
        if str(path).endswith(".wasm"):
            return "application/wasm"
        return super().guess_type(path)
if __name__ == "__main__":
    print(f"FlickDisc at http://127.0.0.1:{PORT}/", flush=True)
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
