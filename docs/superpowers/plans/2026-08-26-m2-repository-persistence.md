# M2 Repository + ArkData 持久化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 新增 C 模块 `EventRepository`（同步缓存 + 异步写穿）与 ArkData RDB 端侧持久化，并授权最小改动 A 的 `EventService`/`EntryAbility`，让现有数据流接入持久化（重启数据不丢）。

**Architecture:** `页面(B) → EventService(A,仅数据源切换) → EventRepository(C) → EventStore(存储抽象) → {MemoryEventStore(本地单测) | RdbEventStore(relationalStore 真机)}`。Repository 持同步内存缓存供页面读，写入经 EventStore 异步写穿 RDB；启动时 `RepositoryManager.init(context)` 开库灌缓存后 `loadContent`。

**Tech Stack:** ArkTS / ArkUI（复用模型）、ArkData relationalStore（API 20）、Hypium 单元测试（本地 Node 可跑 async 用例）。

**关键环境（已验证，勿重复验证）：**
- 命令行构建/测试命令（git-bash）：
  ```bash
  cd "f:/OpenHarmony/OpenHarmonyCampusSafety"
  export DEVECO_SDK_HOME="F:/OpenHarmony/IDE/DevEco Studio/sdk"
  export NODE_HOME="F:/OpenHarmony/IDE/DevEco Studio/tools/node"
  HV="F:/OpenHarmony/IDE/DevEco Studio/tools/node/node.exe F:/OpenHarmony/IDE/DevEco Studio/tools/hvigor/bin/hvigorw.js"
  "$HV" test --no-daemon            # 本地单元测试
  "$HV" assembleHap --mode module -p product=default -p buildMode=debug --no-daemon   # 编译
  ```
- 已验证事实：`@kit.ArkData` 导出 `relationalStore/ValuesBucket`；`getRdbStore(context, StoreConfig): Promise<RdbStore>`；`StoreConfig{name, securityLevel: SecurityLevel.S1}`；`new RdbPredicates(table).equalTo(field, value)`；`insert(table, values, ConflictResolution.ON_CONFLICT_REPLACE)`；`update(values, predicates)`；`delete(predicates)`；`executeSql(sql)`；`querySql(sql): Promise<ResultSet>`；`ResultSet.goToNextRow()/getString(idx)/getColumnIndex(name)/close()`；`ValuesBucket = Record<string, ValueType>`；`common.Context`/`ApplicationContext` 从 `@kit.AbilityKit` 导出；本地单测可 import `@kit.ArkData`；`string as 枚举` 类型断言可编译可运行；Hypium 默认支持 async 测试用例。

**边界（硬性）：** 只改 C 范围文件 + 授权 A 文件 `EventService.ets`、`EntryAbility.ets`。任何 A/B 改动登记 `docs/C跨模块对接.md`。git 身份必须为 `Lycorius03`，提交前 `git config user.name` 检查 + `git diff --name-only` 核对。

---

## File Structure

- Create: `entry/src/main/ets/repository/EventRepository.ets` — 数据访问层（同步缓存 + 写穿）
- Create: `entry/src/main/ets/repository/RepositoryManager.ets` — 初始化入口（开库/建表/灌缓存）
- Create: `entry/src/main/ets/repository/store/EventStore.ets` — 存储抽象接口
- Create: `entry/src/main/ets/repository/store/MemoryEventStore.ets` — 内存实现（本地单测）
- Create: `entry/src/main/ets/repository/store/RdbEventStore.ets` — relationalStore 实现（真机）
- Create: `entry/src/test/EventRepository.test.ets` — Repository/EventService/播种测试
- Modify: `entry/src/test/List.test.ets` — 注册新测试套件
- Modify（A 授权）: `entry/src/main/ets/service/EventService.ets` — 数据源切换 + 播种
- Modify（A 授权）: `entry/src/main/ets/entryability/EntryAbility.ets` — 初始化接入
- Modify: `docs/C跨模块对接.md` — 登记/更新 A 改动

---

### Task 1: EventStore 抽象接口 + MemoryEventStore

**Files:**
- Create: `entry/src/main/ets/repository/store/EventStore.ets`
- Create: `entry/src/main/ets/repository/store/MemoryEventStore.ets`
- Create: `entry/src/test/EventRepository.test.ets`
- Modify: `entry/src/test/List.test.ets`

- [x] **Step 1: 写失败测试（MemoryEventStore 的保存/加载/删除 + 任务）**

创建 `entry/src/test/EventRepository.test.ets`：

