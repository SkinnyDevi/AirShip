import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// -----------------------------------------------------------------------------
// 1. Segregated Service Protocols (ISP / DIP)
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// 2. Platform Clipboard Reader
// -----------------------------------------------------------------------------

public struct SystemClipboardReader: ClipboardReading {
	public init() {}

	public func readPlainText() -> String? {
		#if canImport(UIKit)
		return UIPasteboard.general.string
		#elseif canImport(AppKit)
		return NSPasteboard.general.string(forType: .string)
		#else
		return nil
		#endif
	}
}

// -----------------------------------------------------------------------------
// 3. PhotosUI Transferable Wrapper
// -----------------------------------------------------------------------------

public struct ImportedPhotoTransferable: Transferable, Sendable {
	public let temporaryFileURL: URL
	public let originalFilename: String

	public init(temporaryFileURL: URL, originalFilename: String) {
		self.temporaryFileURL = temporaryFileURL
		self.originalFilename = originalFilename
	}

	public static var transferRepresentation: some TransferRepresentation {
		FileRepresentation(importedContentType: .movie) { receivedFile in
			try copyImportedTransferFile(from: receivedFile.file, defaultExtension: "mov")
		}
		FileRepresentation(importedContentType: .image) { receivedFile in
			try copyImportedTransferFile(from: receivedFile.file, defaultExtension: "jpg")
		}
		FileRepresentation(importedContentType: .data) { receivedFile in
			try copyImportedTransferFile(from: receivedFile.file, defaultExtension: "bin")
		}
	}

	private static func copyImportedTransferFile(
		from receivedURL: URL,
		defaultExtension: String
	) throws -> ImportedPhotoTransferable {
		let fileSystem = FileManager.default
		let destinationDirectory = incomingTransferDirectoryURL(using: fileSystem)
		try fileSystem.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

		let filename = resolvedIncomingFilename(from: receivedURL, defaultExtension: defaultExtension)
		let copiedFileURL = destinationDirectory.appendingPathComponent(filename)
		try fileSystem.copyItem(at: receivedURL, to: copiedFileURL)

		return ImportedPhotoTransferable(
			temporaryFileURL: copiedFileURL,
			originalFilename: filename
		)
	}

	private static func incomingTransferDirectoryURL(using fileSystem: FileManager) -> URL {
		let rootTemp = fileSystem.temporaryDirectory
		let stagingRoot = rootTemp.appendingPathComponent(
			AttachmentConstants.stagingFolderName,
			isDirectory: true
		)
		let incomingRoot = stagingRoot.appendingPathComponent(
			AttachmentConstants.incomingPhotoFolderName,
			isDirectory: true
		)
		return incomingRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
	}

	private static func resolvedIncomingFilename(
		from receivedURL: URL,
		defaultExtension: String
	) -> String {
		let candidateName = receivedURL.lastPathComponent
		if !candidateName.isEmpty && candidateName != "/" {
			return candidateName
		}
		return generatedMediaFilename(prefix: "Photo", fileExtension: defaultExtension)
	}
}

// -----------------------------------------------------------------------------
// 4. Local Staging Service Implementation
// -----------------------------------------------------------------------------

public final class LocalAttachmentStagingService: AttachmentStagingServiceProtocol {
	private let stagingDirectoryURL: URL

	public init(stagingDirectoryURL: URL? = nil) {
		if let customDirectoryURL = stagingDirectoryURL {
			self.stagingDirectoryURL = customDirectoryURL
		} else {
			let baseTempDirectory = FileManager.default.temporaryDirectory
			self.stagingDirectoryURL = baseTempDirectory.appendingPathComponent(
				AttachmentConstants.stagingFolderName,
				isDirectory: true
			)
		}
	}

	public func stageFileCopy(
		from sourceURL: URL,
		sourceKind: AttachmentSourceKind,
		fallbackContentType: UTType?
	) throws -> StagedItem {
		let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
		defer {
			if hasSecurityScope {
				sourceURL.stopAccessingSecurityScopedResource()
			}
		}

		do {
			return try copySourceFileToStaging(
				from: sourceURL,
				sourceKind: sourceKind,
				fallbackContentType: fallbackContentType
			)
		} catch let stagingError as AttachmentStagingError {
			throw stagingError
		} catch {
			throw AttachmentStagingError.fileImportFailed(error.localizedDescription)
		}
	}

