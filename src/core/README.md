# AirShip Core Engine (src/core)

Native Rust shared core for AirShip, compiled via UniFFI for iOS and Android.

## Workspace Architecture

Strictly adheres to the bottom-up complexity dependency hierarchy:
`primitives` -> `domain` -> `crypto` -> `storage` -> `network` -> `ffi`

- **primitives**: Byte buffers (`ByteBuffer`), cryptographic hashes (`CryptoHash`), user identities (`PeerId`), and error types (`AirShipError`).
- **domain**: Peer entities, trust-list models, package manifests, and transfer state machines.
- **crypto**: Ed25519 keypair generation, X.509 certificate pinning, and TLS 1.3 configurations.
- **storage**: Interface-segregated persistence contracts (`TrustReadStore`, `TrustWriteStore`, `TransferLogReadStore`, `TransferLogWriteStore`) and in-memory mock engine.
- **network**: mDNS service broadcasting (`_airship._tcp.local.`), UDP fallback discovery (port 53317), and streaming socket abstractions.
- **ffi**: Thin UniFFI boundary exposing thread-safe controller `AirShipCoreController` to Swift and Kotlin.

## Prerequisites

- **Rust Toolchain**: Edition `2024` (`rustc >= 1.85`). Ensure Cargo is on your `PATH` (typically `$HOME/.cargo/bin`).
- **Clippy**: Install via `rustup component add clippy`.
- **Cross-Compilation Targets (optional, for mobile bindings)**:
  - **iOS**: `rustup target add aarch64-apple-ios aarch64-apple-ios-sim` (plus `xcodebuild` for XCFramework packaging).
  - **Android**: `rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android`, Android NDK, and `cargo-ndk`.

> **Workspace Root Note**: The Cargo workspace manifest is located at the repository root (`../../Cargo.toml`). You can run `cargo` commands either from the repository root or directly inside `src/core/` (Cargo resolves the workspace manifest upward automatically).

## Compiling

Build all crates in the workspace (debug profile):

```bash
cargo build --workspace
```

Build release library artifacts (including the `airship-ffi` `lib`, `staticlib`, and `cdylib` outputs under `../../target/release/`):

```bash
cargo build --release -p airship-ffi
```

Check or compile a single crate (e.g., `airship-domain`):

```bash
cargo check -p airship-domain
```

## Running & Verification

`src/core` consists of library crates (no standalone executable binary). Execute behavior verification and strict linting via:

```bash
# Lint all workspace crates (warnings treated as errors)
cargo clippy -- -D warnings

# Run unit and integration tests across all 6 crates
cargo test
```

Run tests for a single crate:

```bash
cargo test -p airship-domain
```
