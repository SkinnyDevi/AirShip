import Foundation
import Network

public protocol FramedByteChannel: Sendable {
	func readFrame() async throws -> WireFrame
	func writeFrame(_ frame: WireFrame) async throws
	func close() async
}

private final class OneShotFlag: @unchecked Sendable {
	private let lock = NSLock()
	private var completed = false

	func tryClaim() -> Bool {
		lock.withLock {
			guard !completed else { return false }
			completed = true
			return true
		}
	}
}

public enum ChannelConstants {
	public static let defaultConnectTimeoutSeconds: Double = 15.0
}

public actor NetworkFramedChannel: FramedByteChannel {
	private let connection: NWConnection
	private let connectionQueue: DispatchQueue
	private var isClosed = false

	public init(connection: NWConnection, queueLabel: String = "com.skdvcsm.airship.channel") {
		self.connection = connection
		self.connectionQueue = DispatchQueue(label: queueLabel)
	}

	public init(endpoint: NWEndpoint, parameters: NWParameters = makeAirShipTcpParameters()) {
		let queue = DispatchQueue(label: "com.skdvcsm.airship.outbound.\(UUID().uuidString)")
		self.connection = NWConnection(to: endpoint, using: parameters)
		self.connectionQueue = queue
	}

	public func connectAndAwaitReady(
		timeoutSeconds: Double = ChannelConstants.defaultConnectTimeoutSeconds
	) async throws {
		guard !isClosed else {
			throw CoreBridgeError.transferCancelled
		}

		let completionGate = OneShotFlag()
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			scheduleConnectionTimeout(
				seconds: timeoutSeconds,
				gate: completionGate,
				continuation: continuation
			)
			attachReadyStateHandler(gate: completionGate, continuation: continuation)
			connection.start(queue: connectionQueue)
		}
		connection.stateUpdateHandler = nil
	}

	public func readFrame() async throws -> WireFrame {
		let headerBytes = try await readExactBytes(count: TransferProtocolConstants.headerByteLength)
		let (frameType, payloadLength) = try WireFrame.decodeHeader(headerBytes)
		if payloadLength == 0 {
			return try WireFrame(frameType: frameType, payloadBytes: Data())
		}
		let payloadBytes = try await readExactBytes(count: Int(payloadLength))
		return try WireFrame(frameType: frameType, payloadBytes: payloadBytes)
	}

	public func writeFrame(_ frame: WireFrame) async throws {
		guard !isClosed else {
			throw CoreBridgeError.transferCancelled
		}
		let encodedPacket = try frame.encodeHeaderAndPayload()
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			connection.send(
				content: encodedPacket,
				completion: .contentProcessed { sendError in
					if let sendError {
						continuation.resume(
							throwing: CoreBridgeError.transferFailed(sendError.localizedDescription)
						)
						return
					}
					continuation.resume()
				}
			)
		}
	}

	public func close() async {
		guard !isClosed else { return }
		isClosed = true
		connection.stateUpdateHandler = nil
		connection.cancel()
	}

	private func scheduleConnectionTimeout(
		seconds: Double,
		gate: OneShotFlag,
		continuation: CheckedContinuation<Void, Error>
	) {
		connectionQueue.asyncAfter(deadline: .now() + seconds) { [weak connection] in
			guard gate.tryClaim() else { return }
			connection?.cancel()
			continuation.resume(
				throwing: CoreBridgeError.transferFailed("Connection timed out")
			)
		}
	}

	private func attachReadyStateHandler(
		gate: OneShotFlag,
		continuation: CheckedContinuation<Void, Error>
	) {
		connection.stateUpdateHandler = { [weak connection] newState in
			switch newState {
			case .ready:
				guard gate.tryClaim() else { return }
				continuation.resume()
			case .failed(let networkError):
				guard gate.tryClaim() else { return }
				connection?.cancel()
				continuation.resume(
					throwing: CoreBridgeError.transferFailed(networkError.localizedDescription)
				)
			case .cancelled:
				guard gate.tryClaim() else { return }
				continuation.resume(throwing: CoreBridgeError.transferCancelled)
			default:
				break
			}
		}
	}

	private func readExactBytes(count requestedCount: Int) async throws -> Data {
		var collectedBytes = Data(capacity: requestedCount)
		while collectedBytes.count < requestedCount {
			let remainingCount = requestedCount - collectedBytes.count
			let chunk = try await receiveChunk(maximumLength: remainingCount)
			guard !chunk.isEmpty else {
				throw CoreBridgeError.transferFailed("Connection closed unexpectedly")
			}
			collectedBytes.append(chunk)
		}
		return collectedBytes
	}

	private func receiveChunk(maximumLength: Int) async throws -> Data {
		guard !isClosed else {
			throw CoreBridgeError.transferCancelled
		}
		return try await withCheckedThrowingContinuation {
			(continuation: CheckedContinuation<Data, Error>) in
			connection.receive(
				minimumIncompleteLength: 1,
				maximumLength: maximumLength
			) { receivedBytes, _, isComplete, receiveError in
				if let receiveError {
					continuation.resume(
						throwing: CoreBridgeError.transferFailed(receiveError.localizedDescription)
					)
					return
				}
				if let receivedBytes, !receivedBytes.isEmpty {
					continuation.resume(returning: receivedBytes)
					return
				}
				if isComplete {
					continuation.resume(returning: Data())
					return
				}
				continuation.resume(
					throwing: CoreBridgeError.transferFailed("Empty socket read before EOF")
				)
			}
		}
	}
}
