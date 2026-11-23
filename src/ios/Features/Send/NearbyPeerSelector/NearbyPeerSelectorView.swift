import SwiftUI

private func packageItemCountLabel(count: Int) -> String {
	return count == 1 ? "1 item" : "\(count) items"
}

public struct NearbyPeerSelectorView: View {
	@StateObject private var viewModel: NearbyPeerSelectorViewModel
	@Environment(\.dismiss) private var dismiss

	public init(viewModel: @autoclosure @escaping @MainActor () -> NearbyPeerSelectorViewModel) {
		self._viewModel = StateObject(wrappedValue: viewModel())
	}

	public var body: some View {
		ZStack {
			AirShipTheme.primaryDarkBackground.ignoresSafeArea()

			VStack(spacing: 16) {
				packageSummaryCard
				recipientContent
				Spacer(minLength: 0)
			}
			.padding(.top)
		}
		.navigationTitle("Select Recipient")
		#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
			.toolbar(.visible, for: .navigationBar)
		#endif
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				refreshPeersButton
			}
		}
		.task {
			await viewModel.loadNearbyPeers()
		}
		.alert("Unable to Load Peers", isPresented: errorAlertBinding) {
			Button("OK", role: .cancel) {
				viewModel.dismissError()
			}
		} message: {
			Text(viewModel.errorMessage ?? "")
		}
	}

	private var refreshPeersButton: some View {
		Button {
			Task { await viewModel.loadNearbyPeers() }
		} label: {
			Image(systemName: "arrow.clockwise")
				.foregroundStyle(AirShipTheme.accentCyan)
		}
		.disabled(viewModel.isDiscoveringPeers)
	}

	private var packageSummaryCard: some View {
		HStack {
			Image(systemName: "shippingbox.fill")
				.font(.title3)
				.foregroundStyle(AirShipTheme.accentCyan)

			VStack(alignment: .leading, spacing: 2) {
				Text("Ready to send \(packageItemCountLabel(count: viewModel.stagedItems.count))")
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(AirShipTheme.textPrimary)
				Text(formattedByteSize(viewModel.totalStagedByteSize))
					.font(.caption)
					.foregroundStyle(AirShipTheme.textSecondary)
			}

			Spacer()
		}
		.padding()
		.glassEffect(.regular, in: .rect(cornerRadius: AirShipTheme.cardCornerRadius))
		.padding(.horizontal)
	}

	@ViewBuilder
	private var recipientContent: some View {
		switch viewModel.transferState {
		case .sending:
			sendingProgressView
		case .completed:
			completedTransferView
		case .ready, .failed:
			peerSelectionContent
		}
	}

	@ViewBuilder
	private var peerSelectionContent: some View {
		if viewModel.isDiscoveringPeers && viewModel.nearbyPeers.isEmpty {
			scanningPeersView
		} else if viewModel.nearbyPeers.isEmpty {
			emptyPeersView
		} else {
			nearbyPeersList
		}
	}

	private var scanningPeersView: some View {
		VStack(spacing: 20) {
			Spacer()
			BlimpLogoView(size: 96)
			ProgressView()
				.tint(AirShipTheme.accentCyan)
			Text("Searching for nearby users...")
				.font(.headline)
				.foregroundStyle(AirShipTheme.textPrimary)
			Spacer()
		}
	}

	private var emptyPeersView: some View {
		VStack(spacing: 16) {
			Spacer()
			BlimpLogoView(size: 96)
			Text("No nearby users found")
				.font(.headline)
				.foregroundStyle(AirShipTheme.textPrimary)
			Text("Make sure recipients are on the same Wi-Fi network or added to your Trust List.")
				.font(.subheadline)
				.foregroundStyle(AirShipTheme.textSecondary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 24)
			scanAgainButton
			Spacer()
		}
	}

	private var scanAgainButton: some View {
		Button {
			Task { await viewModel.loadNearbyPeers() }
		} label: {
			Text("Scan Again")
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(AirShipTheme.primaryDarkBackground)
				.padding(.horizontal, 24)
				.padding(.vertical, 12)
				.glassEffect(.regular.tint(AirShipTheme.accentCyan).interactive(), in: .capsule)
		}
		.buttonStyle(.plain)
	}

	private var nearbyPeersList: some View {
		List(viewModel.nearbyPeers, rowContent: peerRow)
			.listStyle(.plain)
			.scrollContentBackground(.hidden)
			.glassEffect(.regular, in: .rect(cornerRadius: AirShipTheme.cardCornerRadius))
			.padding(.horizontal)
	}

	private func peerRow(_ peer: PeerBridgeModel) -> some View {
		HStack(spacing: 14) {
			Image(systemName: "person.crop.circle.fill")
				.font(.system(size: 32))
				.foregroundStyle(AirShipTheme.accentCyan)

			VStack(alignment: .leading, spacing: 2) {
				Text(peer.displayAlias)
					.font(.headline)
					.foregroundStyle(AirShipTheme.textPrimary)
				Text(peer.id)
					.font(.caption)
					.foregroundStyle(AirShipTheme.textSecondary)
			}

			Spacer()
			peerRowTrailingActions(for: peer)
		}
		.listRowBackground(Color.clear)
	}

	@ViewBuilder
	private func peerRowTrailingActions(for peer: PeerBridgeModel) -> some View {
		if peer.isTrusted {
			Image(systemName: "heart.fill")
				.font(.system(size: 16))
				.foregroundStyle(AirShipTheme.accentHeart)
		}

		Button {
			Task { await viewModel.dispatchPackage(to: peer.id) }
		} label: {
			Image(systemName: "paperplane.circle.fill")
				.font(.system(size: 28))
				.foregroundStyle(AirShipTheme.accentCyan)
		}
		.buttonStyle(.plain)
	}

	private var sendingProgressView: some View {
		VStack(spacing: 16) {
			Spacer()
			ProgressView("Sending package...")
				.tint(AirShipTheme.accentCyan)
				.foregroundStyle(AirShipTheme.accentCyan)
			Spacer()
		}
	}

	private var completedTransferView: some View {
		VStack(spacing: 18) {
			Spacer()
			Image(systemName: "checkmark.circle.fill")
				.font(.system(size: 64))
				.foregroundStyle(Color.green)
			Text("Package Sent!")
				.font(.title2.bold())
				.foregroundStyle(AirShipTheme.textPrimary)
			doneButton
			Spacer()
		}
	}

	private var doneButton: some View {
		Button {
			viewModel.finishCompletedTransfer()
			dismiss()
		} label: {
			Text("Done")
				.font(.headline)
				.foregroundStyle(AirShipTheme.primaryDarkBackground)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 14)
				.glassEffect(.regular.tint(AirShipTheme.accentCyan).interactive(), in: .capsule)
		}
		.buttonStyle(.plain)
		.padding(.horizontal, 32)
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
}
