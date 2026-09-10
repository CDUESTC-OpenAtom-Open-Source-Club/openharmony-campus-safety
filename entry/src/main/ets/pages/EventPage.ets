import {
  SecurityEvent,
  EventPriority,
  EventStatus
} from '../model/SecurityEvent';
import { EventService } from '../service/EventService';
import { AccountService } from '../service/AccountService';
import { User, UserRole } from '../model/User';
import { AppTheme } from '../common/AppTheme';

interface PriorityFilter {
  id: string;
  label: string;
}

@Component
export struct EventPage {
  pageStack: NavPathStack = new NavPathStack();

  @State private pageReady: boolean = false;
  @State private events: SecurityEvent[] = EventService.getAllEvents();
  @State private searchQuery: string = '';
  @State private filterPriority: string = 'ALL';
  @State private filterStatus: string = 'ALL';

  private filters: PriorityFilter[] = [
    { id: 'ALL', label: '全部' },
    { id: '紧急', label: '紧急' },
    { id: '高', label: '较高' },
    { id: '中', label: '中等' },
    { id: '低', label: '普通' }
  ];

  private statusFilters: PriorityFilter[] = [
    { id: 'ALL', label: '全部状态' },
    { id: '待确认', label: '待确认' },
    { id: '已确认', label: '已确认' },
    { id: '处理中', label: '处理中' },
    { id: '待审核', label: '待审核' },
    { id: '已完成', label: '已完成' }
  ];

  private isPersonalView(): boolean {
    const user: User | null = AccountService.getCurrentUser();
    return user?.role === UserRole.STUDENT || user?.role === UserRole.TEACHER;
  }

  private getPriorityBg(priority: EventPriority): string {
    if (priority === EventPriority.URGENT) {
      return AppTheme.dangerSoft;
    } else if (priority === EventPriority.HIGH) {
      return AppTheme.amberSoft;
    } else if (priority === EventPriority.MEDIUM) {
      return AppTheme.infoSoft;
    }
    return AppTheme.surfaceMuted;
  }

  private getPriorityColor(priority: EventPriority): string {
    if (priority === EventPriority.URGENT) {
      return AppTheme.danger;
    } else if (priority === EventPriority.HIGH) {
      return AppTheme.amber;
    } else if (priority === EventPriority.MEDIUM) {
      return AppTheme.info;
    }
    return AppTheme.muted;
  }

  private getStatusColor(status: EventStatus): string {
    if (status === EventStatus.PENDING) {
      return AppTheme.amber;
    } else if (status === EventStatus.CONFIRMED) {
      return AppTheme.info;
    } else if (status === EventStatus.PROCESSING) {
      return AppTheme.accent;
    } else if (status === EventStatus.REVIEW) {
      return AppTheme.accentDark;
    } else if (status === EventStatus.COMPLETED) {
      return AppTheme.success;
    }
    return AppTheme.muted;
  }

  private getFilteredEvents(): SecurityEvent[] {
    const query: string = this.searchQuery.trim().toLowerCase();
    return this.events.filter((event: SecurityEvent) => {
      const matchPriority: boolean =
        this.filterPriority === 'ALL' || event.priority === this.filterPriority;
      const matchStatus: boolean =
        this.filterStatus === 'ALL' || event.status === this.filterStatus;
      const matchSearch: boolean =
        query === '' ||
        event.title.toLowerCase().includes(query) ||
        event.location.toLowerCase().includes(query) ||
        event.id.toLowerCase().includes(query);
      return matchPriority && matchStatus && matchSearch;
    });
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
          Text(this.isPersonalView() ? '我的上报记录' : '安全事件流转中心')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ink)

