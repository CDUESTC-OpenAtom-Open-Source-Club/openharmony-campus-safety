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
import { AppTheme } from '../common/AppTheme';

interface BarItem {
  day: string;
  value: number;
  height: string;
}

interface DomainItem {
  type: EventType;
  label: string;
  color: string;
}

@Component
export struct StatisticsPage {
  pageStack: NavPathStack = new NavPathStack();

  @State private pageReady: boolean = false;
  @State private events: SecurityEvent[] = EventService.getAllEvents();
  @State private tasks: Task[] = EventService.getAllTasks();

  private domains: DomainItem[] = [
    { type: EventType.FIRE, label: '消防器材与通道', color: AppTheme.accent },
    { type: EventType.ELECTRIC, label: '强弱电与实验室用电', color: AppTheme.success },
    { type: EventType.FACILITY, label: '楼宇公共设施及门窗', color: AppTheme.amber }
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

  @Builder
  sectionHeader(title: string, tag: string) {
    Row() {
      Row()
        .width(4)
        .height(12)
        .borderRadius(2)
        .backgroundColor(AppTheme.accent)
        .margin({ right: 6 })
      Text(title)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.ink)
      Blank()
      if (tag !== '') {
        Text(tag)
          .fontSize(10)
          .fontColor(AppTheme.muted)
      }
    }
    .width('100%')
  }

  @Builder
  metricItem(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(10)
        .fontColor(AppTheme.muted)
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.ink)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  domainMeter(item: DomainItem) {
    Column({ space: 8 }) {
      Row() {
        Row()
          .width(4)
          .height(12)
          .borderRadius(2)
          .backgroundColor(item.color)
          .margin({ right: 6 })
        Text(item.label)
          .fontSize(11)
          .fontColor(AppTheme.inkSoft)
          .layoutWeight(1)
        Text(this.getDomainRateLabel(item.type))
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.ink)
      }
      .width('100%')

      Row() {
        Row()
          .width(this.getDomainRate(item.type).toString() + '%')
          .height(8)
          .borderRadius(4)
          .backgroundColor(item.color)
      }
      .width('100%')
      .height(8)
      .borderRadius(4)
      .backgroundColor(AppTheme.surfaceMuted)
    }
    .width('100%')
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor(AppTheme.inkSoft)
          .padding({ left: 4, right: 10 })
          .onClick(() => {
            this.pageStack.pop();
          })

        Column({ space: 2 }) {
          Text('数据统计')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ink)

