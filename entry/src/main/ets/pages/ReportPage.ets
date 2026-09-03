import {
  EventType,
  EventPriority
} from '../model/SecurityEvent';
import { EventWorkflowService } from '../service/EventWorkflowService';
import { promptAction } from '@kit.ArkUI';

interface TypeCard {
  type: EventType;
  label: string;
  icon: string;
  color: string;
  bg: string;
}

@Component
export struct ReportPage {
  pageStack: NavPathStack = new NavPathStack();

  @State private pageReady: boolean = false;
  @State private selectedTypeIndex: number = 0;
  @State private selectedPriorityIndex: number = 1;
  @State private location: string = '';
  @State private description: string = '';
  @State private reporter: string = '';
  @State private hasPhoto: boolean = false;

  private typeCards: TypeCard[] = [
    { type: EventType.FIRE, label: '消防隐患', icon: '▲', color: '#DC2626', bg: '#FEF2F2' },
    { type: EventType.ELECTRIC, label: '用电安全', icon: '◆', color: '#D97706', bg: '#FFF7ED' },
    { type: EventType.FACILITY, label: '设施故障', icon: '●', color: '#2563EB', bg: '#EFF6FF' },
    { type: EventType.CAMPUS, label: '校园秩序', icon: '◇', color: '#7C3AED', bg: '#FAF5FF' },
    { type: EventType.OTHER, label: '其他隐患', icon: '○', color: '#64748B', bg: '#F1F5F9' }
  ];

  private quickLocations: string[] = [
    '明德楼',
    '物理实验楼',
    '第12学生宿舍',
    '北区第一食堂',
    '东区体育馆'
  ];

  private priorityValues: EventPriority[] = [
    EventPriority.URGENT,
    EventPriority.HIGH,
    EventPriority.MEDIUM,
    EventPriority.LOW
  ];

