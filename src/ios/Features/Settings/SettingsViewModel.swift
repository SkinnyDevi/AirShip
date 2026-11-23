import Combine
import Foundation

@MainActor
public final class SettingsViewModel: ObservableObject {
	@Published public var deviceAlias: String
	@Published public var downloadDestinationPath: String
	@Published public private(set) var networkStatusDescription: String
	@Published public private(set) var certificateFingerprint: String
	@Published public private(set) var statusBannerMessage: String?

	private let coreBridge: AirShipCoreBridgeProtocol
	private let onIdentityChanged: @MainActor () -> Void

	public init(
		coreBridge: AirShipCoreBridgeProtocol,
		onIdentityChanged: @escaping @MainActor () -> Void = {}
	) {
		self.coreBridge = coreBridge
		self.onIdentityChanged = onIdentityChanged
		self.deviceAlias = coreBridge.getLocalDisplayAlias()
		self.downloadDestinationPath = "Files / AirShip / Received"
		self.networkStatusDescription = coreBridge.getNetworkStatusDescription()
		self.certificateFingerprint = coreBridge.getLocalFingerprint()
	}

	public func refreshNetworkStatus() {
		networkStatusDescription = coreBridge.getNetworkStatusDescription()
	}

	public func resetCertificateIdentity() {
		Task {
			await performResetCertificateIdentity()
		}
	}

	public func performResetCertificateIdentity() async {
		do {
			try await coreBridge.resetLocalIdentity()
			certificateFingerprint = coreBridge.getLocalFingerprint()
			deviceAlias = coreBridge.getLocalDisplayAlias()
			statusBannerMessage = "Identity regenerated"
			onIdentityChanged()
		} catch {
			statusBannerMessage = error.localizedDescription
		}
	}

	public func saveAlias() {
		Task {
			await performSaveAlias()
		}
	}

	public func performSaveAlias() async {
		let trimmed = deviceAlias.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		do {
			try await coreBridge.updateLocalAlias(trimmed)
			deviceAlias = coreBridge.getLocalDisplayAlias()
			statusBannerMessage = "Alias updated"
			onIdentityChanged()
		} catch {
			statusBannerMessage = error.localizedDescription
		}
	}
}
