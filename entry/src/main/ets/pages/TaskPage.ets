import {
  Task,
  TaskStatus
} from '../model/Task';
import {
  EventService
} from '../service/EventService';

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
  @State private processingTaskId: string = '';
  @State private resultText: string = '';
  @State private reviewTaskId: string = '';
  @State private rejectionReason: string = '';

  private filters: TaskFilter[] = [
    { id: 'ALL', label: '全部' },
    { id: '待处理', label: '待处理' },
    { id: '处理中', label: '处理中' },
    { id: '待审核', label: '待审核' },
    { id: '已完成', label: '已完成' }
  ];

  private getStatusColor(status: TaskStatus): string {
    if (status === TaskStatus.PENDING) {
      return '#B45309';
    } else if (status === TaskStatus.PROCESSING) {
      return '#2563EB';
    } else if (status === TaskStatus.REVIEW) {
      return '#7C3AED';
    }
    return '#059669';
  }

  private getStatusBg(status: TaskStatus): string {
    if (status === TaskStatus.PENDING) {
      return '#FFF7ED';
    } else if (status === TaskStatus.PROCESSING) {
      return '#EFF6FF';
    } else if (status === TaskStatus.REVIEW) {
      return '#F5F3FF';
    }
    return '#ECFDF5';
  }

  private getFilteredTasks(): Task[] {
    return this.tasks.filter((task: Task) => {
      if (this.filterTab === 'ALL') {
        return true;
      }
      return task.status === this.filterTab;
    });
  }

  private refreshTasks(): void {
    this.tasks = EventService.getAllTasks().slice();
  }

  private confirmSubmit(task: Task): void {
    if (this.resultText.trim() === '') {
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
          Text('处置任务')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Text('现场工单接单与闭环反馈')
            .fontSize(10)
            .fontColor('#94A3B8')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(this.tasks.length.toString() + ' 项工单')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#B45309')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(12)
          .backgroundColor('#FFF7ED')
          .border({ width: 1, color: '#FDE68A' })
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 14, bottom: 10 })
      .backgroundColor(Color.White)

      // 状态分类切换
      Row({ space: 6 }) {
        ForEach(this.filters, (item: TaskFilter) => {
          Text(item.label)
            .fontSize(11)
            .fontWeight(this.filterTab === item.id ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.filterTab === item.id ? Color.White : '#64748B')
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .borderRadius(12)
            .backgroundColor(this.filterTab === item.id ? '#2563EB' : '#F1F5F9')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.filterTab = item.id;
            })
        }, (item: TaskFilter) => item.id)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 10 })
      .backgroundColor(Color.White)
      .border({ width: { bottom: 1 }, color: '#E2E8F0' })

      // 任务列表
      if (this.getFilteredTasks().length === 0) {
        Column({ space: 8 }) {
          Text('○')
            .fontSize(34)
            .fontColor('#CBD5E1')
          Text('暂无对应状态的处置任务')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#475569')
          Text('确认安全事件后可自动生成任务')
            .fontSize(12)
            .fontColor('#94A3B8')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.getFilteredTasks(), (task: Task) => {
              Column() {
                Row() {
                  Text(task.id)
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#64748B')
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(8)
                    .backgroundColor('#F1F5F9')

                  Text(task.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#0F172A')
                    .margin({ left: 8 })
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(task.status)
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.getStatusColor(task.status))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(10)
                    .backgroundColor(this.getStatusBg(task.status))
                }
                .width('100%')
                .margin({ bottom: 10 })

                Column({ space: 5 }) {
                  Row() {
                    Text('处置地点：')
                      .fontSize(11)
                      .fontColor('#94A3B8')
                      .layoutWeight(1)
                    Text(task.location)
                      .fontSize(11)
                      .fontColor('#334155')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                  }
                  .width('100%')

                  Row() {
                    Text('责任人员：')
                      .fontSize(11)
                      .fontColor('#94A3B8')
                      .layoutWeight(1)
                    Text(task.assignee)
                      .fontSize(11)
                      .fontColor('#334155')
                  }
                  .width('100%')

                  Row() {
                    Text('关联事件：')
                      .fontSize(11)
                      .fontColor('#94A3B8')
                      .layoutWeight(1)
                    Text(task.eventId)
                      .fontSize(11)
                      .fontColor('#475569')
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(10)
                .borderRadius(12)
                .backgroundColor('#F8FAFC')
                .margin({ bottom: 10 })

                Text(task.description)
                  .fontSize(12)
                  .fontColor('#475569')
                  .lineHeight(18)
                  .width('100%')
                  .margin({ bottom: 12 })

                if (task.status === TaskStatus.PENDING) {
                  Button('接单并开始处置')
                    .width('100%')
                    .height(42)
                    .borderRadius(12)
                    .backgroundColor('#2563EB')
                    .fontColor(Color.White)
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .onClick(() => {
                      EventService.updateTaskStatus(
                        task.id,
                        TaskStatus.PROCESSING
                      );
                      this.refreshTasks();
                    })
                }

                if (task.status === TaskStatus.PROCESSING) {
                  Column({ space: 8 }) {
                    TextInput({
                      placeholder: '请输入现场处置措施与结果反馈...',
                      text: this.processingTaskId === task.id ? this.resultText : task.result ?? ''
                    })
                      .width('100%')
                      .height(80)
                      .fontSize(12)
                      .borderRadius(12)
                      .backgroundColor('#F8FAFC')
                      .border({ width: 1, color: '#CBD5E1' })
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
                      .backgroundColor('#059669')
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
                    Text('处置结果：' + (task.result ?? ''))
                      .fontSize(11)
                      .fontColor('#334155')
                      .width('100%')
                      .padding(10)
                      .borderRadius(12)
                      .backgroundColor('#F5F3FF')
                      .border({ width: 1, color: '#DDD6FE' })

                    TextInput({
                      placeholder: '驳回时请输入返工原因...',
                      text: this.reviewTaskId === task.id ? this.rejectionReason : ''
                    })
                      .width('100%')
                      .height(42)
                      .fontSize(12)
                      .borderRadius(12)
                      .backgroundColor('#F8FAFC')
                      .border({ width: 1, color: '#CBD5E1' })
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
                        .backgroundColor('#DC2626')
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
                        .backgroundColor('#059669')
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
                  }
                  .width('100%')
                }

                if (task.status === TaskStatus.PROCESSING && task.rejectionReason !== undefined) {
                  Text('返工原因：' + task.rejectionReason)
                    .fontSize(11)
                    .fontColor('#B91C1C')
                    .width('100%')
                    .padding(10)
                    .borderRadius(12)
                    .backgroundColor('#FEF2F2')
                    .border({ width: 1, color: '#FECACA' })
                    .margin({ top: 8 })
                }

                if (task.status === TaskStatus.COMPLETED) {
                  Column() {
                    Text('✓ 工单已完成现场验收')
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#059669')
                      .width('100%')

                    if (task.result !== undefined && task.result.trim() !== '') {
                      Text('处置结果：' + task.result)
                        .fontSize(11)
                        .fontColor('#334155')
                        .width('100%')
                        .padding(10)
                        .borderRadius(12)
                        .backgroundColor('#ECFDF5')
                        .border({ width: 1, color: '#A7F3D0' })
                        .margin({ top: 8 })
                    }

                    if (task.completedTime !== undefined) {
                      Text('归档时间：' + task.completedTime)
                        .fontSize(10)
                        .fontColor('#94A3B8')
                        .width('100%')
                        .textAlign(TextAlign.End)
                        .margin({ top: 6 })
                    }
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                }
              }
              .width('100%')
              .padding(14)
              .borderRadius(18)
              .backgroundColor(Color.White)
              .border({ width: 1, color: '#E2E8F0' })
              .shadow({ radius: 10, color: 'rgba(15,23,42,0.04)', offsetY: 2 })
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
    .backgroundColor('#F8FAFC')
    .opacity(this.pageReady ? 1 : 0)
    .translate({ y: this.pageReady ? 0 : 18 })
    .animation({ duration: 320, curve: Curve.EaseOut })
    .onAppear(() => {
      this.pageReady = true;
    })
  }
}
