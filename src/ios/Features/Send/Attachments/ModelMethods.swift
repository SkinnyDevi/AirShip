import UniformTypeIdentifiers

public func formattedByteSize(_ byteCount: Int64) -> String {
	let clampedByteCount = max(0, byteCount)
	return ByteCountFormatter.string(fromByteCount: clampedByteCount, countStyle: .file)
}

public func resolvedMimeType(forFileExtension fileExtension: String, fallbackContentType: UTType?)
	-> String
{
	let normalizedExtension =
		fileExtension
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
	let firstNonEmptyLine =
		lines
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
