import XCTest
@testable import AirShipKit

@MainActor
final class AirShipViewModelTests: XCTestCase {
    private var mockBridge: MockCoreBridge!

    override func setUp() {
        super.setUp()
        mockBridge = MockCoreBridge(
            localUserNameId: "TEST_USER_ID",
            localFingerprint: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            initialPeers: [
                PeerBridgeModel(
                    id: "USER_PEER_1",
                    displayAlias: "Alice Phone",
                    fingerprintHex: String(repeating: "1", count: 64),
                    isTrusted: false
                )
            ]
        )
    }

    // -------------------------------------------------------------------------
    // Send ViewModel: Empty -> Staged -> Sending -> Completed
    // -------------------------------------------------------------------------

    func testSendWorkflowTransitions() async {
        let viewModel = SendViewModel(coreBridge: mockBridge)
        XCTAssertEqual(viewModel.transferState, .empty)
        XCTAssertTrue(viewModel.stagedItems.isEmpty)

        // Stage attachments
        viewModel.addPhotoAttachment(name: "Photo.png", size: 1024)
        XCTAssertEqual(viewModel.transferState, .staged)
        XCTAssertEqual(viewModel.stagedItems.count, 1)

        // Dispatch package
        await viewModel.dispatchPackage(to: "USER_PEER_1")
        XCTAssertEqual(viewModel.transferState, .completed)

        // Remove item resets to empty
        viewModel.removeItem(id: viewModel.stagedItems[0].id)
        XCTAssertEqual(viewModel.transferState, .empty)
        XCTAssertTrue(viewModel.stagedItems.isEmpty)
    }

    // -------------------------------------------------------------------------
    // Receive ViewModel: Waiting -> Package Received -> Downloading
    // -------------------------------------------------------------------------

    func testReceiveWorkflowTransitions() {
        let viewModel = ReceiveViewModel(coreBridge: mockBridge)
        XCTAssertEqual(viewModel.screenState, .waiting)

        let incomingItem = ReceivedPackageItem(
            id: "pkg_item_1",
            name: "Document.pdf",
            byteSize: 2048,
            isDownloaded: false
        )
        viewModel.simulateIncomingPackage(items: [incomingItem])
        XCTAssertEqual(viewModel.screenState, .packageReceived(items: [incomingItem]))

        viewModel.downloadSingleItem(id: "pkg_item_1")
        let expectedDownloaded = ReceivedPackageItem(
            id: "pkg_item_1",
            name: "Document.pdf",
            byteSize: 2048,
            isDownloaded: true
        )
        XCTAssertEqual(viewModel.screenState, .packageReceived(items: [expectedDownloaded]))

        viewModel.downloadAllItems()
        XCTAssertEqual(viewModel.screenState, .completed)
    }

    // -------------------------------------------------------------------------
    // Trust List ViewModel: Search, Heart Toggle & Removal
    // -------------------------------------------------------------------------

    func testTrustListPeerToggleAndFilter() async {
        let viewModel = TrustListViewModel(coreBridge: mockBridge)
        await viewModel.loadPeers()
        XCTAssertEqual(viewModel.peers.count, 1)
        XCTAssertFalse(viewModel.peers[0].isTrusted)

        // Toggle trust to true
        await viewModel.toggleTrust(for: viewModel.peers[0])
        XCTAssertTrue(viewModel.peers[0].isTrusted)

        // Filter search
        viewModel.searchQuery = "Alice"
        XCTAssertEqual(viewModel.filteredPeers.count, 1)

        viewModel.searchQuery = "NonExistent"
        XCTAssertEqual(viewModel.filteredPeers.count, 0)
    }
}
