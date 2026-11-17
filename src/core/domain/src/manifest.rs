use airship_primitives::cryptohash::CryptoHash;
use airship_primitives::errors::AirShipError;
use airship_primitives::peer::PeerId;

use crate::constants::PayloadKind;

fn calculate_manifest_total_bytes(items: &[PackageManifestItem]) -> u64 {
    items.iter().map(|item| item.byte_size).sum()
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
