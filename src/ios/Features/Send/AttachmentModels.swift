import CoreGraphics
import Foundation
import UniformTypeIdentifiers

// -----------------------------------------------------------------------------
// 1. Constants & Primitive Error Types
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// 2. Pure Helper Functions
// -----------------------------------------------------------------------------

public func formattedByteSize(_ byteCount: Int64) -> String {
	let clampedByteCount = max(0, byteCount)
	return ByteCountFormatter.string(fromByteCount: clampedByteCount, countStyle: .file)
}

public func resolvedMimeType(forFileExtension fileExtension: String, fallbackContentType: UTType?)
	-> String
{
	let normalizedExtension = fileExtension
		.trimmingCharacters(in: .whitespacesAndNewlines)
		.lowercased()

	if let resolvedFromExtension = mimeTypeForExtension(normalizedExtension) {
		return resolvedFromExtension
	}

	if let resolvedFromContentType = mimeTypeForContentType(fallbackContentType) {
		return resolvedFromContentType
	}

	return AttachmentMimeTypes.octetStream
}

private func mimeTypeForExtension(_ normalizedExtension: String) -> String? {
	guard !normalizedExtension.isEmpty else { return nil }
	if let systemMime = UTType(filenameExtension: normalizedExtension)?.preferredMIMEType {
		return systemMime
	}
	return AttachmentMimeTypes.commonByExtension[normalizedExtension]
}

private func mimeTypeForContentType(_ contentType: UTType?) -> String? {
	guard let contentType else { return nil }
	if let systemMime = contentType.preferredMIMEType {
		return systemMime
	}
	return AttachmentMimeTypes.commonByTypeIdentifier[contentType.identifier]
}

public func resolvedTextAttachmentTitle(from textSnippet: String) -> String {
	let lines = textSnippet.components(separatedBy: .newlines)
	let firstNonEmptyLine = lines
		.map { line in line.trimmingCharacters(in: .whitespacesAndNewlines) }
		.first { trimmedLine in !trimmedLine.isEmpty }

	guard let titleLine = firstNonEmptyLine else {
		return AttachmentConstants.defaultTextTitle
	}

	if titleLine.count <= AttachmentConstants.maxTextTitleLength {
		return titleLine
	}

	let endIndex = titleLine.index(
		titleLine.startIndex,
		offsetBy: AttachmentConstants.maxTextTitleLength
	)
	return "\(titleLine[..<endIndex])…"
}

public func generatedMediaFilename(
	prefix: String,
	fileExtension: String,
	timestamp: Date = Date()
) -> String {
	let formatter = DateFormatter()
	formatter.locale = Locale(identifier: "en_US_POSIX")
	formatter.timeZone = TimeZone(secondsFromGMT: 0)
	formatter.dateFormat = "yyyyMMdd_HHmmss"

	let formattedTimestamp = formatter.string(from: timestamp)
	let normalizedExtension = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
	return "\(prefix)_\(formattedTimestamp).\(normalizedExtension)"
}

// -----------------------------------------------------------------------------
// 3. Domain Model
// -----------------------------------------------------------------------------

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
