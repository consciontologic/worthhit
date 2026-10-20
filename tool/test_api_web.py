"""Exercise the production OpenRouter price parser after Dart-to-JS compilation."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build" / "api-web-regression"
MARKER = "PASS: production API pricing on Dart JavaScript"


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    compiled = OUTPUT / "client_test.js"
    compiler = subprocess.run(
        [
            os.environ.get("DART", "dart"), "compile", "js", "-O2",
            "tool/api_web_regression.dart", "-o", str(compiled),
        ],
        cwd=ROOT,
        check=False,
    )
    if compiler.returncode:
        return compiler.returncode
    # Dart's browser-target bootstrap expects `self`. Mapping it to the Node
    # global is sufficient; all HTTP calls are injected MockClients.
    runner = OUTPUT / "run.cjs"
    runner.write_text(
        "'use strict';\nglobalThis.self = globalThis;\n"
        "require('./client_test.js');\n",
        encoding="utf-8",
    )
    result = subprocess.run(
        [os.environ.get("NODE", "node"), str(runner)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    sys.stdout.write(result.stdout)
    if result.returncode:
        return result.returncode
    if MARKER not in result.stdout:
        print("Dart JavaScript regression did not confirm completion.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
