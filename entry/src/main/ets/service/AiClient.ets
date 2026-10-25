import { PlatformBridge } from './PlatformBridge';
import type { HarmonyAiTransport } from './HarmonyAiTransport';
import { AiConfig, AiProtocol, AiModelList, AiModelPage } from '../model/AiConfig';
import { AiProtocolService, AiSafeError } from './AiProtocolService';

interface NativeHttpReply {
  status: number;
  body: string;
}

/** One request per client. Never retries, redirects, logs payloads, caches, or fails over to another vendor. */
export class AiClient {
  private static sequence: number = 0;
  private transport: HarmonyAiTransport | null = null;
  private generation: number = 0;
  private nativeRequest: string = '';
  private requesting: boolean = false;

  cancel(): void {
    this.generation++;
    this.transport?.cancel();
    if (this.nativeRequest !== '') {
      PlatformBridge.call('cancelRequest', this.nativeRequest).catch(() => {});
    }
  }

  async send(config: AiConfig, text: string, confirmedEndpoint: string): Promise<string> {
    const error: string = AiProtocolService.validate(config);
    if (error !== '') throw new Error(error);
    if (confirmedEndpoint !== config.endpoint) throw new Error('发送目标已变化，请重新确认');
    if (text.trim().length === 0 || text.length > AiProtocolService.MAX_INPUT) throw new Error('请输入 1—8000 字的消息');
    const raw: string = await this.request(config, config.endpoint, 'POST', AiProtocolService.body(config, text));
    return AiProtocolService.parse(config.protocol, raw);
  }

  async listModels(config: AiConfig): Promise<AiModelList> {
    const endpoint: string = AiProtocolService.modelsEndpoint(config);
    const version: number = this.generation;
    const ids: string[] = [];
    const cursors: string[] = [];
    let afterId: string = '';
    let hasMore: boolean = false;
    for (let page: number = 0; page < 10; page++) {
      if (version !== this.generation) throw new AiSafeError('模型读取已取消');
      let target: string = endpoint;
      if (config.protocol === AiProtocol.CLAUDE) {
        target += '?limit=100' + (afterId === '' ? '' : '&after_id=' + encodeURIComponent(afterId));
      }
      const raw: string = await this.request(config, target, 'GET');
      if (version !== this.generation) throw new AiSafeError('模型读取已取消');
      const result: AiModelPage = AiProtocolService.parseModels(config.protocol, raw);
      let overflow: boolean = false;
      result.ids.forEach((id: string) => {
        if (!ids.includes(id)) {
          if (ids.length < 500) ids.push(id);
          else overflow = true;
        }
      });
      hasMore = result.hasMore || overflow || result.truncated;
      if (!result.hasMore || ids.length >= 500) break;
      if (cursors.includes(result.afterId)) throw new AiSafeError('服务返回重复分页信息，请手动输入 ID');
      cursors.push(result.afterId);
      afterId = result.afterId;
    }
    return { ids: ids.sort(), truncated: hasMore };
  }

  private async request(config: AiConfig, endpoint: string, method: string, body?: string): Promise<string> {
    if (this.requesting) throw new AiSafeError('请等待当前请求完成');
    const headers: Record<string, string> = { 'Content-Type': 'application/json', 'Accept': 'application/json' };
    if (config.apiKey !== '') {
      if (config.protocol === AiProtocol.CLAUDE) headers['x-api-key'] = config.apiKey;
      else headers['Authorization'] = 'Bearer ' + config.apiKey;
    }
    if (config.protocol === AiProtocol.CLAUDE) headers['anthropic-version'] = '2023-06-01';
    this.requesting = true;
    const version: number = this.generation;
    try {
      const native = await PlatformBridge.get();
      if (version !== this.generation) throw new AiSafeError('请求已取消');
      if (native !== null) {
        const id: string = Date.now().toString() + '-' + (++AiClient.sequence).toString();
        this.nativeRequest = id;
        const raw: string = await PlatformBridge.call('request', JSON.stringify({
          id: id, endpoint: endpoint, method: method, headers: headers, body: body ?? '',
          timeout: method === 'GET' ? 30000 : 120000, maxBytes: AiProtocolService.MAX_RESPONSE
        }), method === 'GET' ? 32000 : 122000);
        if (version !== this.generation) throw new AiSafeError('请求已取消');
        const result: NativeHttpReply = JSON.parse(raw) as NativeHttpReply;
        if (typeof result.status !== 'number' || typeof result.body !== 'string' ||
          result.body.length > AiProtocolService.MAX_RESPONSE) throw new AiSafeError('AI 响应格式或大小无效');
        if (result.status < 200 || result.status >= 300) throw new AiSafeError(AiProtocolService.statusMessage(result.status));
        return result.body;
      }
      const module = await import('./HarmonyAiTransport');
      const transport: HarmonyAiTransport = new module.HarmonyAiTransport();
      if (version !== this.generation) throw new AiSafeError('请求已取消');
      this.transport = transport;
      return await transport.request(config, endpoint, method === 'GET' ? 'GET' : 'POST', body);
    } catch (error) {
      if (this.nativeRequest !== '') {
        PlatformBridge.call('cancelRequest', this.nativeRequest).catch(() => {});
      }
      if (error instanceof AiSafeError) throw error;
      throw new Error('请求未完成或已取消，请检查网络、证书与服务状态后重试');
    } finally {
      this.transport = null;
      this.requesting = false;
      this.nativeRequest = '';
    }
  }
}
