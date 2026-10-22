import { promptAction } from '@kit.ArkUI';
import { AccountService } from '../service/AccountService';
import { User } from '../model/User';
import { LoginPage } from './LoginPage';
import { AppTheme } from '../common/AppTheme';

/** “我”页面：参考浅蓝白卡片式个人中心设计，保留原有登录、账号管理与退出逻辑。 */
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
  private statusBadge() {
    Row({ space: 6 }) {
      Row()
        .width(7)
        .height(7)
        .borderRadius(4)
        .backgroundColor(this.user() === null ? AppTheme.amber : AppTheme.success)

      Text(this.user() === null ? '访客浏览' : '安全在线')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.user() === null ? AppTheme.amber : AppTheme.success)
    }
    .padding({ left: 9, right: 9, top: 5, bottom: 5 })
    .borderRadius(14)
    .backgroundColor(this.user() === null ? AppTheme.amberSoft : AppTheme.successSoft)
  }

  @Builder
  private miniStat(icon: Resource, title: string, detail: string, action: () => void) {
    Row({ space: 10 }) {
      Row() {
        Image(icon)
          .width(21)
          .height(21)
          .fillColor(AppTheme.accent)
      }
      .width(42)
      .height(42)
      .borderRadius(13)
      .backgroundColor(AppTheme.accentSoft)
      .justifyContent(FlexAlign.Center)

      Column({ space: 3 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.ink)
        Text(detail)
          .fontSize(10)
          .fontColor(AppTheme.muted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›')
        .fontSize(20)
        .fontColor(AppTheme.muted)
    }
    .layoutWeight(1)
    .height(78)
    .padding({ left: 13, right: 10 })
    .borderRadius(16)
    .backgroundColor(AppTheme.surface)
    .border({ width: 1, color: AppTheme.line })
    .shadow({ radius: 8, color: AppTheme.cardShadow, offsetY: 2 })
    .onClick(action)
  }

  @Builder
  private profileHero() {
    Column({ space: 14 }) {
      Row() {
        Row() {
          Image($r('app.media.ic_account'))
            .width(40)
            .height(40)
            .fillColor(AppTheme.accent)
        }
        .width(58)
        .height(58)
        .borderRadius(20)
        .backgroundColor(Color.White)
        .justifyContent(FlexAlign.Center)
        .shadow({ radius: 8, color: AppTheme.glowBlue, offsetY: 2 })

        Column({ space: 4 }) {
          Text(this.user()?.name ?? '校园访客')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text(this.user() === null ? '登录后解锁更多安全协同功能' : (this.user()?.role ?? '校园成员'))
            .fontSize(11)
            .fontColor('rgba(255,255,255,0.76)')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })

        Text(this.user() === null ? '去登录' : '已认证')
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.accent)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .backgroundColor(Color.White)
          .borderRadius(11)
          .onClick(() => {
            if (this.user() === null) {
              this.openAuth(false);
            }
          })
      }
      .width('100%')

      Row() {
        Column({ space: 4 }) {
          Text(this.user() === null ? '账号状态' : '安全状态')
            .fontSize(10)
            .fontColor('rgba(255,255,255,0.7)')
          Text(this.user() === null ? '待认证' : '正常活跃')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 4 }) {
          Text(this.user() === null ? '安全等级' : '权限等级')
            .fontSize(10)
            .fontColor('rgba(255,255,255,0.7)')
          Text(this.user() === null ? '基础' : '良好')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 4 }) {
          Text('系统')
            .fontSize(10)
            .fontColor('rgba(255,255,255,0.7)')
          Text('鸿蒙智安')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ top: 10 })
      .border({ width: { top: 1 }, color: 'rgba(255,255,255,0.14)' })
    }
    .width('100%')
    .padding(18)
    .borderRadius(22)
    .linearGradient({
      angle: 145,
      colors: [
        [AppTheme.accentDeep, 0],
        [AppTheme.accent, 0.52],
        ['#5EA8FF', 1]
      ]
    })
    .shadow({ radius: 14, color: AppTheme.glowBlue, offsetY: 5 })
  }

  @Builder
  private featureCard() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 3 }) {
          Text('安全成长中心')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text(this.user() === null ? '登录后查看你的校园安全档案' : '账户、权限、应急设置一站管理')
            .fontSize(10)
            .fontColor('rgba(255,255,255,0.76)')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Image($r('app.media.safety_crest'))
          .width(72)
          .height(72)
          .opacity(0.32)
      }
      .width('100%')

      Row() {
        Text(this.user() === null ? '登录 / 注册' : '进入账号与安全')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.accent)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor(Color.White)
          .borderRadius(11)
          .onClick(() => {
            if (this.user() === null) {
              this.openAuth(false);
            } else {
              this.onManageAccount();
            }
          })
        Blank()
        Text('安全中心 ›')
          .fontSize(10)
          .fontColor('rgba(255,255,255,0.8)')
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(20)
    .linearGradient({ angle: 160, colors: [[AppTheme.accentDark, 0], ['#6A99FF', 1]] })
    .shadow({ radius: 10, color: AppTheme.glowBlue, offsetY: 4 })
  }

  @Builder
  private menuRow(icon: Resource, title: string, detail: string, accent: string, action: () => void) {
    Row({ space: 12 }) {
      Row() {
        Image(icon)
          .width(19)
          .height(19)
          .fillColor(accent)
      }
      .width(40)
      .height(40)
      .borderRadius(12)
      .backgroundColor(accent + '18')
      .justifyContent(FlexAlign.Center)

      Column({ space: 3 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.ink)
        Text(detail)
          .fontSize(10)
          .fontColor(AppTheme.muted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›')
        .fontSize(20)
        .fontColor(AppTheme.muted)
    }
    .width('100%')
    .padding({ top: 11, bottom: 11 })
    .border({ width: { bottom: 1 }, color: AppTheme.line })
    .onClick(action)
  }

  @Builder
  private menuSection() {
    Column() {
      this.menuRow(
        $r('app.media.ic_shield_check'),
        '账号与安全',
        '凭证保护、密码修改与账户管理',
        AppTheme.accent,
        () => {
          if (this.user() === null) {
            this.openAuth(false);
          } else {
            this.onManageAccount();
          }
        }
      )
      this.menuRow(
        $r('app.media.ic_event'),
        '登录与认证',
        this.user() === null ? '登录后参与事件处置与安全协同' : '当前身份已完成认证',
        AppTheme.info,
        () => {
          if (this.user() === null) {
            this.openAuth(false);
          } else {
            promptAction.showToast({ message: '当前身份已认证' });
          }
        }
      )
      this.menuRow(
        $r('app.media.ic_phone'),
        '退出当前账号',
        '退出后恢复为只读访客模式',
        AppTheme.danger,
        () => {
          if (this.user() === null) {
            promptAction.showToast({ message: '当前已是访客模式' });
          } else {
            this.logout();
          }
        }
      )
      this.menuRow(
        $r('app.media.ic_calendar'),
        '安全说明',
        '查看鸿蒙智安的安全协同说明',
        AppTheme.success,
        () => promptAction.showToast({ message: '鸿蒙智安：让校园安全协同更简单' })
      )
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 4, bottom: 4 })
    .borderRadius(18)
    .backgroundColor(AppTheme.surface)
    .border({ width: 1, color: AppTheme.line })
    .shadow({ radius: 9, color: AppTheme.cardShadow, offsetY: 2 })
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
        Column({ space: 14 }) {
          Row() {
            Column({ space: 4 }) {
              Text('我的')
                .fontSize(26)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ink)
              Text('你的校园安全身份与服务空间')
                .fontSize(11)
                .fontColor(AppTheme.muted)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            this.statusBadge()
          }
          .width('100%')

          this.profileHero()

          Row({ space: 10 }) {
            this.miniStat(
              $r('app.media.ic_event'),
              '我的事件',
              this.user() === null ? '登录后查看' : '安全事件记录',
              () => {
                promptAction.showToast({ message: this.user() === null ? '请先登录' : '事件记录入口已保留在底部“记录”页面' });
              }
            )
            this.miniStat(
              $r('app.media.ic_shield_check'),
              '安全档案',
              this.user() === null ? '待认证' : '正常活跃',
              () => {
                if (this.user() === null) {
                  this.openAuth(false);
                } else {
                  this.onManageAccount();
                }
              }
            )
          }
          .width('100%')

          this.featureCard()

          Column({ space: 9 }) {
            Text('我的服务')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ink)
              .width('100%')
            this.menuSection()
          }
          .width('100%')

          Column({ space: 7 }) {
            Row({ space: 6 }) {
              Row()
                .width(4)
                .height(12)
                .borderRadius(2)
                .backgroundColor(AppTheme.accent)
              Text('安全与隐私')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ink)
            }
            .width('100%')

            Text('个人账户、身份信息与应急配置均由本地业务能力负责管理。AI 助手、校园数据等后续服务将在独立权限和安全接口下接入。')
              .fontSize(10)
              .fontColor(AppTheme.muted)
              .lineHeight(16)
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(15)
          .backgroundColor(AppTheme.surfaceMuted)
          .border({ width: 1, color: AppTheme.line })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 15, bottom: 28 })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(AppTheme.canvas)
      .scrollBar(BarState.Off)
    }
  }
}
