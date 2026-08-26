# M2 数据层设计：Repository + ArkData 端侧持久化

> 日期：2026-08-26
> 分支：feature/C-event-simulator（M1 已收官）→ M2 应开 `feature/C-repository`
> 适用：C_MODULE_SPEC.md / MODULE_BOUNDARIES.md / TESTING.md

## 1. 背景与目标

当前数据全在 A 的 `EventService` 内存数组里（3 条种子 EVT001-003），无任何持久化，**应用重启数据即丢**。

M2 目标（对齐 [C模块整体计划](docs/C模块整体计划.md) 的 M2）：

- 新增 C 侧 `EventRepository`，提供 `getEvents / getEventById / saveEvent / updateEvent / deleteEvent`（+ Task 方法）
- 用 ArkData **RDB（relationalStore）** 实现端侧持久化
- 授权最小改动 A 的 `EventService` / `EntryAbility`，让现有数据流接入持久化
- 验收：读写/更新/删除/重启恢复全部通过；本地单测通过

## 2. 决策记录（已与 Lycorius03 确认）

| 决策点 | 结论 | 确认时间 |
|---|---|---|
| 数据源衔接 | 授权 C 在 A 的 `EventService` 内做最小数据源切换（页面零改动） | 2026-08-26 |
| 持久化选型 | ArkData RDB（relationalStore），库名 `campus_safety.db` | 2026-08-26 |
| A/B 改动留档 | 涉及 A/B 的改动全部登记到 `docs/C跨模块对接.md` | 2026-08-26 |
| EntryAbility 初始化 | 同意在 `onWindowStageCreate` 中 `loadContent` 前 await 初始化 | 2026-08-26 |
| 播种策略 | 种子数据保留在 EventService，空库时播种，不清库不重复播 | 2026-08-26 |
| Task 方法 | Repository 一并提供 `saveTask / getTaskByEventId / getAllTasks`，为 M3 铺路 | 2026-08-26 |

## 3. 总体架构

```
页面 (B, 不改)
  ↓ 调用不变（同步）
EventService (A, 最小改动)
  ↓ 改调
EventRepository (C 新增, 同步缓存)
  ├─ events: SecurityEvent[]   （内存缓存 = 读源头）
  ├─ tasks: Task[]
  └─ store: EventStore         （持久化后端，异步写穿）
       ├─ MemoryEventStore     （本地单测注入）
       └─ RdbEventStore        （relationalStore，真机/云手机）
```

**为什么是"同步缓存 + 异步写穿"：**

- 页面用同步方式读数据（`@State events = EventService.getAllEvents()`），且页面不能改 → 读取必须同步返回。
- relationalStore 是异步 API → 只能把"写"做成写穿（同步更新缓存 + 异步落盘），"读"走缓存。
- 启动时 `RepositoryManager.init(context)` 异步把 RDB 全量灌入缓存，页面出现前完成（await 后再 loadContent），消除竞态。

## 4. 文件结构

### C 范围新增（`entry/src/main/ets/repository/`）

| 文件 | 职责 |
|---|---|
| `EventRepository.ets` | 数据访问层（单例）。同步 API：`getEvents / getEventById / saveEvent / updateEvent / deleteEvent / saveEvents`；任务：`getAllTasks / getTaskByEventId / saveTask`。内部维护内存缓存 + 持有一个 `EventStore`。 |
| `store/EventStore.ets` | 存储抽象接口（异步）：`loadEvents(): Promise<SecurityEvent[]>`、`loadTasks(): Promise<Task[]>`、`saveEvent(e): Promise<void>`、`updateEvent(e): Promise<void>`、`deleteEvent(id): Promise<void>`、`saveTask(t): Promise<void>` |
| `store/MemoryEventStore.ets` | 内存实现，供本地单测（无系统 API，Node 可跑） |
| `store/RdbEventStore.ets` | relationalStore 实现。建表、插入、更新、删除、全量查询 |
| `RepositoryManager.ets` | 初始化入口。`init(context): Promise<void>`（开库→建表→灌缓存→播种）；`initForTest(store)`（测试注入） |

### A 授权改动（登记于 `docs/C跨模块对接.md`）

| 文件 | 改动 |
|---|---|
| `entry/src/main/ets/service/EventService.ets` | 数据源改为经 `EventRepository` 读写（见 §6） |
| `entry/src/main/ets/entryability/EntryAbility.ets` | `onWindowStageCreate` 中 await `RepositoryManager.init(context)` 后再 `loadContent` |

### C 测试新增（`entry/src/test/`）

- `EventRepository.test.ets`：Repository CRUD / 任务防重复 / 种子播种 / 空数据处理（注入 MemoryEventStore）
- `List.test.ets`：注册新测试套件

