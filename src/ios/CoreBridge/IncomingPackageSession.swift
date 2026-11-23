import CryptoKit
import Foundation

private func buildIncomingOffer(from manifest: WirePackageManifest) -> IncomingPackageOffer {
	let mappedItems = manifest.items.map { wireItem in
		IncomingPackageItemBridgeModel(
			id: wireItem.id,
			name: wireItem.name,
			byteSize: wireItem.byteSize,
			mimeType: wireItem.mimeType,
			isTextSnippet: wireItem.isTextSnippet,
			sha256Hex: wireItem.sha256Hex
		)
	}
	return IncomingPackageOffer(
		id: manifest.packageId,
		senderIdentifier: manifest.senderId,
		senderAlias: manifest.senderAlias,
		senderFingerprintHex: manifest.senderFingerprint,
		items: mappedItems
	)
}

private func createTempPartFileURL() -> URL {
	return FileManager.default.temporaryDirectory
		.appendingPathComponent("airship_part_\(UUID().uuidString)")
}

public actor IncomingPackageSession {
	private let channel: any FramedByteChannel
	public let manifest: WirePackageManifest
	private let downloadsDirectoryURL: URL
	private var downloadedItemIds: Set<String> = []
	private var isSessionClosed = false

	private init(
		channel: any FramedByteChannel,
		manifest: WirePackageManifest,
		downloadsDirectoryURL: URL
	) {
		self.channel = channel
		self.manifest = manifest
		self.downloadsDirectoryURL = downloadsDirectoryURL
	}

	public static func open(
		channel: any FramedByteChannel,
		downloadsDirectoryURL: URL = defaultReceivedDownloadsDirectoryURL()
	) async throws -> (IncomingPackageSession, IncomingPackageOffer) {
		let firstFrame = try await channel.readFrame()
		guard firstFrame.frameType == .manifestOffer else {
			throw CoreBridgeError.invalidPayload("Expected manifest offer frame")
		}
		let manifest = try decodeWirePayload(WirePackageManifest.self, from: firstFrame)
		guard !manifest.items.isEmpty else {
			throw CoreBridgeError.invalidPayload("Incoming manifest has no items")
		}

		let pendingFrame = try encodeWireFrame(
			type: .manifestPending,
			payload: WireStatusPayload(status: 202)
		)
		try await channel.writeFrame(pendingFrame)

		let session = IncomingPackageSession(
			channel: channel,
			manifest: manifest,
			downloadsDirectoryURL: downloadsDirectoryURL
		)
		return (session, buildIncomingOffer(from: manifest))
	}

	public func downloadItems(
		itemIds: [String],
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws -> [DownloadedItemResult] {
		guard !isSessionClosed else {
			throw CoreBridgeError.transferCancelled
		}
		let pendingIds = itemIds.filter { !downloadedItemIds.contains($0) }
		guard !pendingIds.isEmpty else { return [] }

		let manifestItemsById = Dictionary(uniqueKeysWithValues: manifest.items.map { ($0.id, $0) })
		let requestedTotalBytes = pendingIds.reduce(Int64(0)) { accumulated, itemId in
			accumulated + (manifestItemsById[itemId]?.byteSize ?? 0)
		}

		let requestFrame = try encodeWireFrame(
			type: .requestItems,
			payload: WireItemRequestPayload(itemIds: pendingIds)
		)
		try await channel.writeFrame(requestFrame)

		let results = try await receiveRequestedItems(
			expectedIds: pendingIds,
			manifestItemsById: manifestItemsById,
			requestedTotalBytes: requestedTotalBytes,
			onProgress: onProgress
		)

		if downloadedItemIds.count == manifest.items.count {
			await finishSession()
		}
		onProgress(TransferProgressUpdate(phase: .completed))
		return results
	}

	public func finishSession() async {
		guard !isSessionClosed else { return }
		isSessionClosed = true
		if let completeFrame = try? WireFrame(frameType: .transferComplete) {
			try? await channel.writeFrame(completeFrame)
		}
		await channel.close()
	}

	public func rejectSession(reason: String) async {
		guard !isSessionClosed else { return }
		isSessionClosed = true
		if let rejectFrame = try? encodeWireFrame(
			type: .transferRejected,
			payload: WireReasonPayload(reason: reason)
		) {
			try? await channel.writeFrame(rejectFrame)
		}
		await channel.close()
	}

	private func receiveRequestedItems(
		expectedIds: [String],
		manifestItemsById: [String: WireManifestItem],
		requestedTotalBytes: Int64,
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws -> [DownloadedItemResult] {
		var results: [DownloadedItemResult] = []
		var cumulativeBytes: Int64 = 0

		for expectedId in expectedIds {
			guard let manifestItem = manifestItemsById[expectedId] else {
				throw CoreBridgeError.invalidPayload("Unknown item requested: \(expectedId)")
			}
			let (result, receivedItemBytes) = try await receiveSingleItem(
				manifestItem: manifestItem,
				initialCompletedBytes: cumulativeBytes,
				requestedTotalBytes: requestedTotalBytes,
				onProgress: onProgress
			)
			cumulativeBytes += receivedItemBytes
			downloadedItemIds.insert(manifestItem.id)
			results.append(result)
		}
		return results
	}

	private func receiveSingleItem(
		manifestItem: WireManifestItem,
		initialCompletedBytes: Int64,
		requestedTotalBytes: Int64,
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws -> (DownloadedItemResult, Int64) {
		let headerFrame = try await channel.readFrame()
		guard headerFrame.frameType == .itemHeader else {
			throw CoreBridgeError.transferFailed("Expected item header frame")
		}
		let itemHeader = try decodeWirePayload(WireItemHeaderPayload.self, from: headerFrame)
		guard itemHeader.itemId == manifestItem.id else {
			throw CoreBridgeError.transferFailed("Item header mismatch for \(manifestItem.name)")
		}

		let tempFileURL = createTempPartFileURL()
		FileManager.default.createFile(atPath: tempFileURL.path, contents: nil)
		let fileHandle = try FileHandle(forWritingTo: tempFileURL)
		var didMoveTempFile = false
		defer {
			try? fileHandle.close()
			if !didMoveTempFile {
				try? FileManager.default.removeItem(at: tempFileURL)
			}
		}

		let (receivedBytes, actualSha256) = try await writeIncomingItemChunks(
			into: fileHandle,
			expectedItemName: manifestItem.name,
			initialCompletedBytes: initialCompletedBytes,
			requestedTotalBytes: requestedTotalBytes,
			onProgress: onProgress
		)
		try fileHandle.close()

		try await validateReceivedItem(
			receivedBytes: receivedBytes,
			actualSha256: actualSha256,
			expectedHeader: itemHeader,
			itemName: manifestItem.name
		)

		let savedURL = try persistVerifiedTempFile(
			from: tempFileURL,
			preferredFilename: manifestItem.name
		)
		didMoveTempFile = true
		let textContent =
			manifestItem.isTextSnippet ? try? String(contentsOf: savedURL, encoding: .utf8) : nil
		let result = DownloadedItemResult(
			itemId: manifestItem.id,
			savedFileURL: savedURL,
			textContent: textContent
		)
		return (result, receivedBytes)
	}

	private func writeIncomingItemChunks(
		into fileHandle: FileHandle,
		expectedItemName: String,
		initialCompletedBytes: Int64,
		requestedTotalBytes: Int64,
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws -> (Int64, String) {
		var hasher = SHA256()
		var itemBytes: Int64 = 0

		while true {
			let nextFrame = try await channel.readFrame()
			switch nextFrame.frameType {
			case .itemChunk:
				try fileHandle.write(contentsOf: nextFrame.payloadBytes)
				hasher.update(data: nextFrame.payloadBytes)
				itemBytes += Int64(nextFrame.payloadBytes.count)
				onProgress(
					TransferProgressUpdate(
						phase: .transferring(
							completedBytes: initialCompletedBytes + itemBytes,
							totalBytes: max(requestedTotalBytes, initialCompletedBytes + itemBytes)
						)
					)
				)
			case .itemComplete:
				let digestHex = hasher.finalize().map { String(format: "%02x", $0) }.joined()
				return (itemBytes, digestHex)
			case .transferError:
				let errorPayload = try decodeWirePayload(WireErrorPayload.self, from: nextFrame)
				throw CoreBridgeError.transferFailed(errorPayload.message)
			default:
				throw CoreBridgeError.transferFailed("Unexpected frame while receiving \(expectedItemName)")
			}
		}
	}

	private func validateReceivedItem(
		receivedBytes: Int64,
		actualSha256: String,
		expectedHeader: WireItemHeaderPayload,
		itemName: String
	) async throws {
		let hashesMatch = actualSha256.caseInsensitiveCompare(expectedHeader.sha256Hex) == .orderedSame
		guard receivedBytes == expectedHeader.byteSize && hashesMatch else {
			if let errorFrame = try? encodeWireFrame(
				type: .transferError,
				payload: WireErrorPayload(message: "Checksum mismatch for \(itemName)")
			) {
				try? await channel.writeFrame(errorFrame)
			}
			throw CoreBridgeError.checksumMismatch(itemName)
		}
	}

	private func persistVerifiedTempFile(from tempFileURL: URL, preferredFilename: String) throws
		-> URL
	{
		let fileManager = FileManager.default
		try fileManager.createDirectory(at: downloadsDirectoryURL, withIntermediateDirectories: true)
		let destinationURL = uniqueDestinationFileURL(
			in: downloadsDirectoryURL,
			preferredFilename: preferredFilename
		)
		try fileManager.moveItem(at: tempFileURL, to: destinationURL)
		return destinationURL
	}
}
