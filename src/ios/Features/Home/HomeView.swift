import SwiftUI

public struct HomeView: View {
    @ObservedObject public var viewModel: HomeViewModel
    @Binding public var activeTab: NavigationTab

    public init(viewModel: HomeViewModel, activeTab: Binding<NavigationTab>) {
        self.viewModel = viewModel
        self._activeTab = activeTab
    }

    public var body: some View {
        ZStack {
            AirShipTheme.primaryDarkBackground.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                BlimpLogoView(size: 140)

                VStack(spacing: 8) {
                    Text("Your Identity")
                        .font(.subheadline)
                        .foregroundStyle(AirShipTheme.textSecondary)

                    Text(viewModel.userNameId)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(AirShipTheme.textPrimary)
                }

                SegmentedToggleView(selectedOption: $viewModel.selectedMode)
                    .padding(.horizontal, 48)

                Spacer()

                FloatingBottomBar(activeTab: $activeTab)
                    .padding(.bottom, 16)
            }
            .padding()
        }
    }
}
