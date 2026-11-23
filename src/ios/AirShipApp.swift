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
			Tab(value: NavigationTab.transfer) {
				transferTabScreen
			} label: {
				tabLabel(for: .transfer)
			}
			Tab(value: NavigationTab.trustList) {
				TrustListView(viewModel: trustListViewModel)
			} label: {
				tabLabel(for: .trustList)
			}
			Tab(value: NavigationTab.settings) {
				SettingsView(viewModel: settingsViewModel)
			} label: {
				tabLabel(for: .settings)
			}
		}
	}

	private func tabLabel(for tab: NavigationTab) -> some View {
		Label {
			Text(tab.rawValue)
		} icon: {
			tab.iconImage
		}
	}

	@ViewBuilder
	private var transferTabScreen: some View {
		NavigationStack {
			ZStack {
				AirShipTheme.primaryDarkBackground.ignoresSafeArea()

				VStack(spacing: 20) {
					SegmentedToggleView(selectedOption: $homeViewModel.selectedMode)
						.padding(.horizontal)

					if homeViewModel.selectedMode == .send {
						SendView(
							viewModel: sendViewModel,
							selectedMode: $homeViewModel.selectedMode,
							showsModeSwitcher: false
						)
					} else {
						ReceiveView(
							viewModel: receiveViewModel,
							selectedMode: $homeViewModel.selectedMode,
							showsModeSwitcher: false
						)
					}
				}
				.padding(.top)
			}
			#if os(iOS)
			.toolbar(.hidden, for: .navigationBar)
			#endif
		}
	}
}
