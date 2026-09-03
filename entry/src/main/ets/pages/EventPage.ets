import {
  SecurityEvent,
  EventPriority,
  EventStatus
} from '../model/SecurityEvent';
import { EventService } from '../service/EventService';

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

  private filters: PriorityFilter[] = [
    { id: 'ALL', label: '全部' },
    { id: '紧急', label: '紧急' },
    { id: '高', label: '较高' },
    { id: '中', label: '中等' },
    { id: '低', label: '普通' }
  ];

  private getPriorityBg(priority: EventPriority): string {
    if (priority === EventPriority.URGENT) {
      return '#FEF2F2';
    } else if (priority === EventPriority.HIGH) {
      return '#FFF7ED';
    } else if (priority === EventPriority.MEDIUM) {
      return '#EFF6FF';
    }
    return '#F1F5F9';
  }

  private getPriorityColor(priority: EventPriority): string {
    if (priority === EventPriority.URGENT) {
      return '#DC2626';
    } else if (priority === EventPriority.HIGH) {
      return '#EA580C';
    } else if (priority === EventPriority.MEDIUM) {
      return '#2563EB';
    }
    return '#64748B';
  }

  private getStatusColor(status: EventStatus): string {
    if (status === EventStatus.PENDING) {
      return '#B45309';
    } else if (status === EventStatus.CONFIRMED) {
      return '#2563EB';
    } else if (status === EventStatus.PROCESSING) {
      return '#4F46E5';
    } else if (status === EventStatus.COMPLETED) {
      return '#059669';
    }
    return '#64748B';
  }

  private getFilteredEvents(): SecurityEvent[] {
    const query: string = this.searchQuery.trim().toLowerCase();
    return this.events.filter((event: SecurityEvent) => {
      const matchPriority: boolean =
        this.filterPriority === 'ALL' || event.priority === this.filterPriority;
      const matchSearch: boolean =
        query === '' ||
        event.title.toLowerCase().includes(query) ||
        event.location.toLowerCase().includes(query) ||
        event.id.toLowerCase().includes(query);
      return matchPriority && matchSearch;
    });
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
          Text('安全事件')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Text('校园安全隐患汇聚与流转')
            .fontSize(10)
            .fontColor('#94A3B8')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(this.getFilteredEvents().length.toString() + ' 项')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2563EB')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(12)
          .backgroundColor('#EFF6FF')
          .border({ width: 1, color: '#DBEAFE' })
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 14, bottom: 10 })
      .backgroundColor(Color.White)

      // 搜索与筛选
      Column({ space: 10 }) {
        TextInput({
          placeholder: '搜索事件名称、地点或编号...',
          text: this.searchQuery
        })
          .width('100%')
          .height(40)
          .fontSize(12)
          .borderRadius(12)
          .backgroundColor('#F1F5F9')
          .border({ width: 1, color: '#E2E8F0' })
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.searchQuery = value;
          })

        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.filters, (item: PriorityFilter) => {
              Text(item.label)
                .fontSize(11)
                .fontWeight(this.filterPriority === item.id ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.filterPriority === item.id ? Color.White : '#64748B')
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(14)
                .backgroundColor(this.filterPriority === item.id ? '#2563EB' : '#F1F5F9')
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
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 12 })
      .backgroundColor(Color.White)
      .border({ width: { bottom: 1 }, color: '#E2E8F0' })

      // 事件列表
      if (this.getFilteredEvents().length === 0) {
        Column({ space: 8 }) {
          Text('◆')
            .fontSize(34)
            .fontColor('#CBD5E1')
          Text('未找到符合条件的安全事件')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#475569')
          Text('您可以调整检索词或切换优先级分类')
            .fontSize(12)
            .fontColor('#94A3B8')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.getFilteredEvents(), (event: SecurityEvent) => {
              Column() {
                Row() {
                  Text(event.id)
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#64748B')
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(8)
                    .backgroundColor('#F1F5F9')

                  Text(event.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#0F172A')
                    .margin({ left: 8 })
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(event.priority)
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.getPriorityColor(event.priority))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(10)
                    .backgroundColor(this.getPriorityBg(event.priority))
                }
                .width('100%')
                .margin({ bottom: 10 })

                Column({ space: 6 }) {
                  Row() {
                    Text('发生地点')
                      .fontSize(11)
                      .fontColor('#94A3B8')
                      .layoutWeight(1)
                    Text(event.location)
                      .fontSize(11)
                      .fontColor('#334155')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                  }
                  .width('100%')

                  Row() {
                    Text('流转状态')
                      .fontSize(11)
                      .fontColor('#94A3B8')
                      .layoutWeight(1)
                    Text(event.status)
                      .fontSize(11)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.getStatusColor(event.status))
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(10)
                .borderRadius(12)
                .backgroundColor('#F8FAFC')
                .margin({ bottom: 10 })

                Text(event.description)
                  .fontSize(12)
                  .fontColor('#475569')
                  .lineHeight(18)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .margin({ bottom: 10 })

                Row() {
                  Text(event.reporter)
                    .fontSize(11)
                    .fontColor('#94A3B8')
                  Blank()
                  Text('处置跟踪 ›')
                    .fontSize(11)
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
              .shadow({ radius: 10, color: 'rgba(15,23,42,0.04)', offsetY: 2 })
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
    .backgroundColor('#F8FAFC')
    .opacity(this.pageReady ? 1 : 0)
    .translate({ y: this.pageReady ? 0 : 18 })
    .animation({ duration: 320, curve: Curve.EaseOut })
    .onAppear(() => {
      this.pageReady = true;
    })
  }
}
