//! Cryptographic keypair generation, X.509 certificate pinning, and TLS 1.3 configurations.

use airship_domain::PeerEntity;
use airship_primitives::{AirShipError, ByteBuffer, CryptoHash, PeerId, ED25519_PUBLIC_KEY_LENGTH};

// -----------------------------------------------------------------------------
// 1. Constants
// -----------------------------------------------------------------------------

pub const ED25519_SECRET_KEY_LENGTH: usize = 32;
pub const TLS_PROTOCOL_VERSION_1_3: &str = "TLSv1.3";

// -----------------------------------------------------------------------------
// 2. Pure Helper Functions
// -----------------------------------------------------------------------------

fn format_simulated_fingerprint(public_key_slice: &[u8]) -> String {
    let mut hex_string = String::with_capacity(64);
    for byte_value in public_key_slice.iter().take(32) {
        let high_nibble = char::from_digit((byte_value >> 4) as u32, 16);
        let low_nibble = char::from_digit((byte_value & 0x0f) as u32, 16);
        if let Some(character) = high_nibble {
            hex_string.push(character);
        }
        if let Some(character) = low_nibble {
            hex_string.push(character);
        }
    }
    while hex_string.len() < 64 {
        hex_string.push('0');
    }
    hex_string
}

// -----------------------------------------------------------------------------
// 3. Domain Structs & Configurations
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// 4. Traits & Implementations
// -----------------------------------------------------------------------------

pub trait IdentityKeyGenerator: Send + Sync {
    fn generate_persistent_identity(&self, user_name_alias: &str) -> Result<IdentityKeypair, AirShipError>;
}

pub trait CertificateValidator: Send + Sync {
    fn validate_peer_certificate(
        &self,
        peer: &PeerEntity,
        presented_certificate_bytes: &ByteBuffer,
    ) -> Result<bool, AirShipError>;
}

#[derive(Debug, Default)]
pub struct MockIdentityKeyGenerator;

impl MockIdentityKeyGenerator {
    pub fn new() -> Self {
        Self
    }
}

impl IdentityKeyGenerator for MockIdentityKeyGenerator {
    fn generate_persistent_identity(&self, user_name_alias: &str) -> Result<IdentityKeypair, AirShipError> {
        let public_bytes = vec![0x42u8; ED25519_PUBLIC_KEY_LENGTH];
        let secret_bytes = vec![0x24u8; ED25519_SECRET_KEY_LENGTH];
        let peer_id_string = format!("USER_{user_name_alias}");
        let peer_id = PeerId::new(peer_id_string)?;
        let hex_string = format_simulated_fingerprint(&public_bytes);
        let fingerprint = CryptoHash::from_hex(hex_string)?;
        IdentityKeypair::new(public_bytes, secret_bytes, peer_id, fingerprint)
    }
}

#[derive(Debug, Default)]
pub struct MockCertificateValidator;

impl MockCertificateValidator {
    pub fn new() -> Self {
        Self
    }
}

impl CertificateValidator for MockCertificateValidator {
    fn validate_peer_certificate(
        &self,
        peer: &PeerEntity,
        presented_certificate_bytes: &ByteBuffer,
    ) -> Result<bool, AirShipError> {
        if presented_certificate_bytes.is_empty() {
            return Err(AirShipError::EmptyPayload);
        }
        let pin = TlsCertificatePin::new(peer.fingerprint().clone());
        Ok(pin.verify_fingerprint(peer.fingerprint()))
    }
}

// -----------------------------------------------------------------------------
// 5. Unit Tests
// -----------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use airship_domain::TrustLevel;

    #[test]
    fn test_mock_key_generation() -> Result<(), AirShipError> {
        let generator = MockIdentityKeyGenerator::new();
        let keypair = generator.generate_persistent_identity("ALICE")?;
        assert_eq!(keypair.public_key_bytes().len(), ED25519_PUBLIC_KEY_LENGTH);
        assert_eq!(keypair.derived_peer_id().as_str(), "USER_ALICE");
        Ok(())
    }

    #[test]
    fn test_certificate_pin_matching() -> Result<(), AirShipError> {
        let generator = MockIdentityKeyGenerator::new();
        let keypair = generator.generate_persistent_identity("BOB")?;
        let peer = PeerEntity::new(
            keypair.derived_peer_id().clone(),
            "Bob Device".to_string(),
            keypair.public_fingerprint().clone(),
            TrustLevel::TrustedAutoDownload,
        );
        let validator = MockCertificateValidator::new();
        let dummy_cert = ByteBuffer::new(vec![0x30, 0x82, 0x01]);
        let is_valid = validator.validate_peer_certificate(&peer, &dummy_cert)?;
        assert!(is_valid);
        Ok(())
    }
}
