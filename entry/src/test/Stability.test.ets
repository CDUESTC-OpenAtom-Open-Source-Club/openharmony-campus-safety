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

import { EventWorkflowService } from '../main/ets/service/EventWorkflowService';

/**
 * 稳定性与重启恢复测试（C 模块 M4）
 *
 * 覆盖：重启后数据恢复、大批量连续生成、数据量增加后的筛选、
 * 快速重复操作幂等、单次异常不影响后续。真实 RDB 文件持久化
 * 依赖系统环境，留待云手机真机验证（见 docs/C跨模块对接.md）。
 */
export default function stabilityTest() {
  describe('StabilityTest', () => {
    beforeEach(() => {
      EventRepository.initForTest(new MemoryEventStore());
    });

    it('stability_restart_reload_restores_events_and_tasks', 0, async () => {
      const store = new MemoryEventStore();
      EventRepository.initForTest(store);
      const repo = EventRepository.getInstance();
      repo.saveEvent({
        id: 'EVT-R1',
        title: '烟雾异常',
        type: EventType.FIRE,
        location: '教学楼3层走廊',
        description: '消防监测区域发现异常烟雾',
        reporter: '系统模拟',
        reportTime: '2026-08-27 10:00',
        status: EventStatus.CONFIRMED,
        priority: EventPriority.HIGH
      });
      repo.saveTask({
        id: 'TASK-R1',
        eventId: 'EVT-R1',
        title: '烟雾异常处置',
        location: '教学楼3层走廊',
        description: '消防监测区域发现异常烟雾',
        assignee: 'inspector_001',
        createTime: '2026-08-27 10:00',
        status: TaskStatus.PROCESSING
      });

      // 模拟应用重启：同一持久层 store，Repository 重建后重新装载
      EventRepository.initForTest(store);
      const restored = EventRepository.getInstance();
      await restored.load();

      expect(restored.getEvents().length).assertEqual(1);
      expect(restored.getAllTasks().length).assertEqual(1);
      const event = restored.getEventById('EVT-R1');
      expect(event === undefined).assertFalse();
      if (event !== undefined) {
        expect(event.id).assertEqual('EVT-R1');
        expect(event.status).assertEqual(EventStatus.CONFIRMED);
      }
      const task = restored.getTaskByEventId('EVT-R1');
      expect(task === undefined).assertFalse();
      if (task !== undefined) {
        expect(task.id).assertEqual('TASK-R1');
        expect(task.status).assertEqual(TaskStatus.PROCESSING);
      }
    });

    it('stability_restart_reload_preserves_event_task_link', 0, async () => {
      const store = new MemoryEventStore();
      EventRepository.initForTest(store);
      const repo = EventRepository.getInstance();
      repo.saveEvent({
        id: 'EVT-LINK',
        title: '设备故障',
        type: EventType.ELECTRIC,
        location: '宿舍楼公共区域',
        description: '公共设施发生故障',
        reporter: '系统模拟',
        reportTime: '2026-08-27 10:05',
        status: EventStatus.PENDING,
        priority: EventPriority.MEDIUM
      });
      repo.saveTask({
        id: 'TASK-LINK',
        eventId: 'EVT-LINK',
        title: '设备故障处置',
        location: '宿舍楼公共区域',
        description: '公共设施发生故障',
        assignee: 'inspector_001',
        createTime: '2026-08-27 10:05',
        status: TaskStatus.PENDING
      });

      EventRepository.initForTest(store);
      const restored = EventRepository.getInstance();
      await restored.load();

      const task = restored.getTaskByEventId('EVT-LINK');
      expect(task === undefined).assertFalse();
      if (task !== undefined) {
        expect(task.eventId).assertEqual('EVT-LINK');
        expect(restored.getEventById(task.eventId) === undefined).assertFalse();
      }
    });

    it('stability_large_batch_50_events_no_duplicate_ids', 0, () => {
      const events: SecurityEvent[] = EventWorkflowService.simulateAndEnqueueBatch(50);
      expect(events.length).assertEqual(50);
      let duplicate: boolean = false;
      for (let i = 0; i < events.length; i++) {
        for (let j = i + 1; j < events.length; j++) {
          if (events[i].id === events[j].id) {
            duplicate = true;
          }
        }
      }
      expect(duplicate).assertFalse();
    });

    it('stability_large_batch_all_pending', 0, () => {
      const repo = EventRepository.getInstance();
      EventWorkflowService.simulateAndEnqueueBatch(50);
      expect(repo.getEvents().length).assertEqual(50);
      let allPending: boolean = true;
      repo.getEvents().forEach((event: SecurityEvent) => {
        if (event.status !== EventStatus.PENDING) {
          allPending = false;
        }
      });
      expect(allPending).assertTrue();
    });

    it('stability_mixed_states_filter_after_confirms', 0, () => {
      const repo = EventRepository.getInstance();
      const events: SecurityEvent[] = EventWorkflowService.simulateAndEnqueueBatch(50);
      for (let i = 0; i < 10; i++) {
        EventService.confirmEvent(events[i].id);
      }
      expect(repo.getEvents().length).assertEqual(50);
      expect(repo.getEvents().filter((event: SecurityEvent) => event.status === EventStatus.CONFIRMED).length).assertEqual(10);
      const pending: SecurityEvent[] = EventService.getPendingEvents();
      expect(pending.length).assertEqual(40);
    });

    it('stability_repeated_confirm_dispatch_ten_times_keeps_one_task', 0, () => {
      const event: SecurityEvent = EventWorkflowService.simulateAndEnqueue(0);
      for (let i = 0; i < 10; i++) {
        EventService.confirmEvent(event.id);
        EventService.createTaskFromEvent(event.id);
      }
      const repo = EventRepository.getInstance();
      expect(repo.getAllTasks().length).assertEqual(1);
      const task = repo.getTaskByEventId(event.id);
      expect(task === undefined).assertFalse();
      if (task !== undefined) {
        expect(task.status).assertEqual(TaskStatus.PENDING);
      }
    });

    it('stability_repeated_complete_keeps_state_stable', 0, () => {
      const event: SecurityEvent = EventWorkflowService.runFullWorkflow(0);
      const repo = EventRepository.getInstance();
      const task = repo.getTaskByEventId(event.id);
      expect(task === undefined).assertFalse();
      if (task !== undefined) {
        for (let i = 0; i < 5; i++) {
          EventService.updateTaskStatus(task.id, TaskStatus.COMPLETED);
        }
        const storedTask = repo.getTaskByEventId(event.id);
        expect(storedTask === undefined).assertFalse();
        if (storedTask !== undefined) {
          expect(storedTask.status).assertEqual(TaskStatus.COMPLETED);
        }
        const storedEvent = repo.getEventById(event.id);
        expect(storedEvent === undefined).assertFalse();
        if (storedEvent !== undefined) {
          expect(storedEvent.status).assertEqual(EventStatus.COMPLETED);
        }
      }
    });

    it('stability_large_batch_then_workflow_still_runs', 0, () => {
      const repo = EventRepository.getInstance();
      const events: SecurityEvent[] = EventWorkflowService.simulateAndEnqueueBatch(50);
      expect(events.length).assertEqual(50);

      // 对批量中的第一个事件跑完整闭环
      EventService.confirmEvent(events[0].id);
      EventService.createTaskFromEvent(events[0].id);
      const task = repo.getTaskByEventId(events[0].id);
      expect(task === undefined).assertFalse();
      if (task !== undefined) {
        EventService.updateTaskStatus(task.id, TaskStatus.PROCESSING);
        EventService.updateTaskStatus(task.id, TaskStatus.COMPLETED);
      }

      expect(repo.getEvents().length).assertEqual(50);
      expect(repo.getAllTasks().length).assertEqual(1);
      const completed = repo.getEventById(events[0].id);
      expect(completed === undefined).assertFalse();
      if (completed !== undefined) {
        expect(completed.status).assertEqual(EventStatus.COMPLETED);
      }
      // 其余 49 个保持 PENDING，不受影响
      let untouched: boolean = true;
      for (let i = 1; i < events.length; i++) {
        const other = repo.getEventById(events[i].id);
        if (other === undefined || other.status !== EventStatus.PENDING) {
          untouched = false;
        }
      }
      expect(untouched).assertTrue();
    });

    it('stability_invalid_template_does_not_block_followups', 0, () => {
      const repo = EventRepository.getInstance();
      const bad: SecurityEvent = EventWorkflowService.simulateAndEnqueue(99);
      expect(bad.status).assertEqual(EventStatus.PENDING);
      const next: SecurityEvent = EventWorkflowService.simulateAndEnqueue(0);
      expect(repo.getEvents().length).assertEqual(2);
      expect(next.title).assertEqual('烟雾异常');
      expect(bad.id === next.id).assertFalse();
    });
  });
}
