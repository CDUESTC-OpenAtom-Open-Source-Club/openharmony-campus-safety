import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

import {
  SecurityEvent,
  EventStatus,
  EventPriority,
  EventType
} from '../../model/SecurityEvent';
import { Task, TaskStatus } from '../../model/Task';
import { EventStore } from './EventStore';

const DB_NAME: string = 'campus_safety.db';

/**
 * relationalStore 存储实现（C 模块，真机/云手机用）。
 *
 * 事件与任务各一张表，task.eventId 关联 security_event.id。
 */
export class RdbEventStore implements EventStore {
  private rdbStore: relationalStore.RdbStore;

  private constructor(rdbStore: relationalStore.RdbStore) {
    this.rdbStore = rdbStore;
  }

  static async create(context: common.Context): Promise<RdbEventStore> {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const rdbStore: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config);
    const store: RdbEventStore = new RdbEventStore(rdbStore);
    await store.initSchema();
    return store;
  }

  private async initSchema(): Promise<void> {
    await this.rdbStore.executeSql(
      'CREATE TABLE IF NOT EXISTS security_event (' +
      'id TEXT PRIMARY KEY, title TEXT NOT NULL, type TEXT NOT NULL, ' +
      'location TEXT NOT NULL, description TEXT NOT NULL, reporter TEXT NOT NULL, ' +
      'reportTime TEXT NOT NULL, status TEXT NOT NULL, priority TEXT NOT NULL, handler TEXT)'
    );
    await this.rdbStore.executeSql(
      'CREATE TABLE IF NOT EXISTS task (' +
      'id TEXT PRIMARY KEY, eventId TEXT NOT NULL, title TEXT NOT NULL, ' +
      'location TEXT NOT NULL, description TEXT NOT NULL, assignee TEXT NOT NULL, ' +
      'createTime TEXT NOT NULL, status TEXT NOT NULL)'
    );
  }

  async loadEvents(): Promise<SecurityEvent[]> {
    const resultSet: relationalStore.ResultSet = await this.rdbStore.querySql('SELECT * FROM security_event');
    const events: SecurityEvent[] = [];
    while (resultSet.goToNextRow()) {
      events.push(this.rowToEvent(resultSet));
    }
    resultSet.close();
    return events;
  }

  async loadTasks(): Promise<Task[]> {
    const resultSet: relationalStore.ResultSet = await this.rdbStore.querySql('SELECT * FROM task');
    const tasks: Task[] = [];
    while (resultSet.goToNextRow()) {
      tasks.push(this.rowToTask(resultSet));
    }
    resultSet.close();
    return tasks;
  }

  async saveEvent(event: SecurityEvent): Promise<void> {
    await this.rdbStore.insert(
      'security_event',
      this.eventToBucket(event),
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
    );
  }

  async updateEvent(event: SecurityEvent): Promise<void> {
    const predicates: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates('security_event').equalTo('id', event.id);
    await this.rdbStore.update(this.eventToBucket(event), predicates);
  }

  async deleteEvent(id: string): Promise<void> {
    const predicates: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates('security_event').equalTo('id', id);
    await this.rdbStore.delete(predicates);
  }

  async saveTask(task: Task): Promise<void> {
    const values: ValuesBucket = {
      'id': task.id,
      'eventId': task.eventId,
      'title': task.title,
      'location': task.location,
      'description': task.description,
      'assignee': task.assignee,
      'createTime': task.createTime,
      'status': task.status
    };
    await this.rdbStore.insert('task', values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  private eventToBucket(event: SecurityEvent): ValuesBucket {
    const handler: string | null = event.handler === undefined ? null : event.handler;
    const bucket: ValuesBucket = {
      'id': event.id,
      'title': event.title,
      'type': event.type,
      'location': event.location,
      'description': event.description,
      'reporter': event.reporter,
      'reportTime': event.reportTime,
      'status': event.status,
      'priority': event.priority,
      'handler': handler
    };
    return bucket;
  }

  private rowToEvent(resultSet: relationalStore.ResultSet): SecurityEvent {
    const handlerValue: string = resultSet.getString(resultSet.getColumnIndex('handler'));
    const event: SecurityEvent = {
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      title: resultSet.getString(resultSet.getColumnIndex('title')),
      type: resultSet.getString(resultSet.getColumnIndex('type')) as EventType,
      location: resultSet.getString(resultSet.getColumnIndex('location')),
      description: resultSet.getString(resultSet.getColumnIndex('description')),
      reporter: resultSet.getString(resultSet.getColumnIndex('reporter')),
      reportTime: resultSet.getString(resultSet.getColumnIndex('reportTime')),
      status: resultSet.getString(resultSet.getColumnIndex('status')) as EventStatus,
      priority: resultSet.getString(resultSet.getColumnIndex('priority')) as EventPriority,
      handler: handlerValue === '' ? undefined : handlerValue
    };
    return event;
  }

  private rowToTask(resultSet: relationalStore.ResultSet): Task {
    const task: Task = {
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      eventId: resultSet.getString(resultSet.getColumnIndex('eventId')),
      title: resultSet.getString(resultSet.getColumnIndex('title')),
      location: resultSet.getString(resultSet.getColumnIndex('location')),
      description: resultSet.getString(resultSet.getColumnIndex('description')),
      assignee: resultSet.getString(resultSet.getColumnIndex('assignee')),
      createTime: resultSet.getString(resultSet.getColumnIndex('createTime')),
      status: resultSet.getString(resultSet.getColumnIndex('status')) as TaskStatus
    };
    return task;
  }
}
