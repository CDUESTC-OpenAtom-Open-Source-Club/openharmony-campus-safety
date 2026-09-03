import { EventPage } from './EventPage';
import { EventDetailPage } from './EventDetailPage';
import { TaskPage } from './TaskPage';
import { ReportPage } from './ReportPage';
import { StatisticsPage } from './StatisticsPage';
import {
  SecurityEvent,
  EventPriority,
  EventStatus
} from '../model/SecurityEvent';
import {
  Task,
  TaskStatus
} from '../model/Task';
import { EventService } from '../service/EventService';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  private pageStack: NavPathStack = new NavPathStack();

  @State private currentTab: string = 'Index';

  // 开屏动画控制
  @State private splashVisible: boolean = true;
  @State private splashOpacity: number = 0;
  @State private splashScale: number = 0.6;
  @State private splashOffsetY: number = 20;
  @State private splashProgress: number = 0;
  @State private splashStepText: string = '正在初始化安防引擎...';

  // 首页入场动效
  @State private homeReady: boolean = false;

  // 数据
  @State private events: SecurityEvent[] = EventService.getAllEvents();
  @State private tasks: Task[] = EventService.getAllTasks();

  private timerEnter: number = -1;
  private timerExit: number = -1;
  private timerFinish: number = -1;
  private timerProgress1: number = -1;
  private timerProgress2: number = -1;
  private timerProgress3: number = -1;

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
    if (this.timerProgress1 !== -1) {
      clearTimeout(this.timerProgress1);
    }
    if (this.timerProgress2 !== -1) {
      clearTimeout(this.timerProgress2);
    }
    if (this.timerProgress3 !== -1) {
      clearTimeout(this.timerProgress3);
    }
  }

  private navigateTo(name: string): void {
    this.currentTab = name;
    if (name === 'Index') {
      this.pageStack.clear();
      return;
    }
    this.pageStack.clear();
    this.pageStack.pushPath({ name: name });
  }

  private getUrgentCount(): number {
    const urgent: SecurityEvent[] = this.events.filter(
      (event: SecurityEvent) =>
        event.priority === EventPriority.URGENT ||
        event.priority === EventPriority.HIGH
    );
    return urgent.length;
  }

  private getPendingTaskCount(): number {
    const pending: Task[] = this.tasks.filter(
      (task: Task) =>
        task.status === TaskStatus.PENDING ||
        task.status === TaskStatus.PROCESSING
    );
    return pending.length;
  }

  private getStatusColor(status: EventStatus): string {
    if (status === EventStatus.PENDING) {
      return '#EA580C';
    } else if (status === EventStatus.CONFIRMED) {
      return '#1B6EFF';
    } else if (status === EventStatus.PROCESSING) {
      return '#6366F1';
    } else if (status === EventStatus.COMPLETED) {
      return '#16A34A';
    }
    return '#64748B';
  }

  @Builder
  pageMap(name: string) {
    if (name === 'EventPage') {
      NavDestination() {
        EventPage({
          pageStack: this.pageStack
        })
      }
      .title('安全事件')
      .hideTitleBar(true)
      .systemTransition(NavigationSystemTransitionType.FADE)
    } else if (name === 'EventDetailPage') {
      NavDestination() {
        EventDetailPage({
          pageStack: this.pageStack
        })
      }
      .title('事件详情')
      .hideTitleBar(true)
      .systemTransition(NavigationSystemTransitionType.FADE)
    } else if (name === 'TaskPage') {
      NavDestination() {
        TaskPage({
          pageStack: this.pageStack
        })
      }
      .title('处置任务')
      .hideTitleBar(true)
      .systemTransition(NavigationSystemTransitionType.FADE)
    } else if (name === 'ReportPage') {
      NavDestination() {
        ReportPage({
          pageStack: this.pageStack
        })
      }
      .title('隐患上报')
      .hideTitleBar(true)
      .systemTransition(NavigationSystemTransitionType.FADE)
    } else if (name === 'StatisticsPage') {
      NavDestination() {
        StatisticsPage({
          pageStack: this.pageStack
        })
      }
      .title('数据统计')
      .hideTitleBar(true)
      .systemTransition(NavigationSystemTransitionType.FADE)
    }
  }

  @Builder
  bentoCard(
    title: string,
    desc: string,
    badge: string,
    badgeColor: string,
    iconBg: string,
    iconColor: string,
    icon: Resource,
    route: string
  ) {
    Column() {
      Row() {
        Row() {
          Image(icon)
            .width(22)
            .height(22)
            .fillColor(iconColor)
        }
        .width(42)
        .height(42)
        .borderRadius(14)
        .backgroundColor(iconBg)
        .justifyContent(FlexAlign.Center)

        Blank()

        Text(badge)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(badgeColor)
          .backgroundColor('#F8FAFC')
          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
          .borderRadius(8)
      }
      .width('100%')
      .margin({ bottom: 10 })

      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
        .width('100%')

      Text(desc)
        .fontSize(11)
        .fontColor('#94A3B8')
        .width('100%')
        .margin({ top: 3 })
    }
    .width('100%')
    .padding(14)
    .borderRadius(18)
    .backgroundColor(Color.White)
    .border({ width: 1, color: '#E2E8F0' })
    .shadow({ radius: 10, color: 'rgba(15,23,42,0.04)', offsetY: 2 })
    .onClick(() => {
      this.navigateTo(route);
    })
  }

  @Builder
  tabItem(key: string, label: string, icon: Resource) {
    Column() {
      Image(icon)
        .width(20)
        .height(20)
        .fillColor(this.currentTab === key ? '#1B6EFF' : '#94A3B8')
      Text(label)
        .fontSize(10)
        .fontWeight(this.currentTab === key ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTab === key ? '#1B6EFF' : '#94A3B8')
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.navigateTo(key);
    })
  }

  private startSplash(): void {
    this.getUIContext().animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
      this.splashOpacity = 1;
      this.splashScale = 1;
      this.splashOffsetY = 0;
    });

    // 进度条从 0 丝滑连续生长到 100%，避免分段跳变
    this.getUIContext().animateTo({ duration: 1500, curve: Curve.EaseOut }, () => {
      this.splashProgress = 100;
    });

    this.timerProgress1 = setTimeout(() => {
      this.splashStepText = '连接校园物联网感知网格...';
    }, 400);
    this.timerProgress2 = setTimeout(() => {
      this.splashStepText = '校验 428 个安防巡检节点...';
    }, 900);
    this.timerProgress3 = setTimeout(() => {
      this.splashStepText = '鸿蒙智安守护网络已就绪';
    }, 1450);

    this.timerExit = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 450, curve: Curve.EaseIn }, () => {
        this.splashOpacity = 0;
        this.splashScale = 0.92;
      });
    }, 1850);

    this.timerFinish = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
        this.homeReady = true;
      });
      this.splashVisible = false;
    }, 2350);
  }

  private skipSplash(): void {
    if (this.timerProgress1 !== -1) {
      clearTimeout(this.timerProgress1);
    }
    if (this.timerProgress2 !== -1) {
      clearTimeout(this.timerProgress2);
    }
    if (this.timerProgress3 !== -1) {
      clearTimeout(this.timerProgress3);
    }
    if (this.timerExit !== -1) {
      clearTimeout(this.timerExit);
    }
    if (this.timerFinish !== -1) {
      clearTimeout(this.timerFinish);
    }
    this.homeReady = true;
    this.splashVisible = false;
  }

  build() {
    Stack() {
      Column() {
        Navigation(this.pageStack) {
          Scroll() {
            Column() {
              // ========================
              // 顶部品牌与安全状态
              // ========================
              Row() {
                Row() {
                  Image($r('app.media.ic_shield_check'))
                    .width(22)
                    .height(22)
                    .fillColor(Color.White)
                }
                .width(42)
                .height(42)
                .borderRadius(14)
                .linearGradient({
                  angle: 135,
                  colors: [['#2563EB', 0.0], ['#6366F1', 1.0]]
                })
                .justifyContent(FlexAlign.Center)
                .shadow({ radius: 12, color: 'rgba(37,99,235,0.3)', offsetY: 4 })

                Column() {
                  Row() {
                    Text('鸿蒙智安')
                      .fontSize(20)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#0F172A')

                    Text('NEXT')
                      .fontSize(9)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#2563EB')
                      .backgroundColor('#DBEAFE')
                      .padding({ left: 5, right: 5, top: 2, bottom: 2 })
                      .borderRadius(6)
                      .margin({ left: 6 })
                  }

                  Text('智慧校园 · 安全协同平台')
                    .fontSize(11)
                    .fontColor('#64748B')
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 10 })

                Blank()

                Row({ space: 5 }) {
                  Row()
                    .width(7)
                    .height(7)
                    .borderRadius(4)
                    .backgroundColor('#10B981')
                  Text('守护中')
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#047857')
                }
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .borderRadius(16)
                .backgroundColor('#ECFDF5')
                .border({ width: 1, color: '#A7F3D0' })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 16, bottom: 12 })

              // ========================
              // 智慧安防总览卡片
              // ========================
              Column() {
                Row() {
                  Text('综合安全指数 99.4')
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(12)
                    .backgroundColor('rgba(255,255,255,0.18)')
                    .border({ width: 1, color: 'rgba(255,255,255,0.25)' })

                  Blank()

                  Text('今日实时播报')
                    .fontSize(11)
                    .fontColor('rgba(255,255,255,0.75)')
                }
                .width('100%')
                .margin({ bottom: 12 })

                Row() {
                  Column() {
                    Text(this.events.length.toString())
                      .fontSize(20)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Color.White)
                    Text('安全事件')
                      .fontSize(10)
                      .fontColor('rgba(255,255,255,0.75)')
                      .margin({ top: 2 })
                  }
                  .layoutWeight(1)

                  Column() {
                    Text(this.getUrgentCount().toString())
                      .fontSize(20)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#FCD34D')
                    Text('高危预警')
                      .fontSize(10)
                      .fontColor('rgba(255,255,255,0.75)')
                      .margin({ top: 2 })
                  }
                  .layoutWeight(1)
                  .border({
                    width: { left: 1, right: 1 },
                    color: 'rgba(255,255,255,0.15)'
                  })

                  Column() {
                    Text(this.getPendingTaskCount().toString())
                      .fontSize(20)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#6EE7B7')
                    Text('在办任务')
                      .fontSize(10)
                      .fontColor('rgba(255,255,255,0.75)')
                      .margin({ top: 2 })
                  }
                  .layoutWeight(1)
                }
                .width('100%')
                .padding({ top: 10, bottom: 10 })

                Text('全校 428 个安防巡检网格运行正常')
                  .fontSize(11)
                  .fontColor('rgba(255,255,255,0.8)')
                  .width('100%')
                  .margin({ top: 8 })
              }
              .width('100%')
              .padding(16)
              .borderRadius(20)
              .linearGradient({
                angle: 135,
                colors: [['#2563EB', 0.0], ['#1E40AF', 0.6], ['#312E81', 1.0]]
              })
              .shadow({ radius: 18, color: 'rgba(37,99,235,0.28)', offsetY: 8 })
              .opacity(this.homeReady ? 1 : 0)
              .translate({ y: this.homeReady ? 0 : 16 })
              .animation({ duration: 420, curve: Curve.EaseOut, delay: 80 })
              .margin({ left: 16, right: 16 })

              // ========================
              // 24H 保卫处一键求助
              // ========================
              Row() {
                Row({ space: 6 }) {
                  Row()
                    .width(7)
                    .height(7)
                    .borderRadius(4)
                    .backgroundColor('#EF4444')
                  Text('24H 校园保卫处总机')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1E293B')
                }

                Blank()

                Text('一键求助')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#DC2626')
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .borderRadius(14)
                  .backgroundColor('#FEF2F2')
                  .onClick(() => {
                    promptAction.showToast({ message: '已模拟拨通保卫处应急调度室' });
                  })
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 12, bottom: 12 })
              .borderRadius(16)
              .backgroundColor(Color.White)
              .border({ width: 1, color: '#E2E8F0' })
              .shadow({ radius: 8, color: 'rgba(15,23,42,0.03)', offsetY: 2 })
              .opacity(this.homeReady ? 1 : 0)
              .translate({ y: this.homeReady ? 0 : 16 })
              .animation({ duration: 420, curve: Curve.EaseOut, delay: 160 })
              .margin({ left: 16, right: 16, top: 12 })

              // ========================
              // 业务协同 Bento 网格
              // ========================
              Row() {
                Text('业务协同与处置中心')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#64748B')
                Blank()
                Text('协同闭环率 100%')
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#2563EB')
              }
              .width('100%')
              .padding({ left: 18, right: 18, top: 18, bottom: 8 })

              Row() {
                Column({ space: 10 }) {
                  this.bentoCard(
                    '安全事件',
                    '核查、确权与指派',
                    this.events.length.toString() + ' 件',
                    '#2563EB',
                    '#EFF6FF',
                    '#2563EB',
                    $r('app.media.ic_event'),
                    'EventPage'
                  )
                  this.bentoCard(
                    '隐患上报',
                    '随手拍与一键提交',
                    '秒级直达',
                    '#059669',
                    '#ECFDF5',
                    '#059669',
                    $r('app.media.ic_report'),
                    'ReportPage'
                  )
                }
                .layoutWeight(1)

                Column({ space: 10 }) {
                  this.bentoCard(
                    '处置任务',
                    '巡检维保现场接单',
                    this.getPendingTaskCount().toString() + ' 待办',
                    '#D97706',
                    '#FFF7ED',
                    '#D97706',
                    $r('app.media.ic_task'),
                    'TaskPage'
                  )
                  this.bentoCard(
                    '数据统计',
                    '安全全景量化分析',
                    '态势洞察',
                    '#7C3AED',
                    '#FAF5FF',
                    '#7C3AED',
                    $r('app.media.ic_stats'),
                    'StatisticsPage'
                  )
                }
                .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 16, right: 16 })
              .opacity(this.homeReady ? 1 : 0)
              .translate({ y: this.homeReady ? 0 : 20 })
              .animation({ duration: 460, curve: Curve.EaseOut, delay: 240 })

              // ========================
              // 最新流转事件
              // ========================
              Row() {
                Text('最新流转事件')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#334155')
                Blank()
                Text('查看全部 ›')
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#2563EB')
                  .onClick(() => {
                    this.navigateTo('EventPage');
                  })
              }
              .width('100%')
              .padding({ left: 18, right: 18, top: 18, bottom: 8 })

              Column({ space: 10 }) {
                if (this.events.length === 0) {
                  Row() {
                    Text('暂无流转事件，等待首次发现')
                      .fontSize(12)
                      .fontColor('#94A3B8')
                  }
                  .width('100%')
                  .padding(14)
                  .borderRadius(16)
                  .backgroundColor(Color.White)
                  .border({ width: 1, color: '#E2E8F0' })
                  .justifyContent(FlexAlign.Center)
                } else {
                  ForEach(this.events.slice(0, 2), (event: SecurityEvent) => {
                    Row() {
                      Row()
                        .width(8)
                        .height(8)
                        .borderRadius(4)
                        .backgroundColor('#2563EB')

                      Column() {
                        Text(event.title)
                          .fontSize(13)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#334155')
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text(event.location)
                          .fontSize(11)
                          .fontColor('#94A3B8')
                          .margin({ top: 3 })
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)
                      .margin({ left: 10 })

                      Text(event.status)
                        .fontSize(10)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.getStatusColor(event.status))
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .borderRadius(8)
                        .backgroundColor('#F8FAFC')
                    }
                    .width('100%')
                    .padding(12)
                    .borderRadius(16)
                    .backgroundColor(Color.White)
                    .border({ width: 1, color: '#E2E8F0' })
                    .shadow({ radius: 8, color: 'rgba(15,23,42,0.03)', offsetY: 2 })
                    .onClick(() => {
                      EventService.setSelectedEventId(event.id);
                      this.currentTab = 'EventPage';
                      this.pageStack.pushPath({ name: 'EventDetailPage' });
                    })
                  }, (event: SecurityEvent) => event.id)
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 20 })
              .opacity(this.homeReady ? 1 : 0)
              .translate({ y: this.homeReady ? 0 : 20 })
              .animation({ duration: 460, curve: Curve.EaseOut, delay: 320 })
            }
            .width('100%')
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#F8FAFC')
        }
        .width('100%')
        .layoutWeight(1)
        .navDestination(this.pageMap)

        // ========================
        // 底部 TabBar
        // ========================
        Row() {
          this.tabItem('Index', '首页', $r('app.media.ic_home'))
          this.tabItem('EventPage', '事件', $r('app.media.ic_event'))

          Column() {
            Row() {
              Image($r('app.media.ic_report'))
                .width(20)
                .height(20)
                .fillColor(Color.White)
            }
            .width(46)
            .height(46)
            .borderRadius(23)
            .linearGradient({
              angle: 135,
              colors: [['#2563EB', 0.0], ['#6366F1', 1.0]]
            })
            .justifyContent(FlexAlign.Center)
            .shadow({ radius: 12, color: 'rgba(37,99,235,0.35)', offsetY: 4 })

            Text('上报')
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor('#2563EB')
              .margin({ top: 2 })
          }
          .width(56)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.navigateTo('ReportPage');
          })

          this.tabItem('TaskPage', '任务', $r('app.media.ic_task'))
          this.tabItem('StatisticsPage', '统计', $r('app.media.ic_stats'))
        }
        .width('100%')
        .height(62)
        .backgroundColor(Color.White)
        .border({ width: 1, color: '#E2E8F0' })
      }
      .width('100%')
      .height('100%')

      // ========================
      // 启动开屏动画
      // ========================
      if (this.splashVisible) {
        Column() {
          // 跳过按钮
          Row() {
            Blank()
            Text('跳过 ›')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor('rgba(255,255,255,0.8)')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(14)
              .backgroundColor('rgba(255,255,255,0.1)')
              .border({ width: 1, color: 'rgba(255,255,255,0.15)' })
              .onClick(() => {
                this.skipSplash();
              })
          }
          .width('100%')
          .padding({ top: 56, right: 20 })

          // 品牌徽章 + 雷达光环
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(128)
              .height(128)
              .borderRadius(64)
              .border({ width: 1, color: 'rgba(96,165,250,0.4)' })
              .scale({ x: this.splashScale, y: this.splashScale })

            Column()
              .width(104)
              .height(104)
              .borderRadius(52)
              .border({ width: 1, color: 'rgba(129,140,248,0.3)' })
              .scale({ x: this.splashScale, y: this.splashScale })

            Row() {
              Image($r('app.media.ic_shield'))
                .width(44)
                .height(44)
                .fillColor(Color.White)
            }
            .width(92)
            .height(92)
            .borderRadius(28)
            .linearGradient({
              angle: 135,
              colors: [['#3B82F6', 0.0], ['#6366F1', 1.0]]
            })
            .justifyContent(FlexAlign.Center)
            .shadow({ radius: 24, color: 'rgba(59,130,246,0.45)', offsetY: 10 })
            .scale({ x: this.splashScale, y: this.splashScale })
            .opacity(this.splashOpacity)
          }
          .width(140)
          .height(140)

          // 品牌名称
          Row() {
            Text('鸿蒙智安')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
            Text('NEXT')
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor('rgba(255,255,255,0.18)')
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(6)
              .margin({ left: 8 })
          }
          .margin({ top: 24 })
          .opacity(this.splashOpacity)
          .translate({ y: this.splashOffsetY })

          Text('智慧校园 · 安全敏捷协同平台')
            .fontSize(12)
            .fontColor('rgba(255,255,255,0.65)')
            .margin({ top: 8, bottom: 28 })
            .opacity(this.splashOpacity)
            .translate({ y: this.splashOffsetY })

          // 进度条与状态文案
          Column() {
            Row() {
              Row()
                .width(this.splashProgress * 1.8)
                .height(5)
                .borderRadius(3)
                .linearGradient({
                  angle: 90,
                  colors: [['#60A5FA', 0.0], ['#818CF8', 1.0]]
                })
            }
            .width(180)
            .height(5)
            .borderRadius(3)
            .backgroundColor('rgba(255,255,255,0.12)')

            Row() {
              Text(this.splashStepText)
                .fontSize(10)
                .fontColor('rgba(255,255,255,0.55)')
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(Math.round(this.splashProgress).toString() + '%')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor('#93C5FD')
            }
            .width(180)
            .margin({ top: 8 })
          }
          .opacity(this.splashOpacity)

          // 底部认证
          Text('HarmonyOS NEXT 驱动 · 敏捷响应 闭环协同')
            .fontSize(10)
            .fontColor('rgba(255,255,255,0.35)')
            .margin({ top: 90 })
        }
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#020617', 0.0], ['#0F172A', 0.55], ['#1E1B4B', 1.0]]
        })
        .justifyContent(FlexAlign.Center)
        .onAppear(() => {
          this.startSplash();
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
