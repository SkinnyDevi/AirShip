import Combine
import Foundation

// -----------------------------------------------------------------------------
// 1. Domain Models & Screen States
// -----------------------------------------------------------------------------

public struct ReceivedPackageItem: Identifiable, Equatable, Sendable {
	public let id: String
	public let name: String
	public let byteSize: Int64
	public let mimeType: String
	public let isTextSnippet: Bool
	public var textContent: String?
	public var localFileURL: URL?
	public var isDownloaded: Bool

	public init(
		id: String,
		name: String,
		byteSize: Int64,
		mimeType: String = "application/octet-stream",
		isTextSnippet: Bool = false,
		textContent: String? = nil,
		localFileURL: URL? = nil,
		isDownloaded: Bool = false
	) {
		self.id = id
		self.name = name
		self.byteSize = byteSize
		self.mimeType = mimeType
		self.isTextSnippet = isTextSnippet
		self.textContent = textContent
		self.localFileURL = localFileURL
		self.isDownloaded = isDownloaded
	}
}

public enum ReceiveScreenState: Equatable {
	case waiting
	case packageReceived(items: [ReceivedPackageItem])
	case downloading
	case completed
}

private func mapOfferItems(_ offer: IncomingPackageOffer) -> [ReceivedPackageItem] {
	return offer.items.map { item in
		ReceivedPackageItem(
			id: item.id,
			name: item.name,
			byteSize: item.byteSize,
			mimeType: item.mimeType,
			isTextSnippet: item.isTextSnippet,
			textContent: nil,
			localFileURL: nil,
			isDownloaded: false
		)
	}
}

private func resolvedDownloadFraction(from update: TransferProgressUpdate) -> Double? {
	guard case .transferring(let completedBytes, let totalBytes) = update.phase,
		totalBytes > 0
	else {
		return nil
	}
	return min(max(Double(completedBytes) / Double(totalBytes), 0.0), 1.0)
}

// -----------------------------------------------------------------------------
// 2. Receive ViewModel
// -----------------------------------------------------------------------------

@MainActor
public final class ReceiveViewModel: ObservableObject {
	@Published public private(set) var screenState: ReceiveScreenState = .waiting
	@Published public private(set) var localDisplayAlias: String
	@Published public private(set) var localUserNameId: String
	@Published public private(set) var senderAlias: String?
	@Published public private(set) var downloadProgressFraction: Double?
	@Published public private(set) var savedItems: [ReceivedPackageItem] = []
	@Published public private(set) var errorMessage: String?

	private let coreBridge: AirShipCoreBridgeProtocol
	private var activePackageId: String?

	public init(coreBridge: AirShipCoreBridgeProtocol) {
		self.coreBridge = coreBridge
		self.localDisplayAlias = coreBridge.getLocalDisplayAlias()
		self.localUserNameId = coreBridge.getLocalUserNameId()
	}

	public func refreshIdentity() {
		localDisplayAlias = coreBridge.getLocalDisplayAlias()
		localUserNameId = coreBridge.getLocalUserNameId()
	}

	public func startListeningForIncomingPackages() async {
		let offerStream = coreBridge.observeIncomingPackages()
		for await offer in offerStream {
			applyIncomingOffer(offer)
		}
	}

	public func simulateIncomingPackage(items: [ReceivedPackageItem]) {
		activePackageId = nil
		senderAlias = nil
		savedItems = []
		screenState = .packageReceived(items: items)
	}

	public func downloadSingleItem(id: String) {
		guard case .packageReceived(var currentItems) = screenState else { return }
		if activePackageId == nil {
			if let targetIndex = currentItems.firstIndex(where: { $0.id == id }) {
				currentItems[targetIndex].isDownloaded = true
				screenState = .packageReceived(items: currentItems)
			}
			return
		}
		Task { await performDownloadSingleItem(id: id) }
	}

