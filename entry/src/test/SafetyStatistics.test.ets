import { describe, it, expect } from '@ohos/hypium';
import { EventPriority, EventStatus, EventType, SecurityEvent } from '../main/ets/model/SecurityEvent';
import { Task, TaskStatus } from '../main/ets/model/Task';
import { SafetyStatisticsService } from '../main/ets/service/SafetyStatisticsService';

export default function safetyStatisticsTest() {
  describe('SafetyStatisticsTest', () => {
    it('returns_empty_data_indicators_without_demo_values', 0, () => {
      const stats = SafetyStatisticsService.createSnapshot([], []);
      expect(stats.totalEvents).assertEqual(0);
      expect(stats.averageFirstResponseMinutes === null).assertTrue();
      expect(stats.averageHandlingMinutes === null).assertTrue();
      expect(stats.onTimeCompletionRate === null).assertTrue();
      expect(SafetyStatisticsService.getTypeCompletionRate([], EventType.FIRE) === null).assertTrue();
    });

    it('derives_response_handling_and_deadline_metrics_from_lifecycle_times', 0, () => {
      const events: SecurityEvent[] = [
        {
          id: 'EVT-STAT-1', title: '消防通道堆物', type: EventType.FIRE,
          location: '教学楼一层', description: '通道需要清理', reporter: 'student_001',
          reportTime: '2026-09-09 09:00', status: EventStatus.COMPLETED, priority: EventPriority.HIGH
        },
        {
          id: 'EVT-STAT-2', title: '配电箱异响', type: EventType.ELECTRIC,
          location: '实验楼二层', description: '待确认', reporter: 'teacher_001',
          reportTime: '2026-09-09 10:00', status: EventStatus.PENDING, priority: EventPriority.MEDIUM
        }
      ];
      const tasks: Task[] = [
        {
          id: 'TASK-STAT-1', eventId: 'EVT-STAT-1', title: '清理消防通道',
          location: '教学楼一层', description: '处置任务', assignee: 'inspector_001',
          createTime: '2026-09-09 09:10', acceptedTime: '2026-09-09 09:10',
          deadline: '2026-09-09 10:00', completedTime: '2026-09-09 09:40', status: TaskStatus.COMPLETED
        },
        {
          id: 'TASK-STAT-2', eventId: 'EVT-STAT-2', title: '检查配电箱',
          location: '实验楼二层', description: '处置任务', assignee: 'inspector_001',
          createTime: '2026-09-09 10:00', deadline: '2026-09-09 10:30', status: TaskStatus.PENDING
        }
      ];

      const stats = SafetyStatisticsService.createSnapshot(events, tasks);
      expect(stats.pendingEvents).assertEqual(1);
      expect(stats.completedEvents).assertEqual(1);
      expect(stats.averageFirstResponseMinutes).assertEqual(10);
      expect(stats.averageHandlingMinutes).assertEqual(30);
      expect(stats.onTimeCompletionRate).assertEqual(100);
      expect(SafetyStatisticsService.getTypeCompletionRate(events, EventType.FIRE)).assertEqual(100);
      expect(SafetyStatisticsService.getTypeCompletionRate(events, EventType.CAMPUS) === null).assertTrue();
    });
  });
}
