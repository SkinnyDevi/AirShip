//! Cryptographic keypair generation, X.509 certificate pinning, and TLS 1.3 configurations.

pub mod constants;
pub mod generator;
pub mod identity;

// -----------------------------------------------------------------------------
// Unit Tests
// -----------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use airship_domain::{constants::TrustLevel, peer_entity::PeerEntity};
    use airship_primitives::{
        bytebuffer::ByteBuffer, constants::ED25519_PUBLIC_KEY_LENGTH, errors::AirShipError,
    };

    use crate::generator::{
        CertificateValidator, IdentityKeyGenerator, MockCertificateValidator,
        MockIdentityKeyGenerator,
    };

    #[test]
    fn test_mock_key_generation() -> Result<(), AirShipError> {
        let identity_generator = MockIdentityKeyGenerator::new();
        let keypair = identity_generator.generate_persistent_identity("ALICE")?;
        assert_eq!(keypair.public_key_bytes().len(), ED25519_PUBLIC_KEY_LENGTH);
        assert_eq!(keypair.derived_peer_id().as_str(), "USER_ALICE");
        Ok(())
    }

    #[test]
    fn test_certificate_pin_matching() -> Result<(), AirShipError> {
        let identity_generator = MockIdentityKeyGenerator::new();
        let keypair = identity_generator.generate_persistent_identity("BOB")?;
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
