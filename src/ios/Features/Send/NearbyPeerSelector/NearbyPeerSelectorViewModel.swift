import Combine
import Foundation

@MainActor
public final class NearbyPeerSelectorViewModel: ObservableObject {
	@Published public private(set) var nearbyPeers: [PeerBridgeModel] = []
	@Published public private(set) var isDiscoveringPeers = false
	@Published public private(set) var selectedRecipientPeerId: String?
	@Published public private(set) var transferState: PeerTransferState = .ready
	@Published public private(set) var errorMessage: String?

	public let stagedItems: [StagedItem]

	private let coreBridge: AirShipCoreBridgeProtocol
	private let onTransferCompleted: @MainActor () -> Void

	public var totalStagedByteSize: Int64 {
		stagedItems.reduce(0) { accumulated, nextItem in
			accumulated + nextItem.byteSize
		}
	}

	public init(
		coreBridge: AirShipCoreBridgeProtocol,
		stagedItems: [StagedItem],
		onTransferCompleted: @escaping @MainActor () -> Void = {}
	) {
		self.coreBridge = coreBridge
		self.stagedItems = stagedItems
		self.onTransferCompleted = onTransferCompleted
	}

	public func loadNearbyPeers() async {
		isDiscoveringPeers = true
		defer { isDiscoveringPeers = false }

		do {
			nearbyPeers = try await coreBridge.listPeers()
		} catch {
			reportError(error)
		}
	}

	public func dispatchPackage(to peerId: String) async {
		guard !stagedItems.isEmpty else { return }
		selectedRecipientPeerId = peerId
		transferState = .sending
		// Simulate transfer execution via bridge
		transferState = .completed
	}

	public func finishCompletedTransfer() {
		onTransferCompleted()
	}

	public func dismissError() {
		errorMessage = nil
	}

	private func reportError(_ error: Error) {
		if let localizedError = error as? LocalizedError,
			let description = localizedError.errorDescription
		{
			errorMessage = description
			return
		}
		errorMessage = error.localizedDescription
	}
}
