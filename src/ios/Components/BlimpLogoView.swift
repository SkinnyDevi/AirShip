import SwiftUI

private enum BlimpLogoMetrics {
	static let glyphScaleFactor: CGFloat = 0.62
}

public struct BlimpLogoView: View {
	public let size: CGFloat

	public init(size: CGFloat = 120.0) {
		self.size = size
	}

	public var body: some View {
		AirShipSymbol.blimpImage
			.resizable()
			.scaledToFit()
			.frame(
				width: size * BlimpLogoMetrics.glyphScaleFactor,
				height: size * BlimpLogoMetrics.glyphScaleFactor
			)
			.foregroundStyle(AirShipTheme.accentCyan)
			.frame(width: size, height: size)
			.glassEffect(.regular, in: .circle)
			.accessibilityLabel("AirShip Blimp Logo")
	}
}
