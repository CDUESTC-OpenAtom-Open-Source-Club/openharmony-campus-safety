import { promptAction, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppTheme } from '../common/AppTheme';
import { AiConfig, AiProtocol, AiProvider, AiProviders, AiModelList } from '../model/AiConfig';
import { AiConfigService } from '../service/AiConfigService';
import { AiProtocolService } from '../service/AiProtocolService';
import { AiClient } from '../service/AiClient';
import { AccountService } from '../service/AccountService';
import { PlatformBridge } from '../service/PlatformBridge';

@Component
export struct AiAssistantPage {
  pageStack: NavPathStack = new NavPathStack();
  @State private provider: number = 0;
  @State private protocol: number = 0;
  @State private endpoint: string = AiProviders.ALL[0].endpoint;
  @State private model: string = '';
  @State private apiKey: string = '';
  @State private localHttp: boolean = false;
  @State private input: string = '';
  @State private answer: string = '';
  @State private status: string = '';
  @State private busy: boolean = false;
  @State private loading: boolean = false;
  @State private settings: boolean = true;
  @State private saved: boolean = false;
  @State private privacyReady: boolean = false;
  @State private modelIds: string[] = [];
  @State private modelFilter: string = '';
  @State private modelStatus: string = '';
  @State private readingModels: boolean = false;
  @StorageLink('aiPrivacyEpoch') @Watch('onPrivacyChanged') private privacyEpoch: number = 0;
  private client: AiClient = new AiClient();
  private revision: number = 0;
  // Directory edits invalidate responses, but must never own the config form lock.
  private configOperation: number = 0;
  private readonly configTimeoutMs: number = 8000;
  private active: boolean = true;
  private owner: string = '';
  private protocols: AiProtocol[] = [AiProtocol.OPENAI, AiProtocol.CLAUDE, AiProtocol.OLLAMA];

  aboutToAppear(): void {
    this.active = true;
    this.owner = AccountService.getCurrentUser()?.id ?? '';
    this.enablePrivacy();
    this.loadProvider(0);
  }

  private async enablePrivacy(): Promise<void> {
    try {
      if (await PlatformBridge.get() !== null) {
        await PlatformBridge.call('enablePrivacy', '');
        if (this.active) this.privacyReady = true;
        return;
      }
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const main: window.Window = await window.getLastWindow(context);
      await main.setWindowPrivacyMode(true);
      this.privacyReady = true;
    } catch (_) { this.status = '系统隐私窗口不可用：请勿在共享屏幕环境输入敏感信息'; }
  }

  aboutToDisappear(): void {
    this.active = false;
    this.onPrivacyChanged();
    // Privacy mode remains enabled for the application window to avoid a navigation/snapshot race.
  }

  private onPrivacyChanged(): void {
    this.configOperation++;
    this.invalidateModels();
    this.apiKey = '';
    this.input = '';
    this.answer = '';
    this.saved = false;
    this.loading = false;
    this.status = '已清除页面敏感内容，可重新读取安全配置';
  }

  private config(): AiConfig {
    return { providerId: AiProviders.ALL[this.provider].id, protocol: this.protocols[this.protocol],
      endpoint: this.endpoint.trim(), model: this.model.trim(), apiKey: this.apiKey,
      allowLocalHttp: this.localHttp };
  }

  private isOwner(): boolean {
    return this.active && this.owner !== '' && this.owner === (AccountService.getCurrentUser()?.id ?? '');
  }

  private async awaitConfig<T>(operation: Promise<T>): Promise<T> {
    let timer: number = -1;
    try {
      return await Promise.race([
        operation,
        new Promise<T>((_, reject) => {
          timer = setTimeout(() => reject(new Error('安全存储响应超时，已解除等待；可手动配置或重试读取')), this.configTimeoutMs);
        })
      ]);
    } finally {
      if (timer !== -1) clearTimeout(timer);
    }
  }

