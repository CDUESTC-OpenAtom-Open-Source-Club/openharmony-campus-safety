# AI API 接入

入口：登录后打开首页的 AI 助手，或「我 → AI 助手与 API 配置」。本功能为可选的文字咨询，不参与事件审批、派单、账号管理或应急自动决策。

## 技术方案与支持范围

沿用现有 ArkTS、ArkUI、Navigation 和 HarmonyOS API 20。HarmonyOS 网络使用 Remote Communication Kit（RCP），配置与密钥使用 Asset Store Kit。Android 通过 ArkUI-X 原生桥接调用 HttpURLConnection，以及 Android Keystore 的 AES-256-GCM 密钥；Preferences 仅存放经认证加密的密文。两端均关闭自动重定向并保留系统默认 TLS 校验。Android 宿主沿用 ArkUI-X 运行库，并引入官方宿主所需的 AndroidX Window 依赖。

支持三种 HTTP JSON 文字协议：OpenAI Chat Completions 兼容、Anthropic Messages、Ollama `/api/chat`。Gemini 使用其官方 OpenAI 兼容接口。当前是单条消息、非流式响应；支持测试连接、取消、超时、错误提示和清除内容。

厂商选项包括 DeepSeek、阿里云百炼/千问、火山方舟/豆包、智谱 GLM、Kimi、百度千帆、腾讯混元、硅基流动、MiniMax、讯飞星火、华为云 ModelArts MaaS、OpenAI、Claude、Gemini、Mistral、xAI、Groq，以及 Ollama、自定义 API。

所有地址可编辑；模型 ID 由用户依据账号权限填写。百炼、华为云地址需从控制台复制工作空间和区域对应的完整请求 URL。预设只是协议配置便利项，未持有各厂商账号，不能视为全部厂商已联调认证。厂商专用签名、OAuth、任意请求模板、自定义认证头、图片/语音/工具调用与 Responses-only 模型不在本版范围；自定义入口要求兼容以上三种协议之一。

编译目标为项目现有 **HarmonyOS API 20**；Android 已增加原生网络、安全配置及隐私窗口适配。平台专用模块延迟加载，避免在应用启动时加载另一平台不提供的 Kit。Android 必须重新编译原生宿主，仅替换旧 APK 资源无法接入这些能力。设备验收仍未完成，不能将编译通过视为真机可用证明；纯 OpenHarmony 发行版仍需单独验收。

## 配置与使用

1. 选择厂商及协议，填写**完整接口地址**（含 `/chat/completions`、`/messages` 或 `/api/chat` 路径），不是仅填写 Base URL。
2. 填写密钥后点击「读取可用模型 / 重新读取模型」。支持搜索、下拉选择，同时始终保留手动输入。方舟等使用专用接入点或未提供模型目录的服务可直接填写实际接入点 ID；Ollama 目录读取的是本机已安装模型。
3. 在密码输入框粘贴该服务的密钥。Ollama 或无需认证的自定义服务可留空。更改地址或协议会清空待保存密钥，须重新填写。
4. 可保存、读取或删除当前账号该厂商的配置。每个账号每个厂商保存一份，自定义入口保存一份自定义配置。未保存的有效配置也可临时调用。
5. 切换「问答」，发送前确认目标、模型及发送范围。测试连接也会发送固定文字、可能计费，需要确认。取消不保证服务端停止生成或免计费。

每次只发送当前文本，不发送历史回复。上限：输入 8000 个 UTF-16 代码单元（界面按字符计数）、响应 1 MiB、连接 15 秒、总传输 120 秒；Claude、兼容接口和 Ollama 请求设置 2048 输出 token 限额，实际支持及推理 token 计数取决于模型。OpenAI 设置 `store:false`，这不等于供应商零留存。

## Ollama 与其他本地服务

手机上的 `127.0.0.1` 指手机，不能用它访问电脑。电脑部署 Ollama 时，填写同一可信局域网中电脑的 IPv4，例如：

```text
http://192.168.1.20:11434/api/chat
```

需要使用 HTTP 时开启「允许私网 / 本机明文 HTTP」。只允许 localhost、127/8、10/8、172.16/12、192.168/16；不接受公网 HTTP、IPv6 或私网域名 HTTP。HTTPS 可使用用户指定的合法主机名和私网 IP。服务端需监听手机可达的地址，防火墙仅放行可信设备；不要将无认证的 Ollama 暴露到公网。推荐使用带认证的 HTTPS 反向代理。模型或代理仍可能调用云端，填写局域网地址本身不证明模型全离线。

## 安全与隐私行为

