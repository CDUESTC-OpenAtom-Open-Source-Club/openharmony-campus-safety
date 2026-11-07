import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

export interface AiConfig { endpoint: string; model: string; apiKey: string; }

/** One atomic encrypted asset per account; never write API keys to Preferences. */
export class AiConfigService {
  private static sessionOwner: string = '';
  private static sessionConfig: AiConfig | null = null;
  private static generation: number = 0;

  static clearSession(): void {
    AiConfigService.generation++;
    AiConfigService.sessionOwner = ''; AiConfigService.sessionConfig = null;
  }

  static validate(config: AiConfig): string {
    if (typeof config.endpoint !== 'string' ||
      !/^https:\/\/[a-zA-Z0-9.-]+(?::\d{1,5})?\/(?:[a-zA-Z0-9_./~-]+\/)?chat\/completions$/.test(config.endpoint)) {
      return '请填写 HTTPS 的完整 chat/completions 地址，不含查询参数或账号信息';
    }
    if (config.endpoint.length > 300 || config.endpoint.includes('/../') || config.endpoint.includes('/./')) return '服务地址过长或路径无效';
    if (typeof config.model !== 'string' || !/^[a-zA-Z0-9_.:/-]{1,100}$/.test(config.model)) return '请填写有效模型 ID（最多 100 字符）';
    if (typeof config.apiKey !== 'string' || config.apiKey.length < 1 || config.apiKey.length > 512 || /\s/.test(config.apiKey)) {
      return '请填写有效 API Key（最多 512 字符，不含空白）';
    }
    return '';
  }

  static retainedKey(endpoint: string, saved: AiConfig | null): string {
    return saved !== null && saved.endpoint === endpoint ? saved.apiKey : '';
  }

  private static queryFor(owner: string): asset.AssetMap {
    if (!/^[a-zA-Z0-9_-]{1,100}$/.test(owner)) throw new Error('请先登录 App 账号');
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto('campus_ai_' + owner));
    return query;
  }

  static async load(context: common.Context, owner: string): Promise<AiConfig | null> {
    const pref = await preferences.getPreferences(context, 'ai_auth_preferences');
    await pref.delete('ai_access_token'); await pref.flush();
    if (AiConfigService.sessionOwner === owner && AiConfigService.sessionConfig !== null) return AiConfigService.sessionConfig;
    if (!canIUse('SystemCapability.Security.Asset')) return null;
    const query: asset.AssetMap = AiConfigService.queryFor(owner);
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    let items: asset.AssetMap[];
    try { items = await asset.query(query); }
    catch (error) {
      if ((error as BusinessError).code === 24000002) return null;
      throw new Error('安全存储不可用或已锁定；可选择“仅本次使用”');
    }
    if (items.length === 0) return null;
    const secret = items[0].get(asset.Tag.SECRET);
    if (!(secret instanceof Uint8Array)) throw new Error('保存的配置无法读取，请清除后重新配置');
    const config = JSON.parse(new util.TextDecoder().decodeToString(secret)) as AiConfig;
    if (AiConfigService.validate(config) !== '') throw new Error('保存的配置无效，请重新配置');
    return config;
  }

  static async save(owner: string, config: AiConfig, remember: boolean): Promise<void> {
    const generation: number = AiConfigService.generation;
    const validation: string = AiConfigService.validate(config);
    if (validation !== '') throw new Error(validation);
    const query: asset.AssetMap = AiConfigService.queryFor(owner);
    if (remember) {
      if (!canIUse('SystemCapability.Security.Asset')) throw new Error('当前设备不支持安全存储，请选择仅本次使用');
      const bytes: Uint8Array = new util.TextEncoder().encodeInto(JSON.stringify(config));
      if (bytes.length > 1024) throw new Error('配置总长度超出安全存储限制，请缩短地址或模型 ID');
      query.set(asset.Tag.SECRET, bytes);
      query.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
      query.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER);
      query.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
      await asset.add(query);
    } else {
      await AiConfigService.remove(owner, false);
    }
    if (generation !== AiConfigService.generation) return;
    AiConfigService.sessionOwner = owner;
    AiConfigService.sessionConfig = { endpoint: config.endpoint, model: config.model, apiKey: config.apiKey };
  }

  static async remove(owner: string, clearSession: boolean = true): Promise<void> {
    const query: asset.AssetMap = AiConfigService.queryFor(owner);
    try { if (canIUse('SystemCapability.Security.Asset')) await asset.remove(query); }
    catch (error) {
      if ((error as BusinessError).code !== 24000002) throw new Error('无法清除安全存储，请解锁设备后重试');
    }
    if (clearSession && AiConfigService.sessionOwner === owner) AiConfigService.clearSession();
  }
}
