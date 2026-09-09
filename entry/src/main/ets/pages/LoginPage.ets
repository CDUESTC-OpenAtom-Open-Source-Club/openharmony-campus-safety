import { promptAction } from '@kit.ArkUI';
import { AccountService, LoginResult } from '../service/AccountService';
import { UserRole } from '../model/User';

@Component
export struct LoginPage {
  onLogin: () => void = (): void => {};
  @State private username: string = '';
  @State private password: string = '';
  @State private displayName: string = '';
  @State private registerMode: boolean = false;
  @State private internalMode: boolean = false;
  @State private invitationCode: string = '';
  @State private role: UserRole = UserRole.STUDENT;
  @State private submitting: boolean = false;

  private submit(): void {
    if (this.submitting) return;
    this.submitting = true;
    let request: Promise<LoginResult>;
    if (AccountService.needsAdministratorBootstrap()) {
      request = AccountService.bootstrapAdministrator(this.username, this.displayName, this.password);
    } else if (this.internalMode) {
      request = AccountService.registerInternalUser(this.invitationCode, this.username, this.displayName, this.password);
    } else if (this.registerMode) {
      request = AccountService.registerUser(this.username, this.displayName, this.password, this.role);
    } else {
      request = AccountService.login(this.username, this.password);
    }
    request.then((result: LoginResult) => {
      this.submitting = false;
      promptAction.showToast({ message: result.message });
      if (result.success && !this.registerMode && !this.internalMode) this.onLogin();
      if (result.success && (this.registerMode || this.internalMode)) {
        this.registerMode = false;
        this.internalMode = false;
        this.password = '';
        this.invitationCode = '';
      }
    }).catch(() => {
      this.submitting = false;
      promptAction.showToast({ message: '操作失败，请稍后重试' });
    });
  }

  private isBootstrap(): boolean {
    return AccountService.needsAdministratorBootstrap();
  }

  private needsProfile(): boolean {
    return this.isBootstrap() || this.registerMode || this.internalMode;
  }

  build() {
    Column() {
      Blank()
      Column({ space: 10 }) {
        Text('鸿蒙智安').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#0F172A')
        Text(this.isBootstrap() ? '首次安装：初始化管理员' :
          (this.internalMode ? '内部身份开通' : (this.registerMode ? '注册普通用户' : '校园安全协同 · Beta')))
          .fontSize(13).fontColor('#64748B')
      }.alignItems(HorizontalAlign.Center)
      Column({ space: 14 }) {
        if (this.needsProfile()) {
          TextInput({ placeholder: this.isBootstrap() ? '管理员姓名' : '姓名', text: this.displayName })
            .onChange((value: string) => this.displayName = value)
        }
        TextInput({ placeholder: '账号（3—32 位字母、数字或下划线）', text: this.username })
          .onChange((value: string) => this.username = value)
        TextInput({ placeholder: '密码（至少 10 位，含字母和数字）', text: this.password })
          .type(InputType.Password).onChange((value: string) => this.password = value)
        if (this.internalMode && !this.isBootstrap()) {
          TextInput({ placeholder: '内部邀请码（由管理员签发）', text: this.invitationCode })
            .onChange((value: string) => this.invitationCode = value)
        }
        if (this.registerMode && !this.internalMode && !this.isBootstrap()) {
          Row({ space: 8 }) {
            Button('学生').backgroundColor(this.role === UserRole.STUDENT ? '#2563EB' : '#E2E8F0')
              .fontColor(this.role === UserRole.STUDENT ? Color.White : '#334155').onClick(() => this.role = UserRole.STUDENT)
            Button('教师').backgroundColor(this.role === UserRole.TEACHER ? '#2563EB' : '#E2E8F0')
              .fontColor(this.role === UserRole.TEACHER ? Color.White : '#334155').onClick(() => this.role = UserRole.TEACHER)
          }.width('100%')
        }
        Button(this.submitting ? '正在处理...' : (this.isBootstrap() ? '完成管理员初始化' :
          (this.internalMode ? '验证邀请码并开通' : (this.registerMode ? '提交注册' : '登录'))))
          .width('100%').height(50).backgroundColor('#2563EB').fontColor(Color.White).onClick(() => this.submit())
        if (!this.isBootstrap() && !this.internalMode) {
          Button(this.registerMode ? '返回登录' : '注册学生 / 教师账号')
            .width('100%').backgroundColor('#EFF6FF').fontColor('#2563EB')
            .onClick(() => { this.registerMode = !this.registerMode; this.internalMode = false; this.password = ''; })
        }
        if (!this.isBootstrap() && !this.registerMode) {
          Text('内部人员开通 ›').fontSize(11).fontColor('#64748B').textAlign(TextAlign.Center)
            .onClick(() => { this.internalMode = true; this.password = ''; })
        }
        if (this.internalMode) {
          Text('返回登录').fontSize(12).fontColor('#2563EB').textAlign(TextAlign.Center)
            .onClick(() => { this.internalMode = false; this.invitationCode = ''; this.password = ''; })
        }
        Text(this.isBootstrap() ? '管理员口令仅由首次设备持有人设置，应用不提供默认管理员账号。' :
          '安保与管理员只可通过管理员签发的一次性限时邀请码开通；本地账号不替代校园统一身份认证。')
          .fontSize(10).fontColor('#64748B').lineHeight(16).textAlign(TextAlign.Center)
      }.width('100%').padding(22).borderRadius(22).backgroundColor(Color.White).margin({ top: 38 })
      Blank()
    }.width('100%').height('100%').padding(24).backgroundColor('#F8FAFC')
  }
}
