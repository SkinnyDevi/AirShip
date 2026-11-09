## 1. Project Overview & Core Language Selection

AirShip is a native cross-platform peer-to-peer (P2P) local file and text sharing application for iOS and Android with a cryptographic trust-list permission layer.

* **Core Engine (src/core — Rust + UniFFI)**: Handles mDNS discovery, TLS 1.3 / QUIC sockets, Ed25519 identity keys, trust evaluation, and chunked file streaming without garbage-collection pauses.
* **iOS Client (src/ios — Swift 6 + SwiftUI)**: Implements native iOS UI, platform permissions, system share extensions, and lifecycle hooks consuming compiled Rust XCFrameworks.
* **Android Client (src/android — Kotlin 2 + Jetpack Compose)**: Implements Material 3 / custom Compose UI, foreground transfer services, and storage APIs consuming Rust JNI libraries.

| Layer | Technology | Responsibility | Binding Mechanism |
| --- | --- | --- | --- |
| Shared Core | Rust (2024 Edition) | Discovery, mTLS, Trust Engine, File I/O | UniFFI Procedural Macros |
| iOS Native | Swift 6, SwiftUI | UI Rendering, Sandboxed File Picker, Lifecycle | XCFramework + Swift Package |
| Android Native | Kotlin 2, Compose | UI Rendering, MulticastLock, Scoped Storage | JNI + JNA AAR Artifact |

Rust outperforms Kotlin Multiplatform (KMP) and C++ for AirShip because P2P file transfer requires identical low-level TCP/QUIC socket behavior, raw multicast UDP packet handling, and zero-copy byte streaming across both OS kernels.

## 2. Repository Directory Structure

All agent-generated code must strictly follow this three-folder root architecture under **src**:

* **src/core**: Rust workspace containing domain logic, networking, persistence, and FFI definitions.
* **src/core/primitives**: Byte buffers, cryptographic hashes, UUIDs, and error types.
* **src/core/domain**: Peer entities, trust-list models, package manifests, and transfer state machines.
* **src/core/crypto**: Ed25519 keypair generation, X.509 certificate pinning, and TLS 1.3 configurations.
* **src/core/network**: mDNS service broadcasting, UDP fallback discovery, and HTTP/2 or QUIC streaming servers.
* **src/core/storage**: SQLite or redb embedded persistence for trusted peer fingerprints and transfer logs.
* **src/core/ffi**: Thin UniFFI boundary exposing thread-safe controllers and callbacks to Swift and Kotlin.


* **src/ios**: Native Xcode project following MVVM + Clean Architecture.
* **src/ios/CoreBridge**: Generated UniFFI Swift bindings and reactive Combine/AsyncStream wrappers.
* **src/ios/DesignSystem**: Reusable UI primitives including the blimp logo, segmented toggles, and floating bottom bar.


* **src/ios/Features/Home**: Identity display screen showing the local user ID and primary mode switcher.


* **src/ios/Features/Send**: Package builder supporting Photos, Camera, Files, and Text inputs.


* **src/ios/Features/Receive**: Listener view handling waiting states and incoming package queues.


* **src/ios/Features/TrustList**: Peer search, manual user addition, heart trust toggles, and peer deletion.


* **src/ios/Features/Settings**: Device alias configuration, storage path rules, and certificate reset.




* **src/android**: Native Android Studio project following MVVM + Unidirectional Data Flow (UDF).
* **src/android/corebridge**: Generated UniFFI Kotlin bindings wrapped in Kotlin Coroutines and `Flow<T>`.
* **src/android/designsystem**: Reusable Compose components matching the wireframes.


* **src/android/features/home**: Identity screen and Send/Receive navigation entry point.


* **src/android/features/send**: Multi-source attachment staging list with item removal controls.


* **src/android/features/receive**: Active listening screen with individual and batch download controls.


* **src/android/features/trustlist**: Searchable contact list with inline user addition and trust toggles.


* **src/android/features/settings**: System preferences, background execution toggles, and network diagnostics.





## 3. System Architecture & P2P Protocol (LocalSend Model)

AirShip operates entirely offline over local area networks (Wi-Fi LAN, Hotspot, or Wi-Fi Direct) without central relay servers.

**Cryptographic Identity & Discovery**

