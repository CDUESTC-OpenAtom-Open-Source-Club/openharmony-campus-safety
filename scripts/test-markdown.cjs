// Runs the production ArkTS parser on Node using DevEco's bundled TypeScript compiler.
// Usage: node scripts/test-markdown.cjs
// Optional: TYPESCRIPT_PATH=/path/to/typescript when DevEco is not configured locally.
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const assert = require('node:assert/strict');
const { test } = require('node:test');

const root = path.resolve(__dirname, '..');
const properties = fs.existsSync(path.join(root, 'local.properties')) ?
  fs.readFileSync(path.join(root, 'local.properties'), 'utf8') : '';
const sdk = properties.match(/^hwsdk\.dir=(.+)$/m)?.[1].trim().replace(/\\(.)/g, '$1');
const candidates = [process.env.TYPESCRIPT_PATH, 'typescript'];
if (sdk) {
  candidates.push(path.join(sdk, 'default/openharmony/ets/build-tools/ets-loader/node_modules/typescript'));
}
let ts;
for (const candidate of candidates.filter(Boolean)) {
  try { ts = require(candidate); break; } catch (_) { /* Try the next installed compiler. */ }
}
if (!ts) {
  throw new Error('Set TYPESCRIPT_PATH to an installed TypeScript package, or configure hwsdk.dir in local.properties.');
}
const filename = path.join(root, 'entry/src/main/ets/common/MarkdownParser.ets');
const compiled = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  fileName: 'MarkdownParser.ts',
  compilerOptions: { target: ts.ScriptTarget.ES2019, module: ts.ModuleKind.CommonJS }
});
const loaded = new Module(filename, module);
loaded.filename = filename;
loaded.paths = module.paths;
loaded._compile(compiled.outputText, filename);
const { MarkdownParser } = loaded.exports;
const parse = text => MarkdownParser.parse(text);
const spans = text => parse(text)[0].spans;
const text = tokens => tokens.map(token => token.text).join('');

test('Chinese paragraphs, line breaks and six heading levels', () => {
  const blocks = parse('# 消防安全\r\n\r\n第一步。  \r\n第二步。\n\n###### 注意');
  assert.deepEqual(blocks.map(b => b.kind), ['heading', 'paragraph', 'heading']);
  assert.equal(blocks[0].level, 1);
  assert.equal(text(blocks[1].spans), '第一步。\n第二步。');
  assert.equal(blocks[2].level, 6);
});

test('setext headings and horizontal rules remain distinct', () => {
  const blocks = parse('标题\n===\n\n内容\n\n---\n\n***');
  assert.deepEqual(blocks.map(b => b.kind), ['heading', 'paragraph', 'rule', 'rule']);
  assert.equal(parse('标题\n---')[0].level, 2);
});

test('nested strong, emphasis and strikethrough keep their combined styles', () => {
  const tokens = spans('**加粗与 *斜体***，***全部强调***，~~删除~~，`**原样**`');
  assert.equal(text(tokens), '加粗与 斜体，全部强调，删除，**原样**');
  assert.ok(tokens.find(s => s.text === '斜体' && s.bold && s.italic));
  assert.ok(tokens.find(s => s.text === '全部强调' && s.bold && s.italic));
  assert.ok(tokens.find(s => s.text === '删除' && s.strike));
  assert.ok(tokens.find(s => s.text === '**原样**' && s.code && !s.bold));
});

test('italic around bold, inline code and ordinary heading hashes keep their meaning', () => {
  const tokens = spans('*前缀 **加粗*** 与 *外层 `*` 结尾*');
  assert.equal(text(tokens), '前缀 加粗 与 外层 * 结尾');
  assert.ok(tokens.find(s => s.text === '加粗' && s.bold && s.italic));
  assert.ok(tokens.find(s => s.text === '*' && s.code && s.italic));
  assert.equal(parse('# C#')[0].text, 'C#');
  assert.equal(parse('## 标题 ##')[0].text, '标题');
  assert.deepEqual(parse('---\n---').map(b => b.kind), ['rule', 'rule']);
});

test('backslash escapes, entities and literal HTML do not introduce active markup', () => {
  const tokens = spans('\\*原样\\* &lt;script&gt; &#x1F6E1; &amp; <script>alert(1)</script>');
  assert.equal(text(tokens), '*原样* <script> 🛡 & <script>alert(1)</script>');
  assert.ok(tokens.every(s => !s.bold && !s.italic && s.url === ''));
});

test('code fences preserve tabs, blank lines and Markdown symbols', () => {
  const blocks = parse('```ts\n\tconst a = "**hello**";\n\n[ref]: https://example.com\n```\n\n正文');
  assert.equal(blocks[0].kind, 'code');
  assert.equal(blocks[0].marker, 'ts');
  assert.equal(blocks[0].text, '\tconst a = "**hello**";\n\n[ref]: https://example.com');
  assert.equal(blocks[1].text, '正文');
});