```typescript
import { describe, it, beforeEach, expect } from '@ohos/hypium';

import {
  SecurityEvent,
  EventStatus,
  EventPriority,
  EventType
} from '../main/ets/model/SecurityEvent';

import {
  Task,
  TaskStatus
} from '../main/ets/model/Task';

import { MemoryEventStore } from '../main/ets/repository/store/MemoryEventStore';

function buildEvent(id: string): SecurityEvent {
  return {
    id: id,
    title: '烟雾异常',
    type: EventType.FIRE,
    location: '教学楼3层走廊',
    description: '消防监测区域发现异常烟雾',
    reporter: '系统模拟',
    reportTime: '2026-08-26 10:00',
    status: EventStatus.PENDING,
    priority: EventPriority.HIGH
  };
}

function buildTask(id: string, eventId: string): Task {
  return {
    id: id,
    eventId: eventId,
    title: '烟雾异常处置',
    location: '教学楼3层走廊',
    description: '消防监测区域发现异常烟雾',
    assignee: '待分配',
    createTime: '2026-08-26 10:00',
    status: TaskStatus.PENDING
  };
}

export default function eventRepositoryTest() {
  describe('EventRepositoryTest', () => {
    beforeEach(() => {
    });

    it('memory_store_save_and_load_events', 0, async () => {
      const store = new MemoryEventStore();
      await store.saveEvent(buildEvent('E1'));
      await store.saveEvent(buildEvent('E2'));
      const events: SecurityEvent[] = await store.loadEvents();
      expect(events.length).assertEqual(2);
      expect(events[0].id).assertEqual('E1');
    });

    it('memory_store_delete_event', 0, async () => {
      const store = new MemoryEventStore();
      await store.saveEvent(buildEvent('E1'));
      await store.deleteEvent('E1');
      const events: SecurityEvent[] = await store.loadEvents();
      expect(events.length).assertEqual(0);
    });

    it('memory_store_save_and_load_tasks', 0, async () => {
      const store = new MemoryEventStore();
      await store.saveTask(buildTask('TASK001', 'E1'));
      const tasks: Task[] = await store.loadTasks();
      expect(tasks.length).assertEqual(1);
      expect(tasks[0].eventId).assertEqual('E1');
    });
  });
}
```

- [x] **Step 2: 注册测试套件**

修改 `entry/src/test/List.test.ets`：

```typescript
import localUnitTest from './LocalUnit.test';
import eventSimulatorTest from './EventSimulator.test';
import eventRepositoryTest from './EventRepository.test';

export default function testsuite() {
  localUnitTest();
  eventSimulatorTest();
  eventRepositoryTest();
}
```

- [x] **Step 3: 运行确认失败**

Run: `"$HV" test --no-daemon`
Expected: `BUILD FAILED`，报 `Cannot find module .../repository/store/MemoryEventStore`（类尚未定义）。

- [x] **Step 4: 实现 EventStore 接口 + MemoryEventStore**

创建 `entry/src/main/ets/repository/store/EventStore.ets`：

```typescript
import { SecurityEvent } from '../../model/SecurityEvent';
import { Task } from '../../model/Task';

/**
 * 存储抽象接口（C 模块）
 *
 * 持久化后端统一入口：本地单测用 MemoryEventStore，
 * 真机/云手机用 RdbEventStore（relationalStore）。
 */
export interface EventStore {
  loadEvents(): Promise<SecurityEvent[]>;
  loadTasks(): Promise<Task[]>;
  saveEvent(event: SecurityEvent): Promise<void>;
  updateEvent(event: SecurityEvent): Promise<void>;
  deleteEvent(id: string): Promise<void>;
  saveTask(task: Task): Promise<void>;
}
```

创建 `entry/src/main/ets/repository/store/MemoryEventStore.ets`：

```typescript
import { SecurityEvent } from '../../model/SecurityEvent';
import { Task } from '../../model/Task';
import { EventStore } from './EventStore';

/**
 * 内存版存储实现：供本地单元测试注入，
 * 不依赖任何系统 API，Node 环境可运行。
 */
export class MemoryEventStore implements EventStore {
  private events: SecurityEvent[] = [];
  private tasks: Task[] = [];

  async loadEvents(): Promise<SecurityEvent[]> {
    return this.events;
  }

  async loadTasks(): Promise<Task[]> {
    return this.tasks;
  }

  async saveEvent(event: SecurityEvent): Promise<void> {
    const index: number = this.events.findIndex((item: SecurityEvent) => item.id === event.id);
    if (index >= 0) {
      this.events[index] = event;
    } else {
      this.events.push(event);
    }
  }

  async updateEvent(event: SecurityEvent): Promise<void> {
    const index: number = this.events.findIndex((item: SecurityEvent) => item.id === event.id);
    if (index >= 0) {
      this.events[index] = event;
    } else {
      this.events.push(event);
    }
  }

  async deleteEvent(id: string): Promise<void> {
    this.events = this.events.filter((item: SecurityEvent) => item.id !== id);
  }

  async saveTask(task: Task): Promise<void> {
    const index: number = this.tasks.findIndex((item: Task) => item.id === task.id);
    if (index >= 0) {
      this.tasks[index] = task;
    } else {
      this.tasks.push(task);
    }
  }
}
```

