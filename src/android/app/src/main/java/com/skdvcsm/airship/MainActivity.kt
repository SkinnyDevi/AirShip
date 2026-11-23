package com.airship

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.airship.corebridge.MockCoreBridge
import com.airship.designsystem.AirShipTheme
import com.airship.designsystem.AppNavigationTab
import com.airship.designsystem.TransferModeOption
import com.airship.features.home.HomeViewModel
import com.airship.features.receive.ReceiveScreen
import com.airship.features.receive.ReceiveViewModel
import com.airship.features.send.SendScreen
import com.airship.features.send.SendViewModel
import com.airship.features.settings.SettingsScreen
import com.airship.features.settings.SettingsViewModel
import com.airship.features.trustlist.TrustListScreen
import com.airship.features.trustlist.TrustListViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val coreBridge = MockCoreBridge()
        val homeViewModel = HomeViewModel(coreBridge)
        val sendViewModel = SendViewModel(coreBridge)
        val receiveViewModel = ReceiveViewModel(coreBridge)
        val trustListViewModel = TrustListViewModel(coreBridge)
        val settingsViewModel = SettingsViewModel(coreBridge)

        setContent {
            AirShipTheme {
                var activeTab by remember { mutableStateOf(AppNavigationTab.Transfer) }
                val homeUiState by homeViewModel.uiState.collectAsState()
                val sendUiState by sendViewModel.uiState.collectAsState()
                val receiveUiState by receiveViewModel.uiState.collectAsState()

                LaunchedEffect(sendUiState.selectedMode) {
                    if (sendUiState.selectedMode == TransferModeOption.Receive) {
                        homeViewModel.updateSelectedMode(TransferModeOption.Receive)
                        sendViewModel.updateSelectedMode(TransferModeOption.Send)
                    }
                }

                LaunchedEffect(receiveUiState.selectedMode) {
                    if (receiveUiState.selectedMode == TransferModeOption.Send) {
                        homeViewModel.updateSelectedMode(TransferModeOption.Send)
                        receiveViewModel.updateSelectedMode(TransferModeOption.Receive)
                    }
                }

                when (activeTab) {
                    AppNavigationTab.Transfer -> {
                        if (homeUiState.selectedMode == TransferModeOption.Send) {
                            SendScreen(
                                viewModel = sendViewModel,
                                activeTab = activeTab,
                                onTabSelected = { activeTab = it }
                            )
                        } else {
                            ReceiveScreen(
                                viewModel = receiveViewModel,
                                activeTab = activeTab,
                                onTabSelected = { activeTab = it }
                            )
                        }
                    }
                    AppNavigationTab.TrustList -> {
                        TrustListScreen(
                            viewModel = trustListViewModel,
                            activeTab = activeTab,
                            onTabSelected = { activeTab = it }
                        )
                    }
                    AppNavigationTab.Settings -> {
                        SettingsScreen(
                            viewModel = settingsViewModel,
                            activeTab = activeTab,
                            onTabSelected = { activeTab = it }
                        )
                    }
                }
            }
        }
    }
}
