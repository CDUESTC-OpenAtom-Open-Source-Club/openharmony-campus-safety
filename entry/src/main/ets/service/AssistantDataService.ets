import { common } from '@kit.AbilityKit';
import { PersonalDataMigrationService } from './PersonalDataMigrationService';
import { AccountService } from './AccountService';
import { EventService } from './EventService';
import { ScheduleService } from './ScheduleService';
import { CountdownService } from './CountdownService';
import { AssistantReminderService } from './AssistantReminderService';
import { UserRole } from '../model/User';
import { AiSafetyService } from './AiSafetyService';

interface AssistantDataItem { title: string; status: string; time: string; }
export interface AssistantDataSnapshot {
  capturedAt: string;
  tasks: AssistantDataItem[];
  events: AssistantDataItem[];
  reminders: AssistantDataItem[];
  courses: AssistantDataItem[];
  countdowns: AssistantDataItem[];
  availability: string[];
}

/** Fresh, read-only, minimal context. Never read the unrestricted task-view list or credentials. */
export class AssistantDataService {
  static describe(data: AssistantDataSnapshot): string {
    const lines: string[] = [];
    const names: string[] = ['任务', '事件', '提醒', '课程', '倒计时'];
    const groups: AssistantDataItem[][] = [data.tasks, data.events, data.reminders, data.courses, data.countdowns];
    groups.forEach((items: AssistantDataItem[], index: number) => {
      if (items.length > 0) {
        lines.push('**' + names[index] + '**');
        items.forEach((item: AssistantDataItem) => lines.push('• ' + item.title + ' · ' + item.status +
          (item.time === '' ? '' : ' · ' + item.time)));
      }
    });
    data.availability.forEach((value: string) => {
      if (/读取失败|未归属/.test(value)) { lines.push(value); return; }
      const count = value.match(/(\d+) 条/);
      const name: string = value.split('：')[0];
      if (count !== null && Number(count[1]) === 0) lines.push(name + '：暂无记录');
      else if (count !== null && Number(count[1]) > 12) lines.push(name + '：共 ' + count[1] + ' 条，本次显示前 12 条');
    });
    return lines.length > 0 ? lines.join('\n') : '暂时没有取得相关记录，请到对应页面查看。';
  }

  static needsData(question: string): boolean {
    return /任务|待办|巡检|处置|工单|上报|隐患|事件|提醒|日程|课程|课表|上课|倒计时|考试|我的安排|今天有什么|明天有什么/.test(question);
  }

  private static assertOwner(owner: string): void {
    if (owner === '' || AccountService.getCurrentUser()?.id !== owner) throw new Error('账号已变化，无法读取数据');
  }

  private static item(title: string, status: string, time: string): AssistantDataItem {
    return { title: AiSafetyService.data(title), status: AiSafetyService.data(status, 32), time: AiSafetyService.data(time, 48) };
  }

  static async collect(context: common.Context, owner: string, question: string): Promise<AssistantDataSnapshot> {
    AssistantDataService.assertOwner(owner);
    const data: AssistantDataSnapshot = { capturedAt: new Date().toISOString(), tasks: [], events: [], reminders: [],
      courses: [], countdowns: [], availability: [] };
    const all: boolean = /我的安排|今天有什么|明天有什么/.test(question);
    if (all || /任务|待办|巡检|处置|工单/.test(question)) {
      const user = AccountService.getCurrentUser();
      const items = EventService.getAllTasks().filter((task) => user?.role === UserRole.ADMIN || task.assignee === owner);
      data.tasks = items.slice(0, 12).map((task) => AssistantDataService.item(task.title, task.status, task.deadline ?? ''));
      data.availability.push('任务：可见 ' + items.length + ' 条，展示前 12 条');
    }
    if (all || /上报|隐患|事件/.test(question)) {
      const items = EventService.getAllEvents();
      data.events = items.slice(0, 12).map((event) => AssistantDataService.item(event.title, event.status, event.reportTime));
      data.availability.push('事件：当前权限可见 ' + items.length + ' 条，展示前 12 条');
    }
    if (all || /提醒|日程/.test(question)) {
      try {
        const items = await AssistantReminderService.list(context, owner);
        data.reminders = items.slice(0, 12).map((item) => AssistantDataService.item(item.title,
          item.at > Date.now() ? '待提醒' : '已到期', new Date(item.at).toISOString()));
        data.availability.push('提醒：' + items.length + ' 条本机记录，展示前 12 条；不是送达凭证');
      } catch (_) { data.availability.push('提醒：读取失败，不能当作没有提醒'); }
    }
    if (all || /课程|课表|上课/.test(question)) {
        const items = await ScheduleService.getCourses(context);
        data.courses = items.slice(0, 12).map((item) => AssistantDataService.item(item.name,
          '周' + item.weekday, item.startTime + '—' + item.endTime));
        data.availability.push(await PersonalDataMigrationService.pending(context, 'student_schedule', 'courses') ?
          '课表：存在未归属的旧记录，请在课表页确认导入，不能推断当前账号没有课程' : '课表：' + items.length + ' 条，展示前 12 条');
    }
    if (all || /倒计时|考试/.test(question)) {
        const items = await CountdownService.getEvents(context);
        data.countdowns = items.slice(0, 12).map((item) => AssistantDataService.item(item.name, item.tag, item.date));
        data.availability.push(await PersonalDataMigrationService.pending(context, 'countdown_events', 'countdown_events_v1') ?
          '倒计时：存在未归属的旧记录，请在倒计时页确认导入，不能推断当前账号没有倒计时' : '倒计时：' + items.length + ' 条，展示前 12 条');
    }
    AssistantDataService.assertOwner(owner);
    return data;
  }
}
