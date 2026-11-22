package com.example.voicebank.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.voicebank.BankAction
import com.example.voicebank.model.Tier
import com.example.voicebank.voice.VoiceDialog

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VoiceBankRoot(
    route: BankAction?,
    onNavigate: (BankAction) -> Unit,
    onVoice: (BankAction) -> Unit,
    onBack: () -> Unit,
) {
    var showAudit by rememberSaveable { mutableStateOf(false) }
    var showVoice by rememberSaveable { mutableStateOf(false) }

    if (showVoice) {
        VoiceDialog(
            onAction = { action ->
                showVoice = false
                showAudit = false
                onVoice(action)
            },
            onDismiss = { showVoice = false },
        )
    }

    MaterialTheme {
        when {
            showAudit -> {
                BackHandler { showAudit = false }
                AuditScreen(onBack = { showAudit = false })
            }
            route != null -> {
                BackHandler(onBack = onBack)
                when (route) {
                    BankAction.ShowQR -> QRScreen(onBack)
                    BankAction.Rates -> RatesScreen(onBack)
                    BankAction.Branches -> BranchesScreen(onBack)
                    BankAction.Balance -> BalanceScreen(onBack)
                    BankAction.FreezeCard -> CardScreen(onBack)
                    // key(route): a new voice/deep-link transfer must reset the form, never reuse a stale draft.
                    is BankAction.Transfer -> key(route) { TransferScreen(route.payee, route.amount, onBack) }
                }
            }
            else -> HomeScreen(onNavigate = onNavigate, onAudit = { showAudit = true }, onVoice = { showVoice = true })
        }
    }
}

private data class Tile(val action: BankAction, val title: String)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HomeScreen(onNavigate: (BankAction) -> Unit, onAudit: () -> Unit, onVoice: () -> Unit) {
    val tiles = listOf(
        Tile(BankAction.ShowQR, "Receive (KHQR)"),
        Tile(BankAction.Rates, "Exchange Rates"),
        Tile(BankAction.Branches, "ATM & Branches"),
        Tile(BankAction.Balance, "Balance"),
        Tile(BankAction.FreezeCard, "Card Controls"),
        Tile(BankAction.Transfer(), "Transfer"),
    )
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("VoiceBank") },
                actions = {
                    TextButton(onClick = onVoice) { Text("Voice") }
                    TextButton(onClick = onAudit) { Text("Audit") }
                },
            )
        },
    ) { padding ->
        Column(Modifier.padding(padding)) {
            Text(
                "Demo build · mock data only",
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                contentPadding = PaddingValues(16.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                items(tiles) { tile ->
                    Card(onClick = { onNavigate(tile.action) }, modifier = Modifier.fillMaxWidth().heightIn(min = 120.dp)) {
                        Column(
                            Modifier.fillMaxWidth().padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Text(tile.title, style = MaterialTheme.typography.titleSmall)
                            TierBadge(tile.action.tier)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun TierBadge(tier: Tier) {
    val color = when (tier) {
        Tier.PUBLIC -> Color(0xFF2E7D32)
        Tier.AUTH_VIEW -> Color(0xFFEF6C00)
        Tier.AUTH_CONFIRM -> Color(0xFFC62828)
    }
    AssistChip(onClick = {}, label = { Text(tier.label, color = color) })
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScreenScaffold(title: String, onBack: () -> Unit, content: @Composable (PaddingValues) -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = { TextButton(onClick = onBack) { Text("Back") } },
            )
        },
        content = content,
    )
}
