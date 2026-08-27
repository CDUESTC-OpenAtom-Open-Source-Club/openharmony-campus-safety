# C 模块跨 A/B 改动对接记录

> 用途：记录 C 在开发过程中**涉及修改 A/B 内容**的所有改动，保证与 A/B 成员随时对齐。
> 原则：C 不改 A/B；以下条目均为 Lycorius03 明确授权的最小必要改动。
> 任何未在本表登记的 A/B 文件改动视为越界，不得提交。

## 当前分支：feature/C-repository（M2 已实现，云手机重启恢复验证待 Lycorius03 执行）

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

## 待对齐事项

- （暂无）

---

## 已归档条目

- M1（feature/C-event-simulator）：无 A/B 文件改动（仅 C 范围：simulator + test）。2026-08-26 已快进合入 main（2074da1），11 条单测通过。
