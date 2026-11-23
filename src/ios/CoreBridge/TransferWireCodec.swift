import CryptoKit
import Foundation
import Network

// -----------------------------------------------------------------------------
// 1. Constants & Wire Frame Types
// -----------------------------------------------------------------------------

public enum TransferProtocolConstants {
	public static let bonjourServiceType = "_airship._tcp"
	public static let protocolVersion = "1"
	public static let headerByteLength = 5
	public static let maxFramePayloadBytes: UInt32 = 1_048_576
	public static let chunkByteSize = 65_536
	public static let receivedDirectoryName = "Received"

	public static let txtPeerIdKey = "id"
	public static let txtAliasKey = "alias"
	public static let txtFingerprintKey = "fp"
	public static let txtVersionKey = "ver"
}

public enum WireFrameType: UInt8, Equatable, Sendable {
	case manifestOffer = 0x01
	case manifestPending = 0x02
	case requestItems = 0x03
	case itemHeader = 0x04
	case itemChunk = 0x05
	case itemComplete = 0x06
	case transferComplete = 0x07
	case transferRejected = 0x08
	case transferError = 0x09
}

public struct WireFrame: Equatable, Sendable {
	public let frameType: WireFrameType
	public let payloadBytes: Data

	public init(frameType: WireFrameType, payloadBytes: Data = Data()) throws {
		guard payloadBytes.count <= Int(TransferProtocolConstants.maxFramePayloadBytes) else {
			throw CoreBridgeError.invalidPayload(
				"Frame payload exceeds \(TransferProtocolConstants.maxFramePayloadBytes) bytes"
			)
		}
		self.frameType = frameType
		self.payloadBytes = payloadBytes
	}

	public func encodeHeaderAndPayload() throws -> Data {
		let payloadCount = payloadBytes.count
		guard payloadCount <= Int(TransferProtocolConstants.maxFramePayloadBytes) else {
			throw CoreBridgeError.invalidPayload("Frame payload exceeds maximum size")
		}
		var packet = Data(capacity: TransferProtocolConstants.headerByteLength + payloadCount)
		packet.append(frameType.rawValue)
		var bigEndianLength = UInt32(payloadCount).bigEndian
		withUnsafeBytes(of: &bigEndianLength) { lengthBytes in
			packet.append(contentsOf: lengthBytes)
		}
		packet.append(payloadBytes)
		return packet
	}

	public static func decodeHeader(_ headerBytes: Data) throws -> (WireFrameType, UInt32) {
		guard headerBytes.count == TransferProtocolConstants.headerByteLength else {
			throw CoreBridgeError.invalidPayload("Expected 5-byte frame header")
		}
		let rawTypeByte = headerBytes[headerBytes.startIndex]
		guard let frameType = WireFrameType(rawValue: rawTypeByte) else {
			throw CoreBridgeError.invalidPayload("Unknown wire frame type: \(rawTypeByte)")
		}
		let lengthSlice = headerBytes.dropFirst()
		let payloadLength = lengthSlice.reduce(UInt32(0)) { accumulated, nextByte in
			(accumulated << 8) | UInt32(nextByte)
		}
		guard payloadLength <= TransferProtocolConstants.maxFramePayloadBytes else {
			throw CoreBridgeError.invalidPayload("Incoming frame size \(payloadLength) exceeds limit")
		}
		return (frameType, payloadLength)
	}
}

// -----------------------------------------------------------------------------
// 2. Wire JSON Payloads
// -----------------------------------------------------------------------------

public struct WireManifestItem: Codable, Equatable, Sendable {
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

public struct WirePackageManifest: Codable, Equatable, Sendable {
	public let packageId: String
	public let senderId: String
	public let senderAlias: String
	public let senderFingerprint: String
	public let items: [WireManifestItem]

	public init(
		packageId: String,
		senderId: String,
		senderAlias: String,
		senderFingerprint: String,
		items: [WireManifestItem]
	) {
		self.packageId = packageId
		self.senderId = senderId
		self.senderAlias = senderAlias
		self.senderFingerprint = senderFingerprint
		self.items = items
	}
}

public struct WireStatusPayload: Codable, Equatable, Sendable {
	public let status: Int

	public init(status: Int) {
		self.status = status
	}
}

public struct WireItemRequestPayload: Codable, Equatable, Sendable {
	public let itemIds: [String]

