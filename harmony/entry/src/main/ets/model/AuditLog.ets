import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Tier } from './Models';

export interface AuditEvent {
  id: string;
  timestamp: string;
  source: string; // touch | deeplink | xiaoyi | app
  action: string;
  tier: Tier;
  result: string;
}

/**
 * Records every action and its outcome (PLAN.md §6.5). Persisted in app-private Preferences.
 * Never store balances or full account numbers here.
 */
@ObservedV2
export class AuditLog {
  private static instance?: AuditLog;
  private static readonly KEY: string = 'events';
  @Trace events: AuditEvent[] = [];
  private store?: preferences.Preferences;

  static shared(): AuditLog {
    if (!AuditLog.instance) {
      AuditLog.instance = new AuditLog();
    }
    return AuditLog.instance;
  }

  load(context: common.Context): void {
    if (this.store) {
      return;
    }
    const options: preferences.Options = { name: 'voicebank_audit' };
    this.store = preferences.getPreferencesSync(context, options);
    const raw = this.store.getSync(AuditLog.KEY, '[]') as string;
    try {
      this.events = JSON.parse(raw) as AuditEvent[];
    } catch (e) {
      this.events = [];
    }
  }

  record(source: string, action: string, tier: Tier, result: string): void {
    const event: AuditEvent = {
      id: util.generateRandomUUID(),
      timestamp: new Date().toISOString(),
      source: source,
      action: action,
      tier: tier,
      result: result
    };
    this.events = [event].concat(this.events);
    this.save();
  }

  clear(): void {
    this.events = [];
    this.save();
  }

  private save(): void {
    if (!this.store) {
      return;
    }
    this.store.putSync(AuditLog.KEY, JSON.stringify(this.events));
    this.store.flush();
  }
}