  private submit(): void {
    if (this.location.trim() === '' || this.description.trim() === '') {
      promptAction.showToast({ message: '请填写发生地点和隐患描述' });
      return;
    }
    const result = EventWorkflowService.reportHazard({
      title: EventWorkflowService.buildSummaryTitle(this.description),
      type: this.typeCards[this.selectedTypeIndex].type,
      location: this.location,
      description: this.description,
      reporter: this.reporter,
      priority: this.priorityValues[this.selectedPriorityIndex]
    });
    if (result === undefined) {
      promptAction.showToast({ message: '请填写发生地点和隐患描述' });
    } else {
      promptAction.showToast({ message: '上报成功！编号：' + result.id });
      this.location = '';
      this.description = '';
      this.reporter = '';
      this.hasPhoto = false;
    }
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
          Text('隐患上报')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Text('随手拍隐患 · 师生共建平安校园')
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
        Column({ space: 12 }) {
          // 隐患类型选择
          Column() {
            Row() {
              Text('隐患类型选择')
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#334155')
              Text(' *')
                .fontSize(11)
                .fontColor('#EF4444')
            }
            .width('100%')
            .margin({ bottom: 10 })

            Row({ space: 8 }) {
              ForEach(this.typeCards.slice(0, 3), (item: TypeCard, index: number) => {
                this.typeCell(item, index)
              }, (item: TypeCard) => item.type)
            }
            .width('100%')

            Row({ space: 8 }) {
              ForEach(this.typeCards.slice(3, 5), (item: TypeCard, index: number) => {
                this.typeCell(item, index + 3)
              }, (item: TypeCard) => item.type)
            }
            .width('100%')
            .margin({ top: 8 })
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(Color.White)
          .border({ width: 1, color: '#E2E8F0' })
          .shadow({ radius: 8, color: 'rgba(15,23,42,0.03)', offsetY: 2 })

          // 隐患等级
          Column({ space: 8 }) {
            Row() {
              Text('隐患等级')
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#334155')
              Text('（用于评估处置优先级）')
                .fontSize(10)
                .fontColor('#94A3B8')
                .margin({ left: 4 })
            }
            .width('100%')

            Row({ space: 8 }) {
              ForEach(this.priorityValues, (priority: EventPriority, index: number) => {
                Text(priority)
                  .fontSize(11)
                  .fontWeight(this.selectedPriorityIndex === index ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.selectedPriorityIndex === index ? Color.White : '#475569')
                  .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                  .borderRadius(12)
                  .backgroundColor(
                    this.selectedPriorityIndex === index
                      ? (priority === EventPriority.URGENT || priority === EventPriority.HIGH ? '#DC2626' : '#2563EB')
                      : '#F1F5F9'
                  )
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    this.selectedPriorityIndex = index;
                  })
              }, (priority: EventPriority) => priority)
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(Color.White)
          .border({ width: 1, color: '#E2E8F0' })

          // 发生地点
          Column({ space: 8 }) {
            Row() {
              Text('发生具体地点')
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#334155')
              Text(' *')
                .fontSize(11)
                .fontColor('#EF4444')
            }
            .width('100%')

            TextInput({
              placeholder: '请输入发生地点',
              text: this.location
            })
              .width('100%')
              .height(42)
              .fontSize(12)
              .borderRadius(12)
              .backgroundColor('#F8FAFC')
              .border({ width: 1, color: '#E2E8F0' })
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.location = value;
              })

            Scroll() {
              Row({ space: 6 }) {
                Text('快捷输入:')
                  .fontSize(10)
                  .fontColor('#94A3B8')
                ForEach(this.quickLocations, (loc: string) => {
                  Text(loc)
                    .fontSize(10)
                    .fontColor('#475569')
                    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                    .borderRadius(10)
                    .backgroundColor('#F1F5F9')
                    .onClick(() => {
                      this.location = loc;
                    })
                }, (loc: string) => loc)
              }
              .width('100%')
            }
            .width('100%')
            .scrollBar(BarState.Off)
            .scrollable(ScrollDirection.Horizontal)
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(Color.White)
          .border({ width: 1, color: '#E2E8F0' })

          // 隐患描述
          Column({ space: 8 }) {
            Row() {
              Text('详细隐患情况')
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#334155')
              Text(' *')
                .fontSize(11)
                .fontColor('#EF4444')
            }
            .width('100%')

            TextArea({
              placeholder: '请详细说明现场隐患现象',
              text: this.description
            })
              .width('100%')
              .height(96)
              .fontSize(12)
              .borderRadius(12)
              .backgroundColor('#F8FAFC')
              .border({ width: 1, color: '#E2E8F0' })
              .padding(12)
              .onChange((value: string) => {
                this.description = value;
              })
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(Color.White)
          .border({ width: 1, color: '#E2E8F0' })

          // 现场照片与上报人
          Column({ space: 12 }) {
            Column({ space: 6 }) {
              Text('现场证据照片')
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#334155')
                .width('100%')

              if (this.hasPhoto) {
                Row() {
                  Text('✓ 已添加照片')
                    .fontSize(11)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#2563EB')
                  Text('移除')
                    .fontSize(10)
                    .fontColor('#DC2626')
                    .margin({ left: 10 })
                    .onClick(() => {
                      this.hasPhoto = false;
                    })
                }
                .width('100%')
                .height(64)
                .borderRadius(14)
                .backgroundColor('#EFF6FF')
                .border({ width: 1, color: '#BFDBFE' })
                .justifyContent(FlexAlign.Center)
              } else {
                Text('点击模拟拍摄或上传照片')
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#64748B')
                  .width('100%')
                  .height(64)
                  .borderRadius(14)
                  .border({ width: 1, color: '#CBD5E1' })
                  .borderStyle(BorderStyle.Dashed)
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    this.hasPhoto = true;
                    promptAction.showToast({ message: '已模拟获取现场拍摄照片' });
                  })
              }
            }
            .width('100%')

            Column({ space: 6 }) {
              Row() {
                Text('上报人姓名/电话')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#334155')
                Text('（选填）')
                  .fontSize(10)
                  .fontColor('#94A3B8')
                  .margin({ left: 4 })
              }
              .width('100%')

              TextInput({
                placeholder: '留空则默认为匿名上报',
                text: this.reporter
              })
                .width('100%')
                .height(42)
                .fontSize(12)
                .borderRadius(12)
                .backgroundColor('#F8FAFC')
                .border({ width: 1, color: '#E2E8F0' })
                .padding({ left: 12, right: 12 })
                .onChange((value: string) => {
                  this.reporter = value;
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(Color.White)
          .border({ width: 1, color: '#E2E8F0' })

          // 提交按钮
          Button('立即提交隐患')
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
              this.submit();
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

  @Builder
  typeCell(item: TypeCard, index: number) {
    Column() {
      Text(item.icon)
        .fontSize(18)
        .fontColor(this.selectedTypeIndex === index ? Color.White : item.color)

      Text(item.label)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.selectedTypeIndex === index ? Color.White : '#334155')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .height(64)
    .borderRadius(14)
    .backgroundColor(
      this.selectedTypeIndex === index ? '#2563EB' : item.bg
    )
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.selectedTypeIndex = index;
    })
  }
}
