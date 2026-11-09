//! Domain entities, trust evaluation models, package manifests, and transfer state machines.

use airship_primitives::{AirShipError, CryptoHash, PeerId};

// -----------------------------------------------------------------------------
// 1. Constants & Enums
// -----------------------------------------------------------------------------

pub const HTTP_STATUS_OK: u16 = 200;
pub const HTTP_STATUS_ACCEPTED_PENDING: u16 = 202;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransferMode {
    Send,
    Receive,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TrustLevel {
    UntrustedPrompt,
    TrustedAutoDownload,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PayloadKind {
    Photos,
    Camera,
    Files,
    Text,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransferStatus {
    Idle,
    Staged,
    PendingApproval,
    Streaming,
    Completed,
    Rejected,
    Failed,
}

// -----------------------------------------------------------------------------
// 2. Pure Helper Functions
// -----------------------------------------------------------------------------

fn calculate_manifest_total_bytes(items: &[PackageManifestItem]) -> u64 {
    items.iter().map(|item| item.byte_size).sum()
}

// -----------------------------------------------------------------------------
// 3. Domain Entities & Manifest Models
// -----------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PeerEntity {
    peer_identifier: PeerId,
    display_alias: String,
    fingerprint: CryptoHash,
    trust_level: TrustLevel,
}

impl PeerEntity {
    pub fn new(
        peer_identifier: PeerId,
        display_alias: String,
        fingerprint: CryptoHash,
        trust_level: TrustLevel,
    ) -> Self {
        Self {
            peer_identifier,
            display_alias,
            fingerprint,
            trust_level,
        }
    }

    pub fn peer_identifier(&self) -> &PeerId {
        &self.peer_identifier
    }

    pub fn display_alias(&self) -> &str {
        &self.display_alias
    }

    pub fn fingerprint(&self) -> &CryptoHash {
        &self.fingerprint
    }

    pub fn trust_level(&self) -> TrustLevel {
        self.trust_level
    }

    pub fn is_trusted(&self) -> bool {
        self.trust_level == TrustLevel::TrustedAutoDownload
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PackageManifestItem {
    item_identifier: String,
    item_name: String,
    byte_size: u64,
    mime_type: String,
    payload_kind: PayloadKind,
    checksum: CryptoHash,
}

impl PackageManifestItem {
    pub fn new(
        item_identifier: String,
        item_name: String,
        byte_size: u64,
        mime_type: String,
        payload_kind: PayloadKind,
        checksum: CryptoHash,
    ) -> Self {
        Self {
            item_identifier,
            item_name,
            byte_size,
            mime_type,
            payload_kind,
            checksum,
        }
    }

    pub fn item_identifier(&self) -> &str {
        &self.item_identifier
    }

    pub fn item_name(&self) -> &str {
        &self.item_name
    }

    pub fn byte_size(&self) -> u64 {
        self.byte_size
    }

    pub fn mime_type(&self) -> &str {
        &self.mime_type
    }

    pub fn payload_kind(&self) -> PayloadKind {
        self.payload_kind
    }

    pub fn checksum(&self) -> &CryptoHash {
        &self.checksum
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PackageManifest {
    package_identifier: String,
    sender_identifier: PeerId,
    items: Vec<PackageManifestItem>,
    total_bytes: u64,
}

impl PackageManifest {
    pub fn new(
        package_identifier: String,
        sender_identifier: PeerId,
        items: Vec<PackageManifestItem>,
    ) -> Result<Self, AirShipError> {
        if items.is_empty() {
            return Err(AirShipError::EmptyPayload);
        }
        let total_bytes = calculate_manifest_total_bytes(&items);
        Ok(Self {
            package_identifier,
            sender_identifier,
            items,
            total_bytes,
        })
    }

    pub fn package_identifier(&self) -> &str {
        &self.package_identifier
    }

    pub fn sender_identifier(&self) -> &PeerId {
        &self.sender_identifier
    }

    pub fn items(&self) -> &[PackageManifestItem] {
        &self.items
    }

    pub fn total_bytes(&self) -> u64 {
        self.total_bytes
    }
}

// -----------------------------------------------------------------------------
// 4. Trust Evaluation & State Machine
// -----------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TransferDecision {
    AutoDownloadDirectly { status_code: u16 },
    RequireManualApproval { status_code: u16 },
}

pub trait TrustEvaluator: Send + Sync {
    fn evaluate_incoming_package(
        &self,
        sender: &PeerEntity,
        manifest: &PackageManifest,
    ) -> Result<TransferDecision, AirShipError>;
}

#[derive(Debug, Default)]
pub struct DefaultTrustEvaluator;

impl DefaultTrustEvaluator {
    pub fn new() -> Self {
        Self
    }
}

impl TrustEvaluator for DefaultTrustEvaluator {
    fn evaluate_incoming_package(
        &self,
        sender: &PeerEntity,
        manifest: &PackageManifest,
    ) -> Result<TransferDecision, AirShipError> {
        if manifest.items().is_empty() {
            return Err(AirShipError::EmptyPayload);
        }
        if sender.is_trusted() {
            Ok(TransferDecision::AutoDownloadDirectly {
                status_code: HTTP_STATUS_OK,
            })
        } else {
            Ok(TransferDecision::RequireManualApproval {
                status_code: HTTP_STATUS_ACCEPTED_PENDING,
            })
        }
    }
}

// -----------------------------------------------------------------------------
// 5. Unit Tests
// -----------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

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
