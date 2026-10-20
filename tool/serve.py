"""Local Pages-like subpath server, bound to loopback only."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1] / "build/web"


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_GET(self):
        path = urlsplit(self.path).path
        if path == "/":
            self.send_response(302)
            self.send_header("Location", "/worthit/")
            self.end_headers()
            return
        if path.startswith("/worthit/"):
            self.path = self.path[len("/worthit"):]
        super().do_GET()

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()

    def log_message(self, format, *args):
        # Avoid recording URLs, query strings, form content or credentials.
        pass


if __name__ == "__main__":
    print("Worthit preview: http://127.0.0.1:8766/worthit/", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 8766), Handler).serve_forever()
