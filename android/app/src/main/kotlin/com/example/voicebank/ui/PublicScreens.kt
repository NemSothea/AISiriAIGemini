package com.example.voicebank.ui

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.graphics.createBitmap
import androidx.core.graphics.set
import com.example.voicebank.voiceBank
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import java.time.ZoneId
import java.time.format.DateTimeFormatter

// Tier 1 — public / receive-only. No authentication.

/** Static sample payload. Real KHQR needs Bakong/KHQR SDK access (PLAN.md §4). */
private const val SAMPLE_QR_PAYLOAD = "DEMO-KHQR-SAMPLE-NOT-FOR-PAYMENT"

@Composable
fun QRScreen(onBack: () -> Unit) {
    val bitmap = remember { qrBitmap(SAMPLE_QR_PAYLOAD, 512) }
    ScreenScaffold("Receive", onBack) { padding ->
        Column(
            Modifier.padding(padding).fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Image(
                bitmap.asImageBitmap(),
                contentDescription = "Sample receive QR code",
                filterQuality = FilterQuality.None,
                modifier = Modifier.size(260.dp).background(Color.White).padding(12.dp),
            )
            Text("Scan to pay me", style = MaterialTheme.typography.titleMedium)
            Text("Sample QR — not a valid KHQR", color = Color(0xFFC62828))
        }
    }
}

private fun qrBitmap(text: String, size: Int): Bitmap {
    val matrix = QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, size, size)
    val bmp = createBitmap(size, size, Bitmap.Config.RGB_565)
    for (x in 0 until size) for (y in 0 until size) {
        bmp[x, y] = if (matrix[x, y]) android.graphics.Color.BLACK else android.graphics.Color.WHITE
    }
    return bmp
}

@Composable
fun RatesScreen(onBack: () -> Unit) {
    val bank = LocalContext.current.voiceBank.bank
    val fmt = DateTimeFormatter.ofPattern("d MMM yyyy HH:mm").withZone(ZoneId.systemDefault())
    ScreenScaffold("Exchange Rates", onBack) { padding ->
        LazyColumn(Modifier.padding(padding)) {
            items(bank.rates) { rate ->
                ListItem(
                    headlineContent = { Text(rate.pair) },
                    trailingContent = { Text("Buy ${rate.buy.toPlainString()}\nSell ${rate.sell.toPlainString()}") },
                )
            }
            item {
                bank.rates.firstOrNull()?.let {
                    Text(
                        "Demo rates, not live · as of ${fmt.format(it.asOf)}",
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(16.dp),
                    )
                }
            }
        }
    }
}

@Composable
fun BranchesScreen(onBack: () -> Unit) {
    val bank = LocalContext.current.voiceBank.bank
    ScreenScaffold("ATM & Branches", onBack) { padding ->
        LazyColumn(Modifier.padding(padding)) {
            items(bank.nearestBranches(), key = { it.first.id }) { (branch, km) ->
                ListItem(
                    overlineContent = { Text(if (branch.type == "atm") "ATM" else "Branch") },
                    headlineContent = { Text(branch.name) },
                    supportingContent = { Text(branch.address) },
                    trailingContent = { Text("%.1f km".format(km)) },
                )
            }
            item {
                Text(
                    "Distances from a fixed demo location (Wat Phnom). Locations are fictional.",
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(16.dp),
                )
            }
        }
    }
}
