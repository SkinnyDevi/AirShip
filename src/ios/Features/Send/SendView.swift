import SwiftUI

public struct SendView: View {
	@ObservedObject public var viewModel: SendViewModel
	@Binding public var selectedMode: ModeSwitchOption

	public init(viewModel: SendViewModel, selectedMode: Binding<ModeSwitchOption>) {
		self.viewModel = viewModel
		self._selectedMode = selectedMode
	}

	public var body: some View {
		ZStack {
			AirShipTheme.primaryDarkBackground.ignoresSafeArea()

			VStack(spacing: 20) {
				SegmentedToggleView(selectedOption: $selectedMode)
					.padding(.horizontal)

				Text("Create your package")
					.font(.title2.bold())
					.foregroundStyle(AirShipTheme.textPrimary)

				AttachmentButtonsBar

				ItemsInPackageContainer

				Spacer()
			}
			.padding(.top)
		}
	}

	private var AttachmentButtonsBar: some View {
		GlassEffectContainer(spacing: 12) {
			HStack(spacing: 12) {
				AttachmentButton("Photos", icon: "photo") {
					viewModel.addPhotoAttachment(name: "IMG_001.jpg", size: 2_450_000)
				}
				AttachmentButton("Camera", icon: "camera") {
					viewModel.addCameraAttachment(name: "CAM_SNAP.jpg", size: 3_100_000)
				}
				AttachmentButton("Files", icon: "folder") {
					viewModel.addFileAttachment(
						name: "Report.pdf", size: 5_200_000, mimeType: "application/pdf")
				}
				AttachmentButton("Text", icon: "doc.text") {
					viewModel.addTextAttachment(textSnippet: "Hello from AirShip!")
				}
			}
		}
		.padding(.horizontal)
	}

	private func AttachmentButton(_ title: String, icon: String, action: @escaping () -> Void)
		-> some View
	{
		Button(action: action) {
			VStack(spacing: 6) {
				Image(systemName: icon)
					.font(.system(size: 20))
				Text(title)
					.font(.caption)
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 12)
			.foregroundStyle(AirShipTheme.accentCyan)
			.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
		}
		.buttonStyle(.plain)
	}

	private var ItemsInPackageContainer: some View {
		VStack {
			if viewModel.stagedItems.isEmpty {
				EmptyPackageContainer
			} else {
				List(viewModel.stagedItems, rowContent: ItemsInPackageRow)
					.listStyle(.plain)
					.scrollContentBackground(.hidden)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: 280)
		.glassEffect(.regular, in: .rect(cornerRadius: AirShipTheme.cardCornerRadius))
		.padding(.horizontal)
	}

	private var EmptyPackageContainer: some View {
		VStack(spacing: 8) {
			Image(systemName: "tray")
				.font(.system(size: 36))
				.foregroundStyle(AirShipTheme.textSecondary)
			Text("No files selected")
				.font(.subheadline)
				.foregroundStyle(AirShipTheme.textSecondary)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}

	private func ItemsInPackageRow(_ item: StagedItem) -> some View {
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
		.listRowBackground(Color.clear)
	}
}
