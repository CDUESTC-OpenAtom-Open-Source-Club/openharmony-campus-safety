import { formBindingData, formProvider } from '@kit.FormKit';
import { AccountService } from './AccountService';
import { EventRepository } from '../repository/EventRepository';
import { EventStatus } from '../model/SecurityEvent';
import { TaskStatus } from '../model/Task';
import { User, UserRole } from '../model/User';

export interface CampusSafetyCardBindingData {
  headline: string;
  primary: string;
  secondary: string;
  hint: string;
}

/**
 * 服务卡片数据只从当前账号和本地持久化缓存中汇总，不预置或伪造业务统计。
 */
export class CampusSafetyCardService {
  static createBindingData(): CampusSafetyCardBindingData {
    const user: User | null = AccountService.getCurrentUser();
    const repository: EventRepository = EventRepository.getInstance();
    if (user === null) {
      return CampusSafetyCardService.createEmptyData('打开应用登录后查看安全动态');
    }
    if (!repository.isLoaded()) {
      return CampusSafetyCardService.createEmptyData('正在读取本地安全数据');
    }

    if (user.role === UserRole.ADMIN) {
      const pendingCount: number = repository.getEvents()
        .filter((event) => event.status === EventStatus.PENDING).length;
      const reviewCount: number = repository.getAllTasks()
        .filter((task) => task.status === TaskStatus.REVIEW).length;
      return CampusSafetyCardService.createData(
        '管理员安全概览',
        '待确认 ' + pendingCount + ' 项',
        '待审核处置任务 ' + reviewCount + ' 项'
      );
    }

    if (user.role === UserRole.SECURITY) {
      const myTasks = repository.getAllTasks().filter((task) => task.assignee === user.id);
      const pendingCount: number = myTasks
        .filter((task) => task.status === TaskStatus.PENDING || task.status === TaskStatus.PROCESSING).length;
      const reviewCount: number = myTasks
        .filter((task) => task.status === TaskStatus.REVIEW).length;
      return CampusSafetyCardService.createData(
        '我的处置任务',
        '待处理 ' + pendingCount + ' 项',
        '待审核 ' + reviewCount + ' 项'
      );
    }

    const myEvents = repository.getEvents().filter((event) => event.reporterId === user.id);
    const activeCount: number = myEvents
      .filter((event) => event.status !== EventStatus.COMPLETED).length;
    return CampusSafetyCardService.createData(
      '我的安全上报',
      '处理中 ' + activeCount + ' 项',
      myEvents.length === 0 ? '暂未提交安全上报' : '累计上报 ' + myEvents.length + ' 项'
    );
  }

  static async refreshPublishedCards(): Promise<void> {
    try {
      const runningForms = await formProvider.getPublishedRunningFormInfos();
      const bindingData = formBindingData.createFormBindingData(CampusSafetyCardService.createBindingData());
      await Promise.all(runningForms.map((form) => formProvider.updateForm(form.formId, bindingData)));
    } catch (error) {
      console.error('CampusSafetyCardService refresh failed: ' + JSON.stringify(error));
    }
  }

  private static createEmptyData(detail: string): CampusSafetyCardBindingData {
    return CampusSafetyCardService.createData('校园安全', '暂无可展示的业务数据', detail);
  }

  private static createData(headline: string, primary: string, secondary: string): CampusSafetyCardBindingData {
    return {
      headline: headline,
      primary: primary,
      secondary: secondary,
      hint: '点击打开鸿蒙智安'
    };
  }
}
