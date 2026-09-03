# 鸿蒙智安 - 校园安全协同应用

基于 OpenHarmony / HarmonyOS 原生 ArkUI 与 ArkTS 的校园安全协同应用，面向校园安全事件与隐患管理，构建「发现 - 确认 - 派单 - 处理 - 反馈 - 完成」的端侧安全闭环，并支持 ArkUI-X 安卓跨平台打包。

## 项目简介

校园安全涉及消防、设施、设备、环境等多个方面。传统校园安全管理过程中，安全隐患的发现、上报、处理和反馈容易出现信息传递不及时、责任不明确、处理过程难追踪等问题。

本项目以「安全事件」为核心，将校园安全问题从发现到最终处理完成进行统一管理，形成完整的业务闭环，帮助管理人员、巡检人员和普通师生高效协同。

## 主要功能

- 安全事件管理
  - 校园安全事件列表、详情查看
  - 事件确认与处置任务生成
  - 事件状态流转跟踪
- 处置任务
  - 巡检人员接单、开始处理
  - 填写处置结果并提交完成
  - 任务与事件状态联动
- 隐患上报
  - 隐患类型选择、地点与描述填写
  - 优先级选择与快捷地点
  - 一键提交进入安全事件管理流程
- 数据统计
  - 实时健康度与安全等级
  - 安全事件、待办任务、已办结实时统计
  - 各重点安防领域达标率
  - 近 7 日事件趋势
- 一键求助
  - 独立应急联系方式配置页
  - 自动打开短信界面并预填号码与求助内容
  - 自动打开拨号界面并预填号码
- 应用体验
  - 启动开屏动画
  - 页面切换淡入动效
  - 纯净初始状态，无预置演示数据

## 核心技术栈

| 技术项 | 说明 |
|---|---|
| 开发语言 | ArkTS |
| UI 框架 | ArkUI（声明式 UI） |
| 应用模型 | Stage Model |
| 页面导航 | Navigation + NavPathStack |
| 端侧数据 | ArkData relationalStore + Preferences |
| 构建工具 | hvigor / DevEco Studio |
| 跨平台 | ArkUI-X（Android） |
| 测试 | Hypium + hamock |
| 版本管理 | Git + GitHub |

## 核心业务流程

```text
发现 / 模拟 / 上报
        ↓
安全事件产生（待确认）
        ↓
管理人员确认事件
        ↓
生成处置任务
        ↓
巡检人员接单处理
        ↓
填写处理结果
        ↓
提交完成
        ↓
事件闭环归档
```

## 项目结构

```text
openharmony-campus-safety
├── AppScope                    # 应用级配置与资源
├── entry
│   └── src
│       └── main
│           └── ets
│               ├── pages       # 页面（首页、事件、任务、上报、统计、应急联系方式）
│               ├── model       # SecurityEvent / Task / User
│               ├── service     # EventService / EventWorkflowService / EmergencyContactService
│               ├── repository  # EventRepository 与存储实现
│               └── simulator   # EventSimulator
├── docs                        # 项目文档
└── .arkui-x                    # ArkUI-X 跨平台安卓工程
```

## 构建与运行

### HarmonyOS / OpenHarmony

1. 使用 DevEco Studio 打开项目根目录
2. 同步工程并安装依赖
3. 选择 `entry` 模块运行到模拟器或真机

命令行构建：

```bash
hvigorw assembleHap --mode module -p product=default -p buildMode=debug
```

### Android（ArkUI-X 跨平台）

```bash
hvigorw assembleApp --mode project -p product=default -p buildMode=debug
```

生成的 APK 位于：

```text
.arkui-x/android/app/build/outputs/apk/debug/app-debug.apk
```

## 测试

测试框架使用 Hypium 与 hamock，覆盖：

- 事件模拟器生成与唯一 ID
- 事件仓储读写、更新、删除
- 事件确认、任务生成与防重复
- 完整业务流程状态联动
- 稳定性与空数据处理

## 说明

项目当前保持纯净初始状态，不内置演示案例数据，适合应用商店上架前验收。应用图标、名称与跨平台安卓图标均已统一为「鸿蒙智安」盾牌设计。

