import { EventPage } from './EventPage';
import { EventDetailPage } from './EventDetailPage';
import { TaskPage } from './TaskPage';
import { ReportPage } from './ReportPage';
import { StatisticsPage } from './StatisticsPage';

@Entry
@Component
struct Index {
  /* 【不可改】pageStack 必须保持普通成员变量；不得改为 @State/@Prop 等响应式声明 */
  private pageStack: NavPathStack = new NavPathStack();

  // 开屏动画控制状态
  @State private splashVisible: boolean = true;
  @State private splashOpacity: number = 0;
  @State private splashScale: number = 0.85;
  @State private splashOffsetY: number = 24;
  @State private splashProgress: number = 0;
  // 首页卡片入场动效
  @State private homeReady: boolean = false;

  // 定时器引用，防止组件销毁后泄漏
  private timerEnter: number = -1;
  private timerExit: number = -1;
  private timerFinish: number = -1;

  aboutToDisappear(): void {
    if (this.timerEnter !== -1) {
      clearTimeout(this.timerEnter);
    }
    if (this.timerExit !== -1) {
      clearTimeout(this.timerExit);
    }
    if (this.timerFinish !== -1) {
      clearTimeout(this.timerFinish);
    }
  }

  /* 【不可改】5 条路由名与标题一字不能改；NavDestination 包装关系不能改 */
  @Builder
  pageMap(name: string) {
    if (name === 'EventPage') {
      NavDestination() {
        EventPage({
          pageStack: this.pageStack
        })
      }
      .title('安全事件')
    } else if (name === 'EventDetailPage') {
      NavDestination() {
        EventDetailPage()
      }
      .title('事件详情')
    } else if (name === 'TaskPage') {
      NavDestination() {
        TaskPage()
      }
      .title('处置任务')
    } else if (name === 'ReportPage') {
      NavDestination() {
        ReportPage()
      }
      .title('隐患上报')
    } else if (name === 'StatisticsPage') {
      NavDestination() {
        StatisticsPage()
      }
      .title('数据统计')
    }
  }

