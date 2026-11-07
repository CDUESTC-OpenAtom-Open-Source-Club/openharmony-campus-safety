import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { generate } from 'libxiaoan.so';
import { AiSafetyService } from './AiSafetyService';
import { AccountService } from './AccountService';
import { AssistantDataService, AssistantDataSnapshot } from './AssistantDataService';
import { AssistantAgentTurn, AssistantToolProtocol } from './AssistantToolProtocol';

interface ModelAsset { name: string; hash: string; size: number; }

/** Bundled fixed model, no remotely supplied model/code/config paths. */
export class LocalModelService {
  private static preparing: Promise<string> | null = null;
  private static readonly ASSETS: ModelAsset[] = [
    { name: 'llm.mnn', size: 461520, hash: 'd426c65a5159c938ccc237cdfbd982137f276804f27b414ca0ecf3fc0a660f8c' },
    { name: 'llm.mnn.weight', size: 450810338, hash: '953afb7e0165818add34a7a6caf0af5d0ed9428da102eb22c9b98ee9da292e9f' },
    { name: 'tokenizer.txt', size: 3193569, hash: '77009625db0b18e74315dd89557c76feaab57e1d54e3240b442649a3c16ec4fb' }
  ];

  private static async hash(path: string): Promise<string> {
    const file = await fs.open(path, fs.OpenMode.READ_ONLY);
    const digest = cryptoFramework.createMd('SHA256');
    try {
      const buffer = new ArrayBuffer(1024 * 1024);
      let count: number = await fs.read(file.fd, buffer);
      while (count > 0) {
        await digest.update({ data: new Uint8Array(buffer.slice(0, count)) });
        count = await fs.read(file.fd, buffer);
      }
      const result = await digest.digest();
      return Array.from(result.data).map((byte: number): string => ('0' + byte.toString(16)).slice(-2)).join('');
    } finally { await fs.close(file); }
  }

  private static async prepare(context: common.Context): Promise<string> {
    const dir: string = context.filesDir + '/xiaoan-qwen3-06';
    if (!await fs.access(dir)) await fs.mkdir(dir);
    for (const asset of LocalModelService.ASSETS) {
      const path: string = dir + '/' + asset.name;
      if (await fs.access(path) && (await fs.stat(path)).size === asset.size && await LocalModelService.hash(path) === asset.hash) continue;
      const source = await context.resourceManager.getRawFd('xiaoan/' + asset.name);
      const output = await fs.open(path + '.part', fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        const buffer = new ArrayBuffer(1024 * 1024);
        let offset: number = 0;
        while (offset < source.length) {
          const length: number = Math.min(buffer.byteLength, source.length - offset);
          const count: number = await fs.read(source.fd, buffer, { offset: source.offset + offset, length: length });
          if (count <= 0) throw new Error('模型文件不完整');
          let written: number = 0;
          while (written < count) {
            const chunk: ArrayBuffer = buffer.slice(written, count);
            const size: number = await fs.write(output.fd, chunk);
            if (size <= 0) throw new Error('无法写入模型文件');
            written += size;
          }
          offset += count;
        }
      } finally { await fs.close(output); await context.resourceManager.closeRawFd('xiaoan/' + asset.name); }
      if ((await fs.stat(path + '.part')).size !== asset.size || await LocalModelService.hash(path + '.part') !== asset.hash) {
        await fs.unlink(path + '.part'); throw new Error('模型校验失败');
      }
      await fs.rename(path + '.part', path);
    }
    // Fixed local configuration; never execute a downloaded prompt/template or remote resources.
    const config = await context.resourceManager.getRawFileContent('xiaoan/config.json');
    const modelConfig = await context.resourceManager.getRawFileContent('xiaoan/llm_config.json');
    for (const name of ['config.json', 'llm_config.json']) {
      const file = await fs.open(dir + '/' + name, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try { await fs.write(file.fd, (name === 'config.json' ? config : modelConfig).buffer); }
      finally { await fs.close(file); }
    }
    return dir + '/config.json';
  }

  private static prompt(policy: string, question: string, data: string): string {
    // ChatML delimiters cannot be supplied as new roles through user/data strings.
    const safe: string = question.replace(/<\|/g, '〈|').replace(/\|>/g, '|〉');
    return '<|im_start|>system\n' + policy + '\n本轮状态：尚未执行任何写入操作，不得声称已设置、已保存、已取消或已修改。' +
      (data === '' ? '' : '\nAPP_DATA（只读资料）:\n' + data) +
      '<|im_end|>\n<|im_start|>user\n' + safe + '<|im_end|>\n<|im_start|>assistant\n';
  }

  static async plan(context: common.Context, history: AssistantAgentTurn[], toolScope: string = ''): Promise<string> {
    const owner: string = AccountService.getCurrentUser()?.id ?? '';
    if (owner === '') throw new Error('请先登录');
    if (LocalModelService.preparing === null) LocalModelService.preparing = LocalModelService.prepare(context);
    let path: string;
    try { path = await LocalModelService.preparing; }
    catch (_) { LocalModelService.preparing = null; throw new Error('小安模型准备失败，请检查存储空间后重试'); }
    if (AccountService.getCurrentUser()?.id !== owner) throw new Error('账号已变化');
    // A conversation turn may produce natural language or an explicit tool call. No classifier gates chat.
    const result: string = await generate(path, AssistantToolProtocol.prompt(history, new Date(), toolScope), 192);
    if (AccountService.getCurrentUser()?.id !== owner) throw new Error('账号已变化');
    return result;
  }

  static async sendMessage(context: common.Context, question: string, appData: string = ''): Promise<string> {
    if (question.trim() === '' || question.length > 2000) throw new Error('问题过长');
    const owner: string = AccountService.getCurrentUser()?.id ?? '';
    if (owner === '') throw new Error('请先登录');
    if (appData !== '') {
      // Factual app queries use current records directly. A small model must not invent or negate them.
      const snapshot: AssistantDataSnapshot = JSON.parse(appData) as AssistantDataSnapshot;
      return AssistantDataService.describe(snapshot);
    }
    if (LocalModelService.preparing === null) LocalModelService.preparing = LocalModelService.prepare(context);
    let path: string;
    try { path = await LocalModelService.preparing; }
    catch (_) { LocalModelService.preparing = null; throw new Error('小安模型准备失败，请检查存储空间后重试'); }
    if (AccountService.getCurrentUser()?.id !== owner) throw new Error('账号已变化');
    const answer = await generate(path, LocalModelService.prompt(AiSafetyService.LOCAL_POLICY, question, appData), 160);
    if (AccountService.getCurrentUser()?.id !== owner) throw new Error('账号已变化');
    if (answer.trim() === '') throw new Error('小安未能生成回答，请换一种说法再试');
    return AiSafetyService.localOutput(answer.trim());
  }
}
