import { promptAction } from '@kit.ArkUI';
import { User } from '../model/User';
import { AccountService, InvitationResult, LoginResult, ManagedAccount } from '../service/AccountService';
import { UserRole } from '../model/User';
import { AppPermission, PermissionService } from '../service/PermissionService';
import { AppTheme } from '../common/AppTheme';

@Component
export struct AccountPage {
  pageStack: NavPathStack = new NavPathStack();
  onLogout: () => void = (): void => {};

  @State private oldPassword: string = '';
  @State private newPassword: string = '';
  @State private confirmPassword: string = '';
  @State private issuedInvitation: string = '';

  private getUser(): User | null {
    return AccountService.getCurrentUser();
  }

  private submitPasswordChange(): void {
    if (this.newPassword !== this.confirmPassword) {
      promptAction.showToast({ message: '两次输入的新密码不一致' });
      return;
    }
    AccountService.changePassword(this.oldPassword, this.newPassword).then((result: LoginResult) => {
      promptAction.showToast({ message: result.message });
      if (result.success) {
        this.oldPassword = '';
        this.newPassword = '';
        this.confirmPassword = '';
      }
    });
  }

  private issueInvitation(role: UserRole): void {
    AccountService.issueInternalInvitation(role).then((result: InvitationResult) => {
      promptAction.showToast({ message: result.message });
      if (result.success) {
        this.issuedInvitation = result.code ?? '';
      }
    });
  }

