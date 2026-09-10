import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * 应急联系电话持久化服务（C 模块）
 *
 * 使用 Preferences 保存用户手动配置的紧急联系电话。
 * 它不是学校保卫处或任何应急平台的接入信息；首页只会交给系统短信编辑或拨号界面处理。
 */
export class EmergencyContactService {
  private static readonly PREF_NAME: string = 'emergency_contact';
  private static readonly KEY_PHONE: string = 'phone';
  private static currentPhone: string = '';

  static normalizePhone(phone: string): string {
    return phone.trim().replace(/[\s-]/g, '');
  }

  static isValidPhone(phone: string): boolean {
    return /^\+?[0-9]{6,20}$/.test(EmergencyContactService.normalizePhone(phone));
  }

  static async getPhone(context: common.Context): Promise<string> {
    if (EmergencyContactService.currentPhone !== '') {
      return EmergencyContactService.currentPhone;
    }
    const pref: preferences.Preferences =
      await preferences.getPreferences(context, EmergencyContactService.PREF_NAME);
    const value: preferences.ValueType =
      await pref.get(EmergencyContactService.KEY_PHONE, '');
    EmergencyContactService.currentPhone = value as string;
    return EmergencyContactService.currentPhone;
  }

  static async savePhone(context: common.Context, phone: string): Promise<boolean> {
    const normalized: string = EmergencyContactService.normalizePhone(phone);
    if (!EmergencyContactService.isValidPhone(normalized)) {
      return false;
    }
    EmergencyContactService.currentPhone = normalized;
    const pref: preferences.Preferences =
      await preferences.getPreferences(context, EmergencyContactService.PREF_NAME);
    await pref.put(EmergencyContactService.KEY_PHONE, normalized);
    await pref.flush();
    return true;
  }
}
