import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * 应急联系电话持久化服务（C 模块）
 *
 * 使用 Preferences 保存用户配置的紧急联系电话，
 * 供首页「一键求助」读取并用于短信与拨号。
 */
export class EmergencyContactService {
  private static readonly PREF_NAME: string = 'emergency_contact';
  private static readonly KEY_PHONE: string = 'phone';

  static async getPhone(context: common.Context): Promise<string> {
    const pref: preferences.Preferences =
      await preferences.getPreferences(context, EmergencyContactService.PREF_NAME);
    const value: preferences.ValueType =
      await pref.get(EmergencyContactService.KEY_PHONE, '');
    return value as string;
  }

  static async savePhone(context: common.Context, phone: string): Promise<void> {
    const pref: preferences.Preferences =
      await preferences.getPreferences(context, EmergencyContactService.PREF_NAME);
    await pref.put(EmergencyContactService.KEY_PHONE, phone);
    await pref.flush();
  }
}
