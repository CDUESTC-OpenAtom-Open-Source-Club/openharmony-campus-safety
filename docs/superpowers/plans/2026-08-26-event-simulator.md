# Event Simulator (M1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 C 模块事件模拟器 `EventSimulator`，能稳定生成标准化 `SecurityEvent`（ID 唯一、字段完整、默认 `待确认` 状态），覆盖现有 `EventType`，并通过 Hypium 单元测试验证。

**Architecture:** 新建 `entry/src/main/ets/simulator/EventSimulator.ets`（纯 ArkTS 逻辑，不依赖系统 API），基于事件模板生成 `SecurityEvent`。数据流遵循 C_MODULE_SPEC：`EventSimulator → SecurityEvent → EventService → Repository`（本阶段只实现前两环，事件产出供后续 M2/M3 接入）。测试用 Hypium，位于 `entry/src/test/`。

**Tech Stack:** ArkTS / ArkUI（仅模型复用，无 UI）、Hypium 单元测试、复用现有 `SecurityEvent`/`EventStatus`/`EventPriority`/`EventType` 模型。

**环境约束（重要）：** 当前开发机无命令行 `hvigorw`，构建与测试验证必须通过 DevEco Studio IDE 执行（本地单元测试：entry 模块的 Local Unit Test Runner）。代码完成后由 Lycorius03 在 DevEco Studio 中运行测试确认。

---

## File Structure

- Create: `entry/src/main/ets/simulator/EventSimulator.ets` — 事件模拟器核心（模板定义、事件生成、唯一 ID、时间格式化）
- Create: `entry/src/test/EventSimulator.test.ets` — 事件模拟器单元测试
- Modify: `entry/src/test/List.test.ets` — 注册 EventSimulator 测试套件

## 设计要点

- 模板（3 种，映射现有 `EventType`）：
  - `烟雾异常` → `EventType.FIRE`（消防安全），默认优先级 `HIGH`
  - `温度异常` → `EventType.ELECTRIC`（用电安全），默认优先级 `MEDIUM`
  - `设备故障` → `EventType.FACILITY`（设施安全），默认优先级 `MEDIUM`
- 事件字段：`id`（`EVT` + 毫秒时间戳 + 3 位计数器，保证唯一且不与种子 `EVT001-003` 冲突）、`title/type/location/description` 来自模板、`reporter` 固定 `'系统模拟'`、`reportTime` 当前时间（`YYYY-MM-DD HH:mm`）、`status` 默认 `EventStatus.PENDING`、`priority` 来自模板。
- 异常输入：`simulateBatch(count<=0)` 返回空数组；`simulateEvent(非法索引)` 回退随机模板，不抛异常。
- 模拟器只产生事件，不修改状态、不创建任务、不操作 UI、不实现业务流程（遵循 C_MODULE_SPEC 第 3 节）。

---

### Task 1: 事件模拟器核心（单个事件生成）

**Files:**
- Create: `entry/src/test/EventSimulator.test.ets`
- Create: `entry/src/main/ets/simulator/EventSimulator.ets`
- Modify: `entry/src/test/List.test.ets`

- [ ] **Step 1: 写失败测试（字段完整 + 默认状态 + 指定类型）**

创建 `entry/src/test/EventSimulator.test.ets`：

```typescript
import { describe, it, expect } from '@ohos/hypium';

import {
  SecurityEvent,
  EventStatus,
  EventType,
  EventPriority
} from '../main/ets/model/SecurityEvent';

import { EventSimulator } from '../main/ets/simulator/EventSimulator';

export default function eventSimulatorTest() {
  describe('EventSimulatorTest', () => {
    it('generate_event_fields_complete', 0, () => {
      const event: SecurityEvent = EventSimulator.simulateEvent(0);
      expect(event.id.length > 0).assertTrue();
      expect(event.title.length > 0).assertTrue();
      expect(event.location.length > 0).assertTrue();
      expect(event.description.length > 0).assertTrue();
      expect(event.reporter.length > 0).assertTrue();
      expect(event.reportTime.length > 0).assertTrue();
      expect(event.type !== undefined).assertTrue();
      expect(event.priority !== undefined).assertTrue();
    });

    it('generate_event_default_status_pending', 0, () => {
      const event: SecurityEvent = EventSimulator.simulateEvent(0);
      expect(event.status).assertEqual(EventStatus.PENDING);
    });

    it('generate_event_by_template_index_maps_type', 0, () => {
      const fireEvent: SecurityEvent = EventSimulator.simulateEvent(0);
      expect(fireEvent.type).assertEqual(EventType.FIRE);

      const electricEvent: SecurityEvent = EventSimulator.simulateEvent(1);
      expect(electricEvent.type).assertEqual(EventType.ELECTRIC);

      const facilityEvent: SecurityEvent = EventSimulator.simulateEvent(2);
      expect(facilityEvent.type).assertEqual(EventType.FACILITY);
    });

    it('generate_random_event_has_valid_type', 0, () => {
      const event: SecurityEvent = EventSimulator.simulateEvent();
      const validTypes: EventType[] = [EventType.FIRE, EventType.ELECTRIC, EventType.FACILITY];
      expect(validTypes).assertContain(event.type);
    });
  });
}
```

