import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AccountService } from './AccountService';

/** Old device-wide records have no provable owner. Only an explicit page action can claim them. */
export class PersonalDataMigrationService {
  private static busy: boolean = false;

  static async pending(context: common.Context, prefName: string, key: string): Promise<boolean> {
    const owner: string = AccountService.getCurrentUser()?.id ?? '';
    if (owner === '') return false;
    const pref = await preferences.getPreferences(context, prefName);
    const legacy = await pref.get(key, '');
    return typeof legacy === 'string' && legacy !== '' && legacy !== '[]' &&
      await pref.get(key + '_legacy_owner', '') === '' && await pref.get(key + '_' + owner, '') === '' &&
      AccountService.getCurrentUser()?.id === owner;
  }

  static async claim(context: common.Context, prefName: string, key: string, owner: string): Promise<void> {
    if (PersonalDataMigrationService.busy || owner === '' || AccountService.getCurrentUser()?.id !== owner) throw new Error('账号已变化或正在导入');
    PersonalDataMigrationService.busy = true;
    try {
      if (!await PersonalDataMigrationService.pending(context, prefName, key)) throw new Error('没有可导入的旧记录');
      const pref = await preferences.getPreferences(context, prefName);
      const legacy = await pref.get(key, '');
      if (AccountService.getCurrentUser()?.id !== owner) throw new Error('账号已变化');
      await pref.put(key + '_' + owner, legacy);
      await pref.put(key + '_legacy_owner', owner);
      await pref.flush();
    } finally { PersonalDataMigrationService.busy = false; }
  }
}