  private async loadProvider(index: number): Promise<void> {
    this.invalidateModels();
    const version: number = ++this.revision;
    this.provider = index;
    const defaults: AiConfig = AiProviders.defaults(index);
    this.endpoint = defaults.endpoint;
    this.protocol = this.protocols.indexOf(defaults.protocol);
    this.model = '';
    this.apiKey = '';
    this.localHttp = false;
    this.input = '';
    this.answer = '';
    this.saved = false;
    this.status = '';
    if (!this.isOwner()) { this.status = '请先登录，再使用账号独立的 AI 配置'; return; }
    const operation: number = ++this.configOperation;
    this.loading = true;
    this.status = '正在读取当前账号的安全配置…';
    console.info('[AiConfigState] read begin operation=' + operation + ' revision=' + version);
    try {
      const config: AiConfig | null = await this.awaitConfig(AiConfigService.load(defaults.providerId));
      console.info('[AiConfigState] read settled operation=' + operation + ' revision=' + this.revision);
      if (version !== this.revision || !this.isOwner()) return;
      if (config !== null) {
        this.endpoint = config.endpoint;
        this.protocol = this.protocols.indexOf(config.protocol);
        this.model = config.model;
        this.apiKey = config.apiKey;
        this.localHttp = config.allowLocalHttp;
        this.saved = true;
        this.status = '已读取当前账号的安全配置';
      } else {
        this.status = '尚无已保存配置，可以直接填写';
      }
    } catch (error) {
      if (operation === this.configOperation && this.isOwner()) this.status = (error as Error).message;
    } finally {
      if (operation === this.configOperation) {
        this.loading = false;
        if (this.status === '正在读取当前账号的安全配置…') this.status = '读取已结束，保留当前输入，可继续配置';
      }
      console.info('[AiConfigState] read finished operation=' + operation + ' currentOperation=' + this.configOperation);
    }
  }

  private async save(): Promise<void> {
    if (!this.isOwner()) { this.status = '请先登录'; return; }
    if (this.loading || this.busy) return;
    this.invalidateModels();
    const version: number = this.revision;
    const operation: number = ++this.configOperation;
    this.loading = true;
    try {
      await this.awaitConfig(AiConfigService.save(this.config()));
      if (version !== this.revision || !this.isOwner()) return;
      this.saved = true;
      this.status = '已保存到系统安全存储';
      this.settings = false;
    } catch (error) {
      if (version === this.revision && this.isOwner()) this.status = (error as Error).message;
    } finally { if (operation === this.configOperation) this.loading = false; }
  }

  private async remove(): Promise<void> {
    if (!this.isOwner()) return;
    if (this.loading || this.busy) return;
    this.invalidateModels();
    const version: number = this.revision;
    const operation: number = ++this.configOperation;
    this.loading = true;
    try {
      await this.awaitConfig(AiConfigService.remove(AiProviders.ALL[this.provider].id));
      if (version !== this.revision || !this.isOwner()) return;
      this.apiKey = '';
      this.saved = false;
      this.answer = '';
      this.input = '';
      this.status = '已删除此服务商的安全配置和密钥';
    } catch (error) {
      if (version === this.revision && this.isOwner()) this.status = (error as Error).message;
    } finally { if (operation === this.configOperation) this.loading = false; }
  }

