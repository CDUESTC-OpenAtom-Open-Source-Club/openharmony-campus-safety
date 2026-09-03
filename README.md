# 鸿蒙智安 - 校园安全协同应用

![HarmonyOS](https://img.shields.io/badge/HarmonyOS-6.0-blue?style=flat-square&logo=huawei)
![ArkTS](https://img.shields.io/badge/Language-ArkTS-3178c6?style=flat-square)
![ArkUI](https://img.shields.io/badge/UI-ArkUI-0A59F7?style=flat-square)
![Stage](https://img.shields.io/badge/Model-Stage-success?style=flat-square)
![ArkUI-X](https://img.shields.io/badge/Cross--Platform-ArkUI--X-orange?style=flat-square)
![Status](https://img.shields.io/badge/Status-Beta-yellow?style=flat-square)
![Version](https://img.shields.io/badge/Version-v0.1.0--beta.1-blue?style=flat-square)
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
| 实时数据统计 | 健康度、达标率、趋势图均根据真实业务数据计算 |
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
| 一键求助 | 打开短信界面预填号码与内容，并打开拨号界面 |
| 应用体验 | 开屏动画、页面切换动效、统一品牌视觉 |

---

## 当前进度

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
| 9 | 签名与发布 | 完成 | HAP 与 APK 签名，Beta Release 已发布 |

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

---

## 发布包

| 平台 | 安装包 | 签名状态 | 说明 |
| :--- | :--- | :--- | :--- |
| HarmonyOS | `HongMengZhiAn-v0.1.0-beta.1-HarmonyOS-signed.hap` | 已签名 | Beta 测试版 |
| Android | `HongMengZhiAn-v0.1.0-beta.1-Android.apk` | 已签名 | Beta 测试版 |

发布地址：

```text
https://github.com/CDUESTC-OpenAtom-Open-Source-Club/openharmony-campus-safety/releases/tag/v0.1.0-beta.1
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

## 后续计划

- 接入校园真实保卫处值班号码配置
- 增加事件图片上传与现场证据留存
- 完善权限申请与合规说明
- 正式签名发布 `v1.0.0` 稳定版

---

## 致谢与说明

- 项目基于 OpenHarmony / HarmonyOS 官方原生能力开发
- Android 跨平台能力由 ArkUI-X 提供
- 发布材料与签名材料未存入仓库，避免密钥泄露
- 项目遵循 Apache License 2.0
