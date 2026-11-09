import Foundation
import Combine

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var userNameId: String
    @Published public private(set) var fingerprint: String
    @Published public var selectedMode: ModeSwitchOption

    private let coreBridge: AirShipCoreBridgeProtocol

    public init(coreBridge: AirShipCoreBridgeProtocol, initialMode: ModeSwitchOption = .send) {
        self.coreBridge = coreBridge
        self.userNameId = coreBridge.getLocalUserNameId()
        self.fingerprint = coreBridge.getLocalFingerprint()
        self.selectedMode = initialMode
    }

    public func refreshIdentity() {
        userNameId = coreBridge.getLocalUserNameId()
        fingerprint = coreBridge.getLocalFingerprint()
    }
}
