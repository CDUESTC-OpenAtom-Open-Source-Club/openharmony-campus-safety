
import { http } from '@kit.NetworkKit';

export class AiChatService {
  private static readonly CHAT_URL: string =
    'https://hongmengzhian.tippydes.com/api/chat';

  static async sendMessage(message: string, token: string): Promise<string> {
    const text = message.trim();

    if (text.length === 0) {
      throw new Error('请输入问题');
    }

    const httpRequest = http.createHttp();

    try {
      const response = await httpRequest.request(
        AiChatService.CHAT_URL,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
          },
          extraData: JSON.stringify({
            message: text
          }),
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 15000,
          readTimeout: 60000
        }
      );

      if (response.responseCode < 200 ||
        response.responseCode >= 300) {
        throw new Error(
          `AI 服务请求失败，HTTP ${response.responseCode}`
        );
      }

      const data = JSON.parse(
        response.result as string
      ) as Record<string, string>;

      if (!data.answer) {
        throw new Error('AI 服务没有返回有效答案');
      }

      return data.answer;
    } finally {
      httpRequest.destroy();
    }
  }
}
