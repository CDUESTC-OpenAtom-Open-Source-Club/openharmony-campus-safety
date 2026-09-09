import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { User, UserRole } from '../model/User';

interface StoredAccount {
  user: User;
  username: string;
  passwordSalt: string;
  passwordHash: string;
  active: boolean;
  failedAttempts: number;
  lockedUntil: number;
}

interface StoredInternalInvitation {
  id: string;
  role: UserRole;
  codeSalt: string;
  codeHash: string;
  expiresAt: number;
  usedAt: number;
  createdBy: string;
}

export interface LoginResult {
  success: boolean;
  message: string;
  user?: User;
}

export interface InvitationResult {
  success: boolean;
  message: string;
  code?: string;
}

export class ManagedAccount {
  user: User;
  active: boolean;

  constructor(user: User, active: boolean) {
    this.user = user;
    this.active = active;
  }
}

/**
 * 本地测试版账号服务。
 *
 * 密码通过 PBKDF2-HMAC-SHA256 与每账号独立随机盐派生后保存，Preferences 中不存明文密码。
 * 本地角色隔离只保护应用内操作，不能替代可信校园身份认证或服务端授权。
 */
export class AccountService {
  private static readonly PREF_NAME: string = 'local_accounts';
  private static readonly KEY_ACCOUNTS: string = 'accounts';
  private static readonly KEY_INVITATIONS: string = 'internal_invitations';
  private static readonly KEY_CURRENT_USER_ID: string = 'currentUserId';
  private static readonly ITERATIONS: number = 120000;
  private static readonly KEY_SIZE: number = 32;
  private static readonly MIN_PASSWORD_LENGTH: number = 10;
  private static readonly MAX_FAILED_ATTEMPTS: number = 5;
  private static readonly LOCK_DURATION_MILLIS: number = 5 * 60 * 1000;
  private static readonly INVITATION_DURATION_MILLIS: number = 24 * 60 * 60 * 1000;
  private static accounts: StoredAccount[] = [];
  private static invitations: StoredInternalInvitation[] = [];
  private static currentUser: User | null = null;
  private static pref: preferences.Preferences | null = null;

  static async init(context: common.Context): Promise<void> {
    AccountService.pref = await preferences.getPreferences(context, AccountService.PREF_NAME);
    const rawAccounts: preferences.ValueType = await AccountService.pref.get(AccountService.KEY_ACCOUNTS, '');
    if (typeof rawAccounts === 'string' && rawAccounts.length > 0) {
      try {
        const parsed: object = JSON.parse(rawAccounts) as object;
        if (Array.isArray(parsed)) {
          AccountService.accounts = parsed as StoredAccount[];
          AccountService.accounts.forEach((account: StoredAccount) => {
            account.failedAttempts = account.failedAttempts ?? 0;
            account.lockedUntil = account.lockedUntil ?? 0;
          });
        }
      } catch (error) {
        console.error('AccountService account data parse failed: ' + JSON.stringify(error));
      }
    }
    const rawInvitations: preferences.ValueType = await AccountService.pref.get(AccountService.KEY_INVITATIONS, '');
    if (typeof rawInvitations === 'string' && rawInvitations.length > 0) {
      try {
        const parsed: object = JSON.parse(rawInvitations) as object;
        if (Array.isArray(parsed)) {
          AccountService.invitations = parsed as StoredInternalInvitation[];
        }
      } catch (error) {
        console.error('AccountService invitation data parse failed: ' + JSON.stringify(error));
      }
    }
    const currentIdValue: preferences.ValueType =
      await AccountService.pref.get(AccountService.KEY_CURRENT_USER_ID, '');
    if (typeof currentIdValue === 'string' && currentIdValue !== '') {
      const current: StoredAccount | undefined = AccountService.accounts.find(
        (account: StoredAccount) => account.user.id === currentIdValue && account.active
      );
      AccountService.currentUser = current === undefined ? null : current.user;
    }
  }

  static getCurrentUser(): User | null {
    return AccountService.currentUser;
  }