- [x] **Step 5: 运行确认通过**

Run: `"$HV" test --no-daemon`
Expected: `BUILD SUCCESSFUL`，`EventRepositoryTest` 的 3 条 MemoryEventStore 用例全过。

- [x] **Step 6: Commit**

```bash
git add entry/src/main/ets/repository/store/EventStore.ets \
        entry/src/main/ets/repository/store/MemoryEventStore.ets \
        entry/src/test/EventRepository.test.ets \
        entry/src/test/List.test.ets
git commit -m "feat: add event store abstraction with memory implementation"
```
提交前检查：`git config user.name`（Lycorius03）；`git diff --cached --name-only` 仅含上述 4 个 C 范围文件。

---

### Task 2: EventRepository（同步缓存 + 异步写穿）

**Files:**
- Create: `entry/src/main/ets/repository/EventRepository.ets`
- Modify: `entry/src/test/EventRepository.test.ets`

- [x] **Step 1: 写失败测试（Repository CRUD + 任务方法 + 空数据处理）**

在 `entry/src/test/EventRepository.test.ets` 的 `beforeEach` 加入 `EventRepository.initForTest(new MemoryEventStore())`，并在 `describe` 内追加：

```typescript
import { EventRepository } from '../main/ets/repository/EventRepository';
```
（顶部 import；beforeEach 改为：）

```typescript
    beforeEach(() => {
      EventRepository.initForTest(new MemoryEventStore());
    });
```

追加用例：

```typescript
    it('repository_save_event_then_get', 0, () => {
      const repo = EventRepository.getInstance();
      repo.saveEvent(buildEvent('EVT100'));
      expect(repo.getEvents().length).assertEqual(1);
      const found = repo.getEventById('EVT100');
      expect(found === undefined).assertFalse();
      if (found !== undefined) {
        expect(found.title).assertEqual('烟雾异常');
      }
    });

    it('repository_get_event_by_id_undefined_when_absent', 0, () => {
      const repo = EventRepository.getInstance();
      expect(repo.getEventById('NOPE')).assertEqual(undefined);
    });

    it('repository_update_event_changes_fields', 0, () => {
      const repo = EventRepository.getInstance();
      repo.saveEvent(buildEvent('EVT100'));
      const updated: SecurityEvent = buildEvent('EVT100');
      updated.status = EventStatus.CONFIRMED;
      repo.updateEvent(updated);
      const found = repo.getEventById('EVT100');
      expect(found === undefined).assertFalse();
      if (found !== undefined) {
        expect(found.status).assertEqual(EventStatus.CONFIRMED);
      }
    });

    it('repository_delete_event_removes', 0, () => {
      const repo = EventRepository.getInstance();
      repo.saveEvent(buildEvent('EVT100'));
      repo.deleteEvent('EVT100');
      expect(repo.getEvents().length).assertEqual(0);
      expect(repo.getEventById('EVT100')).assertEqual(undefined);
    });

    it('repository_save_events_batch', 0, () => {
      const repo = EventRepository.getInstance();
      repo.saveEvents([buildEvent('E1'), buildEvent('E2'), buildEvent('E3')]);
      expect(repo.getEvents().length).assertEqual(3);
    });

    it('repository_save_task_and_get_by_event_id', 0, () => {
      const repo = EventRepository.getInstance();
      repo.saveTask(buildTask('TASK001', 'EVT100'));
      expect(repo.getAllTasks().length).assertEqual(1);
      const task = repo.getTaskByEventId('EVT100');
      expect(task === undefined).assertFalse();
      if (task !== undefined) {
        expect(task.id).assertEqual('TASK001');
      }
    });

    it('repository_get_task_by_event_id_undefined_when_absent', 0, () => {
      const repo = EventRepository.getInstance();
      expect(repo.getTaskByEventId('NOPE')).assertEqual(undefined);
    });

    it('repository_empty_initial_state', 0, () => {
      const repo = EventRepository.getInstance();
      expect(repo.getEvents().length).assertEqual(0);
      expect(repo.getAllTasks().length).assertEqual(0);
    });
```

- [x] **Step 2: 运行确认失败**

Run: `"$HV" test --no-daemon`
Expected: `BUILD FAILED`，`Cannot find module .../repository/EventRepository`。

