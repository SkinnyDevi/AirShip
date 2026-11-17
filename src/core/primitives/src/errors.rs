use crate::constants::{ED25519_PUBLIC_KEY_LENGTH, FINGERPRINT_HEX_LENGTH};

use std::fmt::{Display, Formatter, Result as FmtResult};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AirShipError {
    EmptyPayload,
    InvalidChunkIndex {
        requested_index: usize,
        total_chunks: usize,
    },
    InvalidFingerprintLength {
        actual_length: usize,
    },
    InvalidPublicKeyLength {
        actual_length: usize,
    },
    InvalidIdentifier {
        reason: String,
    },
    PeerNotFound {
        peer_identifier: String,
    },
    StorageFailure {
        message: String,
    },
    NetworkFailure {
        message: String,
    },
    TlsHandshakeFailed {
        message: String,
    },
    TransferRejected {
        reason: String,
    },
}

impl Display for AirShipError {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> FmtResult {
        match self {
            Self::EmptyPayload => write!(formatter, "Payload byte buffer cannot be empty"),
            Self::InvalidChunkIndex {
                requested_index,
                total_chunks,
            } => {
                write!(
                    formatter,
                    "Chunk index {requested_index} is out of bounds (total: {total_chunks})"
                )
            }
            Self::InvalidFingerprintLength { actual_length } => {
                write!(
                    formatter,
                    "Invalid fingerprint length: {actual_length}, expected {FINGERPRINT_HEX_LENGTH}"
                )
            }
            Self::InvalidPublicKeyLength { actual_length } => {
                write!(
                    formatter,
                    "Invalid public key length: {actual_length}, expected {ED25519_PUBLIC_KEY_LENGTH}"
                )
            }
            Self::InvalidIdentifier { reason } => write!(formatter, "Invalid identifier: {reason}"),
            Self::PeerNotFound { peer_identifier } => {
                write!(formatter, "Peer not found: {peer_identifier}")
            }
            Self::StorageFailure { message } => write!(formatter, "Storage error: {message}"),
            Self::NetworkFailure { message } => write!(formatter, "Network error: {message}"),
            Self::TlsHandshakeFailed { message } => {
                write!(formatter, "mTLS handshake failed: {message}")
            }
            Self::TransferRejected { reason } => write!(formatter, "Transfer rejected: {reason}"),
        }
    }
}

impl std::error::Error for AirShipError {}
