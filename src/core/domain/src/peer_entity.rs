use airship_primitives::cryptohash::CryptoHash;
use airship_primitives::peer::PeerId;

use crate::constants::TrustLevel;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PeerEntity {
    peer_identifier: PeerId,
    display_alias: String,
    fingerprint: CryptoHash,
    trust_level: TrustLevel,
}

impl PeerEntity {
    pub fn new(
        peer_identifier: PeerId,
        display_alias: String,
        fingerprint: CryptoHash,
        trust_level: TrustLevel,
    ) -> Self {
        Self {
            peer_identifier,
            display_alias,
            fingerprint,
            trust_level,
        }
    }

    pub fn peer_identifier(&self) -> &PeerId {
        &self.peer_identifier
    }

    pub fn display_alias(&self) -> &str {
        &self.display_alias
    }

    pub fn fingerprint(&self) -> &CryptoHash {
        &self.fingerprint
    }

    pub fn trust_level(&self) -> TrustLevel {
        self.trust_level
    }

    pub fn is_trusted(&self) -> bool {
        self.trust_level == TrustLevel::TrustedAutoDownload
    }
}
