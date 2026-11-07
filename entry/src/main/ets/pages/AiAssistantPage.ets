import { CampusInputStyle } from '../common/InputStyles';
import { common } from '@kit.AbilityKit';
import { promptAction, KeyboardAvoidMode } from '@kit.ArkUI';
import { AppTheme } from '../common/AppTheme';
import { MarkdownContent } from '../components/MarkdownContent';
import { MarkdownBlock, MarkdownParser, MarkdownSpan, MarkdownRow } from '../common/MarkdownParser';
import { AccountService } from '../service/AccountService';
import { AiConfig, AiConfigService } from '../service/AiConfigService';
import { AiChatService } from '../service/AiChatService';
import { AiSafetyService } from '../service/AiSafetyService';
import { LocalAgentService } from '../service/LocalAgentService';
import { AssistantShortcutService } from '../service/AssistantShortcutService';
import { AssistantAgentTurn } from '../service/AssistantToolProtocol';
import { AssistantConversation, AssistantConversationService, ConversationIndex, ConversationSummary, SavedChatMessage } from '../service/AssistantConversationService';
import { AiProviderPreset, AiProviderPresets } from '../service/AiProviderPresets';

class ChatMessage {
  private static nextId: number = 0;
  id: number = ChatMessage.nextId++;
  text: string;
  source: string;
  markdown: MarkdownBlock[];
  constructor(text: string, source: string) {
    this.text = text; this.source = source;
    this.markdown = source === '我' ? [] : MarkdownParser.parse(text);
    // Never automatically fetch model-provided tracking images. Links require a user tap.
    this.markdown.forEach((block: MarkdownBlock) => ChatMessage.disableImages(block));
  }
  private static disableImages(block: MarkdownBlock): void {
    block.spans.forEach((span: MarkdownSpan) => { if (span.image) { span.image = false; span.url = ''; } });
    block.rows.forEach((row: MarkdownRow) => row.cells.forEach((cell: MarkdownSpan[]) =>
      cell.forEach((span: MarkdownSpan) => { if (span.image) { span.image = false; span.url = ''; } })));
    block.children.forEach((child: MarkdownBlock) => ChatMessage.disableImages(child));
  }
}

@Component
export struct AiAssistantPage {
  onNavigate: (route: string) => void = (): void => {};
  onDataChanged: () => void = (): void => {};
  @State private inputText: string = '';
  @State private messages: ChatMessage[] = [];
  @State private settingsVisible: boolean = false;
  @State private historyVisible: boolean = false;
  @State private conversations: ConversationSummary[] = [];
  @State private conversationId: string = '';
  @State private online: boolean = false;
  @State private ready: boolean = false;
  @State private loading: boolean = true;
  @State private busy: boolean = false;
  @State private endpoint: string = AiProviderPresets.ALL[0].endpoint;
  @State private model: string = AiProviderPresets.ALL[0].model;
  @State private provider: number = 0;
  @State private advancedVisible: boolean = false;
  @State private modelSelection: number = 0;
  @State private apiKey: string = '';
  @State private remember: boolean = true;
  @State private formMessage: string = '';
  private owner: string = '';
  private agentHistory: AssistantAgentTurn[] = [];
  private toolScope: string = '';
  private conversation: AssistantConversation | null = null;
  private previousKeyboardMode: KeyboardAvoidMode = KeyboardAvoidMode.OFFSET;
  private active: boolean = false;
  private config: AiConfig | null = null;
  private scroller: Scroller = new Scroller();
  private scrollPending: boolean = false;

  aboutToAppear(): void {
    this.previousKeyboardMode = this.getUIContext().getKeyboardAvoidMode();
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.active = true;
    this.owner = AccountService.getCurrentUser()?.id ?? '';
    this.initialize();
  }

  aboutToDisappear(): void {
    this.getUIContext().setKeyboardAvoidMode(this.previousKeyboardMode);
    this.active = false; this.online = false; this.config = null; this.apiKey = '';
  }

  private sameOwner(): boolean {
    return this.active && (AccountService.getCurrentUser()?.id ?? '') === this.owner;
  }

