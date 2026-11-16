# AirShip iOS Client (src/ios)

Native Swift 6 + SwiftUI client for AirShip consuming compiled Rust XCFrameworks via UniFFI.

## Architecture & Directory Structure

```
src/ios/
├── Package.swift           # Swift Package Manager manifest (AirShipKit library + AirShipKitTests)
├── Info.plist              # Platform permissions (mDNS, Camera, Photos)
├── AirShipApp.swift        # App entry point with primary tab orchestration
├── CoreBridge/             # UniFFI Swift bindings & reactive Combine/AsyncStream wrappers
├── DesignSystem/           # Reusable UI primitives (Blimp logo, segmented toggles, floating bottom bar)
├── Features/
│   ├── Home/               # Identity display screen (USER_NAME_ID, primary mode switcher)
│   ├── Send/               # Package builder (Photos, Camera, Files, Text attachments)
│   ├── Receive/            # Listener view (waiting states, package queues, batch/individual download)
│   ├── TrustList/          # Contact management (search, inline drawer, heart trust toggle, delete)
│   └── Settings/           # Device alias, storage paths, certificate reset
└── Tests/                  # ViewModel state transition tests with fake UniFFI protocol stubs
```

## Prerequisites

- **macOS with Xcode** (Swift 6 toolchain; targets **iOS 17+** and **macOS 14+** in `Package.swift`).
- Ensure the active command-line developer tools point to `Xcode.app` (not standalone CommandLineTools) to avoid SDK version mismatches:
  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```

## Compiling & Running in Xcode

`src/ios` currently exposes `AirShipKit` as a Swift Package (`Package.swift`) alongside the SwiftUI `@main` entry point (`AirShipApp.swift`) and `Info.plist`.

### 1. Building & Testing `AirShipKit` in Xcode

1. Open **Xcode** and select **File > Open...**, then choose `src/ios/Package.swift` (or run `open src/ios/Package.swift` from Terminal).
2. Wait for Xcode to resolve the package targets (`AirShipKit` and `AirShipKitTests`).
3. Choose a destination from the scheme toolbar (e.g., an **iOS Simulator** or **My Mac**).
4. Compile the library with **Product > Build** (`Cmd + B`).
5. Run the ViewModel unit tests with **Product > Test** (`Cmd + U`).

### 2. Running the Full iOS App (`AirShipApp.swift`)

Because `Package.swift` defines `AirShipKit` as a library product (excluding `AirShipApp.swift` and `Info.plist` from the library target), launching the UI on an iOS Simulator or physical device requires an Xcode **iOS App** project target:

1. In Xcode, create or open an **iOS App** project (SwiftUI App lifecycle) and add `src/ios/` as a local Swift Package dependency linking `AirShipKit`.
2. Include `AirShipApp.swift` as the app target's entry point (or import `AirShipKit` from your app target) and configure its **Info** / `Info.plist` with the permission keys in `src/ios/Info.plist` (`NSLocalNetworkUsageDescription`, `NSBonjourServices` with `_airship._tcp`, `NSCameraUsageDescription`, and `NSPhotoLibraryUsageDescription`).
3. Select an iOS Simulator or connected iPhone/iPad and press **Product > Run** (`Cmd + R`).
   > *Note*: `AirShipApp` currently initializes views with `MockCoreBridge` until the compiled Rust XCFramework and generated UniFFI Swift bindings are linked into `CoreBridge/`.

## Compiling & Testing via CLI (Swift Package Manager)

From inside `src/ios/`:

```bash
cd src/ios

# Compile the AirShipKit Swift package
swift build

# Run AirShipKitTests
swift test
```

## Linking the Rust Core (`src/core`)

1. Compile `airship-ffi` from `src/core` for `aarch64-apple-ios` and `aarch64-apple-ios-sim` and bundle the static libraries into an `.xcframework`.
2. Generate the Swift UniFFI bindings into `src/ios/CoreBridge/`.
3. Add the `.xcframework` as a `.binaryTarget` in `Package.swift` (or link it in the Xcode iOS App target) and replace `MockCoreBridge` in `AirShipApp.swift`.
