import { promptAction } from '@kit.ArkUI';
import { AccountService } from '../service/AccountService';
import { User } from '../model/User';
import { LoginPage } from './LoginPage';
import { AppTheme } from '../common/AppTheme';

/** 底部一级“我”页面：访客在这里认证，已登录用户在这里管理账户。 */
@Component
export struct ProfilePage {
  onLogin: () => void = (): void => {};
  onLogout: () => void = (): void => {};
  onManageAccount: () => void = (): void => {};

  @State private authVisible: boolean = false;
  @State private startInRegister: boolean = false;

  private user(): User | null {
    return AccountService.getCurrentUser();
  }

  private openAuth(register: boolean): void {
    this.startInRegister = register;
    this.authVisible = true;
  }

  private logout(): void {
    AccountService.logout().then(() => {
      promptAction.showToast({ message: '已退出登录，访客模式仍可浏览首页' });
      this.onLogout();
    });
  }

  @Builder
  private sectionTitle(title: string, detail: string) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.ink)
      Text(detail)
        .fontSize(12)
        .fontColor(AppTheme.muted)
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private actionRow(label: string, detail: string, color: string, action: () => void) {
    Row() {
      Column({ space: 3 }) {
        Text(label)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.ink)
        Text(detail)
          .fontSize(11)
          .fontColor(AppTheme.muted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('前往')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
      Text('›')
        .fontSize(18)
        .fontColor(AppTheme.muted)
        .margin({ left: 4 })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: AppTheme.line })
    .onClick(action)
  }

  build() {
    if (this.authVisible) {
      LoginPage({
        startInRegister: this.startInRegister,
        onBack: (): void => {
          this.authVisible = false;
        },
        onLogin: (): void => {
          this.authVisible = false;
          this.onLogin();
        }
      })
    } else {
      Scroll() {
        Column({ space: 16 }) {
          // 顶部标题
          Row() {
            this.sectionTitle('个人与安全中心', '数字化校园安防身份凭证与偏好设置')
            Blank()
            Row({ space: 4 }) {
              Row().width(6).height(6).borderRadius(3)
                .backgroundColor(this.user() === null ? AppTheme.amber : AppTheme.success)
              Text(this.user() === null ? '访客浏览' : '已认证')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.user() === null ? AppTheme.amber : AppTheme.success)
            }
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(12)
            .backgroundColor(this.user() === null ? AppTheme.amberSoft : AppTheme.successSoft)
          }
          .width('100%')

          if (this.user() === null) {
            // 访客状态引导卡
            Column({ space: 16 }) {
              Row() {
                Row() {
                  Image($r('app.media.ic_shield_check'))
                    .width(24)
                    .height(24)
                    .fillColor(AppTheme.accent)
                }
                .width(46)
                .height(46)
                .borderRadius(14)
                .backgroundColor(AppTheme.accentSoft)
                .justifyContent(FlexAlign.Center)

                Column({ space: 4 }) {
                  Text('认证后开启全域协同')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.ink)
                  Text('首页支持免登录快速浏览；隐患提报、工单流转、现场核销与应急联络需身份凭证。')
                    .fontSize(11)
                    .fontColor(AppTheme.muted)
                    .lineHeight(16)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 12 })
              }
              .width('100%')

              Row({ space: 10 }) {
                Button('登录系统')
                  .layoutWeight(1)
                  .height(42)
                  .backgroundColor(AppTheme.accent)
                  .fontColor(Color.White)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .borderRadius(10)
                  .onClick(() => this.openAuth(false))

                Button('注册成员账号')
                  .layoutWeight(1)
                  .height(42)
                  .backgroundColor(AppTheme.surface)
                  .fontColor(AppTheme.accent)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .border({ width: 1, color: AppTheme.line })
                  .borderRadius(10)
                  .onClick(() => this.openAuth(true))
              }
              .width('100%')
            }
            .width('100%')
            .padding(18)
            .borderRadius(16)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.line })
            .shadow({ radius: 8, color: AppTheme.cardShadow, offsetY: 2 })
          } else {
            // 已登录凭证卡（科技蓝深色胸卡质感）
            Column({ space: 14 }) {
              Row() {
                Row() {
                  Text(this.user()?.name.substring(0, 1) ?? '我')
                    .fontSize(22)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                }
                .width(50)
                .height(50)
                .borderRadius(15)
                .backgroundColor(AppTheme.accent)
                .justifyContent(FlexAlign.Center)
                .shadow({ radius: 8, color: 'rgba(37,99,235,0.3)', offsetY: 2 })

                Column({ space: 4 }) {
                  Row({ space: 6 }) {
                    Text(this.user()?.name ?? '')
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Color.White)
                    Text(this.user()?.role ?? '')
                      .fontSize(10)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#38BDF8')
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .borderRadius(4)
                      .backgroundColor('rgba(56,189,248,0.18)')
                  }
                  Text('账号标识：' + (this.user()?.id ?? ''))
                    .fontSize(10)
                    .fontColor('rgba(255,255,255,0.65)')
                }
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 12 })
              }
              .width('100%')

              Row() {
                Row({ space: 4 }) {
                  Row().width(6).height(6).borderRadius(3).backgroundColor('#34D399')
                  Text('凭证状态：正常活跃').fontSize(10).fontColor('#A7F3D0')
                }
                Blank()
                Text('安全等级：高').fontSize(10).fontColor('rgba(255,255,255,0.7)')
              }
              .width('100%')
              .padding({ top: 10 })
              .border({ width: { top: 1 }, color: 'rgba(255,255,255,0.12)' })
            }
            .width('100%')
            .padding(18)
            .borderRadius(18)
            .backgroundColor(AppTheme.accentDark)
            .border({ width: 1, color: 'rgba(56,189,248,0.2)' })
            .shadow({ radius: 12, color: 'rgba(11,25,44,0.16)', offsetY: 3 })

            // 功能列表卡片
            Column() {
              this.actionRow('账号与密码安全', '凭证保护、密码修改与管理权限治理', AppTheme.accent, () => this.onManageAccount())
              this.actionRow('退出当前账号', '退出后恢复为只读访客模式', AppTheme.danger, () => this.logout())
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 4, bottom: 4 })
            .borderRadius(16)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.line })
            .shadow({ radius: 8, color: AppTheme.cardShadow, offsetY: 2 })
          }

          // 规范与说明卡片
          Column({ space: 8 }) {
            Row({ space: 6 }) {
              Row().width(4).height(12).borderRadius(2).backgroundColor(AppTheme.accent)
              Text('协同平台安全架构规范')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ink)
            }
            .width('100%')

            Text('本系统在端侧采用基于加盐哈希的身份隔离方案与细粒度访问控制。用户提报的隐患凭证、指派任务处置证据及应急联络配置均严格归属并加密存储。')
              .fontSize(11)
              .fontColor(AppTheme.muted)
              .lineHeight(17)
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(14)
          .backgroundColor(AppTheme.surfaceMuted)
          .border({ width: 1, color: AppTheme.line })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(AppTheme.canvas)
      .scrollBar(BarState.Off)
    }
  }
}
