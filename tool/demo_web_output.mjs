import { readFile, writeFile, mkdir, readdir, lstat, copyFile, access } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { isIP } from 'node:net';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { constants } from 'node:fs';

export const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const firebaseKeys = Object.freeze(['FIREBASE_API_KEY', 'FIREBASE_AUTH_DOMAIN',
  'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_PROJECT_ID', 'FIREBASE_WEB_APP_ID', 'FIREBASE_WEB_VAPID_KEY']);
const publicFingerprint = '183e612755831da7a2c1e68cfa21f20d41022e1b88f5c837b7de105ac4bc34c1';
const sdkRevision = '00b0c91f06209d9e4a41f71b7a512d6eb3b9c694';
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const fail = code => { throw Object.assign(new Error(code), { code }); };
const git = (...args) => execFileSync('git', args, { cwd: repoRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
const exists = async file => { try { await access(file); return true; } catch { return false; } };
const writeNew = (file, value) => writeFile(file, JSON.stringify(value, null, 2) + '\n', { flag: 'wx' });
const rejectLink = async file => { if (await exists(file) && (await lstat(file)).isSymbolicLink()) fail('DEMO_BUILD_SYMLINK'); };

export function validatePublicConfiguration(apiOrigin, firebase) {
  let url;
  try { url = new URL(apiOrigin); } catch { fail('DEMO_API_ORIGIN_INVALID'); }
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash ||
      url.pathname !== '/' || url.port || isIP(url.hostname) ||
      !/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$/.test(url.hostname) ||
      /(^|\.)(localhost|local|internal|test|invalid|example)$/.test(url.hostname)) fail('DEMO_API_ORIGIN_INVALID');
  if (!firebase || Array.isArray(firebase) || typeof firebase !== 'object' ||
      JSON.stringify(Object.keys(firebase).sort()) !== JSON.stringify(firebaseKeys) ||
      firebaseKeys.some(key => typeof firebase[key] !== 'string')) fail('DEMO_PUBLIC_KEYS_INVALID');
  if (firebase.FIREBASE_PROJECT_ID !== 'crowdradar-hu8-web' ||
      firebase.FIREBASE_AUTH_DOMAIN !== 'crowdradar-hu8-web.firebaseapp.com' ||
      firebase.FIREBASE_MESSAGING_SENDER_ID !== '1073227225099' ||
      firebase.FIREBASE_WEB_APP_ID !== '1:1073227225099:web:4bcd63062f90c2255e4f0e') fail('DEMO_FIREBASE_PROJECT_INVALID');
  const ordered = Object.fromEntries(firebaseKeys.map(key => [key, firebase[key]]));
  if (digest(JSON.stringify(ordered)) !== publicFingerprint) fail('DEMO_PUBLIC_VALUES_UNVERIFIED');
  return { API_BASE_URL: url.origin, ...ordered };
}

export function validateSourceState(expectedSha, actualSha, status) {
  if (!/^[a-f0-9]{40}$/.test(expectedSha) || expectedSha !== actualSha) fail('DEMO_SOURCE_SHA_MISMATCH');
  if (status.trim()) fail('DEMO_SOURCE_DIRTY');
}

function assertSource(expectedSha) {
  validateSourceState(expectedSha, git('rev-parse', 'HEAD'), git('status', '--porcelain=v1', '--untracked-files=all'));
  return git('rev-parse', 'HEAD^{tree}');
}

export async function assertFreshOutput(root = repoRoot) {
  for (const relative of ['build/web', '.vercel/output', '.vercel/demo-build-state.json',
    '.vercel/demo-public-defines.json', '.vercel/demo-manifest.json']) {
    if (await exists(path.join(root, relative))) fail('DEMO_OUTPUT_ALREADY_EXISTS');
  }
}

export function buildOutputConfiguration() {
  return { version: 3, routes: [
    { src: '/(.*)', headers: { 'Cache-Control': 'no-cache, no-store, must-revalidate',
      'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'strict-origin-when-cross-origin' }, continue: true },
    { src: '/$', dest: '/index.html' },
    { handle: 'filesystem' }
  ], overrides: { 'push/firebase-messaging-sw.js': { contentType: 'application/javascript; charset=utf-8' } } };
}

async function filesUnder(directory, prefix = '') {
  const files = [];
  for (const name of (await readdir(directory)).sort()) {
    const relative = prefix ? prefix + '/' + name : name;
    const absolute = path.join(directory, name);
    const stat = await lstat(absolute);
    if (stat.isSymbolicLink()) fail('DEMO_BUILD_SYMLINK');
    if (stat.isDirectory()) files.push(...await filesUnder(absolute, relative));
    else if (stat.isFile()) files.push(relative);
    else fail('DEMO_BUILD_FILE_INVALID');
  }
  return files;
}

const rootAssets = new Set(['index.html', 'main.dart.js', 'flutter.js', 'flutter_bootstrap.js',
  'flutter_service_worker.js', 'crowdradar-push.js', 'version.json', 'favicon.png', 'manifest.json']);
export function allowStaticFile(relative) {
  if (relative === '.last_build_id' || relative.endsWith('.symbols')) return false;
  if (relative.split('/').some(part => part.startsWith('.')) ||
      /\.(dart|map|env|pem|key|p12|pfx|jks|keystore)$/i.test(relative)) fail('DEMO_BUILD_SOURCE_OR_SECRET');
  if (rootAssets.has(relative) || relative === 'push/firebase-messaging-sw.js') return true;
  if (/^(assets|canvaskit)\//.test(relative) &&
      (/\.(js|json|wasm|bin|png|jpg|jpeg|webp|svg|ico|otf|ttf|woff|woff2|frag)$/i.test(relative) || relative === 'assets/NOTICES')) return true;
  fail('DEMO_BUILD_UNEXPECTED_FILE');
}

async function prepare(expectedSha, apiOrigin, configPath, flutterRoot) {
  const sourceTree = assertSource(expectedSha);
  await rejectLink(path.join(repoRoot, '.vercel'));
  await rejectLink(path.join(repoRoot, 'build'));
  await assertFreshOutput();
  const firebase = JSON.parse(await readFile(configPath, 'utf8'));
  const defines = validatePublicConfiguration(apiOrigin, firebase);
  const sdk = JSON.parse(await readFile(path.join(flutterRoot, 'bin/cache/flutter.version.json'), 'utf8'));
  if (sdk.frameworkVersion !== '3.41.9' || sdk.dartSdkVersion !== '3.11.5' ||
      sdk.frameworkRevision !== sdkRevision) fail('DEMO_FLUTTER_VERSION_MISMATCH');
  await mkdir(path.join(repoRoot, '.vercel'), { recursive: true });
  await writeNew(path.join(repoRoot, '.vercel/demo-public-defines.json'), defines);
  await writeNew(path.join(repoRoot, '.vercel/demo-build-state.json'), {
    sourceSha: expectedSha, sourceTree, apiOrigin: defines.API_BASE_URL, publicConfigSha256: publicFingerprint,
    definesSha256: digest(JSON.stringify(defines)), flutter: sdk.frameworkVersion, dart: sdk.dartSdkVersion,
    flutterRevision: sdk.frameworkRevision, startedAt: new Date().toISOString()
  });
}

async function packageOutput(expectedSha) {
  const sourceTree = assertSource(expectedSha);
  await rejectLink(path.join(repoRoot, '.vercel'));
  await rejectLink(path.join(repoRoot, 'build'));
  const state = JSON.parse(await readFile(path.join(repoRoot, '.vercel/demo-build-state.json'), 'utf8'));
  if (state.sourceSha !== expectedSha || state.sourceTree !== sourceTree) fail('DEMO_SOURCE_SHA_MISMATCH');
  const defines = JSON.parse(await readFile(path.join(repoRoot, '.vercel/demo-public-defines.json'), 'utf8'));
  const { API_BASE_URL, ...firebase } = defines;
  validatePublicConfiguration(API_BASE_URL, firebase);
  if (digest(JSON.stringify(defines)) !== state.definesSha256) fail('DEMO_BUILD_CONFIG_CHANGED');
  const buildRoot = path.join(repoRoot, 'build/web');
  await rejectLink(buildRoot);
  const allFiles = await filesUnder(buildRoot);
  const selected = allFiles.filter(allowStaticFile);
  for (const required of ['index.html', 'main.dart.js', 'flutter_bootstrap.js', 'flutter_service_worker.js',
    'crowdradar-push.js', 'push/firebase-messaging-sw.js']) {
    if (!selected.includes(required)) fail('DEMO_BUILD_INCOMPLETE');
  }
  if ((await readFile(path.join(buildRoot, 'flutter_service_worker.js'))).length !== 0 ||
      !/_flutter\.loader\.load\(\);?\s*$/.test(await readFile(path.join(buildRoot, 'flutter_bootstrap.js'), 'utf8'))) fail('DEMO_FLUTTER_CACHE_ENABLED');
  for (const bridge of ['crowdradar-push.js', 'push/firebase-messaging-sw.js']) {
    if (digest(await readFile(path.join(buildRoot, bridge))) !== digest(await readFile(path.join(repoRoot, 'web', bridge)))) fail('DEMO_PUSH_CHANGED');
  }
  const output = path.join(repoRoot, '.vercel/output');
  if (await exists(output) || await exists(path.join(repoRoot, '.vercel/demo-manifest.json'))) fail('DEMO_OUTPUT_ALREADY_EXISTS');
  const hashes = [];
  for (const relative of selected) {
    const bytes = await readFile(path.join(buildRoot, relative));
    if (/\.(js|json|html)$/.test(relative) &&
        /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|postgres(?:ql)?:\/\/[^\s]+:[^\s]+@/.test(bytes.toString('utf8'))) fail('DEMO_BUILD_SECRET_PATTERN');
    hashes.push({ path: relative, bytes: bytes.length, sha256: digest(bytes) });
  }
  assertSource(expectedSha);
  await mkdir(output, { recursive: false }); // Existing output is never replaced.
  await mkdir(path.join(output, 'static'));
  for (const relative of selected) {
    const destination = path.join(output, 'static', relative);
    await mkdir(path.dirname(destination), { recursive: true });
    await copyFile(path.join(buildRoot, relative), destination, constants.COPYFILE_EXCL);
    if (digest(await readFile(destination)) !== hashes.find(file => file.path === relative).sha256) fail('DEMO_BUILD_CHANGED_DURING_PACKAGE');
  }
  const config = buildOutputConfiguration();
  await writeNew(path.join(output, 'config.json'), config);
  await writeNew(path.join(repoRoot, '.vercel/demo-manifest.json'), { ...state,
    completedAt: new Date().toISOString(), pwaStrategy: 'none', deployed: false,
    configSha256: digest(await readFile(path.join(output, 'config.json'))),
    lockSha256: digest(await readFile(path.join(repoRoot, 'pubspec.lock'))),
    files: hashes, excludedBuildMetadata: allFiles.filter(file => !selected.includes(file))
  });
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const [mode, ...args] = process.argv.slice(2);
    if (mode === 'prepare' && args.length === 4) await prepare(...args);
    else if (mode === 'package' && args.length === 1) await packageOutput(...args);
    else fail('DEMO_BUILD_USAGE');
    console.log('Comprobación local completada. Ningún despliegue ejecutado.');
  } catch (error) {
    console.error(/^DEMO_[A-Z_]+$/.test(error.code ?? '') ? error.code : 'DEMO_BUILD_FAILED');
    process.exitCode = 1; // Never echo rejected configuration or command output.
  }
}
