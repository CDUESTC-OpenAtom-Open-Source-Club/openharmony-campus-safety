import { common } from '@kit.AbilityKit';
import { AccountService } from './AccountService';
import { RepositoryManager } from '../repository/RepositoryManager';

/** Keep a single initialization in flight; a retry cannot open a second store. */
export class StartupService {
  private static pending: Promise<void> | null = null;
  static stage: string = '正在读取本机账号';

  static initialize(context: common.Context): Promise<void> {
    if (StartupService.pending !== null) return StartupService.pending;
    StartupService.pending = StartupService.run(context);
    return StartupService.pending;
  }

  private static async run(context: common.Context): Promise<void> {
    try {
      StartupService.stage = '正在读取本机账号';
      await AccountService.init(context);
      StartupService.stage = '正在打开本地事件与任务数据库';
      await RepositoryManager.init(context);
      StartupService.stage = '本地数据已就绪';
    } catch (_) {
      StartupService.pending = null;
      throw new Error('本地数据初始化失败，原有数据未清除，请重试');
    }
  }
}
