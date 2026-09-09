import { SecurityEvent, EventStatus, EventType } from '../model/SecurityEvent';
import { Task, TaskStatus } from '../model/Task';

export interface SafetyStatisticsSnapshot {
  totalEvents: number;
  pendingEvents: number;
  confirmedEvents: number;
  processingEvents: number;
  reviewEvents: number;
  completedEvents: number;
  overdueTasks: number;
  averageFirstResponseMinutes: number | null;
  averageHandlingMinutes: number | null;
  onTimeCompletionRate: number | null;
}

/** 仅基于本地事件和任务生命周期计算的统计，不填充演示指标。 */
export class SafetyStatisticsService {
  static createSnapshot(events: SecurityEvent[], tasks: Task[]): SafetyStatisticsSnapshot {
    const completedTasks: Task[] = tasks.filter((task: Task) => task.status === TaskStatus.COMPLETED);
    const responseMinutes: number[] = [];
    const handlingMinutes: number[] = [];
    let onTimeCount: number = 0;

    tasks.forEach((task: Task) => {
      const event: SecurityEvent | undefined = events.find((item: SecurityEvent) => item.id === task.eventId);
      const acceptedAt: number = SafetyStatisticsService.parseTime(task.acceptedTime);
      const completedAt: number = SafetyStatisticsService.parseTime(task.completedTime);
      const reportedAt: number = event === undefined ? 0 : SafetyStatisticsService.parseTime(event.reportTime);
      if (reportedAt > 0 && acceptedAt > reportedAt) {
        responseMinutes.push(Math.round((acceptedAt - reportedAt) / 60000));
      }
      if (acceptedAt > 0 && completedAt > acceptedAt) {
        handlingMinutes.push(Math.round((completedAt - acceptedAt) / 60000));
      }
      const deadlineAt: number = SafetyStatisticsService.parseTime(task.deadline);
      if (completedAt > 0 && deadlineAt > 0 && completedAt <= deadlineAt) {
        onTimeCount++;
      }
    });

    const completedWithDeadline: number = completedTasks.filter((task: Task) =>
      SafetyStatisticsService.parseTime(task.deadline) > 0 && SafetyStatisticsService.parseTime(task.completedTime) > 0
    ).length;
    return {
      totalEvents: events.length,
      pendingEvents: SafetyStatisticsService.countByStatus(events, EventStatus.PENDING),
      confirmedEvents: SafetyStatisticsService.countByStatus(events, EventStatus.CONFIRMED),
      processingEvents: SafetyStatisticsService.countByStatus(events, EventStatus.PROCESSING),
      reviewEvents: SafetyStatisticsService.countByStatus(events, EventStatus.REVIEW),
      completedEvents: SafetyStatisticsService.countByStatus(events, EventStatus.COMPLETED),
      overdueTasks: tasks.filter((task: Task) => SafetyStatisticsService.isOverdue(task)).length,
      averageFirstResponseMinutes: SafetyStatisticsService.average(responseMinutes),
      averageHandlingMinutes: SafetyStatisticsService.average(handlingMinutes),
      onTimeCompletionRate: completedWithDeadline === 0 ? null : Math.round(onTimeCount / completedWithDeadline * 100)
    };
  }

  static getTypeCompletionRate(events: SecurityEvent[], type: EventType): number | null {
    const items: SecurityEvent[] = events.filter((event: SecurityEvent) => event.type === type);
    if (items.length === 0) {
      return null;
    }
    const completed: number = items.filter((event: SecurityEvent) => event.status === EventStatus.COMPLETED).length;
    return Math.round(completed / items.length * 100);
  }

  static formatMinutes(minutes: number | null): string {
    return minutes === null ? '不适用' : minutes.toString() + ' 分钟';
  }

  private static countByStatus(events: SecurityEvent[], status: EventStatus): number {
    return events.filter((event: SecurityEvent) => event.status === status).length;
  }

  private static average(values: number[]): number | null {
    if (values.length === 0) {
      return null;
    }
    return Math.round(values.reduce((sum: number, value: number) => sum + value, 0) / values.length);
  }

  private static isOverdue(task: Task): boolean {
    if (task.status === TaskStatus.COMPLETED) {
      return false;
    }
    const deadlineAt: number = SafetyStatisticsService.parseTime(task.deadline);
    return deadlineAt > 0 && deadlineAt < Date.now();
  }

  private static parseTime(value: string | undefined): number {
    if (value === undefined || value === '') {
      return 0;
    }
    const normalized: string = value.replace(' ', 'T');
    const time: number = new Date(normalized).getTime();
    return Number.isNaN(time) ? 0 : time;
  }
}
