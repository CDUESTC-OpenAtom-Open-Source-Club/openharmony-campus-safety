import {
  SecurityEvent,
  EventStatus,
  OperationRecord
} from '../model/SecurityEvent';

import {
  Task,
  TaskStatus
} from '../model/Task';

import { EventRepository } from '../repository/EventRepository';
import { AccountService } from './AccountService';
import { AppPermission, PermissionService } from './PermissionService';
import { User, UserRole } from '../model/User';

export class EventService {
  private static selectedEventId: string = '';

  // 上架版本保持纯净空状态，不预置任何演示案例
  private static seedEvents: SecurityEvent[] = [];

  static getAllEvents(): SecurityEvent[] {
    EventService.ensureSeeded();
    const repository: EventRepository = EventRepository.getInstance();
    const currentUser: User | null = AccountService.getCurrentUser();
    if (currentUser === null) {
      return [];
    }
    if (currentUser.role === UserRole.ADMIN) {
      return repository.getEvents();
    }
    if (currentUser.role === UserRole.SECURITY) {
      const assignedEventIds: string[] = repository.getAllTasks()
        .filter((task: Task) => task.assignee === currentUser.id)
        .map((task: Task) => task.eventId);
      return repository.getEvents().filter(
        (event: SecurityEvent) => assignedEventIds.includes(event.id)
      );
    }
    return repository.getEvents().filter(
      (event: SecurityEvent) => event.reporterId === currentUser.id
    );
  }

  static getPendingEvents(): SecurityEvent[] {
    if (!PermissionService.can(AccountService.getCurrentUser(), AppPermission.CONFIRM_EVENT)) {
      return [];
    }
    EventService.ensureSeeded();
    return EventRepository.getInstance().getEvents().filter(
      (event: SecurityEvent) => event.status === EventStatus.PENDING
    );
  }

  static getEventById(id: string): SecurityEvent | undefined {
    EventService.ensureSeeded();
    const repository: EventRepository = EventRepository.getInstance();
    const event: SecurityEvent | undefined = repository.getEventById(id);
    const currentUser: User | null = AccountService.getCurrentUser();
    if (event === undefined || currentUser === null) {
      return undefined;
    }
    if (currentUser.role === UserRole.ADMIN) {
      return event;
    }
    if (currentUser.role === UserRole.SECURITY) {
      const task: Task | undefined = repository.getTaskByEventId(id);
      return task !== undefined && task.assignee === currentUser.id ? event : undefined;
    }
    return event.reporterId === currentUser.id ? event : undefined;
  }

  static getCompletionFeedback(eventId: string): string {
    const event: SecurityEvent | undefined = EventService.getEventById(eventId);
    if (event === undefined || event.status !== EventStatus.COMPLETED) {
      return '';
    }
    const task: Task | undefined = EventRepository.getInstance().getTaskByEventId(eventId);
    if (task === undefined || task.status !== TaskStatus.COMPLETED || task.result === undefined) {
      return '';
    }
    return task.result;
  }

  static setSelectedEventId(id: string): void {
    EventService.selectedEventId = id;
  }

  static getSelectedEventId(): string {
    return EventService.selectedEventId;
  }

  static confirmEvent(id: string): boolean {
    if (!PermissionService.can(AccountService.getCurrentUser(), AppPermission.CONFIRM_EVENT)) {
      return false;
    }
    const event = EventService.getEventById(id);

    if (event === undefined || event.status !== EventStatus.PENDING) {
      return false;
    }
    event.status = EventStatus.CONFIRMED;
    EventService.appendHistory(event, '确认事件', EventStatus.PENDING, EventStatus.CONFIRMED);
    EventRepository.getInstance().updateEvent(event);
    return true;
  }

  static createTaskFromEvent(id: string, assignee: string = 'inspector_001'): boolean {
    if (!PermissionService.can(AccountService.getCurrentUser(), AppPermission.DISPATCH_TASK)) {
      return false;
    }
    const event = EventService.getEventById(id);

    const normalizedAssignee: string = assignee.trim();
    const isSecurityAccount: boolean = AccountService.getSecurityUsers().some(
      (user: User) => user.id === normalizedAssignee
    );
    if (event === undefined || event.status !== EventStatus.CONFIRMED || !isSecurityAccount) {
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
      assignee: normalizedAssignee,
      createTime: event.reportTime,
      status: TaskStatus.PENDING
    };

    EventRepository.getInstance().saveTask(newTask);
    event.handler = newTask.assignee;
    const assigneeUser: User | undefined = AccountService.getSecurityUsers().find(
      (user: User) => user.id === newTask.assignee
    );
    EventService.appendHistory(event, '指派处置任务', EventStatus.CONFIRMED, EventStatus.CONFIRMED,
      '负责人：' + (assigneeUser === undefined ? newTask.assignee : assigneeUser.name));
    EventRepository.getInstance().updateEvent(event);
    return true;
  }