  private async initialize(): Promise<void> {
    try { await Promise.all([this.loadConfig(), this.loadConversations()]); }
    finally { if (this.active) this.loading = false; }
  }

  private async loadConversations(): Promise<void> {
    if (this.owner === '') return;
    try {
      const context = getContext(this) as common.Context;
      let index = await AssistantConversationService.list(context, this.owner);
      if (index.items.length === 0) index = await AssistantConversationService.create(context, this.owner);
      if (!this.sameOwner()) return;
      this.conversations = index.items;
      await this.openConversation(index.selectedId || index.items[0].id, false);
    } catch (_) { if (this.sameOwner()) promptAction.showToast({ message: '历史对话读取失败，请稍后重试' }); }
  }

  private async openConversation(id: string, select: boolean = true): Promise<void> {
    if (!this.sameOwner() || this.busy) return;
    this.busy = true;
    try {
      const context = getContext(this) as common.Context;
      if (select) await AssistantConversationService.select(context, this.owner, id);
      const conversation = await AssistantConversationService.read(context, this.owner, id);
      if (!this.sameOwner()) return;
      this.conversation = conversation; this.conversationId = conversation.id;
      this.toolScope = conversation.toolScope === 'reminder.create' ? 'reminder.create' : '';
      this.messages = conversation.messages.map((item: SavedChatMessage) => new ChatMessage(item.text, item.source));
      this.agentHistory = conversation.turns; this.historyVisible = false; this.settingsVisible = false; this.inputText = '';
      this.scroller.scrollEdge(Edge.Bottom);
    } catch (_) { if (this.sameOwner()) promptAction.showToast({ message: '这个对话暂时无法打开' }); }
    finally { this.busy = false; }
  }

  private async newConversation(): Promise<void> {
    if (!this.sameOwner() || this.busy || this.loading) return;
    this.busy = true;
    try {
      const index = await AssistantConversationService.create(getContext(this), this.owner);
      if (!this.sameOwner()) return;
      this.conversations = index.items; this.busy = false;
      await this.openConversation(index.selectedId, false);
    } catch (error) { if (this.sameOwner()) promptAction.showToast({ message: error instanceof Error ? error.message : '新建对话失败' }); }
    finally { this.busy = false; }
  }

  private async deleteConversation(id: string): Promise<void> {
    if (!this.sameOwner() || this.busy) return;
    this.busy = true;
    try {
      let index = await AssistantConversationService.remove(getContext(this), this.owner, id);
      if (index.items.length === 0) index = await AssistantConversationService.create(getContext(this), this.owner);
      if (!this.sameOwner()) return;
      this.conversations = index.items;
      if (this.conversationId === id) {
        this.busy = false; await this.openConversation(index.selectedId, false); this.historyVisible = true;
      }
    } catch (_) { if (this.sameOwner()) promptAction.showToast({ message: '删除对话失败' }); }
    finally { this.busy = false; }
  }

  private async persistConversation(): Promise<void> {
    const conversation = this.conversation;
    if (conversation === null || AccountService.getCurrentUser()?.id !== this.owner) return;
    conversation.messages = this.messages.map((item: ChatMessage): SavedChatMessage => ({ text: item.text, source: item.source }));
    conversation.turns = this.agentHistory;
    conversation.toolScope = this.toolScope;
    const index = await AssistantConversationService.save(getContext(this), this.owner, conversation);
    if (this.sameOwner()) this.conversations = index.items;
  }

  private async deliverReply(text: string, source: string = '小安'): Promise<void> {
    if (AccountService.getCurrentUser()?.id !== this.owner) return;
    if (this.active) { this.add(text, source); return; }
    const conversation = this.conversation;
    if (conversation === null) return;
    conversation.messages = this.messages.map((item: ChatMessage): SavedChatMessage => ({ text: item.text, source: item.source }));
    conversation.messages.push({ text: text, source: source }); conversation.turns = this.agentHistory;
    conversation.toolScope = this.toolScope;
    await AssistantConversationService.save(getContext(this), this.owner, conversation);
  }

