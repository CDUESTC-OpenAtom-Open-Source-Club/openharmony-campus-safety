import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { AccountService } from './AccountService';
import { AssistantAgentTurn } from './AssistantToolProtocol';

export interface SavedChatMessage { text: string; source: string; }
export interface AssistantConversation { id: string; title: string; updatedAt: number; messages: SavedChatMessage[]; turns: AssistantAgentTurn[]; toolScope?: string; }
export interface ConversationSummary { id: string; title: string; updatedAt: number; }
export interface ConversationIndex { selectedId: string; items: ConversationSummary[]; }

/** Account-scoped private files; atomic message writes, serialized index updates, no API configuration. */
export class AssistantConversationService {
  private static serial: Promise<void> = Promise.resolve();
  private static sequence: number = 0;

  private static owner(owner: string): void {
    if (!/^[A-Za-z0-9_-]{1,100}$/.test(owner) || AccountService.getCurrentUser()?.id !== owner) throw new Error('账号已变化，无法读取对话');
  }

  private static safe(text: string): string {
    return text.replace(/\bBearer\s+[A-Za-z0-9._-]{12,}|\bsk-[A-Za-z0-9_-]{12,}/gi, '（敏感凭证已隐藏）');
  }

  private static path(context: common.Context, owner: string, id: string): string {
    AssistantConversationService.owner(owner);
    if (!/^chat_[0-9_]{1,60}$/.test(id)) throw new Error('无效的对话编号');
    return context.filesDir + '/xiaoan-chats/' + owner + '/' + id + '.json';
  }

  private static async readIndex(context: common.Context, owner: string): Promise<ConversationIndex> {
    AssistantConversationService.owner(owner);
    const pref = await preferences.getPreferences(context, 'xiaoan_chat_index');
    const raw = await pref.get(owner, '');
    AssistantConversationService.owner(owner);
    if (raw === '') return { selectedId: '', items: [] };
    if (typeof raw !== 'string') throw new Error('对话索引无法读取');
    const index = JSON.parse(raw) as ConversationIndex;
    if (!Array.isArray(index.items) || typeof index.selectedId !== 'string' || index.items.length > 20) throw new Error('对话索引无法读取');
    return index;
  }

  private static async writeIndex(context: common.Context, owner: string, index: ConversationIndex): Promise<void> {
    const pref = await preferences.getPreferences(context, 'xiaoan_chat_index');
    AssistantConversationService.owner(owner);
    index.items.sort((a: ConversationSummary, b: ConversationSummary) => b.updatedAt - a.updatedAt);
    await pref.put(owner, JSON.stringify(index)); await pref.flush();
    AssistantConversationService.owner(owner);
  }

