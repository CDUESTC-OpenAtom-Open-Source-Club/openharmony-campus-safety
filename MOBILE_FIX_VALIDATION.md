# 0.2.1 双端故障修复与验收记录

日期：2026-10-25。最新状态：**已完成鸿蒙模拟器上的 AI 配置页专项验证，实体设备与完整业务验收仍待完成**。现场确认并修复了配置操作与模型目录共用版本号导致的永久 loading；实际模型目录、配置保存与读回通过。详细记录见 [LIVE_AI_FREEZE_DIAGNOSIS.md](LIVE_AI_FREEZE_DIAGNOSIS.md)。没有发送问答内容，没有提交、推送或发布远程 Release。以下表格保留早先修复的阶段证据；设备与测试现状以本段及现场记录为准。

## 问题、依据与处理

| 用户反馈 | 本轮检查与修改 | 证据边界 |
| --- | --- | --- |
| 鸿蒙端一直加载，不知道在加载什么 | 原先 EntryAbility 等账号和数据库初始化完成后才加载页面，Index 又展示固定 2.35 秒的模拟进度。现在先加载独立 Startup 页，展示真实初始化阶段；12 秒仍未完成则停止转圈、提示阶段并提供重试；成功后替换为首页。移除模拟联网文案和启动动画；初始化失败不再进入可能使用空内存缓存的业务页。AI 的平台专用模块改为延迟加载。 | 尚未取得用户鸿蒙设备的日志，不能确认原设备的具体阻塞点，也不能声称已在该设备复现和消除问题。 |
| Android 读不到 DeepSeek 模型 | 旧宿主缺少新增 AI 功能依赖的 RCP/Asset 原生库，单纯替换 HAP 资源不会补齐能力。新增 ArkUI-X 原生桥接，Android 使用 HttpURLConnection；共享协议层继续推导同源 `/models`，保留认证、解析与错误提示。HarmonyOS 继续使用 RCP。 | ETS 的 Android 分支替身测试和生产 Java 网络类的本机回环服务测试通过；真实 DeepSeek 账号联调待验收。 |
| Android 保存安全配置无效 | Android 接入 Keystore AES-256-GCM，Preferences 只保存密文，账号和厂商别名作为 AAD，读写前检查解锁；失败不回退明文。HarmonyOS 保留 Asset。移除输入框失焦自动读目录，保存可以取消正在进行的目录读取，避免首次点击保存被目录读取状态阻断。 | 原生 Java 编译和共享逻辑测试通过；Android Keystore 实际落盘、锁屏和重启读取待设备验收。 |
| Android 键盘上方导航遮挡 | 键盘显示时隐藏底部导航。使用窗口键盘事件，并为较旧 ArkUI-X 宿主增加根布局缩小的检测；保持 adjustResize，让表单继续使用可见区域滚动。 | 编译通过；输入法、旋转、多窗口和手势导航的视觉验收待设备执行。 |
| 两端卡顿 | PBKDF2 由同步 generateSecretSync 改为异步 generateSecret，保留 SHA-256、120000 轮、独立盐和旧密码摘要格式。事件与任务列表改为 List + LazyForEach，仅构造可见项及少量缓存项；移除强制启动动画。Android 网络/Keystore 使用后台桥接队列。 | 账号测试验证异步让出事件循环及摘要兼容；未测量设备帧率、启动耗时或提升百分比，不能宣称所有卡顿已消失。 |

