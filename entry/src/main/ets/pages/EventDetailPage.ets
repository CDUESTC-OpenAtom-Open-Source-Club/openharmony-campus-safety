import {
  SecurityEvent,
  EventType,
  EventStatus,
  EventPriority
} from '../model/SecurityEvent';

import { EventService } from '../service/EventService';

@Component
export struct EventDetailPage {
  /* 【不可改】@State 与取值方式逐字保留 */
  @State private eventId: string = EventService.getSelectedEventId();
  @State private isConfirmed: boolean = false;
  @State private taskGenerated: boolean = false;

  build() {
    Column() {
      if (this.eventId !== '') {
        Scroll() {
          this.buildEventDetail()
        }
        .width('100%')
        .height('100%')
      } else {
        Column({ space: 12 }) {
          Text('●')
            .fontSize(36)
            .fontColor('#94A3B8')
            .margin({ bottom: 6 })

          Text('未找到事件')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Text('该事件不存在或已从系统中归档')
            .fontSize(14)
            .fontColor('#64748B')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC')
  }

  /* 【不可改】@Builder 方法与 getEvent() 方法名、逻辑、返回值逐字保留；仅可美化其内部排版 */
  @Builder
  buildEventDetail() {
    Column() {
      // 头部主卡片
      Column() {
        Row() {
          Row() {
            Text('事件详情')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(6)
          .backgroundColor('rgba(255, 255, 255, 0.25)')

          Blank()

          Row() {
            Text('优先级: ' + this.getEvent().priority)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(6)
          .backgroundColor('rgba(0, 0, 0, 0.2)')
        }
        .width('100%')
        .margin({ bottom: 12 })

        Text(this.getEvent().title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width('100%')
          .margin({ bottom: 8 })

        Text('编号：' + this.getEvent().id)
          .fontSize(13)
          .fontColor('rgba(255, 255, 255, 0.8)')
          .width('100%')
      }
      .width('100%')
      .padding(20)
      .borderRadius(18)
      .linearGradient({
        angle: 135,
        colors: [['#1B6EFF', 0.0], ['#0F4CA6', 1.0]]
      })
      .shadow({ radius: 14, color: 'rgba(27, 110, 255, 0.25)', offsetY: 6 })
      .margin({ bottom: 16 })

      // 核心属性矩阵卡片
      Column({ space: 10 }) {
        Text('核心属性')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#334155')
          .width('100%')
          .margin({ bottom: 4 })

        Row() {
          Text('事件类型')
            .fontSize(14)
            .fontColor('#64748B')
            .width(80)

          Text(this.getEvent().type)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F172A')
            .layoutWeight(1)
        }
        .width('100%')

        Row() {
          Text('发生地点')
            .fontSize(14)
            .fontColor('#64748B')
            .width(80)

          Text(this.getEvent().location)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F172A')
            .layoutWeight(1)
        }
        .width('100%')

        Row() {
          Text('当前状态')
            .fontSize(14)
            .fontColor('#64748B')
            .width(80)

          Text(
            this.isConfirmed
              ? EventStatus.CONFIRMED
              : this.getEvent().status
          )
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isConfirmed || this.getEvent().status === EventStatus.CONFIRMED ? '#1B6EFF' : '#EA580C')
            .layoutWeight(1)
        }
        .width('100%')

        Row() {
          Text('上报人')
            .fontSize(14)
            .fontColor('#64748B')
            .width(80)

          Text(this.getEvent().reporter)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F172A')
            .layoutWeight(1)
        }
        .width('100%')

        Row() {
          Text('上报时间')
            .fontSize(14)
            .fontColor('#64748B')
            .width(80)

          Text(this.getEvent().reportTime)
            .fontSize(14)
            .fontColor('#475569')
            .layoutWeight(1)
        }
        .width('100%')
      }
      .width('100%')
      .padding(18)
      .borderRadius(16)
      .backgroundColor('#FFFFFF')
      .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.04)', offsetY: 2 })
      .margin({ bottom: 16 })

      // 事件描述详情卡片
      Column() {
        Text('事件描述')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#334155')
          .width('100%')
          .margin({ bottom: 10 })

        Text(this.getEvent().description)
          .fontSize(14)
          .fontColor('#1E293B')
          .lineHeight(22)
          .width('100%')
      }
      .width('100%')
      .padding(18)
      .borderRadius(16)
      .backgroundColor('#FFFFFF')
      .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.04)', offsetY: 2 })
      .margin({ bottom: 24 })

      // 操作协同按钮组
      if (
        this.getEvent().status === EventStatus.PENDING &&
          !this.isConfirmed
      ) {
        Button('确认事件')
          .width('100%')
          .height(48)
          .borderRadius(12)
          .backgroundColor('#1B6EFF')
          .fontWeight(FontWeight.Medium)
          .shadow({ radius: 10, color: 'rgba(27, 110, 255, 0.25)', offsetY: 4 })
          .onClick(() => {
            EventService.confirmEvent(this.eventId);
            this.isConfirmed = true;
          })
      }

      if (
        (this.getEvent().status === EventStatus.CONFIRMED ||
        this.isConfirmed) &&
          !this.taskGenerated
      ) {
        Button('生成处置任务')
          .width('100%')
          .height(48)
          .borderRadius(12)
          .backgroundColor('#0EA5E9')
          .fontWeight(FontWeight.Medium)
          .shadow({ radius: 10, color: 'rgba(14, 165, 233, 0.25)', offsetY: 4 })
          .margin({ top: 12 })
          .onClick(() => {
            EventService.createTaskFromEvent(this.eventId);
            this.taskGenerated = true;
          })
      }

      if (this.taskGenerated) {
        Row() {
          Text('✓ 处置任务已生成，巡检团队已接入')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#16A34A')
        }
        .width('100%')
        .padding(14)
        .borderRadius(12)
        .backgroundColor('#F0FDF4')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(16)
  }

  /* 【不可改】getEvent() 兜底对象字段与枚举值逐字保留 */
  private getEvent(): SecurityEvent {
    const event = EventService.getEventById(this.eventId);

    if (event !== undefined) {
      return event;
    }

    return {
      id: '',
      title: '未知事件',
      type: EventType.FACILITY,
      location: '',
      description: '',
      reporter: '',
      reportTime: '',
      status: EventStatus.PENDING,
      priority: EventPriority.LOW
    };
  }
}
