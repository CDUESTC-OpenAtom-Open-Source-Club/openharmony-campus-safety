import {
  Task
} from '../model/Task';

import {
  EventService
} from '../service/EventService';

@Component
export struct TaskPage {
  @State private tasks: Task[] = EventService.getAllTasks();

  build() {
    Column() {
      Text('处置任务')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 8 })

      Text('校园安全处置任务')
        .fontSize(16)
        .margin({ bottom: 20 })

      if (this.tasks.length === 0) {
        Column() {
          Text('暂无处置任务')
            .fontSize(20)
            .margin({ bottom: 8 })

          Text('确认安全事件后，可以生成处置任务')
            .fontSize(14)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.tasks, (task: Task) => {
            ListItem() {
              Column() {
                Row() {
                  Text(task.title)
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .layoutWeight(1)

                  Text(task.status)
                    .fontSize(14)
                }
                .width('100%')
                .margin({ bottom: 12 })

                Text('任务编号：' + task.id)
                  .fontSize(14)
                  .width('100%')
                  .margin({ bottom: 6 })

                Text('关联事件：' + task.eventId)
                  .fontSize(14)
                  .width('100%')
                  .margin({ bottom: 6 })

                Text('地点：' + task.location)
                  .fontSize(14)
                  .width('100%')
                  .margin({ bottom: 6 })

                Text('处理人：' + task.assignee)
                  .fontSize(14)
                  .width('100%')
                  .margin({ bottom: 6 })

                Text(task.description)
                  .fontSize(14)
                  .width('100%')
              }
              .width('100%')
              .padding(16)
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
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
}