  private async loadConfig(): Promise<void> {
    try {
      if (this.owner === '') return;
      let timer: number = -1;
      let config: AiConfig | null = null;
      try {
        config = await Promise.race<AiConfig | null>([
          AiConfigService.load(getContext(this), this.owner),
          new Promise<AiConfig | null>((_resolve, reject) => {
            timer = setTimeout(() => reject(new Error('安全存储读取超时')), 5000);
          })
        ]);
      } finally { if (timer !== -1) clearTimeout(timer); }
      if (!this.sameOwner()) return;
      this.config = config; this.ready = config !== null;
      this.endpoint = config?.endpoint ?? AiProviderPresets.ALL[0].endpoint;
      this.model = config?.model ?? AiProviderPresets.ALL[0].model;
      this.provider = AiProviderPresets.indexOf(this.endpoint);
      this.advancedVisible = this.provider === 3;
    } catch (_) {
      if (this.sameOwner()) this.formMessage = '未能读取 API 配置，可解锁设备后重试。';
    }
  }

  private add(text: string, source: string = '小安'): void {
    this.scrollPending = true;
    this.messages = this.messages.concat([new ChatMessage(text, source)]).slice(-200);
    this.scroller.scrollEdge(Edge.Bottom);
  }

  private chooseModel(index: number): void {
    this.modelSelection = index;
    if (index === 0) { this.online = false; return; }
    if (!this.ready || this.config === null) { this.modelSelection = 0; this.settingsVisible = true; return; }
    if (this.online) return;
    AlertDialog.show({
      title: '启用在线问答？',
      message: '问题将发送到你配置的服务：\n' + this.config.endpoint +
        '\n\n发送本次问题；涉及应用安排时，会附带当前账号有权查看的相关任务、事件、提醒或课表摘要。不发送聊天历史、密码、密钥及联系人。答案另做一次内容审核，服务商可能保存内容并计费。',
      primaryButton: { value: '启用在线模式', action: () => { if (this.sameOwner()) { this.online = true; this.modelSelection = 1; } } },
      secondaryButton: { value: '继续使用小安', action: () => { this.modelSelection = 0; } },
      cancel: () => { if (!this.online) this.modelSelection = 0; }
    });
  }

  private async saveConfig(): Promise<void> {
    if (this.busy || this.owner === '' || !this.sameOwner()) { this.formMessage = '请先登录 App 账号后配置 API'; return; }
    const config: AiConfig = { endpoint: this.endpoint.trim(), model: this.model.trim(),
      apiKey: this.apiKey.trim() === '' ? AiConfigService.retainedKey(this.endpoint.trim(), this.config) : this.apiKey.trim() };
    this.formMessage = AiConfigService.validate(config);
    if (this.formMessage !== '') return;
    this.busy = true;
    try {
      await AiConfigService.save(this.owner, config, this.remember);
      if (!this.sameOwner()) return;
      this.config = config; this.ready = true; this.apiKey = ''; this.online = false; this.modelSelection = 0;
      this.formMessage = this.remember ? '配置已加密保存' : '仅本次使用';
    } catch (_) { this.formMessage = '保存失败。请解锁设备；如设备不支持安全存储，可关闭“记住配置”后重试。'; }
    finally { this.busy = false; }
  }

  private askClearConfig(): void {
    AlertDialog.show({ title: '清除当前账号的 API 配置？', message: '清除后仍可使用小安。',
      primaryButton: { value: '清除', action: () => { this.clearConfig(); } },
      secondaryButton: { value: '取消', action: () => {} } });
  }

  private async clearConfig(): Promise<void> {
    if (this.busy || !this.sameOwner() || this.owner === '') return;
    this.busy = true;
    try {
      await AiConfigService.remove(this.owner);
      this.config = null; this.ready = false; this.online = false; this.modelSelection = 0;
      this.apiKey = ''; this.selectProvider(0); this.formMessage = 'API 配置已清除';
    } catch (_) { this.formMessage = '清除失败，请解锁设备后重试'; }
    finally { this.busy = false; }
  }

