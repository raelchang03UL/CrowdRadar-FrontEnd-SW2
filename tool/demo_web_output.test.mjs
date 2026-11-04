import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, mkdir, mkdtemp, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { repoRoot, validatePublicConfiguration, validateSourceState, assertFreshOutput,
  buildOutputConfiguration, allowStaticFile } from './demo_web_output.mjs';

const knownPublic = JSON.parse(await readFile(new URL('./demo_firebase_public.json', import.meta.url), 'utf8'));
const sha = 'a'.repeat(40);
const validOrigin = 'https://api.crowdradar.example.com';

test('known public config remains public; routing preserves a missing worker as 404', () => {
  const defines = validatePublicConfiguration(validOrigin + '/', knownPublic);
  assert.equal(defines.API_BASE_URL, validOrigin);
  assert.equal(Object.keys(defines).length, 7);
  const config = buildOutputConfiguration();
  assert.equal(config.version, 3);
  assert.match(config.routes[0].headers['Cache-Control'], /no-cache/);
  assert.equal(config.routes[0].headers['X-Content-Type-Options'], 'nosniff');
  assert.equal(config.routes.filter(route => route.dest && new RegExp(route.src).test('/push/missing.js')).length, 0);
  assert.equal(allowStaticFile('push/firebase-messaging-sw.js'), true);
  assert.equal(allowStaticFile('.last_build_id'), false);
});

test('unknown/secret keys, unverified values and source files are rejected', () => {
  for (const extra of ['JWT_SECRET', 'DATABASE_URL', 'private_key', 'FIREBASE_ANDROID_APP_ID']) {
    assert.throws(() => validatePublicConfiguration(validOrigin, { ...knownPublic, [extra]: 'synthetic-secret' }), /DEMO_PUBLIC_KEYS_INVALID/);
  }
  assert.throws(() => validatePublicConfiguration(validOrigin, { ...knownPublic, FIREBASE_API_KEY: 'synthetic-secret' }), /DEMO_PUBLIC_VALUES_UNVERIFIED/);
  for (const file of ['.env', 'assets/config.key', 'assets/source.dart', 'main.dart.js.map', 'pubspec.yaml']) {
    assert.throws(() => allowStaticFile(file), /DEMO_BUILD_/);
  }
});

test('HTTP, local/private literals, userinfo, path and query are not API origins', () => {
  for (const origin of ['http://localhost:3053', 'http://api.crowdradar.example.com', 'https://localhost',
    'https://127.0.0.1', 'https://10.1.2.3', 'https://[::1]', 'https://host.local',
    'https://user:synthetic@api.crowdradar.example.com', validOrigin + '/api',
    validOrigin + '?token=synthetic', validOrigin + '#synthetic', validOrigin + ':8443']) {
    assert.throws(() => validatePublicConfiguration(origin, knownPublic), /DEMO_API_ORIGIN_INVALID/);
  }
});

test('Firebase identity cannot silently switch to another project/application', () => {
  for (const key of ['FIREBASE_PROJECT_ID', 'FIREBASE_WEB_APP_ID', 'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_AUTH_DOMAIN']) {
    assert.throws(() => validatePublicConfiguration(validOrigin, { ...knownPublic, [key]: 'other' }), /DEMO_FIREBASE_PROJECT_INVALID/);
  }
});

test('a mismatched commit or staged/unstaged/untracked source fails closed', () => {
  validateSourceState(sha, sha, '');
  assert.throws(() => validateSourceState('b'.repeat(40), sha, ''), /DEMO_SOURCE_SHA_MISMATCH/);
  for (const status of [' M lib/main.dart', 'M  web/index.html', '?? unknown.json']) {
    assert.throws(() => validateSourceState(sha, sha, status), /DEMO_SOURCE_DIRTY/);
  }
});

test('previous build/package/evidence is preserved and blocks a new run', async () => {
  const qa = path.resolve(repoRoot, '../qa');
  await mkdir(qa, { recursive: true });
  for (const relative of ['build/web', '.vercel/output', '.vercel/demo-build-state.json', '.vercel/demo-manifest.json']) {
    const fixture = await mkdtemp(path.join(qa, 'frontend-tooling-fixture-'));
    await assertFreshOutput(fixture);
    const target = path.join(fixture, relative);
    await mkdir(path.dirname(target), { recursive: true });
    if (path.extname(target)) await writeFile(target, 'previous evidence');
    else await mkdir(target);
    await assert.rejects(assertFreshOutput(fixture), /DEMO_OUTPUT_ALREADY_EXISTS/);
    if (path.extname(target)) assert.equal(await readFile(target, 'utf8'), 'previous evidence');
  }
});
