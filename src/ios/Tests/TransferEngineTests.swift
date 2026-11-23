import CryptoKit
import Foundation
import Network
import XCTest

@testable import AirShipKit

// -----------------------------------------------------------------------------
// 1. Loopback Test Harness Helpers
// -----------------------------------------------------------------------------

private final class LoopbackListenerState: @unchecked Sendable {
	private let lock = NSLock()
	private var readyContinuation: CheckedContinuation<UInt16, Error>?
	private var channelContinuation: CheckedContinuation<NetworkFramedChannel, Error>?
	private var bufferedChannel: NetworkFramedChannel?

	func resolveReady(port: UInt16) {
		let continuation = lock.withLock {
			let pending = readyContinuation
			readyContinuation = nil
			return pending
		}
		continuation?.resume(returning: port)
	}

	func failReady(error: Error) {
		let continuation = lock.withLock {
			let pending = readyContinuation
			readyContinuation = nil
			return pending
		}
		continuation?.resume(throwing: error)
	}

	func acceptChannel(_ channel: NetworkFramedChannel) {
		let continuation = lock.withLock { () -> CheckedContinuation<NetworkFramedChannel, Error>? in
			if let pending = channelContinuation {
				channelContinuation = nil
				return pending
			}
			bufferedChannel = channel
			return nil
		}
		continuation?.resume(returning: channel)
	}

	func awaitReady(on listener: NWListener, queue: DispatchQueue) async throws -> UInt16 {
		try await withCheckedThrowingContinuation { continuation in
			lock.withLock { readyContinuation = continuation }
			listener.stateUpdateHandler = { [weak listener] state in
				switch state {
				case .ready:
					if let port = listener?.port?.rawValue {
						self.resolveReady(port: port)
					}
				case .failed(let networkError):
					self.failReady(error: networkError)
				default:
					break
				}
			}
			listener.newConnectionHandler = { incomingConnection in
				Task {
					let channel = NetworkFramedChannel(connection: incomingConnection)
					do {
						try await channel.connectAndAwaitReady()
						self.acceptChannel(channel)
					} catch {
						await channel.close()
					}
				}
			}
			listener.start(queue: queue)
		}
	}

	func nextAcceptedChannel() async throws -> NetworkFramedChannel {
		if let existing = lock.withLock({ () -> NetworkFramedChannel? in
			let channel = bufferedChannel
			bufferedChannel = nil
			return channel
		}) {
			return existing
		}
		return try await withCheckedThrowingContinuation { continuation in
			lock.withLock { channelContinuation = continuation }
		}
	}
}

private final class LockedProgressRecorder: @unchecked Sendable {
	private let lock = NSLock()
	private var phases: [TransferProgressPhase] = []

	func append(_ update: TransferProgressUpdate) {
		lock.withLock { phases.append(update.phase) }
	}

	func recordedPhases() -> [TransferProgressPhase] {
		lock.withLock { phases }
	}
}

// -----------------------------------------------------------------------------
// 2. Wire Codec, Identity, Loopback Transfer & ViewModel Tests
// -----------------------------------------------------------------------------

final class TransferEngineTests: XCTestCase {
	private func makeTempDirectory(prefix: String) throws -> URL {
		let directoryURL = FileManager.default.temporaryDirectory
			.appendingPathComponent("\(prefix)_\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
		addTeardownBlock {
			try? FileManager.default.removeItem(at: directoryURL)
		}
		return directoryURL
	}

	private func makeSampleIdentity(userNameId: String = "USER_SENDER01", alias: String = "Sender")
		-> LocalDeviceIdentity
	{
		LocalDeviceIdentity(
			userNameId: userNameId,
			displayAlias: alias,
			fingerprintHex: String(repeating: "a", count: 64),
			publicKeyBytes: Data(repeating: 0x11, count: 32)
		)
	}

	private func startLoopbackServer() async throws -> (NWListener, LoopbackListenerState, UInt16) {
		let listener = try NWListener(using: makeAirShipTcpParameters())
		let state = LoopbackListenerState()
		let queue = DispatchQueue(label: "com.skdvcsm.airship.test.listener.\(UUID().uuidString)")
		let port = try await state.awaitReady(on: listener, queue: queue)
		return (listener, state, port)
	}

	private func connectLoopbackClient(port: UInt16) async throws -> NetworkFramedChannel {
		guard let nwPort = NWEndpoint.Port(rawValue: port) else {
			throw CoreBridgeError.networkUnavailable
		}
		let endpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: nwPort)
		let channel = NetworkFramedChannel(endpoint: endpoint, parameters: makeAirShipTcpParameters())
		try await channel.connectAndAwaitReady()
		return channel
	}