  private static async writeFile(context: common.Context, owner: string, conversation: AssistantConversation): Promise<void> {
    const root: string = context.filesDir + '/xiaoan-chats';
    const dir: string = root + '/' + owner;
    if (!await fs.access(root)) await fs.mkdir(root);
    if (!await fs.access(dir)) await fs.mkdir(dir);
    const path: string = AssistantConversationService.path(context, owner, conversation.id);
    const data: Uint8Array = new util.TextEncoder().encodeInto(JSON.stringify(conversation));
    const file = await fs.open(path + '.part', fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try {
      let offset: number = 0;
      while (offset < data.length) {
        const count: number = await fs.write(file.fd, data.buffer.slice(offset));
        if (count <= 0) throw new Error('对话保存失败');
        offset += count;
      }
    } finally { await fs.close(file); }
    AssistantConversationService.owner(owner);
    await fs.rename(path + '.part', path);
  }

  private static transaction(context: common.Context, owner: string,
    operation: (index: ConversationIndex) => Promise<ConversationIndex>): Promise<ConversationIndex> {
    const task: Promise<ConversationIndex> = AssistantConversationService.serial.then(async (): Promise<ConversationIndex> => {
      const index = await AssistantConversationService.readIndex(context, owner);
      return operation(index);
    });
    AssistantConversationService.serial = task.then(() => {}, () => {});
    return task;
  }

  static async list(context: common.Context, owner: string): Promise<ConversationIndex> {
    await AssistantConversationService.serial;
    return AssistantConversationService.readIndex(context, owner);
  }

  static create(context: common.Context, owner: string): Promise<ConversationIndex> {
    return AssistantConversationService.transaction(context, owner, async (index: ConversationIndex): Promise<ConversationIndex> => {
      if (index.items.length >= 20) throw new Error('最多保留20个对话，请先删除不再需要的对话');
      const conversation: AssistantConversation = { id: 'chat_' + Date.now() + '_' + (++AssistantConversationService.sequence),
        title: '新对话', updatedAt: Date.now(), messages: [], turns: [] };
      await AssistantConversationService.writeFile(context, owner, conversation);
      index.items.unshift({ id: conversation.id, title: conversation.title, updatedAt: conversation.updatedAt }); index.selectedId = conversation.id;
      await AssistantConversationService.writeIndex(context, owner, index); return index;
    });
  }

  static async read(context: common.Context, owner: string, id: string): Promise<AssistantConversation> {
    const index = await AssistantConversationService.list(context, owner);
    if (!index.items.some((item: ConversationSummary) => item.id === id)) throw new Error('没有找到这个对话');
    const raw: string = await fs.readText(AssistantConversationService.path(context, owner, id));
    AssistantConversationService.owner(owner);
    const conversation = JSON.parse(raw) as AssistantConversation;
    if (conversation.id !== id || !Array.isArray(conversation.messages) || !Array.isArray(conversation.turns)) throw new Error('对话内容无法读取');
    return conversation;
  }

  static save(context: common.Context, owner: string, conversation: AssistantConversation): Promise<ConversationIndex> {
    const copy: AssistantConversation = { id: conversation.id, title: conversation.title, updatedAt: Date.now(),
      toolScope: conversation.toolScope === 'reminder.create' ? 'reminder.create' : '',
      messages: conversation.messages.slice(-200).map((item: SavedChatMessage): SavedChatMessage =>
        ({ text: AssistantConversationService.safe(item.text.slice(0, 12000)), source: item.source.slice(0, 100) })),
      turns: conversation.turns.slice(-8).map((turn: AssistantAgentTurn): AssistantAgentTurn =>
        ({ role: turn.role === 'assistant' ? 'assistant' : 'user', content: AssistantConversationService.safe(turn.content.slice(0, 2400)) })) };
    if (copy.title === '新对话') copy.title = copy.messages.find((item: SavedChatMessage) => item.source === '我')?.text.replace(/\s+/g, ' ').slice(0, 24) ?? '新对话';
    return AssistantConversationService.transaction(context, owner, async (index: ConversationIndex): Promise<ConversationIndex> => {
      const position: number = index.items.findIndex((item: ConversationSummary) => item.id === copy.id);
      if (position < 0) throw new Error('这个对话已删除');
      await AssistantConversationService.writeFile(context, owner, copy);
      index.items[position] = { id: copy.id, title: copy.title, updatedAt: copy.updatedAt };
      await AssistantConversationService.writeIndex(context, owner, index); return index;
    });
  }

  static select(context: common.Context, owner: string, id: string): Promise<ConversationIndex> {
    return AssistantConversationService.transaction(context, owner, async (index: ConversationIndex): Promise<ConversationIndex> => {
      if (!index.items.some((item: ConversationSummary) => item.id === id)) throw new Error('没有找到这个对话');
      index.selectedId = id; await AssistantConversationService.writeIndex(context, owner, index); return index;
    });
  }

  static remove(context: common.Context, owner: string, id: string): Promise<ConversationIndex> {
    return AssistantConversationService.transaction(context, owner, async (index: ConversationIndex): Promise<ConversationIndex> => {
      const path: string = AssistantConversationService.path(context, owner, id);
      if (await fs.access(path)) await fs.unlink(path);
      index.items = index.items.filter((item: ConversationSummary) => item.id !== id);
      if (index.selectedId === id) index.selectedId = index.items[0]?.id ?? '';
      await AssistantConversationService.writeIndex(context, owner, index); return index;
    });
  }
}
