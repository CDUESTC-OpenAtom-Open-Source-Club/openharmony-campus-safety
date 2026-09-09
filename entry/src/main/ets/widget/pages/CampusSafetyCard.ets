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
      Column({ space: 10 }) {
        Row() {
          Text(this.headline)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#183153')
          Blank()
          Text('安全服务')
            .fontSize(12)
            .fontColor('#2F80ED')
        }
        .width('100%')
        Text(this.primary)
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
          .width('100%')
        Text(this.secondary)
          .fontSize(14)
          .fontColor('#52616B')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Divider().color('#DCE5F0')
        Text(this.hint)
          .fontSize(12)
          .fontColor('#667085')
          .width('100%')
      }
      .padding(16)
      .width('100%')
      .height('100%')
      .backgroundColor('#F7FAFF')
      .borderRadius(16)
    }
  }
}