  private changeAccountStatus(item: ManagedAccount): void {
    AccountService.setAccountActive(item.user.id, !item.active).then((result: LoginResult) => {
      promptAction.showToast({ message: result.message });
    });
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor(AppTheme.inkSoft)
          .padding({ left: 4, right: 10 })
          .onClick(() => this.pageStack.pop())
        Text('账号与安全治理')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.ink)
        Blank()
        Button('退出登录')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.danger)
          .backgroundColor(AppTheme.dangerSoft)
          .height(32)
          .borderRadius(8)
          .onClick(() => {
            AccountService.logout().then(() => this.onLogout());
          })
      }
      .width('100%')
      .padding({ left: 14, right: 16, top: 14, bottom: 12 })
      .backgroundColor(AppTheme.surface)
      .border({ width: { bottom: 1 }, color: AppTheme.line })

      Scroll() {
        Column({ space: 14 }) {
          // 当前账户状态卡片
          Column({ space: 8 }) {
            Row() {
              Column({ space: 4 }) {
                Text(this.getUser()?.name ?? '未登录')
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                Text('系统角色：' + (this.getUser()?.role ?? '访客'))
                  .fontSize(11)
                  .fontColor('#38BDF8')
              }
              .alignItems(HorizontalAlign.Start)

              Blank()

              Row({ space: 4 }) {
                Row().width(6).height(6).borderRadius(3).backgroundColor('#34D399')
                Text('加盐哈希保护').fontSize(10).fontColor('#A7F3D0')
              }
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .borderRadius(12)
              .backgroundColor('rgba(16,185,129,0.18)')
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(18)
          .borderRadius(18)
          .backgroundColor(AppTheme.accentDark)
          .border({ width: 1, color: 'rgba(56,189,248,0.2)' })
          .shadow({ radius: 10, color: AppTheme.cardShadow, offsetY: 2 })

          // 修改密码卡片
          Column({ space: 12 }) {
            Row({ space: 6 }) {
              Row().width(4).height(12).borderRadius(2).backgroundColor(AppTheme.accent)
              Text('安全凭证修改')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ink)
            }
            .width('100%')

            Column({ space: 8 }) {
              TextInput({ placeholder: '原密码', text: this.oldPassword })
                .type(InputType.Password)
                .height(42)
                .backgroundColor(AppTheme.surfaceMuted)
                .border({ width: 1, color: AppTheme.line })
                .borderRadius(10)
                .fontSize(12)
                .padding({ left: 12, right: 12 })
                .onChange((value: string) => this.oldPassword = value)

              TextInput({ placeholder: '新密码（至少 10 位，需含字母与数字）', text: this.newPassword })
                .type(InputType.Password)
                .height(42)
                .backgroundColor(AppTheme.surfaceMuted)
                .border({ width: 1, color: AppTheme.line })
                .borderRadius(10)
                .fontSize(12)
                .padding({ left: 12, right: 12 })
                .onChange((value: string) => this.newPassword = value)

              TextInput({ placeholder: '再次确认新密码', text: this.confirmPassword })
                .type(InputType.Password)
                .height(42)
                .backgroundColor(AppTheme.surfaceMuted)
                .border({ width: 1, color: AppTheme.line })
                .borderRadius(10)
                .fontSize(12)
                .padding({ left: 12, right: 12 })
                .onChange((value: string) => this.confirmPassword = value)
            }
            .width('100%')

            Button('更新并保存新凭证')
              .width('100%')
              .height(42)
              .backgroundColor(AppTheme.accent)
              .fontColor(Color.White)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .borderRadius(10)
              .shadow({ radius: 8, color: AppTheme.glowBlue, offsetY: 2 })
              .onClick(() => this.submitPasswordChange())
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.line })
          .shadow({ radius: 8, color: AppTheme.cardShadow, offsetY: 2 })

          // 账户治理（管理员专区）
          if (PermissionService.can(this.getUser(), AppPermission.MANAGE_ACCOUNTS)) {
            Column({ space: 12 }) {
              Row({ space: 6 }) {
                Row().width(4).height(12).borderRadius(2).backgroundColor(AppTheme.cyan)
                Text('组织账户治理与密钥签发')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.ink)
              }
              .width('100%')

              Text('安保与管理员账号遵循受控委派规范，必须凭管理员签发的一次性限时数字邀请码进行身份激活。')
                .fontSize(11).fontColor(AppTheme.muted).lineHeight(16).width('100%')

              Row({ space: 8 }) {
                Button('签发安保人员邀请码')
                  .layoutWeight(1).height(38).fontSize(11).fontWeight(FontWeight.Medium)
                  .backgroundColor(AppTheme.accent).fontColor(Color.White).borderRadius(8)
                  .onClick(() => this.issueInvitation(UserRole.SECURITY))
                Button('签发校级管理员邀请码')
                  .layoutWeight(1).height(38).fontSize(11).fontWeight(FontWeight.Medium)
                  .backgroundColor(AppTheme.accentDark).fontColor(Color.White).borderRadius(8)
                  .onClick(() => this.issueInvitation(UserRole.ADMIN))
              }.width('100%')

              if (this.issuedInvitation !== '') {
                Column({ space: 6 }) {
                  Text('刚签发的安全激活凭证（离开页面后不可再次查看）').fontSize(10).fontColor(AppTheme.amber).width('100%')
                  Text(this.issuedInvitation)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.ink)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding(10)
                    .borderRadius(8)
                    .backgroundColor(AppTheme.amberSoft)
                    .border({ width: 1, color: '#FCD34D' })
                  Text('请通过校内保密渠道送达指定人员，并在规定时间内完成初始化。')
                    .fontSize(9).fontColor(AppTheme.muted).width('100%')
                }.width('100%').padding(12).borderRadius(12).backgroundColor(AppTheme.surfaceMuted)
              }

              Text('当前受管人员列表').fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.inkSoft).width('100%')

              ForEach(AccountService.getManagedUsers(), (item: ManagedAccount) => {
                Row() {
                  Column({ space: 2 }) {
                    Text(item.user.name).fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.ink)
                    Text(item.active ? '状态：正常接入' : '状态：已冻结停用')
                      .fontSize(10).fontColor(item.active ? AppTheme.success : AppTheme.danger)
                  }.alignItems(HorizontalAlign.Start)

                  Blank()

                  Text(item.user.role)
                    .fontSize(10)
                    .fontColor(AppTheme.accent)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(4)
                    .backgroundColor(AppTheme.accentSoft)
                    .margin({ right: 10 })

                  Button(item.active ? '停用' : '启用')
                    .fontSize(10).height(28)
                    .fontColor(item.active ? AppTheme.danger : AppTheme.success)
                    .backgroundColor(item.active ? AppTheme.dangerSoft : AppTheme.successSoft)
                    .borderRadius(6)
                    .onClick(() => this.changeAccountStatus(item))
                }
                .width('100%')
                .padding({ top: 10, bottom: 10 })
                .border({ width: { bottom: 1 }, color: AppTheme.line })
              }, (item: ManagedAccount) => item.user.id)

              Text('当前版本采用本地加盐哈希与角色级权限墙。生产部署可无缝接入学校可信统一身份认证中心（CAS / OAuth2 / LDAP）。')
                .fontSize(10)
                .fontColor(AppTheme.muted)
                .lineHeight(15)
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.line })
            .shadow({ radius: 8, color: AppTheme.cardShadow, offsetY: 2 })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.canvas)
  }
}
