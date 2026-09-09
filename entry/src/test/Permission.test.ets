import { describe, it, beforeEach, expect } from '@ohos/hypium';
import { EventPriority, EventStatus, EventType } from '../main/ets/model/SecurityEvent';
import { User, UserRole } from '../main/ets/model/User';
import { TaskStatus } from '../main/ets/model/Task';
import { EventRepository } from '../main/ets/repository/EventRepository';
import { MemoryEventStore } from '../main/ets/repository/store/MemoryEventStore';
import { AccountService } from '../main/ets/service/AccountService';
import { EventService } from '../main/ets/service/EventService';
import { AppPermission, PermissionService } from '../main/ets/service/PermissionService';
import { TEST_ADMIN, TEST_STUDENT } from './TestAuthFixture';

const TEST_SECURITY: User = {
  id: 'inspector_001',
  name: '测试巡检员',
  role: UserRole.SECURITY
};

export default function permissionTest() {
  describe('PermissionTest', () => {
    beforeEach(() => {
      AccountService.setCurrentUserForTest(TEST_ADMIN);
      EventRepository.initForTest(new MemoryEventStore());
    });

    it('permission_role_matrix_enforces_separation', 0, () => {
      expect(PermissionService.can(TEST_STUDENT, AppPermission.REPORT_HAZARD)).assertTrue();
      expect(PermissionService.can(TEST_STUDENT, AppPermission.CONFIRM_EVENT)).assertFalse();
      expect(PermissionService.can(TEST_SECURITY, AppPermission.START_TASK)).assertTrue();
      expect(PermissionService.can(TEST_SECURITY, AppPermission.REVIEW_TASK)).assertFalse();
      expect(PermissionService.can(TEST_ADMIN, AppPermission.REVIEW_TASK)).assertTrue();
    });

    it('student_only_reads_own_reports_and_completed_feedback', 0, () => {
      const repo: EventRepository = EventRepository.getInstance();
      repo.saveEvent({
        id: 'EVT-MINE-1',
        title: '本人上报',
        type: EventType.FACILITY,
        location: '教学楼',
        description: '安全出口指示灯故障',
        reporter: TEST_STUDENT.name,
        reporterId: TEST_STUDENT.id,
        reportTime: '2026-09-09 10:00:00',
        status: EventStatus.COMPLETED,
        priority: EventPriority.MEDIUM,
        handler: TEST_SECURITY.id
      });
      repo.saveEvent({
        id: 'EVT-OTHER-1',
        title: '他人上报',
        type: EventType.FIRE,
        location: '实验楼',
        description: '烟雾异常',
        reporter: '其他学生',
        reporterId: 'student_other',
        reportTime: '2026-09-09 10:05:00',
        status: EventStatus.PENDING,
        priority: EventPriority.HIGH
      });
      repo.saveTask({
        id: 'TASK-MINE-1',
        eventId: 'EVT-MINE-1',
        title: '本人上报处置',
        location: '教学楼',
        description: '更换指示灯',
        assignee: TEST_SECURITY.id,
        createTime: '2026-09-09 10:10:00',
        status: TaskStatus.COMPLETED,
        result: '已更换指示灯并复测正常',
        completedTime: '2026-09-09 11:00:00'
      });

      AccountService.setCurrentUserForTest(TEST_STUDENT);
      expect(EventService.getAllEvents().length).assertEqual(1);
      expect(EventService.getEventById('EVT-MINE-1') === undefined).assertFalse();
      expect(EventService.getEventById('EVT-OTHER-1') === undefined).assertTrue();
      expect(EventService.getCompletionFeedback('EVT-MINE-1')).assertEqual(
        '已更换指示灯并复测正常'
      );
      expect(EventService.getCompletionFeedback('EVT-OTHER-1')).assertEqual('');
      const ownEvent = repo.getEventById('EVT-MINE-1');
      const ownTask = repo.getTaskByEventId('EVT-MINE-1');
      if (ownEvent !== undefined && ownTask !== undefined) {
        ownEvent.status = EventStatus.REVIEW;
        ownTask.status = TaskStatus.REVIEW;
        expect(EventService.getCompletionFeedback('EVT-MINE-1')).assertEqual('');
      }
    });

    it('student_cannot_confirm_or_dispatch_event', 0, () => {
      EventRepository.getInstance().saveEvent({
        id: 'EVT-AUTH-1',
        title: '权限测试事件',
        type: EventType.OTHER,
        location: '测试地点',
        description: '验证普通用户越权请求会被拒绝',
        reporter: TEST_STUDENT.name,
        reporterId: TEST_STUDENT.id,
        reportTime: '2026-09-08 10:00:00',
        status: EventStatus.PENDING,
        priority: EventPriority.MEDIUM
      });
      AccountService.setCurrentUserForTest(TEST_STUDENT);
      expect(EventService.confirmEvent('EVT-AUTH-1')).assertFalse();
      expect(EventService.createTaskFromEvent('EVT-AUTH-1')).assertFalse();
    });

    it('security_cannot_process_another_assignees_task', 0, () => {
      EventRepository.getInstance().saveEvent({
        id: 'EVT-AUTH-2',
        title: '任务归属测试',
        type: EventType.FACILITY,
        location: '测试地点',
        description: '验证任务仅允许负责人处理',
        reporter: TEST_STUDENT.name,
        reporterId: TEST_STUDENT.id,
        reportTime: '2026-09-08 10:00:00',
        status: EventStatus.CONFIRMED,
        priority: EventPriority.MEDIUM
      });
      EventRepository.getInstance().saveTask({
        id: 'TASK-AUTH-2',
        eventId: 'EVT-AUTH-2',
        title: '任务归属测试',
        location: '测试地点',
        description: '验证任务仅允许负责人处理',
        assignee: 'another_inspector',
        createTime: '2026-09-08 10:00:00',
        status: '待处理'
      });
      AccountService.setCurrentUserForTest(TEST_SECURITY);
      expect(EventService.startTask('TASK-AUTH-2')).assertFalse();
      expect(EventService.getAllTasks().length).assertEqual(0);
    });
  });
}
