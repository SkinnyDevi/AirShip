public enum SendTransferState: Equatable {
	case empty
	case staged
	case sending
	case completed
	case failed(String)
}
