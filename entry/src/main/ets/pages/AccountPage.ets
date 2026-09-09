import { promptAction } from '@kit.ArkUI';
import { User } from '../model/User';
import { AccountService, InvitationResult, LoginResult, ManagedAccount } from '../service/AccountService';
import { UserRole } from '../model/User';
import { AppPermission, PermissionService } from '../service/PermissionService';

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
      Row() {
        Text('‹')
          .fontSize(30)
          .fontColor('#334155')
          .padding({ left: 4, right: 10 })
          .onClick(() => this.pageStack.pop())
        Text('账号与安全')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
        Blank()
        Button('退出登录')
          .fontSize(11)
          .fontColor('#B91C1C')
          .backgroundColor('#FEF2F2')
          .height(34)
          .onClick(() => {
            AccountService.logout().then(() => this.onLogout());
          })
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 14, bottom: 10 })
      .backgroundColor(Color.White)

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 6 }) {
            Text(this.getUser()?.name ?? '未登录')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
            Text(this.getUser()?.role ?? '')
              .fontSize(12)
              .fontColor('#64748B')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(18)
          .borderRadius(18)
          .backgroundColor('#EFF6FF')
          .border({ width: 1, color: '#BFDBFE' })

          Column({ space: 10 }) {
            Text('修改密码')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
              .width('100%')
            TextInput({ placeholder: '原密码', text: this.oldPassword })
              .type(InputType.Password)
              .onChange((value: string) => this.oldPassword = value)
            TextInput({ placeholder: '新密码（至少 10 位，含字母和数字）', text: this.newPassword })
              .type(InputType.Password)
              .onChange((value: string) => this.newPassword = value)
            TextInput({ placeholder: '再次输入新密码', text: this.confirmPassword })
              .type(InputType.Password)
              .onChange((value: string) => this.confirmPassword = value)
            Button('保存新密码')
              .width('100%')
              .height(42)
              .backgroundColor('#2563EB')
              .onClick(() => this.submitPasswordChange())
          }
          .width('100%')
          .padding(16)
          .borderRadius(18)
          .backgroundColor(Color.White)
          .border({ width: 1, color: '#E2E8F0' })

          if (PermissionService.can(this.getUser(), AppPermission.MANAGE_ACCOUNTS)) {
            Column({ space: 10 }) {
              Text('账户治理')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0F172A')
                .width('100%')
              Text('公开注册只支持学生和教师。安保与管理员必须凭本机管理员签发的一次性限时邀请码开通。')
                .fontSize(11).fontColor('#64748B').lineHeight(17).width('100%')
              Row({ space: 8 }) {
                Button('签发安保邀请码')
                  .layoutWeight(1).fontSize(11).backgroundColor('#0F766E').fontColor(Color.White)
                  .onClick(() => this.issueInvitation(UserRole.SECURITY))
                Button('签发管理员邀请码')
                  .layoutWeight(1).fontSize(11).backgroundColor('#7C3AED').fontColor(Color.White)
                  .onClick(() => this.issueInvitation(UserRole.ADMIN))
              }.width('100%')
              if (this.issuedInvitation !== '') {
                Column({ space: 5 }) {
                  Text('刚签发的邀请码（仅显示一次）').fontSize(11).fontColor('#B45309').width('100%')
                  Text(this.issuedInvitation).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#0F172A')
                    .width('100%').textAlign(TextAlign.Center).padding(10).borderRadius(10).backgroundColor('#FFFBEB')
                  Text('请通过受控校内渠道交付。离开此页面后无法再次查看原码。')
                    .fontSize(10).fontColor('#92400E').lineHeight(15).width('100%')
                }.width('100%').padding(10).borderRadius(12).backgroundColor('#FFFBEB')
              }
              Text('已开通账户').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#334155').width('100%')
              ForEach(AccountService.getManagedUsers(), (item: ManagedAccount) => {
                Row() {
                  Column({ space: 2 }) {
                    Text(item.user.name).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#334155')
                    Text(item.active ? '正常' : '已停用').fontSize(10).fontColor(item.active ? '#059669' : '#B91C1C')
                  }.alignItems(HorizontalAlign.Start)
                  Blank()
                  Text(item.user.role).fontSize(11).fontColor('#2563EB').margin({ right: 8 })
                  Button(item.active ? '停用' : '启用').fontSize(10).height(28)
                    .fontColor(item.active ? '#B91C1C' : '#047857')
                    .backgroundColor(item.active ? '#FEF2F2' : '#ECFDF5')
                    .onClick(() => this.changeAccountStatus(item))
                }
                .width('100%')
                .padding({ top: 10, bottom: 10 })
                .border({ width: { bottom: 1 }, color: '#F1F5F9' })
              }, (item: ManagedAccount) => item.user.id)
              Text('当前版本使用本机加盐口令摘要与角色隔离。正式校园部署仍须接入可信身份服务、服务端授权和集中审计。')
                .fontSize(10)
                .fontColor('#94A3B8')
                .lineHeight(16)
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .borderRadius(18)
            .backgroundColor(Color.White)
            .border({ width: 1, color: '#E2E8F0' })
          }
        }
        .width('100%')
        .padding(14)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC')
  }
}
