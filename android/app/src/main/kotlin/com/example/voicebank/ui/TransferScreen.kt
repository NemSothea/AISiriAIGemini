package com.example.voicebank.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.activity.compose.LocalActivity
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import com.example.voicebank.model.BankRepository
import com.example.voicebank.model.Tier
import com.example.voicebank.model.Transaction
import com.example.voicebank.model.TransferDraft
import com.example.voicebank.security.AuthGate
import com.example.voicebank.voiceBank
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.math.BigDecimal
import java.time.Duration
import java.time.Instant

// Tier 3 — voice prepares, app confirms. Saved payees only; biometric + PIN to submit.

private sealed interface Step {
    data object Form : Step
    data class Review(val draft: TransferDraft) : Step
    data class Done(val tx: Transaction) : Step
}

@Composable
fun TransferScreen(prefillPayee: String?, prefillAmount: BigDecimal?, onBack: () -> Unit) {
    val activity = LocalActivity.current as FragmentActivity
    val bank = activity.voiceBank.bank
    val audit = activity.voiceBank.audit
    val scope = rememberCoroutineScope()

    var payeeId by remember { mutableStateOf<String?>(null) }
    var amountText by remember { mutableStateOf(prefillAmount?.toPlainString() ?: "") }
    var step by remember { mutableStateOf<Step>(Step.Form) }
    var error by remember { mutableStateOf<String?>(null) }
    var showPin by remember { mutableStateOf(false) }
    var pin by remember { mutableStateOf("") }

    LaunchedEffect(prefillPayee) {
        if (prefillPayee != null) {
            val payee = bank.payeeNamed(prefillPayee)
            if (payee != null) {
                payeeId = payee.id
            } else {
                error = "\"$prefillPayee\" is not a saved payee. Voice transfers only go to saved payees."
                audit.record("app", "prepareTransfer", Tier.AUTH_CONFIRM, "unknown_payee")
            }
        }
    }

    fun review() {
        error = null
        val id = payeeId
        val amount = amountText.toBigDecimalOrNull()
        if (id == null || amount == null) {
            error = "Choose a payee and enter an amount."
            return
        }
        try {
            step = Step.Review(bank.createDraft(id, amount))
            audit.record("app", "prepareTransfer", Tier.AUTH_CONFIRM, "draft_created")
        } catch (e: BankRepository.BankException) {
            error = e.message
            audit.record("app", "prepareTransfer", Tier.AUTH_CONFIRM, "draft_rejected")
        }
    }

    fun confirm(draft: TransferDraft) {
        error = null
        if (draft.isExpired) {
            error = "This transfer request expired. Start again."
            step = Step.Form
            return
        }
        scope.launch {
            try {
                AuthGate.authenticate(activity, "Confirm transfer to ${draft.payee.name}")
                pin = ""
                showPin = true
            } catch (e: AuthGate.AuthException) {
                error = e.message
                audit.record("app", "submitTransfer", Tier.AUTH_CONFIRM, "auth_failed")
            }
        }
    }

    fun submitWithPin(draft: TransferDraft) {
        showPin = false
        try {
            AuthGate.verifyPin(pin)
            val tx = bank.submit(draft)
            step = Step.Done(tx)
            audit.record("app", "submitTransfer", Tier.AUTH_CONFIRM, "success")
        } catch (e: Exception) {
            error = e.message
            audit.record("app", "submitTransfer", Tier.AUTH_CONFIRM, "failed")
        } finally {
            pin = ""
        }
    }

    ScreenScaffold("Transfer", onBack) { padding ->
        Column(
            Modifier.padding(padding).padding(16.dp).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            when (val s = step) {
                Step.Form -> {
                    Text("To (saved payees only)", style = MaterialTheme.typography.titleSmall)
                    bank.payees.forEach { payee ->
                        FilterChip(
                            selected = payeeId == payee.id,
                            onClick = { payeeId = payee.id },
                            label = { Text("${payee.name} · ${payee.bank} ${payee.maskedAccount}") },
                        )
                    }
                    OutlinedTextField(
                        value = amountText,
                        onValueChange = { amountText = it },
                        label = { Text("Amount (USD)") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Text("Limit USD ${BankRepository.TRANSFER_CAP} per transfer in this demo.",
                        style = MaterialTheme.typography.bodySmall)
                    Button(onClick = ::review, enabled = payeeId != null && amountText.isNotBlank()) { Text("Review") }
                }
                is Step.Review -> {
                    SecureWindow()
                    val draft = s.draft
                    Text("Review", style = MaterialTheme.typography.titleMedium)
                    Text("To: ${draft.payee.name}")
                    Text("Account: ${draft.payee.bank} ${draft.payee.maskedAccount}")
                    Text("Amount: ${money(draft.amount, draft.currency)}")
                    ExpiryCountdown(draft.expiresAt)
                    Button(onClick = { confirm(draft) }) { Text("Confirm with biometrics + PIN") }
                    OutlinedButton(onClick = {
                        audit.record("app", "prepareTransfer", Tier.AUTH_CONFIRM, "cancelled")
                        step = Step.Form
                    }) { Text("Cancel") }

                    if (showPin) {
                        AlertDialog(
                            onDismissRequest = { showPin = false; pin = "" },
                            title = { Text("Enter PIN") },
                            text = {
                                OutlinedTextField(
                                    value = pin,
                                    onValueChange = { if (it.length <= 6) pin = it },
                                    label = { Text("Demo PIN") },
                                    visualTransformation = PasswordVisualTransformation(),
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                                )
                            },
                            confirmButton = {
                                TextButton(onClick = { submitWithPin(draft) }, enabled = pin.length >= 4) { Text("Submit") }
                            },
                            dismissButton = { TextButton(onClick = { showPin = false; pin = "" }) { Text("Cancel") } },
                        )
                    }
                }
                is Step.Done -> {
                    Text("Transfer sent (demo)", color = Color(0xFF2E7D32), style = MaterialTheme.typography.titleMedium)
                    Text(s.tx.detail)
                    Text("Amount: ${money(s.tx.amount, s.tx.currency)}")
                    Text("Reference: ${s.tx.id.take(8)}")
                }
            }
            error?.let { Text(it, color = Color(0xFFC62828)) }
        }
    }
}

@Composable
private fun ExpiryCountdown(expiresAt: Instant) {
    var remaining by remember { mutableLongStateOf(Duration.between(Instant.now(), expiresAt).seconds) }
    LaunchedEffect(expiresAt) {
        while (remaining > 0) {
            delay(1000)
            remaining = Duration.between(Instant.now(), expiresAt).seconds.coerceAtLeast(0)
        }
    }
    Text("Expires in %d:%02d".format(remaining / 60, remaining % 60))
}
