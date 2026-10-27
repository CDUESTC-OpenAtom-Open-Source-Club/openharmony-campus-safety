import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { StartupService } from '../service/StartupService';
import { AppTheme } from '../common/AppTheme';

@Entry
@Component
struct Startup {
  @State private message: string = '正在读取本机账号';
  @State private waiting: boolean = true;
  @State private failed: boolean = false;
  private active: boolean = false;
  private watchdog: number = -1;
  private progress: number = -1;
  private revision: number = 0;

  aboutToAppear(): void {
    this.active = true;
    this.start();
  }

  aboutToDisappear(): void {
    this.active = false;
    this.revision++;
    this.clearTimers();
  }

  private clearTimers(): void {
    if (this.watchdog !== -1) clearTimeout(this.watchdog);
    if (this.progress !== -1) clearInterval(this.progress);
  }

  private async start(): Promise<void> {
    const version: number = ++this.revision;
    this.clearTimers();
    this.waiting = true;
    this.failed = false;
    this.message = StartupService.stage;
    this.progress = setInterval(() => {
      if (this.active && !this.failed) this.message = StartupService.stage;
    }, 300);
    this.watchdog = setTimeout(() => {
      if (!this.active || version !== this.revision) return;
      this.failed = true;
      this.waiting = false;
      this.message = StartupService.stage + '耗时过长。请检查设备存储空间，重试或重新启动应用；不会清除原有数据。';
      this.clearTimers();
    }, 12000);
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      // Keep the application-level storage scope used before the Startup page
      // was introduced. An ability context can open a different module directory.
      await StartupService.initialize(context.getApplicationContext());
      if (!this.active || version !== this.revision) return;
      this.clearTimers();
      await router.replaceUrl({ url: 'pages/Index' });
    } catch (_) {
      if (!this.active || version !== this.revision) return;
      this.clearTimers();
      this.waiting = false;
      this.failed = true;
      this.message = StartupService.stage + '失败。请重试，原有数据未清除。';
    }
  }

  build() {
    Column({ space: 24 }) {
      Text('鸿蒙智安').fontSize(30).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
      if (this.waiting) { LoadingProgress().width(36).height(36) }
      Text(this.message).fontSize(16).fontColor(AppTheme.inkSoft).textAlign(TextAlign.Center)
      Text('启动仅加载本机数据，无需连接云端服务').fontSize(13).fontColor(AppTheme.muted)
      if (this.failed) { Button('重试初始化').height(48).onClick(() => this.start()) }
    }.width('100%').height('100%').padding(28)
      .justifyContent(FlexAlign.Center).backgroundColor(AppTheme.canvas)
  }
}
