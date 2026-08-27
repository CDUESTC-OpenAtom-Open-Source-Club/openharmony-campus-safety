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
    const now: Date = new Date();
    const event: SecurityEvent = {
      id: EventSimulator.generateEventId(),
      title: input.title.trim(),
      type: input.type,
      location: input.location.trim(),
      description: input.description.trim(),
      reporter: input.reporter === undefined || input.reporter.trim() === '' ? '学生上报' : input.reporter.trim(),
      reportTime: EventSimulator.formatReportTime(now),
      status: EventStatus.PENDING,
      priority: input.priority === undefined ? EventPriority.MEDIUM : input.priority
    };
    EventRepository.getInstance().saveEvent(event);
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
