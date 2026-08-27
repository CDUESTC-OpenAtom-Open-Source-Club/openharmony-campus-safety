import {
  SecurityEvent
} from '../model/SecurityEvent';

import { EventService } from '../service/EventService';

@Component
export struct EventPage {
  // 修复闪退：NavPathStack 不得用 @Prop 传递（@Prop 对对象做深拷贝，
  // 拷贝副本的 pushPath 触发原生导航栈状态不一致 → JSNavPathStack::OnStateChanged SIGSEGV）。
  // 按 ArkUI Navigation 官方规范改用普通成员变量，与 Index 的 pageStack 保持同一实例。
  // 默认值仅用于满足 ArkTS 初始化约束；Index 构造 EventPage 时传入的 pageStack 会覆盖它。
  pageStack: NavPathStack = new NavPathStack();
  @State private events: SecurityEvent[] =
    EventService.getAllEvents();

  build() {
    Column() {
      Text('安全事件')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 8 })

      Text('校园安全事件列表')
        .fontSize(16)
        .margin({ bottom: 20 })

      List({ space: 12 }) {
        ForEach(this.events, (event: SecurityEvent) => {
          ListItem() {
            Column() {
              Row() {
                Text(event.title)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .layoutWeight(1)

                Text(event.priority)
                  .fontSize(14)
              }
              .width('100%')
              .margin({ bottom: 10 })

              Text('事件编号：' + event.id)
                .fontSize(14)
                .width('100%')
                .margin({ bottom: 6 })

              Text('地点：' + event.location)
                .fontSize(14)
                .width('100%')
                .margin({ bottom: 6 })

              Text('类型：' + event.type)
                .fontSize(14)
                .width('100%')
                .margin({ bottom: 6 })

              Text('状态：' + event.status)
                .fontSize(14)
                .width('100%')
                .margin({ bottom: 6 })

              Text(event.description)
                .fontSize(14)
                .width('100%')
                .margin({ bottom: 8 })

              Text('上报人：' + event.reporter)
                .fontSize(13)
                .width('100%')
            }
            .width('100%')
            .padding(16)
          }
          .onClick(() => {
            EventService.setSelectedEventId(event.id);

            this.pageStack.pushPath({
              name: 'EventDetailPage'
            });
          })
        })
      }
      .height('100%')
      .width('100%')
      .padding({
        left: 16,
        right: 16
      })
    }
    .width('100%')
    .height('100%')
  }
}