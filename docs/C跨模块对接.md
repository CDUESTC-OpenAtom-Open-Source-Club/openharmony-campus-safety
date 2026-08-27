# C 模块跨 A/B 改动对接记录

> 用途：记录 C 在开发过程中**涉及修改 A/B 内容**的所有改动，保证与 A/B 成员随时对齐。
> 原则：C 不改 A/B；以下条目均为 Lycorius03 明确授权的最小必要改动。
> 任何未在本表登记的 A/B 文件改动视为越界，不得提交。

## 当前分支：feature/C-event-workflow（M3 业务闭环）

---

## 记录格式

| 阶段 | A/B 文件 | 改动内容 | 原因 | 授权/对齐状态 |
|---|---|---|---|---|
| M2 | `entry/src/main/ets/service/EventService.ets` | ... | ... | 已授权（Lycorius03, 2026-08-26） |

---

## M2：Repository + ArkData 持久化

| # | A/B 文件 | 改动内容 | 原因 | 授权/对齐状态 |
|---|---|---|---|---|
| 1 | `entry/src/main/ets/service/EventService.ets` | 数据源从 `private static events[]` 内存数组改为经 C 的 `EventRepository` 读写：`getAllEvents/getPendingEvents/getEventById/getAllTasks` 改读 Repository；`confirmEvent` 更新后 `updateEvent` 落盘；`createTaskFromEvent` 防重复查 Repository 的 Task 并 `saveTask` 落盘；种子数据保留在 EventService 作"空库播种"来源 | 让现有数据流接入持久化，页面零改动，符合 Page→EventService→Repository→ArkData | 已授权 + 已实现（本任务，数据源切换完成，本地单测通过） |
| 2 | `entry/src/main/ets/entryability/EntryAbility.ets` | `onWindowStageCreate` 中在 `loadContent` 前 `await RepositoryManager.init(context)`，保证页面出现前 RDB 数据已载入缓存 | 应用启动需打开 RDB 并灌入缓存，避免页面读空数据的竞态 | 已授权 + 已实现（本任务，初始化接入完成，编译通过，真机验证待回填） |

> 对齐提示（给 A/B）：M2 只改以上 2 个 A 文件，页面文件一个不动。EventService 对外方法签名不变，页面调用无需任何改动。

---

## M3：业务闭环（feature/C-event-workflow）

| # | A/B 文件 | 改动内容 | 原因 | 授权/对齐状态 |
|---|---|---|---|---|
| 3 | `entry/src/main/ets/service/EventService.ets` | `updateTaskStatus(taskId, status, result?)` 在保存任务状态后增加**事件状态联动**：任务置 PROCESSING 且事件为 PENDING/CONFIRMED 时，事件同步置 PROCESSING；任务置 COMPLETED 时事件直接置 COMPLETED。另增加防回退守卫：已完成任务不允许回退到其他状态，事件"已完成"不因任务回退而降级 | 补齐"处理 → 完成"环节的状态一致性，让任务推进能带动事件状态走完整闭环（确认 → 处理中 → 已完成）；`result` 参数因 Task 模型暂无结果字段，维持现状不落库 | 已授权（Lycorius03, 2026-08-27，M3 决策确认"任务完成时事件直接置 COMPLETED"）+ 已实现 |

> 对齐提示（给 A/B）：M3 只改以上 1 个 A 文件，页面文件一个不动。EventService 对外方法签名不变，页面调用无需任何改动；`updateTaskStatus` 联动后，B 端巡检处理任务时事件状态会自动同步，无需额外处理。

---

## 待对齐事项

- （暂无）

---

## 已归档条目

- M1（feature/C-event-simulator）：无 A/B 文件改动（仅 C 范围：simulator + test）。2026-08-26 已快进合入 main（2074da1），11 条单测通过。
- M2（feature/C-repository）：上述 M2 表 2 项已实现并合入 main（fe84bdb，2026-08-27），云手机重启恢复验证待 Lycorius03 执行。
