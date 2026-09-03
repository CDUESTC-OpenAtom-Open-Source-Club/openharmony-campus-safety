import {
  SecurityEvent
} from '../model/SecurityEvent';
import {
  Task,
  TaskStatus
} from '../model/Task';
import { EventService } from '../service/EventService';

interface BarItem {
  day: string;
  value: number;
  height: string;
}

@Component
export struct StatisticsPage {
  pageStack: NavPathStack = new NavPathStack();

  @State private pageReady: boolean = false;
  @State private events: SecurityEvent[] = EventService.getAllEvents();
  @State private tasks: Task[] = EventService.getAllTasks();

  private bars: BarItem[] = [
    { day: '周一', value: 4, height: '40%' },
    { day: '周二', value: 6, height: '60%' },
    { day: '周三', value: 3, height: '30%' },
    { day: '周四', value: 8, height: '80%' },
    { day: '周五', value: 5, height: '50%' },
    { day: '周六', value: 2, height: '20%' },
    { day: '周日', value: 7, height: '70%' }
  ];

  private getPendingTaskCount(): number {
    return this.tasks.filter(
      (task: Task) =>
        task.status === TaskStatus.PENDING ||
        task.status === TaskStatus.PROCESSING
    ).length;
  }

  private getCompletedTaskCount(): number {
    return this.tasks.filter(
      (task: Task) => task.status === TaskStatus.COMPLETED
    ).length;
  }

