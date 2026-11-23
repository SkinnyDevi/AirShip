import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

public struct SendView: View {
	@ObservedObject public var viewModel: SendViewModel
	@Binding public var selectedMode: ModeSwitchOption
	private let showsModeSwitcher: Bool

	@State private var isPhotosPickerPresented = false
	@State private var selectedPhotoPickerItems: [PhotosPickerItem] = []
	@State private var isCameraPresented = false
	@State private var isFileImporterPresented = false
	@State private var isTextSheetPresented = false
	@State private var isPeerSelectorPresented = false

	public init(
		viewModel: SendViewModel,
		selectedMode: Binding<ModeSwitchOption>,
		showsModeSwitcher: Bool = true
	) {
		self.viewModel = viewModel
		self._selectedMode = selectedMode
		self.showsModeSwitcher = showsModeSwitcher
	}

	public var body: some View {
		if showsModeSwitcher {
			NavigationStack {
				ZStack {
					AirShipTheme.primaryDarkBackground.ignoresSafeArea()

					VStack(spacing: 20) {
						SegmentedToggleView(selectedOption: $selectedMode)
							.padding(.horizontal)

						configuredSendContent
					}
					.padding(.top)
				}
				#if os(iOS)
					.toolbar(.hidden, for: .navigationBar)
				#endif
			}
		} else {
			configuredSendContent
		}
	}

	private var configuredSendContent: some View {
		sendContentWithSheets
			.navigationDestination(isPresented: $isPeerSelectorPresented) {
				NearbyPeerSelectorView(viewModel: viewModel.makePeerSelectorViewModel())
			}
			.alert("Unable to Attach Item", isPresented: attachmentErrorAlertBinding) {
				Button("OK", role: .cancel) {
					viewModel.dismissAttachmentError()
				}
			} message: {
				Text(viewModel.attachmentErrorMessage ?? "")
			}
	}

	private var sendContentWithSheets: some View {
		sendContentWithPickers
			.sheet(isPresented: $isTextSheetPresented) {
				TextAttachmentSheet { submittedText in
					viewModel.addTextAttachment(textSnippet: submittedText)
				}
			}
			#if canImport(UIKit)
				.fullScreenCover(isPresented: $isCameraPresented) {
					cameraCaptureSheet
				}
			#endif
	}

	private var sendContentWithPickers: some View {
		sendContent
			.photosPicker(
				isPresented: $isPhotosPickerPresented,
				selection: $selectedPhotoPickerItems,
				matching: .any(of: [.images, .videos]),
				photoLibrary: .shared()
			)
			.onChange(of: selectedPhotoPickerItems) { _, updatedSelection in
				handlePhotoSelectionChange(updatedSelection)
			}
			.fileImporter(
				isPresented: $isFileImporterPresented,
				allowedContentTypes: [.item],
				allowsMultipleSelection: true
			) { importResult in
				viewModel.handleFileImporterResult(importResult)
			}
	}

	private var sendContent: some View {
		VStack(spacing: 20) {
			Text("Create your package")
				.font(.title2.bold())
				.foregroundStyle(AirShipTheme.textPrimary)

			AttachmentButtonsBar

			if viewModel.isStagingAttachments {
				StagingProgressBanner
			}

			ItemsInPackageContainer

			if !viewModel.stagedItems.isEmpty {
				SendPackageActionButton
			}

			Spacer(minLength: 0)
		}
	}

	private var AttachmentButtonsBar: some View {
		GlassEffectContainer(spacing: 12) {
			HStack(spacing: 12) {
				AttachmentButton("Photos", icon: "photo") {
					isPhotosPickerPresented = true
				}
				AttachmentButton("Camera", icon: "camera") {
					Task { await requestAndPresentCamera() }
				}
				AttachmentButton("Files", icon: "folder") {
					isFileImporterPresented = true
				}
				AttachmentButton("Text", icon: "doc.text") {
					isTextSheetPresented = true
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

	private var StagingProgressBanner: some View {
		HStack(spacing: 8) {
			ProgressView()
				.tint(AirShipTheme.accentCyan)
			Text("Adding attachments...")
				.font(.caption)
				.foregroundStyle(AirShipTheme.textSecondary)
		}
	}

	private var SendPackageActionButton: some View {
		Button {
			isPeerSelectorPresented = true
		} label: {
			Label(sendActionButtonTitle, systemImage: "paperplane.fill")
				.font(.headline)
				.foregroundStyle(AirShipTheme.primaryDarkBackground)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 14)
				.glassEffect(.regular.tint(AirShipTheme.accentCyan).interactive(), in: .capsule)
		}
		.buttonStyle(.plain)
		.disabled(!viewModel.canSendPackage)
		.opacity(viewModel.canSendPackage ? 1.0 : 0.5)
		.padding(.horizontal)
		.padding(.bottom, 8)
	}

	private var sendActionButtonTitle: String {
		let count = viewModel.stagedItems.count
		return count == 1 ? "Send 1 Item" : "Send \(count) Items"
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
		.frame(maxWidth: .infinity, maxHeight: 640)
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
				.font(.system(size: 22))
			VStack(alignment: .leading) {
				Text(item.name)
					.lineLimit(1)
					.foregroundStyle(AirShipTheme.textPrimary)
				Text(formattedByteSize(item.byteSize))
					.font(.caption)
					.foregroundStyle(AirShipTheme.textSecondary)
			}
			Spacer()
			Button {
				viewModel.removeItem(id: item.id)
			} label: {
				Image(systemName: "xmark.circle.fill")
					.foregroundStyle(AirShipTheme.textSecondary)
					.font(.system(size: 22))
			}
			.buttonStyle(.plain)
		}
		.listRowBackground(Color.clear)
	}

	private var attachmentErrorAlertBinding: Binding<Bool> {
		Binding(
			get: { viewModel.attachmentErrorMessage != nil },
			set: { isPresented in
				if !isPresented {
					viewModel.dismissAttachmentError()
				}
			}
		)
	}

	#if canImport(UIKit)
		private var cameraCaptureSheet: some View {
			CameraCaptureView(
				onCapturedJpegBytes: { jpegBytes in
					viewModel.stageCapturedCameraImage(jpegBytes: jpegBytes)
					isCameraPresented = false
				},
				onCaptureFailed: { captureError in
					isCameraPresented = false
					viewModel.reportAttachmentError(captureError)
				},
				onCancelled: {
					isCameraPresented = false
				}
			)
			.ignoresSafeArea()
		}
	#endif

	private func handlePhotoSelectionChange(_ updatedSelection: [PhotosPickerItem]) {
		guard !updatedSelection.isEmpty else { return }
		let selectionToImport = updatedSelection
		selectedPhotoPickerItems = []
		Task {
			await viewModel.importPhotoPickerItems(selectionToImport)
		}
	}

	private func requestAndPresentCamera() async {
		let isReady = await viewModel.prepareCameraCapture()
		if isReady {
			isCameraPresented = true
		}
	}
}
