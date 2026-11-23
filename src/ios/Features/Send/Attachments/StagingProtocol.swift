import Foundation
import UniformTypeIdentifiers

public protocol AttachmentStagingServiceProtocol: Sendable {
	func stageFileCopy(
		from sourceURL: URL,
		sourceKind: AttachmentSourceKind,
		fallbackContentType: UTType?
	) throws -> StagedItem

	func stageEncodedMedia(
		encodedBytes: Data,
		filename: String,
		mimeType: String,
		sourceKind: AttachmentSourceKind
	) throws -> StagedItem

	func stageTextSnippet(_ textSnippet: String) throws -> StagedItem

	func removeStagedContent(for item: StagedItem)
}

@MainActor
public protocol ClipboardReading: Sendable {
	func readPlainText() -> String?
}
