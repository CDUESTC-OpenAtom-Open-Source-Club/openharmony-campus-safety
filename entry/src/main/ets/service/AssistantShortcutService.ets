import { common } from '@kit.AbilityKit';
import { AssistantToolExecutor, AssistantToolResult } from './AssistantToolExecutor';

/** Two explicit shortcuts only. All other messages go to the selected model unchanged. */
export class AssistantShortcutService {
  static focus(text: string): string {
    return text.trim().replace(/[。！!？?]+$/, '') === '创建提醒' ? 'reminder.create' : '';
  }
  static match(text: string): string {
    const command: string = text.trim().replace(/[。！!？?]+$/, '');
    if (command === '安全提示' || command === '校园安全提示') return 'safety.tips';
    if (command === '我的提醒' || command === '查看我的提醒') return 'reminders';
    return '';
  }

  static async run(context: common.UIAbilityContext, owner: string, text: string): Promise<AssistantToolResult | null> {
    const command: string = AssistantShortcutService.match(text);
    if (command === '') return null;
    if (command === 'reminders') return AssistantToolExecutor.execute(context, owner,
      { tool: 'app.read', args: { scope: 'reminders' } });
    return AssistantToolExecutor.execute(context, owner, { tool: command, args: {} });
  }
}
