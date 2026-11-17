use crate::constants::FINGERPRINT_HEX_LENGTH;
use crate::errors::AirShipError;
use crate::hex::validate_hex_character;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct CryptoHash {
    hex_digest: String,
}

impl CryptoHash {
    pub fn from_hex(hex_digest: String) -> Result<Self, AirShipError> {
        if hex_digest.len() != FINGERPRINT_HEX_LENGTH {
            return Err(AirShipError::InvalidFingerprintLength {
                actual_length: hex_digest.len(),
            });
        }

        let all_hex_characters = hex_digest.chars().all(validate_hex_character);
        if !all_hex_characters {
            return Err(AirShipError::InvalidIdentifier {
                reason: "Fingerprint contains non-hexadecimal characters".to_string(),
            });
        }

        Ok(Self { hex_digest })
    }

    pub fn as_str(&self) -> &str {
        &self.hex_digest
    }
}