## 5. RDB 设计

库名 `campus_safety.db`，`StoreConfig { name: 'campus_safety.db', securityLevel: SecurityLevel.S1 }`。

```sql
CREATE TABLE IF NOT EXISTS security_event (
  id TEXT PRIMARY KEY, title TEXT NOT NULL, type TEXT NOT NULL,
  location TEXT NOT NULL, description TEXT NOT NULL, reporter TEXT NOT NULL,
  reportTime TEXT NOT NULL, status TEXT NOT NULL, priority TEXT NOT NULL,
  handler TEXT
);
CREATE TABLE IF NOT EXISTS task (
  id TEXT PRIMARY KEY, eventId TEXT NOT NULL, title TEXT NOT NULL,
  location TEXT NOT NULL, description TEXT NOT NULL, assignee TEXT NOT NULL,
  createTime TEXT NOT NULL, status TEXT NOT NULL
);
```

- 枚举以字符串值存储（`EventStatus.PENDING = '待确认'` 等），与模型一致，读写时直接映射。
- 关系：`task.eventId → security_event.id`，靠查询 `WHERE eventId = ?` 关联，M3 闭环直接用。

## 6. EventService 最小改动（A，已授权）

| 现有方法 | 改动 |
|---|---|
| `getAllEvents()` | → `EventRepository.getInstance().getEvents()` |
| `getPendingEvents()` | → 对 Repository 结果过滤 |
| `getEventById(id)` | → Repository |
| `getAllTasks()` | → Repository |
| `confirmEvent(id)` | 查 Repository 事件 → 改 status → `updateEvent` 落盘 |
| `createTaskFromEvent(id)` | 用 Repository 查 eventId 防重复 → 新建 Task → `saveTask` 落盘 |
| 种子数据 | 保留 `EVT001-003` 字面量；按 §7 机制经 Repository 幂等播种 |

外部方法签名全部不变，页面零改动。

## 7. 播种策略

- 种子数据归属：`EVT001-003` 字面量**保留在 EventService**（A 的既有数据，不复制到 C）。
- 触发点：EventService 内新增静态布尔 `seeded`；首次调用 `getAllEvents()` 时，若 `!seeded`：置 `seeded = true`，并检查 `EventRepository.getEvents()` 为空则 `saveEvents(种子)`。
- 幂等：`seeded` 标志保证只播种一次；用户删除全部事件后重启，会再次播种（与现状行为一致，可接受）。
- 前提：`RepositoryManager.init` 已在页面出现前 await 完成，故首次读取时缓存已加载，不会误判空库。

## 8. 错误处理

- 写穿失败：`hilog.error` 记录 + 缓存不回滚（会话内数据不丢），不静默。后续可加错误事件回调（M2 不做，YAGNI）。
- 查询不存在：`getEventById` 返回 `undefined`（与现状一致）。
- RDB 打开/建表失败：init reject，hilog 记录；应用仍可运行（内存空缓存），不崩溃。

## 9. 测试与验证（对齐 TESTING.md 四级）

**① 业务逻辑测试（本地 Node 单测，注入 MemoryEventStore）**
- Repository：saveEvent → getEvents 含新事件；getEventById 命中/未命中；updateEvent 字段更新；deleteEvent 后消失；saveEvents 批量。
- Task：saveTask / getTaskByEventId / 防重复 / getAllTasks。
- 播种：空库播种一次、非空库不重复播。
- 空数据、ID 唯一性不破坏。

**② 应用运行测试（云手机，Lycorius03 执行）**
- 启动 → 看到 3 条种子 → 事件详情确认 → 生成任务 → **杀进程重启** → 确认状态与任务仍在（重启恢复验收）。
- 连续操作不崩溃、数据不错乱。

**③ 回归**：M1 的 11 条用例（EventSimulator + LocalUnit）必须仍通过。

## 10. 边界与风险

- 只允许改 §4 列出的 2 个 A 文件 + C 范围文件；改动均登记 `docs/C跨模块对接.md`。
- `RdbEventStore` 无法在本地 Node 单测运行（系统 API），其正确性由云手机应用运行测试覆盖；本地单测通过 MemoryEventStore 验证 Repository 逻辑。
- 不改页面、不改核心 Model、不改 EventService 对外签名。
- M2 不做事件模拟器→页面的接线（那是 M3 业务闭环）。

## 11. 分支与提交

- M1 合入 main 后，从最新 main 开 `feature/C-repository` 实施（分支策略实施时与 Lycorius03 确认）。
- Commit 身份必须为 `Lycorius03`；提交前 `git diff --name-only` 核对 C 范围 + 授权 A 文件。
