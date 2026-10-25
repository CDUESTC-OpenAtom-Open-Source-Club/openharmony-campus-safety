import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { AiConfig } from '../model/AiConfig';
import { AiProtocolService } from './AiProtocolService';
import { AccountService } from './AccountService';

/** Config and secret share one encrypted record: no plaintext Preferences or backup fallback. */
export class AiConfigService {
  private static alias(providerId: string): Uint8Array {
    const id: string | undefined = AccountService.getCurrentUser()?.id;
    if (id === undefined) throw new Error('请先登录后配置 AI 服务');
    return new util.TextEncoder().encodeInto('campus.ai.v1.' + id + '.' + providerId);
  }

  static async load(providerId: string): Promise<AiConfig | null> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, AiConfigService.alias(providerId));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const records: asset.AssetMap[] = await asset.query(query);
      if (records.length === 0) return null;
      const raw: Uint8Array = records[0].get(asset.Tag.SECRET) as Uint8Array;
      const config: AiConfig = JSON.parse(util.TextDecoder.create('utf-8').decodeWithStream(raw)) as AiConfig;
      if (config.providerId !== providerId || AiProtocolService.validate(config) !== '') throw new Error('invalid');
      return config;
    } catch (error) {
      if ((error as BusinessError).code === asset.ErrorCode.NOT_FOUND) return null;
      throw new Error('安全配置读取失败，请解锁设备或删除后重新配置');
    }
  }

  static async save(config: AiConfig): Promise<void> {
    const error: string = AiProtocolService.validate(config);
    if (error !== '') throw new Error(error);
    const record: asset.AssetMap = new Map();
    record.set(asset.Tag.ALIAS, AiConfigService.alias(config.providerId));
    record.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(JSON.stringify(config)));
    record.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
    record.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER);
    record.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
    try { await asset.add(record); } catch (_) { throw new Error('安全存储不可用，未保存密钥；请解锁设备后重试'); }
  }

  static async remove(providerId: string): Promise<void> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, AiConfigService.alias(providerId));
    try { await asset.remove(query); } catch (error) {
      if ((error as BusinessError).code !== asset.ErrorCode.NOT_FOUND) throw new Error('配置删除失败，请解锁设备后重试');
    }
  }
}