  /** 首次安装仅允许设备持有人建立一个管理员；不预置或暴露任何默认口令。 */
  static async bootstrapAdministrator(username: string, name: string, password: string): Promise<LoginResult> {
    if (AccountService.accounts.length > 0) {
      return { success: false, message: '管理员初始化已完成，请使用现有账号登录' };
    }
    const validation: string = AccountService.validateAccountInput(username, name, password);
    if (validation !== '') {
      return { success: false, message: validation };
    }
    const account: StoredAccount = AccountService.createAccount(
      AccountService.createUserId('admin'), username.trim().toLowerCase(), name.trim(), UserRole.ADMIN, password
    );
    AccountService.accounts = [account];
    AccountService.currentUser = account.user;
    await AccountService.persistAccounts();
    await AccountService.persistCurrentUserId();
    return { success: true, message: '管理员初始化完成', user: account.user };
  }

  /** 公开注册仅创建普通用户，管理员和巡检账号必须由管理员受控创建。 */
  static async registerUser(username: string, name: string, password: string, role: UserRole): Promise<LoginResult> {
    if (role !== UserRole.STUDENT && role !== UserRole.TEACHER) {
      return { success: false, message: '公开注册只支持学生或教师身份' };
    }
    const validation: string = AccountService.validateAccountInput(username, name, password);
    if (validation !== '') {
      return { success: false, message: validation };
    }
    if (AccountService.findByUsername(username) !== undefined) {
      return { success: false, message: '该账号已被使用' };
    }
    const account: StoredAccount = AccountService.createAccount(
      AccountService.createUserId('user'), username.trim().toLowerCase(), name.trim(), role, password
    );
    AccountService.accounts.push(account);
    await AccountService.persistAccounts();
    return { success: true, message: '注册成功，请使用新账号登录', user: account.user };
  }

  static needsAdministratorBootstrap(): boolean {
    return AccountService.accounts.length === 0;
  }

  static isLoggedIn(): boolean {
    return AccountService.currentUser !== null;
  }

  static getUsers(): User[] {
    return AccountService.accounts
      .filter((account: StoredAccount) => account.active)
      .map((account: StoredAccount) => account.user);
  }

  static getSecurityUsers(): User[] {
    return AccountService.getUsers().filter((user: User) => user.role === UserRole.SECURITY);
  }

  /** 仅管理员可签发；明文邀请码只在此刻返回一次，存储中仅保留派生摘要。 */
  static async issueInternalInvitation(role: UserRole): Promise<InvitationResult> {
    if (AccountService.currentUser === null || AccountService.currentUser.role !== UserRole.ADMIN) {
      return { success: false, message: '仅管理员可签发内部开通邀请码' };
    }
    if (role !== UserRole.SECURITY && role !== UserRole.ADMIN) {
      return { success: false, message: '内部邀请码仅适用于安保人员或管理员' };
    }
    const code: string = 'CS-' + AccountService.bytesToHex(
      cryptoFramework.createRandom().generateRandomSync(16).data
    ).toUpperCase();
    const salt: Uint8Array = cryptoFramework.createRandom().generateRandomSync(16).data;
    AccountService.invitations.push({
      id: AccountService.createUserId('invite'),
      role: role,
      codeSalt: AccountService.bytesToHex(salt),
      codeHash: AccountService.derivePassword(code, salt),
      expiresAt: Date.now() + AccountService.INVITATION_DURATION_MILLIS,
      usedAt: 0,
      createdBy: AccountService.currentUser.id
    });
    await AccountService.persistInvitations();
    return { success: true, message: '邀请码已签发，将在 24 小时后失效且只能使用一次', code: code };
  }

  /** 内部入口须同时满足有效、未使用、角色受限的邀请码校验。 */
  static async registerInternalUser(
    invitationCode: string, username: string, name: string, password: string
  ): Promise<LoginResult> {
    const validation: string = AccountService.validateAccountInput(username, name, password);
    if (validation !== '') {
      return { success: false, message: validation };
    }
    if (AccountService.findByUsername(username) !== undefined) {
      return { success: false, message: '该账号已被使用' };
    }
    const code: string = invitationCode.trim().toUpperCase();
    const invitation: StoredInternalInvitation | undefined = AccountService.invitations.find(
      (item: StoredInternalInvitation) => item.usedAt === 0 && item.expiresAt > Date.now() &&
        AccountService.verifySecret(code, item.codeHash, item.codeSalt)
    );
    if (invitation === undefined) {
      return { success: false, message: '内部邀请码无效、已使用或已过期' };
    }
    const account: StoredAccount = AccountService.createAccount(
      AccountService.createUserId('internal'), username.trim().toLowerCase(), name.trim(), invitation.role, password
    );
    invitation.usedAt = Date.now();
    AccountService.accounts.push(account);
    await AccountService.persistAccounts();
    await AccountService.persistInvitations();
    return { success: true, message: '内部账号已开通，请使用新账号登录', user: account.user };
  }

