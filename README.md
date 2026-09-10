# 鸿蒙智安 - 校园安全协同应用

![HarmonyOS](https://img.shields.io/badge/HarmonyOS-6.0-blue?style=flat-square&logo=huawei)
![ArkTS](https://img.shields.io/badge/Language-ArkTS-3178c6?style=flat-square)
![ArkUI](https://img.shields.io/badge/UI-ArkUI-0A59F7?style=flat-square)
![Stage](https://img.shields.io/badge/Model-Stage-success?style=flat-square)
![ArkUI-X](https://img.shields.io/badge/Cross--Platform-ArkUI--X-orange?style=flat-square)
![Status](https://img.shields.io/badge/Status-Beta-yellow?style=flat-square)
![Version](https://img.shields.io/badge/Version-v0.1.0--beta.4-blue?style=flat-square)
![License](https://img.shields.io/badge/License-Apache%202.0-lightgrey?style=flat-square)

基于 OpenHarmony / HarmonyOS 原生 ArkUI 与 ArkTS 开发的校园安全协同应用，覆盖「发现 - 确认 - 派单 - 处理 - 反馈 - 完成」的完整安全事件闭环，并通过 ArkUI-X 支持 Android 跨平台运行。

---

## 项目介绍

校园安全涉及消防、用电、设施、环境等多个领域。传统管理方式中，隐患从发现到处理完成的信息往往依赖人工传递，容易出现记录不完整、责任不明确、状态更新不及时、跨角色协同效率低等问题。

本项目以「安全事件」为核心数据对象，将发现、确认、派单、处理、反馈、归档纳入统一流程，为管理人员、巡检人员和普通师生提供清晰、可追踪的协同工具。

> 项目保持原生鸿蒙属性，核心功能未使用 WebView 或第三方 UI 框架替代 ArkUI。

---

## 核心特性

| 特性 | 说明 |
| :--- | :--- |
| 原生鸿蒙实现 | ArkTS + ArkUI，Stage 模型，Navigation 导航 |
| 完整业务闭环 | 事件从产生到归档全程可追踪 |
| 数据本地持久化 | ArkData relationalStore + Preferences，重启不丢失 |
| 实时数据统计 | 事件、任务、首次响应、处置时长与按期完成率均根据真实本地数据计算；空数据明确标识 |
| 鸿蒙服务卡片 | 基于 Form Kit，按当前角色展示本地上报、任务或待审核数据，并在业务状态变化后刷新 |
| 应急求助能力 | 配置紧急联系电话后，可一键打开短信与拨号界面 |
| 纯净上架状态 | 不预置演示数据，首次启动即为空状态 |
| 跨平台支持 | 通过 ArkUI-X 打包为 Android APK |

---

## 功能模块

| 模块 | 说明 |
| :--- | :--- |
| 安全事件管理 | 事件列表、详情、搜索、优先级与状态筛选、确认事件、生成任务 |
| 处置任务 | 任务列表、状态筛选、接单处理、结果填写、完成提交 |
| 隐患上报 | 多类型隐患、地点与描述、优先级选择、一键提交进入事件流 |
| 数据统计 | 实时健康度、事件与任务指标、领域达标率、近 7 日趋势 |
| 应急联系方式 | 独立配置页，保存紧急联系电话 |
| 一键求助 | 分别打开系统短信编辑或拨号界面，均由用户确认后执行 |
| 应用体验 | 开屏动画、页面切换动效、统一品牌视觉 |

---

## 当前进度

`v0.1.0-beta.2` Demo 已开发完成。项目自 2026-09-08 起进入正式测试版开发，原 A/B/C 固定模块边界不再生效，后续工作按功能、里程碑、代码评审和测试责任协同推进。完整安排见 [正式测试版专业化迭代计划](docs/正式测试版专业化迭代计划.md)。

正式测试版已实现本地多角色账号、业务权限、真实任务指派、审核返工、图片证据与服务卡片。人工回归步骤与账号安全边界见 [正式测试版手动测试清单](docs/正式测试版手动测试清单.md) 和 [身份治理加固方案](docs/security-hardening/identity-governance/hardening.md)。

M7 业务深化已完成四个阶段：上报页接入系统图片选择与应用私有目录保存，事件详情可查看现场证据和操作历史；普通用户可在“我的上报”中跟踪进度与最终反馈；巡检人员可提交处置前后图片；管理员可按本地安保账号真实派单并查看未分配、超时和待审核任务，任务责任时间随业务状态持久化。

M8 已完成 HarmonyOS 原生校园安全服务卡片；M9 已完成真实统计口径与产品可信文案清理。M10 正在进行构建、测试与云手机集成验收，未验证能力不会作为已发布能力声明。

| 阶段 | 模块 | 状态 | 说明 |
| :---: | :--- | :---: | :--- |
| 1 | 项目基础工程 | 完成 | Stage 模型、ArkUI 页面结构、数据模型 |
| 2 | 事件模拟与数据层 | 完成 | EventSimulator、Repository、relationalStore 持久化 |
| 3 | 业务闭环 | 完成 | 确认事件、生成任务、处理完成、状态联动 |
| 4 | 原生 UI 重做 | 完成 | 首页、事件、任务、上报、统计页面统一视觉 |
| 5 | 实时统计 | 完成 | 健康度、达标率、趋势图实时计算 |
| 6 | 应急联系方式与一键求助 | 完成 | 配置页、短信预填、拨号调用 |
| 7 | 开屏与切换动效 | 完成 | 开屏动画、页面淡入动效 |
| 8 | Android 跨平台 | 完成 | ArkUI-X 打包与真机安装验证 |
| 9 | 签名与发布 | 历史 Demo | 旧 Beta Release 仅作历史记录，当前正式测试版需重新完成签名与云手机验收 |
| 10 | 学生课表 | 完成 | 校内课程表网格、课次切换与本地偏好存储 |

---

## 技术栈

| 技术项 | 说明 |
| :--- | :--- |
| 开发语言 | ArkTS |
| UI 框架 | ArkUI（声明式 UI） |
| 应用模型 | Stage Model |
| 页面导航 | Navigation + NavPathStack |
| 本地数据 | ArkData relationalStore |
| 轻量存储 | Preferences |
| 业务服务 | EventService / EventWorkflowService / EmergencyContactService |
| 构建工具 | hvigor / DevEco Studio |
| 跨平台 | ArkUI-X（Android） |
| 测试框架 | Hypium + hamock |
| 版本管理 | Git + GitHub |

---

## 项目结构

```text
openharmony-campus-safety
├── AppScope                     # 应用级配置与资源
├── entry
│   └── src
│       └── main
│           └── ets
│               ├── pages        # 页面
│               ├── model        # 数据模型
│               ├── service      # 业务服务
│               ├── repository   # 数据访问与存储
│               └── simulator    # 事件模拟器
├── docs                         # 项目文档
└── .arkui-x                     # ArkUI-X 跨平台工程
```

---

## 环境要求

| 环境 | 说明 |
| :--- | :--- |
| DevEco Studio | HarmonyOS 开发环境 |
| OpenHarmony SDK | 项目构建所需 SDK |
| Node.js | hvigor 构建所需 |
| Android SDK | 打包 Android 版本时需要 |
| JDK | Android Gradle 构建所需 |

---

## 构建与运行

### HarmonyOS / OpenHarmony

使用 DevEco Studio 打开项目根目录，完成同步后选择 `entry` 模块运行。

```bash
hvigorw assembleHap --mode module -p product=default -p buildMode=debug
```

Release 构建：

```bash
hvigorw assembleHap --mode module -p product=default -p buildMode=release
```

### Android（ArkUI-X 跨平台）

```bash
hvigorw assembleApp --mode project -p product=default -p buildMode=debug
```

Release 构建：

```bash
hvigorw assembleApp --mode project -p product=default -p buildMode=release
```

Debug APK 输出位置：

```text
.arkui-x/android/app/build/outputs/apk/debug/app-debug.apk
```

Release APK 输出位置：

```text
.arkui-x/android/app/build/outputs/apk/release/app-release.apk
```

---

## 发布签名

签名材料、口令与 Android keystore 均保存在本地 `signing/` 目录，**不进入版本库**（见 `.gitignore`）。仓库中的构建配置不包含任何密钥或口令，因此克隆后可以直接构建未签名产物。

Release 产物签名步骤：

1. **HarmonyOS HAP**：先构建未签名 HAP，再用 SDK 的 `hap-sign-tool` 签名。

   ```bash
   hvigorw assembleHap --mode module -p product=default -p buildMode=release
   ```

   签名输入：`signing/OpenHarmony.p12`、`signing/OriginalAppReleaseChain.pem`、`signing/OpenHarmonyProfileRelease.p7b`（`bundle-name` 为 `com.example.hongmengzhian`）。签名命令使用 `hap-sign-tool.jar sign-app -mode localSign`，证书链必须为 3 级（叶子证书 + Application CA + Root CA）。

2. **Android APK**：`.arkui-x/android/keystore.properties`（本地生成，已忽略）提供 `storeFile` / `storePassword` / `keyAlias` / `keyPassword`，`app/build.gradle` 读取后用于 release 签名；缺少该文件时回退为 debug 签名。

3. **签名校验**：

   ```bash
   # HarmonyOS
   java -jar <sdk>/toolchains/lib/hap-sign-tool.jar verify-app -inFile <hap> -outCertChain chain.cer -outProfile profile.p7b

   # Android
   apksigner verify --print-certs -v <apk>
   ```

> 发布包必须使用 release 证书签名，不得使用 debug 签名或 Android Debug 证书。

---

## 发布包

| 平台 | 安装包 | 签名状态 | 说明 |
| :--- | :--- | :--- | :--- |
| HarmonyOS | HongMengZhiAn-v0.1.0-beta.4-HarmonyOS-signed.hap | 已签名 Release HAP | Beta 测试包 |
| Android | HongMengZhiAn-v0.1.0-beta.4-Android.apk | 已签名 Release APK | ArkUI-X 跨平台包 |

发布地址：

```text
https://github.com/CDUESTC-OpenAtom-Open-Source-Club/openharmony-campus-safety/releases/tag/v0.1.0-beta.4
```

---

## 测试

| 范围 | 说明 |
| :--- | :--- |
| 事件模拟器 | 生成与唯一 ID |
| 数据仓储 | 读写、更新、删除 |
| 业务闭环 | 确认、任务生成、防重复、状态联动 |
| 稳定性 | 空数据处理、连续操作、批量生成 |

使用 Hypium 与 hamock，测试代码位于 `entry/src/test/`。

---

## 已知限制与后续计划

- 接入校园真实保卫处值班号码配置
- 增加事件图片上传与现场证据留存
- 完善权限申请与合规说明
- 完成正式签名、HarmonyOS 云手机全量回归后发布稳定版
- 云端协同、校园统一身份认证、分布式软总线与物联网接入不属于当前已实现能力

---

## 致谢与说明

- 项目基于 OpenHarmony / HarmonyOS 官方原生能力开发
- Android 跨平台能力由 ArkUI-X 提供
- 发布材料与签名材料未存入仓库，避免密钥泄露
- 项目遵循 Apache License 2.0
