import { SecurityEvent } from '../../model/SecurityEvent';
import { Task } from '../../model/Task';

/**
 * 存储抽象接口（C 模块）
 *
 * 持久化后端统一入口：本地单测用 MemoryEventStore，
 * 真机/云手机用 RdbEventStore（relationalStore）。
 */
export interface EventStore {
  loadEvents(): Promise<SecurityEvent[]>;
  loadTasks(): Promise<Task[]>;
  saveEvent(event: SecurityEvent): Promise<void>;
  updateEvent(event: SecurityEvent): Promise<void>;
  deleteEvent(id: string): Promise<void>;
  saveTask(task: Task): Promise<void>;
}
