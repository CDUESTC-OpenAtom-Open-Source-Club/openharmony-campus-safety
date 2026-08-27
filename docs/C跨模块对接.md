# C 模块跨 A/B 改动对接记录

> 用途：记录 C 在开发过程中**涉及修改 A/B 内容**的所有改动，保证与 A/B 成员随时对齐。
> 原则：C 不改 A/B；以下条目均为 Lycorius03 明确授权的最小必要改动。
> 任何未在本表登记的 A/B 文件改动视为越界，不得提交。

## 当前分支：feature/C-testing-stability（M4 测试体系 + 稳定性回归）

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

## M4：测试体系 + 稳定性回归（feature/C-testing-stability）

| # | A/B 文件 | 改动内容 | 原因 | 授权/对齐状态 |
|---|---|---|---|---|
| 4 | `entry/src/main/ets/pages/EventPage.ets` | 列表项 `onClick` 中 `pushPath` 用的 `pageStack` 由 `@Prop pageStack: NavPathStack` 改为普通成员变量 `pageStack: NavPathStack = new NavPathStack()`（默认值被 Index 构造参数 `EventPage({ pageStack: this.pageStack })` 覆盖，运行时仍是 Index 的同一实例）。其余逻辑零改动 | ArkUI-X 引擎下 `@Prop` 对 NavPathStack 对象做**深拷贝 + 单向同步**，拷贝副本的 JS 导航栈与原生导航栈状态不一致，副本上 `pushPath` 触发原生空指针崩溃（`JSNavPathStack::OnStateChanged()` SIGSEGV），表现为"进详情页必崩"。改为普通成员变量后真机复现验证通过（首页→列表→详情→确认→生成任务→任务列表 全链路存活） | 已授权（Lycorius03, 2026-08-27，用户指示"把闪退的事给解决了"）+ 已实现 + 已真机验证 |
| 5 | `entry/src/main/ets/pages/ReportPage.ets` | 隐患上报页从占位空壳改为可提交表单：新增隐患类型 Select、发生地点 TextInput、隐患描述 TextArea、上报人 TextInput（选填），"提交隐患"按钮由无 `onClick` 的静态按钮改为绑定 `EventWorkflowService.reportHazard(...)`。必填项（地点/描述）为空时 toast 提示；提交成功后 toast 反馈事件编号并清空表单。纯前端交互 + 调用 C 新增数据层入口，未引入新依赖 | 用户报告"提交隐患"按钮点击无反应，定位为功能未实现（按钮无 `onClick`）。用户拍板"C 补数据层+授权改页面（推荐）"：数据层 `reportHazard` 属 C 职责，页面表单属 B | 已授权（Lycorius03, 2026-08-27，AskUserQuestion 选择"C 补数据层+授权改页面（推荐）"）+ 已实现（单测随本任务构建验证） |
| 6 | `entry/src/main/ets/pages/ReportPage.ets` | 提交隐患时 `title` 由硬编码 `'隐患上报'` 改为 `EventWorkflowService.buildSummaryTitle(description)` 派生（描述摘要前15字+省略号）。配套 C 数据层：`buildSummaryTitle` 折叠换行、按码点截取；`reportHazard` 增加兜底——调用方仍传占位标题时自动用描述摘要替换，避免列表全部显示"隐患上报"。提交动作/字段/交互零改动 | 用户报告安全事件列表中事件标题显示为占位词"隐患上报"而非真实标题。根因：ReportPage 提交时硬编码 `title: '隐患上报'`，且 reportHazard 未对占位标题兜底 | 已授权（Lycorius03, 2026-08-27，用户明确"C 负责这个问题"）+ 已实现 + 已端侧验证（模拟器提交隐患，hilog 实锤落库 `title=操场西侧路灯灯罩脱落电线裸露下…`，不再为"隐患上报"） |

> 对齐提示（给 A/B）：M4 追加 3 处页面改动（① EventPage.ets 替换 `pageStack` 传递方式；② ReportPage.ets 从占位空壳补全为隐患上报表单；③ ReportPage.ets 提交 title 改为描述摘要派生）。三处均已在本表登记，A/B 联调时如需沿用请同步最新代码。EventService 对外接口签名不变；数据层仅新增 `EventSimulator.generateEventId/formatReportTime` 公开方法、`EventWorkflowService.reportHazard`、`EventWorkflowService.buildSummaryTitle`（只增不改，不影响既有调用）。

---

## 待对齐事项

- **【待 A/B 处理】数据统计界面全 0**：用户报告"数据统计界面的数据统计全都是 0"。已定位：`StatisticsPage.ets`（A/B 页面）当前为纯静态写死 0，未接真实统计数据。这属 A/B UI 职责（统计展示属 A 管理端/B 端），C 不越界处理，仅登记提醒。若 A/B 需要统计数据来源，C 可提供事件/任务数量、按类型/状态聚合的 Repository 查询接口支持。状态：待 A/B 确认，2026-08-27 登记。

---

## 已归档条目

- M1（feature/C-event-simulator）：无 A/B 文件改动（仅 C 范围：simulator + test）。2026-08-26 已快进合入 main（2074da1），11 条单测通过。
- M2（feature/C-repository）：上述 M2 表 2 项已实现并合入 main（fe84bdb，2026-08-27），云手机重启恢复验证待 Lycorius03 执行。
