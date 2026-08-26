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

export class EventService {
  private static selectedEventId: string = '';

  private static tasks: Task[] = [];

  private static events: SecurityEvent[] = [
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
    return EventService.events;
  }

  static getPendingEvents(): SecurityEvent[] {
    return EventService.events.filter(
      (event: SecurityEvent) => event.status === EventStatus.PENDING
    );
  }

  static getEventById(id: string): SecurityEvent | undefined {
    return EventService.events.find(
      (event: SecurityEvent) => event.id === id
    );
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
    }
  }

  static createTaskFromEvent(id: string): void {
    const event = EventService.getEventById(id);

    if (event === undefined) {
      return;
    }

    const existingTask = EventService.tasks.find(
      (task: Task) => task.eventId === id
    );

    if (existingTask !== undefined) {
      return;
    }

    const newTask: Task = {
      id: 'TASK' + (EventService.tasks.length + 1).toString().padStart(3, '0'),
      eventId: event.id,
      title: event.title,
      location: event.location,
      description: event.description,
      assignee: '待分配',
      createTime: event.reportTime,
      status: TaskStatus.PENDING
    };

    EventService.tasks.push(newTask);
  }

  static getAllTasks(): Task[] {
    return EventService.tasks;
  }
}