- [ ] **Step 2: 注册测试套件**

修改 `entry/src/test/List.test.ets`，追加导入与调用：

```typescript
import localUnitTest from './LocalUnit.test';
import eventSimulatorTest from './EventSimulator.test';

export default function testsuite() {
  localUnitTest();
  eventSimulatorTest();
}
```

- [ ] **Step 3: 实现最小可用 EventSimulator（含模板、唯一 ID、时间格式化）**

创建 `entry/src/main/ets/simulator/EventSimulator.ets`：

```typescript
import {
  SecurityEvent,
  EventStatus,
  EventPriority,
  EventType
} from '../model/SecurityEvent';

interface EventTemplate {
  title: string;
  type: EventType;
  location: string;
  description: string;
  priority: EventPriority;
}

/**
 * 安全事件模拟器（C 模块）
 *
 * 只负责产生标准化 SecurityEvent，不修改事件状态、不创建任务、
 * 不操作 UI、不实现业务流程。
 */
export class EventSimulator {
  private static idCounter: number = 0;

  private static templates: EventTemplate[] = [
    {
      title: '烟雾异常',
      type: EventType.FIRE,
      location: '教学楼3层走廊',
      description: '消防监测区域发现异常烟雾，疑似火情隐患',
      priority: EventPriority.HIGH
    },
    {
      title: '温度异常',
      type: EventType.ELECTRIC,
      location: '实验楼配电间',
      description: '电气设备表面温度异常升高，存在用电风险',
      priority: EventPriority.MEDIUM
    },
    {
      title: '设备故障',
      type: EventType.FACILITY,
      location: '宿舍楼公共区域',
      description: '公共设施发生故障，无法正常使用',
      priority: EventPriority.MEDIUM
    }
  ];

  /**
   * 生成一个安全事件。
   * @param templateIndex 指定模板索引（0/1/2）；缺省或非法值时随机选择模板
   */
  static simulateEvent(templateIndex?: number): SecurityEvent {
    const index: number = EventSimulator.resolveTemplateIndex(templateIndex);
    const template: EventTemplate = EventSimulator.templates[index];
    const now: Date = new Date();

    return {
      id: EventSimulator.generateUniqueId(),
      title: template.title,
      type: template.type,
      location: template.location,
      description: template.description,
      reporter: '系统模拟',
      reportTime: EventSimulator.formatTime(now),
      status: EventStatus.PENDING,
      priority: template.priority
    };
  }

  private static resolveTemplateIndex(templateIndex?: number): number {
    if (templateIndex !== undefined &&
      templateIndex >= 0 &&
      templateIndex < EventSimulator.templates.length) {
      return templateIndex;
    }
    return Math.floor(Math.random() * EventSimulator.templates.length);
  }

  private static generateUniqueId(): string {
    EventSimulator.idCounter++;
    return 'EVT' + Date.now().toString() + EventSimulator.idCounter.toString().padStart(3, '0');
  }

  private static formatTime(date: Date): string {
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
    const day: string = date.getDate().toString().padStart(2, '0');
    const hour: string = date.getHours().toString().padStart(2, '0');
    const minute: string = date.getMinutes().toString().padStart(2, '0');
    return date.getFullYear().toString() + '-' + month + '-' + day + ' ' + hour + ':' + minute;
  }
}
```

- [ ] **Step 4: 验证**