test('long fences, tilde fences and incomplete AI output render safely', () => {
  assert.equal(parse('````md\n```\n````')[0].text, '```');
  assert.equal(parse('~~~js\nlet a = 1;\n~~~')[0].text, 'let a = 1;');
  assert.equal(parse('```json\n{"pending":')[0].text, '{"pending":');
  assert.equal(text(spans('未闭合 **强调与 `代码')), '未闭合 **强调与 `代码');
});

test('inline backticks can contain backticks and do not decode entities', () => {
  assert.equal(text(spans('`` `a` &amp; ``')), '`a` &amp;');
  assert.equal(text(spans('a_b_c snake_case_name')), 'a_b_c snake_case_name');
});

test('nested ordered lists, paragraphs and task lists preserve structure', () => {
  const block = parse('3. 第一步\n   - 子项目\n   - [x] 已完成\n4. 第二步\n\n   补充说明\n\n结束')[0];
  assert.equal(block.kind, 'list');
  assert.deepEqual(block.children.map(b => b.marker), ['3.', '4.']);
  assert.equal(block.children[0].children[1].kind, 'list');
  assert.equal(block.children[0].children[1].children[1].checked, 1);
  assert.equal(block.children[1].children[1].text, '补充说明');
  assert.equal(parse('- [ ] 待办\n- [X] 完成')[0].children[0].checked, 0);
});

test('nested blockquotes contain formatted blocks and lists', () => {
  const block = parse('> **提示**\n>\n> > 深层引用\n>\n> - 不要乘电梯')[0];
  assert.equal(block.kind, 'quote');
  assert.equal(block.children[0].spans[0].bold, true);
  assert.equal(block.children[1].kind, 'quote');
  assert.equal(block.children[2].kind, 'list');
});

test('GFM tables handle alignments, escaped pipes, inline code and ragged rows', () => {
  const block = parse('| 项目 | 状态 | 备注 |\n| :--- | :---: | ---: |\n| **巡检** | `a|b` | a\\|b |\n| 缺少 |\n| 多余 | 2 | 3 | 4 |')[0];
  assert.equal(block.kind, 'table');
  assert.deepEqual(block.alignments, ['left', 'center', 'right']);
  assert.equal(block.rows.length, 4);
  assert.equal(block.rows[1].cells[0][0].bold, true);
  assert.equal(text(block.rows[1].cells[1]), 'a|b');
  assert.equal(text(block.rows[1].cells[2]), 'a|b');
  assert.equal(text(block.rows[2].cells[2]), '');
  assert.equal(block.rows[3].cells.length, 3);
});

test('inline, reference and automatic links preserve labels and balanced URLs', () => {
  const tokens = spans('[**官网**](https://example.com/a_(b) "标题") 与 <https://example.org>');
  assert.ok(tokens.find(s => s.text === '官网' && s.bold && s.url === 'https://example.com/a_(b)'));
  assert.ok(tokens.find(s => s.url === 'https://example.org'));
  const reference = parse('[参考][school]\n\n[school]: https://example.edu "学校"')[0].spans[0];
  assert.equal(reference.url, 'https://example.edu');
  assert.equal(spans('https://example.com/test).')[0].url, 'https://example.com/test');
});

test('unsafe schemes are never actionable, including encoded schemes', () => {
  for (const url of ['javascript:alert(1)', 'data:text/html,hello', 'file:///etc/passwd',
    'intent://open', 'java&#115;cript:alert(1)', 'https://example.com\u0000']) {
    assert.equal(MarkdownParser.safeUrl(url), '');
  }
  assert.equal(spans('[危险](javascript:alert(1))')[0].url, '');
  assert.equal(spans('[危险](java&#115;cript:alert(1))')[0].url, '');
  assert.equal(spans('![危险](data:text/html,hello)')[0].image, false);
  assert.equal(spans('![截图](https://example.com/image.png)')[0].image, true);
});

test('empty, long and deeply nested messages stay bounded', () => {
  assert.deepEqual(parse(' \n\n'), []);
  assert.equal(text(spans('中文'.repeat(10000))).length, 20000);
  assert.ok(parse('> '.repeat(100) + '末尾').length > 0);
  assert.ok(parse('**未闭合 '.repeat(200)).length > 0);
});

test('unsupported footnotes remain visible rather than silently losing their contents', () => {
  const blocks = parse('说明[^1]\n\n[^1]: 补充内容');
  assert.equal(blocks.length, 2);
  assert.equal(text(blocks[1].spans), '[^1]: 补充内容');
});