  private async send(question: string = this.inputText): Promise<void> {
    const text: string = question.trim();
    if (this.busy || this.loading || !this.sameOwner() || this.conversation === null || text.length === 0) return;
    if (text.length > 2000) { promptAction.showToast({ message: '问题最多 2000 字' }); return; }
    if (this.online) {
      const decision = AiSafetyService.input(text);
      if (!decision.allowed) { this.inputText = ''; this.add(decision.reply); return; }
    }
    this.inputText = ''; this.add(text, '我'); this.busy = true;
    const selectedTool: string = AssistantShortcutService.focus(text);
    if (selectedTool !== '') this.toolScope = selectedTool;
    this.agentHistory.push({ role: 'user', content: text });
    try {
      await this.persistConversation();
      const context = getContext(this) as common.UIAbilityContext;
      const shortcut = await AssistantShortcutService.run(context, this.owner, text);
      if (shortcut !== null) {
        this.agentHistory.push({ role: 'assistant', content: shortcut.text });
        await this.deliverReply(shortcut.text);
        if (!this.sameOwner()) return;
        if (shortcut.route !== '') this.openPage(shortcut.route);
      } else if (this.online) {
        if (this.config === null || !this.ready) { this.online = false; this.add('当前没有可用的备用模型。'); return; }
        if (!this.sameOwner()) return;
        const label: string = this.onlineLabel();
        const answer: string = await AiChatService.sendMessage(text, this.config);
        this.agentHistory.push({ role: 'assistant', content: answer });
        await this.deliverReply(answer, label);
      } else {
        const result = await LocalAgentService.run(context, this.owner, text, this.agentHistory, this.toolScope);
        if (result.changed) this.toolScope = '';
        await this.deliverReply(result.text);
        if (!this.sameOwner()) return;
        if (result.changed) this.onDataChanged();
        if (result.route !== '') this.openPage(result.route);
        this.agentHistory = this.agentHistory.slice(-8);
      }
    } catch (error) {
      await this.deliverReply(error instanceof Error ? error.message : '这次没能完成，请稍后重试。');
    } finally {
      try { if (this.active) await this.persistConversation(); }
      catch (_) { if (this.sameOwner()) promptAction.showToast({ message: '本条对话未能保存，请检查存储空间' }); }
      this.busy = false;
    }
  }

  private selectProvider(index: number): void {
    if (index < 0 || index >= AiProviderPresets.ALL.length) return;
    const next = AiProviderPresets.ALL[index];
    if (this.endpoint !== next.endpoint) this.apiKey = '';
    this.provider = index; this.endpoint = next.endpoint; this.model = next.model;
    this.advancedVisible = index === 3; this.formMessage = '';
  }

  private onlineLabel(): string {
    if (this.config === null) return '配置云端模型…';
    const index: number = AiProviderPresets.indexOf(this.config.endpoint);
    const label: string = index === 3 ? '在线模型' : AiProviderPresets.ALL[index].label;
    return label + ' · ' + this.config.model;
  }

  private openPage(route: string): void {
    const allowed: string[] = ['TaskPage', 'EmergencyContactPage', 'CountdownManagePage'];
    if (!allowed.includes(route)) return;
    if (this.sameOwner()) this.onNavigate(route);
  }

