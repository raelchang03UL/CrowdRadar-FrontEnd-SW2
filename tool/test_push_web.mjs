import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { runInNewContext } from 'node:vm';
import test from 'node:test';

async function worker(bindings = ['current']) {
  let background;
  const handlers = {}, notifications = [], sent = [], focused = [];
  const clients = bindings.map((binding, index) => ({
    postMessage(message, ports) {
      if (message.type === 'CROWDRADAR_BINDING') ports[0].postMessage(binding);
      else sent.push(message);
    },
    focus: async () => focused.push(index),
  }));
  const self = {
    location: {href: 'http://localhost/firebase-messaging-sw.js?projectId=qa'},
    clients: {matchAll: async () => clients},
    registration: {showNotification: async (title, options) => notifications.push({title, ...options})},
    addEventListener: (type, callback) => { handlers[type] = callback; },
  };
  runInNewContext(await readFile(new URL('../web/push/firebase-messaging-sw.js', import.meta.url), 'utf8'), {
    self, URL, MessageChannel, setTimeout, clearTimeout, importScripts() {},
    firebase: {initializeApp() {}, messaging: () => ({onBackgroundMessage: callback => { background = callback; }})},
  });
  return {background, handlers, notifications, sent, focused};
}
const payload = {data: {registrationId: 'current', userId: '1', placeId: '7'}};

test('worker receives only a matching live session and uses generic visible text', async () => {
  const w = await worker();
  await w.background(payload);
  assert.equal(w.notifications.length, 1);
  assert.equal(w.notifications[0].title, 'Cambió la saturación de un favorito');
  assert.equal(w.notifications[0].body, 'Abre CrowdRadar para consultar el lugar.');
  assert.equal(w.notifications[0].data.placeId, '7');
});

test('worker discards a previous account/device binding and closed app', async () => {
  for (const bindings of [['other-account'], []]) {
    const w = await worker(bindings);
    await w.background(payload);
    assert.equal(w.notifications.length, 0);
  }
});

test('worker click focuses only the bound session and delivers exact place', async () => {
  const w = await worker(['another-session', 'current']);
  let completion, closed = false, stopped = false;
  w.handlers.notificationclick({
    notification: {data: payload.data, close() { closed = true; }},
    stopImmediatePropagation() { stopped = true; }, waitUntil(promise) { completion = promise; },
  });
  await completion;
  assert.equal(closed, true); assert.equal(stopped, true);
  assert.deepEqual(w.focused, [1]);
  assert.equal(w.sent.length, 1);
  assert.equal(w.sent[0].type, 'CROWDRADAR_OPEN');
  assert.equal(w.sent[0].data.placeId, '7');
});

test('old notification click cannot focus a new session', async () => {
  const w = await worker(['new-session']);
  let completion;
  w.handlers.notificationclick({notification: {data: payload.data, close() {}}, stopImmediatePropagation() {}, waitUntil(promise) { completion = promise; }});
  await completion;
  assert.equal(w.focused.length, 0); assert.equal(w.sent.length, 0);
});

test('Web bridge waits until messaging worker becomes active', async () => {
  let stateChanged;
  const installed = {state: 'installing', addEventListener(type, callback) { stateChanged = callback; }};
  const registration = {active: null, installing: installed};
  const window = {};
  runInNewContext(await readFile(new URL('../web/crowdradar-push.js', import.meta.url), 'utf8'), {
    window, URL, setTimeout, clearTimeout, document: {baseURI: 'http://localhost/'},
    navigator: {serviceWorker: {register: async path => {
      assert.equal(path, 'push/firebase-messaging-sw.js?projectId=qa');
      return registration;
    }, addEventListener() {}}},
  });
  let ready = false;
  const pending = window.crowdRadarPush.prepare('push/firebase-messaging-sw.js?projectId=qa').then(() => { ready = true; });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(ready, false);
  installed.state = 'activated'; stateChanged();
  await pending;
  assert.equal(ready, true);
});

test('logout cleanup closes only CrowdRadar messaging notifications', async () => {
  const closed = [];
  const registration = scope => ({scope, getNotifications: async () => [{close() { closed.push(scope); }}]});
  const window = {};
  runInNewContext(await readFile(new URL('../web/crowdradar-push.js', import.meta.url), 'utf8'), {
    window, URL, setTimeout, clearTimeout, document: {baseURI: 'http://localhost/'},
    navigator: {serviceWorker: {getRegistrations: async () => [registration('http://localhost/'), registration('http://localhost/push/')], addEventListener() {}}},
  });
  window.crowdRadarPush.clear();
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(closed, ['http://localhost/push/']);
});

async function fidBridge(indexedDB) {
  const window = {};
  runInNewContext(await readFile(new URL('../web/crowdradar-push.js', import.meta.url), 'utf8'), {
    window, indexedDB, URL, setTimeout, clearTimeout,
    navigator: {serviceWorker: {addEventListener() {}}},
  });
  return window.crowdRadarPush;
}

test('FID migration check does not create absent database or touch legacy token cache', async () => {
  const bridge = await fidBridge({databases: async () => [], open() { assert.fail('Must not create database'); }});
  assert.equal(await bridge.hasFidRegistration('current-app'), false);
});

test('FID migration only counts the exact app key in a readonly transaction', async () => {
  for (const countValue of [0, 1]) {
    const bridge = await fidBridge({databases: async () => [{name: 'firebase-messaging-database'}], open() {
      const request = {};
      queueMicrotask(() => {
        request.result = {objectStoreNames: {contains: name => name === 'firebase-messaging-fid-registration-store'}, close() {},
          transaction(name, mode) {
            assert.equal(mode, 'readonly');
            assert.equal(name, 'firebase-messaging-fid-registration-store');
            const transaction = {objectStore: () => ({count(key) {
              assert.equal(key, 'current-app');
              const count = {};
              queueMicrotask(() => { count.result = countValue; count.onsuccess(); transaction.oncomplete(); });
              return count;
            }, get() { assert.fail('Must not read FID/token/auth'); }, put() { assert.fail('Must not modify cache'); }})};
            return transaction;
          }};
        request.onsuccess();
      });
      return request;
    }});
    assert.equal(await bridge.hasFidRegistration('current-app'), countValue === 1);
  }
});

test('FID migration check aborts a database creation race', async () => {
  let aborted = false;
  const bridge = await fidBridge({databases: async () => [{name: 'firebase-messaging-database'}], open() {
    const request = {transaction: {abort() { aborted = true; queueMicrotask(() => request.onerror()); }}};
    queueMicrotask(() => request.onupgradeneeded());
    return request;
  }});
  await assert.rejects(bridge.hasFidRegistration('current-app'));
  assert.equal(aborted, true);
});
