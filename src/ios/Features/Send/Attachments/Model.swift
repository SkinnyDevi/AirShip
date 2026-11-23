import Foundation
import UniformTypeIdentifiers

public enum AttachmentConstants {
	public static let defaultJpegCompressionQuality: CGFloat = 0.9
	public static let maxTextTitleLength: Int = 40
	public static let defaultTextTitle: String = "Text Note"
	public static let stagingFolderName: String = "AirShipStagedAttachments"
	public static let incomingPhotoFolderName: String = "IncomingPhotos"
}

public enum AttachmentMimeTypes {
	public static let jpeg: String = "image/jpeg"
	public static let plainText: String = "text/plain"
	public static let octetStream: String = "application/octet-stream"

	internal static let commonByExtension: [String: String] = [
		"jpg": "image/jpeg",
		"jpeg": "image/jpeg",
		"png": "image/png",
		"heic": "image/heic",
		"gif": "image/gif",
		"webp": "image/webp",
		"mov": "video/quicktime",
		"mp4": "video/mp4",
		"m4v": "video/x-m4v",
		"pdf": "application/pdf",
		"txt": "text/plain",
		"md": "text/markdown",
		"json": "application/json",
		"csv": "text/csv",
		"zip": "application/zip",
	]

	internal static let commonByTypeIdentifier: [String: String] = [
		UTType.jpeg.identifier: "image/jpeg",
		UTType.png.identifier: "image/png",
		UTType.heic.identifier: "image/heic",
		UTType.gif.identifier: "image/gif",
		UTType.quickTimeMovie.identifier: "video/quicktime",
		UTType.mpeg4Movie.identifier: "video/mp4",
		UTType.pdf.identifier: "application/pdf",
		UTType.plainText.identifier: "text/plain",
		UTType.json.identifier: "application/json",
		UTType.zip.identifier: "application/zip",
	]
}

public enum AttachmentSourceKind: String, Equatable, Sendable {
	case photoLibrary
	case cameraCapture
	case documentFile
	case textSnippet

	public var systemIconName: String {
		switch self {
		case .photoLibrary:
			return "photo"
		case .cameraCapture:
			return "camera"
		case .documentFile:
			return "doc"
		case .textSnippet:
			return "doc.text"
		}
	}
}

public enum StagedItemContent: Equatable, Sendable {
	case fileReference(URL)
	case textPayload(String)
	case metadataOnly
}

public enum AttachmentStagingError: Error, LocalizedError, Equatable {
	case emptyTextSnippet
	case cameraUnavailable
	case cameraPermissionDenied
	case photoLoadFailed(String)
	case fileImportFailed(String)
	case imageEncodingFailed

	public var errorDescription: String? {
		switch self {
		case .emptyTextSnippet:
			return "Please enter some text before adding it to your package."
		case .cameraUnavailable:
			return "Camera is not available on this device."
		case .cameraPermissionDenied:
			return "Camera access was denied. Enable camera permissions in Settings to capture photos."
		case .photoLoadFailed(let details):
			return "Unable to load selected photo or video: \(details)"
		case .fileImportFailed(let details):
			return "Unable to import selected file: \(details)"
		case .imageEncodingFailed:
			return "Unable to encode the captured photo."
		}
	}
}

public struct StagedItem: Identifiable, Equatable, Sendable {
	public let id: String
	public let name: String
	public let byteSize: Int64
	public let mimeType: String
	public let systemIconName: String
	public let sourceKind: AttachmentSourceKind
	public let content: StagedItemContent

	public init(
		id: String,
		name: String,
		byteSize: Int64,
		mimeType: String,
		systemIconName: String,
		sourceKind: AttachmentSourceKind = .documentFile,
		content: StagedItemContent = .metadataOnly
	) {
		self.id = id
		self.name = name
		self.byteSize = byteSize
		self.mimeType = mimeType
		self.systemIconName = systemIconName
		self.sourceKind = sourceKind
		self.content = content
	}
}
