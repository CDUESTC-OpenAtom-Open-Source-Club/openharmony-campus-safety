import { AppTheme } from '../../common/AppTheme';

@Entry
@Component
struct CampusSafetyCard {
  @State headline: string = '校园安全';
  @State primary: string = '暂无可展示的业务数据';
  @State secondary: string = '打开应用登录后查看安全动态';
  @State hint: string = '点击打开鸿蒙智安';

  build() {
    FormLink({
      action: 'router',
      abilityName: 'EntryAbility'
    }) {
      Column({ space: 8 }) {
        Row() {
          Row()
            .width(10)
            .height(10)
            .borderRadius(5)
            .backgroundColor(AppTheme.accent)
            .shadow({ radius: 6, color: AppTheme.glowBlue, offsetY: 1 })

          Text(this.headline)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ink)
            .margin({ left: 8 })
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: 4 }) {
            Row()
              .width(5)
              .height(5)
              .borderRadius(2.5)
              .backgroundColor(AppTheme.success)
            Text('在线')
              .fontSize(9)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.success)
          }
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(8)
          .backgroundColor(AppTheme.successSoft)
        }
        .width('100%')

        Text(this.primary)
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.accentDark)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.secondary)
          .fontSize(11)
          .fontColor(AppTheme.inkSoft)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Divider()
          .color(AppTheme.line)
          .margin({ top: 2, bottom: 2 })

        Row() {
          Text(this.hint)
            .fontSize(11)
            .fontColor(AppTheme.muted)
            .layoutWeight(1)
          Text('›')
            .fontSize(16)
            .fontColor(AppTheme.accent)
        }
        .width('100%')
      }
      .padding(14)
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.surface)
      .border({ width: 1, color: AppTheme.line })
      .borderRadius(16)
      .shadow({ radius: 10, color: AppTheme.cardShadow, offsetY: 2 })
    }
  }
}
