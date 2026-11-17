import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AuditLog } from '../model/AuditLog';
import { BankStore } from '../model/BankStore';
import { Router } from '../services/Router';

const TAG = 'VoiceBank';

export default class EntryAbility extends UIAbility {
  private mainWindow?: window.Window;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    BankStore.shared().load(this.context);
    AuditLog.shared().load(this.context);
    AppWindow.ability = this;
    this.handleWant(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handleWant(want);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.getMainWindow().then((w: window.Window) => {
      this.mainWindow = w;
    });
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
      }
    });
  }

  onBackground(): void {
    // Secure screens must re-authenticate when the user comes back.
    Router.shared().dropSecureScreens();
  }

  /** Hides window content from screenshots / recents while sensitive data is shown. */
  setPrivacy(enabled: boolean): void {
    this.mainWindow?.setWindowPrivacyMode(enabled).catch((e: Error) => {
      hilog.warn(0x0000, TAG, 'setWindowPrivacyMode failed: %{public}s', JSON.stringify(e));
    });
  }

  private handleWant(want: Want): void {
    if (want.uri && want.uri.startsWith('voicebank://')) {
      Router.shared().openUri(want.uri, 'deeplink');
    }
  }
}

/** Lets pages toggle window privacy mode without holding a context reference. */
export class AppWindow {
  static ability?: EntryAbility;

  static setPrivacy(enabled: boolean): void {
    AppWindow.ability?.setPrivacy(enabled);
  }
}
