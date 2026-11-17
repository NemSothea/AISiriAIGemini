import AppIntents

/// Zero-setup Siri phrases (English only). Every phrase must contain \(.applicationName).
/// Parameters in phrases may only be entities/enums, so Siri asks for the amount separately.
struct VoiceBankShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowQRIntent(),
            phrases: [
                "Show my \(.applicationName) QR",
                "Show my receive code in \(.applicationName)",
            ],
            shortTitle: "Receive QR",
            systemImageName: "qrcode"
        )
        AppShortcut(
            intent: ExchangeRateIntent(),
            phrases: [
                "\(.applicationName) exchange rate",
                "What's the dollar rate in \(.applicationName)",
            ],
            shortTitle: "Exchange Rate",
            systemImageName: "dollarsign.arrow.circlepath"
        )
        AppShortcut(
            intent: FindBranchIntent(),
            phrases: [
                "Find nearest \(.applicationName) ATM",
                "Find a \(.applicationName) branch",
            ],
            shortTitle: "ATM & Branches",
            systemImageName: "mappin.and.ellipse"
        )
        AppShortcut(
            intent: CheckBalanceIntent(),
            phrases: [
                "Check my balance in \(.applicationName)",
                "\(.applicationName) balance",
            ],
            shortTitle: "Balance",
            systemImageName: "lock.shield"
        )
        AppShortcut(
            intent: FreezeCardIntent(),
            phrases: [
                "Freeze my card in \(.applicationName)",
                "Lock my \(.applicationName) card",
            ],
            shortTitle: "Freeze Card",
            systemImageName: "snowflake"
        )
        AppShortcut(
            intent: PrepareTransferIntent(),
            phrases: [
                "Send money to \(\.$payee) with \(.applicationName)",
                "Transfer to \(\.$payee) in \(.applicationName)",
                "Send money with \(.applicationName)",
            ],
            shortTitle: "Transfer",
            systemImageName: "arrow.left.arrow.right"
        )
    }
}