1. **Identity Generation**: On first launch, **src/core** generates a persistent Ed25519 keypair and derives a human-readable user identifier (`USER_NAME_ID`) alongside a SHA-256 public key fingerprint.


2. **Service Broadcast**: The device registers an mDNS service (`_airship._tcp.local.`) advertising its port, alias, protocol version, and public key fingerprint.
3. **Fallback Discovery**: If multicast DNS is blocked by router client isolation, **src/core** broadcasts periodic UDP beacons on port 53317 and allows direct lookup via the Trust List search bar.



**Trust List & Permission Evaluation Flow**

1. **Handshake & Verification**: All connections upgrade to mutual TLS (mTLS) 1.3 where both peers validate each other's Ed25519-signed X.509 certificates against local storage.
2. **Manifest Exchange**: The sender transmits an encrypted JSON package manifest listing file names, byte sizes, MIME types (Photos, Camera media, Files, or Pasted Text), and SHA-256 checksums.


3. **Trusted Peer Fast-Path (Auto-Download)**: If the sender's verified public key fingerprint has an active trust flag (solid heart icon in the Trust List), **src/core** returns `HTTP 200 OK` and streams the payload directly to local storage.


4. **Untrusted Peer Gatekeeping (Manual Approval)**: If the sender is not trusted (outlined heart icon or unknown peer), **src/core** returns `HTTP 202 Accepted (Pending Approval)` and pauses the stream.


5. **User Resolution**: The receiver UI transitions to "Package Received!" displaying the manifest items with individual download buttons and a "Download All" button.



## 4. UI Architecture & Screen Specifications

Both **src/ios** and **src/android** must implement a unified layout driven by state machines in **src/core**:

* **Global Bottom Navigation Bar**: A persistent floating pill at the bottom of all screens containing three tabs: Transfer/Home (Blimp icon), Trust List/Users (People icon), and Settings (Gear icon).


* **Identity Home Screen (Tab 1 Root)**: Displays the central AirShip blimp illustration, the user's current `USER_NAME_ID`, and a segmented pill button to enter `Send` or `Receive` mode.


* **Send Package Screen**:
* Features a top segmented switch (`Send` active, `Receive` inactive) and a "Create your package" header.


* Provides four media attachment buttons: `Photos`, `Camera`, `Files`, and `Text`.


* Displays "No files selected" inside the dark staging container when empty.


* Lists staged items with type icons, filenames, sizes, and an `X` button to remove individual files before dispatch.




* **Receive Package Screen**:
* Displays a top segmented switch (`Receive` active) and a central blimp icon with "Waiting for your package..." while listening on the local socket.


* Transitions to "Package Received!" upon manifest arrival, rendering each file or pasted text snippet with an individual download icon button and a bottom "Download All" button.




* **Trust List & User Management Screen (Tab 2)**:
* Includes a top search input with a `+` button that expands an inline secondary input drawer to query and add remote users by `USER_NAME_ID`.


* Renders each user row with an avatar icon, username, a heart icon toggle (solid heart = Trusted / Auto-Download enabled; outlined heart = Untrusted / Prompt required), and a trash icon to remove the user.




* **Settings Screen (Tab 3)**: Houses local device alias customization, destination folder permissions, and network interface status.



## 5. Engineering Principles & Coding Standards

All code across Rust, Swift, and Kotlin must strictly enforce the following architectural rules:

**Lower-to-Higher Complexity Ordering (Bottom-Up Construction)**

* **File-Level Ordering**: Every source file must be ordered from lowest complexity to highest complexity: constants and primitive types first, pure helper functions second, domain structs/classes third, and complex orchestrators last.
* **Module-Level Ordering**: Build and import dependencies strictly upward from leaf primitives (`primitives` -> `domain` -> `crypto` -> `network` -> `ffi` -> `ViewModel` -> `View`). Lower layers must never import higher layers.

**Function Granularity & Control Flow**

* **Small Function Bodies**: Functions and methods must not exceed 20 lines of executable code. Extract complex loops, parsing, or conditional branches into well-named private helper functions.
* **Single Level of Abstraction**: Every statements inside a function must operate at the same conceptual level. Do not mix low-level byte manipulation with high-level business workflow rules.
* **Cyclomatic Complexity & Guard Clauses**: Maximum cyclomatic complexity per function is 4. Use early returns (`guard let` in Swift, ` ?: return` in Kotlin, `?` operator in Rust) to eliminate nested `if/else` pyramids (max indentation depth: 2 levels).

