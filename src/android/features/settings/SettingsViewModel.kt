package com.airship.features.settings

import androidx.lifecycle.ViewModel
import com.airship.corebridge.AirShipCoreBridge
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class SettingsUiState(
    val deviceAlias: String = "",
    val destinationFolderPath: String = "Downloads/AirShip",
    val networkStatus: String = "Wi-Fi LAN Active",
    val certificateFingerprint: String = ""
)

class SettingsViewModel(
    private val coreBridge: AirShipCoreBridge
) : ViewModel() {

    private val _uiState = MutableStateFlow(
        SettingsUiState(
            deviceAlias = coreBridge.getLocalUserNameId(),
            destinationFolderPath = "Downloads/AirShip",
            networkStatus = "Wi-Fi LAN Active",
            certificateFingerprint = coreBridge.getLocalFingerprint()
        )
    )
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    fun updateDeviceAlias(newAlias: String) {
        _uiState.value = _uiState.value.copy(deviceAlias = newAlias)
    }

    fun resetCertificate() {
        _uiState.value = _uiState.value.copy(
            certificateFingerprint = coreBridge.getLocalFingerprint()
        )
    }
}