	// -------------------------------------------------------------------------
	// Wire Codec & Filename Helpers
	// -------------------------------------------------------------------------

	func testWireFrameRoundTripAndValidation() throws {
		let allTypes: [WireFrameType] = [
			.manifestOffer,
			.manifestPending,
			.requestItems,
			.itemHeader,
			.itemChunk,
			.itemComplete,
			.transferComplete,
			.transferRejected,
			.transferError,
		]

		for frameType in allTypes {
			let payload = Data("payload-\(frameType.rawValue)".utf8)
			let frame = try WireFrame(frameType: frameType, payloadBytes: payload)
			let packet = try frame.encodeHeaderAndPayload()
			let header = packet.prefix(TransferProtocolConstants.headerByteLength)
			let body = packet.dropFirst(TransferProtocolConstants.headerByteLength)

			let (decodedType, decodedLength) = try WireFrame.decodeHeader(Data(header))
			XCTAssertEqual(decodedType, frameType)
			XCTAssertEqual(Int(decodedLength), payload.count)
			XCTAssertEqual(Data(body), payload)
		}

		let oversizedBytes = Data(count: Int(TransferProtocolConstants.maxFramePayloadBytes) + 1)
		XCTAssertThrowsError(try WireFrame(frameType: .itemChunk, payloadBytes: oversizedBytes))

		let invalidTypeHeader = Data([0xEE, 0x00, 0x00, 0x00, 0x04])
		XCTAssertThrowsError(try WireFrame.decodeHeader(invalidTypeHeader))
	}

	func testFilenameSanitizationCollisionAndStreamedSha256() throws {
		XCTAssertEqual(sanitizedDownloadFilename("../../etc/secret.txt"), "secret.txt")
		XCTAssertTrue(sanitizedDownloadFilename("").hasPrefix("AirShip_Item_"))
		XCTAssertTrue(sanitizedDownloadFilename("..").hasPrefix("AirShip_Item_"))

		let tempDirectory = try makeTempDirectory(prefix: "AirShipCollision")
		let firstURL = uniqueDestinationFileURL(in: tempDirectory, preferredFilename: "Photo.jpg")
		XCTAssertEqual(firstURL.lastPathComponent, "Photo.jpg")
		try Data("one".utf8).write(to: firstURL)

		let secondURL = uniqueDestinationFileURL(in: tempDirectory, preferredFilename: "Photo.jpg")
		XCTAssertEqual(secondURL.lastPathComponent, "Photo (1).jpg")
		try Data("two".utf8).write(to: secondURL)

		let thirdURL = uniqueDestinationFileURL(in: tempDirectory, preferredFilename: "Photo.jpg")
		XCTAssertEqual(thirdURL.lastPathComponent, "Photo (2).jpg")

		let multiChunkPayload = Data((0..<180_000).map { UInt8($0 & 0xFF) })
		let hashFileURL = tempDirectory.appendingPathComponent("big.bin")
		try multiChunkPayload.write(to: hashFileURL)
		let streamedHash = try computeFileSha256Hex(at: hashFileURL)
		XCTAssertEqual(streamedHash, computeBytesSha256Hex(multiChunkPayload))
	}

	// -------------------------------------------------------------------------
	// Persistent Identity Store
	// -------------------------------------------------------------------------

