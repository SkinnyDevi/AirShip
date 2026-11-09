import Foundation
import Combine

public struct StagedItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let byteSize: Int64
    public let mimeType: String
    public let systemIconName: String

    public init(id: String, name: String, byteSize: Int64, mimeType: String, systemIconName: String) {
        self.id = id
        self.name = name
        self.byteSize = byteSize
        self.mimeType = mimeType
        self.systemIconName = systemIconName
    }
}

public enum SendTransferState: Equatable {
    case empty
    case staged
    case sending
    case completed
    case failed(String)
}

@MainActor
public final class SendViewModel: ObservableObject {
    @Published public private(set) var stagedItems: [StagedItem] = []
    @Published public private(set) var transferState: SendTransferState = .empty
    @Published public var selectedMode: ModeSwitchOption = .send

    private let coreBridge: AirShipCoreBridgeProtocol

    public init(coreBridge: AirShipCoreBridgeProtocol) {
        self.coreBridge = coreBridge
    }

    public func addPhotoAttachment(name: String, size: Int64) {
        let item = StagedItem(
            id: UUID().uuidString,
            name: name,
            byteSize: size,
            mimeType: "image/jpeg",
            systemIconName: "photo"
        )
        stagedItems.append(item)
        transferState = .staged
    }

    public func addCameraAttachment(name: String, size: Int64) {
        let item = StagedItem(
            id: UUID().uuidString,
            name: name,
            byteSize: size,
            mimeType: "image/jpeg",
            systemIconName: "camera"
        )
        stagedItems.append(item)
        transferState = .staged
    }

    public func addFileAttachment(name: String, size: Int64, mimeType: String) {
        let item = StagedItem(
            id: UUID().uuidString,
            name: name,
            byteSize: size,
            mimeType: mimeType,
            systemIconName: "doc"
        )
        stagedItems.append(item)
        transferState = .staged
    }

    public func addTextAttachment(textSnippet: String) {
        let byteCount = Int64(textSnippet.utf8.count)
        let item = StagedItem(
            id: UUID().uuidString,
            name: "Pasted Text",
            byteSize: byteCount,
            mimeType: "text/plain",
            systemIconName: "doc.text"
        )
        stagedItems.append(item)
        transferState = .staged
    }

    public func removeItem(id: String) {
        stagedItems.removeAll { $0.id == id }
        if stagedItems.isEmpty {
            transferState = .empty
        }
    }

    public func dispatchPackage(to peerId: String) async {
        guard !stagedItems.isEmpty else { return }
        transferState = .sending
        // Simulate transfer execution via bridge
        transferState = .completed
    }
}