原生桥接接口依据：[ArkUI-X Bridge](https://github.com/arkui-x/docs/blob/master/zh-cn/application-dev/reference/apis/js-apis-bridge.md)、[Android BridgePlugin](https://github.com/arkui-x/docs/blob/master/zh-cn/application-dev/reference/arkui-for-android/BridgePlugin.md)。本机 SDK 的 BridgePlugin/TaskOption 签名也已通过 javap 核对。HarmonyOS 构建使用延迟原生 OHM URL 加载桥接，Android-only 模块不存在时不会成为启动依赖；这一加载路径仍需设备验证。

## 已执行的验证

- HarmonyOS API20 Debug HAP、最终 Release HAP：实际构建成功，Release 为未签名产物。
- Android：实际重新编译 Java、DEX、资源和原生宿主，Release APK 构建成功，正式证书签名通过 apksigner 验证。
- AI 套件：74 项通过。新增 Android 目录请求、账号隔离、原生错误脱敏、超时、取消、读取期间保存测试。系统 Kit/桥接使用替身，未证明设备行为。
- 启动与账号套件：5 项通过。覆盖单次初始化、失败重试、真实阶段、异步注册、密码摘要兼容、登录、改密与一次性邀请码。
- 生产 Android Java 网络类：9 项本机回环 HTTP 测试通过，覆盖 GET 认证、中文 POST/响应、重定向不二跳、错误正文丢弃、Content-Length 和分块响应上限、读超时、派发前取消和接收数据期间取消。
- APK/HAP 的全部应用资源逐项一致，modules.abc 的 SHA-256 一致；APK 包含新桥接类和网络类，entryTest 资源已移除，Android 备份已关闭。
- Impeccable 源代码检测输出为空数组；这不是 ArkUI 截图或可视质量验收。
- git diff --check：本轮修改没有空白错误；既有 oh-package-lock.json5 修改的两处行尾空白保留原状。

命令（TypeScript 参数使用本机 SDK 路径，也可替换为已安装的 TypeScript）：

```powershell
node scripts/test-ai.cjs 'F:/OpenHarmony/IDE/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript'
node scripts/test-mobile.cjs 'F:/OpenHarmony/IDE/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript'
```

Java 本机传输测试：编译 `.arkui-x/android/app/src/main/java/com/example/hongmengzhian/AiHttpTransport.java` 和 `scripts/java/NativeHttpTest.java`，加入 `jdk.httpserver` 模块，运行 `NativeHttpTest`。

HarmonyOS 构建完成后执行 `python scripts/sync-android-assets.py`，再运行 Android Gradle。同步脚本只清理已校验路径下的应用生成资源，保留 systemres；不能用旧的资源重打包流程替代原生宿主构建。

## 安装包与签名

产物目录：`release/v0.2.1/`；逐文件 SHA-256、签名指纹与校验结果见该目录的 `build-verification.json`。

| 文件 | 用途 |
| --- | --- |
| HongMengZhiAn-v0.2.1-Android-test-update.apk | **本轮优先测试这个包**。与之前 20261025-models 测试 APK 使用同一 Android Debug 证书，已核对指纹并验证签名，可用于同证书覆盖安装。它是调试证书签名的测试包，不能作为正式发布包。 |
| HongMengZhiAn-v0.2.1-Android-release.apk | 本机正式 Android 证书签名的候选包；其证书与之前 Debug 测试包不同，不能直接覆盖该测试包。两份 APK 的 DEX、原生库与应用资源一致。 |
| HongMengZhiAn-v0.2.1-HarmonyOS-unsigned.hap | 编译完成，**未签名，不能直接当作真机覆盖安装包**。现有工程 signingConfigs 为空，本轮没有可用的鸿蒙签名口令配置。需通过原有鸿蒙签名身份完成签名，不应为覆盖安装另建身份。 |

Android 版本号为 0.2.1 / versionCode 6；HarmonyOS 为 0.2.1 / versionCode 1000005。没有清除设备或应用数据。旧包是否确为用户当前安装版本，仍需安装时由系统验证。

## 未完成的验收

1. hdc、adb 都没有连接设备，也没有配置可用的 Android AVD。未执行任何真机安装、截图、键盘或业务流程验收。
2. 鸿蒙启动阻塞的设备根因、最终 HAP 签名和安装，仍待完成。
3. 真实 DeepSeek 密钥请求、模型权限、保存后重启读取、账号切换、锁屏、后台取消与截图保护，仍待验证。
4. Android lint 的首次依赖下载未完成；最终打包命令排除了 lintVitalAnalyzeRelease / lintVitalReportRelease / lintVitalRelease。Java/DEX 编译通过不等于 lint 通过。
5. 完整 Hypium、事件到任务的设备业务回归以及性能采样尚未执行。

建议设备验收顺序：覆盖安装测试更新 APK → 注册/登录时弹出与收起键盘 → DeepSeek 填密钥并点读取模型 → 选择模型后保存 → 重启读取 → 测试连接（用户确认后才发送）→ 检查事件/任务列表。鸿蒙端签名安装后首先检查 Startup 提示的具体阶段与是否进入首页。
