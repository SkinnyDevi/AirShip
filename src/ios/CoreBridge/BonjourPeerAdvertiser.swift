import Foundation
import Network

/// Protocol defining the interface for a Bonjour peer advertiser, which is responsible for
/// advertising the local device identity over Bonjour and handling incoming connections.
public protocol PeerAdvertiserProtocol: Sendable {
	/// Starts advertising the local device identity over Bonjour, and listens for incoming connections.
	/// The provided callbacks are invoked on the main actor.
	func startAdvertising(
		identity: LocalDeviceIdentity,
		onIncomingChannel: @escaping @Sendable (any FramedByteChannel) -> Void,
		onStatusChange: @escaping @Sendable (String) -> Void
	) async throws
	func stopAdvertising() async
	func currentListeningPort() async -> UInt16?
}

private func buildTxtRecord(for identity: LocalDeviceIdentity) -> NWTXTRecord {
	var txtRecord = NWTXTRecord()
	txtRecord[TransferProtocolConstants.txtPeerIdKey] = identity.userNameId
	txtRecord[TransferProtocolConstants.txtAliasKey] = identity.displayAlias
	txtRecord[TransferProtocolConstants.txtFingerprintKey] = identity.fingerprintHex
	txtRecord[TransferProtocolConstants.txtVersionKey] = TransferProtocolConstants.protocolVersion
	return txtRecord
}

public actor BonjourPeerAdvertiser: PeerAdvertiserProtocol {
	private let listenerQueue = DispatchQueue(label: "com.skdvcsm.airship.bonjour.listener")
	private var activeListener: NWListener?

	public init() {}

	public func startAdvertising(
		identity: LocalDeviceIdentity,
		onIncomingChannel: @escaping @Sendable (any FramedByteChannel) -> Void,
		onStatusChange: @escaping @Sendable (String) -> Void
	) async throws {
		await stopAdvertising()

		let listener = try NWListener(using: makeAirShipTcpParameters())
		let txtRecord = buildTxtRecord(for: identity)
		listener.service = NWListener.Service(
			name: identity.userNameId,
			type: TransferProtocolConstants.bonjourServiceType,
			domain: nil,
			txtRecord: txtRecord
		)
		configureHandlers(
			on: listener,
			onIncomingChannel: onIncomingChannel,
			onStatusChange: onStatusChange
		)
		activeListener = listener
		listener.start(queue: listenerQueue)
	}

	public func stopAdvertising() async {
		guard let listener = activeListener else { return }
		activeListener = nil
		listener.stateUpdateHandler = nil
		listener.newConnectionHandler = nil
		listener.cancel()
	}

	public func currentListeningPort() async -> UInt16? {
		return activeListener?.port?.rawValue
	}

	private func configureHandlers(
		on listener: NWListener,
		onIncomingChannel: @escaping @Sendable (any FramedByteChannel) -> Void,
		onStatusChange: @escaping @Sendable (String) -> Void
	) {
		listener.stateUpdateHandler = { newState in
			let statusText = Self.describeListenerState(newState)
			onStatusChange(statusText)
		}
		listener.newConnectionHandler = { incomingConnection in
			Task {
				let channel = NetworkFramedChannel(
					connection: incomingConnection,
					queueLabel: "com.skdvcsm.airship.inbound.\(UUID().uuidString)"
				)
				do {
					try await channel.connectAndAwaitReady()
					onIncomingChannel(channel)
				} catch {
					await channel.close()
				}
			}
		}
	}

	private static func describeListenerState(_ state: NWListener.State) -> String {
		switch state {
		case .ready:
			return "Wi-Fi LAN Active"
		case .waiting:
			return "Waiting for Local Network Permission"
		case .failed(let networkError):
			return "Listener Error: \(networkError.localizedDescription)"
		case .cancelled:
			return "Stopped"
		default:
			return "Starting Local Network..."
		}
	}
}
