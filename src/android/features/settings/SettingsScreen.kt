package com.airship.features.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.airship.designsystem.AirShipColors
import com.airship.designsystem.AirShipDimens
import com.airship.designsystem.AppNavigationTab
import com.airship.designsystem.FloatingBottomBar

@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel,
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
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
                Text(
                    text = "Settings",
                    color = AirShipColors.TextPrimary,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold
                )

                SettingsSection(title = "Device Configuration") {
                    OutlinedTextField(
                        value = uiState.deviceAlias,
                        onValueChange = { viewModel.updateDeviceAlias(it) },
                        label = { Text("Device Alias") },
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                SettingsSection(title = "Storage & Permissions") {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(text = "Save Location", color = AirShipColors.TextPrimary)
                        Text(text = uiState.destinationFolderPath, color = AirShipColors.TextSecondary)
                    }
                }

                SettingsSection(title = "Network & Security") {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(text = "Interface Status", color = AirShipColors.TextPrimary)
                        Text(text = uiState.networkStatus, color = Color.Green)
                    }

                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(text = "Certificate Fingerprint", color = AirShipColors.TextSecondary, fontSize = 12.sp)
                        Text(
                            text = uiState.certificateFingerprint,
                            color = AirShipColors.TextPrimary,
                            fontSize = 11.sp,
                            fontFamily = FontFamily.Monospace
                        )
                    }

                    Button(
                        onClick = { viewModel.resetCertificate() },
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Red.copy(alpha = 0.8f)),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text(text = "Reset Identity Certificate")
                    }
                }
            }

            FloatingBottomBar(
                currentTab = activeTab,
                onTabSelected = onTabSelected,
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .padding(bottom = 16.dp)
            )
        }
    }
}

@Composable
private fun SettingsSection(
    title: String,
    content: @Composable () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AirShipDimens.CardCornerRadius))
            .background(AirShipColors.SecondaryCardBackground)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(text = title, color = AirShipColors.AccentCyan, fontWeight = FontWeight.Bold)
        content()
    }
}
