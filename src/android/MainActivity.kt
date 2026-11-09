package com.airship

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.airship.corebridge.MockCoreBridge
import com.airship.designsystem.AirShipTheme
import com.airship.designsystem.AppNavigationTab
import com.airship.designsystem.TransferModeOption
import com.airship.features.home.HomeScreen
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

                when (activeTab) {
                    AppNavigationTab.Transfer -> {
                        if (homeViewModel.uiState.value.selectedMode == TransferModeOption.Send) {
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
