import { promptAction } from '@kit.ArkUI';
import { AccountService, LoginResult } from '../service/AccountService';
import { UserRole } from '../model/User';
import { AppTheme } from '../common/AppTheme';

@Component
export struct LoginPage {
  onLogin: () => void = (): void => {};
  onBack: () => void = (): void => {};
  startInRegister: boolean = false;
  @State private username: string = '';
  @State private password: string = '';
  @State private confirmPassword: string = '';
  @State private displayName: string = '';
  @State private registerMode: boolean = false;
  @State private internalMode: boolean = false;
  @State private invitationCode: string = '';
  @State private role: UserRole = UserRole.STUDENT;
  @State private submitting: boolean = false;
  @State private formMessage: string = '';
  @State private formMessageIsError: boolean = false;

  aboutToAppear(): void {
    this.registerMode = this.startInRegister;
  }

  private submit(): void {
    if (this.submitting) return;
    if (this.registerMode && !this.internalMode && this.password !== this.confirmPassword) {
      this.formMessage = '两次输入的密码不一致，请重新确认';
      this.formMessageIsError = true;
      return;
    }
    this.submitting = true;
    this.formMessage = '';
    const openingRegistration: boolean = this.registerMode || this.internalMode;
    const publicRegistration: boolean = this.registerMode && !this.internalMode;
    let request: Promise<LoginResult>;
    if (this.internalMode) {
      request = AccountService.registerInternalUser(this.invitationCode, this.username, this.displayName, this.password);
    } else if (this.registerMode) {
      request = AccountService.registerUser(
        this.username, this.displayName, this.password, this.role, this.confirmPassword
      );
    } else {
      request = AccountService.login(this.username, this.password);
    }
    request.then((result: LoginResult) => {
      this.submitting = false;
      this.formMessage = result.message;
      this.formMessageIsError = !result.success;
      promptAction.showToast({ message: result.message });
      if (result.success && !openingRegistration) this.onLogin();
      if (result.success && openingRegistration) {
        this.registerMode = false;
        this.internalMode = false;
        this.password = '';
        this.confirmPassword = '';
        this.invitationCode = '';
        if (publicRegistration) this.onLogin();
      }
    }).catch(() => {
      this.submitting = false;
      this.formMessage = '操作失败，请稍后重试';
      this.formMessageIsError = true;
      promptAction.showToast({ message: '操作失败，请稍后重试' });
    });
  }

  private needsProfile(): boolean {
    return this.registerMode || this.internalMode;
  }

  private resetMessage(): void {
    this.formMessage = '';
    this.formMessageIsError = false;
  }

