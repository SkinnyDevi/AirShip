#if canImport(UIKit)
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// -----------------------------------------------------------------------------
// 1. Camera Capture Wrapper (UIImagePickerController)
// -----------------------------------------------------------------------------

internal struct CameraCaptureView: UIViewControllerRepresentable {
	private let onCapturedJpegBytes: @MainActor (Data) -> Void
	private let onCaptureFailed: @MainActor (AttachmentStagingError) -> Void
	private let onCancelled: @MainActor () -> Void

	internal init(
		onCapturedJpegBytes: @escaping @MainActor (Data) -> Void,
		onCaptureFailed: @escaping @MainActor (AttachmentStagingError) -> Void,
		onCancelled: @escaping @MainActor () -> Void
	) {
		self.onCapturedJpegBytes = onCapturedJpegBytes
		self.onCaptureFailed = onCaptureFailed
		self.onCancelled = onCancelled
	}

	internal func makeCoordinator() -> Coordinator {
		Coordinator(
			onCapturedJpegBytes: onCapturedJpegBytes,
			onCaptureFailed: onCaptureFailed,
			onCancelled: onCancelled
		)
	}

	internal func makeUIViewController(context: Context) -> UIImagePickerController {
		let pickerController = UIImagePickerController()
		pickerController.sourceType = .camera
		pickerController.mediaTypes = [UTType.image.identifier]
		pickerController.delegate = context.coordinator
		return pickerController
	}

	internal func updateUIViewController(
		_ uiViewController: UIImagePickerController,
		context: Context
	) {}

	@MainActor
	internal final class Coordinator: NSObject, UIImagePickerControllerDelegate,
		UINavigationControllerDelegate
	{
		private let onCapturedJpegBytes: @MainActor (Data) -> Void
		private let onCaptureFailed: @MainActor (AttachmentStagingError) -> Void
		private let onCancelled: @MainActor () -> Void

		internal init(
			onCapturedJpegBytes: @escaping @MainActor (Data) -> Void,
			onCaptureFailed: @escaping @MainActor (AttachmentStagingError) -> Void,
			onCancelled: @escaping @MainActor () -> Void
		) {
			self.onCapturedJpegBytes = onCapturedJpegBytes
			self.onCaptureFailed = onCaptureFailed
			self.onCancelled = onCancelled
		}

		internal func imagePickerController(
			_ picker: UIImagePickerController,
			didFinishPickingMediaWithInfo mediaDetails: [UIImagePickerController.InfoKey: Any]
		) {
			let selectedImage =
				(mediaDetails[.editedImage] as? UIImage)
				?? (mediaDetails[.originalImage] as? UIImage)

			guard let capturedImage = selectedImage,
				let jpegBytes = capturedImage.jpegData(
					compressionQuality: AttachmentConstants.defaultJpegCompressionQuality
				)
			else {
				onCaptureFailed(.imageEncodingFailed)
				return
			}

			onCapturedJpegBytes(jpegBytes)
		}

		internal func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
			onCancelled()
		}
	}
}
#endif
