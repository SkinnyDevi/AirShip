import SwiftUI

public struct ReceiveView: View {
    @ObservedObject public var viewModel: ReceiveViewModel
    @Binding public var activeTab: NavigationTab

    public init(viewModel: ReceiveViewModel, activeTab: Binding<NavigationTab>) {
        self.viewModel = viewModel
        self._activeTab = activeTab
    }

    public var body: some View {
        ZStack {
            AirShipTheme.primaryDarkBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                SegmentedToggleView(selectedOption: $viewModel.selectedMode)
                    .padding(.horizontal)

                contentForCurrentState

                Spacer()

                FloatingBottomBar(activeTab: $activeTab)
                    .padding(.bottom, 16)
            }
            .padding(.top)
        }
    }

    @ViewBuilder
    private var contentForCurrentState: some View {
        switch viewModel.screenState {
        case .waiting:
            waitingView
        case .packageReceived(let items):
            packageReceivedView(items: items)
        case .downloading:
            ProgressView("Downloading package...")
                .foregroundStyle(AirShipTheme.accentCyan)
        case .completed:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.green)
                Text("All Items Saved!")
                    .font(.title2.bold())
                    .foregroundStyle(AirShipTheme.textPrimary)
            }
        }
    }

    private var waitingView: some View {
        VStack(spacing: 24) {
            Spacer()
            BlimpLogoView(size: 130)
            Text("Waiting for your package...")
                .font(.title3.weight(.medium))
                .foregroundStyle(AirShipTheme.textPrimary)
            ProgressView()
                .tint(AirShipTheme.accentCyan)
            Spacer()
        }
    }

    private func packageReceivedView(items: [ReceivedPackageItem]) -> some View {
        VStack(spacing: 16) {
            Text("Package Received!")
                .font(.title2.bold())
                .foregroundStyle(AirShipTheme.textPrimary)

            List(items) { item in
                HStack {
                    Image(systemName: item.isTextSnippet ? "doc.text" : "doc")
                        .foregroundStyle(AirShipTheme.accentCyan)

                    VStack(alignment: .leading) {
                        Text(item.name)
                            .foregroundStyle(AirShipTheme.textPrimary)
                        Text("\(item.byteSize / 1024) KB")
                            .font(.caption)
                            .foregroundStyle(AirShipTheme.textSecondary)
                    }

                    Spacer()

                    Button {
                        viewModel.downloadSingleItem(id: item.id)
                    } label: {
                        Image(systemName: item.isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(item.isDownloaded ? Color.green : AirShipTheme.accentCyan)
                    }
                }
                .listRowBackground(AirShipTheme.secondaryCardBackground)
            }
            .listStyle(.plain)
            .frame(maxHeight: 280)
            .clipShape(RoundedRectangle(cornerRadius: AirShipTheme.cardCornerRadius))
            .padding(.horizontal)

            Button {
                viewModel.downloadAllItems()
            } label: {
                Text("Download All")
                    .font(.headline)
                    .foregroundStyle(AirShipTheme.primaryDarkBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AirShipTheme.accentCyan)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
        }
    }
}
