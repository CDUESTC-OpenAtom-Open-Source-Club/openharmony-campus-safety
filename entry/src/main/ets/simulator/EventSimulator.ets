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
