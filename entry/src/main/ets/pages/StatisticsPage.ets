import { SecurityEvent } from '../model/SecurityEvent';
import { Task } from '../model/Task';

@Component
export struct StatisticsPage {
  build() {
    /* 【不可改】外层 NavDestination(){...}.title('数据统计') 结构必须保留（同上，双层 NavDestination 嵌套，勿动） */
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          // 顶部安全态势大屏头部
          Column() {
            Row() {
              Column() {
                Text('数据统计')
                  .fontSize(24)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
                  .margin({ bottom: 4 })

                Text('校园安全数据统计 · 运行态势多维洞察')
                  .fontSize(13)
                  .fontColor('rgba(255, 255, 255, 0.85)')
              }
              .alignItems(HorizontalAlign.Start)

              Blank()

              // 安全健康指数微标
              Column() {
                Text('98.5%')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#10B981')

                Text('安全达标')
                  .fontSize(10)
                  .fontColor('rgba(255, 255, 255, 0.8)')
              }
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .borderRadius(10)
              .backgroundColor('rgba(255, 255, 255, 0.15)')
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .padding(20)
          .borderRadius(18)
          .linearGradient({
            angle: 135,
            colors: [['#0F172A', 0.0], ['#1E293B', 1.0]]
          })
          .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.25)', offsetY: 6 })

          // 核心三项统计指标卡片（文案与占位完全保持原版）
          Column({ space: 12 }) {
            // 1. 安全事件指标
            Row() {
              Row() {
                Text('◆')
                  .fontSize(20)
                  .fontColor('#1B6EFF')
                  .fontWeight(FontWeight.Bold)
              }
              .width(44)
              .height(44)
              .borderRadius(12)
              .backgroundColor('#EFF6FF')
              .justifyContent(FlexAlign.Center)
              .margin({ right: 12 })

              Column() {
                Text('安全事件：0')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#0F172A')

                Text('历史归档与在办事件总量统计')
                  .fontSize(12)
                  .fontColor('#64748B')
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
            .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.04)', offsetY: 2 })

            // 2. 待处理任务指标
            Row() {
              Row() {
                Text('▲')
                  .fontSize(20)
                  .fontColor('#EA580C')
                  .fontWeight(FontWeight.Bold)
              }
              .width(44)
              .height(44)
              .borderRadius(12)
              .backgroundColor('#FFF7ED')
              .justifyContent(FlexAlign.Center)
              .margin({ right: 12 })

              Column() {
                Text('待处理任务：0')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#EA580C')

                Text('当前待安保与维保团队介入的现场工单')
                  .fontSize(12)
                  .fontColor('#64748B')
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
            .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.04)', offsetY: 2 })

            // 3. 已完成任务指标
            Row() {
              Row() {
                Text('✓')
                  .fontSize(20)
                  .fontColor('#16A34A')
                  .fontWeight(FontWeight.Bold)
              }
              .width(44)
              .height(44)
              .borderRadius(12)
              .backgroundColor('#F0FDF4')
              .justifyContent(FlexAlign.Center)
              .margin({ right: 12 })

              Column() {
                Text('已完成任务：0')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#16A34A')

                Text('全流程已复核完成闭环的安全处置任务')
                  .fontSize(12)
                  .fontColor('#64748B')
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
            .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.04)', offsetY: 2 })
          }
          .width('100%')

          // 综合安全态势图表卡片 (纯 ArkUI 构件绘制，无第三方依赖)
          Column() {
            Text('重点安防领域监控分布')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#334155')
              .width('100%')
              .margin({ bottom: 12 })

            Column({ space: 10 }) {
              Row() {
                Text('消防设施安全')
                  .fontSize(13)
                  .fontColor('#475569')
                  .width(90)

                Row() {
                  Row()
                    .width('85%')
                    .height(8)
                    .borderRadius(4)
                    .backgroundColor('#1B6EFF')
                }
                .layoutWeight(1)
                .height(8)
                .borderRadius(4)
                .backgroundColor('#F1F5F9')

                Text('85%')
                  .fontSize(12)
                  .fontColor('#64748B')
                  .margin({ left: 10 })
              }
              .width('100%')

              Row() {
                Text('电气线路安全')
                  .fontSize(13)
                  .fontColor('#475569')
                  .width(90)

                Row() {
                  Row()
                    .width('92%')
                    .height(8)
                    .borderRadius(4)
                    .backgroundColor('#10B981')
                }
                .layoutWeight(1)
                .height(8)
                .borderRadius(4)
                .backgroundColor('#F1F5F9')

                Text('92%')
                  .fontSize(12)
                  .fontColor('#64748B')
                  .margin({ left: 10 })
              }
              .width('100%')

              Row() {
                Text('校园通道秩序')
                  .fontSize(13)
                  .fontColor('#475569')
                  .width(90)

                Row() {
                  Row()
                    .width('78%')
                    .height(8)
                    .borderRadius(4)
                    .backgroundColor('#F59E0B')
                }
                .layoutWeight(1)
                .height(8)
                .borderRadius(4)
                .backgroundColor('#F1F5F9')

                Text('78%')
                  .fontSize(12)
                  .fontColor('#64748B')
                  .margin({ left: 10 })
              }
              .width('100%')
            }
            .width('100%')
          }
          .width('100%')
          .padding(18)
          .borderRadius(16)
          .backgroundColor('#FFFFFF')
          .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.04)', offsetY: 2 })
          .margin({ bottom: 20 })
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8FAFC')
    }
    .title('数据统计')
  }
}
