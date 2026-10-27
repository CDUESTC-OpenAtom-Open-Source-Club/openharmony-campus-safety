import { rcp } from '@kit.RemoteCommunicationKit';
import { util } from '@kit.ArkTS';
import { AiConfig, AiProtocol } from '../model/AiConfig';
import { AiProtocolService, AiSafeError } from './AiProtocolService';

export class HarmonyAiTransport {
  private session: rcp.Session | null = null;
  cancel(): void {
    try { this.session?.cancel(); } catch (_) { /* Continue clearing private UI state. */ }
  }
  async request(config: AiConfig, endpoint: string, method: rcp.HttpMethod, body?: string): Promise<string> {
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
      if (tooLarge) throw new AiSafeError('AI 响应超过 1 MiB，已停止接收');
      // Only our own fixed messages escape; native errors may echo credentials, endpoints or bodies.
      if (error instanceof AiSafeError) throw error;
      throw new Error('请求未完成或已取消，请检查网络、证书与服务状态后重试');
    } finally {
      session.close();
      this.session = null;
    }
  }
}
