import SwiftUI

@main
public struct AirShipApp: App {
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var sendViewModel: SendViewModel
    @StateObject private var receiveViewModel: ReceiveViewModel
    @StateObject private var trustListViewModel: TrustListViewModel
    @StateObject private var settingsViewModel: SettingsViewModel

    @State private var activeTab: NavigationTab = .transfer

    public init() {
        let bridge = MockCoreBridge()
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(coreBridge: bridge))
        _sendViewModel = StateObject(wrappedValue: SendViewModel(coreBridge: bridge))
        _receiveViewModel = StateObject(wrappedValue: ReceiveViewModel(coreBridge: bridge))
        _trustListViewModel = StateObject(wrappedValue: TrustListViewModel(coreBridge: bridge))
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(coreBridge: bridge))
    }

    public var body: some Scene {
        WindowGroup {
            ZStack {
                switch activeTab {
                case .transfer:
                    if homeViewModel.selectedMode == .send {
                        SendView(viewModel: sendViewModel, activeTab: $activeTab)
                    } else {
                        ReceiveView(viewModel: receiveViewModel, activeTab: $activeTab)
                    }
                case .trustList:
                    TrustListView(viewModel: trustListViewModel, activeTab: $activeTab)
                case .settings:
                    SettingsView(viewModel: settingsViewModel, activeTab: $activeTab)
                }
            }
        }
    }
}
