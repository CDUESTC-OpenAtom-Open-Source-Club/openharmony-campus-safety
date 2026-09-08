import { promptAction } from '@kit.ArkUI';
import { AccountService, LoginResult } from '../service/AccountService';

@Component
export struct LoginPage {
  onLogin: () => void = (): void => {};
  @State private username: string = '';
  @State private password: string = '';
  @State private submitting: boolean = false;

  private login(): void {
    if (this.submitting || this.username.trim() === '' || this.password === '') {
      return;
    }
    this.submitting = true;
    AccountService.login(this.username, this.password).then((result: LoginResult) => {
      this.submitting = false;
      if (!result.success) {
        promptAction.showToast({ message: result.message });
        return;
      }
      this.onLogin();
    }).catch((error: Error) => {
      this.submitting = false;
      console.error('Login failed: ' + error.message);
      promptAction.showToast({ message: '登录失败，请稍后重试' });
    });
  }

  build() {
    Column() {
      Blank()

      Column({ space: 10 }) {
        Row() {
          Image($r('app.media.ic_shield'))
            .width(44)
            .height(44)
            .fillColor(Color.White)
        }
        .width(86)
        .height(86)
        .borderRadius(26)
        .linearGradient({
          angle: 135,
          colors: [['#2563EB', 0.0], ['#6366F1', 1.0]]
        })
        .justifyContent(FlexAlign.Center)
        .shadow({ radius: 20, color: 'rgba(37,99,235,0.28)', offsetY: 8 })

        Text('鸿蒙智安')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')

        Text('校园安全协同 · 正式测试版')
          .fontSize(12)
          .fontColor('#64748B')
      }

      Column({ space: 14 }) {
        TextInput({ placeholder: '请输入账号', text: this.username })
          .height(50)
          .fontSize(14)
          .backgroundColor('#F8FAFC')
          .border({ width: 1, color: '#CBD5E1' })
          .borderRadius(14)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.username = value;
          })

        TextInput({ placeholder: '请输入密码', text: this.password })
          .type(InputType.Password)
          .height(50)
          .fontSize(14)
          .backgroundColor('#F8FAFC')
          .border({ width: 1, color: '#CBD5E1' })
          .borderRadius(14)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.password = value;
          })
          .onSubmit(() => {
            this.login();
          })

        Button(this.submitting ? '正在登录...' : '登录')
          .width('100%')
          .height(50)
          .borderRadius(14)
          .backgroundColor('#2563EB')
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
          .enabled(!this.submitting)
          .onClick(() => {
            this.login();
          })

        Text('测试账号：admin / inspector / student / teacher\n初始密码分别为 admin12345 / inspect123 / student123 / teacher123')
          .fontSize(10)
          .lineHeight(16)
          .fontColor('#94A3B8')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding(22)
      .borderRadius(22)
      .backgroundColor(Color.White)
      .border({ width: 1, color: '#E2E8F0' })
      .shadow({ radius: 16, color: 'rgba(15,23,42,0.06)', offsetY: 6 })
      .margin({ top: 38 })

      Blank()

      Text('本地账号仅用于应用内角色隔离，不等同于校园统一身份认证')
        .fontSize(10)
        .fontColor('#94A3B8')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 28 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 22, right: 22 })
    .linearGradient({
      angle: 180,
      colors: [['#EFF6FF', 0.0], ['#F8FAFC', 0.55], ['#EEF2FF', 1.0]]
    })
  }
}
