import {
  SecurityEvent,
  OperationRecord,
  EventType,
  EventStatus,
  EventPriority
} from '../model/SecurityEvent';
import { EventService } from '../service/EventService';
import { AccountService } from '../service/AccountService';
import { AppPermission, PermissionService } from '../service/PermissionService';
import { User, UserRole } from '../model/User';

@Component
export struct EventDetailPage {
  pageStack: NavPathStack = new NavPathStack();

  @State private pageReady: boolean = false;
  @State private eventId: string = EventService.getSelectedEventId();
  @State private isConfirmed: boolean = false;
  @State private taskGenerated: boolean = false;
  @State private selectedAssigneeId: string = '';

  private can(permission: AppPermission): boolean {
    return PermissionService.can(AccountService.getCurrentUser(), permission);
  }

  private getSecurityUsers(): User[] {
    return AccountService.getSecurityUsers();
  }

  private canViewHistoryNote(): boolean {
    const user: User | null = AccountService.getCurrentUser();
    return user?.role === UserRole.ADMIN || user?.role === UserRole.SECURITY;
  }

  private isConfirmedProgress(): boolean {
    return this.getEvent().status !== EventStatus.PENDING;
  }

  private isAssignedProgress(): boolean {
    return this.getEvent().handler !== undefined && this.getEvent().handler !== '';
  }

  private isHandlingProgress(): boolean {
    const status: EventStatus = this.getEvent().status;
    return status === EventStatus.PROCESSING || status === EventStatus.REVIEW || status === EventStatus.COMPLETED;
  }

  private isHandledProgress(): boolean {
    const status: EventStatus = this.getEvent().status;
    return status === EventStatus.REVIEW || status === EventStatus.COMPLETED;
  }

  private getProgressLabel(): string {
    const status: EventStatus = this.getEvent().status;
    if (status === EventStatus.PENDING) {
      return '第 1 阶段 · 待核查';
    } else if (status === EventStatus.CONFIRMED) {
      return this.isAssignedProgress() ? '第 3 阶段 · 已指派' : '第 2 阶段 · 已确认';
    } else if (status === EventStatus.PROCESSING) {
      return '第 4 阶段 · 现场处置';
    } else if (status === EventStatus.REVIEW) {
      return '第 4 阶段 · 待审核';
    }
    return '第 5 阶段 · 已闭环';
  }

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