在 DevEco Studio 中打开项目 → 对 `entry` 模块运行 **Local Unit Test**（Test Runner 执行 `entry/src/test`）→ 预期 `EventSimulatorTest` 的 4 条用例全部通过，无编译错误。
（若后续配置了命令行 `hvigorw`，等价命令：`hvigorw test`。）

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/simulator/EventSimulator.ets entry/src/test/EventSimulator.test.ets entry/src/test/List.test.ets
git commit -m "feat: add event simulator core generation"
```

提交前复核：`git config user.name`（应为 `Lycorius03`）；`git diff --cached --name-only`（仅含上述 3 个文件）。

---

### Task 2: 批量生成 + ID 唯一性

**Files:**
- Modify: `entry/src/main/ets/simulator/EventSimulator.ets`
- Modify: `entry/src/test/EventSimulator.test.ets`

- [ ] **Step 1: 写失败测试（批量数量 + ID 唯一）**

在 `entry/src/test/EventSimulator.test.ets` 的 `describe` 内追加两个用例：

```typescript
    it('generate_batch_returns_expected_count', 0, () => {
      const events: SecurityEvent[] = EventSimulator.simulateBatch(10);
      expect(events.length).assertEqual(10);
    });

    it('generate_batch_ids_are_unique', 0, () => {
      const events: SecurityEvent[] = EventSimulator.simulateBatch(50);
      const idSet: Set<string> = new Set<string>();
      events.forEach((event: SecurityEvent) => {
        idSet.add(event.id);
      });
      expect(idSet.size).assertEqual(50);
    });
```

- [ ] **Step 2: 运行确认失败**

DevEco Studio → entry 模块 Local Unit Test → 预期编译/运行报错（`simulateBatch` 尚未定义），用例失败。

- [ ] **Step 3: 实现 `simulateBatch`**

在 `EventSimulator` 类内、`simulateEvent` 之后新增：

```typescript
  /**
   * 批量生成安全事件。
   * @param count 生成数量；小于等于 0 时返回空数组
   */
  static simulateBatch(count: number): SecurityEvent[] {
    if (count <= 0) {
      return [];
    }
    const events: SecurityEvent[] = [];
    for (let i = 0; i < count; i++) {
      events.push(EventSimulator.simulateEvent());
    }
    return events;
  }
```

- [ ] **Step 4: 运行确认通过**

DevEco Studio → entry 模块 Local Unit Test → 预期 `EventSimulatorTest` 全部用例（含新增 2 条）通过，`simulateBatch` 返回数量正确、50 条事件 ID 无重复。

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/simulator/EventSimulator.ets entry/src/test/EventSimulator.test.ets
git commit -m "feat: add batch simulation with unique ids"
```

---

### Task 3: 异常输入安全处理

**Files:**
- Modify: `entry/src/test/EventSimulator.test.ets`

- [ ] **Step 1: 写失败测试（负数量 / 零数量 / 非法模板索引）**

在 `describe` 内追加：

```typescript
    it('batch_with_non_positive_count_returns_empty', 0, () => {
      expect(EventSimulator.simulateBatch(-1).length).assertEqual(0);
      expect(EventSimulator.simulateBatch(0).length).assertEqual(0);
    });

    it('event_with_invalid_template_index_falls_back_safely', 0, () => {
      const event: SecurityEvent = EventSimulator.simulateEvent(99);
      expect(event.id.length > 0).assertTrue();
      expect(event.title.length > 0).assertTrue();
      expect(event.status).assertEqual(EventStatus.PENDING);
    });
```

- [ ] **Step 2: 确认测试通过（此阶段校验逻辑已在 Task 1/2 实现）**

DevEco Studio → entry 模块 Local Unit Test → 预期 `EventSimulatorTest` 全部用例（含新增 2 条）通过。负/零数量批量返回空数组，非法模板索引回退随机模板且字段仍完整。

- [ ] **Step 3: Commit**

```bash
git add entry/src/test/EventSimulator.test.ets
git commit -m "test: cover simulator error input handling"
```

---

### Task 4: 完整回归与验证

**Files:**
- 无新增文件（仅验证）

- [ ] **Step 1: 全量测试回归**

DevEco Studio → entry 模块 Local Unit Test → 预期 `EventSimulatorTest` 全部 8 条用例通过，`LocalUnitTest` 原有用例不受影响。

- [ ] **Step 2: 应用编译检查**

DevEco Studio → 构建 entry 模块（debug）→ 预期编译成功、无 lint 报错。

- [ ] **Step 3: 边界检查**

```bash
git status
git diff --name-only
git log -1 --format='author=%an <%ae> / committer=%cn <%ce>'
```

确认：修改文件仅限 `entry/src/main/ets/simulator/`、`entry/src/test/`（C 范围）；无 A/B 文件被改；身份为 `Lycorius03`。

- [ ] **Step 4: 推送分支**

```bash
git push origin feature/C-event-simulator
```

（是否创建 PR 由 Lycorius03 决定。）
