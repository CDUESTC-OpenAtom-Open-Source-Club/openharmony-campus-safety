# C 模块 M4 回归验证报告

> 阶段：M4 测试体系 + 稳定性回归（feature/C-testing-stability）
> 报告日期：2026-08-27
> 执行人：Lycorius03
> 依据：TESTING.md 四级验证框架；C 模块整体计划 M4 验收标准 =「测试通过 + 回归验证报告」

---

## 1. 验证目标与范围

M4 验收标准：测试通过 + 回归验证报告。

验证范围覆盖 C 模块整体计划 §5 要求：

- 回归最低范围：首页 → 事件列表 → 事件详情 → 事件确认 → 生成任务 → 任务列表
- 稳定性场景：连续生成事件、快速重复操作、重复确认、重复生成任务、查询不存在数据、空列表、数据量增加、应用重启

## 2. 验证环境

| 项 | 值 |
|---|---|
| 主机 | Windows 11（x64） |
| IDE | DevEco Studio（自带 Node + hvigor + jbr 21.0.8） |
| 构建工具 | 命令行 hvigorw（`DEVECO_SDK_HOME` 指向 DevEco SDK） |
| ArkUI-X 插件 | `@ohos/hvigor-ohos-arkui-x-plugin@4.20.4`（modelVersion 6.0.0） |
| 单测框架 | Hypium / hamock |
| Android 构建 | Gradle 8.4（华为云镜像 wrapper）+ AGP 7.4.1，SDK platform 33 / build-tools 30.0.3（自动补齐） |
| 测试载体 | 命令行单测 + Android 真机 Demo 回归（见 §6） |

## 3. 验证执行过程与结果

### 3.1 第一级：代码检查

- M4 改动范围核对：仅 C 范围文件 + 2 个 A 文件最小改动（① `EventService.ets` 的 `updateTaskStatus` 状态联动，已在 [C跨模块对接.md](C跨模块对接.md) M3 表第 3 条登记授权；② `EventPage.ets` 的 `pageStack` 传递方式闪退修复，M4 表第 4 条登记授权）。其余页面零改动。
- 复用现有模型与服务接口：`EventWorkflowService` 直接复用 `EventSimulator` / `EventRepository` / `EventService`，未复制第二套 Event/Task 模型，符合 C 模块边界。
- ArkTS 类型约束通过编译（CompileArkTS 完成，无 Error，仅 `RdbEventStore.ets` 抛出异常处理提示类 WARN）。

### 3.2 第二级：业务逻辑测试（单测）

命令：`hvigorw :entry:test`（含 5 个测试套件，全部注册于 `List.test.ets`）。

**结果：`Tests run: 61, Failure: 0, Error: 0, Pass: 61`（全部通过）**

| 测试套件 | 覆盖内容 | 用例数 |
|---|---|---|
| localUnitTest | 既有基础用例 | 1 |
| eventSimulatorTest | 事件模拟器：ID 唯一、字段完整、模板覆盖、非法参数兜底 | 10 |
| eventRepositoryTest | Repository 读写 / 更新 / 删除 / 防重复 / 种子幂等 / 写穿落盘 | 21 |
| eventWorkflowTest | 模拟入库 → 确认 → 派单 → 处理 → 完成 全流程状态机 + 隐患上报 `reportHazard` + `buildSummaryTitle` 标题派生/兜底 | 20 |
| stabilityTest | 重启恢复、大批量、重复操作幂等、异常隔离 | 9 |

### 3.3 第三级：应用运行测试（构建验证）

#### 3.3.1 HAP 构建（鸿蒙侧）

`hvigorw assembleHap` 成功：CompileArkTS / PackageHap / SignHap 全部完成。

#### 3.3.2 Android 跨端构建（ArkUI-X，本轮核心实测）

`hvigorw assembleApp` 的 hvigor 阶段全部成功，生成跨平台产物后，插件内部 `gradlew.bat` 调用在命令行环境触发 `shell:true` 失败（EXIT_CODE=127）。**绕过插件，在 `.arkui-x/android/` 手动执行 `gradlew.bat :app:assembleDebug --no-daemon`**：

