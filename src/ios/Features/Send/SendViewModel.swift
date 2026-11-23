import Combine
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public final class SendViewModel: ObservableObject {
	@Published public private(set) var stagedItems: [StagedItem] = []
	@Published public private(set) var transferState: SendTransferState = .empty
	@Published public private(set) var isStagingAttachments = false
	@Published public private(set) var attachmentErrorMessage: String?

	private let coreBridge: AirShipCoreBridgeProtocol
	private let stagingService: AttachmentStagingServiceProtocol
	private let cameraAuthorizer: CameraAccessAuthorizing

	public var canSendPackage: Bool {
		!stagedItems.isEmpty && !isStagingAttachments
	}

	public init(
		coreBridge: AirShipCoreBridgeProtocol,
		stagingService: AttachmentStagingServiceProtocol = LocalAttachmentStagingService(),
		cameraAuthorizer: CameraAccessAuthorizing = SystemCameraAccessAuthorizer()
	) {
		self.coreBridge = coreBridge
		self.stagingService = stagingService
		self.cameraAuthorizer = cameraAuthorizer
	}

	public func addPhotoAttachment(name: String, size: Int64) {
		let item = StagedItem(
			id: UUID().uuidString,
			name: name,
			byteSize: size,
			mimeType: AttachmentMimeTypes.jpeg,
			systemIconName: AttachmentSourceKind.photoLibrary.systemIconName,
			sourceKind: .photoLibrary,
			content: .metadataOnly
		)
		appendStagedItem(item)
	}

	public func addCameraAttachment(name: String, size: Int64) {
		let item = StagedItem(
			id: UUID().uuidString,
			name: name,
			byteSize: size,
			mimeType: AttachmentMimeTypes.jpeg,
			systemIconName: AttachmentSourceKind.cameraCapture.systemIconName,
			sourceKind: .cameraCapture,
			content: .metadataOnly
		)
		appendStagedItem(item)
	}

	public func addFileAttachment(name: String, size: Int64, mimeType: String) {
		let item = StagedItem(
			id: UUID().uuidString,
			name: name,
			byteSize: size,
			mimeType: mimeType,
			systemIconName: AttachmentSourceKind.documentFile.systemIconName,
			sourceKind: .documentFile,
			content: .metadataOnly
		)
		appendStagedItem(item)
	}

	public func addTextAttachment(textSnippet: String) {
		do {
			let stagedTextItem = try stagingService.stageTextSnippet(textSnippet)
			appendStagedItem(stagedTextItem)
		} catch {
			reportAttachmentError(error)
		}
	}

	public func importPhotoPickerItems(_ pickerItems: [PhotosPickerItem]) async {
		guard !pickerItems.isEmpty else { return }
		isStagingAttachments = true
		defer { isStagingAttachments = false }

		for pickerItem in pickerItems {
			await stageSinglePhotoPickerItem(pickerItem)
		}
	}

	public func prepareCameraCapture() async -> Bool {
		let authorization = await cameraAuthorizer.requestCameraAccess()
		switch authorization {
		case .authorized:
			return true
		case .unavailable:
			reportAttachmentError(AttachmentStagingError.cameraUnavailable)
			return false
		case .denied:
			reportAttachmentError(AttachmentStagingError.cameraPermissionDenied)
			return false
		}
	}

	public func stageCapturedCameraImage(jpegBytes: Data, capturedAt: Date = Date()) {
		let filename = generatedMediaFilename(
			prefix: "Camera",
			fileExtension: "jpg",
			timestamp: capturedAt
		)
		do {
			let stagedPhoto = try stagingService.stageEncodedMedia(
				encodedBytes: jpegBytes,
				filename: filename,
				mimeType: AttachmentMimeTypes.jpeg,
				sourceKind: .cameraCapture
			)
			appendStagedItem(stagedPhoto)
		} catch {
			reportAttachmentError(error)
		}
	}

	public func handleFileImporterResult(_ result: Result<[URL], Error>) {
		switch result {
		case .success(let selectedURLs):
			stageImportedFileURLs(selectedURLs)
		case .failure(let importError):
			reportAttachmentError(
				AttachmentStagingError.fileImportFailed(importError.localizedDescription)
			)
		}
	}

	public func stageImportedFileURLs(_ fileURLs: [URL]) {
		guard !fileURLs.isEmpty else { return }
		isStagingAttachments = true
		defer { isStagingAttachments = false }

		for fileURL in fileURLs {
			stageSingleImportedFile(fileURL)
		}
	}

	public func removeItem(id: String) {
		if let matchingItem = stagedItems.first(where: { $0.id == id }) {
			stagingService.removeStagedContent(for: matchingItem)
		}
		stagedItems.removeAll { $0.id == id }
		if stagedItems.isEmpty {
			transferState = .empty
		}
	}

	public func reportAttachmentError(_ error: Error) {
		if let localizedError = error as? LocalizedError,
			let message = localizedError.errorDescription
		{
			attachmentErrorMessage = message
			return
		}
		attachmentErrorMessage = error.localizedDescription
	}

	public func dismissAttachmentError() {
		attachmentErrorMessage = nil
	}

	public func clearStagedItems() {
		for stagedItem in stagedItems {
			stagingService.removeStagedContent(for: stagedItem)
		}
		stagedItems.removeAll()
		transferState = .empty
	}

	public func makePeerSelectorViewModel() -> NearbyPeerSelectorViewModel {
		NearbyPeerSelectorViewModel(
			coreBridge: coreBridge,
			stagedItems: stagedItems,
			onTransferCompleted: { [weak self] in
				self?.clearStagedItems()
			}
		)
	}

	public func dispatchPackage(to peerId: String) async {
		guard !stagedItems.isEmpty else { return }
		transferState = .sending
		let outgoingItems = stagedItems.map(buildOutgoingItem)

		do {
			try await coreBridge.sendPackage(to: peerId, items: outgoingItems) { _ in }
			transferState = .completed
		} catch {
			transferState = .failed(error.localizedDescription)
		}
	}

	private func buildOutgoingItem(from stagedItem: StagedItem) -> OutgoingTransferItem {
		let source: OutgoingPayloadSource
		switch stagedItem.content {
		case .fileReference(let fileURL):
			source = .fileURL(fileURL)
		case .textPayload(let textContent):
			source = .textContent(textContent)
		case .metadataOnly:
			source = .textContent("")
		}
		return OutgoingTransferItem(
			id: stagedItem.id,
			name: stagedItem.name,
			byteSize: stagedItem.byteSize,
			mimeType: stagedItem.mimeType,
			isTextSnippet: stagedItem.sourceKind == .textSnippet,
			payloadSource: source
		)
	}

	private func stageSinglePhotoPickerItem(_ pickerItem: PhotosPickerItem) async {
		do {
			guard
				let importedPhoto = try await pickerItem.loadTransferable(
					type: ImportedPhotoTransferable.self
				)
			else {
				reportAttachmentError(AttachmentStagingError.photoLoadFailed("Unsupported media item"))
				return
			}
			let incomingDirectory = importedPhoto.temporaryFileURL.deletingLastPathComponent()
			defer { try? FileManager.default.removeItem(at: incomingDirectory) }

			let fallbackContentType = pickerItem.supportedContentTypes.first
			let stagedItem = try stagingService.stageFileCopy(
				from: importedPhoto.temporaryFileURL,
				sourceKind: .photoLibrary,
				fallbackContentType: fallbackContentType
			)
			appendStagedItem(stagedItem)
		} catch {
			reportAttachmentError(AttachmentStagingError.photoLoadFailed(error.localizedDescription))
		}
	}

	private func stageSingleImportedFile(_ fileURL: URL) {
		do {
			let stagedFile = try stagingService.stageFileCopy(
				from: fileURL,
				sourceKind: .documentFile,
				fallbackContentType: nil
			)
			appendStagedItem(stagedFile)
		} catch {
			reportAttachmentError(error)
		}
	}

	private func appendStagedItem(_ item: StagedItem) {
		stagedItems.append(item)
		transferState = .staged
	}
}
