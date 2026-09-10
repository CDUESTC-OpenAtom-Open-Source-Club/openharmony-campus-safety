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
import { AppTheme } from '../common/AppTheme';

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
      Text(done ? '' : index.toString())
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(done ? Color.White : active ? Color.White : AppTheme.muted)
    }
    .width(26)
    .height(26)
    .borderRadius(13)
    .backgroundColor(done ? AppTheme.success : active ? AppTheme.accent : AppTheme.surfaceMuted)
    .border({ width: 1, color: done ? AppTheme.success : active ? AppTheme.accent : AppTheme.line })
    .justifyContent(FlexAlign.Center)
    .shadow(active ? { radius: 8, color: AppTheme.glowBlue, offsetY: 2 } : { radius: 0, color: Color.Transparent })

    Text(label)
      .fontSize(10)
      .fontWeight(FontWeight.Medium)
      .fontColor(done || active ? AppTheme.accent : AppTheme.muted)
      .margin({ top: 6 })
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
          Text('事件处置详情')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ink)

          Text('工单流水号：' + this.eventId)
            .fontSize(10)
            .fontColor(AppTheme.muted)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 14, right: 16, top: 14, bottom: 12 })
      .backgroundColor(AppTheme.surface)
      .border({ width: { bottom: 1 }, color: AppTheme.line })

      if (this.getEvent().id === '') {
        Column({ space: 10 }) {
          Row() {
            Image($r('app.media.ic_shield'))
              .width(32).height(32).fillColor(AppTheme.muted)
          }
          .width(60).height(60).borderRadius(30).backgroundColor(AppTheme.surfaceMuted)
          .justifyContent(FlexAlign.Center)

          Text('未检索到对应安全事件')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.inkSoft)
          Text('该工单不存在或已由数据中心归档')
            .fontSize(11)
            .fontColor(AppTheme.muted)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            // 全流程 5 节点流转轴卡片
            Column() {
              Row() {
                Row({ space: 6 }) {
                  Row().width(4).height(12).borderRadius(2).backgroundColor(AppTheme.accent)
                  Text('全生命周期流转进度')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.ink)
                }
                Blank()
                Text(this.getProgressLabel())
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.accent)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(6)
                  .backgroundColor(AppTheme.accentSoft)
              }
              .width('100%')
              .margin({ bottom: 16 })

              Row() {
                this.flowNode(1, '上报', true, true)

                Row()
                  .height(2)
                  .layoutWeight(1)
                  .backgroundColor(this.isConfirmedProgress() ? AppTheme.accent : AppTheme.line)
                  .margin({ bottom: 20 })

                this.flowNode(2, '确认', this.isConfirmedProgress(),
                  this.getEvent().status === EventStatus.CONFIRMED && !this.isAssignedProgress())

                Row()
                  .height(2)
                  .layoutWeight(1)
                  .backgroundColor(this.isAssignedProgress() ? AppTheme.accent : AppTheme.line)
                  .margin({ bottom: 20 })

                this.flowNode(3, '指派', this.isAssignedProgress(),
                  this.getEvent().status === EventStatus.CONFIRMED && this.isAssignedProgress())

                Row()
                  .height(2)
                  .layoutWeight(1)
                  .backgroundColor(this.isHandlingProgress() ? AppTheme.accent : AppTheme.line)
                  .margin({ bottom: 20 })

                this.flowNode(4, '处置', this.isHandledProgress(),
                  this.getEvent().status === EventStatus.PROCESSING || this.getEvent().status === EventStatus.REVIEW)

                Row()
                  .height(2)
                  .layoutWeight(1)
                  .backgroundColor(this.getEvent().status === EventStatus.COMPLETED ? AppTheme.success : AppTheme.line)
                  .margin({ bottom: 20 })

                this.flowNode(5, '闭环', this.getEvent().status === EventStatus.COMPLETED,
                  this.getEvent().status === EventStatus.COMPLETED)
              }
              .width('100%')
              .alignItems(VerticalAlign.Bottom)
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.line })
            .shadow({ radius: 8, color: AppTheme.cardShadow, offsetY: 2 })

            // 头部详情卡片（科技蓝黑底色）
            Column() {
              Row() {
                Text(this.getEvent().type)
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#38BDF8')
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(4)
                  .backgroundColor('rgba(56,189,248,0.18)')

                Blank()

                Text('优先级 · ' + this.getEvent().priority)
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FCD34D')
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(4)
                  .backgroundColor('rgba(245,158,11,0.18)')
              }
              .width('100%')
              .margin({ bottom: 10 })

              Text(this.getEvent().title)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .width('100%')

              Text('发生区域 · ' + this.getEvent().location)
                .fontSize(11)
                .fontColor('rgba(255,255,255,0.7)')
                .margin({ top: 6 })
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor(AppTheme.accentDark)
            .border({ width: 1, color: 'rgba(56,189,248,0.2)' })
            .shadow({ radius: 10, color: 'rgba(11,25,44,0.16)', offsetY: 3 })

            // 核心参数卡片
            Column({ space: 8 }) {
              Text('工单核心属性')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.muted)
                .width('100%')

              Row() {
                Text('提报人员')
                  .fontSize(12)
                  .fontColor(AppTheme.muted)
                  .layoutWeight(1)
                Text(this.getEvent().reporter)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.ink)
              }
              .width('100%')

              Row() {
                Text('登记时间')
                  .fontSize(12)
                  .fontColor(AppTheme.muted)
                  .layoutWeight(1)
                Text(this.getEvent().reportTime)
                  .fontSize(12)
                  .fontColor(AppTheme.inkSoft)
              }
              .width('100%')

              Row() {
                Text('流转状态')
                  .fontSize(12)
                  .fontColor(AppTheme.muted)
                  .layoutWeight(1)
                Text(this.isConfirmed ? EventStatus.CONFIRMED : this.getEvent().status)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
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

            // 现场隐患描述
            Column({ space: 6 }) {
              Text('现场详细描述')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.muted)
                .width('100%')

              Text(this.getEvent().description)
                .fontSize(12)
                .fontColor(AppTheme.ink)
                .lineHeight(19)
                .width('100%')
                .padding(12)
                .borderRadius(10)
                .backgroundColor(AppTheme.surfaceMuted)
            }
            .width('100%')
            .padding(14)
            .borderRadius(16)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.line })

            // 现场附件证据
            if ((this.getEvent().attachmentPaths ?? []).length > 0) {
              Column({ space: 8 }) {
                Text('现场影像证据')
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.muted)
                  .width('100%')
                Row({ space: 8 }) {
                  ForEach(this.getEvent().attachmentPaths ?? [], (path: string) => {
                    Image('file://' + path)
                      .width(80)
                      .height(80)
                      .borderRadius(10)
                      .objectFit(ImageFit.Cover)
                      .border({ width: 1, color: AppTheme.line })
                  }, (path: string) => path)
                }
                .width('100%')
              }
              .width('100%')
              .padding(14)
              .borderRadius(16)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.line })
            }

            // 操作审计历史
            if ((this.getEvent().history ?? []).length > 0) {
              Column({ space: 10 }) {
                Text('协同流转审计日志')
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.muted)
                  .width('100%')
                ForEach(this.getEvent().history ?? [], (record: OperationRecord) => {
                  Row({ space: 8 }) {
                    Row().width(6).height(6).borderRadius(3).backgroundColor(AppTheme.accent).margin({ top: 5 })
                    Column({ space: 2 }) {
                      Text(record.action)
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(AppTheme.ink)
                      Text(record.operatorName + '  ·  ' + record.operationTime)
                        .fontSize(10)
                        .fontColor(AppTheme.muted)
                      if (this.canViewHistoryNote() && record.note !== undefined && record.note !== '') {
                        Text(record.note)
                          .fontSize(11)
                          .fontColor(AppTheme.inkSoft)
                          .padding({ top: 2 })
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
              .borderRadius(16)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.line })
            }

            // 最终处理反馈结果（单次展示，美化风格）
            if (EventService.getCompletionFeedback(this.eventId) !== '') {
              Column({ space: 6 }) {
                Row({ space: 6 }) {
                  Row().width(4).height(12).borderRadius(2).backgroundColor(AppTheme.success)
                  Text('现场处置闭环反馈')
                    .fontSize(11)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.success)
                }
                .width('100%')

                Text(EventService.getCompletionFeedback(this.eventId))
                  .fontSize(12)
                  .fontColor(AppTheme.ink)
                  .lineHeight(19)
                  .width('100%')
              }
              .width('100%')
              .padding(14)
              .borderRadius(16)
              .backgroundColor(AppTheme.successSoft)
              .border({ width: 1, color: '#A7F3D0' })
            }

            // 操作按钮群
            if (
              this.getEvent().status === EventStatus.PENDING &&
              !this.isConfirmed &&
              this.can(AppPermission.CONFIRM_EVENT)
            ) {
              Button('确认现场情况属实并立案')
                .width('100%')
                .height(44)
                .borderRadius(10)
                .backgroundColor(AppTheme.accent)
                .fontColor(Color.White)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .shadow({ radius: 8, color: AppTheme.glowBlue, offsetY: 2 })
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
              Column({ space: 10 }) {
                Text('选择现场处置负责人')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.inkSoft)
                  .width('100%')

                Row({ space: 8 }) {
                  ForEach(this.getSecurityUsers(), (user: User) => {
                    Text(user.name)
                      .fontSize(11)
                      .fontWeight(this.selectedAssigneeId === user.id ? FontWeight.Bold : FontWeight.Normal)
                      .fontColor(this.selectedAssigneeId === user.id ? Color.White : AppTheme.inkSoft)
                      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                      .borderRadius(8)
                      .backgroundColor(this.selectedAssigneeId === user.id ? AppTheme.accent : AppTheme.surfaceMuted)
                      .onClick(() => {
                        this.selectedAssigneeId = user.id;
                      })
                  }, (user: User) => user.id)
                }
                .width('100%')

                if (this.getSecurityUsers().length === 0) {
                  Text('暂无可用安保账号，请先在账号治理中配置负责人')
                    .fontSize(10)
                    .fontColor(AppTheme.amber)
                    .width('100%')
                }

                Button('生成并下发处置工单')
                  .width('100%')
                  .height(44)
                  .borderRadius(10)
                  .backgroundColor(AppTheme.cyan)
                  .fontColor(Color.White)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .shadow({ radius: 8, color: 'rgba(2,132,199,0.25)', offsetY: 2 })
                  .margin({ top: 6 })
                  .enabled(this.selectedAssigneeId !== '')
                  .opacity(this.selectedAssigneeId === '' ? 0.5 : 1)
                  .onClick(() => {
                    if (EventService.createTaskFromEvent(this.eventId, this.selectedAssigneeId)) {
                      this.taskGenerated = true;
                    }
                  })
              }
              .width('100%')
              .padding(14)
              .borderRadius(16)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.line })
            }

            if (this.taskGenerated) {
              Column({ space: 8 }) {
                Text('处置工单已下发，维保及安保团队已就绪')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.success)
                  .width('100%')
                  .textAlign(TextAlign.Center)

                Button('前往处置任务看板')
                  .width('100%')
                  .height(40)
                  .borderRadius(8)
                  .backgroundColor(AppTheme.success)
                  .fontColor(Color.White)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .onClick(() => {
                    this.pageStack.pushPath({ name: 'TaskPage' });
                  })
              }
              .width('100%')
              .padding(14)
              .borderRadius(14)
              .backgroundColor(AppTheme.successSoft)
              .border({ width: 1, color: '#A7F3D0' })
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
    .backgroundColor(AppTheme.canvas)
    .opacity(this.pageReady ? 1 : 0)
    .translate({ y: this.pageReady ? 0 : 12 })
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
