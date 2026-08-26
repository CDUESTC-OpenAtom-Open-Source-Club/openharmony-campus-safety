@Component
export struct ReportPage {
  build() {
    NavDestination() {
      Column() {
        Text('隐患上报')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)

        Text('校园安全隐患上报')
          .fontSize(18)
          .margin({ top: 20 })

        Text('在这里可以提交发现的校园安全隐患')
          .fontSize(16)
          .margin({ top: 40 })

        Button('提交隐患')
          .width('60%')
          .height(50)
          .margin({ top: 40 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .title('隐患上报')
  }
}