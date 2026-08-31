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

  build() {
    Column() {

      Text('处置任务')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .margin({
          top: 20,
          bottom: 8
        })

      Text('校园安全处置任务')
        .fontSize(16)
        .margin({
          bottom: 20
        })

      if (this.tasks.length === 0) {

        Column() {

          Text('暂无处置任务')
            .fontSize(20)
            .margin({
              bottom: 8
            })

          Text('确认安全事件后，可以生成处置任务')
            .fontSize(14)

        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

      } else {

        List({ space: 12 }) {

          ForEach(
            this.tasks,
            (task: Task) => {

              ListItem() {

                Column() {

                  // ========================
                  // 任务标题
                  // ========================

                  Row() {

                    Text(task.title)
                      .fontSize(20)
                      .fontWeight(FontWeight.Bold)
                      .layoutWeight(1)

                    Text(task.status)
                      .fontSize(14)

                  }
                  .width('100%')
                  .margin({
                    bottom: 12
                  })


                  // ========================
                  // 基础信息
                  // ========================

                  Text('任务编号：' + task.id)
                    .fontSize(14)
                    .width('100%')
                    .margin({
                      bottom: 6
                    })

                  Text('关联事件：' + task.eventId)
                    .fontSize(14)
                    .width('100%')
                    .margin({
                      bottom: 6
                    })

                  Text('地点：' + task.location)
                    .fontSize(14)
                    .width('100%')
                    .margin({
                      bottom: 6
                    })

                  Text('处理人：' + task.assignee)
                    .fontSize(14)
                    .width('100%')
                    .margin({
                      bottom: 6
                    })

                  Text(task.description)
                    .fontSize(14)
                    .width('100%')
                    .margin({
                      bottom: 12
                    })


                  // ========================
                  // 待处理
                  // ========================

                  if (task.status === TaskStatus.PENDING) {

                    Button('开始处理')
                      .width('100%')
                      .height(44)
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

                    TextInput({
                      placeholder: '请输入本次任务的处理结果',
                      text: this.processingTaskId === task.id
                        ? this.resultText
                        : ''
                    })
                      .width('100%')
                      .height(100)
                      .margin({
                        bottom: 12
                      })
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


                  // ========================
                  // 已完成
                  // ========================

                  if (task.status === TaskStatus.COMPLETED) {

                    Text('✓ 任务已完成')
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .margin({
                        bottom: 8
                      })

                    if (task.result !== undefined &&
                      task.result.trim() !== '') {

                      Text('处理结果：')
                        .fontSize(14)
                        .margin({
                          bottom: 4
                        })

                      Text(task.result)
                        .fontSize(14)
                        .width('100%')
                        .margin({
                          bottom: 8
                        })

                    }

                    if (task.completedTime !== undefined) {

                      Text('完成时间：' + task.completedTime)
                        .fontSize(14)
                        .width('100%')

                    }

                  }

                }
                .width('100%')
                .padding(16)

              }

            }
          )

        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .padding({
          left: 16,
          right: 16
        })

      }

    }
    .width('100%')
    .height('100%')
    .padding({
      left: 16,
      right: 16
    })
  }

  // 刷新任务列表
  private refreshTasks(): void {
    this.tasks = EventService.getAllTasks().slice();
  }
}