  @Builder
  private settingsPanel() {
    Column({ space: 12 }) {
      if (this.owner === '') {
        Button('登录 App 账号').height(48).onClick(() => this.onNavigate('ProfilePage'))
      } else {
        Text('服务商').fontSize(14).fontColor(AppTheme.inkSoft).width('100%')
        Select(AiProviderPresets.ALL.map((item: AiProviderPreset): SelectOption => { return { value: item.label }; }))
          .selected(this.provider).value(AiProviderPresets.ALL[this.provider].label)
          .width('100%').height(48).font({ size: 15 }).backgroundColor(AppTheme.surfaceMuted)
          .borderRadius(12).onSelect((index: number) => this.selectProvider(index))
          .accessibilityText('选择在线服务商')
        if (this.advancedVisible) {
        Text('服务地址（HTTPS）').fontSize(14).fontColor(AppTheme.inkSoft).width('100%')
        TextInput({ text: this.endpoint })
          .height(48).maxLength(300).onChange((v: string) => this.endpoint = v)
          .accessibilityText('完整 HTTPS 服务地址')
          .attributeModifier(new CampusInputStyle())
        Text('模型 ID').fontSize(14).fontColor(AppTheme.inkSoft).width('100%')
        TextInput({ text: this.model })
          .height(48).maxLength(100).onChange((v: string) => this.model = v).accessibilityText('模型 ID')
          .attributeModifier(new CampusInputStyle())
        }
        Button(this.advancedVisible ? '收起高级设置' : '模型与地址').height(44).fontSize(13)
          .fontColor(AppTheme.inkSoft).backgroundColor(Color.Transparent).width('100%')
          .onClick(() => this.advancedVisible = !this.advancedVisible)
        Text('API Key').fontSize(14).fontColor(AppTheme.inkSoft).width('100%')
        TextInput({ text: this.apiKey, placeholder: AiConfigService.retainedKey(this.endpoint, this.config) !== '' ? '已加密保存' : '' })
          .height(48).maxLength(512).type(InputType.Password).onChange((v: string) => this.apiKey = v)
          .accessibilityText('API 密钥，已保存时留空保留')
          .attributeModifier(new CampusInputStyle())
        Row({ space: 12 }) {
          Text('记住配置').fontSize(14).fontColor(AppTheme.inkSoft).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.remember }).onChange((v: boolean) => this.remember = v)
            .accessibilityText('记住 API 配置，关闭后仅本次使用')
        }.width('100%')
        Button(this.busy ? '正在处理…' : '保存配置').height(48).width('100%').enabled(!this.busy)
          .onClick(() => this.saveConfig())
        Button('清除 API 配置').height(48).width('100%').enabled(!this.busy)
          .fontColor(AppTheme.inkSoft).backgroundColor(AppTheme.surfaceMuted).onClick(() => this.askClearConfig())
      }
      if (this.formMessage !== '') { Text(this.formMessage).fontSize(14).fontColor(AppTheme.inkSoft).width('100%') }
    }.width('100%').padding(16).backgroundColor(AppTheme.surface).borderRadius(16)
  }

  @Builder
  private quickButton(label: string) {
    Button(label).height(48).fontSize(14).layoutWeight(1).fontColor(AppTheme.inkSoft)
      .backgroundColor(AppTheme.surfaceMuted).enabled(!this.busy && !this.loading).onClick(() => this.send(label))
  }

  private isConversation(): boolean {
    return !this.settingsVisible && !this.historyVisible;
  }

  private returnToConversation(): void {
    this.settingsVisible = false; this.historyVisible = false;
    this.apiKey = ''; this.scroller.scrollEdge(Edge.Top);
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Column({ space: 4 }) {
          Text(this.settingsVisible ? '在线模型设置' : this.historyVisible ? '历史对话' : '小安')
            .fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
          if (this.settingsVisible) {
            Text(this.settingsVisible ? '兼容 Chat Completions' : '本机提醒')
              .fontSize(13).fontColor(AppTheme.inkSoft)
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (this.isConversation()) {
          Button('对话').height(40).fontSize(13).fontColor(AppTheme.inkSoft).backgroundColor(AppTheme.surface)
            .enabled(!this.busy && !this.loading).onClick(() => this.historyVisible = true)
          Button('新建').height(40).fontSize(13).fontColor(AppTheme.inkSoft).backgroundColor(AppTheme.surface)
            .enabled(!this.busy && !this.loading).onClick(() => this.newConversation())
        }
        Button(this.isConversation() ? '设置' : '返回对话').height(48).fontSize(14)
          .fontColor(AppTheme.inkSoft).backgroundColor(AppTheme.surface).enabled(!this.busy && !this.loading)
          .onClick(() => {
            if (!this.isConversation()) this.returnToConversation();
            else { this.settingsVisible = true; this.scroller.scrollEdge(Edge.Top); }
          })
      }.width('100%')
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          if (this.settingsVisible) { this.settingsPanel() }
          if (this.historyVisible) {
            ForEach(this.conversations, (item: ConversationSummary) => {
              Row({ space: 12 }) {
                Column({ space: 6 }) {
                  Text(item.title).fontSize(16).fontColor(AppTheme.ink).maxLines(2).width('100%')
                  Text(new Date(item.updatedAt).toLocaleString()).fontSize(12).fontColor(AppTheme.inkSoft).width('100%')
                }.layoutWeight(1).onClick(() => this.openConversation(item.id))
                Button('删除').fontSize(12).height(36).fontColor(AppTheme.inkSoft).backgroundColor(Color.Transparent)
                  .enabled(!this.busy).onClick(() => this.deleteConversation(item.id))
              }.width('100%').padding(16).borderRadius(16)
                .backgroundColor(item.id === this.conversationId ? AppTheme.accentSoft : AppTheme.surface)
            }, (item: ConversationSummary) => item.id)
            Button('新建对话').height(48).width('100%').enabled(!this.busy).onClick(() => this.newConversation())
          }
          if (this.isConversation()) {
          if (this.messages.length === 0) {
            Column({ space: 16 }) {
              Image($r('app.media.ic_shield_check')).width(36).height(36).fillColor(AppTheme.accent).accessibilityLevel('no')
              Text('你好，我是小安').fontSize(20).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
            }.width('100%').padding(20).backgroundColor(AppTheme.surface).borderRadius(16)
          }
          Row({ space: 8 }) {
            this.quickButton('安全提示'); this.quickButton('创建提醒'); this.quickButton('我的提醒')
          }.width('100%')
          ForEach(this.messages, (item: ChatMessage) => {
            Column({ space: 8 }) {
              Text(item.source).fontSize(13).fontColor(AppTheme.inkSoft).width('100%')
              if (item.source === '我') {
                Text(item.text).fontSize(16).lineHeight(24).fontColor(AppTheme.ink).width('100%')
                  .copyOption(CopyOptions.LocalDevice).wordBreak(WordBreak.BREAK_WORD)
              } else { MarkdownContent({ blocks: item.markdown }) }
            }.width('100%').padding(16).backgroundColor(item.source === '我' ? AppTheme.accentSoft : AppTheme.surface).borderRadius(16)
          }, (item: ChatMessage) => item.id.toString())
          }
          if (this.busy) { Text('正在处理，请稍候…').fontSize(14).fontColor(AppTheme.inkSoft) }
        }.width('100%').padding({ bottom: 12 }).onAreaChange(() => {
          if (this.scrollPending) { this.scrollPending = false; this.scroller.scrollEdge(Edge.Bottom); }
        })
      }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Auto)
      if (this.isConversation()) {
        Column({ space: 4 }) {
          TextArea({ text: this.inputText, placeholder: '和小安聊一聊…' })
            .height(68).maxLength(2000).backgroundColor(Color.Transparent).border({ width: 0 })
            .fontSize(16).placeholderFont({ size: 16, weight: FontWeight.Normal })
            .placeholderColor(AppTheme.inputPlaceholder).fontColor(AppTheme.ink).caretColor(AppTheme.accent)
            .padding({ left: 4, right: 4, top: 8, bottom: 4 })
            .onChange((v: string) => this.inputText = v).accessibilityText('向小安输入问题或提醒')
          Row() {
            Select([{ value: '小安' }, { value: this.onlineLabel() }])
              .selected(this.modelSelection).value(this.online ? this.onlineLabel() : '小安')
              .height(44).font({ size: 13 }).backgroundColor(Color.Transparent).fontColor(AppTheme.inkSoft)
              .constraintSize({ maxWidth: '78%' }).enabled(!this.busy && !this.loading)
              .onSelect((index: number) => this.chooseModel(index)).accessibilityText('选择小安的本地模式或在线模型')
            Blank()
            Button() {
              Image($r('app.media.ic_send_up')).width(22).height(22).accessibilityLevel('no')
            }.width(44).height(44).padding(0)
              .backgroundColor(AppTheme.accent).borderRadius(22).accessibilityText('发送消息')
              .enabled(!this.busy && this.inputText.trim() !== '').onClick(() => this.send())
          }.width('100%')
        }.width('100%').padding({ left: 16, right: 12, top: 8, bottom: 10 })
          .backgroundColor(AppTheme.surface).borderRadius(22).border({ width: 1, color: AppTheme.line })
          .margin({ bottom: 20 })
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.canvas)
  }
}
