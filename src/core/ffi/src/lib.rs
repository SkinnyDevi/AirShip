//! Thin UniFFI boundary exposing thread-safe controllers and callbacks to Swift and Kotlin.

use std::sync::Arc;

use airship_crypto::{IdentityKeyGenerator, IdentityKeypair, MockIdentityKeyGenerator};
use airship_domain::{
    DefaultTrustEvaluator, PackageManifest, PeerEntity, TransferDecision, TrustEvaluator,
    TrustLevel,
};
use airship_network::{
    DiscoveredServiceInfo, MdnsAdvertiser, MockMdnsAdvertiser, MockPackageSender, PackageSender,
    DEFAULT_STREAM_PORT,
};
use airship_primitives::{AirShipError, ByteBuffer, CryptoHash, PeerId};
use airship_storage::{InMemoryStorageEngine, TrustReadStore, TrustWriteStore};

// -----------------------------------------------------------------------------
// 1. FFI Data Models
// -----------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiPeerInfo {
    pub peer_identifier: String,
    pub display_alias: String,
    pub fingerprint_hex: String,
    pub is_trusted: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiManifestSummary {
    pub package_identifier: String,
    pub sender_identifier: String,
    pub item_count: u32,
    pub total_bytes: u64,
}

// -----------------------------------------------------------------------------
// 2. Thread-Safe Orchestration Controller
// -----------------------------------------------------------------------------

pub struct AirShipCoreController {
    local_identity: IdentityKeypair,
    storage_engine: Arc<InMemoryStorageEngine>,
    trust_evaluator: Arc<dyn TrustEvaluator>,
    advertiser: Arc<dyn MdnsAdvertiser>,
    package_sender: Arc<dyn PackageSender>,
}

impl AirShipCoreController {
    pub fn new(local_alias: &str) -> Result<Self, AirShipError> {
        let key_generator = MockIdentityKeyGenerator::new();
        let local_identity = key_generator.generate_persistent_identity(local_alias)?;
        let storage_engine = Arc::new(InMemoryStorageEngine::new());
        let trust_evaluator = Arc::new(DefaultTrustEvaluator::new());
        let advertiser = Arc::new(MockMdnsAdvertiser::new());
        let package_sender = Arc::new(MockPackageSender::new());

        Ok(Self {
            local_identity,
            storage_engine,
            trust_evaluator,
            advertiser,
            package_sender,
        })
    }

    pub fn get_local_user_name_id(&self) -> String {
        self.local_identity.derived_peer_id().as_str().to_string()
    }

    pub fn get_local_fingerprint(&self) -> String {
        self.local_identity.public_fingerprint().as_str().to_string()
    }

    pub fn start_broadcasting_presence(&self) -> Result<(), AirShipError> {
        let service_info = DiscoveredServiceInfo::new(
            self.local_identity.derived_peer_id().clone(),
            self.get_local_user_name_id(),
            DEFAULT_STREAM_PORT,
            self.local_identity.public_fingerprint().clone(),
            "1.0".to_string(),
        );
        self.advertiser.start_advertising(&service_info)
    }

    pub fn stop_broadcasting_presence(&self) -> Result<(), AirShipError> {
        self.advertiser.stop_advertising()
    }

    pub fn is_broadcasting(&self) -> bool {
        self.advertiser.is_advertising()
    }

    pub fn list_all_peers(&self) -> Result<Vec<FfiPeerInfo>, AirShipError> {
        let peer_entities = self.storage_engine.list_all_peers()?;
        let mapped_infos = peer_entities
            .into_iter()
            .map(|entity| FfiPeerInfo {
                peer_identifier: entity.peer_identifier().as_str().to_string(),
                display_alias: entity.display_alias().to_string(),
                fingerprint_hex: entity.fingerprint().as_str().to_string(),
                is_trusted: entity.is_trusted(),
            })
            .collect();
        Ok(mapped_infos)
    }

