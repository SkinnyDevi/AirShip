package com.airship

import com.airship.corebridge.MockCoreBridge
import com.airship.corebridge.PeerBridgeModel
import com.airship.features.receive.ReceiveScreenStatus
import com.airship.features.receive.ReceiveViewModel
import com.airship.features.receive.ReceivedItem
import com.airship.features.send.SendTransferStatus
import com.airship.features.send.SendViewModel
import com.airship.features.trustlist.TrustListViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AirShipViewModelTest {

    private lateinit var mockBridge: MockCoreBridge

    @Before
    fun setUp() {
        mockBridge = MockCoreBridge(
            localUserNameId = "TEST_ANDROID_DEVICE",
            localFingerprint = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789",
            initialPeers = listOf(
                PeerBridgeModel(
                    identifier = "USER_BOB",
                    displayAlias = "Bob Phone",
                    fingerprintHex = "0".repeat(64),
                    isTrusted = false
                )
            )
        )
    }

    // -------------------------------------------------------------------------
    // Send ViewModel: Empty -> Staged -> Sending -> Completed
    // -------------------------------------------------------------------------

    @Test
    fun testSendWorkflowTransitions() {
        val viewModel = SendViewModel(mockBridge)
        assertEquals(SendTransferStatus.Empty, viewModel.uiState.value.transferStatus)
        assertTrue(viewModel.uiState.value.stagedItems.isEmpty())

        // Stage attachment
        viewModel.addPhoto("vacation.png", 2048)
        assertEquals(SendTransferStatus.Staged, viewModel.uiState.value.transferStatus)
        assertEquals(1, viewModel.uiState.value.stagedItems.size)

        // Dispatch package
        viewModel.dispatchPackage("USER_BOB")
        assertEquals(SendTransferStatus.Completed, viewModel.uiState.value.transferStatus)

        // Removal transitions back to Empty
        val itemId = viewModel.uiState.value.stagedItems[0].identifier
        viewModel.removeItem(itemId)
        assertEquals(SendTransferStatus.Empty, viewModel.uiState.value.transferStatus)
        assertTrue(viewModel.uiState.value.stagedItems.isEmpty())
    }

    // -------------------------------------------------------------------------
    // Receive ViewModel: Waiting -> Package Received -> Downloading
    // -------------------------------------------------------------------------

    @Test
    fun testReceiveWorkflowTransitions() {
        val viewModel = ReceiveViewModel(mockBridge)
        assertEquals(ReceiveScreenStatus.Waiting, viewModel.uiState.value.screenStatus)

        val item = ReceivedItem("pkg_item_1", "notes.txt", 1024)
        viewModel.simulateIncomingPackage(listOf(item))

        val status = viewModel.uiState.value.screenStatus
        assertTrue(status is ReceiveScreenStatus.PackageReceived)

        viewModel.downloadSingleItem("pkg_item_1")
        val updatedStatus = viewModel.uiState.value.screenStatus as ReceiveScreenStatus.PackageReceived
        assertTrue(updatedStatus.items[0].isDownloaded)

        viewModel.downloadAllItems()
        assertEquals(ReceiveScreenStatus.Completed, viewModel.uiState.value.screenStatus)
    }

    // -------------------------------------------------------------------------
    // Trust List ViewModel: Toggle & Query
    // -------------------------------------------------------------------------

    @Test
    fun testTrustListManagement() = runTest {
        val viewModel = TrustListViewModel(mockBridge)
        viewModel.loadPeers()

        assertEquals(1, viewModel.uiState.value.peers.size)
        assertFalse(viewModel.uiState.value.peers[0].isTrusted)

        viewModel.toggleTrust(viewModel.uiState.value.peers[0])
        viewModel.loadPeers()
        assertTrue(viewModel.uiState.value.peers[0].isTrusted)

        viewModel.updateSearchQuery("Bob")
        assertEquals(1, viewModel.uiState.value.filteredPeers.size)

        viewModel.updateSearchQuery("Unknown")
        assertEquals(0, viewModel.uiState.value.filteredPeers.size)
    }
}
