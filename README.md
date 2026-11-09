# AirShip

AirShip is a native cross-platform peer-to-peer (P2P) local file and text sharing application for iOS and Android with a cryptographic trust-list permission layer.

## Repository Architecture

The project strictly follows a three-folder root architecture under `src`:

```
AirShip/
├── Cargo.toml               # Rust workspace manifest
├── AGENTS.md                # Engineering standards & project specification
├── gradlew                  # Root Gradle wrapper delegating to Android client
├── .gitignore               # Multi-platform gitignore rules
└── src/
    ├── core/                # Shared Core (Rust 2024 Edition + UniFFI)
    │   ├── primitives/      # Byte buffers, cryptographic hashes, UUIDs, error types
    │   ├── domain/          # Peer entities, trust-list models, package manifests, state machines
    │   ├── crypto/          # Ed25519 keypair generation, X.509 certificate pinning, TLS 1.3
    │   ├── storage/         # Interface-segregated embedded persistence contracts & in-memory engine
    │   ├── network/         # mDNS discovery (_airship._tcp.local.), UDP beacon fallback (port 53317)
    │   └── ffi/             # Thin UniFFI boundary exposing thread-safe controller
    │
    ├── ios/                 # iOS Native Client (Swift 6 + SwiftUI)
    │   ├── Package.swift    # Swift Package Manager manifest
    │   ├── Info.plist       # Permissions (mDNS, Camera, Photos)
    │   ├── CoreBridge/      # UniFFI Swift bindings & reactive Combine/AsyncStream wrappers
    │   ├── DesignSystem/    # Reusable UI primitives (Blimp logo, segmented toggle, floating bottom bar)
    │   └── Features/        # MVVM feature views (Home, Send, Receive, TrustList, Settings)
    │
    └── android/             # Android Native Client (Kotlin 2 + Jetpack Compose)
        ├── build.gradle.kts # Android Studio project build configuration
        ├── corebridge/      # UniFFI Kotlin bindings wrapped in Coroutines and Flow<T>
        ├── designsystem/    # Reusable Compose components matching wireframes
        └── features/        # UDF feature screens (home, send, receive, trustlist, settings)
```

## Verification

To verify the codebase:

```bash
# Verify Rust shared core
cargo clippy -- -D warnings
cargo test

# Verify Android client
./gradlew testDebugUnitTest
```
