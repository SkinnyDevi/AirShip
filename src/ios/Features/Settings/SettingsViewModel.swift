import Foundation
import Combine

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var deviceAlias: String
    @Published public var downloadDestinationPath: String
    @Published public private(set) var networkStatusDescription: String
    @Published public private(set) var certificateFingerprint: String

    private let coreBridge: AirShipCoreBridgeProtocol

    public init(coreBridge: AirShipCoreBridgeProtocol) {
        self.coreBridge = coreBridge
        self.deviceAlias = coreBridge.getLocalUserNameId()
        self.downloadDestinationPath = "Downloads/AirShip"
        self.networkStatusDescription = "Wi-Fi LAN Active"
        self.certificateFingerprint = coreBridge.getLocalFingerprint()
    }

    public func resetCertificateIdentity() {
        // Triggers regeneration of identity keys
        certificateFingerprint = coreBridge.getLocalFingerprint()
    }

    public func saveAlias() {
        // Persists updated alias
    }
}