- HarmonyOS 完整配置（含地址和密钥）保存在系统 Asset SECRET，按当前本地用户 ID 与厂商 ID 分别命名；要求设备解锁才能访问，设置 `SYNC_TYPE.NEVER`，不创建卸载后仍保留的资产。安全存储失败时明确失败，不使用 Preferences/文件明文回退。
- Android 使用不可导出的 Android Keystore AES 密钥和每条记录独立随机 GCM IV，账号与厂商别名作为附加认证数据；存取前检查设备解锁，禁止 Android 应用备份。安全存储失败不回退明文。进入 AI 页面时在主线程开启 FLAG_SECURE，离开页面后保持该窗口保护，与鸿蒙端生命周期保持一致。硬件保护级别、锁屏和截图行为仍待真机验证。
- 账号隔离为应用层控制，依赖现有 AccountService；不能防御 root、代码注入或被控制的系统。未设置锁屏口令时，系统 DEVICE_UNLOCKED 保护可能弱化，应在设备上设置锁屏密码。
- 密钥禁用输入框复制、自动填充和明文显示按钮。AI 页面尝试开启系统窗口隐私模式；若失败显示提示。为避免页面切换/任务快照竞态，开启后保持到应用窗口销毁；因此同一窗口内其他页面的截图也可能受限。
- 返回或进入后台会清空页面中的密钥输入、当前文本和回复，并取消请求；异步结果用版本和账号检查防止回填。托管语言内存不承诺物理清零；已存入 Asset 的配置保留到用户删除或卸载。
- 不调用校园事件、联系人、附件或统计服务；没有 AI 对话文件、分析遥测或载荷日志。请求仅含模型参数、当前用户文本和该目标的认证信息。系统 DNS、网络栈及用户配置的代理仍可能观察连接元数据。
- 不自动重试、跟随重定向、跨厂商回退或在打开页面时测试联网。错误正文和原生异常不直接展示。模型回复以 ArkUI Text 展示，不能执行 HTML、脚本、工具或业务动作。
- 自定义目标由用户自行信任；App 没有远程可触发的请求代理。不将私网地址校验描述为完整 SSRF 防御，不承诺阻止 HTTPS 域名解析到内部地址。
- 每次发送需确认。发送给境外服务可能涉及境外处理，接收方留存、训练政策与实际处理区域必须由用户另行确认。应用不能撤销已经送达第三方的数据，也不自动识别/脱敏用户主动输入的个人信息。

## 官方协议依据

文档核对日期：2026-10-25；服务商会变更模型、权限、域名及地区。真实调用可用性以用户账户及联调结果为准。

- [OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)
- [Gemini OpenAI compatibility](https://ai.google.dev/gemini-api/docs/openai)
- [Claude Messages](https://platform.claude.com/docs/en/api/messages/create)
- [Ollama Chat](https://docs.ollama.com/api/chat)
- [DeepSeek 首次调用](https://api-docs.deepseek.com/)
- [百炼 OpenAI 兼容](https://help.aliyun.com/zh/model-studio/compatibility-of-openai-with-dashscope)
- [智谱对话补全](https://docs.bigmodel.cn/api-reference/模型-api/对话补全)
- [Kimi Chat Completions](https://platform.kimi.com/docs/api/chat)
- [火山方舟 Chat API](https://docs.volcengine.com/docs/ark/chat-api)（该页面依赖 JavaScript，文本抓取不完整；接口路径由官方 API Explorer 交叉核对）
- [腾讯混元兼容接口](https://cloud.tencent.com/document/product/1729/111007)（官方提示新模型服务逐步迁移 TokenHub，可填写其控制台实际地址）
- [硅基流动对话接口](https://docs.siliconflow.cn/docs/api/chat-completions-post)
- [MiniMax Anthropic 兼容](https://platform.minimax.cn/docs/api-reference/text-anthropic-api)
- [讯飞 Spark-X2.5](https://www.xfyun.cn/doc/spark/Spark-X2.5.html)
- [华为云 MaaS V2](https://support.huaweicloud.com/intl/zh-cn/model-call-maas/model-call-019.html)
- [Mistral Chat](https://docs.mistral.ai/api)、[xAI Chat](https://docs.x.ai/developers/rest-api-reference/inference/chat-completions)、[Groq compatibility](https://console.groq.com/docs/openai)
- [Asset Store 官方接口](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-asset-store-kit/js-apis-asset.md)；具体类型与 API 版本同时由本机 API20 SDK 及真实构建核对。

测试结果与未验收范围见 [AI_VALIDATION.md](AI_VALIDATION.md)。

## 模型目录读取（2026-10-25 增补）

用户填写地址与密钥后，点击「读取可用模型」发出目录 GET 请求。结束输入不再自动发请求，避免点击保存时触发目录读取并使保存按钮失效；打开页面或读取已保存配置不自动联网。密钥/地址/厂商/协议变更会清空旧目录并取消原读取。目录仅在页面内存中存在，进入后台或离开页面时清除。

按完整推理接口的同源路径推导目录：OpenAI/Gemini 兼容 `/chat/completions → /models`，Anthropic `/messages → /models`，Ollama `/api/chat → /api/tags`。保留网关路径前缀；不尝试其他厂商或域名，不跟随响应中的跳转/next_url。认证方式与推理接口相同；请求不含问答内容。HTTP 仍须先显式允许私网 HTTP。

目录读取无需预先填写模型 ID，保存配置和发送问答仍要求有效 ID。读取结果不覆盖已有手动 ID，也不自动选定第一个模型。返回空目录、401/403/404、协议不兼容等均保留手动输入路径；模型目录可能包含不支持 Chat 的模型或需要另开权限的模型，目录出现不等于真实调用验证通过。

每页响应限制 1 MiB、传输 30 秒；Claude 分页最多 10 页，游标编码后只请求同源目录，重复游标停止。列表最多保留 500 个 ID；页面下拉最多显示当前搜索的前 100 项，提供截断提示。可随时取消读取或修改配置。其他厂商的非标准分页和专用模型管理 API 通过手动 ID 兜底，不宣称已完整支持。

协议依据：[OpenAI Models](https://developers.openai.com/api/reference/resources/models/methods/list)、[Claude Models](https://platform.claude.com/docs/en/api/models/list)、[Ollama Tags](https://docs.ollama.com/api/tags)、[Gemini 模型目录](https://ai.google.dev/gemini-api/docs/openai#list-models)。
