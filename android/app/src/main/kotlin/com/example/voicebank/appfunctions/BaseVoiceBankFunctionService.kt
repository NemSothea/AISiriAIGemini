package com.example.voicebank.appfunctions

import android.app.PendingIntent
import android.content.Intent
import androidx.annotation.RequiresApi
import androidx.appfunctions.AppFunctionDeclaration
import androidx.appfunctions.AppFunctionElementNotFoundException
import androidx.appfunctions.AppFunctionInvalidArgumentException
import androidx.appfunctions.AppFunctionSerializable
import androidx.appfunctions.AppFunctionService
import androidx.appfunctions.AppFunctionServiceEntryPoint
import androidx.appfunctions.AppFunctionStringValueConstraint
import com.example.voicebank.BankAction
import com.example.voicebank.MainActivity
import com.example.voicebank.model.BankRepository
import com.example.voicebank.model.Tier
import com.example.voicebank.voiceBank
import java.math.BigDecimal
import java.math.RoundingMode

// Gemini / Android MCP entry points for demo commands D1–D5 (PLAN.md §1).
// Rules (same as iOS Siri):
//  - Tier 1 functions may return public data.
//  - Tier 2–3 functions NEVER return balances, transactions or account numbers.
//    They return a PendingIntent; the user continues in the app behind biometrics (+PIN for Tier 3).

/** A public exchange rate (demo data, not live). */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class ExchangeRateResult(
    /** Currency pair, e.g. "USD/KHR". */
    val pair: String,
    /** Price at which the bank buys the base currency. */
    val buy: Double,
    /** Price at which the bank sells the base currency. */
    val sell: Double,
    /** ISO-8601 timestamp the demo rate applies to. */
    val asOf: String,
)

/** A public ATM or branch location (fictional demo data). */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class BranchResult(
    /** Display name of the location. */
    val name: String,
    /** "atm" or "branch". */
    val type: String,
    /** Street address. */
    val address: String,
    /** Distance in kilometres from the demo origin. */
    val distanceKm: Double,
)

/** A saved payee. Contains no account number. */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class PayeeResult(
    /** Identifier to pass to prepareTransfer. */
    val payeeId: String,
    /** Payee display name. */
    val name: String,
)

@RequiresApi(36)
@AppFunctionServiceEntryPoint(
    serviceName = "VoiceBankFunctionService",
    appFunctionXmlFileName = "voicebank_function_service",
)
abstract class BaseVoiceBankFunctionService : AppFunctionService() {

    private val bank: BankRepository get() = voiceBank.bank

    private fun audit(action: String, tier: Tier, result: String) =
        voiceBank.audit.record("agent", action, tier, result)

