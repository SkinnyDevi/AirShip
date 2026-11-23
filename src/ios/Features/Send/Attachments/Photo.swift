import Foundation
import SwiftUI

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
