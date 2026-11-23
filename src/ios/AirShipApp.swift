import AirShipKit
import SwiftUI

@main
public struct AirShipApp: App {
	@Environment(\.scenePhase) private var scenePhase

	private let coreBridge: AirShipCoreBridgeProtocol
	@StateObject private var homeViewModel: HomeViewModel
	@StateObject private var sendViewModel: SendViewModel
	@StateObject private var receiveViewModel: ReceiveViewModel
	@StateObject private var trustListViewModel: TrustListViewModel
	@StateObject private var settingsViewModel: SettingsViewModel

	@State private var activeTab: NavigationTab = .transfer

	public init() {
		let bridge = LiveAirShipCoreBridge()
		self.coreBridge = bridge

		let homeModel = HomeViewModel(coreBridge: bridge)
		let sendModel = SendViewModel(coreBridge: bridge)
		let receiveModel = ReceiveViewModel(coreBridge: bridge)
		let trustModel = TrustListViewModel(coreBridge: bridge)
		let settingsModel = SettingsViewModel(coreBridge: bridge) {
			homeModel.refreshIdentity()
			receiveModel.refreshIdentity()
		}

		_homeViewModel = StateObject(wrappedValue: homeModel)
		_sendViewModel = StateObject(wrappedValue: sendModel)
		_receiveViewModel = StateObject(wrappedValue: receiveModel)
		_trustListViewModel = StateObject(wrappedValue: trustModel)
		_settingsViewModel = StateObject(wrappedValue: settingsModel)
	}

	public var body: some Scene {
		WindowGroup {
			navigationTabView
				.tint(AirShipTheme.accentCyan)
				.preferredColorScheme(.dark)
				.task {
					await startNetworkingAndListener()
				}
				.onChange(of: scenePhase) { _, updatedPhase in
					handleScenePhaseChange(updatedPhase)
				}
				.onChange(of: receiveViewModel.screenState) { _, updatedState in
					if case .packageReceived = updatedState {
						activeTab = .transfer
						homeViewModel.selectedMode = .receive
					}
				}
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

	private func startNetworkingAndListener() async {
		try? await coreBridge.startBroadcasting()
		settingsViewModel.refreshNetworkStatus()
		await receiveViewModel.startListeningForIncomingPackages()
	}

	private func handleScenePhaseChange(_ phase: ScenePhase) {
		guard phase == .active else { return }
		Task {
			try? await coreBridge.startBroadcasting()
			settingsViewModel.refreshNetworkStatus()
		}
	}
}
