//! Networking primitives, mDNS discovery, UDP fallback beacons, and peer stream abstractions.

pub mod constants;
pub mod discover_service_info;
pub mod mock;
pub mod network_interfaces;
pub mod tcp_receiver;
pub mod tcp_transfer;
pub mod wire_protocol;

mod tcp_connection;

// -----------------------------------------------------------------------------
// Unit Tests
// -----------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use std::io::Cursor;
    use std::net::{IpAddr, Ipv4Addr, SocketAddr};

    use airship_domain::{
        constants::{PayloadKind, TrustLevel},
        manifest::{PackageManifest, PackageManifestItem},
        peer_entity::PeerEntity,
    };
    use airship_primitives::{
        bytebuffer::ByteBuffer, cryptohash::CryptoHash, errors::AirShipError, peer::PeerId,
    };

    use crate::tcp_receiver::TcpPackageReceiver;
    use crate::tcp_transfer::TcpPackageSender;
    use crate::{
        constants::{DEFAULT_STREAM_PORT, MAX_WIRE_FRAME_PAYLOAD_BYTES},
        discover_service_info::DiscoveredServiceInfo,
        mock::{MockMdnsAdvertiser, MockPackageSender},
        network_interfaces::{MdnsAdvertiser, PackageReceiver, PackageSender},
        wire_protocol::{WireFrame, WireFrameKind},
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

    #[test]
    fn test_wire_frame_roundtrip_and_validation() -> Result<(), AirShipError> {
        let frame = WireFrame::new(WireFrameKind::ItemChunk, b"hello-wire-frame".to_vec())?;
        let mut cursor = Cursor::new(Vec::new());
        frame.write_to_stream(&mut cursor)?;
        cursor.set_position(0);

        let decoded = WireFrame::read_from_stream(&mut cursor)?;
        assert_eq!(decoded, frame);

        let oversized_result = WireFrame::new(
            WireFrameKind::ItemChunk,
            vec![0u8; (MAX_WIRE_FRAME_PAYLOAD_BYTES as usize) + 1],
        );
        assert!(oversized_result.is_err());

        let unknown_kind = WireFrameKind::try_from(0xFE);
        assert!(unknown_kind.is_err());
        Ok(())
    }

    #[test]
    fn test_loopback_tcp_package_transfer_and_rejection() -> Result<(), AirShipError> {
        let receiver = TcpPackageReceiver::new(true);
        let assigned_port =
            receiver.bind_socket_address(SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0))?;

        let peer_id = PeerId::new("USER_LOOPBACK".to_string())?;
        let fingerprint = CryptoHash::from_hex("a".repeat(64))?;
        let peer_entity = PeerEntity::new(
            peer_id.clone(),
            "Loopback Peer".to_string(),
            fingerprint,
            TrustLevel::UntrustedPrompt,
        );
        let manifest = PackageManifest::new(
            "pkg_tcp_1".to_string(),
            peer_id,
            vec![PackageManifestItem::new(
                "item_1".to_string(),
                "archive.bin".to_string(),
                150_000,
                "application/octet-stream".to_string(),
                PayloadKind::Files,
                CryptoHash::from_hex("b".repeat(64))?,
            )],
        )?;
        let payload = ByteBuffer::new(vec![0x5A; 150_000]);

        let sender = TcpPackageSender::new(SocketAddr::new(
            IpAddr::V4(Ipv4Addr::LOCALHOST),
            assigned_port,
        ));
        let status_code = sender.send_package(&peer_entity, &manifest, &payload)?;
        assert_eq!(status_code, 202);

        let stored = receiver.received_packages()?;
        assert_eq!(stored.len(), 1);
        assert_eq!(stored[0].item_payloads[0], payload.as_slice());
        receiver.stop_listening()?;

        let rejecting_receiver = TcpPackageReceiver::new(false);
        let reject_port = rejecting_receiver
            .bind_socket_address(SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0))?;
        let reject_sender = TcpPackageSender::new(SocketAddr::new(
            IpAddr::V4(Ipv4Addr::LOCALHOST),
            reject_port,
        ));
        let reject_result = reject_sender.send_package(&peer_entity, &manifest, &payload);
        assert!(matches!(
            reject_result,
            Err(AirShipError::TransferRejected { .. })
        ));
        rejecting_receiver.stop_listening()
    }
}
