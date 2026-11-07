// Rebuild the store artwork from actual Release screenshots; no old bitmap is edited.
// Usage: node scripts/generate-store-screenshots.cjs
// CHROME_PATH may point to Chrome/Edge when it is installed elsewhere.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const { pathToFileURL } = require('node:url');

const root = path.resolve(__dirname, '..');
const output = path.join(root, 'dist/store-screenshots');
const work = path.join(root, '.regression/store-previews');
fs.mkdirSync(work, { recursive: true });
const browser = [process.env.CHROME_PATH,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'
].find(candidate => candidate && fs.existsSync(candidate));
if (!browser) throw new Error('Set CHROME_PATH to an installed Chrome or Edge executable.');

const pages = [
  ['01-home.jpeg', '01-校园安全_一屏掌握.png', '校园安全，一屏掌握', '安全指数 · 实时动态 · 快捷上报'],
  ['02-report.jpeg', '02-隐患上报_分级流转.png', '隐患上报，分级流转', '多类型隐患 · 优先级设置 · 现场描述'],
  ['03-records.jpeg', '03-处置流程_全程留痕.png', '事件记录，全程跟踪', '上报记录 · 状态筛选 · 进度查询'],
  ['04-profile.jpeg', '04-统一身份_分级授权.png', '统一身份，分级授权', '学生 / 教工 / 安保 分角色管理'],
  ['05-account.jpeg', '05-凭证安全_加盐保护.png', '账号安全，便捷管理', '密码修改 · 账号状态 · 身份权限']
];
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'store-artwork-'));
for (const [index, [source, filename, title, subtitle]] of pages.entries()) {
  const image = fs.readFileSync(path.join(output, 'source', source)).toString('base64');
  const html = `<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<title>校安通 - ${title}</title><style>
* { box-sizing: border-box; }
html, body { margin: 0; width: 1080px; height: 1920px; overflow: hidden; }
body { position: relative; font-family: "Microsoft YaHei", sans-serif;
  color: #172033; background: linear-gradient(#ffffff, #e5eeff); }
.brand { position: absolute; left: 72px; top: 96px; width: 208px; height: 58px;
  border-radius: 32px; background: #2f6bff; color: white;
  text-align: center; font-size: 30px; font-weight: 700; line-height: 58px; }
h1 { position: absolute; left: 72px; top: 188px; margin: 0; font-size: 64px;
  line-height: 1.4; letter-spacing: -2px; }
.subtitle { position: absolute; left: 72px; top: 282px; margin: 0;
  color: #657999; font-size: 34px; line-height: 1.5; }
.number { position: absolute; right: 82px; top: 202px; color: #adc1e7;
  font-size: 32px; font-weight: 700; }
.screen { position: absolute; left: 225px; top: 398px; width: 630px; height: 1356px;
  overflow: hidden; border: 1px solid #b9cdef; border-radius: 44px;
  box-shadow: 0 18px 36px #203b6629; background: white; }
.screen img { display: block; width: 100%; height: 100%; object-fit: contain; }
footer { position: absolute; left: 72px; bottom: 25px; color: #91a6c5; font-size: 34px; }
</style><body><div class="brand">校安通</div><h1>${title}</h1>
<p class="subtitle">${subtitle}</p><div class="number">${String(index + 1).padStart(2, '0')}</div>
<div class="screen"><img src="data:image/jpeg;base64,${image}" alt="校安通实际运行界面"></div>
<footer>HarmonyOS 原生应用 · 校安通</footer></body></html>`;
  const htmlPath = path.join(work, `${index + 1}.html`);
  const target = path.join(output, filename);
  fs.writeFileSync(htmlPath, html);
  const result = spawnSync(browser, ['--headless=new', '--disable-gpu', '--hide-scrollbars',
    '--no-first-run', '--no-default-browser-check', '--force-device-scale-factor=1',
    '--window-size=1080,1920', '--virtual-time-budget=1000', `--user-data-dir=${profile}`,
    `--screenshot=${target}`, pathToFileURL(htmlPath).href],
  { windowsHide: true, encoding: 'utf8', timeout: 30000 });
  if (result.error || result.status !== 0 || !fs.existsSync(target)) {
    throw new Error(`Could not render ${filename}: ${result.error || result.stderr}`);
  }
  console.log(`${filename}: ${fs.statSync(target).size} bytes`);
}
