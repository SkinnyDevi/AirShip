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
