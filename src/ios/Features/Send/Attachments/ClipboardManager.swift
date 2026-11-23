import Foundation
import SwiftUI

#if canImport(UIKit)
	import UIKit
#elseif canImport(AppKit)
	import AppKit
#endif

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
