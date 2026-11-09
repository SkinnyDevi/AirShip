import Foundation
import Combine

public struct ReceivedPackageItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let byteSize: Int64
    public let isTextSnippet: Bool
    public let textContent: String?
    public var isDownloaded: Bool

    public init(
        id: String,
        name: String,
        byteSize: Int64,
        isTextSnippet: Bool = false,
        textContent: String? = nil,
        isDownloaded: Bool = false
    ) {
        self.id = id
        self.name = name
        self.byteSize = byteSize
        self.isTextSnippet = isTextSnippet
        self.textContent = textContent
        self.isDownloaded = isDownloaded
    }
}

public enum ReceiveScreenState: Equatable {
    case waiting
    case packageReceived(items: [ReceivedPackageItem])
    case downloading
    case completed
}

@MainActor
public final class ReceiveViewModel: ObservableObject {
    @Published public private(set) var screenState: ReceiveScreenState = .waiting
    @Published public var selectedMode: ModeSwitchOption = .receive

    private let coreBridge: AirShipCoreBridgeProtocol

    public init(coreBridge: AirShipCoreBridgeProtocol) {
        self.coreBridge = coreBridge
    }

    public func simulateIncomingPackage(items: [ReceivedPackageItem]) {
        screenState = .packageReceived(items: items)
    }

    public func downloadSingleItem(id: String) {
        guard case .packageReceived(var currentItems) = screenState else { return }
        if let targetIndex = currentItems.firstIndex(where: { $0.id == id }) {
            currentItems[targetIndex].isDownloaded = true
            screenState = .packageReceived(items: currentItems)
        }
    }

    public func downloadAllItems() {
        guard case .packageReceived(var currentItems) = screenState else { return }
        for index in currentItems.indices {
            currentItems[index].isDownloaded = true
        }
        screenState = .completed
    }

    public func resetToWaiting() {
        screenState = .waiting
    }
}
