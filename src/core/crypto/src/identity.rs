use airship_primitives::constants::ED25519_PUBLIC_KEY_LENGTH;
use airship_primitives::cryptohash::CryptoHash;
use airship_primitives::errors::AirShipError;
use airship_primitives::peer::PeerId;

use crate::constants::TLS_PROTOCOL_VERSION_1_3;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct IdentityKeypair {
    public_key_bytes: Vec<u8>,
    secret_key_bytes: Vec<u8>,
    derived_peer_id: PeerId,
    public_fingerprint: CryptoHash,
}

impl IdentityKeypair {
    pub fn new(
        public_key_bytes: Vec<u8>,
        secret_key_bytes: Vec<u8>,
        derived_peer_id: PeerId,
        public_fingerprint: CryptoHash,
    ) -> Result<Self, AirShipError> {
        if public_key_bytes.len() != ED25519_PUBLIC_KEY_LENGTH {
            return Err(AirShipError::InvalidPublicKeyLength {
                actual_length: public_key_bytes.len(),
            });
        }

        Ok(Self {
            public_key_bytes,
            secret_key_bytes,
            derived_peer_id,
            public_fingerprint,
        })
    }

    pub fn public_key_bytes(&self) -> &[u8] {
        &self.public_key_bytes
    }

    pub fn derived_peer_id(&self) -> &PeerId {
        &self.derived_peer_id
    }

    pub fn public_fingerprint(&self) -> &CryptoHash {
        &self.public_fingerprint
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TlsCertificatePin {
    pinned_fingerprint: CryptoHash,
}

impl TlsCertificatePin {
    pub fn new(pinned_fingerprint: CryptoHash) -> Self {
        Self { pinned_fingerprint }
    }

    pub fn verify_fingerprint(&self, candidate_fingerprint: &CryptoHash) -> bool {
        &self.pinned_fingerprint == candidate_fingerprint
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TlsConfiguration {
    protocol_version: &'static str,
    identity_keypair: IdentityKeypair,
}

impl TlsConfiguration {
    pub fn new(identity_keypair: IdentityKeypair) -> Self {
        Self {
            protocol_version: TLS_PROTOCOL_VERSION_1_3,
            identity_keypair,
        }
    }

    pub fn protocol_version(&self) -> &'static str {
        self.protocol_version
    }

    pub fn identity_keypair(&self) -> &IdentityKeypair {
        &self.identity_keypair
    }
}
