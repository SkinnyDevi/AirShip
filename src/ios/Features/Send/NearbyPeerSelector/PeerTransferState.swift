public enum PeerTransferState: Equatable, Sendable {
	case ready
	case sending
	case completed
	case failed(String)
}
