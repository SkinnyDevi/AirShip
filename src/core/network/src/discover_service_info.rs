use airship_primitives::{cryptohash::CryptoHash, peer::PeerId};

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
