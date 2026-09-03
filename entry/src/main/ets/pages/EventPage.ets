import {
  SecurityEvent,
  EventPriority,
  EventStatus
} from '../model/SecurityEvent';

import { EventService } from '../service/EventService';

@Component
export struct EventPage {
  /* 【不可改】NavPathStack 必须保持普通成员变量（用 @Prop 传递会 SIGSEGV 闪退）；这段注释也别删 */
  // 修复闪退：NavPathStack 不得用 @Prop 传递（@Prop 对对象做深拷贝，
  // 拷贝副本的 pushPath 触发原生导航栈状态不一致 → JSNavPathStack::OnStateChanged SIGSEGV）。
  // 按 ArkUI Navigation 官方规范改用普通成员变量，与 Index 的 pageStack 保持同一实例。
  // 默认值仅用于满足 ArkTS 初始化约束；Index 构造 EventPage 时传入的 pageStack 会覆盖它。
  pageStack: NavPathStack = new NavPathStack();

  /* 【不可改】@State 数据源与取值方式逐字保留 */
  @State private events: SecurityEvent[] =
    EventService.getAllEvents();

  // 优先级辅助背景色
  private getPriorityBgColor(priority: EventPriority): string {
    if (priority === EventPriority.URGENT) {
      return '#FEF2F2';
    } else if (priority === EventPriority.HIGH) {
      return '#FFF7ED';
    } else if (priority === EventPriority.MEDIUM) {
      return '#EFF6FF';
    }
    return '#F1F5F9';
  }

  // 优先级辅助文字色
  private getPriorityTextColor(priority: EventPriority): string {
    if (priority === EventPriority.URGENT) {
      return '#DC2626';
    } else if (priority === EventPriority.HIGH) {
      return '#EA580C';
    } else if (priority === EventPriority.MEDIUM) {
      return '#1B6EFF';
    }
    return '#64748B';
  }

  // 状态辅助文字色
  private getStatusColor(status: EventStatus): string {
    if (status === EventStatus.PENDING) {
      return '#EA580C';
    } else if (status === EventStatus.CONFIRMED) {
      return '#1B6EFF';
    } else if (status === EventStatus.PROCESSING) {
      return '#D97706';
    } else if (status === EventStatus.COMPLETED) {
      return '#16A34A';
    }
    return '#64748B';
  }

  build() {
    Column() {
      // 头部标题与统计简述
      Column() {
        Row() {
          Column() {
            Text('安全事件')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
              .margin({ bottom: 4 })

            Text('校园安全事件列表 · 点击查看详情与指派')
              .fontSize(13)
              .fontColor('#64748B')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          // 计数徽章
          Text(this.events.length.toString() + ' 项记录')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1B6EFF')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#EFF6FF')
            .borderRadius(12)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      // 列表展示区
      if (this.events.length === 0) {
        Column({ space: 12 }) {
          Text('◆')
            .fontSize(40)
            .fontColor('#94A3B8')
            .margin({ bottom: 8 })

          Text('暂无待处理安全事件')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#334155')

          Text('当前校园运行平稳，所有上报已处理完毕')
            .fontSize(13)
            .fontColor('#94A3B8')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 14 }) {
          ForEach(this.events, (event: SecurityEvent) => {
            ListItem() {
              Column() {
                // 顶部标题与优先级徽章
                Row() {
                  Text(event.title)
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#0F172A')
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Row() {
                    Text(event.priority)
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.getPriorityTextColor(event.priority))
                  }
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(8)
                  .backgroundColor(this.getPriorityBgColor(event.priority))
                }
                .width('100%')
                .margin({ bottom: 12 })

                // 核心属性两列矩阵
                Column({ space: 6 }) {
                  Row() {
                    Text('事件编号：' + event.id)
                      .fontSize(13)
                      .fontColor('#64748B')
                      .layoutWeight(1)

                    Text('状态：' + event.status)
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.getStatusColor(event.status))
                  }
                  .width('100%')

                  Row() {
                    Text('地点：' + event.location)
                      .fontSize(13)
                      .fontColor('#475569')
                      .layoutWeight(1)

                    Text('类型：' + event.type)
                      .fontSize(13)
                      .fontColor('#64748B')
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(10)
                .borderRadius(10)
                .backgroundColor('#F8FAFC')
                .margin({ bottom: 10 })

                // 描述信息
                Text(event.description)
                  .fontSize(13)
                  .fontColor('#334155')
                  .lineHeight(19)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .margin({ bottom: 10 })

                // 底部信息与上报人
                Row() {
                  Text('上报人：' + event.reporter)
                    .fontSize(12)
                    .fontColor('#94A3B8')

                  Blank()

                  Text('查看详情 ›')
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1B6EFF')
                }
                .width('100%')
              }
              .width('100%')
              .padding(16)
              .borderRadius(16)
              .backgroundColor('#FFFFFF')
              .shadow({
                radius: 10,
                color: 'rgba(15, 23, 42, 0.05)',
                offsetY: 3
              })
            }
            /* 【不可改】点击行为：先写静态字段，再 pushPath 到 'EventDetailPage' */
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
        .layoutWeight(1)
        .padding({
          left: 16,
          right: 16,
          bottom: 16
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC')
  }
}
