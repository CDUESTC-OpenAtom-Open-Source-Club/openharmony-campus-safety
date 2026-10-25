/* Executes the actual ETS services after TypeScript transpilation. Native kits are boundary doubles,
 * so this validates application behavior, not device encryption, TLS, or ArkUI rendering. No network. */
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const ts = require(process.argv[2] || 'typescript');
const root = path.resolve(__dirname, '..');
const cache = new Map();
let user = { id: 'user-a' };
let assetFailure = false;
const records = new Map();
const asset = {
  Tag: { ALIAS: 1, SECRET: 2, RETURN_TYPE: 3, ACCESSIBILITY: 4, SYNC_TYPE: 5, CONFLICT_RESOLUTION: 6 },
  ReturnType: { ALL: 0 }, Accessibility: { DEVICE_UNLOCKED: 2 }, SyncType: { NEVER: 0 },
  ConflictResolution: { OVERWRITE: 0 }, ErrorCode: { NOT_FOUND: 24000002 },
  async add(record) {
    if (assetFailure) throw { code: 24000005, message: 'native secret echo' };
    assert.equal(record.get(4), 2); assert.equal(record.get(5), 0);
    records.set(Buffer.from(record.get(1)).toString(), new Map(record));
  },
  async query(query) {
    if (assetFailure) throw { code: 24000005, message: 'native secret echo' };
    const found = records.get(Buffer.from(query.get(1)).toString());
    if (!found) throw { code: 24000002 };
    return [found];
  },
  async remove(query) { records.delete(Buffer.from(query.get(1)).toString()); }
};
let behavior;
let confirmation = async () => ({ index: 0 });
let lastSession;
const sessions = [];
const rcp = {
  Request: class { constructor(url, method, headers, content) { Object.assign(this, { url, method, headers, content }); } },
  createSession(options) {
    const session = {
      options, canceled: false, closed: false,
      cancel() { this.canceled = true; this.reject?.(new Error('native key echo')); },
      close() { this.closed = true; },
      async fetch(request) { this.request = request; return behavior(this, request); }
    };
    lastSession = session; sessions.push(session); return session;
  }
};
const kits = {
  '@kit.ArkUI': { promptAction: { showDialog: (options) => confirmation(options) }, window: {} },
  '@kit.AbilityKit': {},
  '@kit.AssetStoreKit': { asset },
  '@kit.ArkTS': { util: {
    TextEncoder: class { encodeInto(s) { return new TextEncoder().encode(s); } },
    TextDecoder: { create: () => ({ decodeWithStream: (b) => new TextDecoder('utf-8', { fatal: true }).decode(b) }) }
  } },
  '@kit.RemoteCommunicationKit': { rcp },
  '@kit.BasicServicesKit': {}
};
function load(file) {
  file = file.replaceAll('\\', '/');
  if (file.endsWith('/AccountService.ets')) return { AccountService: { getCurrentUser: () => user } };
  if (cache.has(file)) return cache.get(file).exports;
  const mod = { exports: {} }; cache.set(file, mod);
  let source = fs.readFileSync(file, 'utf8');
  if (file.endsWith('/AiAssistantPage.ets')) {
    // Test the actual page controller methods; omit only the ArkUI render builders/decorators.
    source = source.slice(0, source.indexOf('  @Builder')) + '\n}';
    source = source.replace('@Component', '').replace('export struct', 'export class')
      .replaceAll('@State ', '').replace(/@StorageLink\('[^']+'\) @Watch\('[^']+'\) /g, '');
    source = 'const NavPathStack = class {};\n' + source;
  }
  const js = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText;
  const localRequire = (id) => id in kits ? kits[id] : load(path.resolve(path.dirname(file), id) + '.ets');
  vm.runInThisContext('(function(require,module,exports){' + js + '\n})', { filename: file })(localRequire, mod, mod.exports);
  return mod.exports;
}
const base = path.join(root, 'entry/src/main/ets').replaceAll('\\', '/');
const { AiProtocol, AiProviders } = load(base + '/model/AiConfig.ets');
const { AiProtocolService: protocol } = load(base + '/service/AiProtocolService.ets');
const { AiConfigService: storage } = load(base + '/service/AiConfigService.ets');
const { AiClient } = load(base + '/service/AiClient.ets');
const { AiAssistantPage } = load(base + '/pages/AiAssistantPage.ets');
const { PlatformBridge } = load(base + '/service/PlatformBridge.ets');
const config = (patch = {}) => ({ ...AiProviders.defaults(0), model: 'test-model', apiKey: 'fixture-key-only', ...patch });
function reply(status = 200, raw = '{"choices":[{"message":{"content":"你好"}}]}') {
  behavior = async (session) => {
    const bytes = new TextEncoder().encode(raw);
    // Split inside a UTF-8 character to exercise byte accumulation.
    for (let i = 0; i < bytes.length; i += 2) session.options.requestConfiguration.tracing.httpEventsHandler.onDataReceive(bytes.slice(i, i + 2).buffer);
    if (session.canceled) throw new Error('canceled');
    return { statusCode: status, toString: () => raw };
  };
}
test('all presets validate when account model and URL are supplied', () => {
  for (let i = 0; i < AiProviders.ALL.length; i++) {
    const c = { ...AiProviders.defaults(i), model: 'account-model', apiKey: 'fixture', allowLocalHttp: true };
    if (!c.endpoint) c.endpoint = 'https://example.com/v1/chat/completions';
    assert.equal(protocol.validate(c), '', c.providerId);
  }
});
for (const url of ['ftp://example.com/api', 'https://user:pass@example.com/api', 'https://example.com/api?key=secret',
  'https://example.com/api#fragment', 'https://example.com/%2e%2e/api', 'https://example.com/../api',
  'https://example.com//api', 'https://example.com:0/api', 'https://example.com:65536/api',
  'https://example.com\\@evil.com/api', 'https://example..com/api', 'https://169.254.169.254/api',
  'http://example.com/api', 'http://10.evil.com/api', 'http://2130706433/api', 'http://0177.0.0.1/api',
  'http://0.0.0.0/api', 'http://169.254.1.2/api', 'https://metadata.google.internal/api']) {
  test('reject unsafe endpoint: ' + url, () => assert.notEqual(protocol.validate(config({ endpoint: url, allowLocalHttp: true })), ''));
}
for (const host of ['127.0.0.1', 'localhost', '10.1.2.3', '172.16.0.1', '172.31.255.254', '192.168.1.20']) {
  test('private HTTP needs explicit opt-in: ' + host, () => {
    const c = config({ endpoint: 'http://' + host + ':11434/api/chat' });
    assert.notEqual(protocol.validate(c), ''); c.allowLocalHttp = true; assert.equal(protocol.validate(c), '');
  });
}
for (const key of ['foo\r\nX-Injected: 1', 'foo bar', 'foo\u0000', '密钥', 'x'.repeat(4097)]) {
  test('reject unsafe key format length ' + key.length, () => assert.notEqual(protocol.validate(config({ apiKey: key })), ''));
}
test('model, provider and protocol are validated', () => {
  for (const patch of [{ model: '' }, { model: 'x\nfoo' }, { model: 'x'.repeat(161) }, { providerId: 'missing' }, { protocol: 'bad' }, { apiKey: '' }]) {
    assert.notEqual(protocol.validate(config(patch)), '');
  }
  assert.equal(protocol.validate(config({ providerId: 'custom', apiKey: '' })), '');
});
test('request bodies only include current message and no secrets', () => {
  for (const p of Object.values(AiProtocol)) {
    const body = JSON.parse(protocol.body(config({ protocol: p }), 'only-current'));
    assert.deepEqual(body.messages, [{ role: 'user', content: 'only-current' }]);
    assert.equal(body.stream, false); assert.equal(JSON.stringify(body).includes('fixture-key'), false);
  }
  assert.equal(JSON.parse(protocol.body(config({ providerId: 'openai' }), 'hello')).store, false);
  assert.equal(JSON.parse(protocol.body(config(), 'hello')).store, undefined);
});
test('all three response protocols and Claude non-text blocks', () => {
  assert.equal(protocol.parse(AiProtocol.OPENAI, '{"choices":[{"message":{"content":"ok"}}]}'), 'ok');
  assert.equal(protocol.parse(AiProtocol.OLLAMA, '{"message":{"content":"ok"}}'), 'ok');
  assert.equal(protocol.parse(AiProtocol.CLAUDE, '{"content":[{"type":"thinking","text":"private"},{"type":"text","text":"ok"}]}'), 'ok');
});
for (const raw of ['null', '[]', '{}', 'not json', '{"choices":[null]}', '{"choices":[{"message":{"content":123}}]}', '{"error":{"message":"fixture-key-only"}}', 'x'.repeat(1024 * 1024 + 1)]) {
  test('malformed response is bounded and sanitized: ' + raw.slice(0, 35), () => {
    assert.throws(() => protocol.parse(AiProtocol.OPENAI, raw), (e) => !e.message.includes('fixture-key-only'));
  });
}
test('account-scoped storage, overwrite, deletion and safe failures', async () => {
  user = { id: 'user-a' }; await storage.save(config());
  assert.equal((await storage.load('deepseek')).apiKey, 'fixture-key-only');
  user = { id: 'user-b' }; assert.equal(await storage.load('deepseek'), null);
  await storage.save(config({ apiKey: 'user-b-key' }));
  user = { id: 'user-a' }; assert.equal((await storage.load('deepseek')).apiKey, 'fixture-key-only');
  await storage.save(config({ model: 'new-model' })); assert.equal((await storage.load('deepseek')).model, 'new-model');
  await storage.remove('deepseek'); assert.equal(await storage.load('deepseek'), null);
  user = { id: 'user-b' }; assert.equal((await storage.load('deepseek')).apiKey, 'user-b-key');
  assetFailure = true;
  await assert.rejects(storage.save(config()), /安全存储不可用/);
  await assert.rejects(storage.load('deepseek'), /安全配置读取失败/);
  assetFailure = false; user = null;
  await assert.rejects(storage.save(config()), /请先登录/);
  user = { id: 'user-a' };
});
test('HTTP client headers, byte chunks, bounds, redirect and cancellation', async () => {
  const client = new AiClient(); const c = config(); reply();
  assert.equal(await client.send(c, 'hello', c.endpoint), '你好');
  assert.equal(lastSession.options.requestConfiguration.transfer.autoRedirect, false);
  assert.equal(lastSession.options.requestConfiguration.transfer.timeout.transferMs, 120000);
  assert.equal(lastSession.request.headers.Authorization, 'Bearer fixture-key-only');
  assert.equal(lastSession.closed, true);
  await assert.rejects(client.send(c, 'hello', 'https://changed.example/api'), /目标已变化/);
  await assert.rejects(client.send(c, 'x'.repeat(8001), c.endpoint), /1—8000/);
  for (const code of [301, 302, 307, 308, 401, 403, 404, 429, 500]) {
    reply(code); await assert.rejects(client.send(c, 'hello', c.endpoint), (e) => !e.message.includes('fixture-key-only'));
    assert.equal(lastSession.closed, true);
  }
  reply(200, '{"content":[{"type":"text","text":"ok"}]}');
  const claude = config({ protocol: AiProtocol.CLAUDE });
  assert.equal(await client.send(claude, 'hello', c.endpoint), 'ok');
  assert.equal(lastSession.request.headers['x-api-key'], c.apiKey);
  assert.equal(lastSession.request.headers.Authorization, undefined);
  reply(200, '{"message":{"content":"ok"}}');
  const ollama = config({ providerId: 'ollama', protocol: AiProtocol.OLLAMA, apiKey: '' });
  assert.equal(await client.send(ollama, 'hello', c.endpoint), 'ok');
  assert.equal(lastSession.request.headers.Authorization, undefined);
  behavior = async (s) => {
    s.options.requestConfiguration.tracing.httpEventsHandler.onDataReceive(new ArrayBuffer(1024 * 1024 + 1));
    throw new Error('fixture-key-only');
  };
  await assert.rejects(client.send(c, 'hello', c.endpoint), /1 MiB/); assert.equal(lastSession.canceled, true);
  behavior = () => { throw new Error('fixture-key-only in native failure'); };
  await assert.rejects(client.send(c, 'hello', c.endpoint), (e) => !e.message.includes('fixture-key-only'));
  behavior = () => { throw new Error('服务商 fixture-key-only in native failure'); };
  await assert.rejects(client.send(c, 'hello', c.endpoint), (e) => !e.message.includes('fixture-key-only'));
  behavior = (s) => new Promise((resolve, reject) => { s.reject = reject; });
  const pending = client.send(c, 'hello', c.endpoint);
  await assert.rejects(client.send(c, 'duplicate', c.endpoint), /等待当前请求/);
  client.cancel(); await assert.rejects(pending, /取消/); assert.equal(lastSession.closed, true);
  assert.equal(sessions.every(s => s.closed), true);
});
test('page requires per-request approval and never sends on cancel', async () => {
  user = { id: 'user-a' };
  const page = new AiAssistantPage(); page.owner = 'user-a'; page.model = 'fixture'; page.apiKey = 'fixture'; page.input = 'current-only';
  const before = sessions.length;
  confirmation = async (options) => { assert.ok(options.message.includes(page.endpoint)); return { index: 0 }; };
  await page.send(false); assert.equal(sessions.length, before); assert.equal(page.busy, false);
  confirmation = async () => ({ index: 1 }); reply();
  await page.send(false); assert.equal(sessions.length, before + 1); assert.equal(page.answer, '你好');
  assert.deepEqual(JSON.parse(lastSession.request.content).messages, [{ role: 'user', content: 'current-only' }]);
  assert.equal(page.input, '');
});
test('background during confirmation prevents send and clears sensitive UI fields', async () => {
  const page = new AiAssistantPage(); page.owner = 'user-a'; page.model = 'fixture'; page.apiKey = 'fixture'; page.input = 'private'; page.answer = 'private-answer';
  const before = sessions.length;
  confirmation = async () => { page.onPrivacyChanged(); return { index: 1 }; };
  await page.send(false);
  assert.equal(sessions.length, before); assert.equal(page.apiKey, ''); assert.equal(page.input, ''); assert.equal(page.answer, '');
});
test('late network reply after background never repopulates page', async () => {
  const page = new AiAssistantPage(); page.owner = 'user-a'; page.model = 'fixture'; page.apiKey = 'fixture'; page.input = 'private';
  confirmation = async () => ({ index: 1 });
  let finish;
  behavior = () => new Promise(resolve => { finish = resolve; });
  const pending = page.send(false);
  await new Promise(resolve => setImmediate(resolve));
  page.onPrivacyChanged();
  finish({ statusCode: 200, toString: () => '{"choices":[{"message":{"content":"late-private"}}]}' });
  await pending; assert.equal(page.answer, ''); assert.equal(page.apiKey, ''); assert.equal(page.busy, false);
});
test('account switch before confirmation prevents another account using key', async () => {
  const page = new AiAssistantPage(); page.owner = 'user-a'; page.model = 'fixture'; page.apiKey = 'fixture'; page.input = 'private';
  const before = sessions.length;
  confirmation = async () => { user = { id: 'user-b' }; return { index: 1 }; };
  await page.send(false); assert.equal(sessions.length, before);
  user = { id: 'user-a' };
});

