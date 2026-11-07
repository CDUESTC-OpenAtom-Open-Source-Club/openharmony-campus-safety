import { common } from '@kit.AbilityKit';
import { AssistantTimeService } from './AssistantTimeService';
import { AssistantReminderService } from './AssistantReminderService';
import { AccountService } from './AccountService';
import { ScheduleService } from './ScheduleService';
import { CountdownService } from './CountdownService';
import { Course, CourseColor } from '../model/Course';
import { AssistantToolCall } from './AssistantToolProtocol';
import { AssistantDataService } from './AssistantDataService';

interface AssistantCommand {
  kind: string; title: string; date: string; time: string; weekday: number;
  start: number; end: number; location: string; question: string; operation: string;
}
export interface AssistantToolResult { text: string; changed: boolean; route: string; }

/** Executes validated model calls and explicit shortcuts. Contains no natural-language intent parser. */
export class AssistantToolExecutor {
  private static busy: boolean = false;
  private static sequence: number = 0;
  private static readonly TIMES: string[][] = [
    ['08:15', '09:00'], ['09:05', '09:50'], ['10:05', '10:50'], ['10:55', '11:40'],
    ['14:00', '14:45'], ['14:50', '15:35'], ['15:50', '16:35'], ['16:40', '17:25']
  ];

  private static string(value: string | undefined, field: string, max: number = 60): string {
    if (typeof value !== 'string' || value.trim() === '' || value.length > max) throw new Error('参数缺失或无效：' + field);
    return value.trim();
  }

  private static integer(value: number | undefined, field: string, max: number): number {
    if (typeof value !== 'number' || !Number.isInteger(value) || value < 1 || value > max) throw new Error('参数缺失或无效：' + field);
    return value;
  }

  static async execute(context: common.UIAbilityContext, owner: string, call: AssistantToolCall): Promise<AssistantToolResult> {
    AssistantToolExecutor.owner(owner);
    const args = call.args;
    if (call.tool === 'safety.tips') {
      return { text: '• 离开房间前检查门窗、电源和用电设备。\n• 保持消防通道畅通，不在室内给电动车或电池充电。\n• 发现设施损坏、异常气味等隐患，及时上报并远离危险区域。\n• 保护密码和验证码，遇到可疑链接或转账要求先核实。', changed: false, route: '' };
    }
    if (call.tool === 'app.read') {
      const scopes: string[] = ['tasks', 'events', 'reminders', 'courses', 'countdowns', 'all'];
      const labels: string[] = ['任务', '事件', '提醒', '课程', '倒计时', '我的安排'];
      const scope: string = AssistantToolExecutor.string(args.scope, 'scope');
      const index: number = scopes.indexOf(scope);
      if (index < 0) throw new Error('无效的数据范围');
      const data = await AssistantDataService.collect(context, owner, labels[index]);
      AssistantToolExecutor.owner(owner);
      return { text: AssistantDataService.describe(data), changed: false, route: '' };
    }
    if (call.tool === 'app.open') {
      const page: string = AssistantToolExecutor.string(args.page, 'page');
      if (!['TaskPage', 'EmergencyContactPage', 'CountdownManagePage'].includes(page)) throw new Error('无效的页面');
      return { text: '正在打开相关页面。', changed: false, route: page };
    }
    const command: AssistantCommand = { kind: '', title: '', date: '', time: '', weekday: 0,
      start: 0, end: 0, location: '', question: '', operation: 'add' };
    if (call.tool === 'reminder.create') {
      command.kind = 'reminder'; command.title = AssistantToolExecutor.string(args.content ?? args.title, '提醒事项');
      command.date = AssistantToolExecutor.string(args.date, '提醒日期'); command.time = AssistantToolExecutor.string(args.time, '提醒时间');
    } else if (call.tool === 'schedule.add') {
      command.kind = 'course'; command.title = AssistantToolExecutor.string(args.name, '课程名称');
      command.weekday = AssistantToolExecutor.integer(args.weekday, '周几', 7);
      command.start = AssistantToolExecutor.integer(args.startPeriod, '开始节次', 8); command.end = AssistantToolExecutor.integer(args.endPeriod, '结束节次', 8);
      command.location = AssistantToolExecutor.string(args.location, '教室');
      if (args.operation !== undefined && args.operation !== 'add' && args.operation !== 'update') throw new Error('无效的课表操作');
      command.operation = args.operation ?? 'add';
    } else if (call.tool === 'countdown.add') {
      command.kind = 'countdown'; command.title = AssistantToolExecutor.string(args.name, '倒计时名称', 20);
      command.date = AssistantToolExecutor.string(args.date, '目标日期');
    } else if (call.tool === 'item.delete') {
      const kinds: string[] = ['reminder', 'course', 'countdown'];
      const targets: string[] = ['cancelReminder', 'removeCourse', 'removeCountdown'];
      const index: number = kinds.indexOf(AssistantToolExecutor.string(args.kind, '事项类型'));
      if (index < 0) throw new Error('无效的删除类型');
      command.kind = targets[index]; command.title = AssistantToolExecutor.string(args.name, '完整事项名称');
    } else { throw new Error('无效的工具调用'); }
    const text = await AssistantToolExecutor.executeCommand(context, owner, command);
    AssistantToolExecutor.owner(owner);
    return { text: text, changed: true, route: '' };
  }

