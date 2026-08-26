import {
  SecurityEvent,
  EventType,
  EventStatus,
  EventPriority
} from '../model/SecurityEvent';

import { EventService } from '../service/EventService';

@Component
export struct EventDetailPage {
  @State private eventId: string = EventService.getSelectedEventId();

  @State private isConfirmed: boolean = false;

  @State private taskGenerated: boolean = false;

  build() {
    Column() {
      if (this.eventId !== '') {
        this.buildEventDetail()
      } else {
        Text('未找到事件')
          .fontSize(20)
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
  }

  @Builder
  buildEventDetail() {
    Column() {
      Text(this.getEvent().title)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 24 })

      Text('事件编号：' + this.getEvent().id)
        .fontSize(16)
        .margin({ bottom: 12 })

      Text('事件类型：' + this.getEvent().type)
        .fontSize(16)
        .margin({ bottom: 12 })

      Text('发生地点：' + this.getEvent().location)
        .fontSize(16)
        .margin({ bottom: 12 })

      Text(
        '事件状态：' +
          (this.isConfirmed
            ? EventStatus.CONFIRMED
            : this.getEvent().status)
      )
        .fontSize(16)
        .margin({ bottom: 12 })

      Text('事件优先级：' + this.getEvent().priority)
        .fontSize(16)
        .margin({ bottom: 12 })

      Text('上报人：' + this.getEvent().reporter)
        .fontSize(16)
        .margin({ bottom: 12 })

      Text('上报时间：' + this.getEvent().reportTime)
        .fontSize(16)
        .margin({ bottom: 20 })

      Text('事件描述')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .margin({ bottom: 10 })

      Text(this.getEvent().description)
        .fontSize(16)
        .width('100%')
        .margin({ bottom: 30 })

      if (
        this.getEvent().status === EventStatus.PENDING &&
          !this.isConfirmed
      ) {
        Button('确认事件')
          .width('80%')
          .height(50)
          .onClick(() => {
            EventService.confirmEvent(this.eventId);
            this.isConfirmed = true;
          })
      }

      if (
        (this.getEvent().status === EventStatus.CONFIRMED ||
        this.isConfirmed) &&
          !this.taskGenerated
      ) {
        Button('生成处置任务')
          .width('80%')
          .height(50)
          .margin({ top: 12 })
          .onClick(() => {
            EventService.createTaskFromEvent(this.eventId);
            this.taskGenerated = true;
          })
      }
    }
    .width('100%')
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