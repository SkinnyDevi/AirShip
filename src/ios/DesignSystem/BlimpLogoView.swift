import SwiftUI

public struct BlimpLogoView: View {
    public let size: CGFloat

    public init(size: CGFloat = 120.0) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(AirShipTheme.secondaryCardBackground)
                .frame(width: size, height: size)

            Image(systemName: "airplane.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.65, height: size * 0.65)
                .foregroundStyle(AirShipTheme.accentCyan)
        }
        .accessibilityLabel("AirShip Blimp Logo")
    }
}
