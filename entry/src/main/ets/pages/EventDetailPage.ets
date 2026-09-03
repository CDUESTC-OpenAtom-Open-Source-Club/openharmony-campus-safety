import {
  SecurityEvent,
  EventType,
  EventStatus,
  EventPriority
} from '../model/SecurityEvent';
import { EventService } from '../service/EventService';

@Component
export struct EventDetailPage {
  pageStack: NavPathStack = new NavPathStack();

  @State private eventId: string = EventService.getSelectedEventId();
  @State private isConfirmed: boolean = false;
  @State private taskGenerated: boolean = false;

  @Builder
  flowNode(
    index: number,
    label: string,
    done: boolean,
    active: boolean
  ) {
    Column() {
      Text(done ? '✓' : index.toString())
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(done ? Color.White : active ? Color.White : '#64748B')
    }
    .width(24)
    .height(24)
    .borderRadius(12)
    .backgroundColor(done ? '#10B981' : active ? '#2563EB' : '#E2E8F0')
    .justifyContent(FlexAlign.Center)

    Text(label)
      .fontSize(9)
      .fontWeight(FontWeight.Medium)
      .fontColor(done || active ? '#2563EB' : '#94A3B8')
      .margin({ top: 5 })
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
          Text('事件详情')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Text('单号：' + this.eventId)
            .fontSize(10)
            .fontColor('#94A3B8')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 14, bottom: 10 })
      .backgroundColor(Color.White)

      if (this.eventId === '') {
        Column({ space: 10 }) {
          Text('●')
            .fontSize(32)
            .fontColor('#CBD5E1')
          Text('未找到安全事件')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#475569')
          Text('该事件不存在或已从系统中归档')
            .fontSize(12)
            .fontColor('#94A3B8')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            // 全流程 5 节点流转轴
            Column() {
              Row() {
                Text('事件全流程流转进度')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#334155')
                Blank()
                Text(
                  this.taskGenerated
                    ? '第 3 阶段 · 现场处置'
                    : this.isConfirmed
                    ? '第 2 阶段 · 已确认'
                    : '第 1 阶段 · 待核查'
                )
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#2563EB')
              }
              .width('100%')
              .margin({ bottom: 14 })

              Row() {
                this.flowNode(1, '上报', true, true)

                Row()
                  .height(2)
                  .layoutWeight(1)
                  .backgroundColor(this.isConfirmed || this.taskGenerated ? '#2563EB' : '#E2E8F0')
                  .margin({ bottom: 18 })

                this.flowNode(2, '确认', this.isConfirmed, this.isConfirmed)

                Row()
                  .height(2)
                  .layoutWeight(1)
                  .backgroundColor(this.taskGenerated ? '#2563EB' : '#E2E8F0')
                  .margin({ bottom: 18 })

                this.flowNode(3, '指派', this.taskGenerated, this.taskGenerated)

                Row()
                  .height(2)
                  .layoutWeight(1)
                  .backgroundColor(this.getEvent().status === EventStatus.COMPLETED ? '#10B981' : '#E2E8F0')
                  .margin({ bottom: 18 })

                this.flowNode(4, '处置', false, this.getEvent().status === EventStatus.COMPLETED)

                Row()
                  .height(2)
                  .layoutWeight(1)
                  .backgroundColor(this.getEvent().status === EventStatus.COMPLETED ? '#10B981' : '#E2E8F0')
                  .margin({ bottom: 18 })

                this.flowNode(5, '闭环', false, this.getEvent().status === EventStatus.COMPLETED)
              }
              .width('100%')
              .alignItems(VerticalAlign.Bottom)
            }
            .width('100%')
            .padding(14)
            .borderRadius(18)
            .backgroundColor(Color.White)
            .border({ width: 1, color: '#E2E8F0' })
            .shadow({ radius: 8, color: 'rgba(15,23,42,0.03)', offsetY: 2 })

            // 头部详情卡片
            Column() {
              Row() {
                Text(this.getEvent().type)
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                  .borderRadius(10)
                  .backgroundColor('rgba(255,255,255,0.18)')

                Blank()

                Text('优先级：' + this.getEvent().priority)
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FCD34D')
                  .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                  .borderRadius(10)
                  .backgroundColor('rgba(245,158,11,0.18)')
                  .border({ width: 1, color: 'rgba(245,158,11,0.35)' })
              }
              .width('100%')
              .margin({ bottom: 10 })

              Text(this.getEvent().title)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .width('100%')

              Text(this.getEvent().location)
                .fontSize(11)
                .fontColor('rgba(255,255,255,0.7)')
                .margin({ top: 6 })
            }
            .width('100%')
            .padding(16)
            .borderRadius(20)
            .linearGradient({
              angle: 135,
              colors: [['#0F172A', 0.0], ['#312E81', 1.0]]
            })
            .shadow({ radius: 16, color: 'rgba(15,23,42,0.25)', offsetY: 6 })

            // 核心信息卡片
            Column({ space: 10 }) {
              Text('工单核心信息')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor('#94A3B8')
                .width('100%')

              Row() {
                Text('上报人员')
                  .fontSize(12)
                  .fontColor('#64748B')
                  .layoutWeight(1)
                Text(this.getEvent().reporter)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#0F172A')
              }
              .width('100%')

              Row() {
                Text('上报时间')
                  .fontSize(12)
                  .fontColor('#64748B')
                  .layoutWeight(1)
                Text(this.getEvent().reportTime)
                  .fontSize(12)
                  .fontColor('#475569')
              }
              .width('100%')

              Row() {
                Text('当前流转状态')
                  .fontSize(12)
                  .fontColor('#64748B')
                  .layoutWeight(1)
                Text(this.isConfirmed ? EventStatus.CONFIRMED : this.getEvent().status)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#2563EB')
              }
              .width('100%')
            }
            .width('100%')
            .padding(14)
            .borderRadius(18)
            .backgroundColor(Color.White)
            .border({ width: 1, color: '#E2E8F0' })
            .shadow({ radius: 8, color: 'rgba(15,23,42,0.03)', offsetY: 2 })

            // 现场情况描述
            Column() {
              Text('现场情况描述')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor('#94A3B8')
                .width('100%')
                .margin({ bottom: 8 })

              Text(this.getEvent().description)
                .fontSize(12)
                .fontColor('#334155')
                .lineHeight(20)
                .width('100%')
                .padding(12)
                .borderRadius(14)
                .backgroundColor('#F8FAFC')
            }
            .width('100%')
            .padding(14)
            .borderRadius(18)
            .backgroundColor(Color.White)
            .border({ width: 1, color: '#E2E8F0' })

            // 操作按钮
            if (
              this.getEvent().status === EventStatus.PENDING &&
              !this.isConfirmed
            ) {
              Button('确认事件属实')
                .width('100%')
                .height(46)
                .borderRadius(14)
                .backgroundColor('#2563EB')
                .fontColor(Color.White)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .shadow({ radius: 10, color: 'rgba(37,99,235,0.25)', offsetY: 4 })
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
              Button('下发并生成现场处置任务')
                .width('100%')
                .height(46)
                .borderRadius(14)
                .backgroundColor('#0EA5E9')
                .fontColor(Color.White)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .shadow({ radius: 10, color: 'rgba(14,165,233,0.25)', offsetY: 4 })
                .margin({ top: 10 })
                .onClick(() => {
                  EventService.createTaskFromEvent(this.eventId);
                  this.taskGenerated = true;
                })
            }

            if (this.taskGenerated) {
              Column({ space: 10 }) {
                Text('✓ 处置工单已下发，维保团队已接入')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#059669')
                  .width('100%')
                  .textAlign(TextAlign.Center)

                Button('前往处置任务中心')
                  .width('100%')
                  .height(42)
                  .borderRadius(12)
                  .backgroundColor('#059669')
                  .fontColor(Color.White)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .onClick(() => {
                    this.pageStack.pushPath({ name: 'TaskPage' });
                  })
              }
              .width('100%')
              .padding(14)
              .borderRadius(16)
              .backgroundColor('#ECFDF5')
              .border({ width: 1, color: '#A7F3D0' })
              .margin({ top: 10 })
            }
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 24 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC')
  }

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
