import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { AccountService, LoginResult } from '../main/ets/service/AccountService';
import { UserRole } from '../main/ets/model/User';

export default function accountRegistrationTest() {
  describe('AccountRegistrationTest', () => {
    beforeEach(() => {
      AccountService.resetForTest();
    });

    it('empty_device_allows_regular_member_registration_without_admin_bootstrap', 0, async () => {
      expect(AccountService.needsAdministratorBootstrap()).assertFalse();
      const result: LoginResult = await AccountService.registerUser(
        'member_2026', '普通成员', 'Member2026A', UserRole.STUDENT
      );
      expect(result.success).assertTrue();
      expect(result.user?.role).assertEqual(UserRole.STUDENT);
      expect(AccountService.getUsers().length).assertEqual(1);
      expect(AccountService.getCurrentUser()?.id).assertEqual(result.user?.id);
    });

    it('public_registration_rejects_security_and_administrator_roles', 0, async () => {
      const securityResult: LoginResult = await AccountService.registerUser(
        'security_2026', '安保成员', 'Security2026A', UserRole.SECURITY
      );
      const adminResult: LoginResult = await AccountService.registerUser(
        'admin_2026', '管理员', 'Admin2026A', UserRole.ADMIN
      );
      expect(securityResult.success).assertFalse();
      expect(adminResult.success).assertFalse();
      expect(AccountService.getUsers().length).assertEqual(0);
    });

    it('public_registration_rejects_mismatched_password_confirmation', 0, async () => {
      const result: LoginResult = await AccountService.registerUser(
        'confirm_2026', '确认成员', 'Member2026A', UserRole.STUDENT, 'Member2026B'
      );
      expect(result.success).assertFalse();
      expect(AccountService.getUsers().length).assertEqual(0);
    });

    it('newly_registered_member_can_log_in_with_derived_password', 0, async () => {
      await AccountService.registerUser('member_login', '登录成员', 'Login2026A', UserRole.TEACHER);
      const loginResult: LoginResult = await AccountService.login('member_login', 'Login2026A');
      expect(loginResult.success).assertTrue();
      expect(loginResult.user?.name).assertEqual('登录成员');
    });
  });
}