- 自动补齐 SDK 组件：Build-Tools 30.0.3、Platform 33
- `BUILD SUCCESSFUL in 46s`，31 个任务执行
- 产物：`.arkui-x/android/app/build/outputs/apk/debug/app-debug.apk`（88.4 MB）

APK 内容核验（unzip / aapt）：

| 检查项 | 结果 |
|---|---|
| package / version | `com.example.hongmengzhian`，versionName 1.0，targetSdk 33，minSdk 26 |
| 原生库 arm64-v8a | `libarkui_android.so` / `libdata_relationalstore.so` / `libhilog.so` ✓ |
| 原生库 armeabi-v7a | 同上三库 ✓ |
| ArkTS 编译产物 | `assets/arkui-x/entry/ets/modules.abc` ✓ |
| 资源索引 | `assets/arkui-x/entry/resources.index` ✓ |

**关键结论：`libdata_relationalstore.so` 成功打进 APK，说明 `@kit.ArkData`（relationalStore）的 JNI 实现已编译进安卓包，RDB 端侧持久化在安卓端可正常工作。**

### 3.4 稳定性场景覆盖（单测断言）

| 场景 | 覆盖用例 |
|---|---|
| 连续生成事件 | `stability_large_batch_50_events_no_duplicate_ids` / `stability_large_batch_all_pending` |
| 数据量增加后的筛选 | `stability_mixed_states_filter_after_confirms` |
| 重复确认 / 重复派单 | `stability_repeated_confirm_dispatch_ten_times_keeps_one_task`、`workflow_duplicate_confirm_and_dispatch_protected` |
| 重复完成 / 状态防回退 | `stability_repeated_complete_keeps_state_stable`、`workflow_completed_event_no_downgrade_on_task_rollback` |
| 应用重启恢复 | `stability_restart_reload_restores_events_and_tasks`、`stability_restart_reload_preserves_event_task_link` |
| 查询不存在 / 空列表 / 非法参数 | `workflow_simulate_and_enqueue_batch_invalid_count_noop`、`stability_invalid_template_does_not_block_followups` |
| 大批量后业务流程仍正常 | `stability_large_batch_then_workflow_still_runs` |

### 3.5 隐患上报标题修复验证（2026-08-27，鸿蒙模拟器）

用户报告"安全事件列表中事件标题显示为占位词'隐患上报'而非真实标题"。根因：`ReportPage.ets` 提交时硬编码 `title: '隐患上报'`，且 C 数据层 `reportHazard` 未对占位标题兜底。

修复（登记 [C跨模块对接.md](C跨模块对接.md) M4 表第 6 条）：

- `EventWorkflowService.buildSummaryTitle(description)`：描述摘要（前 15 字 + 省略号，折叠换行、按 Unicode 码点截取）；
- `ReportPage.ets` 提交时用 `buildSummaryTitle(description)` 派生 title；
- `reportHazard` 兜底：调用方仍传占位标题时自动用描述摘要替换。

端侧实锤验证（模拟器手动提交隐患 → hilog 落库日志）：

```text
EventWorkflow reportHazard saved: id=EVT1787847210594001 title=操场西侧路灯灯罩脱落电线裸露下… location=操场西侧 status=待确认
```

落库 `title` 为描述摘要（非"隐患上报"），问题 1 已解决。新增 10 条单测（`reportHazard` 4 条 + `buildSummaryTitle` 5 条 + 占位标题兜底 1 条）随 M4 一并通过。

## 4. 验证结论

- 单测：61/61 全部通过，流程状态机、隐患上报与稳定性场景全覆盖。
- 隐患上报标题修复：模拟器 hilog 实锤落库 title=描述摘要（非占位词），问题 1 已解决。
- 鸿蒙侧 HAP 构建成功；Android 跨端 APK 构建成功且产物核验完整。
- ArkData（relationalStore）跨端可用性得到构建级验证（.so 已入包）。
- 未发现 A/B 文件被越界修改。

## 5. 构建产物说明（不入库）

