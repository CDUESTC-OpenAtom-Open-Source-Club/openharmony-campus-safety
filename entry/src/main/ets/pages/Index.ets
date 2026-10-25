import { EventPage } from './EventPage';
import { EventDetailPage } from './EventDetailPage';
import { TaskPage } from './TaskPage';
import { ReportPage } from './ReportPage';
import { StatisticsPage } from './StatisticsPage';
import { EmergencyContactPage } from './EmergencyContactPage';
import { StudentSchedulePage } from './StudentSchedulePage';
import { AccountPage } from './AccountPage';
import { ProfilePage } from './ProfilePage';
import { AiAssistantPage } from './AiAssistantPage';
import { CountdownManagePage } from './CountdownManagePage';
import { CountdownEvent } from '../model/CountdownEvent';
import { CountdownService } from '../service/CountdownService';
import { Course } from '../model/Course';
import { ScheduleService } from '../service/ScheduleService';
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
import { EmergencyContactService } from '../service/EmergencyContactService';
import { AccountService } from '../service/AccountService';
import { AppPermission, PermissionService } from '../service/PermissionService';
import { User, UserRole } from '../model/User';
import { promptAction, curves } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { AppTheme } from '../common/AppTheme';

@Entry
@Component
struct Index {
  private pageStack: NavPathStack = new NavPathStack();

  @State private currentTab: string = 'Index';
  @State private pressedTab: string = '';
  @State private reportPressed: boolean = false;
  @State private loggedIn: boolean = AccountService.isLoggedIn();
  @StorageLink('emergencyPhone') private emergencyPhone: string = '';

  // 开屏动画控制：保留现有启动流程，但视觉改为安静的品牌引导。
  @State private splashVisible: boolean = true;
  @State private splashOpacity: number = 0;
  @State private splashScale: number = 0.92;
  @State private splashOffsetY: number = 18;
  @State private splashProgress: number = 0;
  @State private splashStepText: string = '正在初始化安防引擎...';

  @State private homeReady: boolean = false;
  @State private events: SecurityEvent[] = EventService.getAllEvents();
  @State private tasks: Task[] = EventService.getAllTasks();
  @State private scheduleCourses: Course[] = [];
  @State private showSchedulePage: boolean = false;
  @State private scheduleCardPressed: boolean = false;
  @State private countdownEvents: CountdownEvent[] = [];
  @State private countdownCardPressed: boolean = false;

  private timerEnter: number = -1;
  private timerExit: number = -1;
  private timerFinish: number = -1;
  private timerProgress1: number = -1;
  private timerProgress2: number = -1;
  private timerProgress3: number = -1;

  aboutToAppear(): void {
    this.refreshEmergencyPhone();
    this.refreshSchedule();
    this.refreshCountdowns();
  }

  aboutToDisappear(): void {
    if (this.timerEnter !== -1) clearTimeout(this.timerEnter);
    if (this.timerExit !== -1) clearTimeout(this.timerExit);
    if (this.timerFinish !== -1) clearTimeout(this.timerFinish);
    if (this.timerProgress1 !== -1) clearTimeout(this.timerProgress1);
    if (this.timerProgress2 !== -1) clearTimeout(this.timerProgress2);
    if (this.timerProgress3 !== -1) clearTimeout(this.timerProgress3);
  }

  onPageShow(): void {
    this.refreshEmergencyPhone();
    this.refreshSchedule();
    this.refreshCountdowns();
    this.loggedIn = AccountService.isLoggedIn();
  }

  private navigateTo(name: string): void {
    if (!this.loggedIn && name !== 'Index' && name !== 'ProfilePage') {
      this.showLoginRequiredDialog();
      return;
    }
    if (name === 'SchedulePage') {
      this.currentTab = name;
      this.showSchedulePage = true;
      return;
    }
    if (name === 'TaskPage' && !this.can(AppPermission.VIEW_ASSIGNED_TASKS)) {
      promptAction.showToast({ message: '当前账号暂无处置任务权限' });
      return;
    }
    if (name === 'StatisticsPage' && !this.can(AppPermission.VIEW_STATISTICS)) {
      promptAction.showToast({ message: '当前账号暂无数据统计权限' });
      return;
    }
    if (name !== 'ReportPage' && name !== 'CountdownManagePage') {
      this.currentTab = name;
    }
    if (name === 'Index') {
      this.events = EventService.getAllEvents().slice();
      this.tasks = EventService.getAllTasks().slice();
      this.pageStack.clear();
      return;
    }
    this.pageStack.clear();
    this.pageStack.pushPath({ name: name });
  }

  // 中间的上报按钮是快捷动作：打开上报流程，但不修改底部导航选中态。
  private openReportFlow(): void {
    if (!this.loggedIn) {
      this.showLoginRequiredDialog();
      return;
    }
    this.pageStack.clear();
    this.pageStack.pushPath({ name: 'ReportPage' });
  }

  private can(permission: AppPermission): boolean {
    return PermissionService.can(AccountService.getCurrentUser(), permission);
  }

  private currentUser(): User | null {
    return AccountService.getCurrentUser();
  }

  private isPersonalUser(): boolean {
    const user: User | null = this.currentUser();
    return user?.role === UserRole.STUDENT || user?.role === UserRole.TEACHER;
  }

  private completeLogout(): void {
    this.pageStack.clear();
    this.currentTab = 'Index';
    this.events = [];
    this.tasks = [];
    this.loggedIn = false;
  }