	public init(itemIds: [String]) {
		self.itemIds = itemIds
	}
}

public struct WireItemHeaderPayload: Codable, Equatable, Sendable {
	public let itemId: String
	public let byteSize: Int64
	public let sha256Hex: String

	public init(itemId: String, byteSize: Int64, sha256Hex: String) {
		self.itemId = itemId
		self.byteSize = byteSize
		self.sha256Hex = sha256Hex
	}
}

public struct WireItemCompletePayload: Codable, Equatable, Sendable {
	public let itemId: String

	public init(itemId: String) {
		self.itemId = itemId
	}
}

public struct WireReasonPayload: Codable, Equatable, Sendable {
	public let reason: String

	public init(reason: String) {
		self.reason = reason
	}
}

public struct WireErrorPayload: Codable, Equatable, Sendable {
	public let message: String

	public init(message: String) {
		self.message = message
	}
}

// -----------------------------------------------------------------------------
// 3. Pure Helper Functions
// -----------------------------------------------------------------------------

public func computeBytesSha256Hex(_ rawBytes: Data) -> String {
	let digest = SHA256.hash(data: rawBytes)
	return digest.map { String(format: "%02x", $0) }.joined()
}

public func computeFileSha256Hex(at fileURL: URL) throws -> String {
	let fileHandle = try FileHandle(forReadingFrom: fileURL)
	defer { try? fileHandle.close() }

	var hasher = SHA256()
	while true {
		let chunk = try fileHandle.read(upToCount: TransferProtocolConstants.chunkByteSize)
		guard let chunk, !chunk.isEmpty else { break }
		hasher.update(data: chunk)
	}
	let digest = hasher.finalize()
	return digest.map { String(format: "%02x", $0) }.joined()
}

public func sanitizedDownloadFilename(_ candidateName: String) -> String {
	let lastComponent = (candidateName as NSString).lastPathComponent
	let cleaned =
		lastComponent
		.replacingOccurrences(of: "/", with: "_")
		.replacingOccurrences(of: "\0", with: "")
		.trimmingCharacters(in: .whitespacesAndNewlines)

	if cleaned.isEmpty || cleaned == "." || cleaned == ".." {
		return "AirShip_Item_\(UUID().uuidString.prefix(8))"
	}
	return cleaned
}

public func uniqueDestinationFileURL(in directoryURL: URL, preferredFilename: String) -> URL {
	let safeName = sanitizedDownloadFilename(preferredFilename)
	let fileManager = FileManager.default
	let initialURL = directoryURL.appendingPathComponent(safeName)
	guard fileManager.fileExists(atPath: initialURL.path) else {
		return initialURL
	}

	let nsName = safeName as NSString
	let stem = nsName.deletingPathExtension
	let ext = nsName.pathExtension
	var attempt = 1
	while true {
		let suffixedName = ext.isEmpty ? "\(stem) (\(attempt))" : "\(stem) (\(attempt)).\(ext)"
		let candidateURL = directoryURL.appendingPathComponent(suffixedName)
		if !fileManager.fileExists(atPath: candidateURL.path) {
			return candidateURL
		}
		attempt += 1
	}
}

public func makeAirShipTcpParameters() -> NWParameters {
	let tcpOptions = NWProtocolTCP.Options()
	tcpOptions.enableKeepalive = true
	tcpOptions.noDelay = true
	let parameters = NWParameters(tls: nil, tcp: tcpOptions)
	parameters.includePeerToPeer = true
	return parameters
}

public func encodeWireFrame<Payload: Encodable>(
	type frameType: WireFrameType,
	payload: Payload
) throws -> WireFrame {
	let encodedBytes = try JSONEncoder().encode(payload)
	return try WireFrame(frameType: frameType, payloadBytes: encodedBytes)
}

public func decodeWirePayload<Payload: Decodable>(
	_ payloadType: Payload.Type,
	from frame: WireFrame
) throws -> Payload {
	return try JSONDecoder().decode(payloadType, from: frame.payloadBytes)
}

public func defaultReceivedDownloadsDirectoryURL() -> URL {
	let fileManager = FileManager.default
	let baseDirectory =
		fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
		?? fileManager.temporaryDirectory
	return baseDirectory.appendingPathComponent(
		TransferProtocolConstants.receivedDirectoryName,
		isDirectory: true
	)
}
