import { SecurityEvent } from '../../model/SecurityEvent';
import { Task } from '../../model/Task';
import { EventStore } from './EventStore';

/**
 * 内存版存储实现：供本地单元测试注入，
 * 不依赖任何系统 API，Node 环境可运行。
 */
export class MemoryEventStore implements EventStore {
  private events: SecurityEvent[] = [];
  private tasks: Task[] = [];

  async loadEvents(): Promise<SecurityEvent[]> {
    return this.events;
  }

  async loadTasks(): Promise<Task[]> {
    return this.tasks;
  }

  async saveEvent(event: SecurityEvent): Promise<void> {
    const index: number = this.events.findIndex((item: SecurityEvent) => item.id === event.id);
    if (index >= 0) {
      this.events[index] = event;
    } else {
      this.events.push(event);
    }
  }

  async updateEvent(event: SecurityEvent): Promise<void> {
    const index: number = this.events.findIndex((item: SecurityEvent) => item.id === event.id);
    if (index >= 0) {
      this.events[index] = event;
    } else {
      this.events.push(event);
    }
  }

  async deleteEvent(id: string): Promise<void> {
    this.events = this.events.filter((item: SecurityEvent) => item.id !== id);
  }

  async saveTask(task: Task): Promise<void> {
    const index: number = this.tasks.findIndex((item: Task) => item.id === task.id);
    if (index >= 0) {
      this.tasks[index] = task;
    } else {
      this.tasks.push(task);
    }
  }
}
