use airship_primitives::peer::PeerId;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TransferRecord {
    record_identifier: String,
    package_identifier: String,
    peer_identifier: PeerId,
    bytes_transferred: u64,
    success: bool,
}

impl TransferRecord {
    pub fn new(
        record_identifier: String,
        package_identifier: String,
        peer_identifier: PeerId,
        bytes_transferred: u64,
        success: bool,
    ) -> Self {
        Self {
            record_identifier,
            package_identifier,
            peer_identifier,
            bytes_transferred,
            success,
        }
    }

    pub fn record_identifier(&self) -> &str {
        &self.record_identifier
    }

    pub fn package_identifier(&self) -> &str {
        &self.package_identifier
    }

    pub fn peer_identifier(&self) -> &PeerId {
        &self.peer_identifier
    }

    pub fn bytes_transferred(&self) -> u64 {
        self.bytes_transferred
    }

    pub fn is_success(&self) -> bool {
        self.success
    }
}
