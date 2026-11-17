use airship_domain::{constants::TrustLevel, peer_entity::PeerEntity};
use airship_primitives::{cryptohash::CryptoHash, errors::AirShipError, peer::PeerId};

use crate::constants::TransferRecord;

pub trait TrustReadStore: Send + Sync {
    fn find_peer_by_identifier(
        &self,
        peer_identifier: &PeerId,
    ) -> Result<Option<PeerEntity>, AirShipError>;

    fn find_peer_by_fingerprint(
        &self,
        fingerprint: &CryptoHash,
    ) -> Result<Option<PeerEntity>, AirShipError>;

    fn list_all_peers(&self) -> Result<Vec<PeerEntity>, AirShipError>;
}

pub trait TrustWriteStore: Send + Sync {
    fn save_peer(&self, peer: PeerEntity) -> Result<(), AirShipError>;

    fn update_trust_level(
        &self,
        peer_identifier: &PeerId,
        new_level: TrustLevel,
    ) -> Result<(), AirShipError>;

    fn delete_peer(&self, peer_identifier: &PeerId) -> Result<bool, AirShipError>;
}

pub trait TransferLogReadStore: Send + Sync {
    fn list_transfer_records(&self) -> Result<Vec<TransferRecord>, AirShipError>;
}

pub trait TransferLogWriteStore: Send + Sync {
    fn append_transfer_record(&self, record: TransferRecord) -> Result<(), AirShipError>;
}
