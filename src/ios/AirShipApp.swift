import AirShipKit
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
			navigationTabView
				.tint(AirShipTheme.accentCyan)
				.preferredColorScheme(.dark)
		}
	}

	private var navigationTabView: some View {
		TabView(selection: $activeTab) {
			Tab(NavigationTab.transfer.rawValue, systemImage: NavigationTab.transfer.systemIconName, value: NavigationTab.transfer) {
				transferTabScreen
			}
			Tab(NavigationTab.trustList.rawValue, systemImage: NavigationTab.trustList.systemIconName, value: NavigationTab.trustList) {
				TrustListView(viewModel: trustListViewModel)
			}
			Tab(NavigationTab.settings.rawValue, systemImage: NavigationTab.settings.systemIconName, value: NavigationTab.settings) {
				SettingsView(viewModel: settingsViewModel)
			}
		}
	}

	@ViewBuilder
	private var transferTabScreen: some View {
		if homeViewModel.selectedMode == .send {
			SendView(viewModel: sendViewModel, selectedMode: $homeViewModel.selectedMode)
		} else {
			ReceiveView(viewModel: receiveViewModel, selectedMode: $homeViewModel.selectedMode)
		}
	}
}
