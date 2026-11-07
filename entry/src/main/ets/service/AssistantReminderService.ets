import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AccountService } from './AccountService';
import { AssistantTimeService } from './AssistantTimeService';

export interface AssistantReminder { id: number; title: string; at: number; }

/** System-backed one-shot reminders, indexed by local App account. */
export class AssistantReminderService {
  private static busy: boolean = false;

  private static assertOwner(owner: string): void {
    if (owner === '' || AccountService.getCurrentUser()?.id !== owner) throw new Error('账号已变化，请重新打开助手');
    if (!canIUse('SystemCapability.Notification.ReminderAgent')) throw new Error('当前设备不支持系统代理提醒');
  }

  private static async store(context: common.Context): Promise<preferences.Preferences> {
    return preferences.getPreferences(context, 'assistant_reminders');
  }

  static async list(context: common.Context, owner: string): Promise<AssistantReminder[]> {
    AssistantReminderService.assertOwner(owner);
    const pref = await AssistantReminderService.store(context);
    const raw = await pref.get(owner, '[]');
    const items = JSON.parse(typeof raw === 'string' ? raw : '[]') as AssistantReminder[];
    if (!Array.isArray(items)) throw new Error('提醒记录无法读取');
    return items.filter((item: AssistantReminder) => Number.isInteger(item.id) &&
      typeof item.title === 'string' && Number.isFinite(item.at)).sort((a: AssistantReminder, b: AssistantReminder) => a.at - b.at);
  }

  static async create(context: common.UIAbilityContext, owner: string, title: string, date: string, time: string): Promise<void> {
    if (AssistantReminderService.busy) throw new Error('正在处理提醒，请稍后重试');
    AssistantReminderService.busy = true;
    let published: number = -1;
    let original: AssistantReminder[] = [];
    try {
      AssistantReminderService.assertOwner(owner);
      const at: number = AssistantTimeService.timestamp(date, time);
      if (title.trim().length === 0 || title.trim().length > 60) throw new Error('事项需要 1—60 个字符');
      if (at < Date.now() + 60000) throw new Error('请选择至少一分钟后的有效日期和时间');
      const items: AssistantReminder[] = await AssistantReminderService.list(context, owner);
      original = items;
      if (items.filter((item: AssistantReminder) => item.at > Date.now()).length >= 20) throw new Error('最多保留 20 条待提醒事项，请先取消部分提醒');
      if (!(await notificationManager.isNotificationEnabled())) await notificationManager.requestEnableNotification(context);
      if (!(await notificationManager.isNotificationEnabled())) throw new Error('通知尚未开启，提醒未创建');
      AssistantReminderService.assertOwner(owner);
      const target = new Date(at);
      const request: reminderAgentManager.ReminderRequestCalendar = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
        dateTime: { year: target.getFullYear(), month: target.getMonth() + 1, day: target.getDate(),
          hour: target.getHours(), minute: target.getMinutes(), second: 0 },
        title: '校安通 · 本机提醒', content: title.trim(), expiredContent: title.trim(), ringDuration: 0,
        notificationId: Math.floor(Date.now() % 2000000000),
        slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION
      };
      published = await reminderAgentManager.publishReminder(request);
      AssistantReminderService.assertOwner(owner);
      const next: AssistantReminder[] = items.filter((item: AssistantReminder) => item.at > Date.now());
      next.push({ id: published, title: title.trim(), at: at });
      const pref = await AssistantReminderService.store(context);
      await pref.put(owner, JSON.stringify(next)); await pref.flush();
    } catch (error) {
      if (published >= 0) {
        try { await reminderAgentManager.cancelReminder(published); }
        catch (_) { throw new Error('记录保存失败且未能撤销系统提醒，请在系统通知中检查'); }
        try {
          const pref = await AssistantReminderService.store(context);
          await pref.put(owner, JSON.stringify(original)); await pref.flush();
        } catch (_) { /* The system reminder is already canceled; do not claim successful creation. */ }
      }
      throw new Error((error as Error).message || '系统提醒创建失败');
    } finally { AssistantReminderService.busy = false; }
  }

  static async cancel(context: common.Context, owner: string, id: number): Promise<void> {
    if (AssistantReminderService.busy) throw new Error('正在处理提醒，请稍后重试');
    AssistantReminderService.busy = true;
    try {
      const items: AssistantReminder[] = await AssistantReminderService.list(context, owner);
      const target: AssistantReminder | undefined = items.find((item: AssistantReminder) => item.id === id);
      if (target === undefined) throw new Error('当前账号没有这条提醒');
      AssistantReminderService.assertOwner(owner);
      if (target.at > Date.now()) {
        try { await reminderAgentManager.cancelReminder(id); }
        catch (error) { if ((error as BusinessError).code !== 1700003) throw new Error('系统提醒取消失败'); }
      }
      const pref = await AssistantReminderService.store(context);
      await pref.put(owner, JSON.stringify(items.filter((item: AssistantReminder) => item.id !== id))); await pref.flush();
    } finally { AssistantReminderService.busy = false; }
  }
}
