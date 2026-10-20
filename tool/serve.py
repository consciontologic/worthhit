"""Local static root-path server, bound to loopback only."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "build/web"


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()

    def log_message(self, format, *args):
        # Avoid recording URLs, query strings, form content or credentials.
        pass


if __name__ == "__main__":
    print("Worthhit preview: http://127.0.0.1:8766/", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 8766), Handler).serve_forever()
