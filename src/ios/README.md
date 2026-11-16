# AirShip iOS Client (src/ios)

Native Swift 6 + SwiftUI client for AirShip consuming compiled Rust XCFrameworks via UniFFI.

## Architecture & Directory Structure

```
src/ios/
├── AirShip.xcodeproj/      # Xcode iOS App project (AirShip target + AirShip scheme)
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

### 1. Running the iOS App on Simulator or iPhone (`AirShip.xcodeproj`)

1. Open `src/ios/AirShip.xcodeproj` in Xcode (do **not** open `Package.swift` directly if you want to run the app, because `Package.swift` only exposes the `AirShipKit` library).
2. Select the **AirShip** scheme and choose your connected **iPhone** or an **iOS Simulator**.
3. For a physical iPhone, open the **AirShip** target > **Signing & Capabilities**, select your Apple **Team**, and set a unique **Bundle Identifier** if needed.
4. Press **Product > Run** (`Cmd + R`).
   > *Note*: `AirShipApp` currently initializes views with `MockCoreBridge` until the compiled Rust XCFramework and generated UniFFI Swift bindings are linked into `CoreBridge/`.

### 2. Building & Testing `AirShipKit` via Swift Package Manager

1. Open `src/ios/Package.swift` in Xcode (or run `swift test` from CLI) to run `AirShipKitTests`.
2. Choose a destination (an **iOS Simulator** or **My Mac**) and run **Product > Test** (`Cmd + U`).

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
