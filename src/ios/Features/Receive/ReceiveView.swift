import SwiftUI

#if canImport(UIKit)
	import UIKit
#endif

public struct ReceiveView: View {
	@ObservedObject public var viewModel: ReceiveViewModel
	@Binding public var selectedMode: ModeSwitchOption
	private let showsModeSwitcher: Bool
	@State private var copiedItemId: String?

	public init(
		viewModel: ReceiveViewModel,
		selectedMode: Binding<ModeSwitchOption>,
		showsModeSwitcher: Bool = true
	) {
		self.viewModel = viewModel
		self._selectedMode = selectedMode
		self.showsModeSwitcher = showsModeSwitcher
	}

	public var body: some View {
		if showsModeSwitcher {
			ZStack {
				AirShipTheme.primaryDarkBackground.ignoresSafeArea()

				VStack(spacing: 20) {
					SegmentedToggleView(selectedOption: $selectedMode)
						.padding(.horizontal)

					receiveContent
				}
				.padding(.top)
			}
		} else {
			receiveContent
		}
	}

	private var receiveContent: some View {
		VStack(spacing: 20) {
			ReceiveStateContainer
			Spacer()
		}
		.alert("Receive Error", isPresented: errorAlertBinding) {
			Button("OK", role: .cancel) {
				viewModel.dismissError()
			}
		} message: {
			Text(viewModel.errorMessage ?? "")
		}
	}

	@ViewBuilder
	private var ReceiveStateContainer: some View {
		switch viewModel.screenState {
		case .waiting:
			WaitingContainerView
		case .packageReceived(let items):
			PackageReceivedView(items: items)
		case .downloading:
			DownloadingProgressView
		case .completed:
			CompletedContainerView
		}
	}

	private var WaitingContainerView: some View {
		VStack(spacing: 20) {
			Spacer()
			BlimpLogoView(size: 130)
			Text("Waiting for your package...")
				.font(.title3.weight(.medium))
				.foregroundStyle(AirShipTheme.textPrimary)
			ProgressView()
				.tint(AirShipTheme.accentCyan)
			localIdentityPill
			Spacer()
		}
	}

	private var localIdentityPill: some View {
		VStack(spacing: 4) {
			Text(viewModel.localDisplayAlias)
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(AirShipTheme.textPrimary)
			Text(viewModel.localUserNameId)
				.font(.caption.monospaced())
				.foregroundStyle(AirShipTheme.accentCyan)
		}
		.padding(.horizontal, 18)
		.padding(.vertical, 10)
		.glassEffect(.regular, in: .capsule)
	}

	private func PackageReceivedView(items: [ReceivedPackageItem]) -> some View {
		VStack(spacing: 16) {
			Text("Package Received!")
				.font(.title2.bold())
				.foregroundStyle(AirShipTheme.textPrimary)

			if let senderAlias = viewModel.senderAlias {
				Text("From \(senderAlias)")
					.font(.subheadline)
					.foregroundStyle(AirShipTheme.accentCyan)
			}

			List(items, rowContent: PackageItemRow)
				.listStyle(.plain)
				.scrollContentBackground(.hidden)
				.frame(maxHeight: 300)
				.glassEffect(.regular, in: .rect(cornerRadius: AirShipTheme.cardCornerRadius))
				.padding(.horizontal)

			downloadAllButton
			declinePackageButton
		}
	}

