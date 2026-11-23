import SwiftUI

public enum ModeSwitchOption: String, CaseIterable, Identifiable {
	case send = "Send"
	case receive = "Receive"

	public var id: String { rawValue }
}

private enum SegmentedToggleMetrics {
	static let glassContainerSpacing: CGFloat = 16
	static let buttonRowSpacing: CGFloat = 6
	static let barInnerPadding: CGFloat = 6
	static let buttonHorizontalPadding: CGFloat = 16
	static let buttonVerticalPadding: CGFloat = 12
	static let dragActivationDistance: CGFloat = 8
	static let activePillScaleWhileDragging: CGFloat = 1.06
	static let activePillHighlightOpacity: Double = 0.16
	static let activeSelectionIdentifier = "activeModeSwitchSelection"
}

internal func resolvedModeSwitchOption(
	atHorizontalOffset horizontalOffset: CGFloat,
	totalBarWidth: CGFloat
) -> ModeSwitchOption? {
	let availableOptions = ModeSwitchOption.allCases
	guard totalBarWidth > 0, !availableOptions.isEmpty else { return nil }

	let normalizedPosition = min(max(horizontalOffset / totalBarWidth, 0), 0.999)
	let targetIndex = Int(normalizedPosition * CGFloat(availableOptions.count))
	guard availableOptions.indices.contains(targetIndex) else { return nil }

	return availableOptions[targetIndex]
}

public struct SegmentedToggleView: View {
	@Binding public var selectedOption: ModeSwitchOption
	@Namespace private var selectionNamespace
	@State private var barWidth: CGFloat = 0
	@State private var isScrubbingOptions = false

	public init(selectedOption: Binding<ModeSwitchOption>) {
		self._selectedOption = selectedOption
	}

	public var body: some View {
		GlassEffectContainer(spacing: SegmentedToggleMetrics.glassContainerSpacing) {
			HStack(spacing: SegmentedToggleMetrics.buttonRowSpacing) {
				ForEach(ModeSwitchOption.allCases, content: optionButton)
			}
			.frame(maxWidth: .infinity)
			.padding(SegmentedToggleMetrics.barInnerPadding)
			.glassEffect(.regular.interactive(), in: .capsule)
			.onGeometryChange(for: CGFloat.self) { geometryProxy in
				geometryProxy.size.width
			} action: { updatedWidth in
				barWidth = updatedWidth
			}
			.simultaneousGesture(modeScrubGesture)
		}
	}

	private func optionButton(for option: ModeSwitchOption) -> some View {
		let isSelected = selectedOption == option
		return Button {
			selectOption(option)
		} label: {
			optionButtonLabel(for: option, isSelected: isSelected)
		}
		.buttonStyle(.plain)
	}

	private func optionButtonLabel(for option: ModeSwitchOption, isSelected: Bool) -> some View {
		Text(option.rawValue)
			.font(.headline.weight(isSelected ? .semibold : .medium))
			.foregroundStyle(isSelected ? AirShipTheme.textPrimary : AirShipTheme.textSecondary)
			.frame(maxWidth: .infinity)
			.padding(.horizontal, SegmentedToggleMetrics.buttonHorizontalPadding)
			.padding(.vertical, SegmentedToggleMetrics.buttonVerticalPadding)
			.background {
				if isSelected {
					activeSelectionPill
				}
			}
			.contentShape(Capsule())
	}

	private var activeSelectionPill: some View {
		Capsule()
			.fill(Color.white.opacity(SegmentedToggleMetrics.activePillHighlightOpacity))
			.matchedGeometryEffect(
				id: SegmentedToggleMetrics.activeSelectionIdentifier,
				in: selectionNamespace
			)
			.scaleEffect(isScrubbingOptions ? SegmentedToggleMetrics.activePillScaleWhileDragging : 1.0)
	}

	private var modeScrubGesture: some Gesture {
		DragGesture(minimumDistance: SegmentedToggleMetrics.dragActivationDistance)
			.onChanged { dragValue in
				beginScrubbingIfNeeded()
				guard
					let targetOption = resolvedModeSwitchOption(
						atHorizontalOffset: dragValue.location.x,
						totalBarWidth: barWidth
					)
				else { return }
				selectOption(targetOption)
			}
			.onEnded { _ in
				withAnimation(.bouncy) {
					isScrubbingOptions = false
				}
			}
	}

	private func beginScrubbingIfNeeded() {
		guard !isScrubbingOptions else { return }
		withAnimation(.bouncy) {
			isScrubbingOptions = true
		}
	}

	private func selectOption(_ option: ModeSwitchOption) {
		guard selectedOption != option else { return }
		withAnimation(.bouncy) {
			selectedOption = option
		}
	}
}
