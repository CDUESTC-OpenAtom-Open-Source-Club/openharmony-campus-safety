import { rcp } from '@kit.RemoteCommunicationKit';
import { util } from '@kit.ArkTS';
import { AiConfig, AiProtocol, AiModelList, AiModelPage } from '../model/AiConfig';
import { AiProtocolService, AiSafeError } from './AiProtocolService';

/** One request per client. Never retries, redirects, logs payloads, caches, or fails over to another vendor. */
export class AiClient {
  private session: rcp.Session | null = null;
  private generation: number = 0;

  cancel(): void {
    this.generation++;
    this.session?.cancel();
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

  private async request(config: AiConfig, endpoint: string, method: rcp.HttpMethod, body?: string): Promise<string> {
    if (this.session !== null) throw new AiSafeError('请等待当前请求完成');
    const headers: rcp.RequestHeaders = { 'Content-Type': 'application/json', 'Accept': 'application/json' };
    if (config.apiKey !== '') {
      if (config.protocol === AiProtocol.CLAUDE) headers['x-api-key'] = config.apiKey;
      else headers['Authorization'] = 'Bearer ' + config.apiKey;
    }
    if (config.protocol === AiProtocol.CLAUDE) headers['anthropic-version'] = '2023-06-01';
    let size: number = 0;
    let tooLarge: boolean = false;
    const chunks: Uint8Array[] = [];
    const session: rcp.Session = rcp.createSession({ requestConfiguration: {
      transfer: { autoRedirect: false, timeout: { connectMs: 15000, transferMs: method === 'GET' ? 30000 : 120000 } },
      tracing: { httpEventsHandler: { onDataReceive: (data: ArrayBuffer): void => {
        size += data.byteLength;
        if (size > AiProtocolService.MAX_RESPONSE) { tooLarge = true; session.cancel(); return; }
        chunks.push(new Uint8Array(data));
      } } }
    } });
    this.session = session;
    try {
      const response: rcp.Response = await session.fetch(new rcp.Request(endpoint, method, headers, body));
      if (tooLarge || (response.body?.byteLength ?? 0) > AiProtocolService.MAX_RESPONSE) throw new AiSafeError('AI 响应超过大小限制');
      if (response.statusCode < 200 || response.statusCode >= 300) throw new AiSafeError(AiProtocolService.statusMessage(response.statusCode));
      const bytes: Uint8Array = new Uint8Array(size);
      let offset: number = 0;
      chunks.forEach((chunk: Uint8Array) => { bytes.set(chunk, offset); offset += chunk.byteLength; });
      const raw: string = size > 0 ? util.TextDecoder.create('utf-8').decodeWithStream(bytes) : (response.toString() ?? '');
      return raw;
    } catch (error) {
      if (tooLarge) throw new Error('AI 响应超过 1 MiB，已停止接收');
      // Only our own fixed messages escape; native errors may echo credentials, endpoints or bodies.
      if (error instanceof AiSafeError) throw error;
      throw new Error('请求未完成或已取消，请检查网络、证书与服务状态后重试');
    } finally {
      session.close();
      this.session = null;
    }
  }
}