- [x] **Step 3: 实现 EventRepository**

创建 `entry/src/main/ets/repository/EventRepository.ets`：

```typescript
import { SecurityEvent } from '../model/SecurityEvent';
import { Task } from '../model/Task';
import { EventStore } from './store/EventStore';

/**
 * 数据访问层（C 模块）
 *
 * 同步缓存 + 异步写穿：读取走内存缓存（页面同步接口），
 * 写入同步更新缓存并通过 EventStore 异步持久化。
 */
export class EventRepository {
  private static instance: EventRepository | null = null;

  private store: EventStore | null = null;
  private events: SecurityEvent[] = [];
  private tasks: Task[] = [];
  private seeded: boolean = false;
  private loaded: boolean = false;

  static getInstance(): EventRepository {
    if (EventRepository.instance === null) {
      EventRepository.instance = new EventRepository();
    }
    return EventRepository.instance;
  }

  /**
   * 测试注入：用指定 store 重置单例，保证用例间隔离。
   */
  static initForTest(store: EventStore): EventRepository {
    const repository: EventRepository = new EventRepository();
    repository.store = store;
    repository.loaded = true;
    EventRepository.instance = repository;
    return repository;
  }

  setStore(store: EventStore): void {
    this.store = store;
  }

  isLoaded(): boolean {
    return this.loaded;
  }

  /**
   * 从持久化后端加载全部数据到缓存（应用启动时调用一次）。
   */
  async load(): Promise<void> {
    if (this.store === null) {
      return;
    }
    this.events = await this.store.loadEvents();
    this.tasks = await this.store.loadTasks();
    this.loaded = true;
  }

  /**
   * 空库播种（幂等）：仅第一次且缓存为空时写入种子。
   */
  seedIfEmpty(seedEvents: SecurityEvent[]): void {
    if (this.seeded) {
      return;
    }
    this.seeded = true;
    if (this.events.length === 0) {
      this.saveEvents(seedEvents);
    }
  }

  getEvents(): SecurityEvent[] {
    return this.events;
  }

  getEventById(id: string): SecurityEvent | undefined {
    return this.events.find((event: SecurityEvent) => event.id === id);
  }

  saveEvent(event: SecurityEvent): void {
    const index: number = this.events.findIndex((item: SecurityEvent) => item.id === event.id);
    if (index >= 0) {
      this.events[index] = event;
    } else {
      this.events.push(event);
    }
    if (this.store !== null) {
      this.store.saveEvent(event).catch((err: Error) => {
        console.error('EventRepository.saveEvent failed: ' + err.message);
      });
    }
  }

  saveEvents(events: SecurityEvent[]): void {
    events.forEach((event: SecurityEvent) => {
      this.saveEvent(event);
    });
  }

  updateEvent(event: SecurityEvent): void {
    const index: number = this.events.findIndex((item: SecurityEvent) => item.id === event.id);
    if (index >= 0) {
      this.events[index] = event;
      if (this.store !== null) {
        this.store.updateEvent(event).catch((err: Error) => {
          console.error('EventRepository.updateEvent failed: ' + err.message);
        });
      }
    } else {
      this.saveEvent(event);
    }
  }

  deleteEvent(id: string): void {
    this.events = this.events.filter((event: SecurityEvent) => event.id !== id);
    if (this.store !== null) {
      this.store.deleteEvent(id).catch((err: Error) => {
        console.error('EventRepository.deleteEvent failed: ' + err.message);
      });
    }
  }

  getAllTasks(): Task[] {
    return this.tasks;
  }

  getTaskByEventId(eventId: string): Task | undefined {
    return this.tasks.find((task: Task) => task.eventId === eventId);
  }

  saveTask(task: Task): void {
    const index: number = this.tasks.findIndex((item: Task) => item.id === task.id);
    if (index >= 0) {
      this.tasks[index] = task;
    } else {
      this.tasks.push(task);
    }
    if (this.store !== null) {
      this.store.saveTask(task).catch((err: Error) => {
        console.error('EventRepository.saveTask failed: ' + err.message);
      });
    }
  }
}
```

- [x] **Step 4: 运行确认通过**

Run: `"$HV" test --no-daemon`
Expected: `BUILD SUCCESSFUL`，全部 `EventRepositoryTest` 用例通过（含新 8 条）。

- [x] **Step 5: Commit**

```bash
git add entry/src/main/ets/repository/EventRepository.ets entry/src/test/EventRepository.test.ets
git commit -m "feat: add event repository with sync cache and async write-through"
```

---

### Task 3: EventService 数据源切换 + 幂等播种（A 授权改动）