  private showLoginRequiredDialog(): void {
    AlertDialog.show({
      title: '登录后即可使用该功能',
      message: '访客模式支持浏览首页。请先登录；如没有账号，可在“我”页面注册普通成员账号。',
      primaryButton: {
        value: '去登录 / 注册',
        action: () => this.navigateTo('ProfilePage')
      },
      secondaryButton: { value: '暂不登录', action: () => {} }
    });
  }

  private refreshSchedule(): void {
    const context = getContext(this) as common.Context;
    ScheduleService.getCourses(context).then((items: Course[]) => {
      this.scheduleCourses = items;
    }).catch((err: Error) => {
      console.error('ScheduleService load failed: ' + err.message);
    });
  }

  private refreshCountdowns(): void {
    CountdownService.getEvents(getContext(this) as common.Context).then((items: CountdownEvent[]) => {
      this.countdownEvents = items.slice();
    }).catch((error: Error) => {
      console.error('CountdownService load failed: ' + error.message);
    });
  }

  private refreshEmergencyPhone(): void {
    const context = getContext(this) as common.Context;
    EmergencyContactService.getPhone(context).then((value: string) => {
      this.emergencyPhone = value;
    }).catch((err: Error) => {
      console.error('EmergencyContactService load failed: ' + err.message);
    });
  }

  private showEmergencyConfigDialog(): void {
    if (!this.loggedIn) {
      this.showLoginRequiredDialog();
      return;
    }
    AlertDialog.show({
      title: '尚未配置有效紧急联系电话',
      message: '请先配置 6—20 位有效电话号码。该号码仅保存在本机，不代表已接入学校或真实应急平台。',
      primaryButton: {
        value: '去配置',
        action: () => this.pageStack.pushPath({ name: 'EmergencyContactPage' })
      },
      secondaryButton: { value: '取消', action: () => {} }
    });
  }

  private getConfiguredEmergencyPhone(): string {
    const phone: string = this.emergencyPhone.trim();
    return EmergencyContactService.isValidPhone(phone) ? EmergencyContactService.normalizePhone(phone) : '';
  }

