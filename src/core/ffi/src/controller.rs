use std::sync::Arc;

use airship_crypto::{
    generator::{IdentityKeyGenerator, MockIdentityKeyGenerator},
    identity::IdentityKeypair,
};
use airship_domain::{
    constants::TrustLevel,
    manifest::PackageManifest,
    peer_entity::PeerEntity,
    trust_evaluator::{DefaultTrustEvaluator, TransferDecision, TrustEvaluator},
};
use airship_network::{
    constants::DEFAULT_STREAM_PORT,
    discover_service_info::DiscoveredServiceInfo,
    mock::{MockMdnsAdvertiser, MockPackageSender},
    network_interfaces::{MdnsAdvertiser, PackageSender},
};
use airship_primitives::{
    bytebuffer::ByteBuffer, cryptohash::CryptoHash, errors::AirShipError, peer::PeerId,
};
use airship_storage::{
    storage_engine::InMemoryStorageEngine,
    store::{TrustReadStore, TrustWriteStore},
};

use crate::data_models::FfiPeerInfo;

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
        self.local_identity
            .public_fingerprint()
            .as_str()
            .to_string()
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

    pub fn set_peer_trust_status(
        &self,
        peer_identifier: &str,
        is_trusted: bool,
    ) -> Result<(), AirShipError> {
        let peer_id = PeerId::new(peer_identifier.to_string())?;
        let trust_level = if is_trusted {
            TrustLevel::TrustedAutoDownload
        } else {
            TrustLevel::UntrustedPrompt
        };
        self.storage_engine
            .update_trust_level(&peer_id, trust_level)
    }

    pub fn add_peer(
        &self,
        peer_identifier: &str,
        display_alias: &str,
        fingerprint_hex: &str,
        is_trusted: bool,
    ) -> Result<(), AirShipError> {
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

    pub fn evaluate_incoming_package(
        &self,
        sender_identifier: &str,
        manifest: &PackageManifest,
    ) -> Result<TransferDecision, AirShipError> {
        let peer_id = PeerId::new(sender_identifier.to_string())?;
        let stored_peer = self.storage_engine.find_peer_by_identifier(&peer_id)?;

        if let Some(peer_entity) = stored_peer {
            self.trust_evaluator
                .evaluate_incoming_package(&peer_entity, manifest)
        } else {
            let unknown_peer = PeerEntity::new(
                peer_id,
                "Unknown Peer".to_string(),
                CryptoHash::from_hex("0".repeat(64))?,
                TrustLevel::UntrustedPrompt,
            );
            self.trust_evaluator
                .evaluate_incoming_package(&unknown_peer, manifest)
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

        self.package_sender
            .send_package(&target_peer, manifest, payload_data)
    }
}
