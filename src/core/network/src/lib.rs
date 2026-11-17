//! Networking primitives, mDNS discovery, UDP fallback beacons, and peer stream abstractions.

pub mod constants;
pub mod discover_service_info;
pub mod mock;
pub mod network_interfaces;

// -----------------------------------------------------------------------------
// Unit Tests
// -----------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use airship_domain::{
        constants::{PayloadKind, TrustLevel},
        manifest::{PackageManifest, PackageManifestItem},
        peer_entity::PeerEntity,
    };
    use airship_primitives::{
        bytebuffer::ByteBuffer, cryptohash::CryptoHash, errors::AirShipError, peer::PeerId,
    };

    use crate::{
        constants::DEFAULT_STREAM_PORT,
        discover_service_info::DiscoveredServiceInfo,
        mock::{MockMdnsAdvertiser, MockPackageSender},
        network_interfaces::{MdnsAdvertiser, PackageSender},
    };

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
            vec![PackageManifestItem::new(
                "item_1".to_string(),
                "file.txt".to_string(),
                10,
                "text/plain".to_string(),
                PayloadKind::Text,
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