	private var downloadAllButton: some View {
		Button {
			viewModel.downloadAllItems()
		} label: {
			Text("Download All")
				.font(.headline)
				.foregroundStyle(AirShipTheme.primaryDarkBackground)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 14)
				.glassEffect(.regular.tint(AirShipTheme.accentCyan).interactive(), in: .capsule)
		}
		.buttonStyle(.plain)
		.padding(.horizontal)
	}

	private var declinePackageButton: some View {
		Button {
			Task { await viewModel.declineIncomingPackage() }
		} label: {
			Text("Decline")
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(AirShipTheme.textSecondary)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 10)
				.glassEffect(.regular.interactive(), in: .capsule)
		}
		.buttonStyle(.plain)
		.padding(.horizontal)
	}

	private func PackageItemRow(_ item: ReceivedPackageItem) -> some View {
		HStack(spacing: 12) {
			Image(systemName: item.isTextSnippet ? "doc.text" : "doc")
				.foregroundStyle(AirShipTheme.accentCyan)

			VStack(alignment: .leading, spacing: 2) {
				Text(item.name)
					.lineLimit(1)
					.foregroundStyle(AirShipTheme.textPrimary)
				Text(formattedByteSize(item.byteSize))
					.font(.caption)
					.foregroundStyle(AirShipTheme.textSecondary)
			}

			Spacer()
			packageRowTrailingControl(for: item)
		}
		.listRowBackground(Color.clear)
	}

	@ViewBuilder
	private func packageRowTrailingControl(for item: ReceivedPackageItem) -> some View {
		if item.isDownloaded {
			savedItemActionControl(for: item)
		} else {
			Button {
				viewModel.downloadSingleItem(id: item.id)
			} label: {
				Image(systemName: "arrow.down.circle.fill")
					.font(.system(size: 24))
					.foregroundStyle(AirShipTheme.accentCyan)
			}
			.buttonStyle(.plain)
		}
	}

	private var DownloadingProgressView: some View {
		VStack(spacing: 18) {
			Spacer()
			if let fraction = viewModel.downloadProgressFraction {
				ProgressView(value: fraction)
					.tint(AirShipTheme.accentCyan)
					.padding(.horizontal, 40)
			} else {
				ProgressView()
					.tint(AirShipTheme.accentCyan)
			}
			Text("Downloading package...")
				.font(.headline)
				.foregroundStyle(AirShipTheme.accentCyan)
			Spacer()
		}
	}

	private var CompletedContainerView: some View {
		VStack(spacing: 16) {
			Image(systemName: "checkmark.circle.fill")
				.font(.system(size: 56))
				.foregroundStyle(Color.green)
			Text("All Items Saved!")
				.font(.title2.bold())
				.foregroundStyle(AirShipTheme.textPrimary)
			Text("Saved to Files › AirShip › Received")
				.font(.caption)
				.foregroundStyle(AirShipTheme.textSecondary)

			if !viewModel.savedItems.isEmpty {
				List(viewModel.savedItems, rowContent: SavedItemRow)
					.listStyle(.plain)
					.scrollContentBackground(.hidden)
					.frame(maxHeight: 280)
					.glassEffect(.regular, in: .rect(cornerRadius: AirShipTheme.cardCornerRadius))
					.padding(.horizontal)
			}

			doneReceivingButton
		}
		.padding(.top, 12)
	}

	private func SavedItemRow(_ item: ReceivedPackageItem) -> some View {
		HStack(spacing: 12) {
			Image(systemName: item.isTextSnippet ? "doc.text" : "doc.fill")
				.foregroundStyle(Color.green)

			VStack(alignment: .leading, spacing: 2) {
				Text(item.name)
					.lineLimit(1)
					.foregroundStyle(AirShipTheme.textPrimary)
				if let textContent = item.textContent {
					Text(textContent)
						.lineLimit(2)
						.font(.caption)
						.foregroundStyle(AirShipTheme.textSecondary)
				} else {
					Text(formattedByteSize(item.byteSize))
						.font(.caption)
						.foregroundStyle(AirShipTheme.textSecondary)
				}
			}

			Spacer()
			savedItemActionControl(for: item)
		}
		.listRowBackground(Color.clear)
	}

	@ViewBuilder
	private func savedItemActionControl(for item: ReceivedPackageItem) -> some View {
		if item.isTextSnippet, let textContent = item.textContent {
			copyTextButton(itemId: item.id, textContent: textContent)
		} else if let fileURL = item.localFileURL {
			ShareLink(item: fileURL) {
				Image(systemName: "square.and.arrow.up")
					.font(.system(size: 20))
					.foregroundStyle(AirShipTheme.accentCyan)
			}
		} else {
			Image(systemName: "checkmark.circle.fill")
				.font(.system(size: 22))
				.foregroundStyle(Color.green)
		}
	}

	private func copyTextButton(itemId: String, textContent: String) -> some View {
		Button {
			copyStringToPasteboard(textContent)
			copiedItemId = itemId
		} label: {
			Label(
				copiedItemId == itemId ? "Copied" : "Copy",
				systemImage: copiedItemId == itemId ? "checkmark" : "doc.on.doc"
			)
			.font(.caption.weight(.semibold))
			.foregroundStyle(AirShipTheme.accentCyan)
		}
		.buttonStyle(.plain)
	}

	private var doneReceivingButton: some View {
		Button {
			copiedItemId = nil
			viewModel.resetToWaiting()
		} label: {
			Text("Done")
				.font(.headline)
				.foregroundStyle(AirShipTheme.primaryDarkBackground)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 14)
				.glassEffect(.regular.tint(AirShipTheme.accentCyan).interactive(), in: .capsule)
		}
		.buttonStyle(.plain)
		.padding(.horizontal)
	}

	private var errorAlertBinding: Binding<Bool> {
		Binding(
			get: { viewModel.errorMessage != nil },
			set: { isPresented in
				if !isPresented {
					viewModel.dismissError()
				}
			}
		)
	}

	private func copyStringToPasteboard(_ text: String) {
		#if canImport(UIKit)
			UIPasteboard.general.string = text
		#endif
	}
}
