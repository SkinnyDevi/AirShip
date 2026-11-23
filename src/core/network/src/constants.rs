pub const MDNS_SERVICE_TYPE: &str = "_airship._tcp.local.";
pub const UDP_FALLBACK_BEACON_PORT: u16 = 53317;
pub const DEFAULT_STREAM_PORT: u16 = 53318;

pub const ACCEPT_POLL_INTERVAL_MS: u64 = 25;
pub const STREAM_IO_TIMEOUT_SECONDS: u64 = 10;

pub const WIRE_HEADER_BYTE_LENGTH: usize = 5;
pub const MAX_WIRE_FRAME_PAYLOAD_BYTES: u32 = 1_048_576;
pub const TRANSFER_CHUNK_BYTE_SIZE: usize = 65_536;
