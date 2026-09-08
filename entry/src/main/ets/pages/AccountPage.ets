import { promptAction } from '@kit.ArkUI';
import { User } from '../model/User';
import { AccountService, LoginResult } from '../service/AccountService';
import { AppPermission, PermissionService } from '../service/PermissionService';

@Component
export struct AccountPage {
  pageStack: NavPathStack = new NavPathStack();
  onLogout: () => void = (): void => {};

  @State private oldPassword: string = '';
  @State private newPassword: string = '';
  @State private confirmPassword: string = '';

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
            Text((this.getUser()?.role ?? '') + ' · ' + (this.getUser()?.id ?? ''))
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
            TextInput({ placeholder: '新密码（至少 8 位）', text: this.newPassword })
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
              Text('本机测试账号')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0F172A')
                .width('100%')
              ForEach(AccountService.getUsers(), (user: User) => {
                Row() {
                  Text(user.name).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#334155')
                  Blank()
                  Text(user.role).fontSize(11).fontColor('#2563EB')
                }
                .width('100%')
                .padding({ top: 10, bottom: 10 })
                .border({ width: { bottom: 1 }, color: '#F1F5F9' })
              }, (user: User) => user.id)
              Text('正式校园身份认证仍需可信服务端支持；当前账号仅用于本机测试版协同。')
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