  private async send(test: boolean): Promise<void> {
    if (!this.isOwner() || this.busy || this.loading || this.readingModels) return;
    const config: AiConfig = this.config();
    const error: string = AiProtocolService.validate(config);
    if (error !== '') { this.status = error; this.settings = true; return; }
    const text: string = test ? '请只回复：连接成功' : this.input;
    if (text.trim().length === 0) { this.status = '请先输入消息'; return; }
    const version: number = this.revision;
    this.busy = true;
    try {
      const decision = await promptAction.showDialog({ title: test ? '确认测试请求' : '确认发送内容',
        message: '目标：' + config.endpoint + '\n模型：' + config.model + '\n将发送' + (test ? '固定测试文字' : '当前输入的 ' + text.length.toString() + ' 字文字') +
          '及此服务的认证信息，可能计费。不会附带校园记录或历史对话。' +
          (config.endpoint.startsWith('http:') ? '\n当前为明文 HTTP，局域网中可被监听。' : '\n数据由目标服务运营方处理，请确认其隐私政策与区域。'),
        buttons: [{ text: '取消', color: AppTheme.inkSoft }, { text: '确认发送', color: AppTheme.accentDeep }] });
      if (decision.index !== 1 || version !== this.revision || !this.isOwner()) return;
      this.status = '正在等待模型回复…';
      const reply: string = await this.client.send(config, text, config.endpoint);
      if (version !== this.revision || !this.isOwner()) return;
      if (test) this.status = '连接与文字响应验证成功';
      else { this.answer = reply; this.input = ''; this.status = '已完成；回复仅供参考，请人工核实'; }
    } catch (error) {
      if (version === this.revision && this.isOwner()) this.status = (error as Error).message;
    } finally { this.busy = false; }
  }

  private invalidateModels(): void {
    this.revision++;
    this.client.cancel();
    this.modelIds = [];
    this.modelFilter = '';
    this.modelStatus = '';
    this.readingModels = false;
  }

  private async readModels(automatic: boolean = false): Promise<void> {
    if (!this.isOwner() || this.busy || this.loading || this.readingModels) return;
    const config: AiConfig = this.config();
    const error: string = AiProtocolService.validate(config, false);
    if (error !== '') { if (!automatic) this.modelStatus = error; return; }
    const version: number = this.revision;
    this.readingModels = true;
    this.modelStatus = '正在读取服务返回的模型…';
    try {
      const result: AiModelList = await this.client.listModels(config);
      if (version !== this.revision || !this.isOwner()) return;
      this.modelIds = result.ids;
      this.modelFilter = '';
      this.modelStatus = result.ids.length === 0 ? '服务未返回模型，仍可手动输入 ID' :
        '已读取 ' + result.ids.length.toString() + ' 个模型' + (result.truncated ? '（列表已截断，可手动输入其他 ID）' : '');
    } catch (error) {
      if (version !== this.revision || !this.isOwner()) return;
      this.modelIds = [];
      this.modelStatus = (error instanceof Error ? error.message : '读取失败') + '；仍可手动输入模型 ID';
    } finally { if (version === this.revision) this.readingModels = false; }
  }

  private filteredModelIds(): string[] {
    const query: string = this.modelFilter.trim().toLowerCase();
    return this.modelIds.filter((id: string) => id.toLowerCase().includes(query));
  }

  private modelOptions(): SelectOption[] {
    return this.filteredModelIds().slice(0, 100).map((id: string): SelectOption => ({ value: id }));
  }

