use std::collections::HashMap;
use std::sync::RwLock;

use airship_domain::constants::TrustLevel;
use airship_domain::peer_entity::PeerEntity;
use airship_primitives::cryptohash::CryptoHash;
use airship_primitives::errors::AirShipError;
use airship_primitives::peer::PeerId;

use crate::constants::TransferRecord;
use crate::store::{TransferLogReadStore, TransferLogWriteStore, TrustReadStore, TrustWriteStore};

pub struct InMemoryStorageEngine {
    peer_storage: RwLock<HashMap<PeerId, PeerEntity>>,
    transfer_records: RwLock<Vec<TransferRecord>>,
}

impl InMemoryStorageEngine {
    pub fn new() -> Self {
        Self {
            peer_storage: RwLock::new(HashMap::new()),
            transfer_records: RwLock::new(Vec::new()),
        }
    }
}

impl Default for InMemoryStorageEngine {
    fn default() -> Self {
        Self::new()
    }
}

impl TrustReadStore for InMemoryStorageEngine {
    fn find_peer_by_identifier(
        &self,
        peer_identifier: &PeerId,
    ) -> Result<Option<PeerEntity>, AirShipError> {
        let guard = self
            .peer_storage
            .read()
            .map_err(|error| AirShipError::StorageFailure {
                message: error.to_string(),
            })?;

        Ok(guard.get(peer_identifier).cloned())
    }

    fn find_peer_by_fingerprint(
        &self,
        fingerprint: &CryptoHash,
    ) -> Result<Option<PeerEntity>, AirShipError> {
        let guard = self
            .peer_storage
            .read()
            .map_err(|error| AirShipError::StorageFailure {
                message: error.to_string(),
            })?;

        let matching_peer = guard
            .values()
            .find(|peer| peer.fingerprint() == fingerprint)
            .cloned();

        Ok(matching_peer)
    }

    fn list_all_peers(&self) -> Result<Vec<PeerEntity>, AirShipError> {
        let guard = self
            .peer_storage
            .read()
            .map_err(|error| AirShipError::StorageFailure {
                message: error.to_string(),
            })?;

        Ok(guard.values().cloned().collect())
    }
}

impl TrustWriteStore for InMemoryStorageEngine {
    fn save_peer(&self, peer: PeerEntity) -> Result<(), AirShipError> {
        let mut guard =
            self.peer_storage
                .write()
                .map_err(|error| AirShipError::StorageFailure {
                    message: error.to_string(),
                })?;

        guard.insert(peer.peer_identifier().clone(), peer);
        Ok(())
    }

    fn update_trust_level(
        &self,
        peer_identifier: &PeerId,
        new_level: TrustLevel,
    ) -> Result<(), AirShipError> {
        let mut guard =
            self.peer_storage
                .write()
                .map_err(|error| AirShipError::StorageFailure {
                    message: error.to_string(),
                })?;

        let peer_entry =
            guard
                .get_mut(peer_identifier)
                .ok_or_else(|| AirShipError::PeerNotFound {
                    peer_identifier: peer_identifier.as_str().to_string(),
                })?;

        let updated_peer = PeerEntity::new(
            peer_entry.peer_identifier().clone(),
            peer_entry.display_alias().to_string(),
            peer_entry.fingerprint().clone(),
            new_level,
        );

        *peer_entry = updated_peer;
        Ok(())
    }

    fn delete_peer(&self, peer_identifier: &PeerId) -> Result<bool, AirShipError> {
        let mut guard =
            self.peer_storage
                .write()
                .map_err(|error| AirShipError::StorageFailure {
                    message: error.to_string(),
                })?;

        Ok(guard.remove(peer_identifier).is_some())
    }
}

impl TransferLogReadStore for InMemoryStorageEngine {
    fn list_transfer_records(&self) -> Result<Vec<TransferRecord>, AirShipError> {
        let guard = self
            .transfer_records
            .read()
            .map_err(|error| AirShipError::StorageFailure {
                message: error.to_string(),
            })?;

        Ok(guard.clone())
    }
}

impl TransferLogWriteStore for InMemoryStorageEngine {
    fn append_transfer_record(&self, record: TransferRecord) -> Result<(), AirShipError> {
        let mut guard =
            self.transfer_records
                .write()
                .map_err(|error| AirShipError::StorageFailure {
                    message: error.to_string(),
                })?;

        guard.push(record);
        Ok(())
    }
}
