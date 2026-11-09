import Foundation
import Combine

// -----------------------------------------------------------------------------
// 1. Primitive Bridge Models
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

public enum CoreBridgeError: Error, LocalizedError, Equatable {
    case initializationFailed(String)
    case peerNotFound(String)
    case transferRejected(String)
    case networkUnavailable

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
        }
    }
}

// -----------------------------------------------------------------------------
// 2. Core Bridge Protocol (DIP)
// -----------------------------------------------------------------------------

public protocol AirShipCoreBridgeProtocol: Sendable {
    func getLocalUserNameId() -> String
    func getLocalFingerprint() -> String
    func startBroadcasting() async throws
    func stopBroadcasting() async throws
    func listPeers() async throws -> [PeerBridgeModel]
    func setPeerTrust(peerIdentifier: String, isTrusted: Bool) async throws
    func addPeer(identifier: String, alias: String, fingerprintHex: String, isTrusted: Bool) async throws
    func removePeer(identifier: String) async throws -> Bool
}

// -----------------------------------------------------------------------------
// 3. Mock Protocol Stub for Testing & Previews (LSP)
// -----------------------------------------------------------------------------

public final class MockCoreBridge: AirShipCoreBridgeProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var peers: [PeerBridgeModel]
    private let localUserNameId: String
    private let localFingerprint: String

    public init(
        localUserNameId: String = "USER_SWIFT_DEVICE",
        localFingerprint: String = "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
        initialPeers: [PeerBridgeModel] = []
    ) {
        self.localUserNameId = localUserNameId
        self.localFingerprint = localFingerprint
        self.peers = initialPeers
    }

    public func getLocalUserNameId() -> String {
        return localUserNameId
    }

    public func getLocalFingerprint() -> String {
        return localFingerprint
    }

    public func startBroadcasting() async throws {}

    public func stopBroadcasting() async throws {}

    public func listPeers() async throws -> [PeerBridgeModel] {
        lock.lock()
        defer { lock.unlock() }
        return peers
    }

    public func setPeerTrust(peerIdentifier: String, isTrusted: Bool) async throws {
        lock.lock()
        defer { lock.unlock() }
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

    public func addPeer(identifier: String, alias: String, fingerprintHex: String, isTrusted: Bool) async throws {
        lock.lock()
        defer { lock.unlock() }
        peers.append(PeerBridgeModel(
            id: identifier,
            displayAlias: alias,
            fingerprintHex: fingerprintHex,
            isTrusted: isTrusted
        ))
    }

    public func removePeer(identifier: String) async throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let initialCount = peers.count
        peers.removeAll { $0.id == identifier }
        return peers.count < initialCount
    }
}
