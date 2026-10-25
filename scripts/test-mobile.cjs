/* Actual ETS startup/account services with native boundaries replaced locally.
 * No network, real credentials, device storage, or ArkUI rendering. */
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const ts = require(process.argv[2] || 'typescript');
const base = path.resolve(__dirname, '../entry/src/main/ets');
const cache = new Map();
const preferences = new Map();
let repositoryCalls = 0;
let repositoryInit = async () => { repositoryCalls++; };
let accountInitGate = async () => {};
let synchronousKdfCalls = 0;
const kits = {
  '@kit.AbilityKit': {},
  '@kit.ArkData': { preferences: { async getPreferences() {
    await accountInitGate();
    return { async get(key, fallback) { return preferences.get(key) ?? fallback; },
      async put(key, value) { preferences.set(key, value); }, async flush() {} };
  } } },
  '@kit.CryptoArchitectureKit': { cryptoFramework: {
    createRandom: () => ({ generateRandomSync: size => ({ data: crypto.randomBytes(size) }) }),
    createKdf: () => ({
      generateSecret: spec => new Promise((resolve, reject) => {
        crypto.pbkdf2(spec.password, spec.salt, spec.iterations, spec.keySize, 'sha256', (error, bytes) => {
          if (error) reject(error); else resolve({ data: new Uint8Array(bytes) });
        });
      }),
      generateSecretSync() { synchronousKdfCalls++; throw new Error('UI-blocking KDF'); }
    })
  } }
};
function load(file) {
  if (file.endsWith('/repository/RepositoryManager.ets')) {
    return { RepositoryManager: { init: () => repositoryInit() } };
  }
  if (cache.has(file)) return cache.get(file).exports;
  const mod = { exports: {} }; cache.set(file, mod);
  const source = fs.readFileSync(file, 'utf8');
  const js = ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021
  } }).outputText;
  const localRequire = id => id in kits ? kits[id] : load(path.resolve(path.dirname(file), id).replaceAll('\\', '/') + '.ets');
  vm.runInThisContext('(function(require,module,exports){' + js + '\n})', { filename: file })(localRequire, mod, mod.exports);
  return mod.exports;
}
const { AccountService: accounts } = load((base + '/service/AccountService.ets').replaceAll('\\', '/'));
const { UserRole } = load((base + '/model/User.ets').replaceAll('\\', '/'));
const { StartupService: startup } = load((base + '/service/StartupService.ets').replaceAll('\\', '/'));

test('startup exposes its real stage, shares one initialization and opens the repository once', async () => {
  startup.pending = null;
  let release;
  accountInitGate = () => new Promise(resolve => { release = resolve; });
  const first = startup.initialize({}); const second = startup.initialize({});
  assert.equal(first, second);
  assert.equal(startup.stage, '正在读取本机账号');
  assert.equal(repositoryCalls, 0);
  release(); await first;
  assert.equal(repositoryCalls, 1);
  assert.equal(startup.stage, '本地数据已就绪');
  accountInitGate = async () => {};
});

test('failed startup is retryable and never pretends the in-memory repository is ready', async () => {
  startup.pending = null;
  repositoryInit = async () => { throw new Error('fixture native failure'); };
  await assert.rejects(startup.initialize({}), /本地数据初始化失败/);
  assert.equal(startup.pending, null);
  assert.equal(startup.stage, '正在打开本地事件与任务数据库');
  repositoryInit = async () => { repositoryCalls++; };
  await startup.initialize({});
  assert.equal(startup.stage, '本地数据已就绪');
});

test('registration yields to the event loop and preserves PBKDF2-SHA256 compatibility', async () => {
  accounts.resetForTest(); preferences.clear(); await accounts.init({});
  let yielded = false;
  setImmediate(() => { yielded = true; });
  const result = await accounts.registerUser('member_async', '测试成员', 'Password2026A', UserRole.STUDENT);
  assert.equal(result.success, true); assert.equal(yielded, true); assert.equal(synchronousKdfCalls, 0);
  const stored = JSON.parse(preferences.get('accounts'))[0];
  const expected = crypto.pbkdf2Sync('Password2026A', Buffer.from(stored.passwordSalt, 'hex'), 120000, 32, 'sha256').toString('hex');
  assert.equal(stored.passwordHash, expected);
  assert.equal(JSON.stringify(stored).includes('Password2026A'), false);
});

test('existing credential login, rejection and password change work with asynchronous derivation', async () => {
  await accounts.logout();
  assert.equal((await accounts.login('member_async', 'wrong')).success, false);
  assert.equal((await accounts.login('member_async', 'Password2026A')).success, true);
  assert.equal((await accounts.changePassword('Password2026A', 'Changed2026B')).success, true);
  await accounts.logout();
  assert.equal((await accounts.login('member_async', 'Password2026A')).success, false);
  assert.equal((await accounts.login('member_async', 'Changed2026B')).success, true);
  assert.equal(synchronousKdfCalls, 0);
});

test('asynchronous invitation verification rejects reused codes and preserves role restrictions', async () => {
  accounts.setCurrentUserForTest({ id: 'admin-fixture', name: '测试管理', role: UserRole.ADMIN });
  const issued = await accounts.issueInternalInvitation(UserRole.SECURITY);
  assert.equal(issued.success, true);
  const joined = await accounts.registerInternalUser(issued.code, 'security_async', '测试巡检', 'Security2026B');
  assert.equal(joined.success, true); assert.equal(joined.user.role, UserRole.SECURITY);
  assert.equal((await accounts.registerInternalUser(issued.code, 'security_again', '再次测试', 'Security2026C')).success, false);
  assert.equal((await accounts.registerUser('bad_role', '测试角色', 'Password2026A', UserRole.ADMIN)).success, false);
  assert.equal(synchronousKdfCalls, 0);
});