    /** Explicit intent into our own activity; immutable and one-shot. */
    private fun openApp(action: BankAction, requestCode: Int): PendingIntent {
        val intent = Intent(this, MainActivity::class.java)
            .setAction(Intent.ACTION_VIEW)
            .setData(action.toUri())
            .putExtra(MainActivity.EXTRA_SOURCE, "agent")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    // ---- Tier 1 ----

    /**
     * Get the bank's current demo exchange rates (public information, safe to tell the user).
     *
     * @return All available demo exchange rates, including USD/KHR.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun getExchangeRate(): List<ExchangeRateResult> {
        audit("getRates", Tier.PUBLIC, "answered")
        return bank.rates.map {
            ExchangeRateResult(it.pair, it.buy.toDouble(), it.sell.toDouble(), it.asOf.toString())
        }
    }

    /**
     * Find the nearest ATMs and branches (public information, safe to tell the user).
     *
     * @param type Filter: "atm", "branch", or "any".
     * @return Locations sorted by distance, nearest first.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun findNearestBranches(
        @AppFunctionStringValueConstraint(enumValues = ["atm", "branch", "any"])
        type: String,
    ): List<BranchResult> {
        audit("findBranch", Tier.PUBLIC, "answered")
        return bank.nearestBranches()
            .filter { type == "any" || it.first.type == type }
            .map { (b, km) -> BranchResult(b.name, b.type, b.address, km) }
    }

    /**
     * Open the user's receive-money QR code so someone can pay them.
     *
     * @return A PendingIntent that opens the QR screen. Launch it.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun showReceiveQr(): PendingIntent {
        audit("showQR", Tier.PUBLIC, "opened_app")
        return openApp(BankAction.ShowQR, 1)
    }

    // ---- Tier 2 ----

    /**
     * Open the balance screen. The balance is NOT returned; the user sees it in the app after biometric verification.
     *
     * @return A PendingIntent that opens the secure balance screen. Launch it.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun openBalance(): PendingIntent {
        audit("checkBalance", Tier.AUTH_VIEW, "opened_app")
        return openApp(BankAction.Balance, 2)
    }

    /**
     * Open card controls so the user can freeze their card. The card is NOT frozen by this call;
     * the user confirms in the app with biometrics.
     *
     * @return A PendingIntent that opens the secure card controls screen. Launch it.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun requestCardFreeze(): PendingIntent {
        audit("freezeCard", Tier.AUTH_VIEW, "opened_app")
        return openApp(BankAction.FreezeCard, 3)
    }

    // ---- Tier 3 ----

    /**
     * Find a saved payee by name. Required before prepareTransfer.
     *
     * @param query Payee name, e.g. "Dara". Must not be blank.
     * @return Matching saved payees (name and id only).
     * @throws AppFunctionElementNotFoundException If no saved payee matches. Ask the user to check the name; new payees cannot be added by voice.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun findPayee(query: String): List<PayeeResult> {
        if (query.isBlank()) throw AppFunctionInvalidArgumentException("Payee name cannot be empty.")
        val matches = bank.payees.filter { it.name.contains(query.trim(), ignoreCase = true) }
        if (matches.isEmpty()) {
            audit("findPayee", Tier.AUTH_CONFIRM, "not_found")
            throw AppFunctionElementNotFoundException("No saved payee named \"$query\". Ask the user to check the name.")
        }
        audit("findPayee", Tier.AUTH_CONFIRM, "found")
        return matches.map { PayeeResult(it.id, it.name) }
    }

    /**
     * Prepare a transfer to a saved payee. Nothing is sent: the app opens a review screen where the user
     * confirms with biometrics and PIN. Do not tell the user the transfer is complete.
     *
     * @param payeeId Identifier returned by findPayee.
     * @param amountUsd Amount in US dollars, greater than 0 and at most 100.
     * @return A PendingIntent that opens the prefilled transfer review screen. Launch it.
     * @throws AppFunctionElementNotFoundException If payeeId is not a saved payee. Call findPayee first.
     * @throws AppFunctionInvalidArgumentException If the amount is not between 0 and 100 USD. Ask the user for a valid amount.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun prepareTransfer(payeeId: String, amountUsd: Double): PendingIntent {
        val payee = bank.payees.firstOrNull { it.id == payeeId }
            ?: run {
                audit("prepareTransfer", Tier.AUTH_CONFIRM, "unknown_payee")
                throw AppFunctionElementNotFoundException("Unknown payeeId. Call findPayee first.")
            }
        val amount = BigDecimal.valueOf(amountUsd).setScale(2, RoundingMode.HALF_UP)
        if (amount <= BigDecimal.ZERO || amount > BankRepository.TRANSFER_CAP) {
            audit("prepareTransfer", Tier.AUTH_CONFIRM, "invalid_amount")
            throw AppFunctionInvalidArgumentException("Amount must be between 0 and ${BankRepository.TRANSFER_CAP} USD.")
        }
        audit("prepareTransfer", Tier.AUTH_CONFIRM, "opened_app")
        return openApp(BankAction.Transfer(payee.name, amount), 4)
    }
}
