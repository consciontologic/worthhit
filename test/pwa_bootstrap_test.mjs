import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../web/pwa_bootstrap.js', import.meta.url), 'utf8');
const settle = async () => {
  for (let i = 0; i < 12; i++) await Promise.resolve();
};
const deferred = () => {
  let resolve;
  let reject;
  const promise = new Promise((yes, no) => {resolve = yes; reject = no;});
  return {promise, resolve, reject};
};
function events() {
  const listeners = new Map();
  return {
    addEventListener(type, listener) {
      if (!listeners.has(type)) listeners.set(type, new Set());
      listeners.get(type).add(listener);
    },
    removeEventListener(type, listener) {listeners.get(type)?.delete(listener);},
    emit(type) {
      for (const listener of listeners.get(type) ?? []) listener({type});
    },
  };
}
function boot({supported = true, online = true, hidden = false, firstFrame = true} = {}) {
  let now = 0;
  let updateCalls = 0;
  let registerCalls = 0;
  let reloads = 0;
  let updateResult = null;
  let registerResult = null;
  const posted = [];
  const intervals = new Map();
  const window = events();
  window.location = {reload() {reloads++;}};
  const document = {
    ...events(),
    visibilityState: hidden ? 'hidden' : 'visible',
    documentElement: {dataset: {}},
  };
  const registration = {
    waiting: {postMessage: message => posted.push(message)},
    update() {
      updateCalls++;
      return updateResult ?? Promise.resolve(registration);
    },
  };
  const serviceWorker = {
    ...events(),
    controller: {postMessage: message => posted.push(message)},
    register(url, options) {
      registerCalls++;
      assert.equal(url, 'service_worker.js');
      assert.equal(options.updateViaCache, 'none');
      return registerResult ?? Promise.resolve(registration);
    },
  };
  const navigator = {onLine: online, ...(supported ? {serviceWorker} : {})};
  const context = {
    navigator, window, document, Date: {now: () => now},
    setInterval(callback, delay) {intervals.set(callback, delay); return callback;},
    clearInterval(callback) {intervals.delete(callback);},
  };
  vm.runInNewContext(source, context);
  if (firstFrame) window.emit('flutter-first-frame');
  return {
    window, document, navigator, serviceWorker, posted, intervals,
    get updateCalls() {return updateCalls;},
    get registerCalls() {return registerCalls;},
    get reloads() {return reloads;},
    setUpdateResult(value) {updateResult = value;},
    setRegisterResult(value) {registerResult = value;},
    advance(milliseconds) {now += milliseconds;},
    tick() {for (const callback of intervals.keys()) callback();},
  };
}

test('offline installation waits for the first Flutter frame, including lifecycle events', async () => {
  const app = boot({firstFrame: false});
  await settle();
  app.advance(300_000);
  app.window.emit('focus');
  app.window.emit('online');
  app.document.emit('visibilitychange');
  app.window.emit('pageshow');
  app.tick();
  await settle();
  assert.equal(app.registerCalls, 0);
  assert.equal(app.updateCalls, 0);
  assert.equal(app.intervals.size, 0);
  assert.ok(app.posted.some(message => message.type === 'CLIENT_RELEASE'),
    'An existing controller still receives this client release before rendering.');
  app.window.emit('flutter-first-frame');
  app.window.emit('flutter-first-frame');
  await settle();
  assert.equal(app.registerCalls, 1);
  assert.equal(app.updateCalls, 1);
  assert.equal(app.intervals.size, 1);
});

test('a first frame after pagehide does not start background installation', async () => {
  const app = boot({firstFrame: false});
  app.window.emit('pagehide');
  app.window.emit('flutter-first-frame');
  await settle();
  assert.equal(app.registerCalls, 0);
  assert.equal(app.intervals.size, 0);
  app.window.emit('pageshow');
  await settle();
  assert.equal(app.registerCalls, 1);
  assert.equal(app.intervals.size, 1);
});

test('startup and five-minute checks discover without activating or reloading', async () => {
  const app = boot();
  await settle();
  assert.equal(app.registerCalls, 1);
  assert.equal(app.updateCalls, 1);
  assert.deepEqual([...app.intervals.values()], [300_000]);
  app.advance(300_000);
  app.tick();
  await settle();
  assert.equal(app.updateCalls, 2);
  assert.equal(app.registerCalls, 1);
  assert.ok(app.posted.every(message => message.type === 'CLIENT_RELEASE'));
  assert.equal(app.reloads, 0);
});

test('focus, online and visibility checks share a cooldown and one in-flight request', async () => {
  const app = boot();
  await settle();
  app.window.emit('focus');
  app.window.emit('online');
  assert.equal(app.updateCalls, 1);
  const pending = deferred();
  app.setUpdateResult(pending.promise);
  app.advance(30_000);
  app.window.emit('focus');
  await settle();
  assert.equal(app.updateCalls, 2);
  app.advance(300_000);
  app.window.emit('online');
  app.document.emit('visibilitychange');
  app.tick();
  await settle();
  assert.equal(app.updateCalls, 2);
  pending.reject(Error('offline during check'));
  await settle();
  app.setUpdateResult(null);
  app.window.emit('online');
  await settle();
  assert.equal(app.updateCalls, 3);
});

test('hidden and offline pages wait until useful visibility or connection returns', async () => {
  const app = boot({online: false, hidden: true});
  await settle();
  assert.equal(app.updateCalls, 0);
  app.navigator.onLine = true;
  app.window.emit('online');
  await settle();
  assert.equal(app.updateCalls, 0);
  app.document.visibilityState = 'visible';
  app.document.emit('visibilitychange');
  await settle();
  assert.equal(app.updateCalls, 1);
  app.advance(300_000);
  app.navigator.onLine = false;
  app.tick();
  await settle();
  assert.equal(app.updateCalls, 1);
  app.navigator.onLine = true;
  app.window.emit('online');
  await settle();
  assert.equal(app.updateCalls, 2);
});

test('pagehide stops discovery and pageshow resumes without accumulating timers', async () => {
  const app = boot();
  await settle();
  app.window.emit('pagehide');
  assert.equal(app.intervals.size, 0);
  app.advance(300_000);
  app.window.emit('focus');
  app.window.emit('online');
  app.document.emit('visibilitychange');
  await settle();
  assert.equal(app.updateCalls, 1);
  app.window.emit('pageshow');
  app.window.emit('pageshow');
  await settle();
  assert.equal(app.intervals.size, 1);
  assert.equal(app.updateCalls, 2);
});

test('failed registration recovers on a later bounded connection check', async () => {
  const app = boot({online: false});
  const registration = deferred();
  app.setRegisterResult(registration.promise);
  app.navigator.onLine = true;
  app.window.emit('online');
  await settle();
  registration.reject(Error('registration unavailable'));
  await settle();
  assert.equal(app.document.documentElement.dataset.pwaUnavailable, 'true');
  app.setRegisterResult(null);
  app.advance(30_000);
  app.window.emit('online');
  await settle();
  assert.equal(app.registerCalls, 2);
  assert.equal(app.updateCalls, 1);
  assert.equal(app.document.documentElement.dataset.pwaUnavailable, undefined);
});

test('unsupported browsers stay usable without update timers', async () => {
  const app = boot({supported: false});
  await settle();
  assert.equal(app.registerCalls, 0);
  assert.equal(app.intervals.size, 0);
});