  private openEmergencySms(): void {
    if (!this.loggedIn) {
      this.showLoginRequiredDialog();
      return;
    }
    const phone: string = this.getConfiguredEmergencyPhone();
    if (phone === '') {
      this.showEmergencyConfigDialog();
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    const want: Want = {
      action: 'ohos.want.action.sendSms',
      uri: 'sms:' + phone + '?body=' + encodeURIComponent('校园安全紧急求助：请立即联系我。')
    };
    context.startAbility(want).catch(() => {
      promptAction.showToast({ message: '无法打开短信编辑界面，请手动联系 ' + phone });
    });
  }

  private openEmergencyDialer(): void {
    if (!this.loggedIn) {
      this.showLoginRequiredDialog();
      return;
    }
    const phone: string = this.getConfiguredEmergencyPhone();
    if (phone === '') {
      this.showEmergencyConfigDialog();
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    const want: Want = { action: 'ohos.want.action.dial', uri: 'tel:' + phone };
    context.startAbility(want).catch(() => {
      promptAction.showToast({ message: '无法打开拨号界面，请手动拨打 ' + phone });
    });
  }

  private getUrgentCount(): number {
    return this.events.filter((event: SecurityEvent) =>
    event.priority === EventPriority.URGENT || event.priority === EventPriority.HIGH
    ).length;
  }

  private getPendingTaskCount(): number {
    return this.tasks.filter((task: Task) =>
    task.status === TaskStatus.PENDING || task.status === TaskStatus.PROCESSING
    ).length;
  }

  private getHealthScore(): number {
    let penalty: number = 0;
    this.events.forEach((event: SecurityEvent) => {
      if (event.status === EventStatus.PENDING || event.status === EventStatus.CONFIRMED) {
        penalty += event.priority === EventPriority.URGENT ? 18 :
          event.priority === EventPriority.HIGH ? 12 :
            event.priority === EventPriority.MEDIUM ? 8 : 4;
      } else if (event.status === EventStatus.PROCESSING) {
        penalty += 4;
      }
    });
    this.tasks.forEach((task: Task) => {
      if (task.status === TaskStatus.PENDING) penalty += 6;
      else if (task.status === TaskStatus.PROCESSING) penalty += 3;
    });
    return Math.round(Math.max(55, Math.min(100, 100 - penalty)) * 10) / 10;
  }

  private getStatusColor(status: EventStatus): string {
    if (status === EventStatus.PENDING) return AppTheme.amber;
    if (status === EventStatus.CONFIRMED) return AppTheme.info;
    if (status === EventStatus.PROCESSING) return AppTheme.accent;
    if (status === EventStatus.COMPLETED) return AppTheme.success;
    return AppTheme.muted;
  }

  @Builder
  pageMap(name: string) {
    if (name === 'EventPage') {
      NavDestination() { EventPage({ pageStack: this.pageStack }) }
      .title('安全事件').hideTitleBar(true).systemTransition(NavigationSystemTransitionType.FADE);
    } else if (name === 'EventDetailPage') {
      NavDestination() { EventDetailPage({ pageStack: this.pageStack }) }
      .title('事件详情').hideTitleBar(true).systemTransition(NavigationSystemTransitionType.FADE);
    } else if (name === 'TaskPage') {
      NavDestination() { TaskPage({ pageStack: this.pageStack }) }
      .title('处置任务').hideTitleBar(true).systemTransition(NavigationSystemTransitionType.FADE);
    } else if (name === 'ReportPage') {
      NavDestination() {
        ReportPage({
          pageStack: this.pageStack,
          onReported: (): void => { this.events = EventService.getAllEvents().slice(); }
        })
      }
      .title('隐患上报').hideTitleBar(true).systemTransition(NavigationSystemTransitionType.FADE);
    } else if (name === 'StatisticsPage') {
      NavDestination() { StatisticsPage({ pageStack: this.pageStack }) }
      .title('数据统计').hideTitleBar(true).systemTransition(NavigationSystemTransitionType.FADE);
    } else if (name === 'EmergencyContactPage') {
      NavDestination() { EmergencyContactPage({ pageStack: this.pageStack }) }
      .title('应急联系方式').hideTitleBar(true).systemTransition(NavigationSystemTransitionType.FADE);
    } else if (name === 'AccountPage') {
      NavDestination() {
        AccountPage({ pageStack: this.pageStack, onLogout: (): void => this.completeLogout() })
      }
      .title('账号与安全').hideTitleBar(true).systemTransition(NavigationSystemTransitionType.FADE);
    } else if (name === 'ProfilePage') {
      NavDestination() {
        ProfilePage({
          onLogin: (): void => {
            this.loggedIn = true;
            this.events = EventService.getAllEvents().slice();
            this.tasks = EventService.getAllTasks().slice();
          },
          onLogout: (): void => this.completeLogout(),
          onManageAccount: (): void => this.navigateTo('AccountPage'),
          onOpenAi: (): void => this.navigateTo('AiAssistantPage')
        })
      }
      .title('我').hideTitleBar(true).systemTransition(NavigationSystemTransitionType.FADE);
    } else if (name === 'CountdownManagePage') {
      NavDestination() {
        CountdownManagePage({
          pageStack: this.pageStack,
          onChanged: (): void => this.refreshCountdowns()
        })
      }
      .title('管理倒计时').hideTitleBar(true).systemTransition(NavigationSystemTransitionType.FADE);
    } else if (name === 'AiAssistantPage') {
      NavDestination() {
        AiAssistantPage({ pageStack: this.pageStack })
      }
      .title('AI 助手').hideTitleBar(true).systemTransition(NavigationSystemTransitionType.FADE);
    }
  }

  private getHomeCountdowns(): CountdownEvent[] {
    return CountdownService.getHomeList(this.countdownEvents);
  }

  private isNearestCountdown(id: string): boolean {
    const items: CountdownEvent[] = this.getHomeCountdowns();
    return items.length > 0 && items[0].id === id;
  }

  @Builder
  private countdownTimelineRow(event: CountdownEvent) {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(2)
          .height(42)
          .backgroundColor('#E8EFF6')
        Row()
          .width(10)
          .height(10)
          .border({ width: 2, color: '#85B7EB' })
          .borderRadius(5)
          .backgroundColor(this.isNearestCountdown(event.id) ? '#DCEBFF' : '#FFFFFF')
          .shadow(this.isNearestCountdown(event.id) ? { radius: 7, color: 'rgba(37, 99, 235, 0.22)', offsetY: 0 } : { radius: 0, color: '#FFFFFF', offsetY: 0 })
      }
      .width(10)
      .height(42)

      Column({ space: 3 }) {
        Text(event.name)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(CountdownService.formatDateLine(event))
          .fontSize(10.5)
          .fontColor('#9CA3AF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row({ space: 3 }) {
        Text(CountdownService.dayText(CountdownService.daysLeft(event.date)))
          .fontSize(CountdownService.daysLeft(event.date) <= 1 ? 12 : 18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2563EB')
        if (CountdownService.daysLeft(event.date) > 1) {
          Text('天')
            .fontSize(10.5)
            .fontColor('#9CA3AF')
        }
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .height(46)
  }

  @Builder
  private countdownCard() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(15)
            .height(15)
            .border({ width: 1.5, color: '#378ADD' })
            .borderRadius(8)
          Row()
            .width(1.5)
            .height(5)
            .backgroundColor('#378ADD')
            .translate({ x: -1, y: -2 })
          Row()
            .width(4)
            .height(1.5)
            .backgroundColor('#378ADD')
            .translate({ x: 1, y: 1 })
        }
        .width(28)
        .height(28)
        .borderRadius(9)
        .backgroundColor('#E6F1FB')

        Text('考试倒计时')
          .fontSize(14)
          .fontWeight(600)
          .fontColor('#1F2937')

        Blank()

        Text('管理 ›')
          .fontSize(11.5)
          .fontColor('#378ADD')
          .padding({ left: 8, right: 2, top: 6, bottom: 6 })
          .onClick(() => this.navigateTo('CountdownManagePage'))
      }
      .width('100%')

      if (this.getHomeCountdowns().length === 0) {
        Column({ space: 9 }) {
          Text('还没有添加倒计时')
            .fontSize(12)
            .fontColor('#8A97AF')
          Text('添加第一个倒计时')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .borderRadius(18)
            .backgroundColor('#185FA5')
            .onClick(() => this.navigateTo('CountdownManagePage'))
        }
        .width('100%')
        .padding({ top: 18, bottom: 18 })
        .border({ width: 1.5, color: '#D7E4F1', style: BorderStyle.Dashed })
        .borderRadius(12)
      } else {
        Column({ space: 0 }) {
          ForEach(this.getHomeCountdowns(), (event: CountdownEvent) => {
            this.countdownTimelineRow(event)
          })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(15)
    .backgroundColor('#FFFFFF')
    .shadow({ radius: this.countdownCardPressed ? 6 : 10, color: this.countdownCardPressed ? 'rgba(24, 60, 110, 0.035)' : 'rgba(24, 60, 110, 0.05)', offsetY: this.countdownCardPressed ? 1 : 2 })
    .scale({ x: this.countdownCardPressed ? 0.985 : 1, y: this.countdownCardPressed ? 0.985 : 1 })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.countdownCardPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.countdownCardPressed = false;
      }
    })
  }

