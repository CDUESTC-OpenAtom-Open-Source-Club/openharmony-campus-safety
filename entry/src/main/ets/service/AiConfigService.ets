import { PlatformBridge } from './PlatformBridge';
import { util } from '@kit.ArkTS';
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
    const owner: string = AccountService.getCurrentUser()?.id ?? '';
    const alias: string = util.TextDecoder.create('utf-8').decodeWithStream(AiConfigService.alias(providerId));
    const native = await PlatformBridge.get();
    if (native !== null) {
      const raw: string = await PlatformBridge.call('loadConfig', alias);
      if (raw === '') return null;
      const config: AiConfig = JSON.parse(raw) as AiConfig;
      if (config.providerId !== providerId || AiProtocolService.validate(config) !== '') throw new Error('安全配置无效，请重新配置');
      return config;
    }
    const module = await import('./HarmonyAiConfigService');
    if (owner !== (AccountService.getCurrentUser()?.id ?? '')) throw new Error('账号已变化，请重试');
    return module.HarmonyAiConfigService.load(providerId);
  }

  static async save(config: AiConfig): Promise<void> {
    const owner: string = AccountService.getCurrentUser()?.id ?? '';
    const alias: string = util.TextDecoder.create('utf-8').decodeWithStream(AiConfigService.alias(config.providerId));
    const error: string = AiProtocolService.validate(config);
    if (error !== '') throw new Error(error);
    const native = await PlatformBridge.get();
    if (native !== null) {
      await PlatformBridge.call('saveConfig', JSON.stringify({ alias: alias, value: JSON.stringify(config) }));
      return;
    }
    const module = await import('./HarmonyAiConfigService');
    if (owner !== (AccountService.getCurrentUser()?.id ?? '')) throw new Error('账号已变化，请重试');
    await module.HarmonyAiConfigService.save(config);
  }

  static async remove(providerId: string): Promise<void> {
    const owner: string = AccountService.getCurrentUser()?.id ?? '';
    const alias: string = util.TextDecoder.create('utf-8').decodeWithStream(AiConfigService.alias(providerId));
    const native = await PlatformBridge.get();
    if (native !== null) {
      await PlatformBridge.call('removeConfig', alias);
      return;
    }
    const module = await import('./HarmonyAiConfigService');
    if (owner !== (AccountService.getCurrentUser()?.id ?? '')) throw new Error('账号已变化，请重试');
    await module.HarmonyAiConfigService.remove(providerId);
  }
}
