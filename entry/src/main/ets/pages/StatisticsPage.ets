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
  completed: number;
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

  private getStatistics(): SafetyStatisticsSnapshot {
    return SafetyStatisticsService.createSnapshot(this.events, this.tasks);
  }

  private getAverageResponse(): string {
    return SafetyStatisticsService.formatMinutes(this.getStatistics().averageFirstResponseMinutes);
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
        completed: this.events.filter((event: SecurityEvent) =>
          (event.history ?? []).some((record) => record.toStatus === EventStatus.COMPLETED &&
            this.isSameDay(record.operationTime, day))
        ).length,
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

  private trendContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private ringContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private chartTypes: EventType[] = [EventType.FIRE, EventType.ELECTRIC, EventType.FACILITY, EventType.CAMPUS, EventType.OTHER];
  private chartColors: string[] = ['#2477FF', '#50A8FF', '#49CDD9', '#7DDDCB', '#B5C6E7'];

  private typeCount(type: EventType): number {
    return this.events.filter((event: SecurityEvent) => event.type === type).length;
  }

  private drawTrend(): void {
    const ctx: CanvasRenderingContext2D = this.trendContext;
    const w: number = ctx.width;
    const h: number = ctx.height;
    ctx.clearRect(0, 0, w, h);
    const items: BarItem[] = this.getLast7Days();
    const max: number = Math.max(1, ...items.map((item: BarItem) => Math.max(item.value, item.completed)));
    ctx.font = '10px sans-serif';
    ctx.fillStyle = AppTheme.muted;
    for (let i: number = 0; i <= 4; i++) {
      const y: number = 12 + (h - 38) * i / 4;
      ctx.beginPath(); ctx.strokeStyle = AppTheme.line; ctx.lineWidth = 1;
      ctx.moveTo(28, y); ctx.lineTo(w - 8, y); ctx.stroke();
      ctx.fillText((max * (4 - i) / 4).toFixed(max < 4 ? 1 : 0), 0, y + 3);
    }
    ctx.beginPath();
    items.forEach((item: BarItem, index: number) => {
      const x: number = 28 + (w - 40) * index / 6;
      const y: number = h - 26 - item.value / max * (h - 38);
      if (index === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    });
    ctx.strokeStyle = '#2477FF'; ctx.lineWidth = 2; ctx.stroke();
    ctx.beginPath();
    items.forEach((item: BarItem, index: number) => {
      const x: number = 28 + (w - 40) * index / 6;
      const y: number = h - 26 - item.completed / max * (h - 38);
      if (index === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    });
    ctx.strokeStyle = '#20BEBC'; ctx.lineWidth = 2; ctx.stroke();
    items.forEach((item: BarItem, index: number) => {
      const x: number = 28 + (w - 40) * index / 6;
      const y: number = h - 26 - item.value / max * (h - 38);
      ctx.beginPath(); ctx.arc(x, y, 3, 0, Math.PI * 2); ctx.fillStyle = '#2477FF'; ctx.fill();
      ctx.fillStyle = AppTheme.muted; ctx.fillText(item.day, x - 12, h - 7);
    });
  }

  private drawRing(): void {
    const ctx: CanvasRenderingContext2D = this.ringContext;
    ctx.clearRect(0, 0, ctx.width, ctx.height);
    const r: number = Math.min(ctx.width, ctx.height) / 2 - 13;
    let angle: number = -Math.PI / 2;
    ctx.lineWidth = 19;
    ctx.beginPath(); ctx.strokeStyle = AppTheme.line;
    ctx.arc(ctx.width / 2, ctx.height / 2, r, 0, Math.PI * 2); ctx.stroke();
    this.chartTypes.forEach((type: EventType, index: number) => {
      const sweep: number = this.events.length === 0 ? 0 : this.typeCount(type) / this.events.length * Math.PI * 2;
      if (sweep > 0) {
        ctx.beginPath(); ctx.strokeStyle = this.chartColors[index];
        ctx.arc(ctx.width / 2, ctx.height / 2, r, angle, angle + sweep); ctx.stroke();
        angle += sweep;
      }
    });
  }

  @Builder
  overviewMetric(label: string, value: string, note: string) {
    Column({ space: 7 }) {
      Text(label).fontSize(11).fontColor(AppTheme.muted)
      Text(value).fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink).maxLines(1).minFontSize(14).maxFontSize(23)
      Text(note).fontSize(10).fontColor(AppTheme.success)
    }.layoutWeight(1).alignItems(HorizontalAlign.Start).padding(12).backgroundColor(AppTheme.surface).borderRadius(12)
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(30).width(44).height(48).onClick(() => { this.pageStack.pop(); })
        Text('数据统计').fontSize(17).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink).layoutWeight(1).textAlign(TextAlign.Center)
        Text('刷新').fontSize(12).fontColor(AppTheme.accent).width(44).textAlign(TextAlign.End)
          .onClick(() => { this.refreshData(); this.drawTrend(); this.drawRing(); })
      }.height(52).width('100%').padding({ left: 16, right: 16 })
      Scroll() {
        Column({ space: 16 }) {
          Row({ space: 8 }) {
            this.overviewMetric('事件总数', this.events.length.toString(), '可见事件')
            this.overviewMetric('完成率', this.events.length === 0 ? '—' : Math.round(this.getStatistics().completedEvents / this.events.length * 100) + '%', '事件办结')
            this.overviewMetric('平均响应', this.getAverageResponse(), '首次响应')
          }.width('100%')
          Column({ space: 12 }) {
            this.sectionHeader('事件趋势', '近 7 天')
            Row({ space: 6 }) {
              Blank()
              Circle().width(6).height(6).fill('#2477FF')
              Text('上报量').fontSize(10).fontColor(AppTheme.muted)
              Circle().width(6).height(6).fill('#20BEBC').margin({ left: 10 })
              Text('完成量').fontSize(10).fontColor(AppTheme.muted)
            }.width('100%')
            Canvas(this.trendContext).width('100%').height(155)
              .onReady(() => this.drawTrend()).onAreaChange(() => this.drawTrend())
          }.width('100%').padding(14).backgroundColor(AppTheme.surface).borderRadius(12)
          Column({ space: 14 }) {
            this.sectionHeader('事件类型分布', '')
            Row({ space: 18 }) {
              Stack() {
                Canvas(this.ringContext).width(142).height(142).onReady(() => this.drawRing())
                Column({ space: 3 }) {
                  Text(this.events.length.toString()).fontSize(26).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
                  Text('总事件数').fontSize(10).fontColor(AppTheme.muted)
                }
              }.width(142).height(142)
              Column({ space: 13 }) {
                ForEach(this.chartTypes, (type: EventType, index: number) => {
                  Row({ space: 6 }) {
                    Circle().width(7).height(7).fill(this.chartColors[index])
                    Text(type).fontSize(11).fontColor(AppTheme.inkSoft).layoutWeight(1)
                    Text(this.events.length === 0 ? '—' : Math.round(this.typeCount(type) / this.events.length * 100) + '%').fontSize(11).fontColor(AppTheme.muted)
                  }.width('100%')
                }, (type: EventType) => type)
              }.layoutWeight(1)
            }.width('100%')
          }.width('100%').padding(14).backgroundColor(AppTheme.surface).borderRadius(12)
          Column({ space: 12 }) {
            this.sectionHeader('应急联系方式', '管理 ›')
            Row({ space: 12 }) {
              Image($r('app.media.ic_phone')).width(30).height(30).fillColor(AppTheme.accent)
              Column({ space: 4 }) {
                Text('校园应急联络').fontSize(14).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
                Text('查看或配置联系电话').fontSize(11).fontColor(AppTheme.muted)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text('›').fontSize(22).fontColor(AppTheme.muted)
            }.width('100%')
          }.width('100%').padding(14).backgroundColor(AppTheme.surface).borderRadius(12)
            .onClick(() => { this.pageStack.pushPath({ name: 'EmergencyContactPage' }); })
          Button('一键求助  ·  应急联络').width('100%').height(54).fontSize(15).fontColor(Color.White).borderRadius(16)
            .linearGradient({ angle: 120, colors: [['#479EFF', 0], ['#1451FF', 1]] })
            .onClick(() => { this.pageStack.pushPath({ name: 'EmergencyContactPage' }); })
        }.width('100%').padding({ left: 14, right: 14, bottom: 20 })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(AppTheme.canvas)
      .onAppear(() => this.refreshData())
  }
}
