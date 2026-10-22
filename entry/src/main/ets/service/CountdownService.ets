import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { CountdownEvent } from '../model/CountdownEvent';

export class CountdownService {
  private static readonly PREF_NAME: string = 'countdown_events';
  private static readonly KEY_EVENTS: string = 'countdown_events_v1';

  // 读取已保存的倒计时事件
  static async getEvents(
    context: common.Context
  ): Promise<CountdownEvent[]> {
    const pref = await preferences.getPreferences(
      context,
      CountdownService.PREF_NAME
    );

    const raw = await pref.get(CountdownService.KEY_EVENTS, '');

    if (typeof raw !== 'string' || raw.length === 0) {
      return [];
    }

    try {
      const parsed: CountdownEvent[] =
        JSON.parse(raw) as CountdownEvent[];

      if (Array.isArray(parsed)) {
        return (parsed as CountdownEvent[]).filter(
          (event: CountdownEvent) =>
            typeof event.id === 'string' &&
            typeof event.name === 'string' &&
            typeof event.date === 'string' &&
            /^\d{4}-\d{2}-\d{2}$/.test(event.date) &&
            typeof event.tag === 'string'
        );
      }
    } catch (error) {
      console.error(
        '读取倒计时数据失败：' + JSON.stringify(error)
      );
    }

    return [];
  }

  // 保存全部倒计时事件
  static async saveEvents(
    context: common.Context,
    events: CountdownEvent[]
  ): Promise<void> {
    const pref = await preferences.getPreferences(
      context,
      CountdownService.PREF_NAME
    );

    await pref.put(
      CountdownService.KEY_EVENTS,
      JSON.stringify(events)
    );

    await pref.flush();
  }

  // 计算距离目标日期还剩多少个自然日
  static daysLeft(dateStr: string): number {
    const now = new Date();

    const today = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate()
    );

    const target = new Date(dateStr + 'T00:00:00');

    return Math.round(
      (target.getTime() - today.getTime()) / 86400000
    );
  }

  // 将日期转换成 YYYY-MM-DD 格式
  static toDateString(date: Date): string {
    const year = date.getFullYear().toString();
    const month = ('0' + (date.getMonth() + 1)).slice(-2);
    const day = ('0' + date.getDate()).slice(-2);

    return year + '-' + month + '-' + day;
  }

  // 生成日期说明，例如：12月19日 周六 · 笔试
  static formatDateLine(event: CountdownEvent): string {
    const date = new Date(event.date + 'T00:00:00');

    const weekdays: string[] = [
      '周日', '周一', '周二', '周三',
      '周四', '周五', '周六'
    ];

    const dateText =
      (date.getMonth() + 1) + '月' +
      date.getDate() + '日 ' +
      weekdays[date.getDay()];

    return event.tag.trim() === ''
      ? dateText
      : dateText + ' · ' + event.tag;
  }

  // 今天显示“今天”，明天显示“明天”，其他日期显示数字
  static dayText(days: number): string {
    if (days < 0) {
      return '已结束';
    }

    if (days === 0) {
      return '今天';
    }

    if (days === 1) {
      return '明天';
    }

    return days.toString();
  }

  // 首页使用：过滤过期事件，按剩余天数排序，最多显示四条
  static getHomeList(
    events: CountdownEvent[]
  ): CountdownEvent[] {
    return events
      .filter((event: CountdownEvent) =>
        CountdownService.daysLeft(event.date) >= 0
      )
      .sort((a: CountdownEvent, b: CountdownEvent) =>
        CountdownService.daysLeft(a.date) -
        CountdownService.daysLeft(b.date)
      )
      .slice(0, 4);
  }

  // 管理页使用：过期事件保留，并排在列表最后
  static getManagementList(
    events: CountdownEvent[]
  ): CountdownEvent[] {
    return events.slice().sort(
      (a: CountdownEvent, b: CountdownEvent) => {
        const daysA = CountdownService.daysLeft(a.date);
        const daysB = CountdownService.daysLeft(b.date);

        if (daysA < 0 && daysB >= 0) {
          return 1;
        }

        if (daysA >= 0 && daysB < 0) {
          return -1;
        }

        return daysA - daysB;
      }
    );
  }
}