**Files:**
- Modify: `entry/src/main/ets/service/EventService.ets`
- Modify: `entry/src/test/EventRepository.test.ets`

- [x] **Step 1: 写失败测试（EventService 走 Repository + 播种幂等 + 确认/任务落盘）**

在 `entry/src/test/EventRepository.test.ets` 的 `describe` 内追加（复用已有 `EventRepository.initForTest` beforeEach，并 import EventService）：

```typescript
import { EventService } from '../main/ets/service/EventService';
```

```typescript
    it('event_service_seeds_empty_repository', 0, () => {
      const events: SecurityEvent[] = EventService.getAllEvents();
      expect(events.length).assertEqual(3);
      expect(events[0].id).assertEqual('EVT001');
    });

    it('event_service_seed_only_once', 0, () => {
      EventService.getAllEvents();
      EventRepository.getInstance().deleteEvent('EVT001');
      const events: SecurityEvent[] = EventService.getAllEvents();
      expect(events.length).assertEqual(2);
    });

    it('event_service_confirm_persists_to_repository', 0, () => {
      EventService.confirmEvent('EVT001');
      const found = EventRepository.getInstance().getEventById('EVT001');
      expect(found === undefined).assertFalse();
      if (found !== undefined) {
        expect(found.status).assertEqual(EventStatus.CONFIRMED);
      }
    });

    it('event_service_create_task_and_deduplicate', 0, () => {
      EventService.createTaskFromEvent('EVT003');
      expect(EventService.getAllTasks().length).assertEqual(1);
      expect(EventService.getAllTasks()[0].eventId).assertEqual('EVT003');
      EventService.createTaskFromEvent('EVT003');
      expect(EventService.getAllTasks().length).assertEqual(1);
    });

    it('event_service_get_event_by_id_unknown_returns_undefined', 0, () => {
      expect(EventService.getEventById('UNKNOWN')).assertEqual(undefined);
    });
```

- [x] **Step 2: 运行确认失败**

Run: `"$HV" test --no-daemon`
Expected: 失败（EventService 仍是内存数组，`getAllEvents` 不播种 → `events.length` 不等于 3）。

- [x] **Step 3: 改造 EventService（数据源切换 + 播种）**

整体替换 `entry/src/main/ets/service/EventService.ets` 为：

```typescript
import {
  SecurityEvent,
  EventStatus,
  EventPriority,
  EventType
} from '../model/SecurityEvent';

import {
  Task,
  TaskStatus
} from '../model/Task';

import { EventRepository } from '../repository/EventRepository';

export class EventService {
  private static selectedEventId: string = '';

  private static seedEvents: SecurityEvent[] = [
    {
      id: 'EVT001',
      title: '教学楼走廊漏水',
      type: EventType.FACILITY,
      location: '教学楼3楼',
      description: '教学楼三楼走廊顶部出现漏水现象',
      reporter: '张同学',
      reportTime: '2026-08-25 09:30',
      status: EventStatus.PENDING,
      priority: EventPriority.HIGH
    },
    {
      id: 'EVT002',
      title: '实验室插座异常',
      type: EventType.ELECTRIC,
      location: '实验楼201',
      description: '实验室墙面插座出现异常发热',
      reporter: '李老师',
      reportTime: '2026-08-25 10:15',
      status: EventStatus.CONFIRMED,
      priority: EventPriority.URGENT
    },
    {
      id: 'EVT003',
      title: '消防通道堆放杂物',
      type: EventType.FIRE,
      location: '宿舍楼1楼',
      description: '消防通道存在杂物堆放情况',
      reporter: '王同学',
      reportTime: '2026-08-25 11:20',
      status: EventStatus.PROCESSING,
      priority: EventPriority.MEDIUM
    }
  ];

  static getAllEvents(): SecurityEvent[] {
    EventService.ensureSeeded();
    return EventRepository.getInstance().getEvents();
  }

  static getPendingEvents(): SecurityEvent[] {
    EventService.ensureSeeded();
    return EventRepository.getInstance().getEvents().filter(
      (event: SecurityEvent) => event.status === EventStatus.PENDING
    );
  }

  static getEventById(id: string): SecurityEvent | undefined {
    EventService.ensureSeeded();
    return EventRepository.getInstance().getEventById(id);
  }

  static setSelectedEventId(id: string): void {
    EventService.selectedEventId = id;
  }

  static getSelectedEventId(): string {
    return EventService.selectedEventId;
  }

  static confirmEvent(id: string): void {
    const event = EventService.getEventById(id);

    if (event !== undefined) {
      event.status = EventStatus.CONFIRMED;
      EventRepository.getInstance().updateEvent(event);
    }
  }

  static createTaskFromEvent(id: string): void {
    const event = EventService.getEventById(id);

    if (event === undefined) {
      return;
    }

    const existingTask = EventRepository.getInstance().getTaskByEventId(id);

    if (existingTask !== undefined) {
      return;
    }

    const newTask: Task = {
      id: 'TASK' + (EventRepository.getInstance().getAllTasks().length + 1).toString().padStart(3, '0'),
      eventId: event.id,
      title: event.title,
      location: event.location,
      description: event.description,
      assignee: '待分配',
      createTime: event.reportTime,
      status: TaskStatus.PENDING
    };

    EventRepository.getInstance().saveTask(newTask);
  }

  static getAllTasks(): Task[] {
    return EventRepository.getInstance().getAllTasks();
  }

  private static ensureSeeded(): void {
    EventRepository.getInstance().seedIfEmpty(EventService.seedEvents);
  }
}
```

