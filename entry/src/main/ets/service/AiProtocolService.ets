import { AiConfig, AiMessage, AiProtocol, AiProviders, AiModelPage } from '../model/AiConfig';

interface OpenAiBody { model: string; messages: AiMessage[]; stream: boolean; store: boolean; max_completion_tokens: number; }
interface ClaudeBody { model: string; messages: AiMessage[]; stream: boolean; max_tokens: number; }
interface OllamaOptions { num_predict: number; }
interface OllamaBody { model: string; messages: AiMessage[]; stream: boolean; options: OllamaOptions; }
interface Choice { message: AiMessage; }
interface TextBlock { type: string; text: string; }
interface AiResponse { choices?: Choice[]; content?: TextBlock[]; message?: AiMessage; error?: object; }
interface ModelRecord { id?: string; name?: string; }
interface ModelResponse { data?: ModelRecord[]; models?: ModelRecord[]; has_more?: boolean; last_id?: string; error?: object; }

export class AiSafeError extends Error {
  constructor(message: string) { super(message); }
}

/** Pure protocol and validation code; no storage, account data, or network dependencies. */
export class AiProtocolService {
  static readonly MAX_INPUT: number = 8000;
  static readonly MAX_RESPONSE: number = 1024 * 1024;

  static isLocalHost(host: string): boolean {
    if (host === 'localhost') return true;
    const parts: string[] = host.split('.');
    if (parts.length !== 4 || !parts.every((p: string) => /^(0|[1-9][0-9]{0,2})$/.test(p) && Number(p) <= 255)) {
      return false;
    }
    const a: number = Number(parts[0]);
    const b: number = Number(parts[1]);
    return a === 127 || a === 10 || (a === 192 && b === 168) || (a === 172 && b >= 16 && b <= 31);
  }

