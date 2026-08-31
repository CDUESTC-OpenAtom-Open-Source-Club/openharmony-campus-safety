import { EventPage } from './EventPage';
import { EventDetailPage } from './EventDetailPage';
import { TaskPage } from './TaskPage';
import { ReportPage } from './ReportPage';
import { StatisticsPage } from './StatisticsPage';

@Entry
@Component
struct Index {
  private pageStack: NavPathStack = new NavPathStack();

  @Builder
  pageMap(name: string) {
    if (name === 'EventPage') {
      NavDestination() {
        EventPage({
          pageStack: this.pageStack
        })
      }
      .title('安全事件')
    } else if (name === 'EventDetailPage') {
      NavDestination() {
        EventDetailPage()
      }
      .title('事件详情')
    } else if (name === 'TaskPage') {
      NavDestination() {
        TaskPage()
      }
      .title('处置任务')
    } else if (name === 'ReportPage') {
      NavDestination() {
        ReportPage()
      }
      .title('隐患上报')
    } else if (name === 'StatisticsPage') {
      NavDestination() {
        StatisticsPage()
      }
      .title('数据统计')
    }
  }

  build() {
    Navigation(this.pageStack) {
      Column() {
        Text('鸿蒙智安')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 12 })

        Text('校园安全协同应用')
          .fontSize(18)
          .margin({ bottom: 40 })

        Button('安全事件')
          .width('80%')
          .height(50)
          .margin({ bottom: 16 })
          .onClick(() => {
            this.pageStack.pushPath({
              name: 'EventPage'
            })
          })

        Button('处置任务')
          .width('80%')
          .height(50)
          .margin({ bottom: 16 })
          .onClick(() => {
            this.pageStack.pushPath({
              name: 'TaskPage'
            })
          })

        Button('隐患上报')
          .width('80%')
          .height(50)
          .margin({ bottom: 16 })
          .onClick(() => {
            this.pageStack.pushPath({
              name: 'ReportPage'
            })
          })

        Button('数据统计')
          .width('80%')
          .height(50)
          .onClick(() => {
            this.pageStack.pushPath({
              name: 'StatisticsPage'
            })
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .navDestination(this.pageMap)
  }
}
