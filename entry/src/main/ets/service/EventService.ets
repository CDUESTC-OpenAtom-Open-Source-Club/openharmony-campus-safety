import {
  SecurityEvent,
  EventStatus
} from '../model/SecurityEvent';

import {
  Task,
  TaskStatus
} from '../model/Task';

import { EventRepository } from '../repository/EventRepository';

export class EventService {
  private static selectedEventId: string = '';

  // 上架版本保持纯净空状态，不预置任何演示案例
  private static seedEvents: SecurityEvent[] = [];

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

  static confirmEvent(id: string): boolean {
    const event = EventService.getEventById(id);

    if (event === undefined || event.status !== EventStatus.PENDING) {
      return false;
    }
    event.status = EventStatus.CONFIRMED;
    EventRepository.getInstance().updateEvent(event);
    return true;
  }

  static createTaskFromEvent(id: string, assignee: string = 'inspector_001'): boolean {
    const event = EventService.getEventById(id);

    if (event === undefined || event.status !== EventStatus.CONFIRMED || assignee.trim() === '') {
      return false;
    }

    const existingTask = EventRepository.getInstance().getTaskByEventId(id);

    if (existingTask !== undefined) {
      return false;
    }

    const newTask: Task = {
      id: 'TASK-' + event.id,
      eventId: event.id,
      title: event.title,
      location: event.location,
      description: event.description,
      assignee: assignee.trim(),
      createTime: event.reportTime,
      status: TaskStatus.PENDING
    };

    EventRepository.getInstance().saveTask(newTask);
    event.handler = newTask.assignee;
    EventRepository.getInstance().updateEvent(event);
    return true;
  }

  static getAllTasks(): Task[] {
    return EventRepository.getInstance().getAllTasks();
  }
  static getMyTaskList(userId: string): Task[] {
    return EventRepository.getInstance().getAllTasks().filter((task: Task) => task.assignee === userId);
  }

  static updateTaskStatus(taskId: string, status: TaskStatus, result?: string): boolean {
    if (status === TaskStatus.PROCESSING) {
      return EventService.startTask(taskId);
    }
    if (status === TaskStatus.REVIEW || status === TaskStatus.COMPLETED) {
      return EventService.submitTaskForReview(taskId, result === undefined ? '' : result);
    }
    return false;
  }

  static startTask(taskId: string): boolean {
    const repository = EventRepository.getInstance();
    const task: Task | undefined = repository.getAllTasks().find((item: Task) => item.id === taskId);
    if (task === undefined || task.status !== TaskStatus.PENDING) {
      return false;
    }
    task.status = TaskStatus.PROCESSING;
    repository.saveTask(task);
    const event: SecurityEvent | undefined = repository.getEventById(task.eventId);
    if (event !== undefined &&
      (event.status === EventStatus.CONFIRMED || event.status === EventStatus.PENDING)) {
      event.status = EventStatus.PROCESSING;
      repository.updateEvent(event);
    }
    return true;
  }

  static submitTaskForReview(taskId: string, result: string): boolean {
    const repository = EventRepository.getInstance();
    const task: Task | undefined = repository.getAllTasks().find((item: Task) => item.id === taskId);
    const trimmedResult: string = result.trim();
    if (task === undefined || task.status !== TaskStatus.PROCESSING || trimmedResult === '') {
      return false;
    }
    task.status = TaskStatus.REVIEW;
    task.result = trimmedResult;
    task.submittedTime = EventService.getCurrentTime();
    task.rejectionReason = undefined;
    repository.saveTask(task);
    const event: SecurityEvent | undefined = repository.getEventById(task.eventId);
    if (event !== undefined && event.status === EventStatus.PROCESSING) {
      event.status = EventStatus.REVIEW;
      repository.updateEvent(event);
    }
    return true;
  }

  static approveTask(taskId: string): boolean {
    const repository = EventRepository.getInstance();
    const task: Task | undefined = repository.getAllTasks().find((item: Task) => item.id === taskId);
    if (task === undefined || task.status !== TaskStatus.REVIEW) {
      return false;
    }
    task.status = TaskStatus.COMPLETED;
    task.completedTime = EventService.getCurrentTime();
    repository.saveTask(task);
    const event: SecurityEvent | undefined = repository.getEventById(task.eventId);
    if (event !== undefined && event.status === EventStatus.REVIEW) {
      event.status = EventStatus.COMPLETED;
      repository.updateEvent(event);
    }
    return true;
  }

  static rejectTask(taskId: string, reason: string): boolean {
    const repository = EventRepository.getInstance();
    const task: Task | undefined = repository.getAllTasks().find((item: Task) => item.id === taskId);
    const trimmedReason: string = reason.trim();
    if (task === undefined || task.status !== TaskStatus.REVIEW || trimmedReason === '') {
      return false;
    }
    task.status = TaskStatus.PROCESSING;
    task.rejectionReason = trimmedReason;
    task.completedTime = undefined;
    repository.saveTask(task);
    const event: SecurityEvent | undefined = repository.getEventById(task.eventId);
    if (event !== undefined && event.status === EventStatus.REVIEW) {
      event.status = EventStatus.PROCESSING;
      repository.updateEvent(event);
    }
    return true;
  }

  private static getCurrentTime(): string {
    const now = new Date();

    const year = now.getFullYear();
    const month = (now.getMonth() + 1).toString().padStart(2, '0');
    const day = now.getDate().toString().padStart(2, '0');

    const hour = now.getHours().toString().padStart(2, '0');
    const minute = now.getMinutes().toString().padStart(2, '0');
    const second = now.getSeconds().toString().padStart(2, '0');

    return year + '-' + month + '-' + day +
      ' ' + hour + ':' + minute + ':' + second;
  }

  private static ensureSeeded(): void {
    EventRepository.getInstance().seedIfEmpty(EventService.seedEvents);
  }
}
