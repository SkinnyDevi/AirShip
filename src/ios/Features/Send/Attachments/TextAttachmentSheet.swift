import SwiftUI

// -----------------------------------------------------------------------------
// 1. Text Attachment Sheet
// -----------------------------------------------------------------------------

internal struct TextAttachmentSheet: View {
	@Environment(\.dismiss) private var dismiss
	@State private var draftText: String = ""

	private let clipboardReader: ClipboardReading
	private let onSubmitText: (String) -> Void

	internal init(
		clipboardReader: ClipboardReading = SystemClipboardReader(),
		onSubmitText: @escaping (String) -> Void
	) {
		self.clipboardReader = clipboardReader
		self.onSubmitText = onSubmitText
	}

	internal var body: some View {
		NavigationStack {
			ZStack {
				AirShipTheme.primaryDarkBackground.ignoresSafeArea()

				VStack(spacing: 16) {
					editorCard
					footerRow
				}
				.padding()
			}
			.navigationTitle("Add Text")
			#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
			#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						dismiss()
					}
					.foregroundStyle(AirShipTheme.textSecondary)
				}
			}
		}
	}

	private var editorCard: some View {
		ZStack(alignment: .topLeading) {
			if draftText.isEmpty {
				Text("Type or paste text to share...")
					.foregroundStyle(AirShipTheme.textSecondary)
					.padding(.horizontal, 16)
					.padding(.vertical, 20)
			}

			TextEditor(text: $draftText)
				.foregroundStyle(AirShipTheme.textPrimary)
				.scrollContentBackground(.hidden)
				.padding(12)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.glassEffect(.regular, in: .rect(cornerRadius: AirShipTheme.cardCornerRadius))
	}

	private var footerRow: some View {
		HStack(spacing: 12) {
			Text(formattedByteSize(Int64(draftText.utf8.count)))
				.font(.caption)
				.foregroundStyle(AirShipTheme.textSecondary)

			Spacer()

			pasteClipboardButton
			submitTextButton
		}
	}

	private var pasteClipboardButton: some View {
		Button {
			appendClipboardText()
		} label: {
			Label("Paste", systemImage: "doc.on.clipboard")
				.font(.subheadline.weight(.medium))
				.foregroundStyle(AirShipTheme.accentCyan)
				.padding(.horizontal, 14)
				.padding(.vertical, 10)
				.glassEffect(.regular.interactive(), in: .capsule)
		}
		.buttonStyle(.plain)
	}

	private var submitTextButton: some View {
		let isDraftEmpty = draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		return Button {
			submitDraftText()
		} label: {
			Text("Add Text")
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(AirShipTheme.primaryDarkBackground)
				.padding(.horizontal, 18)
				.padding(.vertical, 10)
				.glassEffect(
					.regular.tint(AirShipTheme.accentCyan).interactive(),
					in: .capsule
				)
		}
		.buttonStyle(.plain)
		.disabled(isDraftEmpty)
		.opacity(isDraftEmpty ? 0.5 : 1.0)
	}

	private func appendClipboardText() {
		guard let clipboardText = clipboardReader.readPlainText(), !clipboardText.isEmpty else {
			return
		}
		if draftText.isEmpty {
			draftText = clipboardText
		} else {
			draftText.append(clipboardText)
		}
	}

	private func submitDraftText() {
		let trimmedText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedText.isEmpty else { return }
		onSubmitText(draftText)
		dismiss()
	}
}
