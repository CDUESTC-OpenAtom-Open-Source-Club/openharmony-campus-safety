import { describe, it, beforeEach, expect } from '@ohos/hypium';

import {
  SecurityEvent,
  EventStatus,
  EventPriority,
  EventType
} from '../main/ets/model/SecurityEvent';

import {
  Task,
  TaskStatus
} from '../main/ets/model/Task';

import { MemoryEventStore } from '../main/ets/repository/store/MemoryEventStore';

function buildEvent(id: string): SecurityEvent {
  return {
    id: id,
    title: '烟雾异常',
    type: EventType.FIRE,
    location: '教学楼3层走廊',
    description: '消防监测区域发现异常烟雾',
    reporter: '系统模拟',
    reportTime: '2026-08-26 10:00',
    status: EventStatus.PENDING,
    priority: EventPriority.HIGH
  };
}

function buildTask(id: string, eventId: string): Task {
  return {
    id: id,
    eventId: eventId,
    title: '烟雾异常处置',
    location: '教学楼3层走廊',
    description: '消防监测区域发现异常烟雾',
    assignee: '待分配',
    createTime: '2026-08-26 10:00',
    status: TaskStatus.PENDING
  };
}

export default function eventRepositoryTest() {
  describe('EventRepositoryTest', () => {
    beforeEach(() => {
    });

    it('memory_store_save_and_load_events', 0, async () => {
      const store = new MemoryEventStore();
      await store.saveEvent(buildEvent('E1'));
      await store.saveEvent(buildEvent('E2'));
      const events: SecurityEvent[] = await store.loadEvents();
      expect(events.length).assertEqual(2);
      expect(events[0].id).assertEqual('E1');
    });

    it('memory_store_delete_event', 0, async () => {
      const store = new MemoryEventStore();
      await store.saveEvent(buildEvent('E1'));
      await store.deleteEvent('E1');
      const events: SecurityEvent[] = await store.loadEvents();
      expect(events.length).assertEqual(0);
    });

    it('memory_store_save_and_load_tasks', 0, async () => {
      const store = new MemoryEventStore();
      await store.saveTask(buildTask('TASK001', 'E1'));
      const tasks: Task[] = await store.loadTasks();
      expect(tasks.length).assertEqual(1);
      expect(tasks[0].eventId).assertEqual('E1');
    });
  });
}
