import Foundation
import Combine

@MainActor
public final class TrustListViewModel: ObservableObject {
    @Published public private(set) var peers: [PeerBridgeModel] = []
    @Published public var searchQuery: String = ""
    @Published public var isAddDrawerExpanded: Bool = false
    @Published public var newUserIdInput: String = ""
    @Published public var newUserAliasInput: String = ""
    @Published public var errorMessage: String?

    private let coreBridge: AirShipCoreBridgeProtocol

    public init(coreBridge: AirShipCoreBridgeProtocol) {
        self.coreBridge = coreBridge
    }

    public var filteredPeers: [PeerBridgeModel] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return peers
        }
        return peers.filter { peer in
            peer.displayAlias.localizedCaseInsensitiveContains(searchQuery) ||
            peer.id.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    public func loadPeers() async {
        do {
            peers = try await coreBridge.listPeers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func toggleTrust(for peer: PeerBridgeModel) async {
        let newTrustStatus = !peer.isTrusted
        do {
            try await coreBridge.setPeerTrust(peerIdentifier: peer.id, isTrusted: newTrustStatus)
            await loadPeers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func removePeer(peer: PeerBridgeModel) async {
        do {
            _ = try await coreBridge.removePeer(identifier: peer.id)
            await loadPeers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func submitNewUser() async {
        let trimmedId = newUserIdInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAlias = newUserAliasInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else { return }

        let alias = trimmedAlias.isEmpty ? trimmedId : trimmedAlias
        let dummyFingerprint = String(repeating: "0", count: 64)

        do {
            try await coreBridge.addPeer(
                identifier: trimmedId,
                alias: alias,
                fingerprintHex: dummyFingerprint,
                isTrusted: false
            )
            newUserIdInput = ""
            newUserAliasInput = ""
            isAddDrawerExpanded = false
            await loadPeers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
