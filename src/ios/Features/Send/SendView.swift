import SwiftUI

public struct SendView: View {
    @ObservedObject public var viewModel: SendViewModel
    @Binding public var activeTab: NavigationTab

    public init(viewModel: SendViewModel, activeTab: Binding<NavigationTab>) {
        self.viewModel = viewModel
        self._activeTab = activeTab
    }

    public var body: some View {
        ZStack {
            AirShipTheme.primaryDarkBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                SegmentedToggleView(selectedOption: $viewModel.selectedMode)
                    .padding(.horizontal)

                Text("Create your package")
                    .font(.title2.bold())
                    .foregroundStyle(AirShipTheme.textPrimary)

                HStack(spacing: 12) {
                    attachmentButton("Photos", icon: "photo") {
                        viewModel.addPhotoAttachment(name: "IMG_001.jpg", size: 2_450_000)
                    }
                    attachmentButton("Camera", icon: "camera") {
                        viewModel.addCameraAttachment(name: "CAM_SNAP.jpg", size: 3_100_000)
                    }
                    attachmentButton("Files", icon: "folder") {
                        viewModel.addFileAttachment(name: "Report.pdf", size: 5_200_000, mimeType: "application/pdf")
                    }
                    attachmentButton("Text", icon: "doc.text") {
                        viewModel.addTextAttachment(textSnippet: "Hello from AirShip!")
                    }
                }
                .padding(.horizontal)

                stagingArea

                Spacer()

                FloatingBottomBar(activeTab: $activeTab)
                    .padding(.bottom, 16)
            }
            .padding(.top)
        }
    }

    private func attachmentButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AirShipTheme.secondaryCardBackground)
            .foregroundStyle(AirShipTheme.accentCyan)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var stagingArea: some View {
        VStack {
            if viewModel.stagedItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(AirShipTheme.textSecondary)
                    Text("No files selected")
                        .font(.subheadline)
                        .foregroundStyle(AirShipTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.stagedItems) { item in
                        HStack {
                            Image(systemName: item.systemIconName)
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
                                viewModel.removeItem(id: item.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AirShipTheme.textSecondary)
                            }
                        }
                        .listRowBackground(AirShipTheme.secondaryCardBackground)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 280)
        .background(AirShipTheme.secondaryCardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AirShipTheme.cardCornerRadius))
        .padding(.horizontal)
    }
}
