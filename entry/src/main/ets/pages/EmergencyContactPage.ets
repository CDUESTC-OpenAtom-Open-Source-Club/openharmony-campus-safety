import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { EmergencyContactService } from '../service/EmergencyContactService';

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
          .fontSize(30)
          .fontColor('#334155')
          .padding({ left: 4, right: 10 })
          .onClick(() => {
            this.pageStack.pop();
          })

        Column() {
          Text('应急联系方式')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Text('仅打开系统短信编辑或拨号界面，由你确认后执行')
            .fontSize(10)
            .fontColor('#94A3B8')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 14, bottom: 10 })
      .backgroundColor(Color.White)

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 8 }) {
            Text('紧急联系电话')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#334155')
              .width('100%')

            TextInput({
              placeholder: '请输入本地配置的紧急联系电话',
              text: this.phone
            })
              .type(InputType.PhoneNumber)
              .width('100%')
              .height(48)
              .fontSize(14)
              .borderRadius(14)
              .backgroundColor('#F8FAFC')
              .border({ width: 1, color: '#E2E8F0' })
              .padding({ left: 14, right: 14 })
              .onChange((value: string) => {
                this.phone = value;
              })
          }
          .width('100%')
          .padding(16)
          .borderRadius(18)
          .backgroundColor(Color.White)
          .border({ width: 1, color: '#E2E8F0' })
          .shadow({ radius: 10, color: 'rgba(15,23,42,0.04)', offsetY: 2 })

          Column() {
            Text('使用说明')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#334155')
              .width('100%')
              .margin({ bottom: 8 })

            Text('该号码由当前设备本地保存，不代表已接入学校保卫处或真实应急平台。首页可分别打开短信编辑和拨号界面；应用不会自动发送短信或自动拨号。')
              .fontSize(12)
              .fontColor('#64748B')
              .lineHeight(20)
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .borderRadius(18)
          .backgroundColor(Color.White)
          .border({ width: 1, color: '#E2E8F0' })

          Button('保存')
            .width('100%')
            .height(48)
            .borderRadius(14)
            .backgroundColor('#2563EB')
            .fontColor(Color.White)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .shadow({ radius: 12, color: 'rgba(37,99,235,0.3)', offsetY: 4 })
            .margin({ top: 4, bottom: 20 })
            .onClick(() => {
              this.save();
            })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC')
    .opacity(this.pageReady ? 1 : 0)
    .translate({ y: this.pageReady ? 0 : 18 })
    .animation({ duration: 320, curve: Curve.EaseOut })
    .onAppear(() => {
      this.pageReady = true;
    })
  }
}
