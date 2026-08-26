# C 模块整体计划

> 生成日期：2026-08-26
> 分支基线：main（当前 feature/C-event-simulator）
> 适用文档：C_MODULE_SPEC.md / MODULE_BOUNDARIES.md / TECH_STACK.md / TESTING.md / WORKFLOW.md / CLAUDE.md

## 1. 目标与成功标准

在 2026-10-31 竞赛提交/演示截止前，让「发现 → 确认 → 派单 → 处理 → 反馈 → 完成」的**单端业务闭环稳定可演示**。

成功标准：**最小闭环先跑通** —— 第一阶段就产出可演示成果，随后按规范逐步补齐；不做"纸上先进、Demo 跑不动"的设计。

## 2. 总体架构（目标态）

```
EventSimulator ──→ SecurityEvent ──→ EventService(业务) ──→ Repository(数据) ──→ ArkData(持久化)
```

- 复用现有核心模型：`SecurityEvent` / `Task` / `User`（A 负责，只读边界）。
- 复用现有公共服务：`EventService`（A 负责，只读边界，C 只通过其已有接口调用或 C 侧适配）。
- 页面不得直接操作底层存储；数据读写统一经 Repository。
- 端侧持久化优先使用 OpenHarmony 原生能力（ArkData / Preferences）。

## 3. 分期计划

每期一个 `feature/C-*` 分支，从最新 `main` 创建，每期可独立验证、可回归。

| 阶段 | 分支名 | 范围 | 验收标准 |
|---|---|---|---|
| M1 | `feature/C-event-simulator` | 事件模拟器：生成标准化 `SecurityEvent`，ID 唯一、字段完整、覆盖现有 `EventType` | 模拟器稳定产出合法事件；单测通过 |
| M2 | `feature/C-repository` | 数据层：Repository（getEvents / getEventById / saveEvent / updateEvent / deleteEvent）+ ArkData 端侧持久化 | 读写/更新/删除/重启恢复全部通过；单测通过 |
| M3 | `feature/C-event-workflow` | 业务闭环：模拟 → 确认 → 生成任务 → 处理 → 完成，防重复 Task 保护，状态一致性 | 完整闭环稳定可演示；单测通过 |
| M4 | `feature/C-testing-stability` | 测试体系 + 稳定性回归：Hypium/hamock 全流程用例、连续/重复/空数据/重启场景、Demo 回归 | 测试通过 + 回归验证报告 |

## 4. 已知决策点

> 到对应阶段时向 Lycorius03 提出 C 侧方案并确认后再实施，不阻塞当前阶段。

1. **M2 数据层衔接**：`EventService` 属 A 的公共 Service，C 不得修改。需给出「C 侧新增 Repository，由 C 适配层把数据源切换到新存储」的方案，确认后再动。
2. **M2 持久化选型**：倾向 ArkData RDB（关系型，适合事件 ↔ 任务关联）；Preferences 仅适合轻量配置。最终按确认结果实施。

## 5. 质量与验证要求

遵循 TESTING.md 四级验证：代码检查 → 业务逻辑测试 → 应用运行测试 → 完整 Demo 回归。

- 每期必须：构建成功、相关单测通过、核心流程可运行、无 A/B 文件被误改。
- 回归最低范围：首页 → 事件列表 → 事件详情 → 事件确认 → 生成任务 → 任务列表。
- 稳定性场景：连续生成事件、快速重复操作、重复确认、重复生成任务、查询不存在数据、空列表、数据量增加、应用重启。

## 6. 边界约束（重申）

- C 只修改 C 范围内文件；A/B 代码、页面、组件、配置一律只读。
- 遇到 A/B 问题：先 C 内适配；适配不了向 Lycorius03 汇报，不擅自越界。
- Git 提交身份必须为 `Lycorius03`，禁止任何 AI 名义的贡献者信息。
