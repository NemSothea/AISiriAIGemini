import { Tier } from '../model/Models';
import { AuditLog } from '../model/AuditLog';
import { AuthGate } from '../security/AuthGate';
import { AppWindow } from '../entryability/EntryAbility';

@ComponentV2
export struct TierBadge {
  @Param tier: Tier = Tier.PUBLIC;

  private color(): string {
    switch (this.tier) {
      case Tier.AUTH_VIEW: return '#EF6C00';
      case Tier.AUTH_CONFIRM: return '#C62828';
      default: return '#2E7D32';
    }
  }

  build() {
    Text(this.tier)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.color())
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      .borderRadius(10)
      .backgroundColor('#14000000')
  }
}

/**
 * Tier 2 gate: content renders only after device auth. Window privacy mode is on while shown.
 * Re-lock on background is handled by Router.dropSecureScreens().
 */
@ComponentV2
export struct SecureGate {
  @Param title: string = '';
  @Param action: string = '';
  @Param tier: Tier = Tier.AUTH_VIEW;
  @BuilderParam content: () => void;
  @Local unlocked: boolean = false;
  @Local error: string = '';

  aboutToAppear(): void {
    this.unlock();
  }

  aboutToDisappear(): void {
    AppWindow.setPrivacy(false);
  }

  private unlock(): void {
    if (this.unlocked) {
      return;
    }
    AuthGate.authenticate(this.title).then(() => {
      this.unlocked = true;
      this.error = '';
      AppWindow.setPrivacy(true);
      AuditLog.shared().record('app', this.action, this.tier, 'auth_ok');
    }).catch((e: Error) => {
      this.error = e.message;
      AuditLog.shared().record('app', this.action, this.tier, 'auth_failed');
    });
  }

  build() {
    if (this.unlocked) {
      this.content()
    } else {
      Column({ space: 16 }) {
        Text('Locked').fontSize(22).fontWeight(FontWeight.Bold)
        Text(this.error.length > 0 ? this.error : 'Authenticate to continue.').textAlign(TextAlign.Center)
        Button('Unlock').onClick(() => this.unlock())
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding(24)
    }
  }
}