  static getAllTasks(): Task[] {
    const tasks: Task[] = EventRepository.getInstance().getAllTasks();
    const currentUser: User | null = AccountService.getCurrentUser();
    if (currentUser === null) {
      return [];
    }
    if (currentUser.role === UserRole.ADMIN) {
      return tasks;
    }
    if (currentUser.role === UserRole.SECURITY) {
      return tasks.filter((task: Task) => task.assignee === currentUser.id);
    }
    return [];
  }
  static getMyTaskList(userId: string): Task[] {
    return EventRepository.getInstance().getAllTasks().filter((task: Task) => task.assignee === userId);
  }

  static getTaskByEventId(eventId: string): Task | undefined {
    const task: Task | undefined = EventRepository.getInstance().getTaskByEventId(eventId);
    if (task === undefined) {
      return undefined;
    }
    return EventService.getAllTasks().find((visibleTask: Task) => visibleTask.id === task.id);
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
    const currentUser: User | null = AccountService.getCurrentUser();
    if (!PermissionService.can(currentUser, AppPermission.START_TASK)) {
      return false;
    }
    const repository = EventRepository.getInstance();
    const task: Task | undefined = repository.getAllTasks().find((item: Task) => item.id === taskId);
    if (task === undefined || task.status !== TaskStatus.PENDING ||
      (currentUser?.role !== UserRole.ADMIN && task.assignee !== currentUser?.id)) {
      return false;
    }
    task.status = TaskStatus.PROCESSING;
    repository.saveTask(task);
    const event: SecurityEvent | undefined = repository.getEventById(task.eventId);
    if (event !== undefined &&
      (event.status === EventStatus.CONFIRMED || event.status === EventStatus.PENDING)) {
      event.status = EventStatus.PROCESSING;
      EventService.appendHistory(event, '接单并开始处置', EventStatus.CONFIRMED, EventStatus.PROCESSING);
      repository.updateEvent(event);
    }
    return true;
  }

  static submitTaskForReview(taskId: string, result: string): boolean {
    const currentUser: User | null = AccountService.getCurrentUser();
    if (!PermissionService.can(currentUser, AppPermission.SUBMIT_TASK)) {
      return false;
    }
    const repository = EventRepository.getInstance();
    const task: Task | undefined = repository.getAllTasks().find((item: Task) => item.id === taskId);
    const trimmedResult: string = result.trim();
    if (task === undefined || task.status !== TaskStatus.PROCESSING || trimmedResult === '' ||
      (currentUser?.role !== UserRole.ADMIN && task.assignee !== currentUser?.id)) {
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
      EventService.appendHistory(event, '提交处置结果', EventStatus.PROCESSING, EventStatus.REVIEW, trimmedResult);
      repository.updateEvent(event);
    }
    return true;
  }

  static approveTask(taskId: string): boolean {
    if (!PermissionService.can(AccountService.getCurrentUser(), AppPermission.REVIEW_TASK)) {
      return false;
    }
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
      EventService.appendHistory(event, '审核通过', EventStatus.REVIEW, EventStatus.COMPLETED);
      repository.updateEvent(event);
    }
    return true;
  }

  static rejectTask(taskId: string, reason: string): boolean {
    if (!PermissionService.can(AccountService.getCurrentUser(), AppPermission.REVIEW_TASK)) {
      return false;
    }
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
      EventService.appendHistory(event, '驳回返工', EventStatus.REVIEW, EventStatus.PROCESSING, trimmedReason);
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

  private static appendHistory(event: SecurityEvent, action: string, fromStatus: EventStatus,
    toStatus: EventStatus, note?: string): void {
    const currentUser: User | null = AccountService.getCurrentUser();
    const record: OperationRecord = {
      id: 'AUDIT-' + Date.now().toString() + '-' + ((event.history ?? []).length + 1).toString(),
      eventId: event.id,
      operatorId: currentUser === null ? '' : currentUser.id,
      operatorName: currentUser === null ? '本地用户' : currentUser.name,
      action: action,
      operationTime: EventService.getCurrentTime(),
      fromStatus: fromStatus,
      toStatus: toStatus,
      note: note
    };
    event.history = (event.history ?? []).concat([record]);
  }

  private static ensureSeeded(): void {
    EventRepository.getInstance().seedIfEmpty(EventService.seedEvents);
  }
}