  @Builder
  private serviceTile(
    title: string,
    desc: string,
    badge: string,
    icon: Resource,
    tone: string,
    softTone: string,
    route: string
  ) {
    Column({ space: 10 }) {
      Row() {
        Row() {
          Image(icon).width(20).height(20).fillColor(tone)
        }
        .width(40).height(40).borderRadius(12).backgroundColor(softTone).justifyContent(FlexAlign.Center)
        Blank()
        Text(badge)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(tone)
          .backgroundColor(softTone)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(6)
      }
      .width('100%')

      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.ink)
        .width('100%')

      Text(desc)
        .fontSize(11)
        .fontColor(AppTheme.muted)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(132)
    .padding(16)
    .borderRadius(AppTheme.radiusMedium)
    .backgroundColor(AppTheme.surface)
    .border({ width: 1, color: AppTheme.line })
    .shadow({ radius: 10, color: AppTheme.cardShadow, offsetY: 3 })
    .onClick(() => this.navigateTo(route))
  }

  @Builder
  private homeMetric(label: string, value: number) {
    Column({ space: 6 }) {
      Text(label).fontSize(11).fontColor(AppTheme.muted)
      Text(value.toString()).fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
    }.layoutWeight(1)
  }

  @Builder
  private quickAction(title: string, desc: string, icon: Resource, tone: string, route: string) {
    Column({ space: 10 }) {
      Image(icon).width(27).height(27).fillColor(Color.White)
      Text(title).fontSize(13).fontWeight(FontWeight.Medium).fontColor(Color.White)
    }.layoutWeight(1).height(102).borderRadius(17).justifyContent(FlexAlign.Center)
    .linearGradient({ angle: 160, colors: [[tone, 0], ['#1677FF', 1]] })
    .shadow({ radius: 8, color: AppTheme.glowBlue, offsetY: 4 })
    .onClick(() => this.navigateTo(route))
  }

  private getHomeCourses(): Course[] {
    return this.scheduleCourses
      .filter((course: Course) => course.weekday === this.getCurrentWeekday())
      .sort((a: Course, b: Course) => a.startPeriod - b.startPeriod)
      .slice(0, 3);
  }

  private getCurrentWeekday(): number {
    const day: number = new Date().getDay();
    return day === 0 ? 7 : day;
  }

  private getCurrentWeekdayLabel(): string {
    return '周' + ['一', '二', '三', '四', '五', '六', '日'][this.getCurrentWeekday() - 1];
  }

