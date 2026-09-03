# 鸿蒙智安 - 校园安全协同应用

基于 OpenHarmony / HarmonyOS 原生 ArkUI 与 ArkTS 开发的校园安全协同应用。应用面向校园安全事件与隐患管理，覆盖「发现 - 确认 - 派单 - 处理 - 反馈 - 完成」的完整闭环，并通过 ArkUI-X 支持 Android 跨平台运行。

---

## 1. 项目背景

校园安全涉及消防、用电、设施、环境等多个领域。传统管理方式中，隐患从发现到处理完成的信息往往依赖人工传递，容易出现以下问题：

- 事件信息记录不完整，后续难以追溯
- 责任人员不明确，处置过程不可见
- 状态更新不及时，管理人员无法掌握全局
- 各环节缺少统一的数据入口，协同效率低

本项目以「安全事件」为核心数据对象，将发现、确认、派单、处理、反馈、归档纳入统一流程，为管理人员、巡检人员和普通师生提供清晰、可追踪的协同工具。

---

## 2. 核心特点

- 原生鸿蒙实现：使用 ArkTS 与 ArkUI，保持 OpenHarmony 原生属性
- 完整业务闭环：事件从产生到归档全程可追踪
- 数据本地持久化：使用 ArkData relationalStore 与 Preferences，重启不丢失
- 实时数据统计：健康度、达标率、趋势图均根据真实业务数据计算
- 应急求助能力：配置紧急联系电话后，可一键打开短信与拨号界面
- 纯净上架状态：不预置演示数据，首次启动即为空状态
- 跨平台支持：通过 ArkUI-X 可打包为 Android APK

---

## 3. 主要功能

### 3.1 安全事件管理

- 安全事件列表与详情查看
- 事件优先级、状态、地点、上报人等信息展示
- 支持搜索与优先级、状态筛选
- 管理人员可确认事件并生成处置任务

### 3.2 处置任务

- 巡检人员查看任务列表
- 支持按全部 / 待处理 / 处理中 / 已完成筛选
- 接单开始处置，填写处理结果
- 任务完成后自动联动事件状态

### 3.3 隐患上报

- 支持消防、用电、设施、校园秩序等多类隐患
- 可填写发生地点、详细描述、上报人
- 支持选择隐患优先级
- 提交后自动进入安全事件管理流程

### 3.4 数据统计

- 实时健康度与安全等级
- 安全事件、待办任务、已办结数量统计
- 各重点安防领域达标率
- 近 7 日事件趋势图
- 支持手动刷新，数据始终反映最新状态

### 3.5 应急联系方式与一键求助

- 独立配置页面保存紧急联系电话
- 未配置时点击求助会提示并引导前往配置
- 配置后点击「一键求助」：
  1. 打开短信界面并预填号码与求助内容
  2. 打开拨号界面并预填号码

### 3.6 应用体验

- 启动开屏动画
- 页面切换淡入动效
- 首页实时总览卡片
- 统一品牌视觉与盾牌图标

---

## 4. 业务流程

```text
发现 / 上报 / 模拟
        ↓
安全事件产生（待确认）
        ↓
管理人员确认
        ↓
生成处置任务
        ↓
巡检人员接单
        ↓
现场处理并填写结果
        ↓
提交完成
        ↓
事件归档闭环
```

---

## 5. 技术栈

| 技术项 | 说明 |
|---|---|
| 开发语言 | ArkTS |
| UI 框架 | ArkUI（声明式 UI） |
| 应用模型 | Stage Model |
| 页面导航 | Navigation + NavPathStack |
| 本地数据 | ArkData relationalStore |
| 轻量存储 | Preferences |
| 业务服务 | EventService / EventWorkflowService |
| 构建工具 | hvigor / DevEco Studio |
| 跨平台 | ArkUI-X（Android） |
| 测试框架 | Hypium + hamock |
| 版本管理 | Git + GitHub |

---

## 6. 项目结构

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

## 7. 环境要求

- DevEco Studio（HarmonyOS 开发环境）
- OpenHarmony SDK
- Node.js（hvigor 构建所需）
- Android SDK（打包 Android 版本时需要）
- JDK（Android Gradle 构建所需）

---

## 8. 构建与运行

### 8.1 HarmonyOS / OpenHarmony

使用 DevEco Studio 打开项目根目录，完成同步后选择 `entry` 模块运行。

命令行构建：

```bash
hvigorw assembleHap --mode module -p product=default -p buildMode=debug
```

### 8.2 Android（ArkUI-X 跨平台）

```bash
hvigorw assembleApp --mode project -p product=default -p buildMode=debug
```

Android Debug APK 输出位置：

```text
.arkui-x/android/app/build/outputs/apk/debug/app-debug.apk
```

### 8.3 Release 构建

```bash
# HarmonyOS Release HAP
hvigorw assembleHap --mode module -p product=default -p buildMode=release

# Android Release APK
hvigorw assembleApp --mode project -p product=default -p buildMode=release
```

---

## 9. 测试

项目使用 Hypium 与 hamock 进行单元测试与稳定性测试，覆盖：

- 事件模拟器生成与唯一 ID
- 数据仓储读写、更新、删除
- 事件确认与任务生成
- 重复任务保护
- 完整业务流程状态联动
- 空数据处理与稳定性场景

---

## 10. 发布说明

- 当前版本不预置演示数据，首次启动为空状态
- HarmonyOS 安装包为 HAP，Android 安装包为 APK，两个平台需要分别打包
- 正式上架前需要配置对应平台的正式签名
- 应用名称统一为「鸿蒙智安」，图标为盾牌主题设计

---

## 11. 许可

项目遵循仓库内 LICENSE 文件的相关条款。
