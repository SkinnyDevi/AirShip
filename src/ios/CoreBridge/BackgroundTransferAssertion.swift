import Foundation

#if canImport(UIKit)
	import UIKit
#endif

/// Token representing an active background task, which can be used to end the task when it is no longer needed.
public struct BackgroundTaskToken: Sendable, Equatable {
	public let rawIdentifier: Int

	public init(rawIdentifier: Int) {
		self.rawIdentifier = rawIdentifier
	}
}

/// Protocol defining the interface for asserting background tasks, which allows the application to
/// request additional time to complete work when the app is in the background.
public protocol BackgroundTaskAsserting: Sendable {
	/// Begins a background task with the given name.
	func begin(name: String) async -> BackgroundTaskToken
	/// Ends the background task with the given token.
	func end(_ token: BackgroundTaskToken) async
}

/// The default implementation of `BackgroundTaskAsserting` for iOS, which uses `UIApplication` to manage background tasks.
public final class BackgroundTransferAssertion: BackgroundTaskAsserting, @unchecked Sendable {
	public init() {}

	public func begin(name: String) async -> BackgroundTaskToken {
		#if canImport(UIKit)
			return await MainActor.run {
				let taskId = UIApplication.shared.beginBackgroundTask(withName: name) {
					// Expiration handled cleanly by system; active sockets will close if OS suspends.
				}
				return BackgroundTaskToken(rawIdentifier: taskId.rawValue)
			}
		#else
			return BackgroundTaskToken(rawIdentifier: 0)
		#endif
	}

	public func end(_ token: BackgroundTaskToken) async {
		#if canImport(UIKit)
			await MainActor.run {
				let taskId = UIBackgroundTaskIdentifier(rawValue: token.rawIdentifier)
				guard taskId != .invalid else { return }
				UIApplication.shared.endBackgroundTask(taskId)
			}
		#endif
	}
}