	public func stageEncodedMedia(
		encodedBytes: Data,
		filename: String,
		mimeType: String,
		sourceKind: AttachmentSourceKind
	) throws -> StagedItem {
		let itemIdentifier = UUID().uuidString
		do {
			let itemDirectory = try createItemDirectory(for: itemIdentifier)
			let destinationURL = itemDirectory.appendingPathComponent(filename)
			try encodedBytes.write(to: destinationURL, options: .atomic)

			return StagedItem(
				id: itemIdentifier,
				name: filename,
				byteSize: Int64(encodedBytes.count),
				mimeType: mimeType,
				systemIconName: sourceKind.systemIconName,
				sourceKind: sourceKind,
				content: .fileReference(destinationURL)
			)
		} catch {
			throw AttachmentStagingError.fileImportFailed(error.localizedDescription)
		}
	}

	public func stageTextSnippet(_ textSnippet: String) throws -> StagedItem {
		let trimmedText = textSnippet.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedText.isEmpty else {
			throw AttachmentStagingError.emptyTextSnippet
		}

		let byteCount = Int64(textSnippet.utf8.count)
		let title = resolvedTextAttachmentTitle(from: textSnippet)
		return StagedItem(
			id: UUID().uuidString,
			name: title,
			byteSize: byteCount,
			mimeType: AttachmentMimeTypes.plainText,
			systemIconName: AttachmentSourceKind.textSnippet.systemIconName,
			sourceKind: .textSnippet,
			content: .textPayload(textSnippet)
		)
	}

	public func removeStagedContent(for item: StagedItem) {
		guard case .fileReference(let stagedFileURL) = item.content else {
			return
		}

		let normalizedStagingPath = stagingDirectoryURL.standardizedFileURL.path
		let normalizedFilePath = stagedFileURL.standardizedFileURL.path
		guard normalizedFilePath.hasPrefix(normalizedStagingPath) else {
			return
		}

		let itemDirectoryURL = stagedFileURL.deletingLastPathComponent()
		try? FileManager.default.removeItem(at: itemDirectoryURL)
	}

	private func copySourceFileToStaging(
		from sourceURL: URL,
		sourceKind: AttachmentSourceKind,
		fallbackContentType: UTType?
	) throws -> StagedItem {
		let itemIdentifier = UUID().uuidString
		let itemDirectory = try createItemDirectory(for: itemIdentifier)
		let resolvedFilename = resolvedImportFilename(from: sourceURL)
		let destinationURL = itemDirectory.appendingPathComponent(resolvedFilename)

		try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

		let fileByteSize = readFileSize(at: destinationURL)
		let mimeType = resolvedMimeType(
			forFileExtension: destinationURL.pathExtension,
			fallbackContentType: fallbackContentType
		)

		return StagedItem(
			id: itemIdentifier,
			name: resolvedFilename,
			byteSize: fileByteSize,
			mimeType: mimeType,
			systemIconName: sourceKind.systemIconName,
			sourceKind: sourceKind,
			content: .fileReference(destinationURL)
		)
	}

	private func createItemDirectory(for itemIdentifier: String) throws -> URL {
		let itemDirectoryURL = stagingDirectoryURL.appendingPathComponent(
			itemIdentifier,
			isDirectory: true
		)
		try FileManager.default.createDirectory(
			at: itemDirectoryURL,
			withIntermediateDirectories: true
		)
		return itemDirectoryURL
	}

	private func resolvedImportFilename(from sourceURL: URL) -> String {
		let candidateName = sourceURL.lastPathComponent
		if !candidateName.isEmpty && candidateName != "/" {
			return candidateName
		}
		return generatedMediaFilename(prefix: "Attachment", fileExtension: "bin")
	}

	private func readFileSize(at fileURL: URL) -> Int64 {
		let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
		if let reportedSize = resourceValues?.fileSize {
			return Int64(reportedSize)
		}
		let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
		let rawSize = attributes?[.size] as? NSNumber
		return rawSize?.int64Value ?? 0
	}
}