**SOLID Principles**

* **Single Responsibility (SRP)**: Each class, struct, or Rust module must have exactly one reason to change (e.g., separate `MdnsAdvertiser` from `MdnsBrowser`, and separate `TrustEvaluator` from `FileStreamWriter`).
* **Open/Closed (OCP)**: Extend transfer media types (`Photos`, `Camera`, `Files`, `Text`) and discovery transports via traits/protocols/interfaces without modifying existing transfer engine pipelines.


* **Liskov Substitution (LSP)**: Mock discovery services, loop-back socket streams, and in-memory trust stores must be 100% substitutable for production implementations without altering caller behavior.
* **Interface Segregation (ISP)**: Split narrow consumer interfaces (`TrustReadStore`, `TrustWriteStore`, `PackageSender`, `PackageReceiver`) rather than exposing monolithic manager interfaces.
* **Dependency Inversion (DIP)**: UI ViewModels and high-level Rust orchestrators must depend exclusively on traits (`trait`, `protocol`, `interface`), injected via constructor initialization.

**Law of Demeter (Principle of Least Knowledge)**

* **No Train-Wreck Chaining**: Never chain more than one dot accessor across distinct object boundaries (forbid `peerManager.getSession().getSocket().getConfig().setPort()`).
* **Tell, Don't Ask**: Objects and structs must expose domain behavior methods (`peer.evaluateAutoDownloadPermission(for: manifest)`) rather than exposing internal mutable state for callers to inspect.

**Descriptive Naming & Immutability**

* **Intention-Revealing Identifiers**: Use full, unambiguous domain names (`trustedPeerFingerprints`, `pendingPackageManifest`, `incomingByteStream`). Single-letter variables (`x`, `p`, `d`) and vague terms (`data`, `manager`, `helper`, `info`, `util`) are strictly forbidden.
* **Immutability by Default**: Declare all variables immutable by default (`let` in Rust and Swift, `val` in Kotlin). State mutation must be isolated inside thread-safe actors (`actor` in Swift, `Mutex`/`RwLock` in Rust, `StateFlow` in Kotlin).

## 6. Error Handling, Concurrency & Platform Mandates

**Zero Unhandled Crashes**

* **Rust (src/core)**: Ban `.unwrap()`, `.expect()`, and `panic!()` in all production paths. Every fallible function must return `Result<T, AirShipError>` mapped to a UniFFI error enum.
* **Swift (src/ios)**: Ban force-unwrapping (`!`), `try!`, and `as!`. Handle all FFI throws using structured `do/catch` blocks mapped to localized UI error states.
* **Kotlin (src/android)**: Ban the non-null assertion operator (`!!`). Wrap asynchronous operations in sealed result states (` TransferUiState.Error`).

**Platform Permissions & OS Lifecycle Requirements**

* **iOS (Info.plist & Entitlements)**:
* Configure `NSLocalNetworkUsageDescription` and `NSBonjourServices` (`_airship._tcp`) for local peer discovery.
* Configure `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` for the Camera and Photos package builders.


* Acquire `UIApplication.beginBackgroundTask` assertions when streaming active transfers so iOS does not suspend sockets mid-download.


* **Android (AndroidManifest.xml & Services)**:
* Request `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, and `NEARBY_WIFI_DEVICES` (with `neverForLocation` flag on Android 13+).
* Acquire and release `WifiManager.MulticastLock` strictly during active mDNS discovery sessions to preserve battery.
* Run active file transfers inside a `ForegroundService` (` connectedDevice` / `dataSync` type) with persistent notification progress and write received files via `MediaStore` or Storage Access Framework (SAF).



## 7. Testing & Verification Requirements

* **Core Unit & Integration Tests**: Every module in **src/core** requires unit tests covering both trusted (auto-accept) and untrusted (manual accept) state transitions using in-memory loopback TLS streams before binding generation.
* **ViewModel State Tests**: Both **src/ios** and **src/android** ViewModels must test state transitions (Empty -> Staged -> Sending -> Completed, and Waiting -> Package Received -> Downloading) using fake UniFFI protocol stubs.


* **Pre-Commit Verification**: Code agents must verify `cargo clippy -- -D warnings`, `cargo test`, `swift test`, and `./gradlew testDebugUnitTest` pass with zero warnings before completing any task.