  static validate(config: AiConfig, requireModel: boolean = true): string {
    if (!AiProviders.ALL.some((p) => p.id === config.providerId)) return '请选择有效的服务商';
    if (![AiProtocol.OPENAI, AiProtocol.CLAUDE, AiProtocol.OLLAMA].includes(config.protocol)) return '不支持此协议';
    if (typeof config.endpoint !== 'string' || config.endpoint.length > 2048) return '接口地址过长';
    // Full endpoint only; reject credentials, query tokens, ambiguous escapes, fragments and URL normalization tricks.
    const match: RegExpMatchArray | null = config.endpoint.match(/^(https?):\/\/([a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?)(?::([0-9]{1,5}))?(\/[a-zA-Z0-9_./-]+)$/);
    if (match === null || match[4].includes('..') || match[4].includes('//')) {
      return '请输入完整 HTTP(S) 接口地址；不支持用户信息、查询参数、片段或转义字符';
    }
    const host: string = match[2].toLowerCase();
    if (host.split('.').some((part: string) => part.length === 0 || part.startsWith('-') || part.endsWith('-'))) {
      return '接口主机名无效';
    }
    if (match[3] !== undefined && (Number(match[3]) < 1 || Number(match[3]) > 65535)) return '端口须为 1—65535';
    if (host === '169.254.169.254' || host === 'metadata.google.internal' || host.startsWith('169.254.') || host === '0.0.0.0') {
      return '禁止访问元数据或未指定地址';
    }
    if (match[1] === 'http' && (!config.allowLocalHttp || !AiProtocolService.isLocalHost(host))) {
      return '公网接口必须使用 HTTPS；本地 HTTP 仅允许明确开启后的 localhost 或私网 IPv4';
    }
    if (requireModel && !AiProtocolService.validModelId(config.model)) {
      return '请填写服务商提供的模型 ID（最多 160 字符）';
    }
    if (typeof config.apiKey !== 'string' || config.apiKey.length > 4096 || /[^\x21-\x7e]/.test(config.apiKey)) {
      return '密钥包含空格、控制字符或不支持的字符';
    }
    if (config.apiKey.length === 0 && config.providerId !== 'ollama' && config.providerId !== 'custom') return '请填写此厂商的 API 密钥';
    return '';
  }

  static validModelId(id: string): boolean {
    return typeof id === 'string' && id.trim().length > 0 && id.length <= 160 && !/[\x00-\x1f\x7f]/.test(id);
  }

  /** Derive only a sibling path; never follow a server-supplied URL or send credentials to a different origin. */
  static modelsEndpoint(config: AiConfig): string {
    const error: string = AiProtocolService.validate(config, false);
    if (error !== '') throw new AiSafeError(error);
    if (config.protocol === AiProtocol.OLLAMA && config.endpoint.endsWith('/api/chat')) {
      return config.endpoint.slice(0, -5) + '/tags';
    }
    const suffix: string = config.protocol === AiProtocol.CLAUDE ? '/messages' : '/chat/completions';
    if (!config.endpoint.endsWith(suffix)) throw new AiSafeError('无法从此地址推导模型列表接口，请手动输入模型 ID');
    return config.endpoint.slice(0, -suffix.length) + '/models';
  }

  static parseModels(protocol: AiProtocol, raw: string): AiModelPage {
    if (raw.length > AiProtocolService.MAX_RESPONSE) throw new AiSafeError('模型列表超过大小限制，请手动输入 ID');
    let parsed: ModelResponse;
    try { parsed = JSON.parse(raw) as ModelResponse; } catch (_) { throw new AiSafeError('模型列表不是有效 JSON，仍可手动输入 ID'); }
    if (parsed === null || typeof parsed !== 'object' || parsed.error !== undefined) throw new AiSafeError('模型列表读取失败，请检查权限或手动输入 ID');
    const records: ModelRecord[] | undefined = protocol === AiProtocol.OLLAMA ? parsed.models : parsed.data;
    if (!Array.isArray(records)) throw new AiSafeError('服务未提供兼容的模型列表，仍可手动输入 ID');
    const ids: string[] = [];
    records.slice(0, 2000).forEach((item: ModelRecord) => {
      if (item === null || typeof item !== 'object') return;
      const id: string = (protocol === AiProtocol.OLLAMA ? item.name : item.id) ?? '';
      if (ids.length < 501 && AiProtocolService.validModelId(id) && !ids.includes(id.trim())) ids.push(id.trim());
    });
    const hasMore: boolean = protocol === AiProtocol.CLAUDE && parsed.has_more === true;
    const afterId: string = typeof parsed.last_id === 'string' ? parsed.last_id : '';
    if (hasMore && !AiProtocolService.validModelId(afterId)) throw new AiSafeError('模型分页信息无效，请手动输入 ID');
    return { ids: ids, hasMore: hasMore, afterId: afterId, truncated: records.length > 2000 || ids.length > 500 };
  }

  static body(config: AiConfig, text: string): string {
    const messages: AiMessage[] = [{ role: 'user', content: text }];
    if (config.protocol === AiProtocol.CLAUDE) {
      const body: ClaudeBody = { model: config.model.trim(), messages: messages, stream: false, max_tokens: 2048 };
      return JSON.stringify(body);
    }
    if (config.protocol === AiProtocol.OLLAMA) {
      const body: OllamaBody = { model: config.model.trim(), messages: messages, stream: false, options: { num_predict: 2048 } };
      return JSON.stringify(body);
    }
    const body: OpenAiBody = { model: config.model.trim(), messages: messages, stream: false, store: false, max_completion_tokens: 2048 };
    // store is an OpenAI-specific privacy option; don't send it to compatible vendors.
    if (config.providerId === 'openai') return JSON.stringify(body);
    const compatible: ClaudeBody = { model: body.model, messages: body.messages, stream: false, max_tokens: 2048 };
    return JSON.stringify(compatible);
  }

  static parse(protocol: AiProtocol, raw: string): string {
    if (raw.length > AiProtocolService.MAX_RESPONSE) throw new AiSafeError('AI 响应超过大小限制');
    let parsed: AiResponse;
    try { parsed = JSON.parse(raw) as AiResponse; } catch (_) { throw new AiSafeError('接口未返回有效 JSON，请检查协议与地址'); }
    if (parsed === null || typeof parsed !== 'object' || parsed.error !== undefined) throw new AiSafeError('服务商返回错误，请检查模型、额度与配置');
    let result: string = '';
    if (protocol === AiProtocol.OLLAMA) {
      result = parsed.message?.content ?? '';
    } else if (protocol === AiProtocol.CLAUDE) {
      if (Array.isArray(parsed.content)) result = parsed.content.filter((b: TextBlock) => b !== null && b.type === 'text' && typeof b.text === 'string').map((b: TextBlock) => b.text).join('\n');
    } else if (Array.isArray(parsed.choices) && parsed.choices.length > 0) {
      result = parsed.choices[0]?.message?.content ?? '';
    }
    if (typeof result !== 'string' || result.trim().length === 0) throw new AiSafeError('未收到文字回复，请检查模型与协议是否匹配');
    return result;
  }

  static statusMessage(status: number): string {
    if (status >= 300 && status < 400) return '接口重定向已阻止，请直接填写最终接口地址';
    if (status === 401 || status === 403) return '认证失败或无访问权限，请检查密钥、区域与模型权限';
    if (status === 429) return '请求受限或额度不足，请稍后重试并检查账户额度';
    if (status === 404) return '接口或模型不存在，请检查完整地址与模型 ID';
    return '服务商请求失败（HTTP ' + status.toString() + '）';
  }
}
