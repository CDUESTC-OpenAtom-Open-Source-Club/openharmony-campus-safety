import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Course, DEMO_COURSES } from '../model/Course';

/** 学生课表本地持久化服务：每个学生设备本地保存一份课表。 */
export class ScheduleService {
  private static readonly PREF_NAME: string = 'student_schedule';
  private static readonly KEY_COURSES: string = 'courses';

  static async getCourses(context: common.Context): Promise<Course[]> {
    const pref: preferences.Preferences = await preferences.getPreferences(
      context,
      ScheduleService.PREF_NAME
    );
    const raw: preferences.ValueType = await pref.get(ScheduleService.KEY_COURSES, '');
    if (typeof raw !== 'string' || raw.length === 0) {
      const initial: Course[] = DEMO_COURSES.slice();
      await ScheduleService.saveCourses(context, initial);
      return initial;
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
    const pref: preferences.Preferences = await preferences.getPreferences(
      context,
      ScheduleService.PREF_NAME
    );
    await pref.put(ScheduleService.KEY_COURSES, JSON.stringify(courses));
    await pref.flush();
  }
}
