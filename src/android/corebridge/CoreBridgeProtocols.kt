package com.airship.corebridge

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

// -----------------------------------------------------------------------------
// 1. Primitive Bridge Models
// -----------------------------------------------------------------------------

data class PeerBridgeModel(
    val identifier: String,
    val displayAlias: String,
    val fingerprintHex: String,
    val isTrusted: Boolean
)

data class ManifestItemBridgeModel(
    val identifier: String,
    val itemName: String,
    val byteSize: Long,
    val mimeType: String
)

data class ManifestBridgeModel(
    val identifier: String,
    val senderIdentifier: String,
    val items: List<ManifestItemBridgeModel>
) {
    val totalByteSize: Long
        get() = items.sumOf { it.byteSize }
}

sealed class BridgeResult<out T> {
    data class Success<T>(val value: T) : BridgeResult<T>()
    data class Failure(val message: String) : BridgeResult<Nothing>()
}

// -----------------------------------------------------------------------------
// 2. Core Bridge Interface (DIP)
// -----------------------------------------------------------------------------

interface AirShipCoreBridge {
    fun getLocalUserNameId(): String
    fun getLocalFingerprint(): String
    suspend fun startBroadcasting(): BridgeResult<Unit>
    suspend fun stopBroadcasting(): BridgeResult<Unit>
    fun observePeers(): Flow<List<PeerBridgeModel>>
    suspend fun listPeers(): BridgeResult<List<PeerBridgeModel>>
    suspend fun setPeerTrust(peerIdentifier: String, isTrusted: Boolean): BridgeResult<Unit>
    suspend fun addPeer(identifier: String, alias: String, fingerprintHex: String, isTrusted: Boolean): BridgeResult<Unit>
    suspend fun removePeer(identifier: String): BridgeResult<Boolean>
}

// -----------------------------------------------------------------------------
// 3. Mock Protocol Stub for Testing & UDF Previews (LSP)
// -----------------------------------------------------------------------------

class MockCoreBridge(
    private val localUserNameId: String = "USER_KOTLIN_DEVICE",
    private val localFingerprint: String = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
    initialPeers: List<PeerBridgeModel> = emptyList()
) : AirShipCoreBridge {

    private val peerStateFlow = MutableStateFlow(initialPeers)

    override fun getLocalUserNameId(): String = localUserNameId

    override fun getLocalFingerprint(): String = localFingerprint

    override suspend fun startBroadcasting(): BridgeResult<Unit> = BridgeResult.Success(Unit)

    override suspend fun stopBroadcasting(): BridgeResult<Unit> = BridgeResult.Success(Unit)

    override fun observePeers(): Flow<List<PeerBridgeModel>> = peerStateFlow.asStateFlow()

    override suspend fun listPeers(): BridgeResult<List<PeerBridgeModel>> {
        return BridgeResult.Success(peerStateFlow.value)
    }

    override suspend fun setPeerTrust(peerIdentifier: String, isTrusted: Boolean): BridgeResult<Unit> {
        val currentPeers = peerStateFlow.value
        val updatedList = currentPeers.map { peer ->
            if (peer.identifier == peerIdentifier) peer.copy(isTrusted = isTrusted) else peer
        }
        peerStateFlow.value = updatedList
        return BridgeResult.Success(Unit)
    }

    override suspend fun addPeer(
        identifier: String,
        alias: String,
        fingerprintHex: String,
        isTrusted: Boolean
    ): BridgeResult<Unit> {
        val newPeer = PeerBridgeModel(identifier, alias, fingerprintHex, isTrusted)
        peerStateFlow.value = peerStateFlow.value + newPeer
        return BridgeResult.Success(Unit)
    }

    override suspend fun removePeer(identifier: String): BridgeResult<Boolean> {
        val initialSize = peerStateFlow.value.size
        peerStateFlow.value = peerStateFlow.value.filterNot { it.identifier == identifier }
        val removed = peerStateFlow.value.size < initialSize
        return BridgeResult.Success(removed)
    }
}
