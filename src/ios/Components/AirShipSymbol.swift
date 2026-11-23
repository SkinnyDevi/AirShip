import SwiftUI

public enum AirShipSymbol {
	public static let blimpName = "airship"

	public static var blimpImage: Image {
		Image(blimpName, bundle: .module)
	}
}
