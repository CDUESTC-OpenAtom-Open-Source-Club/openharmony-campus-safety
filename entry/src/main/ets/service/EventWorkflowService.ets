import {
  SecurityEvent,
  EventStatus,
  EventPriority,
  EventType
} from '../model/SecurityEvent';

import { Task, TaskStatus } from '../model/Task';

import { EventSimulator } from '../simulator/EventSimulator';
import { EventRepository } from '../repository/EventRepository';
import { EventService } from './EventService';

import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 学生隐患上报入参。
 * title / location / description 必填；reporter / priority 缺省时自动补默认值。
 */
export interface HazardReport {
  title: string;
  type: EventType;
  location: string;
  description: string;
  reporter?: string;
  priority?: EventPriority;
}

/**
 * 安全事件业务流程编排（C 模块）
 *
 * 把事件模拟、确认、派单、处理、完成串成完整业务闭环，
 * 作为无 UI 场景下的流程入口与 Demo 回归验证的调用对象。
 *
 * 设计原则：业务规则（确认 / 派单 / 状态联动）复用 A 的 EventService，
 * 本服务只做 C 侧的流程衔接，不重复实现业务逻辑。
 */
export class EventWorkflowService {
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'EventWorkflow';
  /** 由描述派生的简短标题最大长度（字），与种子/模拟事件"短短语"风格对齐；超过则补省略号 */
  private static readonly TITLE_MAX_LEN: number = 15;
  /** 历史占位标题：ReportPage 遗留默认值，reportHazard 兜底检测用，禁止散落魔法字符串 */
  private static readonly PLACEHOLDER_TITLE: string = '隐患上报';

  /**
   * 由隐患描述生成简短标题：折叠换行、按 Unicode 码点截取前 TITLE_MAX_LEN 字，超长补省略号；
   * 描述为空时回退占位标题。与种子事件"简短短语"风格一致，供隐患上报页派生 event.title。
   */
  static buildSummaryTitle(description: string): string {
    const trimmed: string = description.trim();
    if (trimmed === '') {
      return EventWorkflowService.PLACEHOLDER_TITLE;
    }
    // 折叠换行/回车为单空格，避免列表标题出现换行错乱（split/join 规避正则，兼容 ArkTS 严格模式）
    const singleLine: string =
      trimmed.split('\r\n').join(' ').split('\r').join(' ').split('\n').join(' ');
    const chars: string[] = Array.from(singleLine);
    if (chars.length <= EventWorkflowService.TITLE_MAX_LEN) {
      return singleLine;
    }
    return chars.slice(0, EventWorkflowService.TITLE_MAX_LEN).join('') + '…';
  }

  /**
   * 学生隐患上报：接收用户填写的隐患信息，生成事件并落库。
   * 对应 C_MODULE_SPEC 数据流：B 表单与交互 → C 数据转换与事件生成 → EventService → Repository。
   *
   * @param input 用户上报的隐患信息（title/location/description 必填，空值返回 undefined）
   * @returns 落库后的 SecurityEvent（status 为 PENDING，等待确认）；必填项缺失时返回 undefined
   */
  static reportHazard(input: HazardReport): SecurityEvent | undefined {
    if (input.title === undefined || input.title.trim() === '' ||
      input.location === undefined || input.location.trim() === '' ||
      input.description === undefined || input.description.trim() === '') {
      return undefined;
    }
    const trimmedTitle: string = input.title.trim();
    // 兜底：调用方仍传历史占位标题时，自动用描述摘要生成真实标题，避免列表全部显示"隐患上报"
    const finalTitle: string = trimmedTitle === EventWorkflowService.PLACEHOLDER_TITLE
      ? EventWorkflowService.buildSummaryTitle(input.description)
      : trimmedTitle;
    const now: Date = new Date();
    const event: SecurityEvent = {
      id: EventSimulator.generateEventId(),
      title: finalTitle,
      type: input.type,
      location: input.location.trim(),
      description: input.description.trim(),
      reporter: input.reporter === undefined || input.reporter.trim() === '' ? '学生上报' : input.reporter.trim(),
      reportTime: EventSimulator.formatReportTime(now),
      status: EventStatus.PENDING,
      priority: input.priority === undefined ? EventPriority.MEDIUM : input.priority
    };
    EventRepository.getInstance().saveEvent(event);
    hilog.info(EventWorkflowService.LOG_DOMAIN, EventWorkflowService.LOG_TAG,
      'reportHazard saved: id=%{public}s title=%{public}s location=%{public}s status=%{public}s',
      event.id, event.title, event.location, event.status);
    return event;
  }

  /**
   * 模拟并入库一个待确认事件（事件列表的新增入口）。
   * @param templateIndex 模板索引 0/1/2；缺省或非法值时随机选择模板
   * @returns 入库后的 SecurityEvent（status 为 PENDING，等待确认）
   */
  static simulateAndEnqueue(templateIndex?: number): SecurityEvent {
    const event: SecurityEvent = EventSimulator.simulateEvent(templateIndex);
    EventRepository.getInstance().saveEvent(event);
    return event;
  }

  /**
   * 批量模拟并入库事件。
   * @param count 生成数量；非正整数或非整数时返回空数组，不写入任何数据
   * @returns 入库后的事件数组
   */
  static simulateAndEnqueueBatch(count: number): SecurityEvent[] {
    const events: SecurityEvent[] = EventSimulator.simulateBatch(count);
    if (events.length === 0) {
      return events;
    }
    EventRepository.getInstance().saveEvents(events);
    return events;
  }

  /**
   * 一键跑通完整业务闭环：模拟入库 → 确认 → 派单 → 处理 → 完成。
   * 供无 UI 场景下的流程演示与 Demo 回归脚本调用。
   * @param templateIndex 模板索引 0/1/2；缺省随机
   * @returns 闭环起始事件（处理后其 status 应为 COMPLETED）
   */
  static runFullWorkflow(templateIndex?: number): SecurityEvent {
    const event: SecurityEvent = EventWorkflowService.simulateAndEnqueue(templateIndex);
    EventService.confirmEvent(event.id);
    EventService.createTaskFromEvent(event.id);
    const task: Task | undefined = EventRepository.getInstance().getTaskByEventId(event.id);
    if (task !== undefined) {
      EventService.updateTaskStatus(task.id, TaskStatus.PROCESSING);
      EventService.updateTaskStatus(task.id, TaskStatus.COMPLETED);
    }
    return event;
  }
}
