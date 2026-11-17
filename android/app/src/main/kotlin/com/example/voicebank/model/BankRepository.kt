package com.example.voicebank.model

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import org.json.JSONObject
import java.math.BigDecimal
import java.time.Instant
import java.util.UUID
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Mock bank API backed by assets/mock_bank.json. State resets on every launch.
 * No connection to any real core banking system.
 */
class BankRepository(context: Context) {

    companion object {
        val TRANSFER_CAP: BigDecimal = BigDecimal("100")
        const val DRAFT_LIFETIME_SECONDS = 5 * 60L
    }

    class BankException(message: String) : Exception(message)

    private val _accounts = MutableStateFlow<List<Account>>(emptyList())
    val accounts: StateFlow<List<Account>> = _accounts.asStateFlow()

    private val _cards = MutableStateFlow<List<Card>>(emptyList())
    val cards: StateFlow<List<Card>> = _cards.asStateFlow()

    private val _transactions = MutableStateFlow<List<Transaction>>(emptyList())
    val transactions: StateFlow<List<Transaction>> = _transactions.asStateFlow()

    val payees: List<Payee>
    val rates: List<ExchangeRate>
    val branches: List<Branch>

    private val usedDraftIds = mutableSetOf<String>()

    init {
        val json = JSONObject(context.assets.open("mock_bank.json").bufferedReader().use { it.readText() })

        _accounts.value = json.getJSONArray("accounts").objects().map {
            Account(it.getString("id"), it.getString("name"), it.getString("maskedNumber"),
                it.getString("currency"), BigDecimal(it.get("balance").toString()))
        }
        payees = json.getJSONArray("payees").objects().map {
            Payee(it.getString("id"), it.getString("name"), it.getString("bank"), it.getString("maskedAccount"))
        }
        rates = json.getJSONArray("rates").objects().map {
            ExchangeRate(it.getString("pair"), BigDecimal(it.get("buy").toString()),
                BigDecimal(it.get("sell").toString()), Instant.parse(it.getString("asOf")))
        }
        branches = json.getJSONArray("branches").objects().map {
            Branch(it.getString("id"), it.getString("name"), it.getString("type"),
                it.getString("address"), it.getDouble("lat"), it.getDouble("lng"))
        }
        _cards.value = json.getJSONArray("cards").objects().map {
            Card(it.getString("id"), it.getString("name"), it.getString("maskedNumber"), it.getBoolean("frozen"))
        }
        _transactions.value = json.getJSONArray("transactions").objects().map {
            Transaction(it.getString("id"), Instant.parse(it.getString("date")), it.getString("detail"),
                BigDecimal(it.get("amount").toString()), it.getString("currency"))
        }.sortedByDescending { it.date }
    }

    // Tier 1

    /** Demo origin: Wat Phnom. No location permission requested. */
    fun nearestBranches(lat: Double = 11.5764, lng: Double = 104.9230): List<Pair<Branch, Double>> =
        branches.map { it to distanceKm(lat, lng, it.lat, it.lng) }.sortedBy { it.second }

    // Tier 2

    fun setFrozen(cardId: String, frozen: Boolean) {
        _cards.update { list -> list.map { if (it.id == cardId) it.copy(frozen = frozen) else it } }
    }

    // Tier 3

    fun payeeNamed(name: String): Payee? = payees.firstOrNull { it.name.equals(name, ignoreCase = true) }

    @Synchronized
    fun createDraft(payeeId: String, amount: BigDecimal): TransferDraft {
        val payee = payees.firstOrNull { it.id == payeeId }
            ?: throw BankException("Only saved payees can receive voice transfers.")
        if (amount <= BigDecimal.ZERO) throw BankException("Enter an amount greater than zero.")
        if (amount > TRANSFER_CAP) throw BankException("Voice transfers are limited to USD $TRANSFER_CAP in this demo.")
        return TransferDraft(payee = payee, amount = amount,
            expiresAt = Instant.now().plusSeconds(DRAFT_LIFETIME_SECONDS))
    }

    @Synchronized
    fun submit(draft: TransferDraft): Transaction {
        if (draft.id in usedDraftIds) throw BankException("This transfer request was already used.")
        if (draft.isExpired) throw BankException("This transfer request expired. Start again.")
        val account = _accounts.value.firstOrNull { it.currency == draft.currency && it.balance >= draft.amount }
            ?: throw BankException("Insufficient funds.")

        usedDraftIds += draft.id
        _accounts.update { list ->
            list.map { if (it.id == account.id) it.copy(balance = it.balance - draft.amount) else it }
        }
        val tx = Transaction(UUID.randomUUID().toString(), Instant.now(),
            "Transfer to ${draft.payee.name}", draft.amount.negate(), draft.currency)
        _transactions.update { listOf(tx) + it }
        return tx
    }

    private fun distanceKm(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
        val r = 6371.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLng = Math.toRadians(lng2 - lng1)
        val a = sin(dLat / 2) * sin(dLat / 2) +
            cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLng / 2) * sin(dLng / 2)
        return 2 * r * asin(sqrt(a))
    }
}

private fun org.json.JSONArray.objects(): List<JSONObject> = (0 until length()).map { getJSONObject(it) }