    pub fn set_peer_trust_status(&self, peer_identifier: &str, is_trusted: bool) -> Result<(), AirShipError> {
        let peer_id = PeerId::new(peer_identifier.to_string())?;
        let trust_level = if is_trusted {
            TrustLevel::TrustedAutoDownload
        } else {
            TrustLevel::UntrustedPrompt
        };
        self.storage_engine.update_trust_level(&peer_id, trust_level)
    }

    pub fn add_peer(&self, peer_identifier: &str, display_alias: &str, fingerprint_hex: &str, is_trusted: bool) -> Result<(), AirShipError> {
        let peer_id = PeerId::new(peer_identifier.to_string())?;
        let fingerprint = CryptoHash::from_hex(fingerprint_hex.to_string())?;
        let trust_level = if is_trusted {
            TrustLevel::TrustedAutoDownload
        } else {
            TrustLevel::UntrustedPrompt
        };
        let entity = PeerEntity::new(peer_id, display_alias.to_string(), fingerprint, trust_level);
        self.storage_engine.save_peer(entity)
    }

    pub fn remove_peer(&self, peer_identifier: &str) -> Result<bool, AirShipError> {
        let peer_id = PeerId::new(peer_identifier.to_string())?;
        self.storage_engine.delete_peer(&peer_id)
    }

    pub fn evaluate_incoming_package(&self, sender_identifier: &str, manifest: &PackageManifest) -> Result<TransferDecision, AirShipError> {
        let peer_id = PeerId::new(sender_identifier.to_string())?;
        let stored_peer = self.storage_engine.find_peer_by_identifier(&peer_id)?;
        if let Some(peer_entity) = stored_peer {
            self.trust_evaluator.evaluate_incoming_package(&peer_entity, manifest)
        } else {
            let unknown_peer = PeerEntity::new(
                peer_id,
                "Unknown Peer".to_string(),
                CryptoHash::from_hex("0".repeat(64))?,
                TrustLevel::UntrustedPrompt,
            );
            self.trust_evaluator.evaluate_incoming_package(&unknown_peer, manifest)
        }
    }

    pub fn send_package_to_peer(
        &self,
        peer_identifier: &str,
        manifest: &PackageManifest,
        payload_data: &ByteBuffer,
    ) -> Result<u16, AirShipError> {
        let peer_id = PeerId::new(peer_identifier.to_string())?;
        let stored_peer = self.storage_engine.find_peer_by_identifier(&peer_id)?;
        let target_peer = stored_peer.ok_or_else(|| AirShipError::PeerNotFound {
            peer_identifier: peer_identifier.to_string(),
        })?;
        self.package_sender.send_package(&target_peer, manifest, payload_data)
    }
}

// -----------------------------------------------------------------------------
// 3. Unit Tests
// -----------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_controller_initialization_and_identity() -> Result<(), AirShipError> {
        let controller = AirShipCoreController::new("DEV_USER")?;
        assert_eq!(controller.get_local_user_name_id(), "USER_DEV_USER");
        assert_eq!(controller.get_local_fingerprint().len(), 64);
        assert!(!controller.is_broadcasting());

        controller.start_broadcasting_presence()?;
        assert!(controller.is_broadcasting());

        controller.stop_broadcasting_presence()?;
        assert!(!controller.is_broadcasting());
        Ok(())
    }

    #[test]
    fn test_controller_peer_management() -> Result<(), AirShipError> {
        let controller = AirShipCoreController::new("DEV_USER")?;
        let test_fingerprint = "1".repeat(64);
        controller.add_peer("USER_REMOTE", "Remote User", &test_fingerprint, false)?;

        let peers = controller.list_all_peers()?;
        assert_eq!(peers.len(), 1);
        assert_eq!(peers[0].is_trusted, false);

        controller.set_peer_trust_status("USER_REMOTE", true)?;
        let updated_peers = controller.list_all_peers()?;
        assert_eq!(updated_peers[0].is_trusted, true);

        let removed = controller.remove_peer("USER_REMOTE")?;
        assert!(removed);
        assert_eq!(controller.list_all_peers()?.len(), 0);
        Ok(())
    }
}
