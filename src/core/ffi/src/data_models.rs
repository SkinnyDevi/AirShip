#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiPeerInfo {
    pub peer_identifier: String,
    pub display_alias: String,
    pub fingerprint_hex: String,
    pub is_trusted: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiManifestSummary {
    pub package_identifier: String,
    pub sender_identifier: String,
    pub item_count: u32,
    pub total_bytes: u64,
}