	func testUserDefaultsIdentityStorePersistenceAndReset() {
		let suiteName = "com.skdvcsm.airship.tests.\(UUID().uuidString)"
		addTeardownBlock {
			UserDefaults().removePersistentDomain(forName: suiteName)
		}

		let store = UserDefaultsIdentityStore(suiteName: suiteName)
		let initial = store.loadOrCreateIdentity()
		XCTAssertEqual(initial.fingerprintHex.count, 64)
		XCTAssertTrue(initial.userNameId.hasPrefix("USER_"))

		let reloadedStore = UserDefaultsIdentityStore(suiteName: suiteName)
		XCTAssertEqual(reloadedStore.loadOrCreateIdentity().fingerprintHex, initial.fingerprintHex)

		let updated = store.updateDisplayAlias("Felix iPhone")
		XCTAssertEqual(updated.displayAlias, "Felix iPhone")
		XCTAssertEqual(reloadedStore.loadOrCreateIdentity().displayAlias, "Felix iPhone")

		let regenerated = store.regenerateIdentity()
		XCTAssertNotEqual(regenerated.fingerprintHex, initial.fingerprintHex)
		XCTAssertNotEqual(regenerated.userNameId, initial.userNameId)
	}

	// -------------------------------------------------------------------------
	// Real Loopback TCP Transfer Tests (NWListener + NWConnection)
	// -------------------------------------------------------------------------

	func testLoopbackTransferDownloadAllFileAndText() async throws {
		let sourceDirectory = try makeTempDirectory(prefix: "AirShipLoopSource")
		let downloadsDirectory = try makeTempDirectory(prefix: "AirShipLoopDest")

		let binaryPayload = Data((0..<200_000).map { UInt8(($0 * 7) & 0xFF) })
		let sourceFileURL = sourceDirectory.appendingPathComponent("payload.bin")
		try binaryPayload.write(to: sourceFileURL)
		let textMessage = "Hello from iPhone 18 Pro Max Simulator!"

		let (listener, state, port) = try await startLoopbackServer()
		defer { listener.cancel() }

		let clientChannel = try await connectLoopbackClient(port: port)
		let serverChannel = try await state.nextAcceptedChannel()

		let transferClient = PackageTransferClient()
		let senderIdentity = makeSampleIdentity()
		let senderRecorder = LockedProgressRecorder()
		let items = [
			OutgoingTransferItem(
				id: "item-bin",
				name: "payload.bin",
				byteSize: Int64(binaryPayload.count),
				mimeType: "application/octet-stream",
				isTextSnippet: false,
				payloadSource: .fileURL(sourceFileURL)
			),
			OutgoingTransferItem(
				id: "item-txt",
				name: "Greeting",
				byteSize: Int64(textMessage.utf8.count),
				mimeType: "text/plain",
				isTextSnippet: true,
				payloadSource: .textContent(textMessage)
			),
		]

		let sendTask = Task {
			try await transferClient.sendPackage(
				channel: clientChannel,
				senderIdentity: senderIdentity,
				items: items
			) { update in
				senderRecorder.append(update)
			}
		}

		let (session, offer) = try await IncomingPackageSession.open(
			channel: serverChannel,
			downloadsDirectoryURL: downloadsDirectory
		)
		XCTAssertEqual(offer.senderIdentifier, senderIdentity.userNameId)
		XCTAssertEqual(offer.items.count, 2)

		let receiverRecorder = LockedProgressRecorder()
		let results = try await session.downloadItems(
			itemIds: offer.items.map(\.id)
		) { update in
			receiverRecorder.append(update)
		}
		try await sendTask.value

		XCTAssertEqual(results.count, 2)
		let savedBinaryURL = try XCTUnwrap(results[0].savedFileURL)
		XCTAssertEqual(try Data(contentsOf: savedBinaryURL), binaryPayload)
		XCTAssertEqual(results[1].textContent, textMessage)
		XCTAssertEqual(senderRecorder.recordedPhases().last, .completed)
		XCTAssertEqual(receiverRecorder.recordedPhases().last, .completed)
	}