  private refreshData(): void {
    this.events = EventService.getAllEvents().slice();
    this.tasks = EventService.getAllTasks().slice();
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
          Text('数据统计')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Text('校园安全态势综合量化分析')
            .fontSize(10)
            .fontColor('#94A3B8')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text('刷新')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2563EB')
          .padding({ left: 11, right: 11, top: 5, bottom: 5 })
          .borderRadius(12)
          .backgroundColor('#EFF6FF')
          .onClick(() => {
            this.refreshData();
          })
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 14, bottom: 10 })
      .backgroundColor(Color.White)

      Scroll() {
        Column({ space: 12 }) {
          // 综合评分卡片
          Column() {
            Row() {
              Column() {
                Text('实时健康度 A+')
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#6EE7B7')
                  .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                  .borderRadius(10)
                  .backgroundColor('rgba(16,185,129,0.18)')
                  .border({ width: 1, color: 'rgba(16,185,129,0.35)' })

                Text('校园安全运行态势')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .margin({ top: 8 })
              }
              .alignItems(HorizontalAlign.Start)

              Blank()

              Column() {
                Text('98.5')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#6EE7B7')
              }
              .width(48)
              .height(48)
              .borderRadius(24)
              .border({ width: 2, color: '#34D399' })
              .justifyContent(FlexAlign.Center)
            }
            .width('100%')
            .margin({ bottom: 10 })

            Text('联动巡检网格、物业电工与安保中队，平均响应 4.8 分钟')
              .fontSize(11)
              .fontColor('rgba(255,255,255,0.65)')
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .borderRadius(20)
          .linearGradient({
            angle: 135,
            colors: [['#0F172A', 0.0], ['#1E293B', 0.6], ['#312E81', 1.0]]
          })
          .shadow({ radius: 16, color: 'rgba(15,23,42,0.25)', offsetY: 6 })

          // 三项指标
          Row({ space: 8 }) {
            Column() {
              Text('安全事件')
                .fontSize(10)
                .fontColor('#94A3B8')
              Text(this.events.length.toString())
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#2563EB')
                .margin({ top: 4 })
              Text('全量汇聚')
                .fontSize(9)
                .fontColor('#94A3B8')
                .margin({ top: 2 })
            }
            .layoutWeight(1)
            .padding(12)
            .borderRadius(14)
            .backgroundColor(Color.White)
            .border({ width: 1, color: '#E2E8F0' })

            Column() {
              Text('待办任务')
                .fontSize(10)
                .fontColor('#94A3B8')
              Text(this.getPendingTaskCount().toString())
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#D97706')
                .margin({ top: 4 })
              Text('处置中')
                .fontSize(9)
                .fontColor('#94A3B8')
                .margin({ top: 2 })
            }
            .layoutWeight(1)
            .padding(12)
            .borderRadius(14)
            .backgroundColor(Color.White)
            .border({ width: 1, color: '#E2E8F0' })

            Column() {
              Text('已办结')
                .fontSize(10)
                .fontColor('#94A3B8')
              Text(this.getCompletedTaskCount().toString())
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#059669')
                .margin({ top: 4 })
              Text('归档闭环')
                .fontSize(9)
                .fontColor('#94A3B8')
                .margin({ top: 2 })
            }
            .layoutWeight(1)
            .padding(12)
            .borderRadius(14)
            .backgroundColor(Color.White)
            .border({ width: 1, color: '#E2E8F0' })
          }
          .width('100%')

          // 达标率分布
          Column({ space: 12 }) {
            Row() {
              Text('各重点安防领域达标率')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#334155')
              Blank()
              Text('本周动态')
                .fontSize(10)
                .fontColor('#94A3B8')
            }
            .width('100%')

            Column({ space: 8 }) {
              Row() {
                Text('消防器材与通道')
                  .fontSize(11)
                  .fontColor('#475569')
                  .layoutWeight(1)
                Text('92%')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#334155')
              }
              .width('100%')

              Row() {
                Row()
                  .width('92%')
                  .height(8)
                  .borderRadius(4)
                  .backgroundColor('#2563EB')
              }
              .width('100%')
              .height(8)
              .borderRadius(4)
              .backgroundColor('#F1F5F9')
            }
            .width('100%')

            Column({ space: 8 }) {
              Row() {
                Text('强弱电与实验室用电')
                  .fontSize(11)
                  .fontColor('#475569')
                  .layoutWeight(1)
                Text('96%')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#334155')
              }
              .width('100%')

              Row() {
                Row()
                  .width('96%')
                  .height(8)
                  .borderRadius(4)
                  .backgroundColor('#10B981')
              }
              .width('100%')
              .height(8)
              .borderRadius(4)
              .backgroundColor('#F1F5F9')
            }
            .width('100%')

            Column({ space: 8 }) {
              Row() {
                Text('楼宇公共设施及门窗')
                  .fontSize(11)
                  .fontColor('#475569')
                  .layoutWeight(1)
                Text('88%')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#334155')
              }
              .width('100%')

              Row() {
                Row()
                  .width('88%')
                  .height(8)
                  .borderRadius(4)
                  .backgroundColor('#F59E0B')
              }
              .width('100%')
              .height(8)
              .borderRadius(4)
              .backgroundColor('#F1F5F9')
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(Color.White)
          .border({ width: 1, color: '#E2E8F0' })

          // 近 7 日柱状图
          Column() {
            Row() {
              Text('近 7 日事件办结趋势')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#334155')
              Blank()
              Text('环比提升 12%')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor('#059669')
            }
            .width('100%')
            .margin({ bottom: 10 })

            Row() {
              ForEach(this.bars, (item: BarItem) => {
                Column() {
                  Text(item.value.toString())
                    .fontSize(9)
                    .fontColor('#94A3B8')
                  Column() {
                    Column()
                      .width('100%')
                      .height(item.height)
                      .borderRadius({ topLeft: 4, topRight: 4 })
                      .backgroundColor('#2563EB')
                  }
                  .width(14)
                  .height(56)
                  .borderRadius({ topLeft: 4, topRight: 4 })
                  .backgroundColor('#F1F5F9')
                  .justifyContent(FlexAlign.End)
                  .margin({ top: 4 })

                  Text(item.day)
                    .fontSize(9)
                    .fontColor('#64748B')
                    .margin({ top: 4 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
              }, (item: BarItem) => item.day)
            }
            .width('100%')
            .height(96)
            .alignItems(VerticalAlign.Bottom)
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(Color.White)
          .border({ width: 1, color: '#E2E8F0' })
          .margin({ bottom: 20 })
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
}
