package com.example.voicebank.ui

import android.view.WindowManager
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.activity.compose.LocalActivity
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.voicebank.model.Card
import com.example.voicebank.model.Tier
import com.example.voicebank.security.AuthGate
import com.example.voicebank.voiceBank
import kotlinx.coroutines.launch
import java.text.NumberFormat
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Currency
import java.util.Locale

// Tier 2 — biometric required; data shown in-app only.

/** Blocks screenshots / recents thumbnails while sensitive content is on screen. */
@Composable
fun SecureWindow() {
    val activity = LocalActivity.current as FragmentActivity
    DisposableEffect(Unit) {
        activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        onDispose { activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE) }
    }
}

/** Locks content behind device auth. Re-locks when the app goes to background. */
@Composable
fun AuthLocked(title: String, action: String, tier: Tier, content: @Composable () -> Unit) {
    val activity = LocalActivity.current as FragmentActivity
    val audit = activity.voiceBank.audit
    val scope = rememberCoroutineScope()
    var unlocked by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    suspend fun unlock() {
        if (unlocked) return
        try {
            AuthGate.authenticate(activity, title)
            unlocked = true
            error = null
            audit.record("app", action, tier, "auth_ok")
        } catch (e: AuthGate.AuthException) {
            error = e.message
            audit.record("app", action, tier, "auth_failed")
        }
    }

    LaunchedEffect(Unit) { unlock() }

    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_STOP) unlocked = false }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    if (unlocked) {
        SecureWindow()
        content()
    } else {
        Column(
            Modifier.fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        ) {
            Text("Locked", style = MaterialTheme.typography.headlineSmall)
            Text(error ?: "Authenticate to continue.")
            Button(onClick = { scope.launch { unlock() } }) { Text("Unlock") }
        }
    }
}

fun money(amount: java.math.BigDecimal, currency: String): String =
    NumberFormat.getCurrencyInstance(Locale.US).apply { this.currency = Currency.getInstance(currency) }.format(amount)

@Composable
fun BalanceScreen(onBack: () -> Unit) {
    val bank = LocalContext.current.voiceBank.bank
    val accounts by bank.accounts.collectAsStateWithLifecycle()
    val transactions by bank.transactions.collectAsStateWithLifecycle()
    val fmt = DateTimeFormatter.ofPattern("d MMM HH:mm").withZone(ZoneId.systemDefault())

    ScreenScaffold("Balance", onBack) { padding ->
        Column(Modifier.padding(padding)) {
            AuthLocked("View your balance", "checkBalance", Tier.AUTH_VIEW) {
                LazyColumn {
                    item { Text("Accounts", style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(16.dp)) }
                    items(accounts, key = { it.id }) { account ->
                        ListItem(
                            headlineContent = { Text(account.name) },
                            supportingContent = { Text(account.maskedNumber) },
                            trailingContent = { Text(money(account.balance, account.currency)) },
                        )
                    }
                    item { Text("Recent transactions", style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(16.dp)) }
                    items(transactions.take(10), key = { it.id }) { tx ->
                        ListItem(
                            headlineContent = { Text(tx.detail) },
                            supportingContent = { Text(fmt.format(tx.date)) },
                            trailingContent = { Text(money(tx.amount, tx.currency)) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun CardScreen(onBack: () -> Unit) {
    val activity = LocalActivity.current as FragmentActivity
    val bank = activity.voiceBank.bank
    val audit = activity.voiceBank.audit
    val cards by bank.cards.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    var pending by remember { mutableStateOf<Card?>(null) }

    ScreenScaffold("Card Controls", onBack) { padding ->
        Column(Modifier.padding(padding)) {
            AuthLocked("Manage your card", "freezeCard", Tier.AUTH_VIEW) {
                LazyColumn {
                    items(cards, key = { it.id }) { card ->
                        ListItem(
                            headlineContent = { Text(card.name) },
                            supportingContent = { Text("${card.maskedNumber}\n${if (card.frozen) "Frozen" else "Active"}") },
                            trailingContent = {
                                Button(onClick = { pending = card }) { Text(if (card.frozen) "Unfreeze" else "Freeze") }
                            },
                        )
                    }
                }
            }
        }
    }

    pending?.let { card ->
        val freeze = !card.frozen
        val action = if (freeze) "freezeCard" else "unfreezeCard"
        AlertDialog(
            onDismissRequest = { pending = null },
            title = { Text(if (freeze) "Freeze this card?" else "Unfreeze this card?") },
            confirmButton = {
                TextButton(onClick = {
                    pending = null
                    scope.launch {
                        try {
                            // Fresh auth for the state change itself, not just for viewing.
                            AuthGate.authenticate(activity, if (freeze) "Freeze your card" else "Unfreeze your card")
                            bank.setFrozen(card.id, freeze)
                            audit.record("app", action, Tier.AUTH_VIEW, "success")
                        } catch (e: AuthGate.AuthException) {
                            audit.record("app", action, Tier.AUTH_VIEW, "auth_failed")
                        }
                    }
                }) { Text(if (freeze) "Freeze" else "Unfreeze") }
            },
            dismissButton = { TextButton(onClick = { pending = null }) { Text("Cancel") } },
        )
    }
}
