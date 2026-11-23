import Foundation
import Network

public struct DiscoveredPeerRecord: Equatable, Sendable {
	public let peerModel: PeerBridgeModel
	public let endpoint: NWEndpoint
	public let prefersWifiInterface: Bool

	public init(
		peerModel: PeerBridgeModel,
		endpoint: NWEndpoint,
		prefersWifiInterface: Bool = false
	) {
		self.peerModel = peerModel
		self.endpoint = endpoint
		self.prefersWifiInterface = prefersWifiInterface
	}
}

public protocol PeerBrowserProtocol: Sendable {
	func startBrowsing(
		localUserNameId: String,
		onPeersChanged: @escaping @Sendable ([DiscoveredPeerRecord]) -> Void
	) async
	func stopBrowsing() async
	func currentDiscoveredPeers() async -> [DiscoveredPeerRecord]
	func endpoint(forPeerId peerId: String) async -> NWEndpoint?
}

private func extractTxtMetadata(from result: NWBrowser.Result) -> NWTXTRecord? {
	guard case .bonjour(let txtRecord) = result.metadata else {
		return nil
	}
	return txtRecord
}

private func parsePeerRecord(
	from result: NWBrowser.Result,
	localUserNameId: String
) -> DiscoveredPeerRecord? {
	guard case .service(let serviceName, _, _, _) = result.endpoint else {
		return nil
	}
	let txtRecord = extractTxtMetadata(from: result)
	let resolvedId = txtRecord?[TransferProtocolConstants.txtPeerIdKey] ?? serviceName
	guard !resolvedId.isEmpty, resolvedId != localUserNameId else {
		return nil
	}
	let resolvedAlias = txtRecord?[TransferProtocolConstants.txtAliasKey] ?? resolvedId
	let resolvedFingerprint = txtRecord?[TransferProtocolConstants.txtFingerprintKey] ?? ""
	let usesWifi = result.interfaces.contains { $0.type == .wifi }
	let peerModel = PeerBridgeModel(
		id: resolvedId,
		displayAlias: resolvedAlias,
		fingerprintHex: resolvedFingerprint,
		isTrusted: false
	)
	return DiscoveredPeerRecord(
		peerModel: peerModel,
		endpoint: result.endpoint,
		prefersWifiInterface: usesWifi
	)
}

private func shouldReplaceExistingRecord(
	_ existing: DiscoveredPeerRecord,
	with candidate: DiscoveredPeerRecord
) -> Bool {
	if existing.peerModel.fingerprintHex.isEmpty && !candidate.peerModel.fingerprintHex.isEmpty {
		return true
	}
	return !existing.prefersWifiInterface && candidate.prefersWifiInterface
}

private func deduplicatedSortedPeers(
	from results: Set<NWBrowser.Result>,
	localUserNameId: String
) -> [String: DiscoveredPeerRecord] {
	var recordsById: [String: DiscoveredPeerRecord] = [:]
	for result in results {
		guard let candidate = parsePeerRecord(from: result, localUserNameId: localUserNameId) else {
			continue
		}
		let peerId = candidate.peerModel.id
		if let existing = recordsById[peerId], !shouldReplaceExistingRecord(existing, with: candidate) {
			continue
		}
		recordsById[peerId] = candidate
	}
	return recordsById
}

private func sortedPeerRecords(_ recordsById: [String: DiscoveredPeerRecord])
	-> [DiscoveredPeerRecord]
{
	return recordsById.values.sorted { leftRecord, rightRecord in
		let aliasOrder = leftRecord.peerModel.displayAlias.localizedCaseInsensitiveCompare(
			rightRecord.peerModel.displayAlias
		)
		if aliasOrder != .orderedSame {
			return aliasOrder == .orderedAscending
		}
		return leftRecord.peerModel.id < rightRecord.peerModel.id
	}
}

public actor BonjourPeerBrowser: PeerBrowserProtocol {
	private let browserQueue = DispatchQueue(label: "com.skdvcsm.airship.bonjour.browser")
	private var activeBrowser: NWBrowser?
	private var discoveredById: [String: DiscoveredPeerRecord] = [:]
	private var localUserNameId: String = ""

	public init() {}

	public func startBrowsing(
		localUserNameId: String,
		onPeersChanged: @escaping @Sendable ([DiscoveredPeerRecord]) -> Void
	) async {
		await stopBrowsing()
		self.localUserNameId = localUserNameId

		let descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(
			type: TransferProtocolConstants.bonjourServiceType,
			domain: nil
		)
		let browser = NWBrowser(for: descriptor, using: makeAirShipTcpParameters())
		browser.browseResultsChangedHandler = { [weak self] updatedResults, _ in
			guard let self else { return }
			Task {
				await self.handleBrowseResults(updatedResults, onPeersChanged: onPeersChanged)
			}
		}
		activeBrowser = browser
		browser.start(queue: browserQueue)
	}

	public func stopBrowsing() async {
		if let browser = activeBrowser {
			activeBrowser = nil
			browser.browseResultsChangedHandler = nil
			browser.stateUpdateHandler = nil
			browser.cancel()
		}
		discoveredById.removeAll()
	}

	public func currentDiscoveredPeers() async -> [DiscoveredPeerRecord] {
		return sortedPeerRecords(discoveredById)
	}

	public func endpoint(forPeerId peerId: String) async -> NWEndpoint? {
		return discoveredById[peerId]?.endpoint
	}

	private func handleBrowseResults(
		_ results: Set<NWBrowser.Result>,
		onPeersChanged: @escaping @Sendable ([DiscoveredPeerRecord]) -> Void
	) {
		discoveredById = deduplicatedSortedPeers(from: results, localUserNameId: localUserNameId)
		onPeersChanged(sortedPeerRecords(discoveredById))
	}
}