      if (this.getEvent().id === '') {
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
                Text(this.getProgressLabel())
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
                  .backgroundColor(this.isConfirmedProgress() ? '#2563EB' : '#E2E8F0')
                  .margin({ bottom: 18 })

                this.flowNode(2, '确认', this.isConfirmedProgress(),
                  this.getEvent().status === EventStatus.CONFIRMED && !this.isAssignedProgress())

                Row()
                  .height(2)
                  .layoutWeight(1)
                  .backgroundColor(this.isAssignedProgress() ? '#2563EB' : '#E2E8F0')
                  .margin({ bottom: 18 })

                this.flowNode(3, '指派', this.isAssignedProgress(),
                  this.getEvent().status === EventStatus.CONFIRMED && this.isAssignedProgress())

                Row()
                  .height(2)
                  .layoutWeight(1)
                  .backgroundColor(this.isHandlingProgress() ? '#2563EB' : '#E2E8F0')
                  .margin({ bottom: 18 })

                this.flowNode(4, '处置', this.isHandledProgress(),
                  this.getEvent().status === EventStatus.PROCESSING || this.getEvent().status === EventStatus.REVIEW)

                Row()
                  .height(2)
                  .layoutWeight(1)
                  .backgroundColor(this.getEvent().status === EventStatus.COMPLETED ? '#10B981' : '#E2E8F0')
                  .margin({ bottom: 18 })

                this.flowNode(5, '闭环', this.getEvent().status === EventStatus.COMPLETED,
                  this.getEvent().status === EventStatus.COMPLETED)
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

            if ((this.getEvent().attachmentPaths ?? []).length > 0) {
              Column({ space: 8 }) {
                Text('现场证据')
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#94A3B8')
                  .width('100%')
                Row({ space: 8 }) {
                  ForEach(this.getEvent().attachmentPaths ?? [], (path: string) => {
                    Image('file://' + path)
                      .width(82)
                      .height(82)
                      .borderRadius(12)
                      .objectFit(ImageFit.Cover)
                  }, (path: string) => path)
                }
                .width('100%')
              }
              .width('100%')
              .padding(14)
              .borderRadius(18)
              .backgroundColor(Color.White)
              .border({ width: 1, color: '#E2E8F0' })
            }

            if ((this.getEvent().history ?? []).length > 0) {
              Column({ space: 10 }) {
                Text('操作历史')
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#94A3B8')
                  .width('100%')
                ForEach(this.getEvent().history ?? [], (record: OperationRecord) => {
                  Row({ space: 10 }) {
                    Text('●')
                      .fontSize(10)
                      .fontColor('#2563EB')
                    Column({ space: 3 }) {
                      Text(record.action)
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#0F172A')
                      Text(record.operatorName + '  ·  ' + record.operationTime)
                        .fontSize(10)
                        .fontColor('#64748B')
                      if (this.canViewHistoryNote() && record.note !== undefined && record.note !== '') {
                        Text(record.note)
                          .fontSize(10)
                          .fontColor('#475569')
                          .padding({ top: 3 })
                      }
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                }, (record: OperationRecord) => record.id)
              }
              .width('100%')
              .padding(14)
              .borderRadius(18)
              .backgroundColor(Color.White)
              .border({ width: 1, color: '#E2E8F0' })
            }

            if (EventService.getCompletionFeedback(this.eventId) !== '') {
              Column({ space: 8 }) {
                Text('最终处理反馈')
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#047857')
                  .width('100%')
                Text(EventService.getCompletionFeedback(this.eventId))
                  .fontSize(12)
                  .fontColor('#065F46')
                  .lineHeight(20)
                  .width('100%')
              }
              .width('100%')
              .padding(14)
              .borderRadius(18)
              .backgroundColor('#ECFDF5')
              .border({ width: 1, color: '#A7F3D0' })
            }

            if (EventService.getCompletionFeedback(this.eventId) !== '') {
              Column({ space: 8 }) {
                Text('最终处理反馈')
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#059669')
                  .width('100%')
                Text(EventService.getCompletionFeedback(this.eventId))
                  .fontSize(12)
                  .fontColor('#14532D')
                  .lineHeight(20)
                  .width('100%')
              }
              .width('100%')
              .padding(14)
              .borderRadius(18)
              .backgroundColor('#ECFDF5')
              .border({ width: 1, color: '#A7F3D0' })
            }

            // 操作按钮
            if (
              this.getEvent().status === EventStatus.PENDING &&
              !this.isConfirmed &&
              this.can(AppPermission.CONFIRM_EVENT)
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
              !this.taskGenerated &&
              this.can(AppPermission.DISPATCH_TASK)
            ) {
              Column({ space: 8 }) {
                Text('选择处置人员')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#475569')
                  .width('100%')

                Row({ space: 8 }) {
                  ForEach(this.getSecurityUsers(), (user: User) => {
                    Text(user.name)
                      .fontSize(11)
                      .fontWeight(this.selectedAssigneeId === user.id ? FontWeight.Bold : FontWeight.Normal)
                      .fontColor(this.selectedAssigneeId === user.id ? Color.White : '#475569')
                      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                      .borderRadius(12)
                      .backgroundColor(this.selectedAssigneeId === user.id ? '#2563EB' : '#F1F5F9')
                      .onClick(() => {
                        this.selectedAssigneeId = user.id;
                      })
                  }, (user: User) => user.id)
                }
                .width('100%')

                if (this.getSecurityUsers().length === 0) {
                  Text('暂无可用安保账号，请先配置负责人')
                    .fontSize(11)
                    .fontColor('#B45309')
                    .width('100%')
                }

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
                .enabled(this.selectedAssigneeId !== '')
                .opacity(this.selectedAssigneeId === '' ? 0.5 : 1)
                .onClick(() => {
                  if (EventService.createTaskFromEvent(this.eventId, this.selectedAssigneeId)) {
                    this.taskGenerated = true;
                  }
                })
              }
              .width('100%')
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
    .opacity(this.pageReady ? 1 : 0)
    .translate({ y: this.pageReady ? 0 : 18 })
    .animation({ duration: 320, curve: Curve.EaseOut })
    .onAppear(() => {
      this.pageReady = true;
      this.taskGenerated = EventService.getTaskByEventId(this.eventId) !== undefined;
    })
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
