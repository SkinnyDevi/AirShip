//! Core primitive types, byte buffers, cryptographic hash wrappers, and error definitions.

pub mod bytebuffer;
pub mod constants;
pub mod cryptohash;
pub mod errors;
mod hex;
pub mod peer;

// -----------------------------------------------------------------------------
// Unit Tests
// -----------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use crate::bytebuffer::ByteBuffer;
    use crate::cryptohash::CryptoHash;
    use crate::peer::PeerId;

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
