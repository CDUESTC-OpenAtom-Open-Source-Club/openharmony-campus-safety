@Component
export struct StatisticsPage {
  build() {
    NavDestination() {
      Column() {
        Text('数据统计')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)

        Text('校园安全数据统计')
          .fontSize(18)
          .margin({ top: 20 })

        Text('安全事件：0')
          .fontSize(20)
          .margin({ top: 40 })

        Text('待处理任务：0')
          .fontSize(20)
          .margin({ top: 20 })

        Text('已完成任务：0')
          .fontSize(20)
          .margin({ top: 20 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .title('数据统计')
  }
}