package com.airship.features.home

import androidx.lifecycle.ViewModel
import com.airship.corebridge.AirShipCoreBridge
import com.airship.designsystem.TransferModeOption
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class HomeUiState(
    val userNameId: String = "",
    val fingerprint: String = "",
    val selectedMode: TransferModeOption = TransferModeOption.Send
)

class HomeViewModel(
    private val coreBridge: AirShipCoreBridge
) : ViewModel() {

    private val _uiState = MutableStateFlow(
        HomeUiState(
            userNameId = coreBridge.getLocalUserNameId(),
            fingerprint = coreBridge.getLocalFingerprint(),
            selectedMode = TransferModeOption.Send
        )
    )
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    fun updateSelectedMode(mode: TransferModeOption) {
        _uiState.value = _uiState.value.copy(selectedMode = mode)
    }

    fun refreshIdentity() {
        _uiState.value = _uiState.value.copy(
            userNameId = coreBridge.getLocalUserNameId(),
            fingerprint = coreBridge.getLocalFingerprint()
        )
    }
}