  @Builder
  private fieldLabel(label: string, detail: string) {
    Column({ space: 5 }) {
      Row() {
        Text(label)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.inkSoft)
        Blank()
        Text(detail)
          .fontSize(10)
          .fontColor(AppTheme.muted)
      }
      .width('100%')
    }
    .width('100%')
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        // 顶部品牌导航
        Row() {
          Row() {
            Image($r('app.media.ic_shield_check'))
              .width(22)
              .height(22)
              .fillColor(Color.White)
          }
          .width(44)
          .height(44)
          .borderRadius(13)
          .backgroundColor(AppTheme.accent)
          .justifyContent(FlexAlign.Center)
          .shadow({ radius: 10, color: AppTheme.glowBlue, offsetY: 2 })

          Column({ space: 2 }) {
            Text('鸿蒙智安')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ink)
            Text('智慧校园身份与访问安全控制')
              .fontSize(10)
              .fontColor(AppTheme.muted)
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })

          Blank()

          Row({ space: 4 }) {
            Text('‹ 返回')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.accent)
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(8)
          .backgroundColor(AppTheme.accentSoft)
          .onClick(() => this.onBack())
        }
        .width('100%')

        // 认证卡片容器
        Column({ space: 18 }) {
          Column({ space: 6 }) {
            Text(this.internalMode ? '内部身份开通' : (this.registerMode ? '注册普通成员' : '登录协同平台'))
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ink)
              .width('100%')
            Text(this.internalMode ? '使用校级管理员签发的专用邀请凭证加入网格' : '验证身份后使用隐患流转、事件处置与应急专线功能')
              .fontSize(12)
              .fontColor(AppTheme.muted)
              .lineHeight(18)
              .width('100%')
          }
          .width('100%')

          Column({ space: 14 }) {
            if (this.needsProfile()) {
              Column({ space: 5 }) {
                this.fieldLabel('姓名', '展示名称')
                TextInput({ placeholder: '请输入您的真实姓名', text: this.displayName })
                  .height(44)
                  .backgroundColor(AppTheme.surfaceMuted)
                  .border({ width: 1, color: AppTheme.line })
                  .borderRadius(10)
                  .padding({ left: 12, right: 12 })
                  .onChange((value: string) => this.displayName = value)
              }
              .width('100%')
            }

            Column({ space: 5 }) {
              this.fieldLabel('账号', '3—32 位字母、数字或下划线')
              TextInput({ placeholder: '请输入登录账号', text: this.username })
                .height(44)
                .backgroundColor(AppTheme.surfaceMuted)
                .border({ width: 1, color: AppTheme.line })
                .borderRadius(10)
                .padding({ left: 12, right: 12 })
                .onChange((value: string) => this.username = value)
            }
            .width('100%')

            Column({ space: 5 }) {
              this.fieldLabel('密码', '至少 10 位')
              TextInput({ placeholder: '请输入密码', text: this.password })
                .height(44)
                .backgroundColor(AppTheme.surfaceMuted)
                .border({ width: 1, color: AppTheme.line })
                .borderRadius(10)
                .type(InputType.Password)
                .padding({ left: 12, right: 12 })
                .onChange((value: string) => this.password = value)
            }
            .width('100%')

            if (this.registerMode && !this.internalMode) {
              Column({ space: 5 }) {
                this.fieldLabel('确认密码', '与上方密码保持一致')
                TextInput({ placeholder: '请再次输入密码', text: this.confirmPassword })
                  .height(44)
                  .backgroundColor(AppTheme.surfaceMuted)
                  .border({ width: 1, color: AppTheme.line })
                  .borderRadius(10)
                  .type(InputType.Password)
                  .padding({ left: 12, right: 12 })
                  .onChange((value: string) => this.confirmPassword = value)
              }
              .width('100%')
            }

            if (this.internalMode) {
              Column({ space: 5 }) {
                this.fieldLabel('内部邀请码', '由管理员通过受控渠道签发')
                TextInput({ placeholder: '请输入 32 位安全邀请凭证', text: this.invitationCode })
                  .height(44)
                  .backgroundColor(AppTheme.surfaceMuted)
                  .border({ width: 1, color: AppTheme.line })
                  .borderRadius(10)
                  .padding({ left: 12, right: 12 })
                  .onChange((value: string) => this.invitationCode = value)
              }
              .width('100%')
            }

            if (this.registerMode && !this.internalMode) {
              Column({ space: 6 }) {
                Text('身份类型')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.inkSoft)
                  .width('100%')
                Row({ space: 8 }) {
                  Button('学生成员')
                    .layoutWeight(1)
                    .height(38)
                    .backgroundColor(this.role === UserRole.STUDENT ? AppTheme.accent : AppTheme.surfaceMuted)
                    .fontColor(this.role === UserRole.STUDENT ? Color.White : AppTheme.inkSoft)
                    .fontWeight(this.role === UserRole.STUDENT ? FontWeight.Bold : FontWeight.Normal)
                    .borderRadius(8)
                    .onClick(() => this.role = UserRole.STUDENT)
                  Button('教师人员')
                    .layoutWeight(1)
                    .height(38)
                    .backgroundColor(this.role === UserRole.TEACHER ? AppTheme.accent : AppTheme.surfaceMuted)
                    .fontColor(this.role === UserRole.TEACHER ? Color.White : AppTheme.inkSoft)
                    .fontWeight(this.role === UserRole.TEACHER ? FontWeight.Bold : FontWeight.Normal)
                    .borderRadius(8)
                    .onClick(() => this.role = UserRole.TEACHER)
                }
                .width('100%')
              }
              .width('100%')
            }

            Button(this.submitting ? '正在验证身份...' :
              (this.internalMode ? '验证邀请码并开通' : (this.registerMode ? '提交注册并登录' : '进入协同工作台')))
              .width('100%')
              .height(46)
              .backgroundColor(AppTheme.accent)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
              .borderRadius(10)
              .shadow({ radius: 10, color: AppTheme.glowBlue, offsetY: 3 })
              .margin({ top: 6 })
              .onClick(() => this.submit())

            if (this.formMessage !== '') {
              Text(this.formMessage)
                .fontSize(12)
                .lineHeight(18)
                .textAlign(TextAlign.Center)
                .fontColor(this.formMessageIsError ? AppTheme.danger : AppTheme.success)
                .width('100%')
            }

            if (!this.internalMode) {
              Button(this.registerMode ? '已有账号？返回直接登录' : '没有账号？注册普通成员')
                .width('100%')
                .height(40)
                .backgroundColor(AppTheme.surface)
                .fontColor(AppTheme.accent)
                .border({ width: 1, color: AppTheme.line })
                .borderRadius(10)
                .onClick(() => {
                  this.registerMode = !this.registerMode;
                  this.internalMode = false;
                  this.password = '';
                  this.confirmPassword = '';
                  this.resetMessage();
                })
            }

            if (!this.registerMode) {
              Text('内部人员凭邀请码开通 ›')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.inkSoft)
                .textAlign(TextAlign.Center)
                .width('100%')
                .padding({ top: 4, bottom: 4 })
                .onClick(() => {
                  this.internalMode = true;
                  this.password = '';
                  this.resetMessage();
                })
            }
            if (this.internalMode) {
              Text('返回常规登录 ›')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.accent)
                .textAlign(TextAlign.Center)
                .width('100%')
                .padding({ top: 4, bottom: 4 })
                .onClick(() => {
                  this.internalMode = false;
                  this.invitationCode = '';
                  this.password = '';
                  this.resetMessage();
                })
            }

            Text('普通注册支持学生与教工成员；安保及管理员账号遵循零信任机制，需由系统授权签发。')
              .fontSize(10)
              .fontColor(AppTheme.muted)
              .lineHeight(16)
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ top: 4 })
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .borderRadius(18)
        .backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.line })
        .shadow({ radius: 10, color: AppTheme.cardShadow, offsetY: 2 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 20, bottom: 32 })
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor(AppTheme.canvas)
    .scrollBar(BarState.Off)
  }
}