以下为 ArkUI-X 跨端构建产物，已在 `.gitignore` 中排除，不入库：

- `/.arkui-x/android/app/libs/`（jar + .so）
- `/.arkui-x/android/app/src/main/assets/`（abc / resources.index）
- `/.arkui-x/android/.gradle/`、`/local.properties`（原已排除）

## 6. Android 真机验证补充（2026-08-27，OPPO A56 5G）

真机执行了 C 数据层验证（与 UI 渲染无关的部分），结果如下：

| 验证项 | 方式 | 结果 |
|---|---|---|
| RDB 建表 | `run-as` 拉取 `files/database/rdb/campus_safety.db` 核对 | ✅ `security_event` / `task` 表结构正确，枚举以中文落库（待确认/已确认/处理中/已完成） |
| 种子数据落盘 | 同上 | ✅ EVT001（教学楼走廊漏水/待确认/高）、EVT002（已确认/紧急）、EVT003（处理中/中）全部入库 |
| 重启持久化 | force-stop → am start 重启后重新拉库 | ✅ 种子数据完整保留，`ensureSeeded` 幂等，未重复播种 |
| 状态流转链路 | 命令行单测 | ✅ 61/61（确认→派单→处理→完成 全流程状态机 + 隐患上报 + 稳定性） |

**闪退定位与修复（2026-08-27）：**
- 现象：22:40 进程 `com.example.hongmengzhian`（pid 13037）`Fatal signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x40`，null pointer dereference，backtrace 固定为 `libarkui_android.so (OHOS::Ace::Framework::JSNavPathStack::OnStateChanged()+0)` ← `JsiClass<JSNavPathStack>::MethodCallback` ← `[anon:ArkTS Code]`。
- 根因（分步复现锁定）：一级 push（进事件列表）正常；二级 push（进详情页）必崩；对照实验 push 无 `pageStack` 传参的 TaskPage（纯二级页面）不崩 → 崩溃与 `EventPage` 的 `@Prop pageStack: NavPathStack` 强相关。`@Prop` 对对象做**深拷贝 + 单向同步**，拷贝副本的 JS 导航栈与 ArkUI-X 原生导航栈状态不一致，副本上 `pushPath` 触发原生空指针。
- 修复：`EventPage.ets` 的 `@Prop pageStack: NavPathStack` 改为普通成员变量 `pageStack: NavPathStack = new NavPathStack()`，由 Index 构造参数 `EventPage({ pageStack: this.pageStack })` 覆盖默认值，与 Index 保持同一实例（改动已登记 [C跨模块对接.md](C跨模块对接.md) M4 表第 4 条）。
- 验证：重新构建 HAP + 手动 gradle 打包 APK → 真机覆盖安装 → 首页→列表→详情（二级 push）→确认事件→生成任务→任务列表 全链路进程存活，无崩溃。**闪退已解决。**

## 7. 遗留事项

| 事项 | 说明 | 责任人 | 状态 |
|---|---|---|---|
| Android 真机 Demo 回归（UI 链路） | 首页 → 事件列表 → 事件详情 → 确认 → 生成任务 → 任务列表 的界面操作回归 | Lycorius03 | ✅ 已通过（2026-08-27，修复 §6 闪退后真机全链路回归，进程存活） |
| C 数据层真机验证 | 建表 / 种子落盘 / 重启持久化 | Lycorius03 | ✅ 已在本轮完成（§6） |
| iOS 跨端构建 | ArkUI-X 同样支持 iOS，本轮未验证 | Lycorius03 | 待执行 |

## 8. 声明

本报告所有条目均为实际执行并验证的结果：单测输出 `Tests run: 61, Failure: 0, Error: 0, Pass: 61`；gradle 输出 `BUILD SUCCESSFUL in 46s`；APK 由 aapt/unzip 实际核验；Android 真机 Demo 回归（UI 链路）与 C 数据层持久化验证均已在 OPPO A56 5G 真机上实际执行通过；隐患上报标题修复经鸿蒙模拟器 hilog 实锤（§3.5）。
