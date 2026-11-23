package com.airship

import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.airship.corebridge.MockCoreBridge
import com.airship.designsystem.AirShipColors
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

@Composable
private fun TransferTabContent(
    selectedMode: TransferModeOption,
    sendViewModel: SendViewModel,
    receiveViewModel: ReceiveViewModel,
    activeTab: AppNavigationTab,
    onTabSelected: (AppNavigationTab) -> Unit
) {
    if (selectedMode == TransferModeOption.Send) {
        SendScreen(
            viewModel = sendViewModel,
            activeTab = activeTab,
            onTabSelected = onTabSelected
        )
    } else {
        ReceiveScreen(
            viewModel = receiveViewModel,
            activeTab = activeTab,
            onTabSelected = onTabSelected
        )
    }
}

@Composable
private fun ActiveTabContent(
    activeTab: AppNavigationTab,
    selectedMode: TransferModeOption,
    sendViewModel: SendViewModel,
    receiveViewModel: ReceiveViewModel,
    trustListViewModel: TrustListViewModel,
    settingsViewModel: SettingsViewModel,
    onTabSelected: (AppNavigationTab) -> Unit
) {
    when (activeTab) {
        AppNavigationTab.Transfer -> TransferTabContent(
            selectedMode = selectedMode,
            sendViewModel = sendViewModel,
            receiveViewModel = receiveViewModel,
            activeTab = activeTab,
            onTabSelected = onTabSelected
        )
        AppNavigationTab.TrustList -> TrustListScreen(
            viewModel = trustListViewModel,
            activeTab = activeTab,
            onTabSelected = onTabSelected
        )
        AppNavigationTab.Settings -> SettingsScreen(
            viewModel = settingsViewModel,
            activeTab = activeTab,
            onTabSelected = onTabSelected
        )
    }
}

@Composable
private fun AirShipRootContent(
    homeViewModel: HomeViewModel,
    sendViewModel: SendViewModel,
    receiveViewModel: ReceiveViewModel,
    trustListViewModel: TrustListViewModel,
    settingsViewModel: SettingsViewModel
) {
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

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(AirShipColors.PrimaryDarkBackground)
            .systemBarsPadding()
    ) {
        ActiveTabContent(
            activeTab = activeTab,
            selectedMode = homeUiState.selectedMode,
            sendViewModel = sendViewModel,
            receiveViewModel = receiveViewModel,
            trustListViewModel = trustListViewModel,
            settingsViewModel = settingsViewModel,
            onTabSelected = { activeTab = it }
        )
    }
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT)
        )

        val coreBridge = MockCoreBridge()
        val homeViewModel = HomeViewModel(coreBridge)
        val sendViewModel = SendViewModel(coreBridge)
        val receiveViewModel = ReceiveViewModel(coreBridge)
        val trustListViewModel = TrustListViewModel(coreBridge)
        val settingsViewModel = SettingsViewModel(coreBridge)

        setContent {
            AirShipTheme {
                AirShipRootContent(
                    homeViewModel = homeViewModel,
                    sendViewModel = sendViewModel,
                    receiveViewModel = receiveViewModel,
                    trustListViewModel = trustListViewModel,
                    settingsViewModel = settingsViewModel
                )
            }
        }
    }
}