  @Builder
  private label(text: string) {
    Text(text).fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.ink).width('100%')
  }

  @Builder
  private configuration() {
    Column({ space: 12 }) {
      this.label('服务商')
      Select(AiProviders.ALL.map((item: AiProvider): SelectOption => ({ value: item.name })))
        .selected(this.provider).value(AiProviders.ALL[this.provider].name).width('100%')
        .onSelect((index: number) => { this.loadProvider(index); })
      this.label('接口协议')
      Select([{ value: 'OpenAI 兼容（含 Gemini）' }, { value: 'Anthropic Messages' }, { value: 'Ollama 原生' }])
        .selected(this.protocol).value(['OpenAI 兼容（含 Gemini）', 'Anthropic Messages', 'Ollama 原生'][this.protocol])
        .width('100%').onSelect((index: number) => {
          if (index === this.protocol) return;
          this.invalidateModels(); this.protocol = index; this.saved = false; this.apiKey = '';
        })
      this.label('完整接口地址（含路径）')
      TextInput({ text: this.endpoint, placeholder: 'https://服务地址/v1/chat/completions' })
        .maxLength(2048).height(48).onChange((value: string) => {
          if (value === this.endpoint) return;
          this.invalidateModels(); this.endpoint = value; this.apiKey = ''; this.saved = false; this.answer = '';
        })

      Text('千问、华为云请从控制台复制当前工作空间、区域对应的完整 URL。修改地址或协议后须重新填写密钥。')
        .fontSize(13).fontColor(AppTheme.inkSoft).width('100%')
      this.label('API 密钥（Ollama / 自定义可留空）')
      TextInput({ text: this.apiKey, placeholder: '仅存于当前账号的系统安全存储' })
        .type(InputType.Password).showPasswordIcon(false).enableAutoFill(false).maxLength(4096).height(48)
        .copyOption(CopyOptions.None).onChange((value: string) => {
          if (value === this.apiKey) return;
          this.invalidateModels(); this.apiKey = value; this.saved = false;
        })

      Text('填写密钥后点击“读取可用模型”，仅向当前接口所属服务发送认证信息，不发送问答内容。读取失败时可手动填写 ID。')
        .fontSize(13).fontColor(AppTheme.inkSoft).width('100%')
      Row({ space: 12 }) {
        Text('允许私网 / 本机明文 HTTP').fontSize(14).fontColor(AppTheme.ink).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.localHttp })
          .onChange((value: boolean) => {
            if (value === this.localHttp) return;
            this.invalidateModels(); this.localHttp = value; this.saved = false;
          })
      }.width('100%').constraintSize({ minHeight: 48 })
      Text('手机上的 127.0.0.1 指手机自身。访问电脑 Ollama 请填同一局域网电脑 IP，例如 http://192.168.1.20:11434/api/chat，并检查监听地址、防火墙和访问控制。')
        .fontSize(13).fontColor(AppTheme.inkSoft).width('100%')
      this.label('选择模型 / 手动输入 ID')
      Button(this.modelIds.length === 0 ? '读取可用模型' : '重新读取模型').width('100%').height(48)
        .enabled(!this.readingModels)
        .onClick(() => this.readModels())
      if (this.readingModels) {
        LoadingProgress().width(28).height(28).accessibilityText('正在读取模型目录')
        Button('取消读取').height(48).onClick(() => { this.invalidateModels(); this.modelStatus = '已取消读取，可手动输入 ID'; })
      }
      if (this.modelStatus !== '') {
        Text(this.modelStatus).fontSize(13).fontColor(AppTheme.inkSoft).width('100%')
      }
      if (this.modelIds.length > 0) {
        TextInput({ text: this.modelFilter, placeholder: '搜索模型 ID' }).height(48).maxLength(160)
          .onChange((value: string) => { this.modelFilter = value; })
        if (this.filteredModelIds().length > 0) {
          Select(this.modelOptions()).width('100%')
            .selected(this.filteredModelIds().slice(0, 100).indexOf(this.model))
            .value(this.modelIds.includes(this.model) ? this.model : '请选择模型')
            .onSelect((index: number) => {
              const ids: string[] = this.filteredModelIds().slice(0, 100);
              if (index >= 0 && index < ids.length) { this.model = ids[index]; this.saved = false; }
            })
          if (this.filteredModelIds().length > 100) {
            Text('下拉框显示前 100 项，请输入关键词缩小范围').fontSize(13).fontColor(AppTheme.inkSoft)
          }
        } else {
          Text('没有匹配的模型，仍可在下面手动输入').fontSize(13).fontColor(AppTheme.inkSoft)
        }
        Text('目录可能包含非聊天模型；能否调用仍取决于账号权限及模型协议。')
          .fontSize(13).fontColor(AppTheme.inkSoft).width('100%')
      }
      TextInput({ text: this.model, placeholder: '也可手动输入模型或方舟接入点 ID' })
        .maxLength(160).height(48).onChange((value: string) => { this.model = value; this.saved = false; })
      Button('保存安全配置').width('100%').height(48).backgroundColor(AppTheme.accentDeep)
        .onClick(() => this.save())
      Row({ space: 12 }) {
        Button('读取已保存配置').layoutWeight(1).height(48).enabled(!this.readingModels).onClick(() => this.loadProvider(this.provider))
        Button('删除此配置').layoutWeight(1).height(48).fontColor('#B42332').backgroundColor(AppTheme.surfaceMuted)
          .enabled(!this.readingModels).onClick(() => this.remove())
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).enabled(!this.busy && !this.loading)
  }

  @Builder
  private conversation() {
    Column({ space: 14 }) {
      Text(AiProviders.ALL[this.provider].name + ' · ' + (this.model || '尚未配置模型'))
        .fontSize(16).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink).width('100%')
      Text(this.endpoint || '请先配置接口地址').fontSize(13).fontColor(AppTheme.inkSoft).width('100%')
      Text('每次仅发送当前消息。不要输入姓名、电话、学号、精确地点或未公开事件；历史回复不会再次发送。')
        .fontSize(14).fontColor(AppTheme.inkSoft).width('100%')
      TextArea({ text: this.input, placeholder: '例如：宿舍日常用电应检查哪些隐患？' })
        .height(150).maxLength(AiProtocolService.MAX_INPUT).enabled(!this.busy)
        .onChange((value: string) => { this.input = value; })
      Text(this.input.length.toString() + ' / 8000').fontSize(12).fontColor(AppTheme.inkSoft).width('100%')
      Button(this.busy ? '等待回复…' : '预览目标并发送').width('100%').height(48)
        .backgroundColor(AppTheme.accentDeep).enabled(!this.busy && !this.loading && !this.readingModels).onClick(() => this.send(false))
      Button('测试连接（需确认，可能计费）').width('100%').height(48)
        .enabled(!this.busy && !this.loading && !this.readingModels).onClick(() => this.send(true))
      if (this.busy) {
        Button('取消请求').width('100%').height(48).onClick(() => { this.client.cancel(); })
      }
      if (this.answer !== '') {
        this.label('模型回复 · 请人工核实')
        Text(this.answer).fontSize(16).lineHeight(26).fontColor(AppTheme.ink).width('100%')
        Button('清除本页内容').height(48).onClick(() => { this.answer = ''; this.input = ''; this.status = ''; })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Button('返回').height(44).onClick(() => this.pageStack.pop())
        Text('AI 助手').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink).layoutWeight(1)
        Button(this.settings ? '问答' : '配置').height(44).enabled(!this.busy && !this.loading && !this.readingModels)
          .onClick(() => { this.settings = !this.settings; })
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      Scroll() {
        Column({ space: 20 }) {
          Text(this.settings ? '连接你的 AI 服务' : '校园安全咨询').fontSize(24).fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ink).width('100%')
          Text('按账号保存配置 · 不保存对话 · 不自动上传校园数据').fontSize(13).fontColor(AppTheme.inkSoft).width('100%')
          if (!this.privacyReady) {
            Text('系统隐私窗口尚未启用，请勿在共享屏幕环境输入密钥或敏感内容。').fontSize(13).fontColor('#B42332').width('100%')
          }
          if (this.loading) { LoadingProgress().width(28).height(28).accessibilityText('正在读取安全配置') }
          if (this.settings) { this.configuration() } else { this.conversation() }
          if (this.status !== '') { Text(this.status).fontSize(14).fontColor(AppTheme.ink).width('100%') }
          Text(this.saved ? '当前配置已安全保存' : '当前配置未保存；可直接发送或保存后使用')
            .fontSize(13).fontColor(AppTheme.inkSoft).width('100%')
          Text('AI 内容不替代应急处置。遇到危险请优先联系校园安保或应急服务。离开页面或切到后台将清除密钥输入与问答内容。')
            .fontSize(13).fontColor(AppTheme.inkSoft).width('100%')
        }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 32 })
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor(AppTheme.canvas)
  }
}
