import {
  SecurityEvent,
  EventStatus,
  EventPriority,
  EventType
} from '../model/SecurityEvent';
import {
  Task,
  TaskStatus
} from '../model/Task';
import { EventService } from '../service/EventService';
import { SafetyStatisticsService, SafetyStatisticsSnapshot } from '../service/SafetyStatisticsService';

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

  private getStatistics(): SafetyStatisticsSnapshot {
    return SafetyStatisticsService.createSnapshot(this.events, this.tasks);
  }

  private getHealthScore(): number | null {
    if (this.events.length === 0 && this.tasks.length === 0) {
      return null;
    }
    let penalty: number = 0;
    this.events.forEach((event: SecurityEvent) => {
      if (
        event.status === EventStatus.PENDING ||
        event.status === EventStatus.CONFIRMED
      ) {
        if (event.priority === EventPriority.URGENT) {
          penalty += 18;
        } else if (event.priority === EventPriority.HIGH) {
          penalty += 12;
        } else if (event.priority === EventPriority.MEDIUM) {
          penalty += 8;
        } else {
          penalty += 4;
        }
      } else if (event.status === EventStatus.PROCESSING) {
        penalty += 4;
      }
    });
    this.tasks.forEach((task: Task) => {
      if (task.status === TaskStatus.PENDING) {
        penalty += 6;
      } else if (task.status === TaskStatus.PROCESSING) {
        penalty += 3;
      }
    });
    const score: number = Math.max(0, Math.min(100, 100 - penalty));
    return Math.round(score * 10) / 10;
  }

  private getHealthGrade(score: number | null): string {
    if (score === null) {
      return '暂无数据';
    }
    if (score >= 95) {
      return 'A+';
    } else if (score >= 90) {
      return 'A';
    } else if (score >= 80) {
      return 'B';
    } else if (score >= 70) {
      return 'C';
    }
    return 'D';
  }

  private getHealthScoreText(): string {
    const score: number | null = this.getHealthScore();
    return score === null ? '—' : score.toString();
  }

  private getAverageResponse(): string {
    return SafetyStatisticsService.formatMinutes(this.getStatistics().averageFirstResponseMinutes);
  }

  private getAverageHandling(): string {
    return SafetyStatisticsService.formatMinutes(this.getStatistics().averageHandlingMinutes);
  }

  private getOnTimeRate(): string {
    const rate: number | null = this.getStatistics().onTimeCompletionRate;
    return rate === null ? '不适用' : rate.toString() + '%';
  }

  private getDomainRate(type: EventType): number {
    return SafetyStatisticsService.getTypeCompletionRate(this.events, type) ?? 0;
  }

  private getDomainRateLabel(type: EventType): string {
    const rate: number | null = SafetyStatisticsService.getTypeCompletionRate(this.events, type);
    return rate === null ? '暂无数据' : rate.toString() + '%';
  }

  private isSameDay(reportTime: string, date: Date): boolean {
    if (reportTime === '') {
      return false;
    }
    const datePart: string = reportTime.split(' ')[0];
    const d: string[] = datePart.split('-');
    return Number(d[0]) === date.getFullYear() &&
      Number(d[1]) === date.getMonth() + 1 &&
      Number(d[2]) === date.getDate();
  }

  private getLast7Days(): BarItem[] {
    const items: BarItem[] = [];
    const today: Date = new Date();
    const weekdays: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    let maxValue: number = 1;
    for (let i = 6; i >= 0; i--) {
      const day: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - i);
      const count: number = this.events.filter(
        (event: SecurityEvent) => this.isSameDay(event.reportTime, day)
      ).length;
      if (count > maxValue) {
        maxValue = count;
      }
      items.push({
        day: weekdays[day.getDay()],
        value: count,
        height: '0%'
      });
    }
    items.forEach((item: BarItem) => {
      item.height = Math.round(item.value / maxValue * 100).toString() + '%';
    });
    return items;
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
          // 实时健康度卡片
          Column() {
            Row() {
              Column() {
                Text('实时健康度 ' + this.getHealthGrade(this.getHealthScore()))
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
                Text(this.getHealthScoreText())
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

            Text('平均首次响应：' + this.getAverageResponse())
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

          // 真实状态指标
          Row({ space: 8 }) {
            Column() {
              Text('待确认')
                .fontSize(10)
                .fontColor('#94A3B8')
              Text(this.getStatistics().pendingEvents.toString())
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#2563EB')
                .margin({ top: 4 })
              Text('需确认')
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
              Text('处理中')
                .fontSize(10)
                .fontColor('#94A3B8')
              Text(this.getStatistics().processingEvents.toString())
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#D97706')
                .margin({ top: 4 })
              Text('事件')
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
              Text('待审核')
                .fontSize(10)
                .fontColor('#94A3B8')
              Text(this.getStatistics().reviewEvents.toString())
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#059669')
                .margin({ top: 4 })
              Text('事件')
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

          Column({ space: 8 }) {
            Text('处置效率')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#334155')
              .width('100%')
            Row({ space: 8 }) {
              this.metricItem('已完成', this.getStatistics().completedEvents.toString())
              this.metricItem('超时任务', this.getStatistics().overdueTasks.toString())
              this.metricItem('平均处置', this.getAverageHandling())
              this.metricItem('按期完成', this.getOnTimeRate())
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(Color.White)
          .border({ width: 1, color: '#E2E8F0' })

          // 各领域达标率（按真实事件闭环率计算）
          Column({ space: 12 }) {
            Row() {
              Text('各重点安防领域达标率')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#334155')
              Blank()
              Text('实时计算')
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
                Text(this.getDomainRateLabel(EventType.FIRE))
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#334155')
              }
              .width('100%')

              Row() {
                Row()
                  .width(this.getDomainRate(EventType.FIRE).toString() + '%')
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
                Text(this.getDomainRateLabel(EventType.ELECTRIC))
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#334155')
              }
              .width('100%')

              Row() {
                Row()
                  .width(this.getDomainRate(EventType.ELECTRIC).toString() + '%')
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
                Text(this.getDomainRateLabel(EventType.FACILITY))
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#334155')
              }
              .width('100%')

              Row() {
                Row()
                  .width(this.getDomainRate(EventType.FACILITY).toString() + '%')
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

          // 近 7 日事件趋势（按实际报告时间统计）
          Column() {
            Row() {
              Text('近 7 日事件办结趋势')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#334155')
              Blank()
              Text('实时')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor('#059669')
            }
            .width('100%')
            .margin({ bottom: 10 })

            Row() {
              ForEach(this.getLast7Days(), (item: BarItem) => {
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

  @Builder
  private metricItem(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label).fontSize(10).fontColor('#64748B')
      Text(value).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#0F172A')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }
}