- [x] **Step 4: 运行确认通过**

Run: `"$HV" test --no-daemon`
Expected: `BUILD SUCCESSFUL`，全部 `EventRepositoryTest` 用例通过（含新 5 条 EventService 用例）。

- [x] **Step 5: 登记 A/B 改动到对接文档**

在 `docs/C跨模块对接.md` 的 M2 表格，将第 1 行（EventService）状态从"已授权"更新为"已实现（本任务）"，并保留改动描述。

- [x] **Step 6: Commit**

```bash
git add entry/src/main/ets/service/EventService.ets entry/src/test/EventRepository.test.ets docs/C跨模块对接.md
git commit -m "feat: switch EventService data source to repository with seeding"
```
提交前确认 `git diff --cached --name-only`：除 C 测试外，A 文件仅 `entry/src/main/ets/service/EventService.ets`（授权内），文档已登记。

---

### Task 4: RdbEventStore（relationalStore 真机实现）

**Files:**
- Create: `entry/src/main/ets/repository/store/RdbEventStore.ets`

> 说明：relationalStore 是系统 API，本地 Node 单测无法真实读写（无法注入设备 Context），本任务以**编译验证 + 云手机人工验证**为准（TESTING.md 第三级"应用运行测试"）。本地单测不覆盖本文件，符合 TESTING.md 优先级。

- [x] **Step 1: 实现 RdbEventStore**

创建 `entry/src/main/ets/repository/store/RdbEventStore.ets`：

