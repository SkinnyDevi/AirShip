package com.airship.features.receive

import androidx.lifecycle.ViewModel
import com.airship.corebridge.AirShipCoreBridge
import com.airship.designsystem.TransferModeOption
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class ReceivedItem(
    val identifier: String,
    val name: String,
    val byteSize: Long,
    val isTextSnippet: Boolean = false,
    val textContent: String? = null,
    val isDownloaded: Boolean = false
)

sealed class ReceiveScreenStatus {
    object Waiting : ReceiveScreenStatus()
    data class PackageReceived(val items: List<ReceivedItem>) : ReceiveScreenStatus()
    object Downloading : ReceiveScreenStatus()
    object Completed : ReceiveScreenStatus()
}

data class ReceiveUiState(
    val screenStatus: ReceiveScreenStatus = ReceiveScreenStatus.Waiting,
    val selectedMode: TransferModeOption = TransferModeOption.Receive
)

class ReceiveViewModel(
    private val coreBridge: AirShipCoreBridge
) : ViewModel() {

    private val _uiState = MutableStateFlow(ReceiveUiState())
    val uiState: StateFlow<ReceiveUiState> = _uiState.asStateFlow()

    fun updateSelectedMode(mode: TransferModeOption) {
        _uiState.value = _uiState.value.copy(selectedMode = mode)
    }

    fun simulateIncomingPackage(items: List<ReceivedItem>) {
        _uiState.value = _uiState.value.copy(screenStatus = ReceiveScreenStatus.PackageReceived(items))
    }

    fun downloadSingleItem(identifier: String) {
        val currentStatus = _uiState.value.screenStatus
        if (currentStatus !is ReceiveScreenStatus.PackageReceived) return
        val updatedItems = currentStatus.items.map { item ->
            if (item.identifier == identifier) item.copy(isDownloaded = true) else item
        }
        _uiState.value = _uiState.value.copy(screenStatus = ReceiveScreenStatus.PackageReceived(updatedItems))
    }

    fun downloadAllItems() {
        val currentStatus = _uiState.value.screenStatus
        if (currentStatus !is ReceiveScreenStatus.PackageReceived) return
        _uiState.value = _uiState.value.copy(screenStatus = ReceiveScreenStatus.Completed)
    }

    fun resetToWaiting() {
        _uiState.value = _uiState.value.copy(screenStatus = ReceiveScreenStatus.Waiting)
    }
}
