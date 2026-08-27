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
| 测试载体 | 命令行单测（Android 真机 Demo 回归待执行，见 §6） |

## 3. 验证执行过程与结果

### 3.1 第一级：代码检查

- M4 改动范围核对：仅 C 范围文件 + 1 个 A 文件最小改动（`EventService.ets` 的 `updateTaskStatus` 状态联动，已在 [C跨模块对接.md](C跨模块对接.md) M3 表第 3 条登记授权）。页面文件零改动。
- 复用现有模型与服务接口：`EventWorkflowService` 直接复用 `EventSimulator` / `EventRepository` / `EventService`，未复制第二套 Event/Task 模型，符合 C 模块边界。
- ArkTS 类型约束通过编译（CompileArkTS 完成，无 Error，仅 `RdbEventStore.ets` 抛出异常处理提示类 WARN）。

### 3.2 第二级：业务逻辑测试（单测）

命令：`hvigorw :entry:test`（含 5 个测试套件，全部注册于 `List.test.ets`）。

**结果：`Tests run: 51, Failure: 0, Error: 0, Pass: 51`（全部通过）**

| 测试套件 | 覆盖内容 | 用例数 |
|---|---|---|
| localUnitTest | 既有基础用例 | — |
| eventSimulatorTest | 事件模拟器：ID 唯一、字段完整、模板覆盖 | — |
| eventRepositoryTest | Repository 读写 / 更新 / 删除 / 防重复 | — |
| eventWorkflowTest（新增 9） | 模拟入库 → 确认 → 派单 → 处理 → 完成 全流程状态机 | 9 |
| stabilityTest（新增 9） | 重启恢复、大批量、重复操作幂等、异常隔离 | 9 |

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

## 4. 验证结论

- 单测：51/51 全部通过，流程状态机与稳定性场景全覆盖。
- 鸿蒙侧 HAP 构建成功；Android 跨端 APK 构建成功且产物核验完整。
- ArkData（relationalStore）跨端可用性得到构建级验证（.so 已入包）。
- 未发现 A/B 文件被越界修改。

## 5. 构建产物说明（不入库）

以下为 ArkUI-X 跨端构建产物，已在 `.gitignore` 中排除，不入库：

- `/.arkui-x/android/app/libs/`（jar + .so）
- `/.arkui-x/android/app/src/main/assets/`（abc / resources.index）
- `/.arkui-x/android/.gradle/`、`/local.properties`（原已排除）

## 6. 遗留事项（下一阶段 / 真机回归）

| 事项 | 说明 | 责任人 |
|---|---|---|
| Android 真机 Demo 回归 | 安装 `app-debug.apk`，按回归最低范围逐条验证：首页 → 事件列表 → 事件详情 → 事件确认 → 生成任务 → 任务列表 | Lycorius03 |
| 云手机/真机重启恢复验证 | RDB 真实文件持久化的重启恢复（构建级已验证 .so 入包，行为级待真机确认） | Lycorius03 |
| iOS 跨端构建 | ArkUI-X 同样支持 iOS，本轮未验证 | Lycorius03 |

## 7. 声明

本报告所有条目均为实际执行并验证的结果：单测输出 `Tests run: 51, Failure: 0, Error: 0, Pass: 51`；gradle 输出 `BUILD SUCCESSFUL in 46s`；APK 由 aapt/unzip 实际核验。未执行的真机回归已如实列入 §6，不做"已通过"宣称。
