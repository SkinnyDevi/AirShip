import Combine
import Foundation

// -----------------------------------------------------------------------------
// 1. Primitive & Domain Bridge Models
// -----------------------------------------------------------------------------

public struct PeerBridgeModel: Identifiable, Equatable, Sendable {
	public let id: String
	public let displayAlias: String
	public let fingerprintHex: String
	public let isTrusted: Bool

	public init(id: String, displayAlias: String, fingerprintHex: String, isTrusted: Bool) {
		self.id = id
		self.displayAlias = displayAlias
		self.fingerprintHex = fingerprintHex
		self.isTrusted = isTrusted
	}
}

public struct ManifestItemBridgeModel: Identifiable, Equatable, Sendable {
	public let id: String
	public let itemName: String
	public let byteSize: Int64
	public let mimeType: String

	public init(id: String, itemName: String, byteSize: Int64, mimeType: String) {
		self.id = id
		self.itemName = itemName
		self.byteSize = byteSize
		self.mimeType = mimeType
	}
}

public struct ManifestBridgeModel: Identifiable, Equatable, Sendable {
	public let id: String
	public let senderIdentifier: String
	public let items: [ManifestItemBridgeModel]
	public let totalByteSize: Int64

	public init(id: String, senderIdentifier: String, items: [ManifestItemBridgeModel]) {
		self.id = id
		self.senderIdentifier = senderIdentifier
		self.items = items
		self.totalByteSize = items.reduce(0) { accumulated, nextItem in
			accumulated + nextItem.byteSize
		}
	}
}

public enum OutgoingPayloadSource: Equatable, Sendable {
	case fileURL(URL)
	case textContent(String)
}

public struct OutgoingTransferItem: Identifiable, Equatable, Sendable {
	public let id: String
	public let name: String
	public let byteSize: Int64
	public let mimeType: String
	public let isTextSnippet: Bool
	public let payloadSource: OutgoingPayloadSource

	public init(
		id: String,
		name: String,
		byteSize: Int64,
		mimeType: String,
		isTextSnippet: Bool,
		payloadSource: OutgoingPayloadSource
	) {
		self.id = id
		self.name = name
		self.byteSize = byteSize
		self.mimeType = mimeType
		self.isTextSnippet = isTextSnippet
		self.payloadSource = payloadSource
	}
}

public enum TransferProgressPhase: Equatable, Sendable {
	case connecting
	case awaitingApproval
	case transferring(completedBytes: Int64, totalBytes: Int64)
	case completed
	case failed(String)
}

public struct TransferProgressUpdate: Equatable, Sendable {
	public let phase: TransferProgressPhase

	public init(phase: TransferProgressPhase) {
		self.phase = phase
	}
}

public struct IncomingPackageItemBridgeModel: Identifiable, Equatable, Sendable {
	public let id: String
	public let name: String
	public let byteSize: Int64
	public let mimeType: String
	public let isTextSnippet: Bool
	public let sha256Hex: String

	public init(
		id: String,
		name: String,
		byteSize: Int64,
		mimeType: String,
		isTextSnippet: Bool,
		sha256Hex: String
	) {
		self.id = id
		self.name = name
		self.byteSize = byteSize
		self.mimeType = mimeType
		self.isTextSnippet = isTextSnippet
		self.sha256Hex = sha256Hex
	}
}

public struct IncomingPackageOffer: Identifiable, Equatable, Sendable {
	public let id: String
	public let senderIdentifier: String
	public let senderAlias: String
	public let senderFingerprintHex: String
	public let items: [IncomingPackageItemBridgeModel]

	public init(
		id: String,
		senderIdentifier: String,
		senderAlias: String,
		senderFingerprintHex: String,
		items: [IncomingPackageItemBridgeModel]
	) {
		self.id = id
		self.senderIdentifier = senderIdentifier
		self.senderAlias = senderAlias
		self.senderFingerprintHex = senderFingerprintHex
		self.items = items
	}
}

public struct DownloadedItemResult: Equatable, Sendable {
	public let itemId: String
	public let savedFileURL: URL?
	public let textContent: String?

	public init(itemId: String, savedFileURL: URL?, textContent: String?) {
		self.itemId = itemId
		self.savedFileURL = savedFileURL
		self.textContent = textContent
	}
}

public enum CoreBridgeError: Error, LocalizedError, Equatable {
	case initializationFailed(String)
	case peerNotFound(String)
	case transferRejected(String)
	case networkUnavailable
	case transferFailed(String)
	case transferCancelled
	case checksumMismatch(String)
	case invalidPayload(String)

	public var errorDescription: String? {
		switch self {
		case .initializationFailed(let details):
			return "Failed to initialize shared core: \(details)"
		case .peerNotFound(let identifier):
			return "Peer not found: \(identifier)"
		case .transferRejected(let reason):
			return "Transfer rejected: \(reason)"
		case .networkUnavailable:
			return "Local network interface unavailable"
		case .transferFailed(let details):
			return "Transfer failed: \(details)"
		case .transferCancelled:
			return "Transfer cancelled"
		case .checksumMismatch(let itemName):
			return "Integrity check failed for \(itemName)"
		case .invalidPayload(let details):
			return "Invalid payload: \(details)"
		}
	}
}