	public func downloadAllItems() {
		guard case .packageReceived(var currentItems) = screenState else { return }
		if activePackageId == nil {
			for index in currentItems.indices {
				currentItems[index].isDownloaded = true
			}
			savedItems = currentItems
			screenState = .completed
			return
		}
		Task { await performDownloadAllItems() }
	}

	public func performDownloadSingleItem(id: String) async {
		guard let packageId = activePackageId,
			case .packageReceived(let currentItems) = screenState
		else {
			return
		}
		do {
			let results = try await downloadItemsWithProgress(packageId: packageId, itemIds: [id])
			let updatedItems = applyDownloadResults(results, to: currentItems)
			let allDownloaded = updatedItems.allSatisfy { $0.isDownloaded }
			savedItems = updatedItems.filter { $0.isDownloaded }
			screenState = allDownloaded ? .completed : .packageReceived(items: updatedItems)
		} catch {
			reportError(error)
			screenState = .packageReceived(items: currentItems)
		}
	}

	public func performDownloadAllItems() async {
		guard let packageId = activePackageId,
			case .packageReceived(let currentItems) = screenState
		else {
			return
		}
		let pendingIds = currentItems.filter { !$0.isDownloaded }.map(\.id)
		guard !pendingIds.isEmpty else {
			savedItems = currentItems
			screenState = .completed
			return
		}

		screenState = .downloading
		do {
			let results = try await downloadItemsWithProgress(packageId: packageId, itemIds: pendingIds)
			let updatedItems = applyDownloadResults(results, to: currentItems)
			savedItems = updatedItems
			screenState = .completed
		} catch {
			reportError(error)
			screenState = .packageReceived(items: currentItems)
		}
	}

	public func declineIncomingPackage() async {
		if let packageId = activePackageId {
			await coreBridge.rejectIncomingPackage(packageId: packageId, reason: "Declined by recipient")
		}
		clearActivePackageState()
	}

	public func resetToWaiting() {
		if let packageId = activePackageId, screenState != .completed {
			Task { await coreBridge.finishIncomingPackage(packageId: packageId) }
		}
		clearActivePackageState()
	}

	public func dismissError() {
		errorMessage = nil
	}

	private func applyIncomingOffer(_ offer: IncomingPackageOffer) {
		activePackageId = offer.id
		senderAlias = offer.senderAlias
		savedItems = []
		downloadProgressFraction = nil
		screenState = .packageReceived(items: mapOfferItems(offer))
	}

	private func downloadItemsWithProgress(
		packageId: String,
		itemIds: [String]
	) async throws -> [DownloadedItemResult] {
		downloadProgressFraction = 0.0
		return try await coreBridge.downloadIncomingItems(
			packageId: packageId,
			itemIds: itemIds
		) { [weak self] update in
			Task { @MainActor [weak self] in
				if let fraction = resolvedDownloadFraction(from: update) {
					self?.downloadProgressFraction = fraction
				}
			}
		}
	}

	private func applyDownloadResults(
		_ results: [DownloadedItemResult],
		to items: [ReceivedPackageItem]
	) -> [ReceivedPackageItem] {
		let resultsById = Dictionary(uniqueKeysWithValues: results.map { ($0.itemId, $0) })
		return items.map { existingItem in
			guard let matched = resultsById[existingItem.id] else {
				return existingItem
			}
			var updated = existingItem
			updated.isDownloaded = true
			updated.localFileURL = matched.savedFileURL
			if let text = matched.textContent {
				updated.textContent = text
			}
			return updated
		}
	}

	private func clearActivePackageState() {
		activePackageId = nil
		senderAlias = nil
		savedItems = []
		downloadProgressFraction = nil
		screenState = .waiting
	}

	private func reportError(_ error: Error) {
		if let localizedError = error as? LocalizedError,
			let description = localizedError.errorDescription
		{
			errorMessage = description
			return
		}
		errorMessage = error.localizedDescription
	}
}
