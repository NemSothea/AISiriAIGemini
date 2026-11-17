package com.example.voicebank.voice

import com.example.voicebank.BankAction
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.math.BigDecimal

/** Same cases as iOS's VoiceCommandParserTests — keep in sync. */
class VoiceCommandParserTest {
    private val payees = listOf("Dara", "Sokha", "Vanna")
    private fun parse(text: String) = VoiceCommandParser.parse(text, payees)

    @Test fun publicCommands() {
        assertEquals(BankAction.ShowQR, parse("Show my QR"))
        assertEquals(BankAction.ShowQR, parse("I want to receive money"))
        assertEquals(BankAction.Rates, parse("What's the exchange rate"))
        assertEquals(BankAction.Rates, parse("dollar rate today"))
        assertEquals(BankAction.Branches, parse("Find nearest ATM"))
        assertEquals(BankAction.Branches, parse("where is the closest branch"))
    }

    @Test fun secureCommands() {
        assertEquals(BankAction.Balance, parse("Check my balance"))
        assertEquals(BankAction.Balance, parse("How much money do I have"))
        assertEquals(BankAction.FreezeCard, parse("Freeze my card"))
        assertEquals(BankAction.FreezeCard, parse("please lock my card"))
    }

    @Test fun transferWithPayeeAndAmount() {
        assertEquals(BankAction.Transfer("Dara", BigDecimal("20")), parse("Send 20 dollars to Dara"))
        assertEquals(BankAction.Transfer("Sokha", BigDecimal("15.50")), parse("transfer $15.50 to sokha"))
        assertEquals(BankAction.Transfer("Vanna", BigDecimal("5")), parse("pay Vanna 5"))
    }

    @Test fun transferMissingPartsStillOpensForm() {
        assertEquals(BankAction.Transfer(null, null), parse("send money"))
        assertEquals(BankAction.Transfer(null, BigDecimal("30")), parse("send 30 to Bopha"))
        assertEquals(BankAction.Transfer("Dara", null), parse("transfer to Dara"))
    }

    @Test fun payeeMatchesWholeWordOnly() {
        assertEquals(BankAction.Transfer(null, BigDecimal("10")), parse("send 10 to Darak"))
    }

    @Test fun unknownCommand() {
        assertNull(parse("what's the weather"))
        assertNull(parse(""))
    }
}
