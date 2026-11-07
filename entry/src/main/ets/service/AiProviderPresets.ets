export interface AiProviderPreset { label: string; endpoint: string; model: string; }

/** Official HTTPS endpoints. Selecting a preset never supplies or transfers a credential. */
export class AiProviderPresets {
  static readonly ALL: AiProviderPreset[] = [
    { label: 'DeepSeek', endpoint: 'https://api.deepseek.com/chat/completions', model: 'deepseek-flash' },
    { label: '通义千问（北京）', endpoint: 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions', model: 'qwen-plus' },
    { label: '通义千问（新加坡）', endpoint: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions', model: 'qwen-plus' },
    { label: '自定义', endpoint: '', model: '' }
  ];

  static indexOf(endpoint: string): number {
    const index: number = AiProviderPresets.ALL.findIndex((preset: AiProviderPreset) => preset.endpoint === endpoint);
    return index < 0 ? 3 : index;
  }
}
