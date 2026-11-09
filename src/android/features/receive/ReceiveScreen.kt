package com.airship.features.receive

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.airship.designsystem.AirShipColors
import com.airship.designsystem.AirShipDimens
import com.airship.designsystem.AppNavigationTab
import com.airship.designsystem.BlimpLogo
import com.airship.designsystem.FloatingBottomBar
import com.airship.designsystem.SegmentedToggle

@Composable
fun ReceiveScreen(
    viewModel: ReceiveViewModel,
    activeTab: AppNavigationTab,
    onTabSelected: (AppNavigationTab) -> Unit,
    modifier: Modifier = Modifier
) {
    val uiState by viewModel.uiState.collectAsState()

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(AirShipColors.PrimaryDarkBackground)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            SegmentedToggle(
                selectedOption = uiState.selectedMode,
                onOptionSelected = { viewModel.updateSelectedMode(it) }
            )

            when (val status = uiState.screenStatus) {
                is ReceiveScreenStatus.Waiting -> WaitingState()
                is ReceiveScreenStatus.PackageReceived -> PackageReceivedState(
                    items = status.items,
                    onDownloadItem = { viewModel.downloadSingleItem(it) },
                    onDownloadAll = { viewModel.downloadAllItems() }
                )
                is ReceiveScreenStatus.Downloading -> DownloadingState()
                is ReceiveScreenStatus.Completed -> CompletedState()
            }

            FloatingBottomBar(
                currentTab = activeTab,
                onTabSelected = onTabSelected,
                modifier = Modifier.padding(bottom = 16.dp)
            )
        }
    }
}

@Composable
private fun WaitingState() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        BlimpLogo(size = 130.dp)
        Text(
            text = "Waiting for your package...",
            color = AirShipColors.TextPrimary,
            fontSize = 18.sp,
            fontWeight = FontWeight.Medium
        )
        CircularProgressIndicator(color = AirShipColors.AccentCyan)
    }
}

@Composable
private fun PackageReceivedState(
    items: List<ReceivedItem>,
    onDownloadItem: (String) -> Unit,
    onDownloadAll: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Package Received!",
            color = AirShipColors.TextPrimary,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold
        )

        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .height(240.dp)
                .clip(RoundedCornerShape(AirShipDimens.CardCornerRadius))
                .background(AirShipColors.SecondaryCardBackground)
                .padding(16.dp)
        ) {
            items(items, key = { it.identifier }) { item ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(text = item.name, color = AirShipColors.TextPrimary)
                        Text(text = "${item.byteSize / 1024} KB", color = AirShipColors.TextSecondary, fontSize = 12.sp)
                    }
                    IconButton(onClick = { onDownloadItem(item.identifier) }) {
                        Icon(
                            imageVector = if (item.isDownloaded) Icons.Default.CheckCircle else Icons.Default.PlayArrow,
                            contentDescription = "Download",
                            tint = if (item.isDownloaded) Color.Green else AirShipColors.AccentCyan
                        )
                    }
                }
            }
        }

        Button(
            onClick = onDownloadAll,
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = AirShipColors.AccentCyan,
                contentColor = AirShipColors.PrimaryDarkBackground
            ),
            shape = RoundedCornerShape(AirShipDimens.PillCornerRadius)
        ) {
            Text(text = "Download All", fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun DownloadingState() {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        CircularProgressIndicator(color = AirShipColors.AccentCyan)
        Spacer(modifier = Modifier.height(16.dp))
        Text(text = "Downloading package...", color = AirShipColors.TextPrimary)
    }
}

@Composable
private fun CompletedState() {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(
            imageVector = Icons.Default.CheckCircle,
            contentDescription = "Done",
            tint = Color.Green,
            modifier = Modifier.height(64.dp)
        )
        Spacer(modifier = Modifier.height(12.dp))
        Text(text = "All Items Saved!", color = AirShipColors.TextPrimary, fontSize = 20.sp, fontWeight = FontWeight.Bold)
    }
}
