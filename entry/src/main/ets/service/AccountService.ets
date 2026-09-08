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
}

export interface LoginResult {
  success: boolean;
  message: string;
  user?: User;
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
  private static readonly KEY_CURRENT_USER_ID: string = 'currentUserId';
  private static readonly ITERATIONS: number = 120000;
  private static readonly KEY_SIZE: number = 32;
  private static accounts: StoredAccount[] = [];
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
        }
      } catch (error) {
        console.error('AccountService account data parse failed: ' + JSON.stringify(error));
      }
    }
    if (AccountService.accounts.length === 0) {
      AccountService.accounts = AccountService.buildBetaAccounts();
      await AccountService.persistAccounts();
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

  static async login(username: string, password: string): Promise<LoginResult> {
    const normalizedUsername: string = username.trim().toLowerCase();
    const account: StoredAccount | undefined = AccountService.accounts.find(
      (item: StoredAccount) => item.username.toLowerCase() === normalizedUsername && item.active
    );
    if (account === undefined || !AccountService.verifyPassword(password, account)) {
      return { success: false, message: '账号或密码错误' };
    }
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
    if (newPassword.length < 8) {
      return { success: false, message: '新密码至少需要 8 位' };
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
    if (AccountService.accounts.length === 0) {
      AccountService.accounts = AccountService.buildBetaAccounts();
    }
    AccountService.currentUser = user;
  }

  private static buildBetaAccounts(): StoredAccount[] {
    return [
      AccountService.createAccount('admin_001', 'admin', '系统管理员', UserRole.ADMIN, 'admin12345'),
      AccountService.createAccount('inspector_001', 'inspector', '巡检员一号', UserRole.SECURITY, 'inspect123'),
      AccountService.createAccount('student_001', 'student', '测试学生', UserRole.STUDENT, 'student123'),
      AccountService.createAccount('teacher_001', 'teacher', '测试教师', UserRole.TEACHER, 'teacher123')
    ];
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
      active: true
    };
  }

  private static verifyPassword(password: string, account: StoredAccount): boolean {
    const actualHash: string = AccountService.derivePassword(
      password,
      AccountService.hexToBytes(account.passwordSalt)
    );
    if (actualHash.length !== account.passwordHash.length) {
      return false;
    }
    let difference: number = 0;
    for (let i: number = 0; i < actualHash.length; i++) {
      difference |= actualHash.charCodeAt(i) ^ account.passwordHash.charCodeAt(i);
    }
    return difference === 0;
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
}