	func testLoopbackTransferIndividualItemDownloads() async throws {
		let sourceDirectory = try makeTempDirectory(prefix: "AirShipSingleSource")
		let downloadsDirectory = try makeTempDirectory(prefix: "AirShipSingleDest")

		let firstBytes = Data("FIRST-FILE-PAYLOAD".utf8)
		let secondBytes = Data("SECOND-FILE-PAYLOAD".utf8)
		let firstURL = sourceDirectory.appendingPathComponent("first.txt")
		let secondURL = sourceDirectory.appendingPathComponent("second.txt")
		try firstBytes.write(to: firstURL)
		try secondBytes.write(to: secondURL)

		let (listener, state, port) = try await startLoopbackServer()
		defer { listener.cancel() }

		let clientChannel = try await connectLoopbackClient(port: port)
		let serverChannel = try await state.nextAcceptedChannel()

		let transferClient = PackageTransferClient()
		let outgoing = [
			OutgoingTransferItem(
				id: "one",
				name: "first.txt",
				byteSize: Int64(firstBytes.count),
				mimeType: "text/plain",
				isTextSnippet: false,
				payloadSource: .fileURL(firstURL)
			),
			OutgoingTransferItem(
				id: "two",
				name: "second.txt",
				byteSize: Int64(secondBytes.count),
				mimeType: "text/plain",
				isTextSnippet: false,
				payloadSource: .fileURL(secondURL)
			),
		]

		let senderIdentity = makeSampleIdentity()
		let sendTask = Task {
			try await transferClient.sendPackage(
				channel: clientChannel,
				senderIdentity: senderIdentity,
				items: outgoing
			) { _ in }
		}

		let (session, _) = try await IncomingPackageSession.open(
			channel: serverChannel,
			downloadsDirectoryURL: downloadsDirectory
		)
		let firstResult = try await session.downloadItems(itemIds: ["one"]) { _ in }
		XCTAssertEqual(firstResult.count, 1)
		let savedFirstURL = try XCTUnwrap(firstResult[0].savedFileURL)
		XCTAssertEqual(try Data(contentsOf: savedFirstURL), firstBytes)

		let secondResult = try await session.downloadItems(itemIds: ["two"]) { _ in }
		try await sendTask.value

		XCTAssertEqual(secondResult.count, 1)
		let savedSecondURL = try XCTUnwrap(secondResult[0].savedFileURL)
		XCTAssertEqual(try Data(contentsOf: savedSecondURL), secondBytes)
	}

	func testLoopbackTransferRejection() async throws {
		let (listener, state, port) = try await startLoopbackServer()
		defer { listener.cancel() }

		let clientChannel = try await connectLoopbackClient(port: port)
		let serverChannel = try await state.nextAcceptedChannel()
		let downloadsDirectory = try makeTempDirectory(prefix: "AirShipRejectDest")

		let transferClient = PackageTransferClient()
		let outgoing = [
			OutgoingTransferItem(
				id: "note-1",
				name: "Note",
				byteSize: 5,
				mimeType: "text/plain",
				isTextSnippet: true,
				payloadSource: .textContent("Hello")
			)
		]

		let senderIdentity = makeSampleIdentity()
		let sendTask = Task {
			try await transferClient.sendPackage(
				channel: clientChannel,
				senderIdentity: senderIdentity,
				items: outgoing
			) { _ in }
		}

		let (session, _) = try await IncomingPackageSession.open(
			channel: serverChannel,
			downloadsDirectoryURL: downloadsDirectory
		)
		await session.rejectSession(reason: "Busy")

		do {
			try await sendTask.value
			XCTFail("Expected transferRejected error")
		} catch let bridgeError as CoreBridgeError {
			XCTAssertEqual(bridgeError, .transferRejected("Busy"))
		}
	}

	// -------------------------------------------------------------------------
	// ViewModel Integration Tests
	// -------------------------------------------------------------------------

