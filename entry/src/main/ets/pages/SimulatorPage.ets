import {
  SecurityEvent
} from '../model/SecurityEvent';

import { EventWorkflowService } from '../service/EventWorkflowService';
import { EventService } from '../service/EventService';
import { promptAction } from '@kit.ArkUI';

/**
 * 安全事件模拟器（C 模块二级页）
 *
 * 页面只负责展示模板卡片、触发模拟并展示最近生成结果；
 * 数据生成与落库统一走 C 的 EventWorkflowService / EventService / Repository，
 * 页面不直接操作底层存储。
 */
interface SimCardModel {
  templateIndex: number;
  icon: Resource;
  title: string;
  typeLabel: string;
  typeBg: string;
  typeColor: string;
  priorityLabel: string;
  priorityBg: string;
  priorityColor: string;
  location: string;
  buttonText: string;
  buttonColor: string;
}

@Component
export struct EventSimulatorPage {
  // 与 Index 保持同一 NavPathStack 实例，避免 @Prop 深拷贝导致导航崩溃
  pageStack: NavPathStack = new NavPathStack();
  @State private recentEvents: SecurityEvent[] = [];

  private cardModels: SimCardModel[] = [
    {
      templateIndex: 0,
      icon: $r('app.media.ic_sim_smoke'),
      title: '烟雾异常',
      typeLabel: '消防安全',
      typeBg: '#FDEBEA',
      typeColor: '#E34A41',
      priorityLabel: '高',
      priorityBg: '#FDEBEA',
      priorityColor: '#E34A41',
      location: '模拟地点：教学楼3层走廊',
      buttonText: '模拟烟雾异常',
      buttonColor: '#FF5547'
    },
    {
      templateIndex: 1,
      icon: $r('app.media.ic_sim_temp'),
      title: '温度异常',
      typeLabel: '用电安全',
      typeBg: '#EAF2FF',
      typeColor: '#2F6BFF',
      priorityLabel: '中',
      priorityBg: '#EAF2FF',
      priorityColor: '#2F6BFF',
      location: '模拟地点：实验楼配电间',
      buttonText: '模拟温度异常',
      buttonColor: '#FF8A3D'
    },
    {
      templateIndex: 2,
      icon: $r('app.media.ic_sim_device'),
      title: '设备故障',
      typeLabel: '设施安全',
      typeBg: '#EAF2FF',
      typeColor: '#2F6BFF',
      priorityLabel: '中',
      priorityBg: '#EAF2FF',
      priorityColor: '#2F6BFF',
      location: '模拟地点：宿舍楼公共区域',
      buttonText: '模拟设备故障',
      buttonColor: '#2F6BFF'
    }
  ];

  aboutToAppear(): void {
    this.refreshRecent();
  }

  private refreshRecent(): void {
    const events: SecurityEvent[] = EventService.getAllEvents();
    const simulated: SecurityEvent[] = events.filter(
      (event: SecurityEvent) => event.reporter === '系统模拟'
    );
    if (simulated.length > 0) {
      this.recentEvents = [simulated[simulated.length - 1]];
    } else {
      this.recentEvents = [];
    }
  }

  private handleSimulate(templateIndex: number): void {
    const event: SecurityEvent = EventWorkflowService.simulateAndEnqueue(templateIndex);
    promptAction.showToast({ message: '已生成事件：' + event.id });
    this.recentEvents = [event];
  }

