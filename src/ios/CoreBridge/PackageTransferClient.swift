import Foundation

// -----------------------------------------------------------------------------
// 1. Outgoing Transfer Protocol & Manifest Builder
// -----------------------------------------------------------------------------

public protocol PackageTransferSending: Sendable {
	func sendPackage(
		channel: any FramedByteChannel,
		senderIdentity: LocalDeviceIdentity,
		items: [OutgoingTransferItem],
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws
}

private func buildWireManifestItem(from item: OutgoingTransferItem) throws -> (WireManifestItem, Int64) {
	switch item.payloadSource {
	case .fileURL(let fileURL):
		let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
		let measuredSize = (attributes[.size] as? NSNumber)?.int64Value ?? item.byteSize
		let sha256Hex = try computeFileSha256Hex(at: fileURL)
		let wireItem = WireManifestItem(
			id: item.id,
			name: item.name,
			byteSize: measuredSize,
			mimeType: item.mimeType,
			isTextSnippet: item.isTextSnippet,
			sha256Hex: sha256Hex
		)
		return (wireItem, measuredSize)
	case .textContent(let textPayload):
		let utf8Bytes = Data(textPayload.utf8)
		let sha256Hex = computeBytesSha256Hex(utf8Bytes)
		let wireItem = WireManifestItem(
			id: item.id,
			name: item.name,
			byteSize: Int64(utf8Bytes.count),
			mimeType: item.mimeType,
			isTextSnippet: true,
			sha256Hex: sha256Hex
		)
		return (wireItem, Int64(utf8Bytes.count))
	}
}

private func buildWireManifest(
	senderIdentity: LocalDeviceIdentity,
	items: [OutgoingTransferItem]
) throws -> (WirePackageManifest, [String: WireManifestItem], Int64) {
	guard !items.isEmpty else {
		throw CoreBridgeError.invalidPayload("Cannot send an empty package")
	}

	var wireItems: [WireManifestItem] = []
	var wireItemsById: [String: WireManifestItem] = [:]
	var totalBytes: Int64 = 0

	for item in items {
		let (wireItem, itemBytes) = try buildWireManifestItem(from: item)
		wireItems.append(wireItem)
		wireItemsById[wireItem.id] = wireItem
		totalBytes += itemBytes
	}

	let manifest = WirePackageManifest(
		packageId: UUID().uuidString,
		senderId: senderIdentity.userNameId,
		senderAlias: senderIdentity.displayAlias,
		senderFingerprint: senderIdentity.fingerprintHex,
		items: wireItems
	)
	return (manifest, wireItemsById, totalBytes)
}

// -----------------------------------------------------------------------------
// 2. Package Transfer Client Actor
// -----------------------------------------------------------------------------

public actor PackageTransferClient: PackageTransferSending {
	public init() {}

	public func sendPackage(
		channel: any FramedByteChannel,
		senderIdentity: LocalDeviceIdentity,
		items: [OutgoingTransferItem],
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws {
		let (manifest, wireItemsById, totalBytes) = try buildWireManifest(
			senderIdentity: senderIdentity,
			items: items
		)
		let itemsById = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

		let offerFrame = try encodeWireFrame(type: .manifestOffer, payload: manifest)
		try await channel.writeFrame(offerFrame)
		onProgress(TransferProgressUpdate(phase: .awaitingApproval))

		try await driveResponseLoop(
			channel: channel,
			itemsById: itemsById,
			wireItemsById: wireItemsById,
			totalBytes: totalBytes,
			onProgress: onProgress
		)
	}

	private func driveResponseLoop(
		channel: any FramedByteChannel,
		itemsById: [String: OutgoingTransferItem],
		wireItemsById: [String: WireManifestItem],
		totalBytes: Int64,
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws {
		var sentBytes: Int64 = 0
		while true {
			let incomingFrame = try await channel.readFrame()
			switch incomingFrame.frameType {
			case .manifestPending:
				onProgress(TransferProgressUpdate(phase: .awaitingApproval))
			case .requestItems:
				let request = try decodeWirePayload(WireItemRequestPayload.self, from: incomingFrame)
				sentBytes = try await streamRequestedItems(
					channel: channel,
					requestedIds: request.itemIds,
					itemsById: itemsById,
					wireItemsById: wireItemsById,
					initialSentBytes: sentBytes,
					totalBytes: totalBytes,
					onProgress: onProgress
				)
			case .transferComplete:
				onProgress(TransferProgressUpdate(phase: .completed))
				return
			case .transferRejected:
				let rejection = try decodeWirePayload(WireReasonPayload.self, from: incomingFrame)
				throw CoreBridgeError.transferRejected(rejection.reason)
			case .transferError:
				let errorPayload = try decodeWirePayload(WireErrorPayload.self, from: incomingFrame)
				throw CoreBridgeError.transferFailed(errorPayload.message)
			default:
				throw CoreBridgeError.transferFailed("Unexpected response frame from recipient")
			}
		}
	}

	private func streamRequestedItems(
		channel: any FramedByteChannel,
		requestedIds: [String],
		itemsById: [String: OutgoingTransferItem],
		wireItemsById: [String: WireManifestItem],
		initialSentBytes: Int64,
		totalBytes: Int64,
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws -> Int64 {
		var cumulativeSent = initialSentBytes
		for itemId in requestedIds {
			guard let outgoingItem = itemsById[itemId],
				let wireItem = wireItemsById[itemId]
			else {
				throw CoreBridgeError.transferFailed("Recipient requested unknown item: \(itemId)")
			}
			cumulativeSent = try await streamSingleItem(
				channel: channel,
				item: outgoingItem,
				wireItem: wireItem,
				initialSentBytes: cumulativeSent,
				totalBytes: totalBytes,
				onProgress: onProgress
			)
		}
		return cumulativeSent
	}

	private func streamSingleItem(
		channel: any FramedByteChannel,
		item: OutgoingTransferItem,
		wireItem: WireManifestItem,
		initialSentBytes: Int64,
		totalBytes: Int64,
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws -> Int64 {
		let headerPayload = WireItemHeaderPayload(
			itemId: wireItem.id,
			byteSize: wireItem.byteSize,
			sha256Hex: wireItem.sha256Hex
		)
		try await channel.writeFrame(encodeWireFrame(type: .itemHeader, payload: headerPayload))

		let updatedSentBytes: Int64
		switch item.payloadSource {
		case .fileURL(let fileURL):
			updatedSentBytes = try await streamFileChunks(
				channel: channel,
				fileURL: fileURL,
				initialSentBytes: initialSentBytes,
				totalBytes: totalBytes,
				onProgress: onProgress
			)
		case .textContent(let textPayload):
			updatedSentBytes = try await streamMemoryChunks(
				channel: channel,
				rawBytes: Data(textPayload.utf8),
				initialSentBytes: initialSentBytes,
				totalBytes: totalBytes,
				onProgress: onProgress
			)
		}

		let donePayload = WireItemCompletePayload(itemId: wireItem.id)
		try await channel.writeFrame(encodeWireFrame(type: .itemComplete, payload: donePayload))
		return updatedSentBytes
	}

	private func streamFileChunks(
		channel: any FramedByteChannel,
		fileURL: URL,
		initialSentBytes: Int64,
		totalBytes: Int64,
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws -> Int64 {
		let fileHandle = try FileHandle(forReadingFrom: fileURL)
		defer { try? fileHandle.close() }

		var cumulativeSent = initialSentBytes
		while true {
			let chunk = try fileHandle.read(upToCount: TransferProtocolConstants.chunkByteSize)
			guard let chunk, !chunk.isEmpty else { break }
			try await channel.writeFrame(WireFrame(frameType: .itemChunk, payloadBytes: chunk))
			cumulativeSent += Int64(chunk.count)
			onProgress(
				TransferProgressUpdate(
					phase: .transferring(completedBytes: cumulativeSent, totalBytes: totalBytes)
				)
			)
		}
		return cumulativeSent
	}

	private func streamMemoryChunks(
		channel: any FramedByteChannel,
		rawBytes: Data,
		initialSentBytes: Int64,
		totalBytes: Int64,
		onProgress: @escaping @Sendable (TransferProgressUpdate) -> Void
	) async throws -> Int64 {
		var cumulativeSent = initialSentBytes
		var offset = 0
		while offset < rawBytes.count {
			let endOffset = min(offset + TransferProtocolConstants.chunkByteSize, rawBytes.count)
			let chunk = rawBytes.subdata(in: offset..<endOffset)
			try await channel.writeFrame(WireFrame(frameType: .itemChunk, payloadBytes: chunk))
			cumulativeSent += Int64(chunk.count)
			offset = endOffset
			onProgress(
				TransferProgressUpdate(
					phase: .transferring(completedBytes: cumulativeSent, totalBytes: totalBytes)
				)
			)
		}
		return cumulativeSent
	}
}
