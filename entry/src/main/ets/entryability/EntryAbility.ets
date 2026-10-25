import { AbilityConstant, common, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';


const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // Optional window styling must not block loading application content.
    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#F8FAFC', isStatusBarLightIcon: true,
        navigationBarColor: '#F8FAFC', isNavigationBarLightIcon: true
      }).catch(() => {});
      try {
        mainWindow.on('keyboardHeightChange', (height: number) => {
          AppStorage.setOrCreate('keyboardVisible', height > 0);
        });
      } catch (_) { /* Older ArkUI-X hosts use the root resize fallback. */ }
    } catch (_) { /* The startup page remains available. */ }

    const loadPage = (page: string): void => {
      windowStage.loadContent(page, (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      });
    };

    loadPage('pages/Startup');
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    AppStorage.setOrCreate('aiPrivacyEpoch', Date.now());
    AppStorage.setOrCreate('keyboardVisible', false);
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
