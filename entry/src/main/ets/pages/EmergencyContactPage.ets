import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { EmergencyContactService } from '../service/EmergencyContactService';
import { AppTheme } from '../common/AppTheme';

@Component
export struct EmergencyContactPage {
  pageStack: NavPathStack = new NavPathStack();

  @State private pageReady: boolean = false;
  @State private phone: string = '';

  aboutToAppear(): void {
    const context = getContext(this) as common.Context;
    EmergencyContactService.getPhone(context).then((value: string) => {
      this.phone = value;
      AppStorage.setOrCreate('emergencyPhone', value);
    }).catch((err: Error) => {
      console.error('EmergencyContactService load failed: ' + err.message);
    });
  }

  private save(): void {
    const trimmed: string = this.phone.trim();
    if (!EmergencyContactService.isValidPhone(trimmed)) {
      promptAction.showToast({ message: '请输入 6—20 位有效电话号码，可包含 + 号' });
      return;
    }
    const context = getContext(this) as common.Context;
    EmergencyContactService.savePhone(context, trimmed).then((saved: boolean) => {
      if (!saved) {
        promptAction.showToast({ message: '号码格式无效，请重新输入' });
        return;
      }
      const normalized: string = EmergencyContactService.normalizePhone(trimmed);
      AppStorage.setOrCreate('emergencyPhone', normalized);
      promptAction.showToast({ message: '应急联系电话已保存' });
      this.pageStack.pop();
    }).catch((err: Error) => {
      promptAction.showToast({ message: '保存失败，请重试' });
    });
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor(AppTheme.inkSoft)
          .padding({ left: 4, right: 10 })
          .onClick(() => {
            this.pageStack.pop();
          })

        Column({ space: 2 }) {
          Text('应急联络方式')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ink)

          Text('快速联动系统短信与拨号界面 · 需人工确认触发')
            .fontSize(10)
            .fontColor(AppTheme.muted)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 14, right: 16, top: 14, bottom: 12 })
      .backgroundColor(AppTheme.surface)
      .border({ width: { bottom: 1 }, color: AppTheme.line })

      Scroll() {
        Column({ space: 14 }) {
          // 应急响应专线卡片
          Column({ space: 10 }) {
            Row({ space: 6 }) {
              Row().width(4).height(12).borderRadius(2).backgroundColor(AppTheme.danger)
              Text('本地紧急联络专线号码')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ink)
            }
            .width('100%')

            TextInput({
              placeholder: '请输入 6—20 位有效电话号码（支持 + 号）',
              text: this.phone
            })
              .type(InputType.PhoneNumber)
              .width('100%')
              .height(44)
              .fontSize(13)
              .borderRadius(10)
              .backgroundColor(AppTheme.surfaceMuted)
              .border({ width: 1, color: AppTheme.line })
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.phone = value;
              })
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.line })
          .shadow({ radius: 8, color: AppTheme.cardShadow, offsetY: 2 })

          // 运行规范卡片
          Column({ space: 8 }) {
            Row({ space: 6 }) {
              Row().width(4).height(12).borderRadius(2).backgroundColor(AppTheme.accent)
              Text('安全防护机制与使用须知')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ink)
            }
            .width('100%')

            Text('1. 该号码仅保存在当前设备本地私有配置中，用于突发情况下的快速外呼与求助。')
              .fontSize(11)
              .fontColor(AppTheme.muted)
              .lineHeight(17)
              .width('100%')

            Text('2. 首页的“求助短信”和“一键拨打”仅用于调起系统原生编辑与拨号面板，应用不会在后台静默扣费或自动呼叫，必须由用户核实并主动发出。')
              .fontSize(11)
              .fontColor(AppTheme.muted)
              .lineHeight(17)
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.line })
          .shadow({ radius: 8, color: AppTheme.cardShadow, offsetY: 2 })

          Button('保存应急专线配置')
            .width('100%')
            .height(44)
            .borderRadius(10)
            .backgroundColor(AppTheme.accent)
            .fontColor(Color.White)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .shadow({ radius: 8, color: AppTheme.glowBlue, offsetY: 2 })
            .margin({ top: 4, bottom: 20 })
            .onClick(() => {
              this.save();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.canvas)
    .opacity(this.pageReady ? 1 : 0)
    .translate({ y: this.pageReady ? 0 : 12 })
    .animation({ duration: 320, curve: Curve.EaseOut })
    .onAppear(() => {
      this.pageReady = true;
    })
  }
}