// -----------------------------------------------------------------------------
// 2. Core Bridge Protocol (DIP)
// -----------------------------------------------------------------------------

public protocol AirShipCoreBridgeProtocol: Sendable {
	func getLocalUserNameId() -> String
	func getLocalDisplayAlias() -> String
	func getLocalFingerprint() -> String
	func getNetworkStatusDescription() -> String
	func updateLocalAlias(_ updatedAlias: String) async throws
	func resetLocalIdentity() async throws
	func startBroadcasting() async throws
	func stopBroadcasting() async throws
	func listPeers() async throws -> [PeerBridgeModel]
	func observeDiscoveredPeers() -> AsyncStream<[PeerBridgeModel]>
	func setPeerTrust(peerIdentifier: String, isTrusted: Bool) async throws
	func addPeer(identifier: String, alias: String, fingerprintHex: String, isTrusted: Bool)
		async throws
	func removePeer(identifier: String) async throws -> Bool
	func sendPackage(
		to peerIdentifier: String,
		items: [OutgoingTransferItem],
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws
	func cancelOutgoingTransfer() async
	func observeIncomingPackages() -> AsyncStream<IncomingPackageOffer>
	func downloadIncomingItems(
		packageId: String,
		itemIds: [String],
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws -> [DownloadedItemResult]
	func finishIncomingPackage(packageId: String) async
	func rejectIncomingPackage(packageId: String, reason: String) async
}

// -----------------------------------------------------------------------------
// 3. Mock Protocol Stub for Testing & Previews (LSP)
// -----------------------------------------------------------------------------

public final class MockCoreBridge: AirShipCoreBridgeProtocol, @unchecked Sendable {
	private let lock = NSLock()
	private var peers: [PeerBridgeModel]
	private var localUserNameId: String
	private var localDisplayAlias: String
	private var localFingerprint: String
	private var peerContinuations: [UUID: AsyncStream<[PeerBridgeModel]>.Continuation] = [:]
	private var incomingContinuations: [UUID: AsyncStream<IncomingPackageOffer>.Continuation] = [:]
	private var configuredSendError: Error?
	private var configuredDownloadResultsByItemId: [String: DownloadedItemResult] = [:]
	private var rejectedPackageReasons: [String: String] = [:]
	private var finishedPackageIds: [String] = []
	private var didCancelOutgoingTransfer = false

	public init(
		localUserNameId: String = "USER_SWIFT_DEVICE",
		localDisplayAlias: String = "Swift Mock Device",
		localFingerprint: String = "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
		initialPeers: [PeerBridgeModel] = []
	) {
		self.localUserNameId = localUserNameId
		self.localDisplayAlias = localDisplayAlias
		self.localFingerprint = localFingerprint
		self.peers = initialPeers
	}

	public func getLocalUserNameId() -> String {
		lock.withLock { localUserNameId }
	}

	public func getLocalDisplayAlias() -> String {
		lock.withLock { localDisplayAlias }
	}

	public func getLocalFingerprint() -> String {
		lock.withLock { localFingerprint }
	}

	public func getNetworkStatusDescription() -> String {
		"Wi-Fi LAN Active"
	}

	public func updateLocalAlias(_ updatedAlias: String) async throws {
		let trimmed = updatedAlias.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		lock.withLock {
			localDisplayAlias = trimmed
		}
	}

	public func resetLocalIdentity() async throws {
		lock.withLock {
			localFingerprint = String(repeating: "c", count: 64)
			localUserNameId = "USER_RESET"
		}
	}

	public func startBroadcasting() async throws {}

	public func stopBroadcasting() async throws {}

	public func listPeers() async throws -> [PeerBridgeModel] {
		lock.withLock { peers }
	}

	public func observeDiscoveredPeers() -> AsyncStream<[PeerBridgeModel]> {
		let subscriptionId = UUID()
		let currentPeers = lock.withLock { peers }
		return AsyncStream { continuation in
			self.registerPeerContinuation(id: subscriptionId, continuation: continuation)
			continuation.yield(currentPeers)
			continuation.onTermination = { [weak self] _ in
				self?.removePeerContinuation(id: subscriptionId)
			}
		}
	}

	public func setPeerTrust(peerIdentifier: String, isTrusted: Bool) async throws {
		try lock.withLock {
			guard let matchingIndex = peers.firstIndex(where: { $0.id == peerIdentifier }) else {
				throw CoreBridgeError.peerNotFound(peerIdentifier)
			}

			let existing = peers[matchingIndex]
			peers[matchingIndex] = PeerBridgeModel(
				id: existing.id,
				displayAlias: existing.displayAlias,
				fingerprintHex: existing.fingerprintHex,
				isTrusted: isTrusted
			)
		}
		broadcastPeerSnapshot()
	}

	public func addPeer(identifier: String, alias: String, fingerprintHex: String, isTrusted: Bool)
		async throws
	{
		lock.withLock {
			peers.append(
				PeerBridgeModel(
					id: identifier,
					displayAlias: alias,
					fingerprintHex: fingerprintHex,
					isTrusted: isTrusted
				))
		}
		broadcastPeerSnapshot()
	}

	public func removePeer(identifier: String) async throws -> Bool {
		let removed = lock.withLock {
			let initialCount = peers.count
			peers.removeAll { $0.id == identifier }
			return peers.count < initialCount
		}
		broadcastPeerSnapshot()
		return removed
	}

	public func sendPackage(
		to peerIdentifier: String,
		items: [OutgoingTransferItem],
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws {
		let pendingError = lock.withLock { configuredSendError }
		if let pendingError {
			throw pendingError
		}
		let peerExists = lock.withLock { peers.contains(where: { $0.id == peerIdentifier }) }
		guard peerExists else {
			throw CoreBridgeError.peerNotFound(peerIdentifier)
		}
		let totalBytes = items.reduce(Int64(0)) { $0 + $1.byteSize }
		onProgress(TransferProgressUpdate(phase: .connecting))
		onProgress(TransferProgressUpdate(phase: .transferring(completedBytes: totalBytes, totalBytes: totalBytes)))
		onProgress(TransferProgressUpdate(phase: .completed))
	}

	public func cancelOutgoingTransfer() async {
		lock.withLock {
			didCancelOutgoingTransfer = true
		}
	}

	public func observeIncomingPackages() -> AsyncStream<IncomingPackageOffer> {
		let subscriptionId = UUID()
		return AsyncStream { continuation in
			self.registerIncomingContinuation(id: subscriptionId, continuation: continuation)
			continuation.onTermination = { [weak self] _ in
				self?.removeIncomingContinuation(id: subscriptionId)
			}
		}
	}

	public func downloadIncomingItems(
		packageId: String,
		itemIds: [String],
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws -> [DownloadedItemResult] {
		onProgress(TransferProgressUpdate(phase: .transferring(completedBytes: 1, totalBytes: 1)))
		onProgress(TransferProgressUpdate(phase: .completed))
		return lock.withLock {
			itemIds.map { itemId in
				configuredDownloadResultsByItemId[itemId]
					?? DownloadedItemResult(itemId: itemId, savedFileURL: nil, textContent: nil)
			}
		}
	}

	public func finishIncomingPackage(packageId: String) async {
		lock.withLock {
			finishedPackageIds.append(packageId)
		}
	}

	public func rejectIncomingPackage(packageId: String, reason: String) async {
		lock.withLock {
			rejectedPackageReasons[packageId] = reason
		}
	}

	// Test helper hooks for stubbing behavior in ViewModel unit tests.
	public func setSimulatedSendError(_ error: Error?) {
		lock.withLock { configuredSendError = error }
	}

	public func setSimulatedDownloadResult(_ result: DownloadedItemResult) {
		lock.withLock { configuredDownloadResultsByItemId[result.itemId] = result }
	}

	public func emitIncomingOffer(_ offer: IncomingPackageOffer) {
		let continuations = lock.withLock { Array(incomingContinuations.values) }
		for continuation in continuations {
			continuation.yield(offer)
		}
	}

	public func emitPeerSnapshot(_ updatedPeers: [PeerBridgeModel]) {
		lock.withLock { peers = updatedPeers }
		broadcastPeerSnapshot()
	}

	public func recordedRejectionReason(for packageId: String) -> String? {
		lock.withLock { rejectedPackageReasons[packageId] }
	}

	public func recordedFinishedPackageIds() -> [String] {
		lock.withLock { finishedPackageIds }
	}

	public func wasOutgoingTransferCancelled() -> Bool {
		lock.withLock { didCancelOutgoingTransfer }
	}

	private func registerPeerContinuation(
		id: UUID,
		continuation: AsyncStream<[PeerBridgeModel]>.Continuation
	) {
		lock.withLock { peerContinuations[id] = continuation }
	}

	private func removePeerContinuation(id: UUID) {
		_ = lock.withLock { peerContinuations.removeValue(forKey: id) }
	}

	private func registerIncomingContinuation(
		id: UUID,
		continuation: AsyncStream<IncomingPackageOffer>.Continuation
	) {
		lock.withLock { incomingContinuations[id] = continuation }
	}

	private func removeIncomingContinuation(id: UUID) {
		_ = lock.withLock { incomingContinuations.removeValue(forKey: id) }
	}

	private func broadcastPeerSnapshot() {
		let (snapshot, continuations) = lock.withLock {
			(peers, Array(peerContinuations.values))
		}
		for continuation in continuations {
			continuation.yield(snapshot)
		}
	}
}
