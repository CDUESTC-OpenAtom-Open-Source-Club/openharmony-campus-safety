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

export default function eventWorkflowTest() {
  describe('EventWorkflowTest', () => {
    beforeEach(() => {
      EventRepository.initForTest(new MemoryEventStore());
    });

    it('workflow_simulate_and_enqueue_saves_pending_event', 0, () => {
      const repo = EventRepository.getInstance();
      const before: number = repo.getEvents().length;
      const event: SecurityEvent = EventWorkflowService.simulateAndEnqueue(0);
      expect(repo.getEvents().length).assertEqual(before + 1);
      expect(event.status).assertEqual(EventStatus.PENDING);
      const stored = repo.getEventById(event.id);
      expect(stored === undefined).assertFalse();
      if (stored !== undefined) {
        expect(stored.title).assertEqual('烟雾异常');
        expect(stored.type).assertEqual(EventType.FIRE);
      }
    });

    it('workflow_simulate_and_enqueue_uses_random_template_when_invalid', 0, () => {
      const repo = EventRepository.getInstance();
      const event: SecurityEvent = EventWorkflowService.simulateAndEnqueue(9);
      expect(repo.getEvents().length).assertEqual(1);
      expect(event.status).assertEqual(EventStatus.PENDING);
    });

    it('workflow_simulate_and_enqueue_batch', 0, () => {
      const repo = EventRepository.getInstance();
      const events: SecurityEvent[] = EventWorkflowService.simulateAndEnqueueBatch(3);
      expect(events.length).assertEqual(3);
      expect(repo.getEvents().length).assertEqual(3);
    });

    it('workflow_simulate_and_enqueue_batch_invalid_count_noop', 0, () => {
      const repo = EventRepository.getInstance();
      const empty: SecurityEvent[] = EventWorkflowService.simulateAndEnqueueBatch(0);
      expect(empty.length).assertEqual(0);
      expect(repo.getEvents().length).assertEqual(0);
      const negative: SecurityEvent[] = EventWorkflowService.simulateAndEnqueueBatch(-1);
      expect(negative.length).assertEqual(0);
      expect(repo.getEvents().length).assertEqual(0);
    });

    it('workflow_state_link_task_processing_updates_event', 0, () => {
      const event: SecurityEvent = EventWorkflowService.simulateAndEnqueue(0);
      EventService.confirmEvent(event.id);
      EventService.createTaskFromEvent(event.id);
      const task = EventRepository.getInstance().getTaskByEventId(event.id);
      expect(task === undefined).assertFalse();
      if (task !== undefined) {
        EventService.updateTaskStatus(task.id, TaskStatus.PROCESSING);
        const stored = EventRepository.getInstance().getEventById(event.id);
        expect(stored === undefined).assertFalse();
        if (stored !== undefined) {
          expect(stored.status).assertEqual(EventStatus.PROCESSING);
        }
      }
    });

    it('workflow_state_link_task_completed_updates_event', 0, () => {
      const event: SecurityEvent = EventWorkflowService.simulateAndEnqueue(0);
      EventService.confirmEvent(event.id);
      EventService.createTaskFromEvent(event.id);
      const task = EventRepository.getInstance().getTaskByEventId(event.id);
      expect(task === undefined).assertFalse();
      if (task !== undefined) {
        EventService.updateTaskStatus(task.id, TaskStatus.COMPLETED);
        const stored = EventRepository.getInstance().getEventById(event.id);
        expect(stored === undefined).assertFalse();
        if (stored !== undefined) {
          expect(stored.status).assertEqual(EventStatus.COMPLETED);
        }
      }
    });

    it('workflow_full_loop_states_advance_step_by_step', 0, () => {
      const event: SecurityEvent = EventWorkflowService.simulateAndEnqueue(0);
      const repo = EventRepository.getInstance();

      const beforeConfirm = repo.getEventById(event.id);
      expect(beforeConfirm === undefined).assertFalse();
      if (beforeConfirm !== undefined) {
        expect(beforeConfirm.status).assertEqual(EventStatus.PENDING);
      }

      EventService.confirmEvent(event.id);
      const afterConfirm = repo.getEventById(event.id);
      expect(afterConfirm === undefined).assertFalse();
      if (afterConfirm !== undefined) {
        expect(afterConfirm.status).assertEqual(EventStatus.CONFIRMED);
      }

      EventService.createTaskFromEvent(event.id);
      const task = repo.getTaskByEventId(event.id);
      expect(task === undefined).assertFalse();
      if (task !== undefined) {
        expect(task.status).assertEqual(TaskStatus.PENDING);
      }

      if (task !== undefined) {
        EventService.updateTaskStatus(task.id, TaskStatus.PROCESSING);
        const duringProcessing = repo.getEventById(event.id);
        expect(duringProcessing === undefined).assertFalse();
        if (duringProcessing !== undefined) {
          expect(duringProcessing.status).assertEqual(EventStatus.PROCESSING);
        }
      }

      if (task !== undefined) {
        EventService.updateTaskStatus(task.id, TaskStatus.COMPLETED);
        const afterComplete = repo.getEventById(event.id);
        expect(afterComplete === undefined).assertFalse();
        if (afterComplete !== undefined) {
          expect(afterComplete.status).assertEqual(EventStatus.COMPLETED);
        }
      }
    });

    it('workflow_completed_event_no_downgrade_on_task_rollback', 0, () => {
      const event: SecurityEvent = EventWorkflowService.simulateAndEnqueue(0);
      EventService.confirmEvent(event.id);
      EventService.createTaskFromEvent(event.id);
      const task = EventRepository.getInstance().getTaskByEventId(event.id);
      expect(task === undefined).assertFalse();
      if (task !== undefined) {
        EventService.updateTaskStatus(task.id, TaskStatus.PROCESSING);
        EventService.updateTaskStatus(task.id, TaskStatus.COMPLETED);
        // 已完成任务被要求回退到处理中：任务与事件状态均保持不变
        EventService.updateTaskStatus(task.id, TaskStatus.PROCESSING);
        const storedTask = EventRepository.getInstance().getTaskByEventId(event.id);
        expect(storedTask === undefined).assertFalse();
        if (storedTask !== undefined) {
          expect(storedTask.status).assertEqual(TaskStatus.COMPLETED);
        }
        const storedEvent = EventRepository.getInstance().getEventById(event.id);
        expect(storedEvent === undefined).assertFalse();
        if (storedEvent !== undefined) {
          expect(storedEvent.status).assertEqual(EventStatus.COMPLETED);
        }
      }
    });

    it('workflow_duplicate_confirm_and_dispatch_protected', 0, () => {
      const event: SecurityEvent = EventWorkflowService.simulateAndEnqueue(0);
      EventService.confirmEvent(event.id);
      EventService.createTaskFromEvent(event.id);
      EventService.confirmEvent(event.id);
      EventService.createTaskFromEvent(event.id);
      const repo = EventRepository.getInstance();
      expect(repo.getAllTasks().length).assertEqual(1);
      expect(repo.getTaskByEventId(event.id) === undefined).assertFalse();
    });

    it('workflow_run_full_loop_reaches_completed', 0, () => {
      const event: SecurityEvent = EventWorkflowService.runFullWorkflow(0);
      const repo = EventRepository.getInstance();
      const stored = repo.getEventById(event.id);
      expect(stored === undefined).assertFalse();
      if (stored !== undefined) {
        expect(stored.status).assertEqual(EventStatus.COMPLETED);
      }
      const task = repo.getTaskByEventId(event.id);
      expect(task === undefined).assertFalse();
      if (task !== undefined) {
        expect(task.status).assertEqual(TaskStatus.COMPLETED);
      }
    });

    it('workflow_report_hazard_saves_pending_event', 0, () => {
      const repo = EventRepository.getInstance();
      const before: number = repo.getEvents().length;
      const event: SecurityEvent | undefined = EventWorkflowService.reportHazard({
        title: '楼道应急灯破损',
        type: EventType.FACILITY,
        location: '教学楼2层东侧',
        description: '应急灯外壳破损，灯管裸露',
        reporter: '张三'
      });
      expect(event === undefined).assertFalse();
      expect(repo.getEvents().length).assertEqual(before + 1);
      if (event !== undefined) {
        expect(event.status).assertEqual(EventStatus.PENDING);
        expect(event.type).assertEqual(EventType.FACILITY);
        expect(event.location).assertEqual('教学楼2层东侧');
        expect(event.reporter).assertEqual('张三');
        expect(repo.getEventById(event.id) === undefined).assertFalse();
      }
    });

    it('workflow_report_hazard_trims_and_applies_defaults', 0, () => {
      const event: SecurityEvent | undefined = EventWorkflowService.reportHazard({
        title: '  楼道应急灯破损  ',
        type: EventType.FACILITY,
        location: ' 教学楼2层东侧 ',
        description: '应急灯外壳破损，灯管裸露',
        reporter: '  '
      });
      expect(event === undefined).assertFalse();
      if (event !== undefined) {
        expect(event.title).assertEqual('楼道应急灯破损');
        expect(event.location).assertEqual('教学楼2层东侧');
        expect(event.reporter).assertEqual('学生上报');
        expect(event.priority).assertEqual(EventPriority.MEDIUM);
      }
    });

    it('workflow_report_hazard_missing_required_returns_undefined', 0, () => {
      const repo = EventRepository.getInstance();
      const missingLocation: SecurityEvent | undefined = EventWorkflowService.reportHazard({
        title: '隐患上报',
        type: EventType.OTHER,
        location: '   ',
        description: '没有地点'
      });
      expect(missingLocation === undefined).assertTrue();
      const missingDescription: SecurityEvent | undefined = EventWorkflowService.reportHazard({
        title: '隐患上报',
        type: EventType.OTHER,
        location: '操场',
        description: ''
      });
      expect(missingDescription === undefined).assertTrue();
      expect(repo.getEvents().length).assertEqual(0);
    });

    it('workflow_report_hazard_multiple_submissions_distinct_ids', 0, () => {
      const repo = EventRepository.getInstance();
      const first: SecurityEvent | undefined = EventWorkflowService.reportHazard({
        title: '隐患A',
        type: EventType.CAMPUS,
        location: '食堂',
        description: '地面湿滑'
      });
      const second: SecurityEvent | undefined = EventWorkflowService.reportHazard({
        title: '隐患B',
        type: EventType.CAMPUS,
        location: '操场',
        description: '器材损坏'
      });
      expect(first === undefined).assertFalse();
      expect(second === undefined).assertFalse();
      if (first !== undefined && second !== undefined) {
        expect(first.id === second.id).assertFalse();
      }
      expect(repo.getEvents().length).assertEqual(2);
    });

    it('build_summary_title_short_description_unchanged', 0, () => {
      expect(EventWorkflowService.buildSummaryTitle('楼道应急灯破损')).assertEqual('楼道应急灯破损');
    });

    it('build_summary_title_long_description_truncated_with_ellipsis', 0, () => {
      const longDesc: string = '教学楼2层东侧走廊应急灯外壳破损灯管裸露存在漏电风险请尽快处理';
      const title: string = EventWorkflowService.buildSummaryTitle(longDesc);
      // 15 字截断 + 省略号，共 16 字符；不产生孤代理替换符
      expect(title.length <= 16).assertTrue();
      expect(title.endsWith('…')).assertTrue();
      expect(title.indexOf('�')).assertEqual(-1);
    });

    it('build_summary_title_folds_multiline_whitespace', 0, () => {
      expect(EventWorkflowService.buildSummaryTitle('第一行描述\r\n第二行描述')).assertEqual('第一行描述 第二行描述');
      expect(EventWorkflowService.buildSummaryTitle('第一行描述\n第二行描述')).assertEqual('第一行描述 第二行描述');
    });

    it('build_summary_title_emoji_not_split_into_surrogate', 0, () => {
      const longDesc: string = '🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥 多个火警emoji超长描述';
      const title: string = EventWorkflowService.buildSummaryTitle(longDesc);
      // 按码点截取，不应产生孤代理字符（渲染为替换符 �）
      expect(title.indexOf('�')).assertEqual(-1);
    });

    it('build_summary_title_empty_returns_placeholder', 0, () => {
      expect(EventWorkflowService.buildSummaryTitle('   ')).assertEqual('隐患上报');
    });

    it('workflow_report_hazard_placeholder_title_replaced_with_summary', 0, () => {
      const repo = EventRepository.getInstance();
      const before: number = repo.getEvents().length;
      const event: SecurityEvent | undefined = EventWorkflowService.reportHazard({
        title: '隐患上报',
        type: EventType.FACILITY,
        location: '教学楼2层',
        description: '楼道应急灯外壳破损，灯管裸露存在漏电风险',
        reporter: '张三'
      });
      expect(event === undefined).assertFalse();
      expect(repo.getEvents().length).assertEqual(before + 1);
      if (event !== undefined) {
        // 数据层兜底：占位标题被描述摘要替换
        expect(event.title === '隐患上报').assertFalse();
        expect(event.title.indexOf('应急灯') >= 0).assertTrue();
        expect(event.title.endsWith('…')).assertTrue();
      }
    });
  });
}
