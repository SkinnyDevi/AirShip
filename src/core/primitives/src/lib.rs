//! Core primitive types, byte buffers, cryptographic hash wrappers, and error definitions.

use std::fmt::{Display, Formatter, Result as FmtResult};

// -----------------------------------------------------------------------------
// 1. Constants
// -----------------------------------------------------------------------------

pub const DEFAULT_CHUNK_SIZE_BYTES: usize = 64 * 1024;
pub const FINGERPRINT_HEX_LENGTH: usize = 64;
pub const ED25519_PUBLIC_KEY_LENGTH: usize = 32;

// -----------------------------------------------------------------------------
// 2. Error Types
// -----------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AirShipError {
    EmptyPayload,
    InvalidChunkIndex { requested_index: usize, total_chunks: usize },
    InvalidFingerprintLength { actual_length: usize },
    InvalidPublicKeyLength { actual_length: usize },
    InvalidIdentifier { reason: String },
    PeerNotFound { peer_identifier: String },
    StorageFailure { message: String },
    NetworkFailure { message: String },
    TlsHandshakeFailed { message: String },
    TransferRejected { reason: String },
}

impl Display for AirShipError {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> FmtResult {
        match self {
            Self::EmptyPayload => write!(formatter, "Payload byte buffer cannot be empty"),
            Self::InvalidChunkIndex { requested_index, total_chunks } => {
                write!(formatter, "Chunk index {requested_index} is out of bounds (total: {total_chunks})")
            }
            Self::InvalidFingerprintLength { actual_length } => {
                write!(formatter, "Invalid fingerprint length: {actual_length}, expected {FINGERPRINT_HEX_LENGTH}")
            }
            Self::InvalidPublicKeyLength { actual_length } => {
                write!(formatter, "Invalid public key length: {actual_length}, expected {ED25519_PUBLIC_KEY_LENGTH}")
            }
            Self::InvalidIdentifier { reason } => write!(formatter, "Invalid identifier: {reason}"),
            Self::PeerNotFound { peer_identifier } => write!(formatter, "Peer not found: {peer_identifier}"),
            Self::StorageFailure { message } => write!(formatter, "Storage error: {message}"),
            Self::NetworkFailure { message } => write!(formatter, "Network error: {message}"),
            Self::TlsHandshakeFailed { message } => write!(formatter, "mTLS handshake failed: {message}"),
            Self::TransferRejected { reason } => write!(formatter, "Transfer rejected: {reason}"),
        }
    }
}

impl std::error::Error for AirShipError {}

// -----------------------------------------------------------------------------
// 3. Pure Helper Functions
// -----------------------------------------------------------------------------

fn validate_hex_character(character: char) -> bool {
    character.is_ascii_hexdigit()
}

fn validate_identifier_character(character: char) -> bool {
    character.is_ascii_alphanumeric() || character == '_' || character == '-'
}

// -----------------------------------------------------------------------------
// 4. Domain Structs & Primitive Types
// -----------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ByteBuffer {
    storage: Vec<u8>,
}

impl ByteBuffer {
    pub fn new(storage: Vec<u8>) -> Self {
        Self { storage }
    }

    pub fn empty() -> Self {
        Self { storage: Vec::new() }
    }

    pub fn len(&self) -> usize {
        self.storage.len()
    }

    pub fn is_empty(&self) -> bool {
        self.storage.is_empty()
    }

    pub fn as_slice(&self) -> &[u8] {
        &self.storage
    }

    pub fn into_inner(self) -> Vec<u8> {
        self.storage
    }

    pub fn slice_chunk(&self, chunk_index: usize, chunk_size: usize) -> Result<&[u8], AirShipError> {
        if self.storage.is_empty() {
            return Err(AirShipError::EmptyPayload);
        }
        let total_chunks = self.storage.len().div_ceil(chunk_size);
        if chunk_index >= total_chunks {
            return Err(AirShipError::InvalidChunkIndex {
                requested_index: chunk_index,
                total_chunks,
            });
        }
        let start_offset = chunk_index * chunk_size;
        let end_offset = std::cmp::min(start_offset + chunk_size, self.storage.len());
        Ok(&self.storage[start_offset..end_offset])
    }
}

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

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct PeerId {
    raw_identifier: String,
}

impl PeerId {
    pub fn new(raw_identifier: String) -> Result<Self, AirShipError> {
        if raw_identifier.is_empty() {
            return Err(AirShipError::InvalidIdentifier {
                reason: "Peer identifier cannot be empty".to_string(),
            });
        }
        let valid_characters = raw_identifier.chars().all(validate_identifier_character);
        if !valid_characters {
            return Err(AirShipError::InvalidIdentifier {
                reason: "Peer identifier contains invalid characters".to_string(),
            });
        }
        Ok(Self { raw_identifier })
    }

    pub fn as_str(&self) -> &str {
        &self.raw_identifier
    }
}

// -----------------------------------------------------------------------------
// 5. Unit Tests
// -----------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_byte_buffer_chunking() {
        let payload = vec![1, 2, 3, 4, 5, 6, 7];
        let buffer = ByteBuffer::new(payload);
        let first_chunk = buffer.slice_chunk(0, 3);
        assert_eq!(first_chunk, Ok(&[1, 2, 3][..]));
        let third_chunk = buffer.slice_chunk(2, 3);
        assert_eq!(third_chunk, Ok(&[7][..]));
        let out_of_bounds = buffer.slice_chunk(3, 3);
        assert!(out_of_bounds.is_err());
    }

    #[test]
    fn test_crypto_hash_validation() {
        let valid_hex = "a".repeat(64);
        let hash = CryptoHash::from_hex(valid_hex);
        assert!(hash.is_ok());

        let invalid_length = "a".repeat(32);
        assert!(CryptoHash::from_hex(invalid_length).is_err());

        let invalid_chars = "z".repeat(64);
        assert!(CryptoHash::from_hex(invalid_chars).is_err());
    }

    #[test]
    fn test_peer_id_validation() {
        let valid_id = PeerId::new("USER_NAME_123".to_string());
        assert!(valid_id.is_ok());

        let empty_id = PeerId::new("".to_string());
        assert!(empty_id.is_err());

        let invalid_chars = PeerId::new("USER!@#".to_string());
        assert!(invalid_chars.is_err());
    }
}