  @Builder
  templateCard(model: SimCardModel) {
    Row() {
      Image(model.icon)
        .width(64)
        .height(64)
        .objectFit(ImageFit.Contain)

      Column() {
        Text(model.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2A3240')

        Row() {
          Text(model.typeLabel)
            .fontSize(12)
            .fontColor(model.typeColor)
            .backgroundColor(model.typeBg)
            .borderRadius(10)
            .padding({
              left: 10,
              right: 10,
              top: 4,
              bottom: 4
            })

          Text(model.priorityLabel)
            .fontSize(12)
            .fontColor(model.priorityColor)
            .backgroundColor(model.priorityBg)
            .borderRadius(10)
            .padding({
              left: 10,
              right: 10,
              top: 4,
              bottom: 4
            })
            .margin({ left: 6 })
        }
        .margin({ top: 6 })

        Text(model.location)
          .fontSize(13)
          .fontColor('#8A93A6')
          .margin({ top: 8 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12, right: 10 })

      Row() {
        Text(model.buttonText)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
      }
      .justifyContent(FlexAlign.Center)
      .backgroundColor(model.buttonColor)
      .borderRadius(14)
      .height(40)
      .padding({
        left: 14,
        right: 14
      })
      .onClick(() => {
        this.handleSimulate(model.templateIndex);
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .margin({ bottom: 12 })
    .shadow({
      radius: 16,
      color: '#141F3A74',
      offsetY: 6
    })
  }

  @Builder
  recentCard() {
    Column() {
      Row() {
        Text('最近生成')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2A3240')

        Text('今天')
          .fontSize(13)
          .fontColor('#8A93A6')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 12 })

      if (this.recentEvents.length > 0) {
        ForEach(this.recentEvents, (event: SecurityEvent) => {
          Row() {
            Image($r('app.media.ic_gl_flame'))
              .width(32)
              .height(32)
              .objectFit(ImageFit.Contain)

            Column() {
              Text(event.title + ' · ' + event.location)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#2A3240')

              Text(event.priority + ' · ' + event.status + ' · ' + event.id)
                .fontSize(12)
                .fontColor('#8A93A6')
                .margin({ top: 4 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 12 })

            Row() {
              Image($r('app.media.ic_sim_check'))
                .width(18)
                .height(18)
                .objectFit(ImageFit.Contain)

              Text('已生成')
                .fontSize(12)
                .fontColor('#2EDC8F')
                .margin({ left: 4 })
            }
          }
          .width('100%')
          .padding(12)
          .backgroundColor('#F7F9FC')
          .borderRadius(14)
        })
      } else {
        Text('点击上方按钮模拟生成安全事件')
          .fontSize(13)
          .fontColor('#8A93A6')
          .padding({ top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .margin({ top: 12 })
    .shadow({
      radius: 16,
      color: '#141F3A74',
      offsetY: 6
    })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // 品牌蓝渐变背景，向卡片区后方延伸
      Column()
        .width('100%')
        .height(340)
        .linearGradient({
          angle: 180,
          colors: [
            ['#2F6BFF', 0],
            ['#8FB8FF', 0.72],
            ['#F5F7FA', 1]
          ]
        })

      // 页面内容层
      Scroll() {
        Column() {
          // 沉浸式渐变头部
          Row() {
            Image($r('app.media.ic_sim_back'))
              .width(24)
              .height(24)
              .objectFit(ImageFit.Contain)
              .onClick(() => {
                this.pageStack.pop();
              })

            Column() {
              Text('安全事件模拟器')
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)

              Text('一键模拟 · 演示安全闭环全流程')
                .fontSize(13)
                .fontColor('#DCE8FF')
                .margin({ top: 4 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 16 })

            Image($r('app.media.ic_sim_header'))
              .width(58)
              .height(58)
              .objectFit(ImageFit.Contain)
          }
          .width('100%')
          .padding({
            left: 16,
            right: 16,
            top: 18,
            bottom: 18
          })

          // 三张模板卡片
          ForEach(this.cardModels, (model: SimCardModel) => {
            this.templateCard(model)
          }, (model: SimCardModel) => model.templateIndex.toString())

          // 提示横幅
          Row() {
            Image($r('app.media.ic_gl_info'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)

            Text('模拟事件将自动进入安全事件管理流程，可前往事件列表查看')
              .fontSize(12)
              .fontColor('#2F6BFF')
              .margin({ left: 8 })
          }
          .width('100%')
          .padding({
            left: 12,
            right: 12,
            top: 10,
            bottom: 10
          })
          .backgroundColor('#EAF2FF')
          .borderRadius(14)
          .margin({ top: 12 })
          .onClick(() => {
            this.pageStack.pushPath({
              name: 'EventPage'
            });
          })

          // 最近生成
          this.recentCard()
        }
        .width('100%')
        .padding({
          left: 16,
          right: 16,
          bottom: 24
        })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA')
  }
}
