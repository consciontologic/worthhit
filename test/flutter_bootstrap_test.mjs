import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../web/flutter_bootstrap.js', import.meta.url), 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');
const settle = async () => {
  for (let i = 0; i < 8; i++) await Promise.resolve();
};
function boot({loaderError, rejectedLoader = false} = {}) {
  const listeners = new Map();
  const recovery = {hidden: true, remove() {this.removed = true;}};
  let entrypoint;
  const window = {
    addEventListener(type, listener, capture) {
      assert.equal(capture, true);
      listeners.set(type, listener);
    },
    removeEventListener(type, listener, capture) {
      assert.equal(capture, true);
      if (listeners.get(type) === listener) listeners.delete(type);
    },
  };
  const document = {
    baseURI: 'https://worthhit.com/',
    getElementById(id) {
      assert.equal(id, 'startup-error');
      return recovery.removed ? null : recovery;
    },
  };
  const loader = {
    load(options) {
      entrypoint = options.onEntrypointLoaded;
      if (loaderError) throw loaderError;
      return rejectedLoader ? Promise.reject(Error('Loader failed')) : Promise.resolve();
    },
  };
  vm.runInNewContext(source, {window, document, URL, _flutter: {loader}});
  return {
    recovery, listeners,
    async initialize({engineError, appError, pendingApp} = {}) {
      return entrypoint({initializeEngine: async () => {
        if (engineError) throw engineError;
        return {runApp: async () => {
          if (appError) throw appError;
          await pendingApp;
        }};
      }});
    },
    resourceFailure(src, tagName = 'SCRIPT') {
      listeners.get('error')?.({target: {tagName, src}});
    },
  };
}

test('successful and slow startup stay invisible until Flutter takes over', async () => {
  const app = boot();
  await settle();
  assert.equal(app.recovery.hidden, true);
  let finish;
  const initialization = app.initialize({pendingApp: new Promise(resolve => {finish = resolve;})});
  await settle();
  assert.equal(app.recovery.hidden, true);
  assert.equal(app.recovery.removed, undefined);
  finish();
  await initialization;
  assert.equal(app.recovery.removed, true);
  assert.equal(app.listeners.size, 0);
});

for (const [name, options] of [
  ['synchronous loader failure', {loaderError: Error('Loader failed')}],
  ['rejected loader failure', {rejectedLoader: true}],
]) {
  test(`${name} exposes recovery without rendering an error payload`, async () => {
    const app = boot(options);
    await settle();
    assert.equal(app.recovery.hidden, false);
  });
}

for (const [name, options] of [
  ['engine initialization failure', {engineError: Error('Engine failed')}],
  ['application startup failure', {appError: Error('App failed')}],
]) {
  test(`${name} exposes recovery without an unhandled rejection`, async () => {
    const app = boot();
    await app.initialize(options);
    assert.equal(app.recovery.hidden, false);
  });
}

test('only the app entrypoint resource can expose startup recovery', () => {
  const app = boot();
  app.resourceFailure('https://www.googletagmanager.com/gtag/js?id=G-G4SYW37S81');
  app.resourceFailure('https://another.example/main.dart.js');
  app.resourceFailure('https://worthhit.com/main.dart.js', 'IMG');
  assert.equal(app.recovery.hidden, true);
  app.resourceFailure('https://worthhit.com/main.dart.js');
  assert.equal(app.recovery.hidden, false);
});