```typescript
import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

import {
  SecurityEvent,
  EventStatus,
  EventPriority,
  EventType
} from '../../model/SecurityEvent';
import { Task, TaskStatus } from '../../model/Task';
import { EventStore } from './EventStore';

const DB_NAME: string = 'campus_safety.db';

/**
 * relationalStore 存储实现（C 模块，真机/云手机用）。
 *
 * 事件与任务各一张表，task.eventId 关联 security_event.id。
 */
export class RdbEventStore implements EventStore {
  private rdbStore: relationalStore.RdbStore;

  private constructor(rdbStore: relationalStore.RdbStore) {
    this.rdbStore = rdbStore;
  }

  static async create(context: common.Context): Promise<RdbEventStore> {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const rdbStore: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config);
    const store: RdbEventStore = new RdbEventStore(rdbStore);
    await store.initSchema();
    return store;
  }

  private async initSchema(): Promise<void> {
    await this.rdbStore.executeSql(
      'CREATE TABLE IF NOT EXISTS security_event (' +
      'id TEXT PRIMARY KEY, title TEXT NOT NULL, type TEXT NOT NULL, ' +
      'location TEXT NOT NULL, description TEXT NOT NULL, reporter TEXT NOT NULL, ' +
      'reportTime TEXT NOT NULL, status TEXT NOT NULL, priority TEXT NOT NULL, handler TEXT)'
    );
    await this.rdbStore.executeSql(
      'CREATE TABLE IF NOT EXISTS task (' +
      'id TEXT PRIMARY KEY, eventId TEXT NOT NULL, title TEXT NOT NULL, ' +
      'location TEXT NOT NULL, description TEXT NOT NULL, assignee TEXT NOT NULL, ' +
      'createTime TEXT NOT NULL, status TEXT NOT NULL)'
    );
  }

  async loadEvents(): Promise<SecurityEvent[]> {
    const resultSet: relationalStore.ResultSet = await this.rdbStore.querySql('SELECT * FROM security_event');
    const events: SecurityEvent[] = [];
    while (resultSet.goToNextRow()) {
      events.push(this.rowToEvent(resultSet));
    }
    resultSet.close();
    return events;
  }

  async loadTasks(): Promise<Task[]> {
    const resultSet: relationalStore.ResultSet = await this.rdbStore.querySql('SELECT * FROM task');
    const tasks: Task[] = [];
    while (resultSet.goToNextRow()) {
      tasks.push(this.rowToTask(resultSet));
    }
    resultSet.close();
    return tasks;
  }

  async saveEvent(event: SecurityEvent): Promise<void> {
    await this.rdbStore.insert(
      'security_event',
      this.eventToBucket(event),
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
    );
  }

  async updateEvent(event: SecurityEvent): Promise<void> {
    const predicates: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates('security_event').equalTo('id', event.id);
    await this.rdbStore.update(this.eventToBucket(event), predicates);
  }

  async deleteEvent(id: string): Promise<void> {
    const predicates: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates('security_event').equalTo('id', id);
    await this.rdbStore.delete(predicates);
  }

  async saveTask(task: Task): Promise<void> {
    const values: ValuesBucket = {
      'id': task.id,
      'eventId': task.eventId,
      'title': task.title,
      'location': task.location,
      'description': task.description,
      'assignee': task.assignee,
      'createTime': task.createTime,
      'status': task.status
    };
    await this.rdbStore.insert('task', values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  private eventToBucket(event: SecurityEvent): ValuesBucket {
    const handler: string | null = event.handler === undefined ? null : event.handler;
    const bucket: ValuesBucket = {
      'id': event.id,
      'title': event.title,
      'type': event.type,
      'location': event.location,
      'description': event.description,
      'reporter': event.reporter,
      'reportTime': event.reportTime,
      'status': event.status,
      'priority': event.priority,
      'handler': handler
    };
    return bucket;
  }

  private rowToEvent(resultSet: relationalStore.ResultSet): SecurityEvent {
    const handlerValue: string = resultSet.getString(resultSet.getColumnIndex('handler'));
    const event: SecurityEvent = {
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      title: resultSet.getString(resultSet.getColumnIndex('title')),
      type: resultSet.getString(resultSet.getColumnIndex('type')) as EventType,
      location: resultSet.getString(resultSet.getColumnIndex('location')),
      description: resultSet.getString(resultSet.getColumnIndex('description')),
      reporter: resultSet.getString(resultSet.getColumnIndex('reporter')),
      reportTime: resultSet.getString(resultSet.getColumnIndex('reportTime')),
      status: resultSet.getString(resultSet.getColumnIndex('status')) as EventStatus,
      priority: resultSet.getString(resultSet.getColumnIndex('priority')) as EventPriority,
      handler: handlerValue === '' ? undefined : handlerValue
    };
    return event;
  }

  private rowToTask(resultSet: relationalStore.ResultSet): Task {
    const task: Task = {
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      eventId: resultSet.getString(resultSet.getColumnIndex('eventId')),
      title: resultSet.getString(resultSet.getColumnIndex('title')),
      location: resultSet.getString(resultSet.getColumnIndex('location')),
      description: resultSet.getString(resultSet.getColumnIndex('description')),
      assignee: resultSet.getString(resultSet.getColumnIndex('assignee')),
      createTime: resultSet.getString(resultSet.getColumnIndex('createTime')),
      status: resultSet.getString(resultSet.getColumnIndex('status')) as TaskStatus
    };
    return task;
  }
}
```

- [x] **Step 2: 编译验证**

Run: `"$HV" assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`
Expected: `BUILD SUCCESSFUL`。若 ArkTS 报 `as EventType` 类型断言错误，将对应行改为显式字符串→枚举映射（如 `value === EventType.FIRE ? EventType.FIRE : EventType.OTHER`）后重编。

- [x] **Step 3: Commit**

```bash
git add entry/src/main/ets/repository/store/RdbEventStore.ets
git commit -m "feat: add rdb event store with relationalStore persistence"
```

---

### Task 5: RepositoryManager + EntryAbility 初始化接入（A 授权改动）

**Files:**
- Create: `entry/src/main/ets/repository/RepositoryManager.ets`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`
- Modify: `docs/C跨模块对接.md`

- [x] **Step 1: 实现 RepositoryManager**

创建 `entry/src/main/ets/repository/RepositoryManager.ets`：

```typescript
import { common } from '@kit.AbilityKit';

import { EventRepository } from './EventRepository';
import { RdbEventStore } from './store/RdbEventStore';

/**
 * Repository 初始化入口（C 模块）。
 *
 * 应用启动时开库、建表、把 RDB 数据灌入缓存；
 * 页面出现前完成，避免读空数据的竞态。
 */
export class RepositoryManager {
  private static initialized: boolean = false;

