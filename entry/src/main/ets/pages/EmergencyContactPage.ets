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
    if (trimmed === '') {
      promptAction.showToast({ message: '请输入紧急联系电话' });
      return;
    }
    const context = getContext(this) as common.Context;
    EmergencyContactService.savePhone(context, trimmed).then(() => {
      AppStorage.setOrCreate('emergencyPhone', trimmed);
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

          Text('用于一键求助时自动发送短信并拨号')
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
              placeholder: '请输入接收紧急通知的电话号码',
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

            Text('保存后，首页点击「一键求助」会先打开短信界面并自动填入该号码与求助内容，随后打开拨号界面。')
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
