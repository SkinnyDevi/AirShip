import Foundation
import Network

private actor LiveCoreBridgeCoordinator {
	private let identityStore: any DeviceIdentityStoring
	private let advertiser: any PeerAdvertiserProtocol
	private let browser: any PeerBrowserProtocol
	private let transferClient: any PackageTransferSending
	private let backgroundAssertion: any BackgroundTaskAsserting
	private let downloadsDirectoryURL: URL

	private var localIdentity: LocalDeviceIdentity
	private var networkStatusText: String = "Starting Local Network..."
	private var isRunning = false
	private var discoveredPeers: [PeerBridgeModel] = []
	private var storedTrustPeersById: [String: PeerBridgeModel] = [:]
	private var peerContinuations: [UUID: AsyncStream<[PeerBridgeModel]>.Continuation] = [:]
	private var incomingContinuations: [UUID: AsyncStream<IncomingPackageOffer>.Continuation] = [:]
	private var activeOutgoingChannel: (any FramedByteChannel)?
	private var activeIncomingSession: IncomingPackageSession?

	init(
		identityStore: any DeviceIdentityStoring,
		advertiser: any PeerAdvertiserProtocol,
		browser: any PeerBrowserProtocol,
		transferClient: any PackageTransferSending,
		backgroundAssertion: any BackgroundTaskAsserting,
		downloadsDirectoryURL: URL
	) {
		self.identityStore = identityStore
		self.advertiser = advertiser
		self.browser = browser
		self.transferClient = transferClient
		self.backgroundAssertion = backgroundAssertion
		self.downloadsDirectoryURL = downloadsDirectoryURL
		self.localIdentity = identityStore.loadOrCreateIdentity()
	}

	func currentIdentity() -> LocalDeviceIdentity {
		return localIdentity
	}

	func currentNetworkStatus() -> String {
		return networkStatusText
	}

	func updateAlias(_ updatedAlias: String) async throws {
		localIdentity = identityStore.updateDisplayAlias(updatedAlias)
		if isRunning {
			try await restartServices()
		}
	}

	func resetIdentity() async throws {
		localIdentity = identityStore.regenerateIdentity()
		if isRunning {
			try await restartServices()
		}
	}

	func startServices() async throws {
		guard !isRunning else { return }
		isRunning = true

		try await advertiser.startAdvertising(
			identity: localIdentity,
			onIncomingChannel: { [weak self] channel in
				Task { await self?.acceptIncomingChannel(channel) }
			},
			onStatusChange: { [weak self] statusText in
				Task { await self?.updateNetworkStatus(statusText) }
			}
		)

		await browser.startBrowsing(localUserNameId: localIdentity.userNameId) { [weak self] records in
			Task { await self?.handleDiscoveredRecords(records) }
		}
	}

	func stopServices() async {
		guard isRunning else { return }
		isRunning = false
		await advertiser.stopAdvertising()
		await browser.stopBrowsing()
		discoveredPeers = []
		networkStatusText = "Stopped"
		broadcastCurrentPeers()
	}

	func currentPeerSnapshot() -> [PeerBridgeModel] {
		return mergedPeerList()
	}

	func registerPeerObserver(
		id: UUID,
		continuation: AsyncStream<[PeerBridgeModel]>.Continuation
	) {
		peerContinuations[id] = continuation
		continuation.yield(mergedPeerList())
	}

	func removePeerObserver(id: UUID) {
		peerContinuations.removeValue(forKey: id)
	}

	func registerIncomingObserver(
		id: UUID,
		continuation: AsyncStream<IncomingPackageOffer>.Continuation
	) {
		incomingContinuations[id] = continuation
	}

	func removeIncomingObserver(id: UUID) {
		incomingContinuations.removeValue(forKey: id)
	}

	func setPeerTrust(peerIdentifier: String, isTrusted: Bool) throws {
		if let stored = storedTrustPeersById[peerIdentifier] {
			storedTrustPeersById[peerIdentifier] = PeerBridgeModel(
				id: stored.id,
				displayAlias: stored.displayAlias,
				fingerprintHex: stored.fingerprintHex,
				isTrusted: isTrusted
			)
		} else if let discovered = discoveredPeers.first(where: { $0.id == peerIdentifier }) {
			storedTrustPeersById[peerIdentifier] = PeerBridgeModel(
				id: discovered.id,
				displayAlias: discovered.displayAlias,
				fingerprintHex: discovered.fingerprintHex,
				isTrusted: isTrusted
			)
		} else {
			throw CoreBridgeError.peerNotFound(peerIdentifier)
		}
		broadcastCurrentPeers()
	}

	func addPeer(identifier: String, alias: String, fingerprintHex: String, isTrusted: Bool) {
		storedTrustPeersById[identifier] = PeerBridgeModel(
			id: identifier,
			displayAlias: alias,
			fingerprintHex: fingerprintHex,
			isTrusted: isTrusted
		)
		broadcastCurrentPeers()
	}

	func removePeer(identifier: String) -> Bool {
		let removed = storedTrustPeersById.removeValue(forKey: identifier) != nil
		broadcastCurrentPeers()
		return removed
	}

	func sendPackage(
		to peerIdentifier: String,
		items: [OutgoingTransferItem],
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws {
		guard let endpoint = await browser.endpoint(forPeerId: peerIdentifier) else {
			throw CoreBridgeError.peerNotFound(peerIdentifier)
		}
		let channel = NetworkFramedChannel(endpoint: endpoint, parameters: makeAirShipTcpParameters())
		activeOutgoingChannel = channel
		let backgroundToken = await backgroundAssertion.begin(name: "AirShipOutgoingTransfer")

		defer {
			Task {
				await channel.close()
				await backgroundAssertion.end(backgroundToken)
			}
		}

		onProgress(TransferProgressUpdate(phase: .connecting))
		try await channel.connectAndAwaitReady()
		try await transferClient.sendPackage(
			channel: channel,
			senderIdentity: localIdentity,
			items: items,
			onProgress: onProgress
		)
		activeOutgoingChannel = nil
	}

	func cancelOutgoingTransfer() async {
		guard let channel = activeOutgoingChannel else { return }
		activeOutgoingChannel = nil
		await channel.close()
	}

	func downloadIncomingItems(
		packageId: String,
		itemIds: [String],
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws -> [DownloadedItemResult] {
		guard let session = activeIncomingSession, session.manifest.packageId == packageId else {
			throw CoreBridgeError.transferFailed("Incoming package session is no longer active")
		}
		let backgroundToken = await backgroundAssertion.begin(name: "AirShipIncomingTransfer")
		defer {
			Task { await backgroundAssertion.end(backgroundToken) }
		}
		return try await session.downloadItems(itemIds: itemIds, onProgress: onProgress)
	}

	func finishIncomingPackage(packageId: String) async {
		guard let session = activeIncomingSession, session.manifest.packageId == packageId else {
			return
		}
		activeIncomingSession = nil
		await session.finishSession()
	}

	func rejectIncomingPackage(packageId: String, reason: String) async {
		guard let session = activeIncomingSession, session.manifest.packageId == packageId else {
			return
		}
		activeIncomingSession = nil
		await session.rejectSession(reason: reason)
	}

	private func restartServices() async throws {
		await stopServices()
		try await startServices()
	}

	private func updateNetworkStatus(_ statusText: String) {
		networkStatusText = statusText
	}

	private func handleDiscoveredRecords(_ records: [DiscoveredPeerRecord]) {
		discoveredPeers = records.map { $0.peerModel }
		broadcastCurrentPeers()
	}

	private func mergedPeerList() -> [PeerBridgeModel] {
		var peersById: [String: PeerBridgeModel] = [:]
		for peer in discoveredPeers {
			let trustFlag = storedTrustPeersById[peer.id]?.isTrusted ?? peer.isTrusted
			peersById[peer.id] = PeerBridgeModel(
				id: peer.id,
				displayAlias: peer.displayAlias,
				fingerprintHex: peer.fingerprintHex,
				isTrusted: trustFlag
			)
		}
		for (identifier, storedPeer) in storedTrustPeersById where peersById[identifier] == nil {
			peersById[identifier] = storedPeer
		}
		return peersById.values.sorted { leftPeer, rightPeer in
			leftPeer.displayAlias.localizedCaseInsensitiveCompare(rightPeer.displayAlias)
				== .orderedAscending
		}
	}

	private func broadcastCurrentPeers() {
		let snapshot = mergedPeerList()
		for continuation in peerContinuations.values {
			continuation.yield(snapshot)
		}
	}

	private func acceptIncomingChannel(_ channel: any FramedByteChannel) async {
		if activeIncomingSession != nil {
			if let rejectFrame = try? encodeWireFrame(
				type: .transferRejected,
				payload: WireReasonPayload(reason: "Recipient is busy with another transfer")
			) {
				try? await channel.writeFrame(rejectFrame)
			}
			await channel.close()
			return
		}

		do {
			let (session, offer) = try await IncomingPackageSession.open(
				channel: channel,
				downloadsDirectoryURL: downloadsDirectoryURL
			)
			activeIncomingSession = session
			for continuation in incomingContinuations.values {
				continuation.yield(offer)
			}
		} catch {
			await channel.close()
		}
	}
}

public final class LiveAirShipCoreBridge: AirShipCoreBridgeProtocol, @unchecked Sendable {
	private let coordinator: LiveCoreBridgeCoordinator
	private let cachedIdentityLock = NSLock()
	private var cachedIdentity: LocalDeviceIdentity
	private var cachedNetworkStatus: String = "Starting Local Network..."

	public init(
		identityStore: any DeviceIdentityStoring = UserDefaultsIdentityStore(),
		advertiser: any PeerAdvertiserProtocol = BonjourPeerAdvertiser(),
		browser: any PeerBrowserProtocol = BonjourPeerBrowser(),
		transferClient: any PackageTransferSending = PackageTransferClient(),
		backgroundAssertion: any BackgroundTaskAsserting = BackgroundTransferAssertion(),
		downloadsDirectoryURL: URL = defaultReceivedDownloadsDirectoryURL()
	) {
		self.cachedIdentity = identityStore.loadOrCreateIdentity()
		self.coordinator = LiveCoreBridgeCoordinator(
			identityStore: identityStore,
			advertiser: advertiser,
			browser: browser,
			transferClient: transferClient,
			backgroundAssertion: backgroundAssertion,
			downloadsDirectoryURL: downloadsDirectoryURL
		)
	}

	public func getLocalUserNameId() -> String {
		cachedIdentityLock.withLock { cachedIdentity.userNameId }
	}

	public func getLocalDisplayAlias() -> String {
		cachedIdentityLock.withLock { cachedIdentity.displayAlias }
	}

	public func getLocalFingerprint() -> String {
		cachedIdentityLock.withLock { cachedIdentity.fingerprintHex }
	}

	public func getNetworkStatusDescription() -> String {
		cachedIdentityLock.withLock { cachedNetworkStatus }
	}

	public func updateLocalAlias(_ updatedAlias: String) async throws {
		try await coordinator.updateAlias(updatedAlias)
		let refreshed = await coordinator.currentIdentity()
		cachedIdentityLock.withLock { cachedIdentity = refreshed }
	}

	public func resetLocalIdentity() async throws {
		try await coordinator.resetIdentity()
		let refreshed = await coordinator.currentIdentity()
		cachedIdentityLock.withLock { cachedIdentity = refreshed }
	}

	public func startBroadcasting() async throws {
		try await coordinator.startServices()
		let status = await coordinator.currentNetworkStatus()
		cachedIdentityLock.withLock { cachedNetworkStatus = status }
	}

	public func stopBroadcasting() async throws {
		await coordinator.stopServices()
		let status = await coordinator.currentNetworkStatus()
		cachedIdentityLock.withLock { cachedNetworkStatus = status }
	}

	public func listPeers() async throws -> [PeerBridgeModel] {
		let status = await coordinator.currentNetworkStatus()
		cachedIdentityLock.withLock { cachedNetworkStatus = status }
		return await coordinator.currentPeerSnapshot()
	}

	public func observeDiscoveredPeers() -> AsyncStream<[PeerBridgeModel]> {
		let subscriptionId = UUID()
		return AsyncStream { continuation in
			Task {
				await coordinator.registerPeerObserver(id: subscriptionId, continuation: continuation)
			}
			continuation.onTermination = { [weak self] _ in
				guard let self else { return }
				Task { await self.coordinator.removePeerObserver(id: subscriptionId) }
			}
		}
	}

	public func setPeerTrust(peerIdentifier: String, isTrusted: Bool) async throws {
		try await coordinator.setPeerTrust(peerIdentifier: peerIdentifier, isTrusted: isTrusted)
	}

	public func addPeer(identifier: String, alias: String, fingerprintHex: String, isTrusted: Bool)
		async throws
	{
		await coordinator.addPeer(
			identifier: identifier,
			alias: alias,
			fingerprintHex: fingerprintHex,
			isTrusted: isTrusted
		)
	}

	public func removePeer(identifier: String) async throws -> Bool {
		return await coordinator.removePeer(identifier: identifier)
	}

	public func sendPackage(
		to peerIdentifier: String,
		items: [OutgoingTransferItem],
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws {
		try await coordinator.sendPackage(
			to: peerIdentifier,
			items: items,
			onProgress: onProgress
		)
	}

	public func cancelOutgoingTransfer() async {
		await coordinator.cancelOutgoingTransfer()
	}

	public func observeIncomingPackages() -> AsyncStream<IncomingPackageOffer> {
		let subscriptionId = UUID()
		return AsyncStream { continuation in
			Task {
				await coordinator.registerIncomingObserver(id: subscriptionId, continuation: continuation)
			}
			continuation.onTermination = { [weak self] _ in
				guard let self else { return }
				Task { await self.coordinator.removeIncomingObserver(id: subscriptionId) }
			}
		}
	}

	public func downloadIncomingItems(
		packageId: String,
		itemIds: [String],
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws -> [DownloadedItemResult] {
		return try await coordinator.downloadIncomingItems(
			packageId: packageId,
			itemIds: itemIds,
			onProgress: onProgress
		)
	}

	public func finishIncomingPackage(packageId: String) async {
		await coordinator.finishIncomingPackage(packageId: packageId)
	}

	public func rejectIncomingPackage(packageId: String, reason: String) async {
		await coordinator.rejectIncomingPackage(packageId: packageId, reason: reason)
	}
}
