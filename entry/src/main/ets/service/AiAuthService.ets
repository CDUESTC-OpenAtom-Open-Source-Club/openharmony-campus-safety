
import { http } from '@kit.NetworkKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export class AiAuthService {
  private static readonly LOGIN_URL: string =
    'https://hongmengzhian.tippydes.com/api/auth/login';

  private static readonly PREF_NAME: string = 'ai_auth_preferences';
  private static readonly TOKEN_KEY: string = 'ai_access_token';

  static async login(
    context: common.Context,
    email: string,
    password: string
  ): Promise<void> {
    const normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.length === 0 || password.length === 0) {
      throw new Error('请输入 AI 服务邮箱和密码');
    }

    const request = http.createHttp();

    try {
      const response = await request.request(
        AiAuthService.LOGIN_URL,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            email: normalizedEmail,
            password: password
          }),
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 15000,
          readTimeout: 15000
        }
      );

      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(
          `AI 服务登录失败，HTTP ${response.responseCode}`
        );
      }

      const data = JSON.parse(
        response.result as string
      ) as Record<string, string>;

      if (!data.access_token) {
        throw new Error('服务器没有返回登录令牌');
      }

      const pref = await preferences.getPreferences(
        context,
        AiAuthService.PREF_NAME
      );

      await pref.put(AiAuthService.TOKEN_KEY, data.access_token);
      await pref.flush();
    } finally {
      request.destroy();
    }
  }

  static async getToken(context: common.Context): Promise<string> {
    const pref = await preferences.getPreferences(
      context,
      AiAuthService.PREF_NAME
    );

    const value = await pref.get(AiAuthService.TOKEN_KEY, '');

    return typeof value === 'string' ? value : '';
  }

  static async logout(context: common.Context): Promise<void> {
    const pref = await preferences.getPreferences(
      context,
      AiAuthService.PREF_NAME
    );

    await pref.delete(AiAuthService.TOKEN_KEY);
    await pref.flush();
  }
}