          Text('校园安全态势综合量化分析')
            .fontSize(10)
            .fontColor(AppTheme.muted)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text('刷新')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.accent)
          .padding({ left: 11, right: 11, top: 5, bottom: 5 })
          .borderRadius(12)
          .backgroundColor(AppTheme.accentSoft)
          .border({ width: 1, color: AppTheme.cyanSoft })
          .onClick(() => {
            this.refreshData();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 16, top: 14, bottom: 12 })
      .backgroundColor(AppTheme.surface)
      .border({ width: { bottom: 1 }, color: AppTheme.line })

      Scroll() {
        Column({ space: 12 }) {
          // 实时健康度卡片 (现代冷色安全座舱)
          Column() {
            Row() {
              Column({ space: 6 }) {
                Row({ space: 6 }) {
                  Row()
                    .width(6)
                    .height(6)
                    .borderRadius(3)
                    .backgroundColor('#38BDF8')
                  Text('综合态势 · ' + this.getHealthGrade(this.getHealthScore()))
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#38BDF8')
                    .letterSpacing(0.5)
                }
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .borderRadius(6)
                .backgroundColor('rgba(56,189,248,0.12)')
                .border({ width: 1, color: 'rgba(56,189,248,0.25)' })

                Text('校园安全运行指数')
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
              }
              .alignItems(HorizontalAlign.Start)

              Blank()

              Column() {
                Text(this.getHealthScoreText())
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#38BDF8')
              }
              .width(52)
              .height(52)
              .borderRadius(26)
              .border({ width: 2.5, color: AppTheme.info })
              .backgroundColor('rgba(2,132,199,0.15)')
              .justifyContent(FlexAlign.Center)
            }
            .width('100%')
            .margin({ bottom: 12 })

            Row() {
              Text('平均首次响应：' + this.getAverageResponse())
                .fontSize(11)
                .fontColor('rgba(255,255,255,0.7)')

              Blank()

              Text('安全等级：' + this.getHealthGrade(this.getHealthScore()))
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor('rgba(255,255,255,0.85)')
            }
            .width('100%')
            .padding({ top: 10 })
            .border({ width: { top: 1 }, color: 'rgba(255,255,255,0.12)' })
          }
          .width('100%')
          .padding(18)
          .borderRadius(20)
          .backgroundColor(AppTheme.accentDark)
          .border({ width: 1, color: 'rgba(56,189,248,0.2)' })
          .shadow({ radius: 14, color: 'rgba(11,25,44,0.35)', offsetY: 6 })

          // 核心状态指标卡片
          Row({ space: 8 }) {
            Column() {
              Text('待确认')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.muted)
              Text(this.getStatistics().pendingEvents.toString())
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.accent)
                .margin({ top: 4 })
              Text('需要核实')
                .fontSize(9)
                .fontColor(AppTheme.muted)
                .margin({ top: 2 })
            }
            .layoutWeight(1)
            .padding(12)
            .borderRadius(14)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.line })
            .shadow({ radius: 6, color: AppTheme.cardShadow, offsetY: 2 })

            Column() {
              Text('处理中')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.muted)
              Text(this.getStatistics().processingEvents.toString())
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.amber)
                .margin({ top: 4 })
              Text('正在处置')
                .fontSize(9)
                .fontColor(AppTheme.muted)
                .margin({ top: 2 })
            }
            .layoutWeight(1)
            .padding(12)
            .borderRadius(14)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.line })
            .shadow({ radius: 6, color: AppTheme.cardShadow, offsetY: 2 })

            Column() {
              Text('待审核')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.muted)
              Text(this.getStatistics().reviewEvents.toString())
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.success)
                .margin({ top: 4 })
              Text('整改完毕')
                .fontSize(9)
                .fontColor(AppTheme.muted)
                .margin({ top: 2 })
            }
            .layoutWeight(1)
            .padding(12)
            .borderRadius(14)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.line })
            .shadow({ radius: 6, color: AppTheme.cardShadow, offsetY: 2 })
          }
          .width('100%')

          // 处置效率看板
          Column({ space: 10 }) {
            this.sectionHeader('处置效率与质量', '实时计算')

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
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.line })
          .shadow({ radius: 6, color: AppTheme.cardShadow, offsetY: 2 })

          // 各重点安防领域达标率
          Column({ space: 12 }) {
            this.sectionHeader('各重点安防领域达标率', '实时计算')

            ForEach(this.domains, (item: DomainItem) => {
              this.domainMeter(item)
            }, (item: DomainItem) => item.type)
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.line })
          .shadow({ radius: 6, color: AppTheme.cardShadow, offsetY: 2 })

          // 近 7 日事件趋势（按实际报告时间统计）
          Column() {
            this.sectionHeader('近 7 日事件办结趋势', '实时')

            Row() {
              ForEach(this.getLast7Days(), (item: BarItem) => {
                Column() {
                  Text(item.value.toString())
                    .fontSize(9)
                    .fontColor(AppTheme.muted)
                  Column() {
                    Column()
                      .width('100%')
                      .height(item.height)
                      .borderRadius({ topLeft: 4, topRight: 4 })
                      .backgroundColor(AppTheme.accent)
                  }
                  .width(14)
                  .height(56)
                  .borderRadius({ topLeft: 4, topRight: 4 })
                  .backgroundColor(AppTheme.surfaceMuted)
                  .justifyContent(FlexAlign.End)
                  .margin({ top: 4 })

                  Text(item.day)
                    .fontSize(9)
                    .fontColor(AppTheme.muted)
                    .margin({ top: 4 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
              }, (item: BarItem) => item.day)
            }
            .width('100%')
            .height(96)
            .alignItems(VerticalAlign.Bottom)
            .margin({ top: 10 })
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.line })
          .shadow({ radius: 6, color: AppTheme.cardShadow, offsetY: 2 })
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
    .backgroundColor(AppTheme.canvas)
    .opacity(this.pageReady ? 1 : 0)
    .translate({ y: this.pageReady ? 0 : 18 })
    .animation({ duration: 320, curve: Curve.EaseOut })
    .onAppear(() => {
      this.pageReady = true;
    })
  }
}
