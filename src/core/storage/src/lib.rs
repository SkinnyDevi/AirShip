//! Embedded persistence interfaces and storage implementations for trusted peers and transfer logs.

use std::collections::HashMap;
use std::sync::RwLock;

use airship_domain::{PeerEntity, TrustLevel};
use airship_primitives::{AirShipError, CryptoHash, PeerId};

// -----------------------------------------------------------------------------
// 1. Constants & Types
// -----------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TransferRecord {
    record_identifier: String,
    package_identifier: String,
    peer_identifier: PeerId,
    bytes_transferred: u64,
    success: bool,
}

impl TransferRecord {
    pub fn new(
        record_identifier: String,
        package_identifier: String,
        peer_identifier: PeerId,
        bytes_transferred: u64,
        success: bool,
    ) -> Self {
        Self {
            record_identifier,
            package_identifier,
            peer_identifier,
            bytes_transferred,
            success,
        }
    }

    pub fn record_identifier(&self) -> &str {
        &self.record_identifier
    }

    pub fn package_identifier(&self) -> &str {
        &self.package_identifier
    }

    pub fn peer_identifier(&self) -> &PeerId {
        &self.peer_identifier
    }

    pub fn bytes_transferred(&self) -> u64 {
        self.bytes_transferred
    }

    pub fn is_success(&self) -> bool {
        self.success
    }
}

// -----------------------------------------------------------------------------
// 2. Interface Segregated Traits (ISP)
// -----------------------------------------------------------------------------

pub trait TrustReadStore: Send + Sync {
    fn find_peer_by_identifier(&self, peer_identifier: &PeerId) -> Result<Option<PeerEntity>, AirShipError>;
    fn find_peer_by_fingerprint(&self, fingerprint: &CryptoHash) -> Result<Option<PeerEntity>, AirShipError>;
    fn list_all_peers(&self) -> Result<Vec<PeerEntity>, AirShipError>;
}

pub trait TrustWriteStore: Send + Sync {
    fn save_peer(&self, peer: PeerEntity) -> Result<(), AirShipError>;
    fn update_trust_level(&self, peer_identifier: &PeerId, new_level: TrustLevel) -> Result<(), AirShipError>;
    fn delete_peer(&self, peer_identifier: &PeerId) -> Result<bool, AirShipError>;
}

pub trait TransferLogReadStore: Send + Sync {
    fn list_transfer_records(&self) -> Result<Vec<TransferRecord>, AirShipError>;
}

pub trait TransferLogWriteStore: Send + Sync {
    fn append_transfer_record(&self, record: TransferRecord) -> Result<(), AirShipError>;
}

// -----------------------------------------------------------------------------
// 3. In-Memory Storage Engine (LSP Compliant)
// -----------------------------------------------------------------------------

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
    fn find_peer_by_identifier(&self, peer_identifier: &PeerId) -> Result<Option<PeerEntity>, AirShipError> {
        let guard = self.peer_storage.read().map_err(|error| AirShipError::StorageFailure {
            message: error.to_string(),
        })?;
        Ok(guard.get(peer_identifier).cloned())
    }

    fn find_peer_by_fingerprint(&self, fingerprint: &CryptoHash) -> Result<Option<PeerEntity>, AirShipError> {
        let guard = self.peer_storage.read().map_err(|error| AirShipError::StorageFailure {
            message: error.to_string(),
        })?;
        let matching_peer = guard.values().find(|peer| peer.fingerprint() == fingerprint).cloned();
        Ok(matching_peer)
    }

    fn list_all_peers(&self) -> Result<Vec<PeerEntity>, AirShipError> {
        let guard = self.peer_storage.read().map_err(|error| AirShipError::StorageFailure {
            message: error.to_string(),
        })?;
        Ok(guard.values().cloned().collect())
    }
}

impl TrustWriteStore for InMemoryStorageEngine {
    fn save_peer(&self, peer: PeerEntity) -> Result<(), AirShipError> {
        let mut guard = self.peer_storage.write().map_err(|error| AirShipError::StorageFailure {
            message: error.to_string(),
        })?;
        guard.insert(peer.peer_identifier().clone(), peer);
        Ok(())
    }

    fn update_trust_level(&self, peer_identifier: &PeerId, new_level: TrustLevel) -> Result<(), AirShipError> {
        let mut guard = self.peer_storage.write().map_err(|error| AirShipError::StorageFailure {
            message: error.to_string(),
        })?;
        let peer_entry = guard.get_mut(peer_identifier).ok_or_else(|| AirShipError::PeerNotFound {
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
        let mut guard = self.peer_storage.write().map_err(|error| AirShipError::StorageFailure {
            message: error.to_string(),
        })?;
        Ok(guard.remove(peer_identifier).is_some())
    }
}

impl TransferLogReadStore for InMemoryStorageEngine {
    fn list_transfer_records(&self) -> Result<Vec<TransferRecord>, AirShipError> {
        let guard = self.transfer_records.read().map_err(|error| AirShipError::StorageFailure {
            message: error.to_string(),
        })?;
        Ok(guard.clone())
    }
}

impl TransferLogWriteStore for InMemoryStorageEngine {
    fn append_transfer_record(&self, record: TransferRecord) -> Result<(), AirShipError> {
        let mut guard = self.transfer_records.write().map_err(|error| AirShipError::StorageFailure {
            message: error.to_string(),
        })?;
        guard.push(record);
        Ok(())
    }
}

// -----------------------------------------------------------------------------
// 4. Unit Tests
// -----------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_peer_crud_and_trust_toggle() -> Result<(), AirShipError> {
        let store = InMemoryStorageEngine::new();
        let peer_id = PeerId::new("USER_ALICE".to_string())?;
        let fingerprint = CryptoHash::from_hex("c".repeat(64))?;
        let peer = PeerEntity::new(
            peer_id.clone(),
            "Alice Phone".to_string(),
            fingerprint,
            TrustLevel::UntrustedPrompt,
        );

        store.save_peer(peer)?;
        let retrieved = store.find_peer_by_identifier(&peer_id)?;
        assert!(retrieved.is_some());
        assert_eq!(retrieved.map(|entity| entity.trust_level()), Some(TrustLevel::UntrustedPrompt));

        store.update_trust_level(&peer_id, TrustLevel::TrustedAutoDownload)?;
        let updated = store.find_peer_by_identifier(&peer_id)?;
        assert_eq!(updated.map(|entity| entity.trust_level()), Some(TrustLevel::TrustedAutoDownload));

        let deleted = store.delete_peer(&peer_id)?;
        assert!(deleted);
        assert!(store.find_peer_by_identifier(&peer_id)?.is_none());
        Ok(())
    }

    #[test]
    fn test_transfer_log_append_and_read() -> Result<(), AirShipError> {
        let store = InMemoryStorageEngine::new();
        let peer_id = PeerId::new("USER_BOB".to_string())?;
        let record = TransferRecord::new(
            "rec_1".to_string(),
            "pkg_1".to_string(),
            peer_id,
            1048576,
            true,
        );
        store.append_transfer_record(record)?;
        let records = store.list_transfer_records()?;
        assert_eq!(records.len(), 1);
        assert_eq!(records.first().map(|rec| rec.bytes_transferred()), Some(1048576));
        Ok(())
    }
}