  @Builder
  private emergencyStrip() {
    Row() {
      Row() {
        Row().width(8).height(8).borderRadius(4).backgroundColor(AppTheme.danger)
      }
      .width(28).height(28).borderRadius(8).backgroundColor(AppTheme.dangerSoft)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 10 })

      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text('应急响应专线').fontSize(13).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
          Text('快速联动').fontSize(9).fontColor(AppTheme.danger)
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .borderRadius(4).backgroundColor(AppTheme.dangerSoft)
        }
        Text(this.emergencyPhone === '' ? '未配置，点击设置应急联系电话' : this.emergencyPhone)
          .fontSize(11)
          .fontColor(this.emergencyPhone === '' ? AppTheme.muted : AppTheme.inkSoft)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .onClick(() => this.navigateTo('EmergencyContactPage'))

      Row({ space: 8 }) {
        Button('求助短信')
          .type(ButtonType.Normal).height(32).fontSize(11).fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.danger)
          .backgroundColor(AppTheme.dangerSoft).borderRadius(8).onClick(() => this.openEmergencySms())
        Button('一键拨打')
          .type(ButtonType.Normal).height(32).fontSize(11).fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(AppTheme.danger).borderRadius(8).onClick(() => this.openEmergencyDialer())
      }
      .margin({ left: 10 })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .borderRadius(AppTheme.radiusMedium)
    .backgroundColor(AppTheme.surface)
    .border({ width: 1, color: AppTheme.line })
    .shadow({ radius: 8, color: AppTheme.cardShadow, offsetY: 2 })
  }

  @Builder
  private courseRow(course: Course, active: boolean) {
    Row() {
      Column({ space: 2 }) {
        Text(course.startTime).fontSize(13).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
        Text('第' + course.startPeriod + '-' + course.endPeriod + '节').fontSize(10).fontColor(AppTheme.muted)
      }
      .width(62)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 3 }) {
        Text(course.name).fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.ink)
        Text('教学点 · ' + course.location).fontSize(11).fontColor(AppTheme.muted)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(active ? '进行中' : '待上课')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(active ? AppTheme.success : AppTheme.info)
        .backgroundColor(active ? AppTheme.successSoft : AppTheme.infoSoft)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(6)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 1 }, color: AppTheme.line })
  }

  @Builder
  private scheduleSection() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 2 }) {
          Text('今日课程安排').fontSize(15).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
          Text(this.getCurrentWeekdayLabel() + ' · 共 ' + this.getHomeCourses().length + ' 门课程')
            .fontSize(11).fontColor(AppTheme.muted)
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text('完整课表 ›')
          .fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.accent)
          .onClick(() => this.navigateTo('SchedulePage'))
      }
      .width('100%')

      Column() {
        if (this.getHomeCourses().length === 0) {
          Text('今日暂无课程安排')
            .fontSize(12).fontColor(AppTheme.muted).width('100%')
            .textAlign(TextAlign.Center).padding({ top: 18, bottom: 18 })
        } else {
          ForEach(this.getHomeCourses(), (course: Course, index: number) => {
            this.courseRow(course, index === 0)
          }, (course: Course) => course.id)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .borderRadius(AppTheme.radiusMedium)
      .backgroundColor(AppTheme.surface)
      .border({ width: 1, color: AppTheme.line })
      .onClick(() => this.navigateTo('SchedulePage'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 20 })
  }

  @Builder
  private recentEvents() {
    Column({ space: 10 }) {
      Row() {
        Text('最新动态')
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
        Blank()
        Text('更多 ›').fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.accent)
          .onClick(() => this.navigateTo('EventPage'))
      }
      .width('100%')

      if (this.events.length === 0) {
        Row() {
          Text('当前暂无流转事件，校园运行平稳').fontSize(12).fontColor(AppTheme.muted)
        }
        .width('100%').height(68).justifyContent(FlexAlign.Center)
        .borderRadius(AppTheme.radiusMedium).backgroundColor(AppTheme.surface).border({ width: 1, color: AppTheme.line })
      } else {
        ForEach(this.events.slice(0, 3), (event: SecurityEvent) => {
          Row() {
            Row().width(7).height(7).borderRadius(4).backgroundColor(this.getStatusColor(event.status))
            Column({ space: 4 }) {
              Text(event.title).fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.ink)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(event.location + ' · ' + event.reportTime).fontSize(10).fontColor(AppTheme.muted)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 10 })

            Text(event.status)
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getStatusColor(event.status))
              .backgroundColor(AppTheme.surfaceMuted)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .borderRadius(6)
          }
          .width('100%').padding(14).borderRadius(AppTheme.radiusMedium).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.line })
          .shadow({ radius: 6, color: AppTheme.cardShadow, offsetY: 2 })
          .margin({ bottom: 8 })
          .onClick(() => {
            if (!this.loggedIn) {
              this.showLoginRequiredDialog();
              return;
            }
            EventService.setSelectedEventId(event.id);
            this.currentTab = 'EventPage';
            this.pageStack.pushPath({ name: 'EventDetailPage' });
          })
        }, (event: SecurityEvent) => event.id)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16 })
  }

  @Builder
  private tabIcon(key: string, selected: boolean) {
    Stack() {
      if (key === 'Index') {
        // 首页：屋顶线 + 房屋，选中时房屋实心。
        Row()
          .width(12).height(1.8).borderRadius(2)
          .backgroundColor(selected ? '#185FA5' : '#9CA3AF')
          .rotate({ angle: -42 })
          .position({ x: 1.5, y: 6.5 })
        Row()
          .width(12).height(1.8).borderRadius(2)
          .backgroundColor(selected ? '#185FA5' : '#9CA3AF')
          .rotate({ angle: 42 })
          .position({ x: 9.5, y: 6.5 })
        Row()
          .width(14).height(11)
          .borderRadius(2)
          .border({ width: selected ? 0 : 1.8, color: selected ? '#185FA5' : '#9CA3AF' })
          .backgroundColor(selected ? '#185FA5' : '#FFFFFF')
          .position({ x: 4.5, y: 10 })
        Row()
          .width(4).height(6)
          .borderRadius(1)
          .border({ width: selected ? 0 : 1, color: '#9CA3AF' })
          .backgroundColor(selected ? '#FFFFFF' : '#FFFFFF')
          .position({ x: 9.5, y: 15 })
      } else if (key === 'EventPage') {
        // 记录：文档外框和三条内容线。
        Row()
          .width(15).height(19)
          .borderRadius(2.5)
          .border({ width: selected ? 0 : 1.8, color: selected ? '#185FA5' : '#9CA3AF' })
          .backgroundColor(selected ? '#185FA5' : '#FFFFFF')
          .position({ x: 4, y: 2 })
        Row().width(8).height(1.6).borderRadius(1)
          .backgroundColor(selected ? '#FFFFFF' : '#9CA3AF')
          .position({ x: 7.5, y: 7 })
        Row().width(8).height(1.6).borderRadius(1)
          .backgroundColor(selected ? '#FFFFFF' : '#9CA3AF')
          .position({ x: 7.5, y: 11 })
        Row().width(6).height(1.6).borderRadius(1)
          .backgroundColor(selected ? '#FFFFFF' : '#9CA3AF')
          .position({ x: 7.5, y: 15 })
      } else if (key === 'TaskPage') {
        // 任务：三项清单，选中时勾选框实心。
        Row().width(5).height(5).borderRadius(1.2)
          .border({ width: selected ? 0 : 1.6, color: selected ? '#185FA5' : '#9CA3AF' })
          .backgroundColor(selected ? '#185FA5' : '#FFFFFF')
          .position({ x: 2.5, y: 3 })
        Row().width(5).height(5).borderRadius(1.2)
          .border({ width: selected ? 0 : 1.6, color: selected ? '#185FA5' : '#9CA3AF' })
          .backgroundColor(selected ? '#185FA5' : '#FFFFFF')
          .position({ x: 2.5, y: 9 })
        Row().width(5).height(5).borderRadius(1.2)
          .border({ width: selected ? 0 : 1.6, color: selected ? '#185FA5' : '#9CA3AF' })
          .backgroundColor(selected ? '#185FA5' : '#FFFFFF')
          .position({ x: 2.5, y: 15 })
        Row().width(12).height(1.6).borderRadius(1)
          .backgroundColor(selected ? '#185FA5' : '#9CA3AF')
          .position({ x: 9, y: 4.8 })
        Row().width(12).height(1.6).borderRadius(1)
          .backgroundColor(selected ? '#185FA5' : '#9CA3AF')
          .position({ x: 9, y: 10.8 })
        Row().width(12).height(1.6).borderRadius(1)
          .backgroundColor(selected ? '#185FA5' : '#9CA3AF')
          .position({ x: 9, y: 16.8 })
      } else {
        // 我的：头像和肩部轮廓，选中时采用实心人形。
        Row()
          .width(7.5).height(7.5).borderRadius(4)
          .border({ width: selected ? 0 : 1.8, color: selected ? '#185FA5' : '#9CA3AF' })
          .backgroundColor(selected ? '#185FA5' : '#FFFFFF')
          .position({ x: 7.75, y: 1.5 })
        Row()
          .width(17).height(8)
          .borderRadius(8)
          .border({ width: selected ? 0 : 1.8, color: selected ? '#185FA5' : '#9CA3AF' })
          .backgroundColor(selected ? '#185FA5' : '#FFFFFF')
          .position({ x: 3, y: 13 })
      }
    }
    .width(23).height(23)
    .scale({ x: this.pressedTab === key ? 0.94 : 1, y: this.pressedTab === key ? 0.94 : 1 })
    .animation({ duration: 220, curve: curves.cubicBezierCurve(0.34, 1.4, 0.64, 1) })
  }

  @Builder
  private tabItem(key: string, label: string) {
    Column({ space: 3 }) {
      this.tabIcon(key, this.currentTab === key)
      Text(label)
        .fontSize(10.5)
        .fontWeight(this.currentTab === key ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.currentTab === key ? '#185FA5' : '#9CA3AF')
    }
    .layoutWeight(1)
    .height(58)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .animation({ duration: 200, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedTab = key;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedTab = '';
      }
    })
    .onClick(() => this.navigateTo(key))
  }

  @Builder
  private reportActionItem() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(52).height(52).borderRadius(26)
          .linearGradient({ angle: 140, colors: [['#4C8DF6', 0], ['#2563EB', 1]] })
          .border({ width: 4, color: '#FFFFFF' })
        Row()
          .width(20).height(3).borderRadius(2)
          .backgroundColor('#FFFFFF')
        Row()
          .width(3).height(20).borderRadius(2)
          .backgroundColor('#FFFFFF')
      }
      // 裁剪整个图标容器为圆形；不对矩形 Stack 投影，避免圆外出现浅色方框。
      .width(52).height(52).borderRadius(26).clip(true)
      .translate({ y: -30 })
      .scale({ x: this.reportPressed ? 0.94 : 1, y: this.reportPressed ? 0.94 : 1 })
      .animation({ duration: 220, curve: curves.cubicBezierCurve(0.34, 1.4, 0.64, 1) })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.reportPressed = true;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.reportPressed = false;
        }
      })
      .onClick(() => this.openReportFlow())

      Text('上报')
        .fontSize(10.5)
        .fontWeight(FontWeight.Medium)
        .fontColor('#185FA5')
        .translate({ y: -14 })
    }
    .layoutWeight(1)
    .height(58)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }

  private startSplash(): void {
    this.getUIContext().animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
      this.splashOpacity = 1;
      this.splashScale = 1;
      this.splashOffsetY = 0;
    });
    this.getUIContext().animateTo({ duration: 1500, curve: Curve.EaseOut }, () => {
      this.splashProgress = 100;
    });
    this.timerProgress1 = setTimeout(() => this.splashStepText = '正在加载本地安全数据与规则库...', 400);
    this.timerProgress2 = setTimeout(() => this.splashStepText = '正在连接网格化安防协同控制台...', 900);
    this.timerProgress3 = setTimeout(() => this.splashStepText = '智安核心引擎就绪 · 防护在线', 1450);
    this.timerExit = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 450, curve: Curve.EaseIn }, () => {
        this.splashOpacity = 0;
        this.splashScale = 0.96;
      });
    }, 1850);
    this.timerFinish = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 500, curve: Curve.EaseOut }, () => this.homeReady = true);
      this.splashVisible = false;
    }, 2350);
  }

  private skipSplash(): void {
    if (this.timerProgress1 !== -1) clearTimeout(this.timerProgress1);
    if (this.timerProgress2 !== -1) clearTimeout(this.timerProgress2);
    if (this.timerProgress3 !== -1) clearTimeout(this.timerProgress3);
    if (this.timerExit !== -1) clearTimeout(this.timerExit);
    if (this.timerFinish !== -1) clearTimeout(this.timerFinish);
    this.homeReady = true;
    this.splashVisible = false;
  }

  build() {
    Stack() {
      Column() {
        if (this.showSchedulePage) {
          StudentSchedulePage({ showSchedulePage: $showSchedulePage })
            .width('100%').layoutWeight(1)
        } else {
          Navigation(this.pageStack) {
            Column() {
              Scroll() {
                Column({ space: 0 }) {
                  Row() {
                    Column({ space: 5 }) {
                      Text(new Date().getHours() < 12 ? '上午好，' : new Date().getHours() < 18 ? '下午好，' : '晚上好，')
                        .fontSize(21).fontWeight(FontWeight.Medium).fontColor(AppTheme.ink)
                      Text('让我们共同守护校园安全').fontSize(12).fontColor(AppTheme.inkSoft)
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    Image($r('app.media.ic_account')).width(24).height(24).fillColor(AppTheme.inkSoft)
                      .onClick(() => this.navigateTo('ProfilePage'))
                  }.width('100%').padding({ left: 18, right: 18, top: 16, bottom: 18 })
                  Column({ space: 12 }) {
                    Row({ space: 18 }) {
                      Image($r('app.media.safety_crest')).width(112).height(126).objectFit(ImageFit.Contain)
                      Column({ space: 6 }) {
                        Text('校园安全指数').fontSize(14).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
                        Row({ space: 8 }) {
                          Text(this.getHealthScore().toString()).fontSize(46).fontWeight(FontWeight.Bold).fontColor(AppTheme.accent)
                          Text(this.getHealthScore() >= 90 ? '良好' : '关注').fontSize(11).fontColor(AppTheme.success)
                            .backgroundColor(AppTheme.successSoft).padding(4).borderRadius(5)
                        }
                        Text('共同守护 · 平安校园').fontSize(11).fontColor(AppTheme.muted)
                      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    }.width('100%').padding(16).borderRadius(16)
                    .linearGradient({ angle: 130, colors: [['#FFFFFF', 0], ['#DFEDFF', 1]] })
                    Row() {
                      this.homeMetric('待处理事件', this.events.filter((e: SecurityEvent) => e.status === EventStatus.PENDING).length)
                      Divider().vertical(true).height(32).color(AppTheme.line)
                      this.homeMetric('处理中', this.events.filter((e: SecurityEvent) => e.status === EventStatus.PROCESSING).length)
                      Divider().vertical(true).height(32).color(AppTheme.line)
                      this.homeMetric('今日上报', this.events.filter((e: SecurityEvent) => e.reportTime.startsWith(new Date().getFullYear() + '-' + ('0' + (new Date().getMonth() + 1)).slice(-2) + '-' + ('0' + new Date().getDate()).slice(-2))).length)
                    }.width('100%').padding({ top: 14, bottom: 14 }).backgroundColor(AppTheme.surface).borderRadius(12)
                    Row({ space: 12 }) {
                      Column({ space: 6 }) {
                        Text('AI')
                          .fontSize(13)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(Color.White)
                      }
                      .width(44)
                      .height(44)
                      .borderRadius(14)
                      .backgroundColor(AppTheme.accent)
                      .justifyContent(FlexAlign.Center)

                      Column({ space: 4 }) {
                        Text('智安 AI 助手')
                          .fontSize(15)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(AppTheme.ink)
                        Text('日常 · 学习 · 校园安全')
                          .fontSize(11)
                          .fontColor(AppTheme.muted)
                        Text('功能预留，点击进入')
                          .fontSize(10)
                          .fontColor(AppTheme.accent)
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)

                      Text('›')
                        .fontSize(26)
                        .fontColor(AppTheme.accent)
                    }
                    .width('100%')
                    .padding({ left: 14, right: 14, top: 13, bottom: 13 })
                    .borderRadius(16)
                    .backgroundColor(AppTheme.surface)
                    .border({ width: 1, color: AppTheme.line })
                    .shadow({ radius: 8, color: AppTheme.cardShadow, offsetY: 2 })
                    .onClick(() => this.navigateTo('AiAssistantPage'))
                    Row({ space: 10 }) {
                      this.quickAction('隐患上报', '', $r('app.media.ic_report'), '#26BBF6', 'ReportPage')
                      this.quickAction('一键求助', '', $r('app.media.ic_phone'), '#747DFF', 'EmergencyContactPage')
                      this.quickAction('我的任务', '', $r('app.media.ic_task'), '#318FFF', 'TaskPage')
                    }.width('100%')
                  }.width('100%').padding({ left: 16, right: 16 })
                  this.recentEvents()
                  Row() {
                    Row({ space: 13 }) {
                      Stack({ alignContent: Alignment.Center }) {
                        Row()
                          .width(19)
                          .height(16)
                          .border({ width: 1.5, color: '#378ADD' })
                          .borderRadius(2.8)

                        Row()
                          .width(19)
                          .height(1.5)
                          .backgroundColor('#378ADD')
                          .translate({ y: -2 })

                        Row({ space: 7 }) {
                          Row()
                            .width(1.5)
                            .height(4)
                            .borderRadius(1)
                            .backgroundColor('#378ADD')
                          Row()
                            .width(1.5)
                            .height(4)
                            .borderRadius(1)
                            .backgroundColor('#378ADD')
                        }
                        .width(10)
                        .justifyContent(FlexAlign.SpaceBetween)
                        .translate({ y: -8 })

                        Row()
                          .width(2.5)
                          .height(2.5)
                          .borderRadius(2)
                          .backgroundColor('#378ADD')
                          .translate({ y: 2 })
                      }
                      .width(40)
                      .height(40)
                      .borderRadius(12)
                      .backgroundColor('#E6F1FB')

                      Column({ space: 3 }) {
                        Text('我的课表')
                          .fontSize(14)
                          .fontWeight(600)
                          .fontColor('#1F2937')
                        Text('查看本周课程安排')
                          .fontSize(11)
                          .fontColor('#9CA3AF')
                      }
                      .layoutWeight(1)
                      .alignItems(HorizontalAlign.Start)

                      Text('›')
                        .fontSize(15)
                        .fontColor('#378ADD')
                    }
                    .width('100%')
                    .padding({ left: 15, right: 15, top: 13, bottom: 13 })
                    .borderRadius(15)
                    .backgroundColor('#FFFFFF')
                    .shadow({
                      radius: this.scheduleCardPressed ? 6 : 10,
                      color: this.scheduleCardPressed ? 'rgba(24, 60, 110, 0.04)' : 'rgba(24, 60, 110, 0.06)',
                      offsetY: this.scheduleCardPressed ? 1 : 2
                    })
                    .scale({ x: this.scheduleCardPressed ? 0.985 : 1, y: this.scheduleCardPressed ? 0.985 : 1 })
                    .onTouch((event: TouchEvent) => {
                      if (event.type === TouchType.Down) {
                        this.scheduleCardPressed = true;
                      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                        this.scheduleCardPressed = false;
                      }
                    })
                    .onClick(() => this.navigateTo('SchedulePage'))
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, bottom: 12 })
                  Column() {
                    this.countdownCard()
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, bottom: 16 })
                }
                .width('100%')
                .padding({ bottom: 96 })
              }
              .width('100%').layoutWeight(1).backgroundColor(AppTheme.canvas).scrollBar(BarState.Off)
            }
            .width('100%').height('100%')
          }
          .width('100%').layoutWeight(1).hideTitleBar(true).navDestination(this.pageMap)

          // 底部导航栏：四个页面入口 + 中间凸起的上报快捷动作。
          Row() {
            this.tabItem('Index', '首页')
            this.tabItem('EventPage', this.isPersonalUser() ? '记录' : '事件')
            this.reportActionItem()
            this.tabItem('TaskPage', '任务')
            this.tabItem('ProfilePage', '我')
          }
          .width('100%').height(58).backgroundColor('#FFFFFF')
          .border({ width: { top: 1 }, color: 'rgba(17, 24, 39, 0.08)' })
          .shadow({ radius: 12, color: 'rgba(24, 60, 110, 0.05)', offsetY: -2 })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
          .clip(false)
        }
      }
      .width('100%').height('100%').backgroundColor(AppTheme.canvas)

      // 开屏以静态秩序和细线构图呈现品牌，不再使用旧版科技光晕。
      if (this.splashVisible) {
        Column() {
          Row() {
            Blank()
            Text('跳过')
              .fontSize(12).fontColor(AppTheme.accent)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .borderRadius(AppTheme.radiusSmall).border({ width: 1, color: AppTheme.lineStrong })
              .backgroundColor(AppTheme.surface)
              .onClick(() => this.skipSplash())
          }
          .width('100%').padding({ top: 52, right: 20 })

          Column({ space: 20 }) {
            Stack() {
              Row()
                .width(112).height(112).borderRadius(AppTheme.radiusLarge)
                .border({ width: 1, color: AppTheme.lineStrong })
              Row()
                .width(94).height(94).borderRadius(AppTheme.radiusMedium)
                .backgroundColor(AppTheme.accentSoft)
              Row() {
                Image($r('app.media.ic_shield'))
                  .width(38).height(38).fillColor(Color.White)
              }
              .width(68).height(68).borderRadius(AppTheme.radiusMedium).backgroundColor(AppTheme.accent)
              .justifyContent(FlexAlign.Center)
              .shadow({ radius: 16, color: AppTheme.glowBlue, offsetY: 4 })
            }
            .scale({ x: this.splashScale, y: this.splashScale })
            .opacity(this.splashOpacity)

            Column({ space: 9 }) {
              Text('鸿蒙智安')
                .fontSize(30)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ink)
                .letterSpacing(2)
              Text('CAMPUS SAFETY WORKBENCH')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.bronze)
                .letterSpacing(1)
              Text('守秩序之常，护求学之安')
                .fontSize(13)
                .fontColor(AppTheme.inkSoft)
            }
            .opacity(this.splashOpacity).translate({ y: this.splashOffsetY })

            Column({ space: 10 }) {
              Row() {
                Row().width(this.splashProgress * 1.8).height(3).borderRadius(2).backgroundColor(AppTheme.accent)
              }
              .width(180).height(3).borderRadius(2).backgroundColor(AppTheme.surfaceSubtle)

              Row() {
                Text(this.splashStepText).fontSize(10).fontColor(AppTheme.muted).layoutWeight(1)
                Text(Math.round(this.splashProgress) + '%').fontSize(11).fontWeight(FontWeight.Bold).fontColor(AppTheme.accent)
              }
              .width(180)
            }
            .opacity(this.splashOpacity).translate({ y: this.splashOffsetY })
          }
          .justifyContent(FlexAlign.Center)

          Blank()
          Text('端侧守护 · 可信协同 · 日常安宁')
            .fontSize(10).fontColor(AppTheme.muted).margin({ bottom: 48 })
        }
        .width('100%').height('100%').backgroundColor(AppTheme.canvas)
        .justifyContent(FlexAlign.Center)
        .onAppear(() => this.startSplash())
      }
    }
    .width('100%').height('100%').backgroundColor(AppTheme.canvas)
  }
}
