package com.airship.features.send

import androidx.lifecycle.ViewModel
import com.airship.corebridge.AirShipCoreBridge
import com.airship.designsystem.TransferModeOption
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

data class StagedItem(
    val identifier: String,
    val name: String,
    val byteSize: Long,
    val mimeType: String,
    val typeLabel: String
)

sealed class SendTransferStatus {
    object Empty : SendTransferStatus()
    object Staged : SendTransferStatus()
    object Sending : SendTransferStatus()
    object Completed : SendTransferStatus()
    data class Error(val message: String) : SendTransferStatus()
}

data class SendUiState(
    val stagedItems: List<StagedItem> = emptyList(),
    val transferStatus: SendTransferStatus = SendTransferStatus.Empty,
    val selectedMode: TransferModeOption = TransferModeOption.Send
)

class SendViewModel(
    private val coreBridge: AirShipCoreBridge
) : ViewModel() {

    private val _uiState = MutableStateFlow(SendUiState())
    val uiState: StateFlow<SendUiState> = _uiState.asStateFlow()

    fun addPhoto(name: String, byteSize: Long) {
        val item = StagedItem(UUID.randomUUID().toString(), name, byteSize, "image/jpeg", "Photo")
        updateItemsWithNewAttachment(item)
    }

    fun addCameraCapture(name: String, byteSize: Long) {
        val item = StagedItem(UUID.randomUUID().toString(), name, byteSize, "image/jpeg", "Camera")
        updateItemsWithNewAttachment(item)
    }

    fun addFile(name: String, byteSize: Long, mimeType: String) {
        val item = StagedItem(UUID.randomUUID().toString(), name, byteSize, mimeType, "File")
        updateItemsWithNewAttachment(item)
    }

    fun addTextSnippet(snippet: String) {
        val byteSize = snippet.toByteArray().size.toLong()
        val item = StagedItem(UUID.randomUUID().toString(), "Pasted Text", byteSize, "text/plain", "Text")
        updateItemsWithNewAttachment(item)
    }

    fun removeItem(identifier: String) {
        val updatedList = _uiState.value.stagedItems.filterNot { it.identifier == identifier }
        val nextStatus = if (updatedList.isEmpty()) SendTransferStatus.Empty else SendTransferStatus.Staged
        _uiState.value = _uiState.value.copy(stagedItems = updatedList, transferStatus = nextStatus)
    }

    fun dispatchPackage(targetPeerId: String) {
        if (_uiState.value.stagedItems.isEmpty()) return
        _uiState.value = _uiState.value.copy(transferStatus = SendTransferStatus.Sending)
        // Simulate transfer execution via bridge
        _uiState.value = _uiState.value.copy(transferStatus = SendTransferStatus.Completed)
    }

    fun updateSelectedMode(mode: TransferModeOption) {
        _uiState.value = _uiState.value.copy(selectedMode = mode)
    }

    private fun updateItemsWithNewAttachment(item: StagedItem) {
        val updatedList = _uiState.value.stagedItems + item
        _uiState.value = _uiState.value.copy(
            stagedItems = updatedList,
            transferStatus = SendTransferStatus.Staged
        )
    }
}
