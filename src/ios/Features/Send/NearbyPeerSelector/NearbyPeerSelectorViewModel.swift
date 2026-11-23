import Combine
import Foundation

// -----------------------------------------------------------------------------
// 1. Pure Outgoing Item Mapping Helpers
// -----------------------------------------------------------------------------

private func makeOutgoingTransferItem(from stagedItem: StagedItem) -> OutgoingTransferItem {
	let payloadSource: OutgoingPayloadSource
	switch stagedItem.content {
	case .fileReference(let fileURL):
		payloadSource = .fileURL(fileURL)
	case .textPayload(let textContent):
		payloadSource = .textContent(textContent)
	case .metadataOnly:
		payloadSource = .textContent("")
	}

	return OutgoingTransferItem(
		id: stagedItem.id,
		name: stagedItem.name,
		byteSize: stagedItem.byteSize,
		mimeType: stagedItem.mimeType,
		isTextSnippet: stagedItem.sourceKind == .textSnippet,
		payloadSource: payloadSource
	)
}

private func describeTransferPhase(_ phase: TransferProgressPhase) -> (String, Double?) {
	switch phase {
	case .connecting:
		return ("Connecting to recipient...", nil)
	case .awaitingApproval:
		return ("Waiting for recipient to accept...", nil)
	case .transferring(let completedBytes, let totalBytes):
		guard totalBytes > 0 else {
			return ("Sending package...", nil)
		}
		let fraction = min(max(Double(completedBytes) / Double(totalBytes), 0.0), 1.0)
		let percent = Int((fraction * 100.0).rounded())
		return ("Sending \(percent)%...", fraction)
	case .completed:
		return ("Package Sent!", 1.0)
	case .failed(let reason):
		return (reason, nil)
	}
}

// -----------------------------------------------------------------------------
// 2. Nearby Peer Selector ViewModel
// -----------------------------------------------------------------------------

@MainActor
public final class NearbyPeerSelectorViewModel: ObservableObject {
	@Published public private(set) var nearbyPeers: [PeerBridgeModel] = []
	@Published public private(set) var isDiscoveringPeers = false
	@Published public private(set) var selectedRecipientPeerId: String?
	@Published public private(set) var transferState: PeerTransferState = .ready
	@Published public private(set) var transferStatusMessage: String = "Sending package..."
	@Published public private(set) var transferProgressFraction: Double?
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

	public func startObservingNearbyPeers() async {
		isDiscoveringPeers = true
		defer { isDiscoveringPeers = false }

		let stream = coreBridge.observeDiscoveredPeers()
		for await discoveredPeers in stream {
			nearbyPeers = discoveredPeers
		}
	}

	public func dispatchPackage(to peerId: String) async {
		guard !stagedItems.isEmpty else { return }
		selectedRecipientPeerId = peerId
		transferState = .sending
		transferProgressFraction = nil
		transferStatusMessage = "Connecting to recipient..."

		let outgoingItems = stagedItems.map(makeOutgoingTransferItem)
		do {
			try await coreBridge.sendPackage(to: peerId, items: outgoingItems) { [weak self] update in
				Task { @MainActor [weak self] in
					self?.applyProgressUpdate(update)
				}
			}
			transferProgressFraction = 1.0
			transferState = .completed
		} catch {
			let message = resolvedErrorMessage(error)
			transferProgressFraction = nil
			transferState = .failed(message)
			errorMessage = message
		}
	}

	public func cancelActiveTransfer() async {
		await coreBridge.cancelOutgoingTransfer()
	}

	public func finishCompletedTransfer() {
		onTransferCompleted()
	}

	public func dismissError() {
		errorMessage = nil
	}

	private func applyProgressUpdate(_ update: TransferProgressUpdate) {
		let (message, fraction) = describeTransferPhase(update.phase)
		transferStatusMessage = message
		transferProgressFraction = fraction
	}

	private func reportError(_ error: Error) {
		errorMessage = resolvedErrorMessage(error)
	}

	private func resolvedErrorMessage(_ error: Error) -> String {
		if let localizedError = error as? LocalizedError,
			let description = localizedError.errorDescription
		{
			return description
		}
		return error.localizedDescription
	}
}
