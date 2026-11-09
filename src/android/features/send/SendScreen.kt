package com.airship.features.send

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.airship.designsystem.AirShipColors
import com.airship.designsystem.AirShipDimens
import com.airship.designsystem.AppNavigationTab
import com.airship.designsystem.FloatingBottomBar
import com.airship.designsystem.SegmentedToggle

@Composable
fun SendScreen(
    viewModel: SendViewModel,
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

            Text(
                text = "Create your package",
                color = AirShipColors.TextPrimary,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                AttachmentButton("Photos", Modifier.weight(1f)) {
                    viewModel.addPhoto("IMG_001.jpg", 2_450_000)
                }
                AttachmentButton("Camera", Modifier.weight(1f)) {
                    viewModel.addCameraCapture("CAM_SNAP.jpg", 3_100_000)
                }
                AttachmentButton("Files", Modifier.weight(1f)) {
                    viewModel.addFile("Document.pdf", 4_500_000, "application/pdf")
                }
                AttachmentButton("Text", Modifier.weight(1f)) {
                    viewModel.addTextSnippet("Hello from Android AirShip!")
                }
            }

            StagingContainer(
                items = uiState.stagedItems,
                onRemoveItem = { viewModel.removeItem(it) }
            )

            FloatingBottomBar(
                currentTab = activeTab,
                onTabSelected = onTabSelected,
                modifier = Modifier.padding(bottom = 16.dp)
            )
        }
    }
}

@Composable
private fun AttachmentButton(
    label: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        modifier = modifier.height(48.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = AirShipColors.SecondaryCardBackground,
            contentColor = AirShipColors.AccentCyan
        ),
        shape = RoundedCornerShape(12.dp)
    ) {
        Text(text = label, fontSize = 12.sp)
    }
}

@Composable
private fun StagingContainer(
    items: List<StagedItem>,
    onRemoveItem: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(280.dp)
            .clip(RoundedCornerShape(AirShipDimens.CardCornerRadius))
            .background(AirShipColors.SecondaryCardBackground.copy(alpha = 0.6f))
            .padding(16.dp),
        contentAlignment = Alignment.Center
    ) {
        if (items.isEmpty()) {
            Text(
                text = "No files selected",
                color = AirShipColors.TextSecondary,
                fontSize = 14.sp
            )
        } else {
            LazyColumn(modifier = Modifier.fillMaxSize()) {
                items(items, key = { it.identifier }) { item ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(text = item.name, color = AirShipColors.TextPrimary, fontWeight = FontWeight.Medium)
                            Text(text = "${item.byteSize / 1024} KB", color = AirShipColors.TextSecondary, fontSize = 12.sp)
                        }
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Remove",
                            tint = AirShipColors.TextSecondary,
                            modifier = Modifier.clickable { onRemoveItem(item.identifier) }
                        )
                    }
                }
            }
        }
    }
}
