//! Networking primitives, mDNS discovery, UDP fallback beacons, and peer stream abstractions.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use airship_crypto::TlsConfiguration;
use airship_domain::{PackageManifest, PeerEntity};
use airship_primitives::{AirShipError, ByteBuffer, CryptoHash, PeerId};

// -----------------------------------------------------------------------------
// 1. Constants
// -----------------------------------------------------------------------------

pub const MDNS_SERVICE_TYPE: &str = "_airship._tcp.local.";
pub const UDP_FALLBACK_BEACON_PORT: u16 = 53317;
pub const DEFAULT_STREAM_PORT: u16 = 53318;

// -----------------------------------------------------------------------------
// 2. Data Types
// -----------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DiscoveredServiceInfo {
    peer_identifier: PeerId,
    display_alias: String,
    port: u16,
    fingerprint: CryptoHash,
    protocol_version: String,
}

impl DiscoveredServiceInfo {
    pub fn new(
        peer_identifier: PeerId,
        display_alias: String,
        port: u16,
        fingerprint: CryptoHash,
        protocol_version: String,
    ) -> Self {
        Self {
            peer_identifier,
            display_alias,
            port,
            fingerprint,
            protocol_version,
        }
    }

    pub fn peer_identifier(&self) -> &PeerId {
        &self.peer_identifier
    }

    pub fn display_alias(&self) -> &str {
        &self.display_alias
    }

    pub fn port(&self) -> u16 {
        self.port
    }

    pub fn fingerprint(&self) -> &CryptoHash {
        &self.fingerprint
    }

    pub fn protocol_version(&self) -> &str {
        &self.protocol_version
    }
}

// -----------------------------------------------------------------------------
// 3. Narrow Network Interfaces (ISP)
// -----------------------------------------------------------------------------

pub trait MdnsAdvertiser: Send + Sync {
    fn start_advertising(&self, service_info: &DiscoveredServiceInfo) -> Result<(), AirShipError>;
    fn stop_advertising(&self) -> Result<(), AirShipError>;
    fn is_advertising(&self) -> bool;
}

pub trait MdnsBrowser: Send + Sync {
    fn start_discovery(&self) -> Result<(), AirShipError>;
    fn stop_discovery(&self) -> Result<(), AirShipError>;
    fn get_discovered_peers(&self) -> Result<Vec<DiscoveredServiceInfo>, AirShipError>;
}

pub trait UdpBeaconBroadcaster: Send + Sync {
    fn broadcast_beacon(&self, service_info: &DiscoveredServiceInfo) -> Result<(), AirShipError>;
}

pub trait PackageSender: Send + Sync {
    fn send_package(
        &self,
        target_peer: &PeerEntity,
        manifest: &PackageManifest,
        payload_data: &ByteBuffer,
    ) -> Result<u16, AirShipError>;
}

pub trait PackageReceiver: Send + Sync {
    fn bind_and_listen(&self, port: u16, tls_config: &TlsConfiguration) -> Result<(), AirShipError>;
    fn stop_listening(&self) -> Result<(), AirShipError>;
}

// -----------------------------------------------------------------------------
// 4. Mock Implementations for Loopback / Testing (LSP)
// -----------------------------------------------------------------------------

pub struct MockMdnsAdvertiser {
    active: Arc<AtomicBool>,
}

impl MockMdnsAdvertiser {
    pub fn new() -> Self {
        Self {
            active: Arc::new(AtomicBool::new(false)),
        }
    }
}

impl Default for MockMdnsAdvertiser {
    fn default() -> Self {
        Self::new()
    }
}

impl MdnsAdvertiser for MockMdnsAdvertiser {
    fn start_advertising(&self, _service_info: &DiscoveredServiceInfo) -> Result<(), AirShipError> {
        self.active.store(true, Ordering::SeqCst);
        Ok(())
    }

    fn stop_advertising(&self) -> Result<(), AirShipError> {
        self.active.store(false, Ordering::SeqCst);
        Ok(())
    }

    fn is_advertising(&self) -> bool {
        self.active.load(Ordering::SeqCst)
    }
}

pub struct MockPackageSender;

impl MockPackageSender {
    pub fn new() -> Self {
        Self
    }
}

impl Default for MockPackageSender {
    fn default() -> Self {
        Self::new()
    }
}

impl PackageSender for MockPackageSender {
    fn send_package(
        &self,
        target_peer: &PeerEntity,
        _manifest: &PackageManifest,
        _payload_data: &ByteBuffer,
    ) -> Result<u16, AirShipError> {
        if target_peer.is_trusted() {
            Ok(200)
        } else {
            Ok(202)
        }
    }
}

// -----------------------------------------------------------------------------
// 5. Unit Tests
// -----------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use airship_domain::TrustLevel;

    #[test]
    fn test_advertiser_lifecycle() -> Result<(), AirShipError> {
        let advertiser = MockMdnsAdvertiser::new();
        assert!(!advertiser.is_advertising());

        let peer_id = PeerId::new("USER_NODE_1".to_string())?;
        let fingerprint = CryptoHash::from_hex("d".repeat(64))?;
        let info = DiscoveredServiceInfo::new(
            peer_id,
            "Node 1".to_string(),
            DEFAULT_STREAM_PORT,
            fingerprint,
            "1.0".to_string(),
        );

        advertiser.start_advertising(&info)?;
        assert!(advertiser.is_advertising());

        advertiser.stop_advertising()?;
        assert!(!advertiser.is_advertising());
        Ok(())
    }

    #[test]
    fn test_mock_package_sender() -> Result<(), AirShipError> {
        let sender = MockPackageSender::new();
        let peer_id = PeerId::new("USER_NODE_2".to_string())?;
        let fingerprint = CryptoHash::from_hex("e".repeat(64))?;
        let trusted_peer = PeerEntity::new(
            peer_id.clone(),
            "Trusted Node".to_string(),
            fingerprint.clone(),
            TrustLevel::TrustedAutoDownload,
        );
        let untrusted_peer = PeerEntity::new(
            peer_id,
            "Untrusted Node".to_string(),
            fingerprint,
            TrustLevel::UntrustedPrompt,
        );

        let manifest = PackageManifest::new(
            "pkg_1".to_string(),
            trusted_peer.peer_identifier().clone(),
            vec![airship_domain::PackageManifestItem::new(
                "item_1".to_string(),
                "file.txt".to_string(),
                10,
                "text/plain".to_string(),
                airship_domain::PayloadKind::Text,
                CryptoHash::from_hex("f".repeat(64))?,
            )],
        )?;
        let payload = ByteBuffer::new(vec![1, 2, 3]);

        let trusted_status = sender.send_package(&trusted_peer, &manifest, &payload)?;
        assert_eq!(trusted_status, 200);

        let untrusted_status = sender.send_package(&untrusted_peer, &manifest, &payload)?;
        assert_eq!(untrusted_status, 202);
        Ok(())
    }
}
