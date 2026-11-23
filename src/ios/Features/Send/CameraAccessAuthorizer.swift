import AVFoundation
import Foundation

#if canImport(UIKit)
import UIKit
#endif

// -----------------------------------------------------------------------------
// 1. Authorization Result & Protocol (DIP)
// -----------------------------------------------------------------------------

public enum CameraAuthorizationResult: Equatable, Sendable {
	case authorized
	case denied
	case unavailable
}

public protocol CameraAccessAuthorizing: Sendable {
	func requestCameraAccess() async -> CameraAuthorizationResult
}

// -----------------------------------------------------------------------------
// 2. System Camera Authorization Implementation
// -----------------------------------------------------------------------------

public struct SystemCameraAccessAuthorizer: CameraAccessAuthorizing {
	public init() {}

	public func requestCameraAccess() async -> CameraAuthorizationResult {
		#if canImport(UIKit)
		let isCameraAvailable = await MainActor.run {
			UIImagePickerController.isSourceTypeAvailable(.camera)
		}
		guard isCameraAvailable else {
			return .unavailable
		}

		let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
		switch currentStatus {
		case .authorized:
			return .authorized
		case .notDetermined:
			let isGranted = await AVCaptureDevice.requestAccess(for: .video)
			return isGranted ? .authorized : .denied
		case .denied, .restricted:
			return .denied
		@unknown default:
			return .denied
		}
		#else
		return .unavailable
		#endif
	}
}