  static getManagedUsers(): ManagedAccount[] {
    if (AccountService.currentUser === null || AccountService.currentUser.role !== UserRole.ADMIN) {
      return [];
    }
    return AccountService.accounts.map((account: StoredAccount) => new ManagedAccount(account.user, account.active));
  }

  static async setAccountActive(userId: string, active: boolean): Promise<LoginResult> {
    if (AccountService.currentUser === null || AccountService.currentUser.role !== UserRole.ADMIN) {
      return { success: false, message: '仅管理员可管理账号状态' };
    }
    const account: StoredAccount | undefined = AccountService.accounts.find(
      (item: StoredAccount) => item.user.id === userId
    );
    if (account === undefined) {
      return { success: false, message: '账号不存在' };
    }
    if (!active && account.user.id === AccountService.currentUser.id) {
      return { success: false, message: '不能停用当前登录的管理员账号' };
    }
    if (!active && account.user.role === UserRole.ADMIN) {
      const activeAdministrators: number = AccountService.accounts.filter(
        (item: StoredAccount) => item.active && item.user.role === UserRole.ADMIN
      ).length;
      if (activeAdministrators <= 1) {
        return { success: false, message: '不能停用唯一的启用管理员账号' };
      }
    }
    account.active = active;
    account.failedAttempts = 0;
    account.lockedUntil = 0;
    await AccountService.persistAccounts();
    return { success: true, message: active ? '账号已启用' : '账号已停用' };
  }

  static async login(username: string, password: string): Promise<LoginResult> {
    const normalizedUsername: string = username.trim().toLowerCase();
    const account: StoredAccount | undefined = AccountService.accounts.find(
      (item: StoredAccount) => item.username.toLowerCase() === normalizedUsername && item.active
    );
    if (account === undefined) {
      return { success: false, message: '账号或密码错误' };
    }
    if (account.lockedUntil > Date.now()) {
      return { success: false, message: '登录已暂时锁定，请 5 分钟后重试或联系管理员' };
    }
    if (!AccountService.verifyPassword(password, account)) {
      account.failedAttempts++;
      if (account.failedAttempts >= AccountService.MAX_FAILED_ATTEMPTS) {
        account.failedAttempts = 0;
        account.lockedUntil = Date.now() + AccountService.LOCK_DURATION_MILLIS;
      }
      await AccountService.persistAccounts();
      return { success: false, message: '账号或密码错误' };
    }
    account.failedAttempts = 0;
    account.lockedUntil = 0;
    await AccountService.persistAccounts();
    AccountService.currentUser = account.user;
    if (AccountService.pref !== null) {
      await AccountService.pref.put(AccountService.KEY_CURRENT_USER_ID, account.user.id);
      await AccountService.pref.flush();
    }
    return { success: true, message: '登录成功', user: account.user };
  }

  static async logout(): Promise<void> {
    AccountService.currentUser = null;
    if (AccountService.pref !== null) {
      await AccountService.pref.put(AccountService.KEY_CURRENT_USER_ID, '');
      await AccountService.pref.flush();
    }
  }

  static async changePassword(oldPassword: string, newPassword: string): Promise<LoginResult> {
    if (AccountService.currentUser === null) {
      return { success: false, message: '请先登录' };
    }
    if (newPassword.length < AccountService.MIN_PASSWORD_LENGTH) {
      return { success: false, message: '新密码至少需要 10 位' };
    }
    const account: StoredAccount | undefined = AccountService.accounts.find(
      (item: StoredAccount) => item.user.id === AccountService.currentUser?.id
    );
    if (account === undefined || !AccountService.verifyPassword(oldPassword, account)) {
      return { success: false, message: '原密码错误' };
    }
    const salt: Uint8Array = cryptoFramework.createRandom().generateRandomSync(16).data;
    account.passwordSalt = AccountService.bytesToHex(salt);
    account.passwordHash = AccountService.derivePassword(newPassword, salt);
    await AccountService.persistAccounts();
    return { success: true, message: '密码修改成功' };
  }

  /** 仅供无系统 API 的本地业务测试注入身份。 */
  static setCurrentUserForTest(user: User | null): void {
    AccountService.currentUser = user;
  }

