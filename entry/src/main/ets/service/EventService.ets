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
      assignee: 'inspector_001',
      createTime: event.reportTime,
      status: TaskStatus.PENDING
    };

    EventRepository.getInstance().saveTask(newTask);
  }

  static getAllTasks(): Task[] {
    return EventRepository.getInstance().getAllTasks();
  }
  static getMyTaskList(userId: string): Task[] {
    return EventRepository.getInstance().getAllTasks().filter((task: Task) => task.assignee === userId);
  }

  static updateTaskStatus(taskId: string, status: TaskStatus, result?: string): void {
    const tasks = EventRepository.getInstance().getAllTasks();
    const task = tasks.find((t: Task) => t.id === taskId);
    if (task !== undefined) {
      task.status = status;
      EventRepository.getInstance().saveTask(task);
    }
  }

  private static ensureSeeded(): void {
    EventRepository.getInstance().seedIfEmpty(EventService.seedEvents);
  }
}
