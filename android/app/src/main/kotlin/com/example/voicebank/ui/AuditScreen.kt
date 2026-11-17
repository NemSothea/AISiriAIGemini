package com.example.voicebank.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ListItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.voicebank.voiceBank
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun AuditScreen(onBack: () -> Unit) {
    val audit = LocalContext.current.voiceBank.audit
    val events by audit.events.collectAsStateWithLifecycle()
    val fmt = DateTimeFormatter.ofPattern("d MMM HH:mm:ss").withZone(ZoneId.systemDefault())

    ScreenScaffold("Audit Log", onBack) { padding ->
        Column(Modifier.padding(padding)) {
            TextButton(onClick = audit::clear, enabled = events.isNotEmpty(), modifier = Modifier.padding(horizontal = 8.dp)) {
                Text("Clear")
            }
            if (events.isEmpty()) Text("No events yet.", modifier = Modifier.padding(16.dp))
            LazyColumn {
                items(events, key = { it.id }) { e ->
                    ListItem(
                        headlineContent = { Text(e.action) },
                        supportingContent = { Text("${e.source} · ${e.result}\n${fmt.format(e.timestamp)}") },
                        trailingContent = { TierBadge(e.tier) },
                    )
                }
            }
        }
    }
}
