"""Run the production Dart navigation bridge with a restricted WindowProxy."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build" / "navigation-web-regression"
MARKER = "PASS: production browser navigation on Dart JavaScript"

RUNNER = r"""'use strict';
const assert = require('node:assert/strict');
globalThis.self = globalThis;
globalThis.navigationMode = 'normal';
const activeAnchors = new Set();
const navigations = [];
let denied = 0;
let popupCalls = 0;
let historyCalls = 0;
const body = {
  appendChild(anchor) { activeAnchors.add(anchor); return anchor; },
};
globalThis.document = {
  currentScript: null,
  baseURI: 'https://worthhit.com/preview/',
  get body() { return navigationMode === 'no-body' ? null : body; },
  createElement(tag) {
    assert.equal(tag, 'a');
    const anchor = {
      click() {
        assert.ok(activeAnchors.has(this), 'Attach the link before dispatch');
        assert.equal(this.target, '_blank');
        assert.deepEqual(new Set(this.rel.split(' ')), new Set(['noopener', 'noreferrer']));
        assert.equal(this.referrerPolicy, 'no-referrer');
        assert.ok(/^https?:\/\//.test(this.href), 'The first navigation must use its final URL');
        if (navigationMode === 'denied') { denied++; throw Error('Navigation denied'); }
        navigations.push(this.href);
      },
      remove() { activeAnchors.delete(this); },
    };
    return anchor;
  },
};
globalThis.window = {
  document,
  history: { back() {
    if (navigationMode === 'history-denied') throw Error('History denied');
    historyCalls++;
  } },
  // Some mobile/standalone hosts do not expose a usable child WindowProxy.
  // Opening a placeholder cannot safely be followed by DOM/location mutation.
  open() { popupCalls++; return null; },
};
globalThis.verifyNavigation = () => {
  assert.deepEqual(navigations, [
    'https://worthhit.com/about/',
    'https://worthhit.com/terms/',
    'https://worthhit.com/liability/',
    'https://github.com/consciontologic/worthhit',
    'http://localhost:8766/about/',
  ]);
  assert.equal(popupCalls, 0, 'Do not open a blank placeholder');
  assert.equal(historyCalls, 1, 'Internal Back traverses existing browser history');
  assert.equal(denied, 1);
  assert.equal(activeAnchors.size, 0, 'Remove links after success and denial');
};
require('./navigation_test.js');
"""


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    compiled = OUTPUT / "navigation_test.js"
    compiler = subprocess.run(
        [os.environ.get("DART", "dart"), "compile", "js", "-O2",
         "tool/navigation_web_regression.dart", "-o", str(compiled)],
        cwd=ROOT,
        check=False,
    )
    if compiler.returncode:
        return compiler.returncode
    runner = OUTPUT / "run.cjs"
    runner.write_text(RUNNER, encoding="utf-8")
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
        print("Browser navigation regression did not confirm completion.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
