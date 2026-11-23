import SwiftUI

public enum NavigationTabIcon: Equatable, Sendable {
	case customSymbol(String)
	case systemSymbol(String)
}

public enum NavigationTab: String, CaseIterable, Identifiable {
	case transfer = "Transfer"
	case trustList = "Users"
	case settings = "Settings"

	public var id: String { rawValue }

	public var icon: NavigationTabIcon {
		switch self {
		case .transfer:
			return .customSymbol(AirShipSymbol.blimpName)
		case .trustList:
			return .systemSymbol("person.2.fill")
		case .settings:
			return .systemSymbol("gearshape.fill")
		}
	}

	public var iconImage: Image {
		switch icon {
		case .customSymbol(let symbolName):
			return Image(symbolName, bundle: .module)
		case .systemSymbol(let symbolName):
			return Image(systemName: symbolName)
		}
	}
}

private enum FloatingBottomBarMetrics {
	static let glassContainerSpacing: CGFloat = 24
	static let buttonRowSpacing: CGFloat = 24
	static let maxBarWidth: CGFloat = 480
	static let barInnerPadding: CGFloat = 6
	static let buttonHorizontalPadding: CGFloat = 24
	static let buttonVerticalPadding: CGFloat = 8
	static let iconFontSize: CGFloat = 20
	static let iconLabelSpacing: CGFloat = 3
	static let dragActivationDistance: CGFloat = 8
	static let activePillScaleWhileDragging: CGFloat = 1.06
	static let activePillHighlightOpacity: Double = 0.16
	static let activeSelectionIdentifier = "activeNavigationTabSelection"
}

internal func resolvedNavigationTab(
	atHorizontalOffset horizontalOffset: CGFloat,
	totalBarWidth: CGFloat
) -> NavigationTab? {
	let availableTabs = NavigationTab.allCases
	guard totalBarWidth > 0, !availableTabs.isEmpty else { return nil }

	let normalizedPosition = min(max(horizontalOffset / totalBarWidth, 0), 0.999)
	let targetIndex = Int(normalizedPosition * CGFloat(availableTabs.count))
	guard availableTabs.indices.contains(targetIndex) else { return nil }

	return availableTabs[targetIndex]
}

public struct FloatingBottomBar: View {
	@Binding public var activeTab: NavigationTab
	@Namespace private var selectionNamespace
	@State private var barWidth: CGFloat = 0
	@State private var isScrubbingTabs = false

	public init(activeTab: Binding<NavigationTab>) {
		self._activeTab = activeTab
	}

	public var body: some View {
		GlassEffectContainer(spacing: FloatingBottomBarMetrics.glassContainerSpacing) {
			HStack(spacing: FloatingBottomBarMetrics.buttonRowSpacing) {
				ForEach(NavigationTab.allCases, content: tabButton)
			}
			.frame(maxWidth: FloatingBottomBarMetrics.maxBarWidth)
			.padding(FloatingBottomBarMetrics.barInnerPadding)
			.glassEffect(.regular.interactive(), in: .capsule)
			.onGeometryChange(for: CGFloat.self) { geometryProxy in
				geometryProxy.size.width
			} action: { updatedWidth in
				barWidth = updatedWidth
			}
			.simultaneousGesture(tabScrubGesture)
		}
	}

	private func tabButton(for tab: NavigationTab) -> some View {
		let isSelected = activeTab == tab
		return Button {
			selectTab(tab)
		} label: {
			tabButtonLabel(for: tab, isSelected: isSelected)
		}
		.buttonStyle(.plain)
	}

	private func tabButtonLabel(for tab: NavigationTab, isSelected: Bool) -> some View {
		VStack(spacing: FloatingBottomBarMetrics.iconLabelSpacing) {
			tab.iconImage
				.font(.system(size: FloatingBottomBarMetrics.iconFontSize, weight: .semibold))
			Text(tab.rawValue)
				.font(.caption2.weight(isSelected ? .semibold : .medium))
		}
		.foregroundStyle(isSelected ? AirShipTheme.textPrimary : AirShipTheme.textSecondary)
		.frame(maxWidth: .infinity)
		.padding(.horizontal, FloatingBottomBarMetrics.buttonHorizontalPadding)
		.padding(.vertical, FloatingBottomBarMetrics.buttonVerticalPadding)
		.background {
			if isSelected {
				activeSelectionPill
			}
		}
		.contentShape(Capsule())
	}

	private var activeSelectionPill: some View {
		Capsule()
			.fill(Color.white.opacity(FloatingBottomBarMetrics.activePillHighlightOpacity))
			.matchedGeometryEffect(
				id: FloatingBottomBarMetrics.activeSelectionIdentifier,
				in: selectionNamespace
			)
			.scaleEffect(isScrubbingTabs ? FloatingBottomBarMetrics.activePillScaleWhileDragging : 1.0)
	}

	private var tabScrubGesture: some Gesture {
		DragGesture(minimumDistance: FloatingBottomBarMetrics.dragActivationDistance)
			.onChanged { dragValue in
				beginScrubbingIfNeeded()
				guard
					let targetTab = resolvedNavigationTab(
						atHorizontalOffset: dragValue.location.x,
						totalBarWidth: barWidth
					)
				else { return }
				selectTab(targetTab)
			}
			.onEnded { _ in
				withAnimation(.bouncy) {
					isScrubbingTabs = false
				}
			}
	}

	private func beginScrubbingIfNeeded() {
		guard !isScrubbingTabs else { return }
		withAnimation(.bouncy) {
			isScrubbingTabs = true
		}
	}

	private func selectTab(_ tab: NavigationTab) {
		guard activeTab != tab else { return }
		withAnimation(.bouncy) {
			activeTab = tab
		}
	}
}
