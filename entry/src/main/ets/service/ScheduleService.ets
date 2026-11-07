import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Course } from '../model/Course';
import { AccountService } from './AccountService';

/** 学生课表本地持久化服务：每个学生设备本地保存一份课表。 */
export class ScheduleService {
  private static readonly PREF_NAME: string = 'student_schedule';
  private static readonly KEY_COURSES: string = 'courses';

  static async getCourses(context: common.Context): Promise<Course[]> {
    const owner: string = AccountService.getCurrentUser()?.id ?? '';
    if (owner === '') return [];
    const pref: preferences.Preferences = await preferences.getPreferences(
      context,
      ScheduleService.PREF_NAME
    );
    const raw: preferences.ValueType = await pref.get(ScheduleService.KEY_COURSES + '_' + owner, '');
    if (AccountService.getCurrentUser()?.id !== owner) throw new Error('账号已变化');
    if (typeof raw !== 'string' || raw.length === 0) {
      return [];
    }
    try {
      const parsed: object = JSON.parse(raw) as object;
      if (Array.isArray(parsed)) {
        return parsed as Course[];
      }
    } catch (error) {
      console.error('ScheduleService parse failed: ' + JSON.stringify(error));
    }
    return [];
  }

  static async saveCourses(context: common.Context, courses: Course[]): Promise<void> {
    const owner: string = AccountService.getCurrentUser()?.id ?? '';
    if (owner === '') throw new Error('请先登录');
    const pref: preferences.Preferences = await preferences.getPreferences(
      context,
      ScheduleService.PREF_NAME
    );
    if (AccountService.getCurrentUser()?.id !== owner) throw new Error('账号已变化');
    await pref.put(ScheduleService.KEY_COURSES + '_' + owner, JSON.stringify(courses));
    await pref.flush();
  }
}
