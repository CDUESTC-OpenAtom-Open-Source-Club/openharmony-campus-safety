import { common } from '@kit.AbilityKit';
import { AccountService } from './AccountService';
import { LocalModelService } from './LocalModelService';
import { AssistantAgentTurn, AssistantToolProtocol } from './AssistantToolProtocol';
import { AssistantToolExecutor, AssistantToolResult } from './AssistantToolExecutor';
import { AiSafetyService } from './AiSafetyService';

/** Model decides every intent and argument. The app only validates and executes registered tools. */
export class LocalAgentService {
  private static owner(owner: string): void {
    if (owner === '' || AccountService.getCurrentUser()?.id !== owner) throw new Error('账号已变化，请重新发送');
  }

  static async run(context: common.UIAbilityContext, owner: string, question: string,
    history: AssistantAgentTurn[], toolScope: string = ''): Promise<AssistantToolResult> {
    LocalAgentService.owner(owner);
    if (question.trim() === '' || question.length > 2000) throw new Error('请输入不超过2000字的问题');
    const last = history[history.length - 1];
    if (last?.role !== 'user' || last.content !== question) history.push({ role: 'user', content: question });
    let lastError: string = '';
    const receipts: string[] = [];
    const completed: string[] = [];
    let changed: boolean = false;
    let route: string = '';
    for (let step: number = 0; step < 4; step++) {
      LocalAgentService.owner(owner);
      const raw: string = await LocalModelService.plan(context, history, toolScope);
      LocalAgentService.owner(owner);
      history.push({ role: 'assistant', content: AssistantToolProtocol.visible(raw).slice(0, 2400) });
      try {
        const call = AssistantToolProtocol.parse(raw);
        if (call.tool === 'chat' || call.tool === 'ask') {
          if (typeof call.args.text !== 'string' || call.args.text.trim() === '' || call.args.text.length > 4000) throw new Error('缺少text回答字段');
          const reply: string = AiSafetyService.localOutput(call.args.text.trim());
          history[history.length - 1].content = reply;
          if (!changed && /^(?:好的[，,。！!\s]*)?(?:我(?:已经|已|帮你)?|已经|已|成功)(?:帮你)?(?:设置|创建|添加|保存|取消|删除|修改|更新)/.test(reply)) {
            throw new Error('本轮尚未执行写入工具，不能报告已完成；需要操作时请实际调用工具');
          }
          return { text: reply, changed: changed, route: route };
        }
        const fingerprint: string = call.tool + ':' + JSON.stringify(call.args, Object.keys(call.args).sort());
        if (completed.includes(fingerprint)) throw new Error('此工具调用已经成功执行，请根据已有工具结果回答，不要重复执行');
        const result = await AssistantToolExecutor.execute(context, owner, call);
        LocalAgentService.owner(owner);
        history.push({ role: 'user', content: '<tool_response>\n' + JSON.stringify({ ok: true, tool: call.tool, result: result.text.slice(0, 1000) }) + '\n</tool_response>' });
        lastError = '';
        completed.push(fingerprint);
        receipts.push(result.text);
        changed = changed || result.changed;
        if (result.route !== '') route = result.route;
        // Return the real result to the model so it can answer or request another tool.
      } catch (error) {
        LocalAgentService.owner(owner);
        lastError = error instanceof Error ? error.message : '工具调用失败';
        history.push({ role: 'user', content: '<tool_response>\n' + JSON.stringify({ ok: false, error: lastError }) +
          '\n</tool_response>\n工具未执行成功，请修正参数；缺少用户信息就只追问缺少的内容，不要声称已完成。' });
      }
    }
    if (receipts.length > 0) return { text: receipts.join('\n\n') +
      (lastError === '' ? '' : '\n\n后续操作未完成：' + lastError), changed: changed, route: route };
    return { text: '这次还没能完成。' + (lastError === '' ? '请具体说说要做什么。' : lastError), changed: false, route: '' };
  }
}
