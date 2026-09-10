import {
  Task,
  TaskStatus
} from '../model/Task';
import {
  EventService
} from '../service/EventService';
import { AccountService } from '../service/AccountService';
import { AppPermission, PermissionService } from '../service/PermissionService';
import { AttachmentService } from '../service/AttachmentService';
import { User, UserRole } from '../model/User';
import { SecurityEvent } from '../model/SecurityEvent';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppTheme } from '../common/AppTheme';

interface TaskFilter {
  id: string;
  label: string;
}

@Component
export struct TaskPage {
  pageStack: NavPathStack = new NavPathStack();

  @State private pageReady: boolean = false;
  @State private tasks: Task[] = EventService.getAllTasks();
  @State private filterTab: string = 'ALL';
  @State private expandedTaskId: string = '';
  @State private processingTaskId: string = '';
  @State private resultText: string = '';
  @State private reviewTaskId: string = '';
  @State private rejectionReason: string = '';

  private getFilters(): TaskFilter[] {
    if (this.isAdmin()) {
      return [
        { id: 'ALL', label: '全部' },
        { id: 'UNASSIGNED', label: '未分配' },
        { id: 'OVERDUE', label: '已超时' },
        { id: '待审核', label: '待审核' }
      ];
    }
    return [
      { id: 'ALL', label: '全部' },
      { id: '待处理', label: '待处理' },
      { id: '处理中', label: '处理中' },
      { id: '待审核', label: '待审核' },
      { id: '已完成', label: '已完成' }
    ];
  }

  private isAdmin(): boolean {
    return AccountService.getCurrentUser()?.role === UserRole.ADMIN;
  }

  private getStatusColor(status: TaskStatus): string {
    if (status === TaskStatus.PENDING) {
      return AppTheme.amber;
    } else if (status === TaskStatus.PROCESSING) {
      return AppTheme.info;
    } else if (status === TaskStatus.REVIEW) {
      return AppTheme.accentDark;
    }
    return AppTheme.success;
  }

  private getStatusBg(status: TaskStatus): string {
    if (status === TaskStatus.PENDING) {
      return AppTheme.amberSoft;
    } else if (status === TaskStatus.PROCESSING) {
      return AppTheme.infoSoft;
    } else if (status === TaskStatus.REVIEW) {
      return AppTheme.accentSoft;
    }
    return AppTheme.successSoft;
  }

  private getFilteredTasks(): Task[] {
    return this.tasks.filter((task: Task) => {
      if (this.filterTab === 'ALL') {
        return true;
      }
      if (this.filterTab === 'OVERDUE') {
        return EventService.isTaskOverdue(task);
      }
      if (this.filterTab === 'UNASSIGNED') {
        return false;
      }
      return task.status === this.filterTab;
    });
  }

  private getAssigneeName(task: Task): string {
    const assignee: User | undefined = AccountService.getUsers().find(
      (user: User) => user.id === task.assignee
    );
    return assignee === undefined ? task.assignee : assignee.name;
  }

  private getUnassignedEvents(): SecurityEvent[] {
    return this.isAdmin() ? EventService.getUnassignedEvents() : [];
  }

