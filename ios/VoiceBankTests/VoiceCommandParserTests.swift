import Foundation
import Testing
@testable import VoiceBank

/// Same cases as Android's VoiceCommandParserTest — keep in sync.
struct VoiceCommandParserTests {
    private let payees = ["Dara", "Sokha", "Vanna"]

    private func parse(_ text: String) -> BankAction? {
        VoiceCommandParser.parse(text, payeeNames: payees)
    }

    @Test func publicCommands() {
        #expect(parse("Show my QR") == .showQR)
        #expect(parse("I want to receive money") == .showQR)
        #expect(parse("What's the exchange rate") == .rates)
        #expect(parse("dollar rate today") == .rates)
        #expect(parse("Find nearest ATM") == .branches)
        #expect(parse("where is the closest branch") == .branches)
    }

    @Test func secureCommands() {
        #expect(parse("Check my balance") == .balance)
        #expect(parse("How much money do I have") == .balance)
        #expect(parse("Freeze my card") == .freezeCard)
        #expect(parse("please lock my card") == .freezeCard)
    }

    @Test func transferWithPayeeAndAmount() {
        #expect(parse("Send 20 dollars to Dara") == .transfer(payee: "Dara", amount: 20))
        #expect(parse("transfer $15.50 to sokha") == .transfer(payee: "Sokha", amount: Decimal(string: "15.50")))
        #expect(parse("pay Vanna 5") == .transfer(payee: "Vanna", amount: 5))
    }

    @Test func transferMissingPartsStillOpensForm() {
        #expect(parse("send money") == .transfer(payee: nil, amount: nil))
        #expect(parse("send 30 to Bopha") == .transfer(payee: nil, amount: 30)) // unknown payee → not prefilled
        #expect(parse("transfer to Dara") == .transfer(payee: "Dara", amount: nil))
    }

    @Test func payeeMatchesWholeWordOnly() {
        // "Darak" must not match saved payee "Dara".
        #expect(parse("send 10 to Darak") == .transfer(payee: nil, amount: 10))
    }

    @Test func unknownCommand() {
        #expect(parse("what's the weather") == nil)
        #expect(parse("") == nil)
    }
}
