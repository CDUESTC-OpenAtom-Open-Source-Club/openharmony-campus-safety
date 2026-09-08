import { User, UserRole } from '../model/User';

export enum AppPermission {
  REPORT_HAZARD = 'REPORT_HAZARD',
  VIEW_OWN_REPORTS = 'VIEW_OWN_REPORTS',
  VIEW_ASSIGNED_TASKS = 'VIEW_ASSIGNED_TASKS',
  START_TASK = 'START_TASK',
  SUBMIT_TASK = 'SUBMIT_TASK',
  CONFIRM_EVENT = 'CONFIRM_EVENT',
  DISPATCH_TASK = 'DISPATCH_TASK',
  REVIEW_TASK = 'REVIEW_TASK',
  MANAGE_ACCOUNTS = 'MANAGE_ACCOUNTS',
  VIEW_STATISTICS = 'VIEW_STATISTICS'
}

/** 统一权限入口。页面可据此展示操作，业务服务仍须在执行前再次校验。 */
export class PermissionService {
  static can(user: User | null, permission: AppPermission): boolean {
    if (user === null) {
      return false;
    }
    if (user.role === UserRole.ADMIN) {
      return true;
    }
    if (user.role === UserRole.SECURITY) {
      return permission === AppPermission.VIEW_ASSIGNED_TASKS ||
        permission === AppPermission.START_TASK ||
        permission === AppPermission.SUBMIT_TASK ||
        permission === AppPermission.REPORT_HAZARD;
    }
    return permission === AppPermission.REPORT_HAZARD ||
      permission === AppPermission.VIEW_OWN_REPORTS;
  }
}
