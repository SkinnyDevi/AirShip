use airship_primitives::bytebuffer::ByteBuffer;
use airship_primitives::constants::ED25519_PUBLIC_KEY_LENGTH;
use airship_primitives::cryptohash::CryptoHash;
use airship_primitives::errors::AirShipError;

use airship_domain::peer_entity::PeerEntity;
use airship_primitives::peer::PeerId;

use crate::constants::ED25519_SECRET_KEY_LENGTH;
use crate::identity::{IdentityKeypair, TlsCertificatePin};

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

pub trait IdentityKeyGenerator: Send + Sync {
    fn generate_persistent_identity(
        &self,
        user_name_alias: &str,
    ) -> Result<IdentityKeypair, AirShipError>;
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
    fn generate_persistent_identity(
        &self,
        user_name_alias: &str,
    ) -> Result<IdentityKeypair, AirShipError> {
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
