import { userAuth } from '@kit.UserAuthenticationKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

/**
 * Tier 2: biometric (lock-screen PIN fallback). Tier 3: biometric + app PIN.
 * No bypass in any build — the device must have a lock screen and biometrics set up.
 */
export class AuthGate {
  /** Demo-only PIN. A production app would verify server-side. */
  private static readonly DEMO_PIN: string = '1234';

  static authenticate(title: string): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      try {
        const challenge: Uint8Array = cryptoFramework.createRandom().generateRandomSync(16).data;
        const authParam: userAuth.AuthParam = {
          challenge: challenge,
          authType: [userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT, userAuth.UserAuthType.PIN],
          authTrustLevel: userAuth.AuthTrustLevel.ATL3
        };
        const widgetParam: userAuth.WidgetParam = { title: title };
        const instance: userAuth.UserAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
        const callback: userAuth.IAuthCallback = {
          onResult: (result: userAuth.UserAuthResult) => {
            if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
              resolve();
            } else {
              reject(new Error(`Authentication failed (code ${result.result}).`));
            }
          }
        };
        instance.on('result', callback);
        instance.start();
      } catch (e) {
        reject(new Error(`Device authentication unavailable: ${JSON.stringify(e)}. Set a lock screen and biometrics.`));
      }
    });
  }

  static verifyPin(pin: string): void {
    if (pin !== AuthGate.DEMO_PIN) {
      throw new Error('Incorrect PIN.');
    }
  }
}
