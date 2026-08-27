import { SecurityEvent } from '../model/SecurityEvent';
import { Task } from '../model/Task';
import { EventStore } from './store/EventStore';

/**
 * 数据访问层（C 模块）
 *
 * 同步缓存 + 异步写穿：读取走内存缓存（页面同步接口），
 * 写入同步更新缓存并通过 EventStore 异步持久化。
 */
export class EventRepository {
  private static instance: EventRepository | null = null;

  private store: EventStore | null = null;
  private events: SecurityEvent[] = [];
  private tasks: Task[] = [];
  private seeded: boolean = false;
  private loaded: boolean = false;

  static getInstance(): EventRepository {
    if (EventRepository.instance === null) {
      EventRepository.instance = new EventRepository();
    }
    return EventRepository.instance;
  }

  /**
   * 测试注入：用指定 store 重置单例，保证用例间隔离。
   */
  static initForTest(store: EventStore): EventRepository {
    const repository: EventRepository = new EventRepository();
    repository.store = store;
    repository.loaded = true;
    EventRepository.instance = repository;
    return repository;
  }

  setStore(store: EventStore): void {
    this.store = store;
  }

  isLoaded(): boolean {
    return this.loaded;
  }

  /**
   * 从持久化后端加载全部数据到缓存（应用启动时调用一次）。
   */
  async load(): Promise<void> {
    if (this.store === null) {
      return;
    }
    this.events = await this.store.loadEvents();
    this.tasks = await this.store.loadTasks();
    this.loaded = true;
  }

  /**
   * 空库播种（幂等）：仅第一次且缓存为空时写入种子。
   * 内部先克隆种子对象，避免调用方种子模板被缓存引用后同址修改。
   */
  seedIfEmpty(seedEvents: SecurityEvent[]): void {
    if (this.seeded) {
      return;
    }
    this.seeded = true;
    if (this.events.length === 0) {
      const clones: SecurityEvent[] = seedEvents.map((seed: SecurityEvent): SecurityEvent => {
        const clone: SecurityEvent = {
          id: seed.id,
          title: seed.title,
          type: seed.type,
          location: seed.location,
          description: seed.description,
          reporter: seed.reporter,
          reportTime: seed.reportTime,
          status: seed.status,
          priority: seed.priority,
          handler: seed.handler
        };
        return clone;
      });
      this.saveEvents(clones);
    }
  }

  getEvents(): SecurityEvent[] {
    return this.events;
  }

  getEventById(id: string): SecurityEvent | undefined {
    return this.events.find((event: SecurityEvent) => event.id === id);
  }

  saveEvent(event: SecurityEvent): void {
    const index: number = this.events.findIndex((item: SecurityEvent) => item.id === event.id);
    if (index >= 0) {
      this.events[index] = event;
    } else {
      this.events.push(event);
    }
    if (this.store !== null) {
      this.store.saveEvent(event).catch((err: Error) => {
        console.error('EventRepository.saveEvent failed: ' + err.message);
      });
    }
  }

  saveEvents(events: SecurityEvent[]): void {
    events.forEach((event: SecurityEvent) => {
      this.saveEvent(event);
    });
  }

  updateEvent(event: SecurityEvent): void {
    const index: number = this.events.findIndex((item: SecurityEvent) => item.id === event.id);
    if (index >= 0) {
      this.events[index] = event;
      if (this.store !== null) {
        this.store.updateEvent(event).catch((err: Error) => {
          console.error('EventRepository.updateEvent failed: ' + err.message);
        });
      }
    } else {
      this.saveEvent(event);
    }
  }

  deleteEvent(id: string): void {
    this.events = this.events.filter((event: SecurityEvent) => event.id !== id);
    if (this.store !== null) {
      this.store.deleteEvent(id).catch((err: Error) => {
        console.error('EventRepository.deleteEvent failed: ' + err.message);
      });
    }
  }

  getAllTasks(): Task[] {
    return this.tasks;
  }

  getTaskByEventId(eventId: string): Task | undefined {
    return this.tasks.find((task: Task) => task.eventId === eventId);
  }

  saveTask(task: Task): void {
    const index: number = this.tasks.findIndex((item: Task) => item.id === task.id);
    if (index >= 0) {
      this.tasks[index] = task;
    } else {
      this.tasks.push(task);
    }
    if (this.store !== null) {
      this.store.saveTask(task).catch((err: Error) => {
        console.error('EventRepository.saveTask failed: ' + err.message);
      });
    }
  }
}