  private static createAccount(
    id: string,
    username: string,
    name: string,
    role: UserRole,
    password: string
  ): StoredAccount {
    const salt: Uint8Array = cryptoFramework.createRandom().generateRandomSync(16).data;
    return {
      user: { id: id, name: name, role: role },
      username: username,
      passwordSalt: AccountService.bytesToHex(salt),
      passwordHash: AccountService.derivePassword(password, salt),
      active: true,
      failedAttempts: 0,
      lockedUntil: 0
    };
  }

  private static verifyPassword(password: string, account: StoredAccount): boolean {
    return AccountService.verifySecret(password, account.passwordHash, account.passwordSalt);
  }

  private static verifySecret(secret: string, expectedHash: string, saltHex: string): boolean {
    const actualHash: string = AccountService.derivePassword(secret, AccountService.hexToBytes(saltHex));
    if (actualHash.length !== expectedHash.length) {
      return false;
    }
    let difference: number = 0;
    for (let i: number = 0; i < actualHash.length; i++) {
      difference |= actualHash.charCodeAt(i) ^ expectedHash.charCodeAt(i);
    }
    return difference === 0;
  }

  private static findByUsername(username: string): StoredAccount | undefined {
    const normalized: string = username.trim().toLowerCase();
    return AccountService.accounts.find((item: StoredAccount) => item.username.toLowerCase() === normalized);
  }

  private static validateAccountInput(username: string, name: string, password: string): string {
    if (!/^[a-zA-Z0-9_]{3,32}$/.test(username.trim())) {
      return '账号需为 3—32 位字母、数字或下划线';
    }
    if (name.trim().length < 2 || name.trim().length > 32) {
      return '姓名需为 2—32 个字符';
    }
    if (password.length < AccountService.MIN_PASSWORD_LENGTH) {
      return '密码至少需要 10 位';
    }
    if (!/[a-zA-Z]/.test(password) || !/[0-9]/.test(password)) {
      return '密码须同时包含字母和数字';
    }
    return '';
  }

  private static createUserId(prefix: string): string {
    const random: Uint8Array = cryptoFramework.createRandom().generateRandomSync(8).data;
    return prefix + '_' + Date.now().toString(36) + '_' + AccountService.bytesToHex(random);
  }

  private static async persistCurrentUserId(): Promise<void> {
    if (AccountService.pref === null || AccountService.currentUser === null) {
      return;
    }
    await AccountService.pref.put(AccountService.KEY_CURRENT_USER_ID, AccountService.currentUser.id);
    await AccountService.pref.flush();
  }

  private static derivePassword(password: string, salt: Uint8Array): string {
    const kdf: cryptoFramework.Kdf = cryptoFramework.createKdf('PBKDF2|SHA256');
    const spec: cryptoFramework.PBKDF2Spec = {
      algName: 'PBKDF2|SHA256',
      password: password,
      salt: salt,
      iterations: AccountService.ITERATIONS,
      keySize: AccountService.KEY_SIZE
    };
    return AccountService.bytesToHex(kdf.generateSecretSync(spec).data);
  }

  private static bytesToHex(data: Uint8Array): string {
    let result: string = '';
    data.forEach((value: number) => {
      result += value.toString(16).padStart(2, '0');
    });
    return result;
  }

  private static hexToBytes(value: string): Uint8Array {
    const result: Uint8Array = new Uint8Array(value.length / 2);
    for (let i: number = 0; i < result.length; i++) {
      result[i] = parseInt(value.substring(i * 2, i * 2 + 2), 16);
    }
    return result;
  }

  private static async persistAccounts(): Promise<void> {
    if (AccountService.pref === null) {
      return;
    }
    await AccountService.pref.put(AccountService.KEY_ACCOUNTS, JSON.stringify(AccountService.accounts));
    await AccountService.pref.flush();
  }

  private static async persistInvitations(): Promise<void> {
    if (AccountService.pref === null) {
      return;
    }
    const activeInvitations: StoredInternalInvitation[] = AccountService.invitations.filter(
      (item: StoredInternalInvitation) => item.usedAt === 0 && item.expiresAt > Date.now()
    );
    AccountService.invitations = activeInvitations;
    await AccountService.pref.put(AccountService.KEY_INVITATIONS, JSON.stringify(activeInvitations));
    await AccountService.pref.flush();
  }
}
