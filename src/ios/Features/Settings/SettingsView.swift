import SwiftUI

public struct SettingsView: View {
	@ObservedObject public var viewModel: SettingsViewModel

	public init(viewModel: SettingsViewModel) {
		self.viewModel = viewModel
	}

	public var body: some View {
		ZStack {
			AirShipTheme.primaryDarkBackground.ignoresSafeArea()

			VStack(spacing: 20) {
				Text("Settings")
					.font(.title2.bold())
					.foregroundStyle(AirShipTheme.textPrimary)

				settingsForm

				Spacer()
			}
			.padding(.top)
		}
		.onAppear {
			viewModel.refreshNetworkStatus()
		}
	}

	private var settingsForm: some View {
		Form {
			deviceConfigurationSection
			storageSection
			networkSecuritySection
		}
		.scrollContentBackground(.hidden)
	}

	private var deviceConfigurationSection: some View {
		Section(
			header: Text("Device Configuration").foregroundStyle(AirShipTheme.accentCyan)
		) {
			HStack {
				Text("Device Alias")
				Spacer()
				TextField("Alias", text: $viewModel.deviceAlias)
					.multilineTextAlignment(.trailing)
					.onSubmit {
						viewModel.saveAlias()
					}
			}

			Button {
				viewModel.saveAlias()
			} label: {
				Text("Save Alias")
					.foregroundStyle(AirShipTheme.accentCyan)
			}

			if let statusBanner = viewModel.statusBannerMessage {
				Text(statusBanner)
					.font(.caption)
					.foregroundStyle(AirShipTheme.textSecondary)
			}
		}
		.listRowBackground(AirShipTheme.secondaryCardBackground)
	}

	private var storageSection: some View {
		Section(
			header: Text("Storage & Permissions").foregroundStyle(AirShipTheme.accentCyan)
		) {
			HStack {
				Text("Save Location")
				Spacer()
				Text(viewModel.downloadDestinationPath)
					.foregroundStyle(AirShipTheme.textSecondary)
			}
		}
		.listRowBackground(AirShipTheme.secondaryCardBackground)
	}

	private var networkSecuritySection: some View {
		Section(
			header: Text("Network & Security").foregroundStyle(AirShipTheme.accentCyan)
		) {
			HStack {
				Text("Interface Status")
				Spacer()
				Text(viewModel.networkStatusDescription)
					.foregroundStyle(Color.green)
			}

			VStack(alignment: .leading, spacing: 4) {
				Text("Certificate Fingerprint")
					.font(.caption)
					.foregroundStyle(AirShipTheme.textSecondary)
				Text(viewModel.certificateFingerprint)
					.font(.system(size: 11, design: .monospaced))
					.foregroundStyle(AirShipTheme.textPrimary)
			}

			Button(role: .destructive) {
				viewModel.resetCertificateIdentity()
			} label: {
				Text("Reset Identity Certificate")
			}
		}
		.listRowBackground(AirShipTheme.secondaryCardBackground)
	}
}
