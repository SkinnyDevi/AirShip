# AirShip iOS Client (src/ios)

Native Swift 6 + SwiftUI client for AirShip consuming compiled Rust XCFrameworks via UniFFI.

## Architecture & Directory Structure

```
src/ios/
├── Package.swift           # Swift Package Manager manifest
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