  private static owner(owner: string): void {
    if (owner === '' || AccountService.getCurrentUser()?.id !== owner) throw new Error('账号已变化，请重新发送');
  }

  private static async executeCommand(context: common.UIAbilityContext, owner: string, command: AssistantCommand): Promise<string> {
    AssistantToolExecutor.owner(owner);
    if (command.question !== '' || command.kind === '') throw new Error('还缺少操作信息');
    if (AssistantToolExecutor.busy) throw new Error('正在处理上一项操作');
    AssistantToolExecutor.busy = true;
    try {
      if (command.kind === 'reminder') {
        await AssistantReminderService.create(context, owner, command.title, command.date, command.time);
        AssistantToolExecutor.owner(owner);
        return '已设置提醒：' + command.date + ' ' + command.time + '，' + command.title + '。';
      }
      if (command.kind === 'cancelReminder') {
        const items = await AssistantReminderService.list(context, owner);
        const matches = items.filter((item) => item.title === command.title);
        if (matches.length !== 1) throw new Error(matches.length === 0 ? '没有找到这条提醒，请提供完整名称' : '有多条同名提醒，请在提醒列表中选择要取消的一条');
        await AssistantReminderService.cancel(context, owner, matches[0].id);
        return '已取消提醒：' + command.title + '。';
      }
      if (command.kind === 'course' || command.kind === 'removeCourse') {
        const courses = await ScheduleService.getCourses(context);
        AssistantToolExecutor.owner(owner);
        if (command.kind === 'removeCourse') {
          const matches = courses.filter((course: Course) => course.name === command.title);
          if (matches.length !== 1) throw new Error(matches.length === 0 ? '没有找到这门课，请提供完整课程名称' : '这门课每周有多次安排，请在课表中选择要删除的一次');
          await ScheduleService.saveCourses(context, courses.filter((course: Course) => course.id !== matches[0].id));
          return '已删除课程：' + command.title + '。';
        }
        if (!Number.isInteger(command.weekday) || !Number.isInteger(command.start) || !Number.isInteger(command.end) ||
          command.weekday < 1 || command.weekday > 7 || command.start < 1 || command.end > 8 || command.end < command.start ||
          command.title.trim() === '' || command.title.length > 60 || command.location.trim() === '' || command.location.length > 60) throw new Error('课程信息不完整');
        const matches = courses.filter((course: Course) => course.name === command.title);
        if (command.operation === 'update' && matches.length !== 1) throw new Error('请提供唯一的课程名称，以免修改错误的安排');
        const same: Course | undefined = command.operation === 'update' ? matches[0] : undefined;
        if (command.operation !== 'update' && courses.some((course: Course) => course.name === command.title &&
          course.weekday === command.weekday && course.startPeriod === command.start && course.endPeriod === command.end && course.location === command.location)) {
          return '课表里已经有这项安排，无需重复添加。';
        }
        if (courses.some((course: Course) => course.id !== same?.id && course.weekday === command.weekday &&
          course.startPeriod <= command.end && course.endPeriod >= command.start)) throw new Error('这个时段已有其他课程，请告诉我另一个节次');
        const course: Course = { id: same?.id ?? 'course_' + Date.now() + '_' + (++AssistantToolExecutor.sequence), name: command.title, location: command.location,
          weekday: command.weekday, startPeriod: command.start, endPeriod: command.end,
          startTime: AssistantToolExecutor.TIMES[command.start - 1][0], endTime: AssistantToolExecutor.TIMES[command.end - 1][1], color: same?.color ?? CourseColor.BLUE };
        const next: Course[] = courses.filter((item: Course) => item.id !== course.id).concat([course]);
        await ScheduleService.saveCourses(context, next);
        AssistantToolExecutor.owner(owner);
        return '已' + (same === undefined ? '添加' : '更新') + '课程：' + command.title + '，周' + '一二三四五六日'.charAt(command.weekday - 1) +
          '第' + command.start + (command.end === command.start ? '' : '—' + command.end) + '节，' + command.location + '。';
      }
      if (command.kind === 'countdown' || command.kind === 'removeCountdown') {
        const items = await CountdownService.getEvents(context);
        AssistantToolExecutor.owner(owner);
        const matches = items.filter((item) => item.name === command.title);
        if (command.kind === 'removeCountdown') {
          if (matches.length !== 1) throw new Error('请提供唯一、完整的倒计时名称');
          await CountdownService.saveEvents(context, items.filter((item) => item.id !== matches[0].id));
          return '已删除倒计时：' + command.title + '。';
        }
        if (command.title.trim() === '' || command.title.length > 20 || AssistantTimeService.timestamp(command.date, '00:00') <= 0) throw new Error('倒计时信息不完整');
        if (matches.length > 1) throw new Error('有多条同名倒计时，请先在倒计时页区分名称');
        const id: string = matches[0]?.id ?? 'countdown_' + Date.now() + '_' + (++AssistantToolExecutor.sequence);
        const next = items.filter((item) => item.id !== id);
        next.push({ id: id, name: command.title, date: command.date, tag: matches[0]?.tag ?? '' });
        await CountdownService.saveEvents(context, next);
        AssistantToolExecutor.owner(owner);
        return '已设置倒计时：' + command.title + '，' + command.date + '。';
      }
      throw new Error('暂不支持这项操作，请具体说明要做什么');
    } finally { AssistantToolExecutor.busy = false; }
  }
}
