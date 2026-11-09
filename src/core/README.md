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

## Verification

```bash
cargo clippy -- -D warnings
cargo test
```
