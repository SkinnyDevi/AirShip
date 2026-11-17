//! Domain entities, trust evaluation models, package manifests, and transfer state machines.

pub mod constants;
pub mod manifest;
pub mod peer_entity;
pub mod trust_evaluator;

// -----------------------------------------------------------------------------
// Unit Tests
// -----------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use crate::constants::{HTTP_STATUS_ACCEPTED_PENDING, HTTP_STATUS_OK, PayloadKind, TrustLevel};
    use crate::manifest::{PackageManifest, PackageManifestItem};
    use crate::peer_entity::PeerEntity;
    use crate::trust_evaluator::TrustEvaluator;
    use crate::trust_evaluator::{DefaultTrustEvaluator, TransferDecision};

    use airship_primitives::cryptohash::CryptoHash;
    use airship_primitives::errors::AirShipError;
    use airship_primitives::peer::PeerId;

    fn create_test_manifest(sender_id: PeerId) -> Result<PackageManifest, AirShipError> {
        let valid_hash = CryptoHash::from_hex("0".repeat(64))?;
        let item = PackageManifestItem::new(
            "item_1".to_string(),
            "photo.jpg".to_string(),
            1024,
            "image/jpeg".to_string(),
            PayloadKind::Photos,
            valid_hash,
        );

        PackageManifest::new("pkg_1".to_string(), sender_id, vec![item])
    }

    #[test]
    fn test_trusted_peer_fast_path() -> Result<(), AirShipError> {
        let peer_id = PeerId::new("ALICE_NODE".to_string())?;
        let hash = CryptoHash::from_hex("a".repeat(64))?;
        let trusted_peer = PeerEntity::new(
            peer_id.clone(),
            "Alice Device".to_string(),
            hash,
            TrustLevel::TrustedAutoDownload,
        );

        let manifest = create_test_manifest(peer_id)?;
        let evaluator = DefaultTrustEvaluator::new();
        let decision = evaluator.evaluate_incoming_package(&trusted_peer, &manifest)?;
        assert_eq!(
            decision,
            TransferDecision::AutoDownloadDirectly {
                status_code: HTTP_STATUS_OK
            }
        );

        Ok(())
    }

    #[test]
    fn test_untrusted_peer_manual_approval() -> Result<(), AirShipError> {
        let peer_id = PeerId::new("BOB_NODE".to_string())?;
        let hash = CryptoHash::from_hex("b".repeat(64))?;
        let untrusted_peer = PeerEntity::new(
            peer_id.clone(),
            "Bob Device".to_string(),
            hash,
            TrustLevel::UntrustedPrompt,
        );

        let manifest = create_test_manifest(peer_id)?;
        let evaluator = DefaultTrustEvaluator::new();
        let decision = evaluator.evaluate_incoming_package(&untrusted_peer, &manifest)?;
        assert_eq!(
            decision,
            TransferDecision::RequireManualApproval {
                status_code: HTTP_STATUS_ACCEPTED_PENDING
            }
        );

        Ok(())
    }
}
