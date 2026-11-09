package com.airship.features.trustlist

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.airship.corebridge.AirShipCoreBridge
import com.airship.corebridge.BridgeResult
import com.airship.corebridge.PeerBridgeModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class TrustListUiState(
    val peers: List<PeerBridgeModel> = emptyList(),
    val searchQuery: String = "",
    val isAddDrawerExpanded: Boolean = false,
    val newUserIdInput: String = "",
    val newUserAliasInput: String = "",
    val errorMessage: String? = null
) {
    val filteredPeers: List<PeerBridgeModel>
        get() {
            if (searchQuery.isBlank()) return peers
            return peers.filter { peer ->
                peer.displayAlias.contains(searchQuery, ignoreCase = true) ||
                peer.identifier.contains(searchQuery, ignoreCase = true)
            }
        }
}

class TrustListViewModel(
    private val coreBridge: AirShipCoreBridge
) : ViewModel() {

    private val _uiState = MutableStateFlow(TrustListUiState())
    val uiState: StateFlow<TrustListUiState> = _uiState.asStateFlow()

    init {
        loadPeers()
    }

    fun loadPeers() {
        viewModelScope.launch {
            when (val result = coreBridge.listPeers()) {
                is BridgeResult.Success -> _uiState.value = _uiState.value.copy(peers = result.value)
                is BridgeResult.Failure -> _uiState.value = _uiState.value.copy(errorMessage = result.message)
            }
        }
    }

    fun updateSearchQuery(query: String) {
        _uiState.value = _uiState.value.copy(searchQuery = query)
    }

    fun toggleAddDrawer() {
        _uiState.value = _uiState.value.copy(isAddDrawerExpanded = !_uiState.value.isAddDrawerExpanded)
    }

    fun updateNewUserId(input: String) {
        _uiState.value = _uiState.value.copy(newUserIdInput = input)
    }

    fun updateNewUserAlias(input: String) {
        _uiState.value = _uiState.value.copy(newUserAliasInput = input)
    }

    fun toggleTrust(peer: PeerBridgeModel) {
        viewModelScope.launch {
            coreBridge.setPeerTrust(peer.identifier, !peer.isTrusted)
            loadPeers()
        }
    }

    fun removePeer(peer: PeerBridgeModel) {
        viewModelScope.launch {
            coreBridge.removePeer(peer.identifier)
            loadPeers()
        }
    }

    fun submitNewUser() {
        val trimmedId = _uiState.value.newUserIdInput.trim()
        val trimmedAlias = _uiState.value.newUserAliasInput.trim()
        if (trimmedId.isEmpty()) return

        val alias = if (trimmedAlias.isEmpty()) trimmedId else trimmedAlias
        val dummyFingerprint = "0".repeat(64)

        viewModelScope.launch {
            coreBridge.addPeer(trimmedId, alias, dummyFingerprint, false)
            _uiState.value = _uiState.value.copy(
                newUserIdInput = "",
                newUserAliasInput = "",
                isAddDrawerExpanded = false
            )
            loadPeers()
        }
    }
}