	@MainActor
	func testNearbyPeerSelectorLiveUpdatesAndFailurePreservesStagedItems() async throws {
		let bridge = MockCoreBridge()
		let stagingDirectory = try makeTempDirectory(prefix: "AirShipVmStage")
		let stagingService = LocalAttachmentStagingService(stagingDirectoryURL: stagingDirectory)
		let sendViewModel = SendViewModel(coreBridge: bridge, stagingService: stagingService)
		sendViewModel.addTextAttachment(textSnippet: "Test note")

		let selectorViewModel = sendViewModel.makePeerSelectorViewModel()
		let observerTask = Task {
			await selectorViewModel.startObservingNearbyPeers()
		}
		defer { observerTask.cancel() }

		let discoveredPeer = PeerBridgeModel(
			id: "USER_IPHONE_REAL",
			displayAlias: "Real iPhone",
			fingerprintHex: String(repeating: "f", count: 64),
			isTrusted: false
		)
		bridge.emitPeerSnapshot([discoveredPeer])
		try await Task.sleep(for: .milliseconds(30))
		XCTAssertEqual(selectorViewModel.nearbyPeers, [discoveredPeer])

		bridge.setSimulatedSendError(CoreBridgeError.transferRejected("Declined by recipient"))
		await selectorViewModel.dispatchPackage(to: discoveredPeer.id)

		XCTAssertEqual(
			selectorViewModel.transferState,
			.failed("Transfer rejected: Declined by recipient")
		)
		XCTAssertNotNil(selectorViewModel.errorMessage)
		XCTAssertEqual(sendViewModel.stagedItems.count, 1)
	}

	@MainActor
	func testReceiveViewModelLiveOfferDownloadAndDecline() async throws {
		let bridge = MockCoreBridge()
		let receiveViewModel = ReceiveViewModel(coreBridge: bridge)
		let listenerTask = Task {
			await receiveViewModel.startListeningForIncomingPackages()
		}
		defer { listenerTask.cancel() }

		let downloadsDirectory = try makeTempDirectory(prefix: "AirShipVmReceive")
		let savedFileURL = downloadsDirectory.appendingPathComponent("image.jpg")
		try Data([0x01, 0x02]).write(to: savedFileURL)
		bridge.setSimulatedDownloadResult(
			DownloadedItemResult(itemId: "item-a", savedFileURL: savedFileURL, textContent: nil)
		)

		let offer = IncomingPackageOffer(
			id: "pkg-100",
			senderIdentifier: "USER_ALICE",
			senderAlias: "Alice",
			senderFingerprintHex: String(repeating: "b", count: 64),
			items: [
				IncomingPackageItemBridgeModel(
					id: "item-a",
					name: "image.jpg",
					byteSize: 2,
					mimeType: "image/jpeg",
					isTextSnippet: false,
					sha256Hex: String(repeating: "c", count: 64)
				)
			]
		)

		try await Task.sleep(for: .milliseconds(20))
		bridge.emitIncomingOffer(offer)
		try await Task.sleep(for: .milliseconds(30))

		guard case .packageReceived(let offeredItems) = receiveViewModel.screenState else {
			XCTFail("Expected packageReceived state")
			return
		}
		XCTAssertEqual(offeredItems.count, 1)
		XCTAssertEqual(receiveViewModel.senderAlias, "Alice")

		await receiveViewModel.performDownloadSingleItem(id: "item-a")
		XCTAssertEqual(receiveViewModel.screenState, .completed)
		XCTAssertEqual(receiveViewModel.savedItems.first?.localFileURL, savedFileURL)

		receiveViewModel.resetToWaiting()
		XCTAssertEqual(receiveViewModel.screenState, .waiting)

		let secondOffer = IncomingPackageOffer(
			id: "pkg-101",
			senderIdentifier: "USER_BOB",
			senderAlias: "Bob",
			senderFingerprintHex: String(repeating: "d", count: 64),
			items: offer.items
		)
		bridge.emitIncomingOffer(secondOffer)
		try await Task.sleep(for: .milliseconds(30))

		await receiveViewModel.declineIncomingPackage()
		XCTAssertEqual(receiveViewModel.screenState, .waiting)
		XCTAssertEqual(bridge.recordedRejectionReason(for: "pkg-101"), "Declined by recipient")
	}
}
