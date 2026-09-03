import {
  Task,
  TaskStatus
} from '../model/Task';

import {
  EventService
} from '../service/EventService';

@Component
export struct TaskPage {

  @State private tasks: Task[] = EventService.getAllTasks();

  // 当前正在处理的任务
  @State private processingTaskId: string = '';

  // 当前填写的处理结果
  @State private resultText: string = '';

  // 状态颜色辅助
  private getTaskStatusColor(status: TaskStatus): string {
    if (status === TaskStatus.PENDING) {
      return '#EA580C';
    } else if (status === TaskStatus.PROCESSING) {
      return '#1B6EFF';
    } else if (status === TaskStatus.COMPLETED) {
      return '#16A34A';
    }
    return '#64748B';
  }

  build() {
    Column() {
      // 头部标题与概述
      Column() {
        Row() {
          Column() {
            Text('处置任务')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
              .margin({ bottom: 4 })

            Text('校园安全处置工单 · 现场勘查与隐患闭环')
              .fontSize(13)
              .fontColor('#64748B')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Text(this.tasks.length.toString() + ' 项任务')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#EA580C')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#FFF7ED')
            .borderRadius(12)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      if (this.tasks.length === 0) {
        Column({ space: 10 }) {
          Text('■')
            .fontSize(36)
            .fontColor('#94A3B8')
            .margin({ bottom: 8 })

          Text('暂无处置任务')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#334155')

          Text('确认安全事件后，可以生成处置任务')
            .fontSize(13)
            .fontColor('#94A3B8')
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 14 }) {
          ForEach(
            this.tasks,
            (task: Task) => {
              ListItem() {
                Column() {
                  // ========================
                  // 任务标题与状态标签
                  // ========================
                  Row() {
                    Text(task.title)
                      .fontSize(17)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#0F172A')
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Row() {
                      Text(task.status)
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.getTaskStatusColor(task.status))
                    }
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(8)
                    .backgroundColor(
                      task.status === TaskStatus.COMPLETED
                        ? '#F0FDF4'
                        : task.status === TaskStatus.PROCESSING
                        ? '#EFF6FF'
                        : '#FFF7ED'
                    )
                  }
                  .width('100%')
                  .margin({ bottom: 10 })

                  // ========================
                  // 基础信息区块
                  // ========================
                  Column({ space: 6 }) {
                    Row() {
                      Text('任务编号：' + task.id)
                        .fontSize(13)
                        .fontColor('#64748B')
                        .layoutWeight(1)

                      Text('关联事件：' + task.eventId)
                        .fontSize(13)
                        .fontColor('#64748B')
                    }
                    .width('100%')

                    Row() {
                      Text('地点：' + task.location)
                        .fontSize(13)
                        .fontColor('#475569')
                        .layoutWeight(1)

                      Text('处理人：' + task.assignee)
                        .fontSize(13)
                        .fontColor('#0F172A')
                    }
                    .width('100%')
                  }
                  .width('100%')
                  .padding(10)
                  .borderRadius(10)
                  .backgroundColor('#F8FAFC')
                  .margin({ bottom: 10 })

                  Text(task.description)
                    .fontSize(13)
                    .fontColor('#334155')
                    .lineHeight(19)
                    .width('100%')
                    .margin({ bottom: 12 })

                  // ========================
                  // 待处理
                  // ========================
                  if (task.status === TaskStatus.PENDING) {
                    Button('开始处理')
                      .width('100%')
                      .height(44)
                      .borderRadius(10)
                      .backgroundColor('#1B6EFF')
                      .fontWeight(FontWeight.Medium)
                      .shadow({ radius: 8, color: 'rgba(27, 110, 255, 0.2)', offsetY: 3 })
                      .onClick(() => {
                        EventService.updateTaskStatus(
                          task.id,
                          TaskStatus.PROCESSING
                        );

                        this.refreshTasks();
                      })
                  }

                  // ========================
                  // 处理中
                  // ========================
                  if (task.status === TaskStatus.PROCESSING) {
                    Column() {
                      TextInput({
                        placeholder: '请输入本次任务的处理结果',
                        text: this.processingTaskId === task.id
                          ? this.resultText
                          : ''
                      })
                        .width('100%')
                        .height(84)
                        .borderRadius(10)
                        .backgroundColor('#F8FAFC')
                        .border({ width: 1, color: '#CBD5E1' })
                        .padding(10)
                        .margin({ bottom: 10 })
                        .onFocus(() => {
                          this.processingTaskId = task.id;
                          this.resultText = task.result ?? '';
                        })
                        .onChange((value: string) => {
                          this.processingTaskId = task.id;
                          this.resultText = value;
                        })

                      Button('完成任务')
                        .width('100%')
                        .height(44)
                        .borderRadius(10)
                        .backgroundColor('#16A34A')
                        .fontWeight(FontWeight.Medium)
                        .shadow({ radius: 8, color: 'rgba(22, 163, 74, 0.2)', offsetY: 3 })
                        .onClick(() => {
                          if (this.processingTaskId !== task.id) {
                            this.processingTaskId = task.id;
                          }

                          if (this.resultText.trim() === '') {
                            AlertDialog.show({
                              title: '提示',
                              message: '请先填写处理结果'
                            });
                            return;
                          }

                          AlertDialog.show({
                            title: '确认完成',
                            message: '确定要将该任务标记为已完成吗？',
                            primaryButton: {
                              value: '确认完成',
                              action: () => {
                                EventService.updateTaskStatus(
                                  task.id,
                                  TaskStatus.COMPLETED,
                                  this.resultText.trim()
                                );

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
                        })
                    }
                    .width('100%')
                  }

                  // ========================
                  // 已完成
                  // ========================
                  if (task.status === TaskStatus.COMPLETED) {
                    Column() {
                      Row() {
                        Text('✓ 任务已完成')
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#16A34A')
                      }
                      .width('100%')
                      .margin({ bottom: 6 })

                      if (task.result !== undefined &&
                        task.result.trim() !== '') {
                        Text('处理结果：')
                          .fontSize(13)
                          .fontWeight(FontWeight.Medium)
                          .fontColor('#475569')
                          .margin({ bottom: 2 })

                        Text(task.result)
                          .fontSize(13)
                          .fontColor('#0F172A')
                          .width('100%')
                          .padding(8)
                          .borderRadius(8)
                          .backgroundColor('#F0FDF4')
                          .margin({ bottom: 6 })
                      }

                      if (task.completedTime !== undefined) {
                        Text('完成时间：' + task.completedTime)
                          .fontSize(12)
                          .fontColor('#94A3B8')
                          .width('100%')
                      }
                    }
                    .width('100%')
                    .alignItems(HorizontalAlign.Start)
                  }
                }
                .width('100%')
                .padding(16)
                .borderRadius(16)
                .backgroundColor('#FFFFFF')
                .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.05)', offsetY: 3 })
              }
            }
          )
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .padding({
          left: 16,
          right: 16,
          bottom: 16
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC')
  }

  /* 【不可改】refreshTasks 方法逐字保留 */
  private refreshTasks(): void {
    this.tasks = EventService.getAllTasks().slice();
  }
}
