//! Embedded persistence interfaces and storage implementations for trusted peers and transfer logs.

pub mod constants;
pub mod storage_engine;
pub mod store;

// -----------------------------------------------------------------------------
// Unit Tests
// -----------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use airship_domain::{constants::TrustLevel, peer_entity::PeerEntity};
    use airship_primitives::{cryptohash::CryptoHash, errors::AirShipError, peer::PeerId};

    use crate::{
        constants::TransferRecord,
        storage_engine::InMemoryStorageEngine,
        store::{TransferLogReadStore, TransferLogWriteStore, TrustReadStore, TrustWriteStore},
    };

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
        assert_eq!(
            retrieved.map(|entity| entity.trust_level()),
            Some(TrustLevel::UntrustedPrompt)
        );

        store.update_trust_level(&peer_id, TrustLevel::TrustedAutoDownload)?;
        let updated = store.find_peer_by_identifier(&peer_id)?;
        assert_eq!(
            updated.map(|entity| entity.trust_level()),
            Some(TrustLevel::TrustedAutoDownload)
        );

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
        assert_eq!(
            records.first().map(|rec| rec.bytes_transferred()),
            Some(1048576)
        );
        Ok(())
    }
}
