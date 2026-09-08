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
const DB_VERSION: number = 4;

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
      'location TEXT NOT NULL, description TEXT NOT NULL, reporter TEXT NOT NULL, reporterId TEXT, ' +
      'reportTime TEXT NOT NULL, status TEXT NOT NULL, priority TEXT NOT NULL, handler TEXT)'
    );
    await this.rdbStore.executeSql(
      'CREATE TABLE IF NOT EXISTS task (' +
      'id TEXT PRIMARY KEY, eventId TEXT NOT NULL, title TEXT NOT NULL, ' +
      'location TEXT NOT NULL, description TEXT NOT NULL, assignee TEXT NOT NULL, ' +
      'createTime TEXT NOT NULL, status TEXT NOT NULL, result TEXT, completedTime TEXT, ' +
      'submittedTime TEXT, rejectionReason TEXT)'
    );

    const eventColumns: string[] = await this.getTableColumns('security_event');
    if (!eventColumns.includes('reporterId')) {
      await this.rdbStore.executeSql('ALTER TABLE security_event ADD COLUMN reporterId TEXT');
    }

    // v1 的 task 表没有处理结果和完成时间。按实际列状态执行幂等迁移，
    // 兼容已发布旧库，也能安全恢复上次启动时被中断的部分迁移。
    const taskColumns: string[] = await this.getTableColumns('task');
    if (!taskColumns.includes('result')) {
      await this.rdbStore.executeSql('ALTER TABLE task ADD COLUMN result TEXT');
    }
    if (!taskColumns.includes('completedTime')) {
      await this.rdbStore.executeSql('ALTER TABLE task ADD COLUMN completedTime TEXT');
    }
    if (!taskColumns.includes('submittedTime')) {
      await this.rdbStore.executeSql('ALTER TABLE task ADD COLUMN submittedTime TEXT');
    }
    if (!taskColumns.includes('rejectionReason')) {
      await this.rdbStore.executeSql('ALTER TABLE task ADD COLUMN rejectionReason TEXT');
    }
    if (this.rdbStore.version < DB_VERSION) {
      this.rdbStore.version = DB_VERSION;
    }
  }

  private async getTableColumns(tableName: string): Promise<string[]> {
    const resultSet: relationalStore.ResultSet =
      await this.rdbStore.querySql('PRAGMA table_info(' + tableName + ')');
    const columns: string[] = [];
    try {
      const nameColumnIndex: number = resultSet.getColumnIndex('name');
      while (resultSet.goToNextRow()) {
        columns.push(resultSet.getString(nameColumnIndex));
      }
    } finally {
      resultSet.close();
    }
    return columns;
  }

  async loadEvents(): Promise<SecurityEvent[]> {
    const resultSet: relationalStore.ResultSet = await this.rdbStore.querySql('SELECT * FROM security_event');
    const events: SecurityEvent[] = [];
    try {
      while (resultSet.goToNextRow()) {
        events.push(this.rowToEvent(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return events;
  }

  async loadTasks(): Promise<Task[]> {
    const resultSet: relationalStore.ResultSet = await this.rdbStore.querySql('SELECT * FROM task');
    const tasks: Task[] = [];
    try {
      while (resultSet.goToNextRow()) {
        tasks.push(this.rowToTask(resultSet));
      }
    } finally {
      resultSet.close();
    }
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
    const result: string | null = task.result === undefined ? null : task.result;
    const completedTime: string | null = task.completedTime === undefined ? null : task.completedTime;
    const submittedTime: string | null = task.submittedTime === undefined ? null : task.submittedTime;
    const rejectionReason: string | null = task.rejectionReason === undefined ? null : task.rejectionReason;
    const values: ValuesBucket = {
      'id': task.id,
      'eventId': task.eventId,
      'title': task.title,
      'location': task.location,
      'description': task.description,
      'assignee': task.assignee,
      'createTime': task.createTime,
      'status': task.status,
      'result': result,
      'completedTime': completedTime,
      'submittedTime': submittedTime,
      'rejectionReason': rejectionReason
    };
    await this.rdbStore.insert('task', values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  private eventToBucket(event: SecurityEvent): ValuesBucket {
    const handler: string | null = event.handler === undefined ? null : event.handler;
    const reporterId: string | null = event.reporterId === undefined ? null : event.reporterId;
    const bucket: ValuesBucket = {
      'id': event.id,
      'title': event.title,
      'type': event.type,
      'location': event.location,
      'description': event.description,
      'reporter': event.reporter,
      'reporterId': reporterId,
      'reportTime': event.reportTime,
      'status': event.status,
      'priority': event.priority,
      'handler': handler
    };
    return bucket;
  }

  private rowToEvent(resultSet: relationalStore.ResultSet): SecurityEvent {
    const handlerValue: string = resultSet.getString(resultSet.getColumnIndex('handler'));
    const reporterIdValue: string = resultSet.getString(resultSet.getColumnIndex('reporterId'));
    const event: SecurityEvent = {
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      title: resultSet.getString(resultSet.getColumnIndex('title')),
      type: resultSet.getString(resultSet.getColumnIndex('type')) as EventType,
      location: resultSet.getString(resultSet.getColumnIndex('location')),
      description: resultSet.getString(resultSet.getColumnIndex('description')),
      reporter: resultSet.getString(resultSet.getColumnIndex('reporter')),
      reporterId: reporterIdValue === '' ? undefined : reporterIdValue,
      reportTime: resultSet.getString(resultSet.getColumnIndex('reportTime')),
      status: resultSet.getString(resultSet.getColumnIndex('status')) as EventStatus,
      priority: resultSet.getString(resultSet.getColumnIndex('priority')) as EventPriority,
      handler: handlerValue === '' ? undefined : handlerValue
    };
    return event;
  }

  private rowToTask(resultSet: relationalStore.ResultSet): Task {
    const resultValue: string = resultSet.getString(resultSet.getColumnIndex('result'));
    const completedTimeValue: string = resultSet.getString(resultSet.getColumnIndex('completedTime'));
    const submittedTimeValue: string = resultSet.getString(resultSet.getColumnIndex('submittedTime'));
    const rejectionReasonValue: string = resultSet.getString(resultSet.getColumnIndex('rejectionReason'));
    const task: Task = {
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      eventId: resultSet.getString(resultSet.getColumnIndex('eventId')),
      title: resultSet.getString(resultSet.getColumnIndex('title')),
      location: resultSet.getString(resultSet.getColumnIndex('location')),
      description: resultSet.getString(resultSet.getColumnIndex('description')),
      assignee: resultSet.getString(resultSet.getColumnIndex('assignee')),
      createTime: resultSet.getString(resultSet.getColumnIndex('createTime')),
      status: resultSet.getString(resultSet.getColumnIndex('status')) as TaskStatus,
      result: resultValue === '' ? undefined : resultValue,
      completedTime: completedTimeValue === '' ? undefined : completedTimeValue,
      submittedTime: submittedTimeValue === '' ? undefined : submittedTimeValue,
      rejectionReason: rejectionReasonValue === '' ? undefined : rejectionReasonValue
    };
    return task;
  }
}
