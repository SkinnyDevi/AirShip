import SwiftUI

public struct SettingsView: View {
    @ObservedObject public var viewModel: SettingsViewModel
    @Binding public var activeTab: NavigationTab

    public init(viewModel: SettingsViewModel, activeTab: Binding<NavigationTab>) {
        self.viewModel = viewModel
        self._activeTab = activeTab
    }

    public var body: some View {
        ZStack {
            AirShipTheme.primaryDarkBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Settings")
                    .font(.title2.bold())
                    .foregroundStyle(AirShipTheme.textPrimary)

                Form {
                    Section(header: Text("Device Configuration").foregroundStyle(AirShipTheme.accentCyan)) {
                        HStack {
                            Text("Device Alias")
                            Spacer()
                            TextField("Alias", text: $viewModel.deviceAlias)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .listRowBackground(AirShipTheme.secondaryCardBackground)

                    Section(header: Text("Storage & Permissions").foregroundStyle(AirShipTheme.accentCyan)) {
                        HStack {
                            Text("Save Location")
                            Spacer()
                            Text(viewModel.downloadDestinationPath)
                                .foregroundStyle(AirShipTheme.textSecondary)
                        }
                    }
                    .listRowBackground(AirShipTheme.secondaryCardBackground)

                    Section(header: Text("Network & Security").foregroundStyle(AirShipTheme.accentCyan)) {
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
                .scrollContentBackground(.hidden)

                Spacer()

                FloatingBottomBar(activeTab: $activeTab)
                    .padding(.bottom, 16)
            }
            .padding(.top)
        }
    }
}