  static async init(context: common.Context): Promise<void> {
    if (RepositoryManager.initialized) {
      return;
    }
    const repository: EventRepository = EventRepository.getInstance();
    const store: RdbEventStore = await RdbEventStore.create(context);
    repository.setStore(store);
    await repository.load();
    RepositoryManager.initialized = true;
  }
}
```

- [x] **Step 2: 修改 EntryAbility（初始化后再加载首页）**

将 `entry/src/main/ets/entryability/EntryAbility.ets` 顶部加 import，并把 `onWindowStageCreate` 改为初始化后再 loadContent：

```typescript
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

import { RepositoryManager } from '../repository/RepositoryManager';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    const loadPage = (): void => {
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      });
    };

    // 先初始化持久化（开库/建表/灌缓存），再加载首页，避免页面读空数据
    RepositoryManager.init(this.context.getApplicationContext())
      .then(() => {
        hilog.info(DOMAIN, 'testTag', '%{public}s', 'Repository initialized');
        loadPage();
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', 'Repository init failed: %{public}s', err.message);
        loadPage();
      });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
```

- [x] **Step 3: 编译验证**

Run: `"$HV" assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`
Expected: `BUILD SUCCESSFUL`。

- [x] **Step 4: 全量测试回归**

Run: `"$HV" test --no-daemon`
Expected: `BUILD SUCCESSFUL`，`Tests run: <全部> Failure: 0`（M1 11 条 + EventRepositoryTest 全部，总数应 ≥ 24）。

- [x] **Step 5: 登记 A/B 改动到对接文档**

在 `docs/C跨模块对接.md` 的 M2 表格，将第 2 行（EntryAbility）状态更新为"已实现（本任务）"；顶部"待对齐事项"补充云手机验证结果待回填。

- [x] **Step 6: Commit**

```bash
git add entry/src/main/ets/repository/RepositoryManager.ets \
        entry/src/main/ets/entryability/EntryAbility.ets \
        docs/C跨模块对接.md
git commit -m "feat: initialize repository persistence before loading main page"
```
提交前确认：A 文件仅 `entry/src/main/ets/entryability/EntryAbility.ets`（授权内）。

---

### Task 6: 完整回归 + 推送 + 云手机验证清单

**Files:**
- 无新增代码（仅验证与推送）

- [x] **Step 1: 全量单测 + 编译**

Run: `"$HV" test --no-daemon` 和 `"$HV" assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`
Expected: 两者 `BUILD SUCCESSFUL`；单测 `Failure: 0, Error: 0`。

- [x] **Step 2: 边界检查**

```bash
git status
git diff --name-only origin/feature/C-repository
git log -1 --format='author=%an <%ae> / committer=%cn <%ce>'
```
确认：改动仅 C 范围 + 授权 A 文件（EventService.ets / EntryAbility.ets）；无页面/Model/配置改动；身份为 `Lycorius03`；`docs/C跨模块对接.md` 已登记全部 A 改动。

- [x] **Step 3: 推送分支**

```bash
git push origin feature/C-repository
```
（是否建 PR 由 Lycorius03 决定。）

- [ ] **Step 4: 云手机人工验证（交回 Lycorius03，TESTING.md 第三级）**

在 DevEco Studio 打开工程 → 运行到鸿蒙云手机：
1. 启动 → 首页"安全事件"列表应显示 3 条种子事件（EVT001-003）——证明 RDB 建表 + 播种成功。
2. 进详情 → 点"确认事件" → 状态变已确认；点"生成处置任务"。
3. **杀进程/重启应用** → 事件列表仍显示原 3 条，之前确认的状态、生成的"处置任务"仍存在——**重启恢复验收**。
4. 连续生成/操作多次，不崩溃、数据不错乱。
5. 若验证失败：记录现象 + 复现步骤，交回 Claude 分析（不得绕过程序掩盖问题）。

- [ ] **Step 5: 验证通过后回填对接文档**

将 `docs/C跨模块对接.md` 顶部状态更新为"M2 已实现并通过云手机验证"，归档 M2 条目。

---

## Self-Review 结论（已内联完成）

- 设计覆盖：Task 1-2 覆盖 Repository CRUD + 任务方法 + 空数据；Task 3 覆盖 EventService 衔接 + 播种幂等；Task 4 覆盖 RDB 建表/读写/删除；Task 5 覆盖初始化接入；Task 6 覆盖回归与重启恢复验证。
- 无占位符：每个 Step 含完整代码或明确命令与预期输出。
- 类型一致：`EventStore` 接口方法名/签名在 MemoryEventStore、RdbEventStore、EventRepository 三处保持一致（`loadEvents/loadTasks/saveEvent/updateEvent/deleteEvent/saveTask`）；`EventRepository` 方法名与 EventService 调用一致。
