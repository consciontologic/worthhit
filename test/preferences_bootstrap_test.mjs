import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../web/preferences_bootstrap.js', import.meta.url), 'utf8');
function boot(saved, {denied = false, about = false} = {}) {
  const writes = {};
  const document = {
    documentElement: {dataset: {}},
    querySelector: selector => selector === 'base'
      ? (about ? null : {})
      : {setAttribute: (key, value) => {writes[`${selector}:${key}`] = value;}},
  };
  const localStorage = {getItem(key) {
    assert.equal(key, 'worthhit.preferences.v1');
    if (denied) throw Error('storage denied');
    return saved;
  }};
  vm.runInNewContext(source, {document, localStorage});
  return {theme: document.documentElement.dataset.theme, writes};
}
test('saved dark appearance changes shell, toolbar and favicon', () => {
  const result = boot('{"theme":"dark"}');
  assert.equal(result.theme, 'dark');
  assert.equal(result.writes['meta[name="theme-color"]:content'], '#161A18');
  assert.equal(result.writes['link[rel="icon"]:href'], 'favicon-dark.svg');
});
test('about uses its parent icon path', () => {
  assert.equal(boot('{"theme":"light"}', {about: true}).writes['link[rel="icon"]:href'], '../favicon-light.svg');
});
test('system, malformed and blocked storage preserve browser preference', () => {
  for (const value of [null, '{', '{"theme":"system"}', '{"theme":"url(evil)"}', 'x'.repeat(1025)]) {
    assert.equal(boot(value).theme, undefined);
  }
  assert.equal(boot('', {denied: true}).theme, undefined);
});
