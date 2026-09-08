import { describe, it, beforeEach, expect } from '@ohos/hypium';
import { EventPriority, EventStatus, EventType } from '../main/ets/model/SecurityEvent';
import { User, UserRole } from '../main/ets/model/User';
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
