import UniformTypeIdentifiers
import XCTest

@testable import AirShipKit

// -----------------------------------------------------------------------------
// 1. Test Doubles
// -----------------------------------------------------------------------------

private struct StubCameraAccessAuthorizer: CameraAccessAuthorizing {
	let result: CameraAuthorizationResult

	func requestCameraAccess() async -> CameraAuthorizationResult {
		return result
	}
}

// -----------------------------------------------------------------------------
// 2. ViewModel & Attachment Tests
// -----------------------------------------------------------------------------

@MainActor
final class AirShipViewModelTests: XCTestCase {
	private func makeMockBridge() -> MockCoreBridge {
		MockCoreBridge(
			localUserNameId: "TEST_USER_ID",
			localFingerprint: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
			initialPeers: [
				PeerBridgeModel(
					id: "USER_PEER_1",
					displayAlias: "Alice Phone",
					fingerprintHex: String(repeating: "1", count: 64),
					isTrusted: false
				)
			]
		)
	}

	private func makeTemporaryDirectory(prefix: String) throws -> URL {
		let directoryURL = FileManager.default.temporaryDirectory
			.appendingPathComponent("\(prefix)_\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
		addTeardownBlock {
			try? FileManager.default.removeItem(at: directoryURL)
		}
		return directoryURL
	}

	// -------------------------------------------------------------------------
	// Attachment Helpers
	// -------------------------------------------------------------------------

	func testAttachmentPureHelpers() {
		XCTAssertFalse(formattedByteSize(0).isEmpty)
		XCTAssertEqual(
			resolvedMimeType(forFileExtension: "pdf", fallbackContentType: nil),
			"application/pdf"
		)
		XCTAssertEqual(
			resolvedMimeType(forFileExtension: "unknown_ext_xyz", fallbackContentType: .png),
			"image/png"
		)
		XCTAssertEqual(
			resolvedMimeType(forFileExtension: "unknown_ext_xyz", fallbackContentType: nil),
			AttachmentMimeTypes.octetStream
		)
		XCTAssertEqual(
			resolvedTextAttachmentTitle(from: "\n   First Line Title   \nSecond line"),
			"First Line Title"
		)
		XCTAssertEqual(
			resolvedTextAttachmentTitle(from: "   \n  "),
			AttachmentConstants.defaultTextTitle
		)
		let longLine = String(repeating: "A", count: 55)
		XCTAssertEqual(resolvedTextAttachmentTitle(from: longLine).count, 41)

		let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
		XCTAssertEqual(
			generatedMediaFilename(prefix: "Camera", fileExtension: "jpg", timestamp: referenceDate),
			"Camera_20231114_221320.jpg"
		)
	}

	// -------------------------------------------------------------------------
	// Local Attachment Staging Service
	// -------------------------------------------------------------------------

	func testLocalStagingServiceCopiesAndCleansFiles() throws {
		let sourceDirectory = try makeTemporaryDirectory(prefix: "AirShipSource")
		let stagingDirectory = try makeTemporaryDirectory(prefix: "AirShipStaging")
		let stagingService = LocalAttachmentStagingService(stagingDirectoryURL: stagingDirectory)

		let pdfSourceURL = sourceDirectory.appendingPathComponent("Report.pdf")
		let pdfPayload = Data("PDF-TEST-PAYLOAD".utf8)
		try pdfPayload.write(to: pdfSourceURL)

		let stagedPdf = try stagingService.stageFileCopy(
			from: pdfSourceURL,
			sourceKind: .documentFile,
			fallbackContentType: nil
		)
		XCTAssertEqual(stagedPdf.name, "Report.pdf")
		XCTAssertEqual(stagedPdf.byteSize, Int64(pdfPayload.count))
		XCTAssertEqual(stagedPdf.mimeType, "application/pdf")
		XCTAssertEqual(stagedPdf.sourceKind, .documentFile)

		guard case .fileReference(let stagedURL) = stagedPdf.content else {
			XCTFail("Expected fileReference content for staged PDF")
			return
		}
		XCTAssertTrue(FileManager.default.fileExists(atPath: stagedURL.path))

		stagingService.removeStagedContent(for: stagedPdf)
		XCTAssertFalse(FileManager.default.fileExists(atPath: stagedURL.path))
		XCTAssertTrue(FileManager.default.fileExists(atPath: pdfSourceURL.path))
	}

	func testLocalStagingServiceStagesCameraMediaAndText() throws {
		let stagingDirectory = try makeTemporaryDirectory(prefix: "AirShipStaging")
		let stagingService = LocalAttachmentStagingService(stagingDirectoryURL: stagingDirectory)

		let jpegBytes = Data([0xFF, 0xD8, 0xFF, 0xE0])
		let stagedCamera = try stagingService.stageEncodedMedia(
			encodedBytes: jpegBytes,
			filename: "Camera_20261123_120000.jpg",
			mimeType: AttachmentMimeTypes.jpeg,
			sourceKind: .cameraCapture
		)
		XCTAssertEqual(stagedCamera.sourceKind, .cameraCapture)
		XCTAssertEqual(stagedCamera.byteSize, Int64(jpegBytes.count))
		XCTAssertEqual(stagedCamera.mimeType, AttachmentMimeTypes.jpeg)

		let stagedText = try stagingService.stageTextSnippet("Hello AirShip\nSecond line")
		XCTAssertEqual(stagedText.name, "Hello AirShip")
		XCTAssertEqual(stagedText.sourceKind, .textSnippet)
		XCTAssertEqual(stagedText.content, .textPayload("Hello AirShip\nSecond line"))
		XCTAssertEqual(stagedText.byteSize, Int64("Hello AirShip\nSecond line".utf8.count))

		XCTAssertThrowsError(try stagingService.stageTextSnippet("   \n\t ")) { thrownError in
			XCTAssertEqual(thrownError as? AttachmentStagingError, .emptyTextSnippet)
		}
	}

	// -------------------------------------------------------------------------
	// Send ViewModel: Empty -> Staged -> Sending -> Completed
	// -------------------------------------------------------------------------

	func testSendWorkflowTransitions() async {
		let viewModel = SendViewModel(coreBridge: makeMockBridge())
		XCTAssertEqual(viewModel.transferState, .empty)
		XCTAssertTrue(viewModel.stagedItems.isEmpty)

		viewModel.addPhotoAttachment(name: "Photo.png", size: 1024)
		XCTAssertEqual(viewModel.transferState, .staged)
		XCTAssertEqual(viewModel.stagedItems.count, 1)

		await viewModel.dispatchPackage(to: "USER_PEER_1")
		XCTAssertEqual(viewModel.transferState, .completed)

		viewModel.removeItem(id: viewModel.stagedItems[0].id)
		XCTAssertEqual(viewModel.transferState, .empty)
		XCTAssertTrue(viewModel.stagedItems.isEmpty)
	}

	// -------------------------------------------------------------------------
	// Send ViewModel: File Importer, Camera Capture & Text Sources
	// -------------------------------------------------------------------------

	func testSendViewModelFileImporterSuccessAndFailure() throws {
		let sourceDirectory = try makeTemporaryDirectory(prefix: "AirShipFiles")
		let stagingDirectory = try makeTemporaryDirectory(prefix: "AirShipFileStage")
		let stagingService = LocalAttachmentStagingService(stagingDirectoryURL: stagingDirectory)
		let viewModel = SendViewModel(
			coreBridge: makeMockBridge(),
			stagingService: stagingService,
			cameraAuthorizer: StubCameraAccessAuthorizer(result: .authorized)
		)

		let firstFileURL = sourceDirectory.appendingPathComponent("Notes.txt")
		let secondFileURL = sourceDirectory.appendingPathComponent("Image.png")
		try Data("Sample text".utf8).write(to: firstFileURL)
		try Data([0x89, 0x50, 0x4E, 0x47]).write(to: secondFileURL)

		viewModel.handleFileImporterResult(.success([firstFileURL, secondFileURL]))
		XCTAssertEqual(viewModel.stagedItems.count, 2)
		XCTAssertEqual(viewModel.transferState, .staged)
		XCTAssertNil(viewModel.attachmentErrorMessage)

		viewModel.handleFileImporterResult(
			.failure(NSError(domain: "AirShipTest", code: 42))
		)
		XCTAssertNotNil(viewModel.attachmentErrorMessage)
		XCTAssertEqual(viewModel.stagedItems.count, 2)

		viewModel.dismissAttachmentError()
		XCTAssertNil(viewModel.attachmentErrorMessage)

		for itemIdentifier in viewModel.stagedItems.map(\.id) {
			viewModel.removeItem(id: itemIdentifier)
		}
		XCTAssertEqual(viewModel.transferState, .empty)
		XCTAssertTrue(viewModel.stagedItems.isEmpty)
	}

	func testSendViewModelCameraAuthorizationAndCapture() async throws {
		let stagingDirectory = try makeTemporaryDirectory(prefix: "AirShipCamStage")
		let stagingService = LocalAttachmentStagingService(stagingDirectoryURL: stagingDirectory)

		let authorizedViewModel = SendViewModel(
			coreBridge: makeMockBridge(),
			stagingService: stagingService,
			cameraAuthorizer: StubCameraAccessAuthorizer(result: .authorized)
		)
		let canOpenCamera = await authorizedViewModel.prepareCameraCapture()
		XCTAssertTrue(canOpenCamera)
		XCTAssertNil(authorizedViewModel.attachmentErrorMessage)

		let sampleJpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
		authorizedViewModel.stageCapturedCameraImage(
			jpegBytes: sampleJpeg,
			capturedAt: Date(timeIntervalSince1970: 1_700_000_000)
		)
		XCTAssertEqual(authorizedViewModel.stagedItems.count, 1)
		XCTAssertEqual(authorizedViewModel.stagedItems[0].sourceKind, .cameraCapture)
		XCTAssertEqual(authorizedViewModel.stagedItems[0].name, "Camera_20231114_221320.jpg")

		let deniedViewModel = SendViewModel(
			coreBridge: makeMockBridge(),
			stagingService: stagingService,
			cameraAuthorizer: StubCameraAccessAuthorizer(result: .denied)
		)
		let deniedResult = await deniedViewModel.prepareCameraCapture()
		XCTAssertFalse(deniedResult)
		XCTAssertEqual(
			deniedViewModel.attachmentErrorMessage,
			AttachmentStagingError.cameraPermissionDenied.errorDescription
		)
	}

	func testSendViewModelTextAttachmentValidation() throws {
		let stagingDirectory = try makeTemporaryDirectory(prefix: "AirShipTextStage")
		let stagingService = LocalAttachmentStagingService(stagingDirectoryURL: stagingDirectory)
		let viewModel = SendViewModel(
			coreBridge: makeMockBridge(),
			stagingService: stagingService
		)

		viewModel.addTextAttachment(textSnippet: "   ")
		XCTAssertTrue(viewModel.stagedItems.isEmpty)
		XCTAssertEqual(
			viewModel.attachmentErrorMessage,
			AttachmentStagingError.emptyTextSnippet.errorDescription
		)

		viewModel.dismissAttachmentError()
		viewModel.addTextAttachment(textSnippet: "Meeting Link\nhttps://example.com")
		XCTAssertEqual(viewModel.stagedItems.count, 1)
		XCTAssertEqual(viewModel.stagedItems[0].sourceKind, .textSnippet)
		XCTAssertEqual(
			viewModel.stagedItems[0].content,
			.textPayload("Meeting Link\nhttps://example.com")
		)
	}

	func testNearbyPeerSelectorViewModelDiscoveryDispatchAndCleanup() async throws {
		let stagingDirectory = try makeTemporaryDirectory(prefix: "AirShipDispatchStage")
		let stagingService = LocalAttachmentStagingService(stagingDirectoryURL: stagingDirectory)
		let sendViewModel = SendViewModel(
			coreBridge: makeMockBridge(),
			stagingService: stagingService
		)

		XCTAssertFalse(sendViewModel.canSendPackage)

		sendViewModel.stageCapturedCameraImage(jpegBytes: Data([0xFF, 0xD8, 0xFF, 0xD9]))
		sendViewModel.addTextAttachment(textSnippet: "Hello")
		XCTAssertTrue(sendViewModel.canSendPackage)

		guard case .fileReference(let stagedFileURL) = sendViewModel.stagedItems[0].content else {
			XCTFail("Expected fileReference for staged camera photo")
			return
		}
		XCTAssertTrue(FileManager.default.fileExists(atPath: stagedFileURL.path))

		let selectorViewModel = sendViewModel.makePeerSelectorViewModel()
		XCTAssertEqual(selectorViewModel.stagedItems.count, 2)
		XCTAssertEqual(selectorViewModel.totalStagedByteSize, 9)
		XCTAssertEqual(selectorViewModel.transferState, .ready)

		await selectorViewModel.loadNearbyPeers()
		XCTAssertEqual(selectorViewModel.nearbyPeers.count, 1)
		XCTAssertEqual(selectorViewModel.nearbyPeers[0].id, "USER_PEER_1")

		await selectorViewModel.dispatchPackage(to: "USER_PEER_1")
		XCTAssertEqual(selectorViewModel.selectedRecipientPeerId, "USER_PEER_1")
		XCTAssertEqual(selectorViewModel.transferState, .completed)

		selectorViewModel.finishCompletedTransfer()
		XCTAssertTrue(sendViewModel.stagedItems.isEmpty)
		XCTAssertEqual(sendViewModel.transferState, .empty)
		XCTAssertFalse(FileManager.default.fileExists(atPath: stagedFileURL.path))
	}

	// -------------------------------------------------------------------------
	// Receive ViewModel: Waiting -> Package Received -> Downloading
	// -------------------------------------------------------------------------

	func testReceiveWorkflowTransitions() {
		let viewModel = ReceiveViewModel(coreBridge: makeMockBridge())
		XCTAssertEqual(viewModel.screenState, .waiting)

		let incomingItem = ReceivedPackageItem(
			id: "pkg_item_1",
			name: "Document.pdf",
			byteSize: 2048,
			isDownloaded: false
		)
		viewModel.simulateIncomingPackage(items: [incomingItem])
		XCTAssertEqual(viewModel.screenState, .packageReceived(items: [incomingItem]))

		viewModel.downloadSingleItem(id: "pkg_item_1")
		let expectedDownloaded = ReceivedPackageItem(
			id: "pkg_item_1",
			name: "Document.pdf",
			byteSize: 2048,
			isDownloaded: true
		)
		XCTAssertEqual(viewModel.screenState, .packageReceived(items: [expectedDownloaded]))

		viewModel.downloadAllItems()
		XCTAssertEqual(viewModel.screenState, .completed)
	}

	// -------------------------------------------------------------------------
	// Trust List ViewModel: Search, Heart Toggle & Removal
	// -------------------------------------------------------------------------

	func testTrustListPeerToggleAndFilter() async {
		let viewModel = TrustListViewModel(coreBridge: makeMockBridge())
		await viewModel.loadPeers()
		XCTAssertEqual(viewModel.peers.count, 1)
		XCTAssertFalse(viewModel.peers[0].isTrusted)

		await viewModel.toggleTrust(for: viewModel.peers[0])
		XCTAssertTrue(viewModel.peers[0].isTrusted)

		viewModel.searchQuery = "Alice"
		XCTAssertEqual(viewModel.filteredPeers.count, 1)

		viewModel.searchQuery = "NonExistent"
		XCTAssertEqual(viewModel.filteredPeers.count, 0)
	}

	// -------------------------------------------------------------------------
	// Floating Bottom Bar: Horizontal Scrub Tab Resolution
	// -------------------------------------------------------------------------

	func testFloatingBottomBarTabResolution() {
		XCTAssertNil(resolvedNavigationTab(atHorizontalOffset: 50, totalBarWidth: 0))
		XCTAssertEqual(resolvedNavigationTab(atHorizontalOffset: -10, totalBarWidth: 300), .transfer)
		XCTAssertEqual(resolvedNavigationTab(atHorizontalOffset: 50, totalBarWidth: 300), .transfer)
		XCTAssertEqual(resolvedNavigationTab(atHorizontalOffset: 150, totalBarWidth: 300), .trustList)
		XCTAssertEqual(resolvedNavigationTab(atHorizontalOffset: 250, totalBarWidth: 300), .settings)
		XCTAssertEqual(resolvedNavigationTab(atHorizontalOffset: 400, totalBarWidth: 300), .settings)
	}

	// -------------------------------------------------------------------------
	// Home ViewModel: Default Receive Mode & Send/Receive Mode Switching
	// -------------------------------------------------------------------------

	func testHomeViewModelModeSwitchDefaultsToReceive() {
		let viewModel = HomeViewModel(coreBridge: makeMockBridge())
		XCTAssertEqual(viewModel.selectedMode, .receive)

		viewModel.selectedMode = .send
		XCTAssertEqual(viewModel.selectedMode, .send)

		viewModel.selectedMode = .receive
		XCTAssertEqual(viewModel.selectedMode, .receive)
	}

	// -------------------------------------------------------------------------
	// Segmented Toggle: Horizontal Scrub Option Resolution
	// -------------------------------------------------------------------------

	func testSegmentedToggleOptionResolution() {
		XCTAssertNil(resolvedModeSwitchOption(atHorizontalOffset: 50, totalBarWidth: 0))
		XCTAssertEqual(resolvedModeSwitchOption(atHorizontalOffset: -10, totalBarWidth: 300), .send)
		XCTAssertEqual(resolvedModeSwitchOption(atHorizontalOffset: 75, totalBarWidth: 300), .send)
		XCTAssertEqual(resolvedModeSwitchOption(atHorizontalOffset: 225, totalBarWidth: 300), .receive)
		XCTAssertEqual(resolvedModeSwitchOption(atHorizontalOffset: 400, totalBarWidth: 300), .receive)
	}
}
