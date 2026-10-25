export enum AiProtocol {
  OPENAI = 'openai',
  CLAUDE = 'claude',
  OLLAMA = 'ollama'
}

export interface AiConfig {
  providerId: string;
  protocol: AiProtocol;
  endpoint: string;
  model: string;
  apiKey: string;
  allowLocalHttp: boolean;
}

export interface AiProvider {
  id: string;
  name: string;
  protocol: AiProtocol;
  endpoint: string;
}

export interface AiMessage {
  role: string;
  content: string;
}

export interface AiModelList {
  ids: string[];
  truncated: boolean;
}

export interface AiModelPage {
  ids: string[];
  hasMore: boolean;
  afterId: string;
  truncated: boolean;
}

/** Model IDs are entered by the user: availability and region depend on their account. */
export class AiProviders {
  static readonly ALL: AiProvider[] = [
    { id: 'deepseek', name: 'DeepSeek', protocol: AiProtocol.OPENAI, endpoint: 'https://api.deepseek.com/chat/completions' },
    { id: 'qwen', name: '阿里云百炼 / 千问', protocol: AiProtocol.OPENAI, endpoint: '' },
    { id: 'doubao', name: '火山方舟 / 豆包', protocol: AiProtocol.OPENAI, endpoint: 'https://ark.cn-beijing.volces.com/api/v3/chat/completions' },
    { id: 'glm', name: '智谱 GLM', protocol: AiProtocol.OPENAI, endpoint: 'https://open.bigmodel.cn/api/paas/v4/chat/completions' },
    { id: 'kimi', name: '月之暗面 / Kimi', protocol: AiProtocol.OPENAI, endpoint: 'https://api.moonshot.cn/v1/chat/completions' },
    { id: 'baidu', name: '百度千帆', protocol: AiProtocol.OPENAI, endpoint: 'https://qianfan.baidubce.com/v2/chat/completions' },
    { id: 'hunyuan', name: '腾讯混元', protocol: AiProtocol.OPENAI, endpoint: 'https://api.hunyuan.cloud.tencent.com/v1/chat/completions' },
    { id: 'siliconflow', name: '硅基流动', protocol: AiProtocol.OPENAI, endpoint: 'https://api.siliconflow.cn/v1/chat/completions' },
    { id: 'minimax', name: 'MiniMax', protocol: AiProtocol.CLAUDE, endpoint: 'https://api.minimax.cn/anthropic/v1/messages' },
    { id: 'spark', name: '讯飞星火', protocol: AiProtocol.OPENAI, endpoint: 'https://maas-api.cn-huabei-1.xf-yun.com/v2/chat/completions' },
    { id: 'huawei', name: '华为云 ModelArts MaaS', protocol: AiProtocol.OPENAI, endpoint: '' },
    { id: 'openai', name: 'OpenAI', protocol: AiProtocol.OPENAI, endpoint: 'https://api.openai.com/v1/chat/completions' },
    { id: 'claude', name: 'Anthropic / Claude', protocol: AiProtocol.CLAUDE, endpoint: 'https://api.anthropic.com/v1/messages' },
    { id: 'gemini', name: 'Google / Gemini', protocol: AiProtocol.OPENAI, endpoint: 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions' },
    { id: 'mistral', name: 'Mistral', protocol: AiProtocol.OPENAI, endpoint: 'https://api.mistral.ai/v1/chat/completions' },
    { id: 'xai', name: 'xAI / Grok', protocol: AiProtocol.OPENAI, endpoint: 'https://api.x.ai/v1/chat/completions' },
    { id: 'groq', name: 'Groq', protocol: AiProtocol.OPENAI, endpoint: 'https://api.groq.com/openai/v1/chat/completions' },
    { id: 'ollama', name: 'Ollama（本地部署）', protocol: AiProtocol.OLLAMA, endpoint: 'http://127.0.0.1:11434/api/chat' },
    { id: 'custom', name: '自定义 API / 本地服务', protocol: AiProtocol.OPENAI, endpoint: '' }
  ];

  static defaults(index: number): AiConfig {
    const provider: AiProvider = AiProviders.ALL[index];
    return { providerId: provider.id, protocol: provider.protocol, endpoint: provider.endpoint,
      model: '', apiKey: '', allowLocalHttp: false };
  }
}