  @Builder
  unassignedEventList() {
    if (this.getUnassignedEvents().length === 0) {
      Column({ space: 8 }) {
        Image($r('app.media.ic_shield_check'))
          .width(30)
          .height(30)
          .fillColor(AppTheme.success)
        Text('暂无未分配事件')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.inkSoft)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Scroll() {
        Column({ space: 12 }) {
          ForEach(this.getUnassignedEvents(), (event: SecurityEvent) => {
            Column({ space: 8 }) {
              Row() {
                Text(event.id)
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.accent)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(8)
                  .backgroundColor(AppTheme.accentSoft)
                Blank()
                Text(event.priority + '优先级')
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.amber)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(8)
                  .backgroundColor(AppTheme.amberSoft)
              }
              .width('100%')

              Text(event.title)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ink)
                .width('100%')

              Text(event.location + ' · 上报于 ' + event.reportTime)
                .fontSize(11)
                .fontColor(AppTheme.muted)
                .width('100%')

              Button('选择负责人并派单')
                .width('100%')
                .height(40)
                .borderRadius(12)
                .backgroundColor(AppTheme.accent)
                .fontColor(Color.White)
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .onClick(() => {
                  EventService.setSelectedEventId(event.id);
                  this.pageStack.pushPath({ name: 'EventDetailPage' });
                })
            }
            .width('100%')
            .padding(14)
            .borderRadius(16)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.line })
            .shadow({ radius: 8, color: AppTheme.cardShadow, offsetY: 2 })
          }, (event: SecurityEvent) => event.id)
        }
        .width('100%')
        .padding(12)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
  }

  private refreshTasks(): void {
    this.tasks = EventService.getAllTasks().slice();
  }

  private can(permission: AppPermission): boolean {
    return PermissionService.can(AccountService.getCurrentUser(), permission);
  }

  private selectTaskEvidence(task: Task, isBefore: boolean): void {
    const context: common.Context = getContext(this) as common.Context;
    AttachmentService.selectEvidence(context).then((paths: string[]) => {
      if (paths.length === 0) {
        return;
      }
      const previous: string[] = isBefore ? (task.beforeAttachmentPaths ?? []) :
        (task.afterAttachmentPaths ?? []);
      const beforePaths: string[] = isBefore ? paths : (task.beforeAttachmentPaths ?? []).slice();
      const afterPaths: string[] = isBefore ? (task.afterAttachmentPaths ?? []).slice() : paths;
      if (EventService.updateTaskEvidence(task.id, beforePaths, afterPaths)) {
        previous.forEach((path: string) => AttachmentService.remove(path));
        this.refreshTasks();
      } else {
        paths.forEach((path: string) => AttachmentService.remove(path));
        promptAction.showToast({ message: '当前任务状态无法更新证据' });
      }
    }).catch((error: Error) => {
      promptAction.showToast({ message: '处置证据选择失败：' + error.message });
    });
  }

  private removeTaskEvidence(task: Task, path: string, isBefore: boolean): void {
    const beforePaths: string[] = (task.beforeAttachmentPaths ?? []).filter(
      (item: string) => !isBefore || item !== path
    );
    const afterPaths: string[] = (task.afterAttachmentPaths ?? []).filter(
      (item: string) => isBefore || item !== path
    );
    if (EventService.updateTaskEvidence(task.id, beforePaths, afterPaths)) {
      AttachmentService.remove(path);
      this.refreshTasks();
    }
  }

  @Builder
  evidenceBlock(task: Task, label: string, paths: string[], isBefore: boolean, editable: boolean) {
    Column({ space: 8 }) {
      Row() {
        Row()
          .width(4)
          .height(12)
          .borderRadius(2)
          .backgroundColor(AppTheme.info)
          .margin({ right: 6 })
        Text(label)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.inkSoft)
          .layoutWeight(1)
        Text(paths.length.toString() + ' 张')
          .fontSize(10)
          .fontColor(AppTheme.muted)
      }
      .width('100%')

      if (paths.length > 0) {
        Row({ space: 8 }) {
          ForEach(paths, (path: string) => {
            Column({ space: 4 }) {
              Image('file://' + path)
                .width(72)
                .height(72)
                .borderRadius(10)
                .objectFit(ImageFit.Cover)
                .border({ width: 1, color: AppTheme.line })
              if (editable) {
                Text('移除')
                  .fontSize(9)
                  .fontColor(AppTheme.danger)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .borderRadius(6)
                  .backgroundColor(AppTheme.dangerSoft)
                  .onClick(() => this.removeTaskEvidence(task, path, isBefore))
              }
            }
          }, (path: string) => path)
        }
        .width('100%')
      }

      if (editable) {
        Button(paths.length === 0 ? '选择图片' : '重新选择')
          .width('100%')
          .height(36)
          .borderRadius(10)
          .backgroundColor(AppTheme.accentSoft)
          .fontColor(AppTheme.accent)
          .fontSize(11)
          .border({ width: 1, color: AppTheme.cyanSoft })
          .onClick(() => this.selectTaskEvidence(task, isBefore))
      }
    }
    .width('100%')
    .padding(10)
    .borderRadius(12)
    .backgroundColor(AppTheme.surfaceMuted)
    .border({ width: 1, color: AppTheme.line })
  }

  private confirmSubmit(task: Task): void {
    if (this.resultText.trim() === '') {
      return;
    }
    if ((task.afterAttachmentPaths ?? []).length === 0) {
      promptAction.showToast({ message: '请至少添加一张处置后证据' });
      return;
    }
    AlertDialog.show({
      title: '提交处置审核',
      message: '确认提交工单 ' + task.id + ' 的处置结果吗？提交后将等待管理员审核。',
      primaryButton: {
        value: '提交审核',
        action: () => {
          EventService.submitTaskForReview(task.id, this.resultText.trim());
          this.processingTaskId = '';
          this.resultText = '';
          this.refreshTasks();
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    });
  }

  @Builder
  metaRow(label: string, value: string, emphasize: boolean) {
    Row() {
      Text(label)
        .fontSize(10)
        .fontColor(AppTheme.muted)
        .width(68)
      Text(value)
        .fontSize(11)
        .fontColor(emphasize ? AppTheme.danger : AppTheme.inkSoft)
        .fontWeight(emphasize ? FontWeight.Bold : FontWeight.Normal)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  taskCard(task: Task) {
    Column() {
      Row({ space: 10 }) {
        Image($r('app.media.ic_task')).width(28).height(28).fillColor(AppTheme.accent)
        Column({ space: 4 }) {
          Text(task.title).fontSize(15).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink).maxLines(2)
          Text('#' + task.id).fontSize(10).fontColor(AppTheme.muted)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(task.status).fontSize(10).fontColor(this.getStatusColor(task.status)).padding(5).borderRadius(6)
          .border({ width: 1, color: this.getStatusColor(task.status) })
      }.width('100%').margin({ bottom: 12 })

      Column({ space: 5 }) {
        this.metaRow('处置地点', task.location, false)
        this.metaRow('责任人员', this.getAssigneeName(task), false)
        this.metaRow('关联事件', task.eventId, false)
        this.metaRow('下发时间', task.createTime, false)
        if (task.acceptedTime !== undefined) {
          this.metaRow('接单时间', task.acceptedTime, false)
        }
        if (task.deadline !== undefined) {
          this.metaRow(
            '处理期限',
            task.deadline + (EventService.isTaskOverdue(task) ? ' · 已超时' : ''),
            EventService.isTaskOverdue(task)
          )
        }
      }
      .width('100%')
      .padding({ top: 2, bottom: 2 })
      .borderRadius(12)
      .backgroundColor(AppTheme.surface)

      .margin({ bottom: 10 })

      Row() {
        Blank()
        Button(this.expandedTaskId === task.id ? '收起' : task.status === TaskStatus.COMPLETED ? '查看结果' : '查看 / 处理')
          .height(32).fontSize(12).fontColor(Color.White).backgroundColor(AppTheme.accent).borderRadius(16)
          .onClick(() => { this.expandedTaskId = this.expandedTaskId === task.id ? '' : task.id; })
      }.width('100%')
      if (this.expandedTaskId === task.id) {
      Text(task.description)
        .fontSize(12)
        .fontColor(AppTheme.inkSoft)
        .lineHeight(18)
        .width('100%')
        .margin({ bottom: 12 })

      if (task.status !== TaskStatus.PROCESSING &&
        (task.beforeAttachmentPaths ?? []).length > 0) {
        this.evidenceBlock(task, '处置前证据', task.beforeAttachmentPaths ?? [], true, false)
      }

      if (task.status !== TaskStatus.PROCESSING &&
        (task.afterAttachmentPaths ?? []).length > 0) {
        this.evidenceBlock(task, '处置后证据', task.afterAttachmentPaths ?? [], false, false)
      }

      if (task.status === TaskStatus.PENDING && this.can(AppPermission.START_TASK)) {
        Button('去处理')
          .width('100%')
          .height(42)
          .borderRadius(12)
          .backgroundColor(AppTheme.accent)
          .fontColor(Color.White)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .shadow({ radius: 8, color: AppTheme.glowBlue, offsetY: 2 })
          .onClick(() => {
            EventService.updateTaskStatus(
              task.id,
              TaskStatus.PROCESSING
            );
            this.refreshTasks();
          })
      }

      if (task.status === TaskStatus.PROCESSING && this.can(AppPermission.SUBMIT_TASK)) {
        Column({ space: 8 }) {
          this.evidenceBlock(task, '处置前证据', task.beforeAttachmentPaths ?? [], true, true)
          this.evidenceBlock(task, '处置后证据', task.afterAttachmentPaths ?? [], false, true)

          TextInput({
            placeholder: '请输入现场处置措施与结果反馈...',
            text: this.processingTaskId === task.id ? this.resultText : task.result ?? ''
          })
            .width('100%')
            .height(84)
            .fontSize(12)
            .borderRadius(12)
            .backgroundColor(AppTheme.surfaceMuted)
            .border({ width: 1, color: AppTheme.line })
            .padding(10)
            .onFocus(() => {
              this.processingTaskId = task.id;
              this.resultText = task.result ?? '';
            })
            .onChange((value: string) => {
              this.processingTaskId = task.id;
              this.resultText = value;
            })

          Button('提交处置结果待审核')
            .width('100%')
            .height(42)
            .borderRadius(12)
            .backgroundColor(AppTheme.success)
            .fontColor(Color.White)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .onClick(() => {
              if (this.resultText.trim() === '') {
                return;
              }
              this.confirmSubmit(task);
            })
        }
        .width('100%')
      }

      if (task.status === TaskStatus.REVIEW) {
        Column({ space: 8 }) {
          Row() {
            Row()
              .width(4)
              .height(12)
              .borderRadius(2)
              .backgroundColor(AppTheme.accentDark)
              .margin({ right: 6 })
            Text('处置结果')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.accentDark)
              .layoutWeight(1)
          }
          .width('100%')

          Text(task.result ?? '')
            .fontSize(11)
            .fontColor(AppTheme.inkSoft)
            .width('100%')
            .padding(10)
            .borderRadius(12)
            .backgroundColor(AppTheme.accentSoft)
            .border({ width: 1, color: AppTheme.cyanSoft })

          if (this.can(AppPermission.REVIEW_TASK)) {
            TextInput({
              placeholder: '驳回时请输入返工原因...',
              text: this.reviewTaskId === task.id ? this.rejectionReason : ''
            })
              .width('100%')
              .height(42)
              .fontSize(12)
              .borderRadius(12)
              .backgroundColor(AppTheme.surfaceMuted)
              .border({ width: 1, color: AppTheme.line })
              .padding({ left: 10, right: 10 })
              .onFocus(() => {
                this.reviewTaskId = task.id;
              })
              .onChange((value: string) => {
                this.reviewTaskId = task.id;
                this.rejectionReason = value;
              })

            Row({ space: 8 }) {
              Button('驳回返工')
                .layoutWeight(1)
                .height(42)
                .borderRadius(12)
                .backgroundColor(AppTheme.danger)
                .fontColor(Color.White)
                .fontSize(12)
                .onClick(() => {
                  if (this.rejectionReason.trim() !== '' &&
                    EventService.rejectTask(task.id, this.rejectionReason)) {
                    this.reviewTaskId = '';
                    this.rejectionReason = '';
                    this.refreshTasks();
                  }
                })

              Button('审核通过')
                .layoutWeight(1)
                .height(42)
                .borderRadius(12)
                .backgroundColor(AppTheme.success)
                .fontColor(Color.White)
                .fontSize(12)
                .onClick(() => {
                  if (EventService.approveTask(task.id)) {
                    this.reviewTaskId = '';
                    this.rejectionReason = '';
                    this.refreshTasks();
                  }
                })
            }
            .width('100%')
          } else {
            Text('处置结果已提交，等待管理员审核')
              .fontSize(11)
              .fontColor(AppTheme.accentDark)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(10)
              .borderRadius(12)
              .backgroundColor(AppTheme.accentSoft)
              .border({ width: 1, color: AppTheme.cyanSoft })
          }
        }
        .width('100%')
      }

      if (task.status === TaskStatus.PROCESSING && task.rejectionReason !== undefined) {
        Column({ space: 4 }) {
          Text('返工原因')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.danger)
            .width('100%')
          Text(task.rejectionReason)
            .fontSize(11)
            .fontColor(AppTheme.danger)
            .width('100%')
            .padding(10)
            .borderRadius(12)
            .backgroundColor(AppTheme.dangerSoft)
            .border({ width: 1, color: AppTheme.danger })
            .margin({ top: 2 })
        }
        .width('100%')
        .margin({ top: 8 })
      }

      if (task.status === TaskStatus.COMPLETED) {
        Column() {
          Row({ space: 6 }) {
            Row()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(AppTheme.success)
            Text('工单已完成现场验收')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.success)
              .width('100%')
          }
          .width('100%')

          if (task.result !== undefined && task.result.trim() !== '') {
            Text(task.result)
              .fontSize(11)
              .fontColor(AppTheme.inkSoft)
              .width('100%')
              .padding(10)
              .borderRadius(12)
              .backgroundColor(AppTheme.successSoft)
              .border({ width: 1, color: AppTheme.success })
              .margin({ top: 8 })
          }

          if (task.completedTime !== undefined) {
            Text('归档时间：' + task.completedTime)
              .fontSize(10)
              .fontColor(AppTheme.muted)
              .width('100%')
              .textAlign(TextAlign.End)
              .margin({ top: 6 })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor(AppTheme.surface)
    .border({ width: 1, color: AppTheme.line })
    .shadow({ radius: 10, color: AppTheme.cardShadow, offsetY: 2 })
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(30).fontColor(AppTheme.ink).width(44).height(48)
          .onClick(() => { this.pageStack.pop(); })
        Text('处置任务').fontSize(17).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
          .layoutWeight(1).textAlign(TextAlign.Center)
        Blank().width(44)
      }.width('100%').height(52).padding({ left: 16, right: 16 }).backgroundColor(AppTheme.canvas)


      // 状态分类切换
      Scroll() {
        Row({ space: 6 }) {
          ForEach(this.getFilters(), (item: TaskFilter) => {
            Text(item.label)
              .fontSize(11)
              .fontWeight(this.filterTab === item.id ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.filterTab === item.id ? AppTheme.accent : AppTheme.inkSoft)
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .borderRadius(12)
              .backgroundColor(this.filterTab === item.id ? AppTheme.accentSoft : AppTheme.canvas)
              .onClick(() => {
                this.filterTab = item.id;
              })
          }, (item: TaskFilter) => item.id)
        }
        .width('100%')
      }
      .width('100%')
      .scrollBar(BarState.Off)
      .scrollable(ScrollDirection.Horizontal)
      .padding({ left: 14, right: 14, top: 8, bottom: 10 })
      .backgroundColor(AppTheme.surface)
      .border({ width: { bottom: 1 }, color: AppTheme.line })

      // 任务列表
      if (this.filterTab === 'UNASSIGNED' && this.isAdmin()) {
        this.unassignedEventList()
      } else if (this.getFilteredTasks().length === 0) {
        Column({ space: 8 }) {
          Image($r('app.media.ic_task'))
            .width(34)
            .height(34)
            .fillColor(AppTheme.lineStrong)
          Text('暂无对应状态的处置任务')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.inkSoft)
          Text('确认安全事件后可自动生成任务')
            .fontSize(12)
            .fontColor(AppTheme.muted)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.getFilteredTasks(), (task: Task) => {
              this.taskCard(task)
            }, (task: Task) => task.id)
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
    .translate({ y: this.pageReady ? 0 : 18 })
    .animation({ duration: 320, curve: Curve.EaseOut })
    .onAppear(() => {
      this.refreshTasks();
      this.pageReady = true;
    })
  }
}
