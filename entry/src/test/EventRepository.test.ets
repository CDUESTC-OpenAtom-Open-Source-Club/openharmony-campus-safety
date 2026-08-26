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

import { EventRepository } from '../main/ets/repository/EventRepository';

import { EventService } from '../main/ets/service/EventService';

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
      EventRepository.initForTest(new MemoryEventStore());
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

    it('repository_save_event_then_get', 0, () => {
      const repo = EventRepository.getInstance();
      repo.saveEvent(buildEvent('EVT100'));
      expect(repo.getEvents().length).assertEqual(1);
      const found = repo.getEventById('EVT100');
      expect(found === undefined).assertFalse();
      if (found !== undefined) {
        expect(found.title).assertEqual('烟雾异常');
      }
    });

    it('repository_get_event_by_id_undefined_when_absent', 0, () => {
      const repo = EventRepository.getInstance();
      expect(repo.getEventById('NOPE')).assertEqual(undefined);
    });

    it('repository_update_event_changes_fields', 0, () => {
      const repo = EventRepository.getInstance();
      repo.saveEvent(buildEvent('EVT100'));
      const updated: SecurityEvent = buildEvent('EVT100');
      updated.status = EventStatus.CONFIRMED;
      repo.updateEvent(updated);
      const found = repo.getEventById('EVT100');
      expect(found === undefined).assertFalse();
      if (found !== undefined) {
        expect(found.status).assertEqual(EventStatus.CONFIRMED);
      }
    });

    it('repository_delete_event_removes', 0, () => {
      const repo = EventRepository.getInstance();
      repo.saveEvent(buildEvent('EVT100'));
      repo.deleteEvent('EVT100');
      expect(repo.getEvents().length).assertEqual(0);
      expect(repo.getEventById('EVT100')).assertEqual(undefined);
    });

    it('repository_save_events_batch', 0, () => {
      const repo = EventRepository.getInstance();
      repo.saveEvents([buildEvent('E1'), buildEvent('E2'), buildEvent('E3')]);
      expect(repo.getEvents().length).assertEqual(3);
    });

    it('repository_save_task_and_get_by_event_id', 0, () => {
      const repo = EventRepository.getInstance();
      repo.saveTask(buildTask('TASK001', 'EVT100'));
      expect(repo.getAllTasks().length).assertEqual(1);
      const task = repo.getTaskByEventId('EVT100');
      expect(task === undefined).assertFalse();
      if (task !== undefined) {
        expect(task.id).assertEqual('TASK001');
      }
    });

    it('repository_get_task_by_event_id_undefined_when_absent', 0, () => {
      const repo = EventRepository.getInstance();
      expect(repo.getTaskByEventId('NOPE')).assertEqual(undefined);
    });

    it('repository_empty_initial_state', 0, () => {
      const repo = EventRepository.getInstance();
      expect(repo.getEvents().length).assertEqual(0);
      expect(repo.getAllTasks().length).assertEqual(0);
    });

    it('repository_write_through_save_propagates_to_store', 0, async () => {
      const store = new MemoryEventStore();
      EventRepository.initForTest(store);
      const repo = EventRepository.getInstance();
      repo.saveEvent(buildEvent('EVT100'));
      const stored: SecurityEvent[] = await store.loadEvents();
      expect(stored.length).assertEqual(1);
      expect(stored[0].id).assertEqual('EVT100');
    });

    it('repository_write_through_delete_propagates_to_store', 0, async () => {
      const store = new MemoryEventStore();
      EventRepository.initForTest(store);
      const repo = EventRepository.getInstance();
      repo.saveEvent(buildEvent('EVT100'));
      repo.deleteEvent('EVT100');
      const stored: SecurityEvent[] = await store.loadEvents();
      expect(stored.length).assertEqual(0);
    });

    it('event_service_seeds_empty_repository', 0, () => {
      const events: SecurityEvent[] = EventService.getAllEvents();
      expect(events.length).assertEqual(3);
      expect(events[0].id).assertEqual('EVT001');
    });

    it('event_service_seed_only_once', 0, () => {
      EventService.getAllEvents();
      EventRepository.getInstance().deleteEvent('EVT001');
      const events: SecurityEvent[] = EventService.getAllEvents();
      expect(events.length).assertEqual(2);
    });

    it('event_service_confirm_persists_to_repository', 0, () => {
      EventService.confirmEvent('EVT001');
      const found = EventRepository.getInstance().getEventById('EVT001');
      expect(found === undefined).assertFalse();
      if (found !== undefined) {
        expect(found.status).assertEqual(EventStatus.CONFIRMED);
      }
    });

    it('event_service_create_task_and_deduplicate', 0, () => {
      EventService.createTaskFromEvent('EVT003');
      expect(EventService.getAllTasks().length).assertEqual(1);
      expect(EventService.getAllTasks()[0].eventId).assertEqual('EVT003');
      EventService.createTaskFromEvent('EVT003');
      expect(EventService.getAllTasks().length).assertEqual(1);
    });

    it('event_service_get_event_by_id_unknown_returns_undefined', 0, () => {
      expect(EventService.getEventById('UNKNOWN')).assertEqual(undefined);
    });
  });
}