          Text(this.isPersonalView() ? '全流程闭环追踪与现场核验' : '校园安全隐患汇聚、研判与派单')
            .fontSize(10)
            .fontColor(AppTheme.muted)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Row({ space: 4 }) {
          Row().width(6).height(6).borderRadius(3).backgroundColor(AppTheme.accent)
          Text(this.getFilteredEvents().length.toString() + ' 项记录')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.accent)
        }
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .borderRadius(12)
        .backgroundColor(AppTheme.accentSoft)
        .border({ width: 1, color: AppTheme.line })
      }
      .width('100%')
      .padding({ left: 14, right: 16, top: 14, bottom: 12 })
      .backgroundColor(AppTheme.surface)
      .border({ width: { bottom: 1 }, color: AppTheme.line })

      // 搜索与双层分类过滤条
      Column({ space: 10 }) {
        TextInput({
          placeholder: '输入事件名称、发生地点或工单编号...',
          text: this.searchQuery
        })
          .width('100%')
          .height(40)
          .fontSize(12)
          .borderRadius(10)
          .backgroundColor(AppTheme.surfaceMuted)
          .border({ width: 1, color: AppTheme.line })
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.searchQuery = value;
          })

        // 优先级筛选
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.filters, (item: PriorityFilter) => {
              Text(item.label)
                .fontSize(11)
                .fontWeight(this.filterPriority === item.id ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.filterPriority === item.id ? Color.White : AppTheme.inkSoft)
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .borderRadius(8)
                .backgroundColor(this.filterPriority === item.id ? AppTheme.accent : AppTheme.surfaceMuted)
                .onClick(() => {
                  this.filterPriority = item.id;
                })
            }, (item: PriorityFilter) => item.id)
          }
          .width('100%')
        }
        .width('100%')
        .scrollBar(BarState.Off)
        .scrollable(ScrollDirection.Horizontal)

        // 状态流转筛选
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.statusFilters, (item: PriorityFilter) => {
              Text(item.label)
                .fontSize(11)
                .fontWeight(this.filterStatus === item.id ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.filterStatus === item.id ? Color.White : AppTheme.muted)
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .borderRadius(8)
                .backgroundColor(this.filterStatus === item.id ? AppTheme.accentDark : AppTheme.surfaceMuted)
                .onClick(() => {
                  this.filterStatus = item.id;
                })
            }, (item: PriorityFilter) => item.id)
          }
          .width('100%')
        }
        .width('100%')
        .scrollBar(BarState.Off)
        .scrollable(ScrollDirection.Horizontal)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(AppTheme.surface)
      .border({ width: { bottom: 1 }, color: AppTheme.line })

      // 事件列表容器
      if (this.getFilteredEvents().length === 0) {
        Column({ space: 8 }) {
          Row() {
            Image($r('app.media.ic_shield'))
              .width(28).height(28).fillColor(AppTheme.muted)
          }
          .width(56).height(56).borderRadius(28).backgroundColor(AppTheme.surfaceMuted)
          .justifyContent(FlexAlign.Center).margin({ bottom: 4 })

          Text(this.isPersonalView() ? '暂无匹配的上报记录' : '未检索到符合条件的安全事件')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.inkSoft)
          Text(this.events.length === 0 && this.isPersonalView() ? '提交现场隐患后，可在此实时跟踪处置进展' : '您可以尝试更换关键词或重置筛选维度')
            .fontSize(11)
            .fontColor(AppTheme.muted)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.getFilteredEvents(), (event: SecurityEvent) => {
              Column() {
                Row() {
                  Text(event.id)
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.accent)
                    .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                    .borderRadius(4)
                    .backgroundColor(AppTheme.accentSoft)

                  Text(event.title)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.ink)
                    .margin({ left: 8 })
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(event.priority)
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.getPriorityColor(event.priority))
                    .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                    .borderRadius(4)
                    .backgroundColor(this.getPriorityBg(event.priority))
                }
                .width('100%')
                .margin({ bottom: 8 })

                Column({ space: 5 }) {
                  Row() {
                    Text('发生地点')
                      .fontSize(10)
                      .fontColor(AppTheme.muted)
                      .width(60)
                    Text(event.location)
                      .fontSize(11)
                      .fontColor(AppTheme.inkSoft)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                  }
                  .width('100%')

                  Row() {
                    Text('流转状态')
                      .fontSize(10)
                      .fontColor(AppTheme.muted)
                      .width(60)
                    Text(event.status)
                      .fontSize(11)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.getStatusColor(event.status))
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(10)
                .borderRadius(10)
                .backgroundColor(AppTheme.surfaceMuted)
                .margin({ bottom: 8 })

                Text(event.description)
                  .fontSize(12)
                  .fontColor(AppTheme.inkSoft)
                  .lineHeight(18)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .margin({ bottom: 8 })

                Row() {
                  Text('提报人 · ' + event.reporter + '  ' + event.reportTime)
                    .fontSize(10)
                    .fontColor(AppTheme.muted)
                  Blank()
                  Text('查看详情 ›')
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.accent)
                }
                .width('100%')
              }
              .width('100%')
              .padding(14)
              .borderRadius(16)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.line })
              .shadow({ radius: 8, color: AppTheme.cardShadow, offsetY: 2 })
              .onClick(() => {
                EventService.setSelectedEventId(event.id);
                this.pageStack.pushPath({ name: 'EventDetailPage' });
              })
            }, (event: SecurityEvent) => event.id)
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
    .backgroundColor(AppTheme.canvas)
    .opacity(this.pageReady ? 1 : 0)
    .translate({ y: this.pageReady ? 0 : 12 })
    .animation({ duration: 320, curve: Curve.EaseOut })
    .onAppear(() => {
      this.events = EventService.getAllEvents().slice();
      this.pageReady = true;
    })
  }
}
