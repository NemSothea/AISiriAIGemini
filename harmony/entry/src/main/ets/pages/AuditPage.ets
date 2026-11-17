import { AuditEvent, AuditLog } from '../model/AuditLog';
import { TierBadge } from './Common';

@ComponentV2
export struct AuditPage {
  private audit: AuditLog = AuditLog.shared();

  build() {
    NavDestination() {
      Column() {
        Button('Clear')
          .enabled(this.audit.events.length > 0)
          .margin(12)
          .onClick(() => this.audit.clear())
        if (this.audit.events.length === 0) {
          Text('No events yet.').fontColor('#888888').padding(16)
        }
        List() {
          ForEach(this.audit.events, (e: AuditEvent) => {
            ListItem() {
              Row() {
                Column() {
                  Text(e.action).fontWeight(FontWeight.Medium)
                  Text(`${e.source} · ${e.result}`).fontSize(13)
                  Text(e.timestamp.substring(0, 19).replace('T', ' ')).fontSize(12).fontColor('#888888')
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                TierBadge({ tier: e.tier })
              }.padding(16)
            }
          }, (e: AuditEvent) => e.id)
        }.layoutWeight(1)
      }
    }
    .title('Audit Log')
  }
}