test('model discovery does not require a model ID, send and save still do', async () => {
  const c = config({ model: '' });
  assert.equal(protocol.validate(c, false), '');
  assert.notEqual(protocol.validate(c), '');
  await assert.rejects(storage.save(c), /模型 ID/);
  reply(200, '{"data":[{"id":"model-a"}]}');
  const result = await new AiClient().listModels(c);
  assert.deepEqual(result.ids, ['model-a']);
  assert.equal(lastSession.request.method, 'GET');
  assert.equal(lastSession.request.content, undefined);
  assert.equal(lastSession.request.url, 'https://api.deepseek.com/models');
  assert.equal(lastSession.request.headers.Authorization, 'Bearer fixture-key-only');
});
for (const [p, endpoint, expected] of [
  ['openai', 'https://example.com/gateway/v1/chat/completions', 'https://example.com/gateway/v1/models'],
  ['claude', 'https://example.com/gateway/v1/messages', 'https://example.com/gateway/v1/models'],
  ['ollama', 'http://192.168.1.20:11434/api/chat', 'http://192.168.1.20:11434/api/tags'],
  ['openai', 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions', 'https://generativelanguage.googleapis.com/v1beta/openai/models']
]) {
  test('derive same-origin model endpoint: ' + endpoint, () => {
    assert.equal(protocol.modelsEndpoint(config({ protocol: p, endpoint, allowLocalHttp: true })), expected);
  });
}
test('custom path does not guess alternate hosts or leak keys in URLs', () => {
  assert.throws(() => protocol.modelsEndpoint(config({ endpoint: 'https://example.com/invoke' })), /手动输入/);
  assert.throws(() => protocol.modelsEndpoint(config({ endpoint: 'https://example.com/chat/completions?key=secret' })));
});
test('catalog parsing deduplicates valid IDs and handles Ollama names', () => {
  const raw = JSON.stringify({ data: [{ id: 'a' }, { id: ' a ' }, null, 4, { id: 10 }, { id: '' }, { id: 'bad\nmodel' }, { id: 'x'.repeat(161) }, { id: 'b' }] });
  assert.deepEqual(protocol.parseModels('openai', raw).ids, ['a', 'b']);
  assert.deepEqual(protocol.parseModels('ollama', '{"models":[{"name":"qwen:7b"}]}').ids, ['qwen:7b']);
  assert.deepEqual(protocol.parseModels('openai', '{"data":[]}').ids, []);
});
for (const raw of ['null', '{}', '{"data":null}', 'bad-json', '{"error":{"message":"fixture-key-only"}}', '{"data":[],"has_more":true,"last_id":""}']) {
  test('bad catalog fails safely: ' + raw.slice(0, 45), () => {
    assert.throws(() => protocol.parseModels('claude', raw), e => !e.message.includes('fixture-key-only'));
  });
}
test('Claude pagination uses only encoded cursors on original origin', async () => {
  const urls = [];
  behavior = async (s, r) => {
    urls.push(r.url);
    assert.equal(r.headers['x-api-key'], 'fixture-key-only');
    const data = urls.length === 1 ? { data: [{ id: 'b' }], has_more: true, last_id: 'cursor&next=https://evil.test' } :
      { data: [{ id: 'a' }], has_more: false, next_url: 'https://evil.test' };
    return { statusCode: 200, toString: () => JSON.stringify(data) };
  };
  const result = await new AiClient().listModels(config({ protocol: 'claude', endpoint: 'https://example.com/v1/messages' }));
  assert.deepEqual(result.ids, ['a', 'b']);
  assert.equal(result.truncated, false);
  assert.equal(urls[0], 'https://example.com/v1/models?limit=100');
  assert.equal(urls[1], 'https://example.com/v1/models?limit=100&after_id=cursor%26next%3Dhttps%3A%2F%2Fevil.test');
});
test('catalog is bounded at 500 IDs and repeated pagination stops', async () => {
  reply(200, JSON.stringify({ data: Array.from({ length: 600 }, (_, i) => ({ id: 'model-' + i })) }));
  const result = await new AiClient().listModels(config());
  assert.equal(result.ids.length, 500); assert.equal(result.truncated, true);
  reply(200, '{"data":[{"id":"a"}],"has_more":true,"last_id":"same"}');
  await assert.rejects(new AiClient().listModels(config({ protocol: 'claude', endpoint: 'https://example.com/v1/messages' })), /重复分页/);
});
test('catalog HTTP failure does not return provider secrets or follow redirects', async () => {
  for (const code of [302, 401, 404, 429]) {
    reply(code, '{"error":{"message":"fixture-key-only"}}');
    await assert.rejects(new AiClient().listModels(config()), e => !e.message.includes('fixture-key-only'));
    assert.equal(lastSession.options.requestConfiguration.transfer.autoRedirect, false);
  }
});
test('cancel discovery prevents further pages', async () => {
  const client = new AiClient(); let requests = 0;
  behavior = async () => {
    requests++; client.cancel();
    return { statusCode: 200, toString: () => '{"data":[{"id":"a"}],"has_more":true,"last_id":"next"}' };
  };
  await assert.rejects(client.listModels(config({ protocol: 'claude', endpoint: 'https://example.com/v1/messages' })), /取消/);
  assert.equal(requests, 1);
});
test('page reads catalog without replacing manual ID and filters selection', async () => {
  user = { id: 'user-a' };
  const page = new AiAssistantPage(); page.owner = 'user-a'; page.apiKey = 'fixture'; page.model = 'manual-id';
  reply(200, '{"data":[{"id":"alpha"},{"id":"beta"}]}');
  await page.readModels(true);
  assert.deepEqual(page.modelIds, ['alpha', 'beta']); assert.equal(page.model, 'manual-id');
  page.modelFilter = 'BETA'; assert.deepEqual(page.filteredModelIds(), ['beta']);
  page.invalidateModels(); assert.deepEqual(page.modelIds, []); assert.equal(page.model, 'manual-id');
});
test('page ignores stale model list after background or account change', async () => {
  for (const change of ['background', 'account']) {
    user = { id: 'user-a' };
    const page = new AiAssistantPage(); page.owner = 'user-a'; page.apiKey = 'fixture';
    let finish;
    behavior = () => new Promise(resolve => { finish = resolve; });
    const pending = page.readModels(true);
    await new Promise(resolve => setImmediate(resolve));
    if (change === 'background') page.onPrivacyChanged(); else user = { id: 'user-b' };
    finish({ statusCode: 200, toString: () => '{"data":[{"id":"private-model"}]}' });
    await pending; assert.deepEqual(page.modelIds, []); assert.equal(page.readingModels, false);
  }
  user = { id: 'user-a' };
});
test('oversized catalog object counts and page counts are bounded', async () => {
  const raw = JSON.stringify({ data: Array.from({ length: 2500 }, (_, i) => ({ id: 'id-' + i })) });
  const page = protocol.parseModels('openai', raw);
  assert.equal(page.ids.length, 501); assert.equal(page.truncated, true);
  let requests = 0;
  behavior = async () => {
    requests++;
    return { statusCode: 200, toString: () => JSON.stringify({ data: [{ id: 'id-' + requests }], has_more: true, last_id: 'cursor-' + requests }) };
  };
  const result = await new AiClient().listModels(config({ protocol: 'claude', endpoint: 'https://example.com/v1/messages' }));
  assert.equal(requests, 10); assert.equal(result.truncated, true);
});
test('automatic catalog failure preserves manual ID and does not open a chat approval dialog', async () => {
  const page = new AiAssistantPage(); page.owner = 'user-a'; page.apiKey = 'fixture'; page.model = 'manual';
  confirmation = async () => { throw new Error('catalog must not send prompts'); };
  reply(404, '{}'); await page.readModels(true);
  assert.equal(page.model, 'manual'); assert.equal(page.readingModels, false);
  assert.ok(page.modelStatus.includes('手动输入'));
});

// Exercise the Android branch of the actual shared services. The bridge is a
// native boundary double; these cases do not prove Android Keystore hardware.
test('Android model discovery uses DeepSeek GET endpoint and parses vendor model IDs', async () => {
  const previous = PlatformBridge.bridge;
  PlatformBridge.checked = true;
  const calls = [];
  PlatformBridge.bridge = { async callMethod(method, payload) {
    calls.push([method, JSON.parse(payload)]);
    return JSON.stringify({ ok: true, value: JSON.stringify({ status: 200,
      body: '{"data":[{"id":"deepseek-chat"},{"id":"deepseek-reasoner"}]}' }) });
  } };
  try {
    const result = await new AiClient().listModels(config({ model: '' }));
    assert.deepEqual(result.ids, ['deepseek-chat', 'deepseek-reasoner']);
    assert.equal(calls[0][0], 'request');
    assert.equal(calls[0][1].endpoint, 'https://api.deepseek.com/models');
    assert.equal(calls[0][1].method, 'GET');
    assert.equal(calls[0][1].body, '');
    assert.equal(calls[0][1].headers.Authorization, 'Bearer fixture-key-only');
  } finally { PlatformBridge.bridge = previous; }
});

test('Android config operations preserve account isolation and never fall back after native failure', async () => {
  const previous = PlatformBridge.bridge;
  const saved = new Map();
  let fail = false;
  PlatformBridge.bridge = { async callMethod(method, payload) {
    if (fail) throw new Error('fixture-key-only');
    if (method === 'saveConfig') {
      const record = JSON.parse(payload); saved.set(record.alias, record.value);
      return JSON.stringify({ ok: true, value: '' });
    }
    if (method === 'removeConfig') saved.delete(payload);
    return JSON.stringify({ ok: true, value: method === 'loadConfig' ? (saved.get(payload) || '') : '' });
  } };
  try {
    user = { id: 'user-a' }; await storage.save(config());
    user = { id: 'user-b' }; assert.equal(await storage.load('deepseek'), null);
    user = { id: 'user-a' }; assert.equal((await storage.load('deepseek')).model, 'test-model');
    await storage.remove('deepseek'); assert.equal(await storage.load('deepseek'), null);
    const priorAssetCount = records.size;
    fail = true;
    await assert.rejects(storage.save(config()), e => !e.message.includes('fixture-key-only'));
    assert.equal(records.size, priorAssetCount);
  } finally { PlatformBridge.bridge = previous; user = { id: 'user-a' }; }
});

test('Android native errors, malformed replies and timeouts are bounded and sanitized', async () => {
  const previous = PlatformBridge.bridge;
  try {
    for (const result of ['fixture-key-only', '{"ok":false,"value":"fixture-key-only"}']) {
      PlatformBridge.bridge = { async callMethod() { return result; } };
      await assert.rejects(PlatformBridge.call('loadConfig', 'alias'), e => !e.message.includes('fixture-key-only'));
    }
    PlatformBridge.bridge = { async callMethod() { return new Promise(() => {}); } };
    await assert.rejects(PlatformBridge.call('loadConfig', 'alias', 5), /原生操作未完成/);
  } finally { PlatformBridge.bridge = previous; }
});

test('Android canceled discovery cannot restore a late model list', async () => {
  const previous = PlatformBridge.bridge;
  let finish;
  let requested;
  const started = new Promise(resolve => { requested = resolve; });
  let canceled = false;
  PlatformBridge.bridge = { async callMethod(method) {
    if (method === 'cancelRequest') { canceled = true; return '{"ok":true,"value":""}'; }
    requested();
    return new Promise(resolve => { finish = resolve; });
  } };
  try {
    const client = new AiClient(); const pending = client.listModels(config());
    await started; client.cancel();
    finish(JSON.stringify({ ok: true, value: JSON.stringify({ status: 200, body: '{"data":[{"id":"late"}]}' }) }));
    await assert.rejects(pending, /取消/);
    assert.equal(canceled, true); assert.equal(client.requesting, false);
  } finally { PlatformBridge.bridge = previous; }
});

test('saving while a catalog is running cancels discovery and persists the explicit config', async () => {
  const page = new AiAssistantPage(); page.owner = 'user-a'; page.apiKey = 'fixture'; page.model = 'chosen';
  page.readingModels = true;
  let canceled = false;
  page.client.cancel = () => { canceled = true; };
  await page.save();
  assert.equal(canceled, true); assert.equal(page.readingModels, false);
  assert.equal(page.saved, true); assert.equal(page.loading, false);
  assert.equal((await storage.load('deepseek')).model, 'chosen');
  await storage.remove('deepseek');
});

test('model invalidation during config load must release the form after storage completes', async () => {
  const original = storage.load;
  let finish;
  storage.load = () => new Promise(resolve => { finish = resolve; });
  try {
    const page = new AiAssistantPage(); page.owner = 'user-a';
    const pending = page.loadProvider(0);
    assert.equal(page.loading, true);
    page.invalidateModels();
    finish(null); await pending;
    assert.equal(page.loading, false, 'stale directory revision must not leave config loading locked');
  } finally { storage.load = original; }
});

test('older config reads cannot release the lock held by a newer provider read', async () => {
  const original = storage.load;
  const finishes = [];
  storage.load = () => new Promise(resolve => { finishes.push(resolve); });
  try {
    const page = new AiAssistantPage(); page.owner = 'user-a';
    const first = page.loadProvider(0); const second = page.loadProvider(1);
    finishes[0](null); await first; assert.equal(page.loading, true);
    finishes[1](null); await second; assert.equal(page.loading, false);
  } finally { storage.load = original; }
});

test('config timeout unlocks manual configuration and ignores a late stored reply', async () => {
  const original = storage.load;
  let finish;
  storage.load = () => new Promise(resolve => { finish = resolve; });
  try {
    const page = new AiAssistantPage(); page.owner = 'user-a'; page.configTimeoutMs = 5;
    await page.loadProvider(0);
    assert.equal(page.loading, false); assert.ok(page.status.includes('超时'));
    page.model = 'manual-model'; page.apiKey = 'manual-key';
    finish(config({ model: 'late-model', apiKey: 'late-secret' }));
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(page.model, 'manual-model'); assert.equal(page.apiKey, 'manual-key'); assert.equal(page.saved, false);
  } finally { storage.load = original; }
});

test('config save and removal always unlock after catalog invalidation', async () => {
  for (const name of ['save', 'remove']) {
    const original = storage[name]; let finish;
    storage[name] = () => new Promise(resolve => { finish = resolve; });
    try {
      const page = new AiAssistantPage(); page.owner = 'user-a'; page.apiKey = 'fixture'; page.model = 'model';
      const pending = page[name](); assert.equal(page.loading, true);
      page.invalidateModels(); finish(); await pending;
      assert.equal(page.loading, false, name);
    } finally { storage[name] = original; }
  }
});