  build() {
    Stack() {
      /* 【不可改】Navigation 容器、4 个按钮的 onClick pushPath 与路由名逐字保留 */
      Navigation(this.pageStack) {
        Scroll() {
          Column() {
            // ========================
            // 顶部品牌与安全状态头部
            // ========================
            Column() {
              Row() {
                Column() {
                  Text('鸿蒙智安')
                    .fontSize(30)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#0F172A')
                    .margin({ bottom: 4 })

                  Text('校园安全协同应用')
                    .fontSize(14)
                    .fontColor('#64748B')
                    .fontWeight(FontWeight.Medium)
                }
                .alignItems(HorizontalAlign.Start)

                Blank()

                // 状态指示徽章
                Row({ space: 6 }) {
                  Row()
                    .width(8)
                    .height(8)
                    .borderRadius(4)
                    .backgroundColor('#10B981')

                  Text('实时监控中')
                    .fontSize(12)
                    .fontColor('#047857')
                    .fontWeight(FontWeight.Medium)
                }
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .borderRadius(16)
                .backgroundColor('#ECFDF5')
                .border({ width: 1, color: '#A7F3D0' })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .margin({ bottom: 20 })

              // 校园安全公告卡片
              Row() {
                Column() {
                  Text('平安校园 · 敏捷响应')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                    .margin({ bottom: 4 })

                  Text('隐患秒级上报 · 任务闭环处置 · 数据实时洞察')
                    .fontSize(12)
                    .fontColor('rgba(255, 255, 255, 0.85)')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text('SHIELD')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bolder)
                  .fontColor('rgba(255, 255, 255, 0.3)')
              }
              .width('100%')
              .padding(18)
              .borderRadius(16)
              .linearGradient({
                angle: 135,
                colors: [['#1B6EFF', 0.0], ['#0A4DC2', 1.0]]
              })
              .shadow({
                radius: 16,
                color: 'rgba(27, 110, 255, 0.25)',
                offsetY: 6
              })
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 20, bottom: 12 })

            // ========================
            // 核心业务功能入口 (四宫格/卡片阵列)
            // ========================
            Text('核心业务协同')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#334155')
              .width('100%')
              .padding({ left: 20, right: 20, top: 12, bottom: 12 })

            Column({ space: 14 }) {
              // 1. 安全事件入口
              Button({ type: ButtonType.Normal }) {
                Row() {
                  // 左侧图标装饰块
                  Row() {
                    Text('◆')
                      .fontSize(20)
                      .fontColor('#1B6EFF')
                      .fontWeight(FontWeight.Bold)
                  }
                  .width(48)
                  .height(48)
                  .borderRadius(14)
                  .backgroundColor('#EFF6FF')
                  .justifyContent(FlexAlign.Center)
                  .margin({ right: 14 })

                  Column() {
                    Row() {
                      Text('安全事件')
                        .fontSize(17)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#0F172A')

                      Blank()

                      Text('事件核查与处置')
                        .fontSize(12)
                        .fontColor('#64748B')
                    }
                    .width('100%')
                    .margin({ bottom: 4 })

                    Text('全校安全隐患汇聚列表，支持审核与任务指派')
                      .fontSize(13)
                      .fontColor('#94A3B8')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text('›')
                    .fontSize(24)
                    .fontColor('#CBD5E1')
                    .margin({ left: 8 })
                }
                .width('100%')
                .padding(16)
              }
              .width('100%')
              .borderRadius(16)
              .backgroundColor('#FFFFFF')
              .shadow({ radius: 12, color: 'rgba(15, 23, 42, 0.05)', offsetY: 4 })
              .opacity(this.homeReady ? 1 : 0)
              .translate({ y: this.homeReady ? 0 : 24 })
              .animation({ duration: 420, curve: Curve.EaseOut, delay: 120 })
              .onClick(() => {
                this.pageStack.pushPath({ name: 'EventPage' })
              })

              // 2. 处置任务入口
              Button({ type: ButtonType.Normal }) {
                Row() {
                  Row() {
                    Text('▲')
                      .fontSize(20)
                      .fontColor('#EA580C')
                      .fontWeight(FontWeight.Bold)
                  }
                  .width(48)
                  .height(48)
                  .borderRadius(14)
                  .backgroundColor('#FFF7ED')
                  .justifyContent(FlexAlign.Center)
                  .margin({ right: 14 })

                  Column() {
                    Row() {
                      Text('处置任务')
                        .fontSize(17)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#0F172A')

                      Blank()

                      Text('闭环跟踪')
                        .fontSize(12)
                        .fontColor('#EA580C')
                    }
                    .width('100%')
                    .margin({ bottom: 4 })

                    Text('巡检与维修人员处理工单，反馈处置结果')
                      .fontSize(13)
                      .fontColor('#94A3B8')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text('›')
                    .fontSize(24)
                    .fontColor('#CBD5E1')
                    .margin({ left: 8 })
                }
                .width('100%')
                .padding(16)
              }
              .width('100%')
              .borderRadius(16)
              .backgroundColor('#FFFFFF')
              .shadow({ radius: 12, color: 'rgba(15, 23, 42, 0.05)', offsetY: 4 })
              .opacity(this.homeReady ? 1 : 0)
              .translate({ y: this.homeReady ? 0 : 24 })
              .animation({ duration: 420, curve: Curve.EaseOut, delay: 210 })
              .onClick(() => {
                this.pageStack.pushPath({ name: 'TaskPage' })
              })

              // 3. 隐患上报入口
              Button({ type: ButtonType.Normal }) {
                Row() {
                  Row() {
                    Text('■')
                      .fontSize(20)
                      .fontColor('#16A34A')
                      .fontWeight(FontWeight.Bold)
                  }
                  .width(48)
                  .height(48)
                  .borderRadius(14)
                  .backgroundColor('#F0FDF4')
                  .justifyContent(FlexAlign.Center)
                  .margin({ right: 14 })

                  Column() {
                    Row() {
                      Text('隐患上报')
                        .fontSize(17)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#0F172A')

                      Blank()

                      Text('师生直通车')
                        .fontSize(12)
                        .fontColor('#16A34A')
                    }
                    .width('100%')
                    .margin({ bottom: 4 })

                    Text('发现消防、用电、设施异常，一键快速填报')
                      .fontSize(13)
                      .fontColor('#94A3B8')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text('›')
                    .fontSize(24)
                    .fontColor('#CBD5E1')
                    .margin({ left: 8 })
                }
                .width('100%')
                .padding(16)
              }
              .width('100%')
              .borderRadius(16)
              .backgroundColor('#FFFFFF')
              .shadow({ radius: 12, color: 'rgba(15, 23, 42, 0.05)', offsetY: 4 })
              .opacity(this.homeReady ? 1 : 0)
              .translate({ y: this.homeReady ? 0 : 24 })
              .animation({ duration: 420, curve: Curve.EaseOut, delay: 300 })
              .onClick(() => {
                this.pageStack.pushPath({ name: 'ReportPage' })
              })

              // 4. 数据统计入口
              Button({ type: ButtonType.Normal }) {
                Row() {
                  Row() {
                    Text('◈')
                      .fontSize(20)
                      .fontColor('#9333EA')
                      .fontWeight(FontWeight.Bold)
                  }
                  .width(48)
                  .height(48)
                  .borderRadius(14)
                  .backgroundColor('#FAF5FF')
                  .justifyContent(FlexAlign.Center)
                  .margin({ right: 14 })

                  Column() {
                    Row() {
                      Text('数据统计')
                        .fontSize(17)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#0F172A')

                      Blank()

                      Text('态势总览')
                        .fontSize(12)
                        .fontColor('#9333EA')
                    }
                    .width('100%')
                    .margin({ bottom: 4 })

                    Text('校园安全运行态势量化分析与数据指标')
                      .fontSize(13)
                      .fontColor('#94A3B8')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text('›')
                    .fontSize(24)
                    .fontColor('#CBD5E1')
                    .margin({ left: 8 })
                }
                .width('100%')
                .padding(16)
              }
              .width('100%')
              .borderRadius(16)
              .backgroundColor('#FFFFFF')
              .shadow({ radius: 12, color: 'rgba(15, 23, 42, 0.05)', offsetY: 4 })
              .opacity(this.homeReady ? 1 : 0)
              .translate({ y: this.homeReady ? 0 : 24 })
              .animation({ duration: 420, curve: Curve.EaseOut, delay: 390 })
              .onClick(() => {
                this.pageStack.pushPath({ name: 'StatisticsPage' })
              })
            }
            .width('100%')
            .padding({ left: 20, right: 20, bottom: 28 })
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#F8FAFC')
      }
      .navDestination(this.pageMap)

      // ========================
      // 启动开屏动画覆盖层（方案 A，无缝淡出并彻底销毁）
      // ========================
      if (this.splashVisible) {
        Column() {
          // 品牌 Logo 徽章
          Row() {
            Text('◆')
              .fontSize(42)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
          }
          .width(96)
          .height(96)
          .borderRadius(28)
          .linearGradient({
            angle: 135,
            colors: [['#1B6EFF', 0.0], ['#00C2FF', 1.0]]
          })
          .justifyContent(FlexAlign.Center)
          .shadow({
            radius: 28,
            color: 'rgba(27, 110, 255, 0.35)',
            offsetY: 10
          })
          .scale({ x: this.splashScale, y: this.splashScale })

          Text('鸿蒙智安')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
            .margin({ top: 24 })
            .opacity(this.splashOpacity)
            .translate({ y: this.splashOffsetY })

          Text('校园安全协同应用')
            .fontSize(15)
            .fontColor('#64748B')
            .fontWeight(FontWeight.Medium)
            .margin({ top: 8, bottom: 40 })
            .opacity(this.splashOpacity)

          // 优雅加载条（宽度随 splashProgress 生长）
          Row() {
            Row()
              .width(this.splashProgress)
              .height(4)
              .borderRadius(2)
              .backgroundColor('#1B6EFF')
          }
          .width(80)
          .height(4)
          .borderRadius(2)
          .backgroundColor('#E2E8F0')
          .opacity(this.splashOpacity)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#FFFFFF')
        .justifyContent(FlexAlign.Center)
        .onAppear(() => {
          // 入场动效
          this.getUIContext().animateTo({ duration: 550, curve: Curve.EaseOut }, () => {
            this.splashOpacity = 1;
            this.splashScale = 1;
            this.splashOffsetY = 0;
          });

          // 加载条生长动效
          this.getUIContext().animateTo({ duration: 1100, curve: Curve.EaseOut }, () => {
            this.splashProgress = 80;
          });

          // 停留后平滑淡出
          this.timerExit = setTimeout(() => {
            this.getUIContext().animateTo({ duration: 450, curve: Curve.EaseIn }, () => {
              this.splashOpacity = 0;
              this.splashScale = 0.92;
            });
          }, 1200);

          // 彻底销毁移除，不留返回栈，并触发首页卡片入场
          this.timerFinish = setTimeout(() => {
            this.getUIContext().animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
              this.homeReady = true;
            });
            this.splashVisible = false;
          }, 1700);
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
